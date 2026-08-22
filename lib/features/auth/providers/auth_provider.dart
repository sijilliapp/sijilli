// 📍 lib/features/auth/providers/auth_provider.dart
// 🔐 إدارة حالة المصادقة في التطبيق (نسخة محسنة لتقليل تذبذب الحالة)

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../appointments/services/pb_appointment_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'dart:convert';
import '../../../core/services/pocketbase_client.dart';
import '../services/pb_auth_service.dart';
import '../../settings/services/pb_user_service.dart';
import '../../../core/local/local_db_service.dart';
import '../../../core/security/secure_storage_service.dart';
import '../../../models/user.dart';
import 'package:pocketbase/pocketbase.dart';
import '../services/pb_claim_service.dart';
import '../services/pb_role_service.dart';
import '../../../core/services/onesignal_service.dart';

enum AuthStatus {
  initial,      
  loading,      
  authenticated, 
  unauthenticated, 
  error,        
}

class AuthProvider extends ChangeNotifier {
  // ====================== الحالة ======================
  AuthStatus _status = AuthStatus.initial;
  UserModel? _user;
  String? _errorMessage;
  bool _isLoading = false;
  bool _hasJustClaimedInvitation = false;
  
  static const String keyRecentUsernames = 'recent_usernames';
  List<String> _recentUsernames = [];
  List<String> get recentUsernames => _recentUsernames;
  
  // ====================== الخدمات ======================
  final PbAuthService _authService = PbAuthService();
  final PbUserService _userService = PbUserService();
  final LocalDbService _localDb = LocalDbService.instance;
  final PbClaimService _claimService = PbClaimService();
  final PbRoleService _roleService = PbRoleService();
  final SecureStorageService _secureStorage = SecureStorageService.instance;
  
  // ====================== Getters ======================
  AuthStatus get status => _status;
  UserModel? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _status == AuthStatus.authenticated && _user != null;
  bool get isUnauthenticated => _status == AuthStatus.unauthenticated;
  bool get hasJustClaimedInvitation => _hasJustClaimedInvitation;
  
  void clearJustClaimedInvitation() {
    _hasJustClaimedInvitation = false;
  }
  
  void setJustClaimedInvitation(bool value) {
    _hasJustClaimedInvitation = value;
    notifyListeners();
  }
  
  // ====================== مساعدات الحالة الذرية ======================
  
  /// تحديث الحالة والمستخدم في آن واحد لتقليل notifyListeners
  void _updateState({AuthStatus? status, UserModel? user, bool? loading, String? error, bool clearError = false}) {
    bool changed = false;
    if (status != null && _status != status) {
      _status = status;
      changed = true;
    }
    
    // 🛡️ حماية المستخدم من الإلغاء العرضي أثناء التحميل
    // نحدث المستخدم فقط إذا تم تمرير قيمة غير فارغة، 
    // أو إذا كانت الحالة الجديدة هي 'unauthenticated'
    if (user != null) {
      if (_user != user) {
        _user = user;
        changed = true;
      }
    } else if (status == AuthStatus.unauthenticated) {
      if (_user != null) {
        _user = null;
        changed = true;
      }
    }

    if (loading != null && _isLoading != loading) {
      _isLoading = loading;
      changed = true;
    }
    if (error != null && _errorMessage != error) {
      _errorMessage = error;
      changed = true;
    }
    if (clearError && _errorMessage != null) {
      _errorMessage = null;
      changed = true;
    }
    
    if (changed) {
      notifyListeners();
    }
  }

  // ====================== التهيئة ======================
  
  Future<void> initialize() async {
    _updateState(loading: true, status: AuthStatus.loading);
    
    try {
      // إيقاظ الخادم على الفور عند بدء التشغيل
      await PocketBaseClient.instance.wakeUpServer();
      
      // تحميل الأدوار المخزنة كاش إلى الذاكرة المؤقتة للـ UserModel فوراً
      try {
        await _roleService.getCachedUserRoles();
      } catch (e) {
        debugPrint('⚠️ Failed to load cached roles in memory: $e');
      }

      // 1. First priority: The persistent AuthStore from PocketBase
      final pbUser = PocketBaseClient.instance.currentUser;
      
      if (pbUser != null) {
        debugPrint('🔐 AuthProvider: Found valid session in PersistentAuthStore');
        _user = pbUser;
        _status = AuthStatus.authenticated;
        // Also ensure local DB is synced
        await _localDb.saveUser(pbUser);
        OneSignalService.instance.loginUser(pbUser.id);
      } else {
        // 2. Second priority: Fallback to local DB (might have user but expired token)
        final localUser = await _localDb.getUser().timeout(
          const Duration(seconds: 3),
          onTimeout: () => null,
        );

        if (localUser != null) {
          debugPrint('🔐 AuthProvider: Found user in Local DB (Syncing to AuthStore)');
          _user = localUser;
          _status = AuthStatus.authenticated;
          
          // Inject token back to PocketBase just in case
          if (localUser.token != null) {
            try {
               PocketBaseClient.instance.pb.authStore.save(localUser.token!, null);
            } catch (_) {}
          }
        }
      }

      // Fetch roles configuration in the background
      unawaited(_roleService.fetchAndCacheUserRoles().then((_) async {
        if (_user != null) {
          final updatedUser = await _attachRoleMetadata(_user!);
          if (updatedUser != _user) {
            _user = updatedUser;
            await _localDb.saveUser(updatedUser);
            notifyListeners();
          }
        }
      }));

      await _loadRecentUsernames().timeout(const Duration(seconds: 1), onTimeout: () {});
      
      // نبلغ المستمعين بالحالة الأولية (محلياً) قبل فحص الخادم
      notifyListeners();
      
      // فحص الجلسة مع الخادم بمهلة زمنية
      await _checkSavedSession().timeout(
        const Duration(seconds: 7),
        onTimeout: () {
          debugPrint('⚠️ Session check timed out');
          if (_user != null) {
            _updateState(loading: false, status: AuthStatus.authenticated);
          } else {
            _updateState(loading: false, status: AuthStatus.unauthenticated);
          }
        },
      );
      
    } catch (e) {
      debugPrint('❌ AuthProvider.initialize Error: $e');
      _updateState(
        loading: false, 
        status: _user != null ? AuthStatus.authenticated : AuthStatus.unauthenticated
      );
    }
  }
  
  Future<void> _checkSavedSession() async {
    // 🛡️ التحقق الأولي: إذا لم يكن لدينا مستخدم محلي ولا توكن صالح، فنحن غير مسجلين
    if (!PocketBaseClient.instance.pb.authStore.isValid && _user == null) {
      _updateState(status: AuthStatus.unauthenticated, loading: false);
      return;
    }

    try {
      debugPrint('🔐 AuthProvider: Attempting to refresh session with server...');
      final authData = await PocketBaseClient.instance.pb
          .collection('users')
          .authRefresh()
          .timeout(const Duration(seconds: 15));
      
      final user = UserModel.fromJson(authData.record.toJson(), token: authData.token);
      
      // 📝 تحديث البيانات الإضافية عند النجاح
      if (user.verified && user.phone != null) {
        // نغلفها بـ try-catch لضمان عدم تأثر الجلسة إذا فشلت هذه الخدمة الفرعية
        try {
          await _claimService.claimInvitationsByPhone(user.id, user.phone!);
        } catch (e) {
          debugPrint('⚠️ ClaimService error: $e');
        }
      }
      
      await _updateUserLocally(user);
      debugPrint('✅ AuthProvider: Session refreshed and synced successfully.');
    } catch (e) {
      debugPrint('⚠️ AuthProvider: Session refresh encountered an issue: $e');
      
      bool isPermanentError = false;
      bool isNetworkError = false;

      if (e is ClientException) {
        // 401: التوكن منتهي أو غير صالح نهائياً
        // 403: الحساب محظور أو لا يملك صلاحية
        if (e.statusCode == 401 || e.statusCode == 403) {
          isPermanentError = true;
        } else if (e.statusCode == 0) {
          isNetworkError = true;
        }
      } else if (e is TimeoutException) {
        isNetworkError = true;
      }

      if (isPermanentError) {
        debugPrint('🚫 AuthProvider: Permanent Auth Error (401/403). Forcing Logout.');
        // في حال الخطأ الدائم فقط نقوم بتسجيل الخروج
        await logout();
      } else if (isNetworkError) {
        debugPrint('📡 AuthProvider: Network issue during refresh. Keeping local session.');
        // في حال مشكلة الشبكة، نبقي المستخدم مسجلاً بالبيانات المحلية (Offline Mode)
        _updateState(loading: false, status: AuthStatus.authenticated);
      } else {
        // أخطاء أخرى غير متوقعة، نفضل إبقاء المستخدم مسجلاً لضمان "أبدية" الجلسة محلياً
        debugPrint('❓ AuthProvider: Unknown error during refresh. Maintaining current state.');
        _updateState(loading: false);
      }
    }
  }
  
  // ====================== Rate Limiting ======================
  int _authAttempts = 0;
  DateTime? _lastAuthAttempt;
  static const int _maxAuthAttempts = 5;
  static const int _authCooldownSeconds = 60;

  bool _isAuthThrottled() {
    final now = DateTime.now();
    if (_lastAuthAttempt != null) {
      final diff = now.difference(_lastAuthAttempt!).inSeconds;
      if (diff > _authCooldownSeconds) {
        _authAttempts = 0; // Reset after cooldown expires
      }
    }

    if (_authAttempts >= _maxAuthAttempts) {
      final waitTime = _authCooldownSeconds - now.difference(_lastAuthAttempt!).inSeconds;
      if (waitTime > 0) {
        _updateState(error: 'محاولات كثيرة جداً! يرجى الانتظار $waitTime ثانية.');
        return true;
      }
    }
    return false;
  }

  void _recordAuthAttempt() {
    _authAttempts++;
    _lastAuthAttempt = DateTime.now();
  }

  void _resetAuthAttempts() {
    _authAttempts = 0;
    _lastAuthAttempt = null;
  }

  // ====================== تسجيل الدخول ======================
  
  Future<bool> login({required String identifier, required String password}) async {
    if (_isAuthThrottled()) return false;

    final isEmail = identifier.contains('@');
    return _performLogin(() => isEmail 
      ? _authService.loginWithEmail(email: identifier, password: password)
      : _authService.loginWithUsername(username: identifier, password: password)
    );
  }
  
  Future<bool> _performLogin(Future<UserModel> Function() loginFunction) async {
    _updateState(loading: true, clearError: true);
    _recordAuthAttempt();

    try {
      debugPrint('🔌 AuthProvider: Starting login process...');
      final userResult = await loginFunction();
      
      _resetAuthAttempts(); // Success!
      debugPrint('✅ AuthProvider: Server login success. User ID: ${userResult.id}');
      
      // نحدث الحالة والمستخدم محلياً في عملية واحدة
      final userWithToken = (userResult.token == null && _user?.token != null)
          ? userResult.copyWith(token: _user!.token)
          : userResult;
          
      await _updateUserLocally(userWithToken);
      return true;
    } catch (e) {
      debugPrint('❌ AuthProvider: Login failed: $e');
      _updateState(loading: false, error: _parsePbError(e), status: AuthStatus.error);
      return false;
    }
  }
  
  // ====================== تسجيل الخروج ======================
  
  Future<void> logout() async {
    _updateState(loading: true);
    try {
      // 1. Disconnect all realtime BEFORE clearing authStore to prevent 403 errors
      await PocketBaseClient.instance.disconnectRealtime();
      
      _authService.logout();
      await _clearSession();
      await _localDb.clearUser();
      
      // 🔔 Unmap push notification token from this user in OneSignal
      try {
        await OneSignalService.instance.logoutUser();
      } catch (err) {
        debugPrint('⚠️ Error logging out from OneSignal: $err');
      }
      
      // 🔒 Clear secure storage
      await _secureStorage.clearAll();
      
      _updateState(user: null, status: AuthStatus.unauthenticated, loading: false);
    } catch (e) {
      _updateState(user: null, status: AuthStatus.unauthenticated, loading: false, error: 'Logout error: $e');
    }
  }
  
  // ====================== تحديث البيانات ======================
  
  Future<bool> updateUser(Map<String, dynamic> data, {XFile? avatarFile}) async {
    if (!isAuthenticated) return false;
    _updateState(loading: true, clearError: true);
    try {
      final (updatedUser, record) = await _userService.updateCurrentUser(data, avatarFile: avatarFile);
      
      final pb = PocketBaseClient.instance.pb;
      if (pb.authStore.isValid) {
          pb.authStore.save(pb.authStore.token, record);
      }
      
      await _updateUserLocally(updatedUser);
      return true;
    } catch (e) {
      // ... (retry logic omitted for brevity, same as before)
      _updateState(loading: false, error: _parsePbError(e));
      return false;
    }
  }
  
  Future<void> runTrashCleanup(String userId) async {
    final pb = PocketBaseClient.instance.pb;
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30)).toUtc();
    final formattedDate = thirtyDaysAgo.toIso8601String().replaceFirst('T', ' ').split('.').first;

    debugPrint('🗑️ Starting trash cleanup for user $userId (older than $formattedDate)...');

    // 1. Clean up articles in trash
    try {
      final oldArticles = await pb.collection('articles').getFullList(
        filter: 'post_status = "trash" && updated < "$formattedDate" && author = "$userId"',
      );
      for (final article in oldArticles) {
        debugPrint('🗑️ Hard deleting old trashed article: ${article.id}');
        await pb.collection('articles').delete(article.id);
      }
    } catch (e) {
      debugPrint('⚠️ Error cleaning up articles: $e');
    }

    // 2. Clean up invitations in trash
    try {
      final oldInvitations = await pb.collection('invitations').getFullList(
        filter: 'post_status = "trash" && updated < "$formattedDate" && user = "$userId"',
      );
      for (final inv in oldInvitations) {
        debugPrint('🗑️ Hard deleting old trashed invitation: ${inv.id}');
        await pb.collection('invitations').delete(inv.id);
      }
    } catch (e) {
      debugPrint('⚠️ Error cleaning up invitations: $e');
    }
  }

  Future<void> _updateUserLocally(UserModel user) async {
    UserModel userWithToken = (user.token == null && _user?.token != null)
        ? user.copyWith(token: _user!.token)
        : user;
    
    userWithToken = await _attachRoleMetadata(userWithToken);
    
    _user = userWithToken;
    _status = AuthStatus.authenticated;
    _isLoading = false;
    
    // 💾 حفظ في قاعدة البيانات المحلية (Hive)
    await _localDb.saveUser(userWithToken);

    // 🔔 ربط معرف المستخدم في OneSignal لضمان استلام الإشعارات
    try {
      await OneSignalService.instance.loginUser(userWithToken.id);
    } catch (err) {
      debugPrint('⚠️ Error logging in user to OneSignal: $err');
    }

    // 🔒 حفظ التوكن ومعرف المستخدم بشكل آمن (Secure Storage)
    if (userWithToken.token != null) {
      await _secureStorage.saveAuthToken(userWithToken.token!);
      await _secureStorage.saveUserId(userWithToken.id);
      
      // 🔌 مزامنة الجلسة مع PocketBase لضمان عمل العمليات التي تتطلب صلاحية
      final pb = PocketBaseClient.instance.pb;
      if (userWithToken.token != null && (pb.authStore.token != userWithToken.token || pb.authStore.model == null)) {
        try {
          // نحفظ التوكن مع الحفاظ على الـ model الحالي إن وُجد
          pb.authStore.save(userWithToken.token!, pb.authStore.model);
        } catch (_) {}
      }
    }

    if (userWithToken.username != null) {
      await _saveRecentUsername(userWithToken.username!);
    }
    
    // 🔗 فحص رابط الدعوة المحفوظ محلياً
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingToken = prefs.getString('pending_invite_token');
      if (pendingToken != null && pendingToken.isNotEmpty) {
        // حذف التوكن فوراً لمنع أي استدعاء متزامن موازٍ
        await prefs.remove('pending_invite_token');
        debugPrint('🔗 Found pending invitation token: $pendingToken. Attempting to claim...');
        final apptService = PbAppointmentService();
        final success = await apptService.claimAppointmentByToken(pendingToken, user.id);
        if (success) {
          debugPrint('✅ Successfully claimed appointment by token.');
          _hasJustClaimedInvitation = true;
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error claiming invitation: $e');
    }

    // تشغيل تنظيف سلة المحذوفات في الخلفية للمقالات والمواعيد التي مضى عليها أكثر من 30 يوماً
    unawaited(runTrashCleanup(user.id));
    
    notifyListeners();
  }

  // (بقية الدوال المساعدة والـ Register تبقى كما هي ولكن باستخدام _updateState عند الحاجة)
  
  Future<bool> register({
    required String username,
    required String email,
    required String password,
    required String passwordConfirm,
    required String name,
    String? phone,
  }) async {
    if (_isAuthThrottled()) return false;
    _updateState(loading: true, clearError: true);
    _recordAuthAttempt();
    
    try {
      final userResult = await _authService.register(
        username: username,
        email: email,
        password: password,
        passwordConfirm: passwordConfirm,
        name: name,
        phone: phone,
      );
      _resetAuthAttempts();
      await _updateUserLocally(userResult);
      return true;
    } catch (e) {
      _updateState(loading: false, error: _parsePbError(e), status: AuthStatus.error);
      return false;
    }
  }

  Future<bool> requestPasswordReset(String email) async {
    if (_isAuthThrottled()) return false;
    _updateState(loading: true, clearError: true);
    _recordAuthAttempt();
    
    try {
      await _authService.requestPasswordReset(email);
      _resetAuthAttempts();
      _updateState(loading: false);
      return true;
    } catch (e) {
      _updateState(loading: false, error: _parsePbError(e));
      return false;
    }
  }

  Future<bool> changePassword({
    required String oldPassword,
    required String password,
    required String passwordConfirm,
  }) async {
    if (!isAuthenticated) return false;
    _updateState(loading: true, clearError: true);
    try {
      await _authService.changePassword(
        userId: _user!.id,
        oldPassword: oldPassword,
        password: password,
        passwordConfirm: passwordConfirm,
      );
      _updateState(loading: false);
      return true;
    } catch (e) {
      _updateState(loading: false, error: _parsePbError(e));
      return false;
    }
  }

  // ====================== حذف الحساب ======================
  
  Future<bool> deleteAccount({bool performLogout = true, Function(String)? onStepComplete}) async {
    if (_user == null) return false;
    _updateState(loading: true, clearError: true);
    final userId = _user!.id;
    try {
      await _authService.deleteAccount(userId, onStepComplete: onStepComplete);
      if (performLogout) await logout();
      return true;
    } catch (e) {
      debugPrint('🚨 [AuthProvider] Account deletion FAILED for $userId: $e');
      if (e is ClientException) {
        debugPrint('   - Status: ${e.statusCode}');
        debugPrint('   - Response: ${e.response}');
      }
      _updateState(loading: false, error: _parsePbError(e));
      return false;
    }
  }

  Future<void> _clearSession() async {
    // 🧹 تم تنظيف SharedPreferences من البيانات الحساسة.
    // الجلسة الآن تُدار بالكامل عبر LocalDbService المشفر.
  }

  String _parsePbError(dynamic e) {
    if (e is! ClientException) return e.toString();
    final statusCode = e.statusCode;
    final responseData = e.response;
    
    if (statusCode == 400) {
      final errorData = responseData['data'] as Map<String, dynamic>?;
      if (errorData != null) {
        if (errorData.containsKey('username')) return 'اسم المستخدم مأخوذ بالفعل، يرجى اختيار اسم آخر.';
        if (errorData.containsKey('email')) {
           final code = errorData['email']['code'];
           if (code == 'validation_invalid_email' || code == 'validation_is_unique') {
             return 'البريد الإلكتروني مسجل مسبقاً، يرجى استخدام بريد آخر.';
           }
        }
        if (errorData.containsKey('password')) return 'كلمة المرور غير صالحة أو ضعيفة جداً.';
      }
      return 'بيانات غير صالحة، يرجى مراجعة الحقول.';
    }
    
    if (statusCode == 401) {
      final errorData = responseData['data'] as Map<String, dynamic>?;
      if (errorData != null && errorData.containsKey('email') && errorData['email']['code'] == 'validation_is_not_verified') {
         return 'يرجى تأكيد بريدك الإلكتروني أولاً لتتمكن من الدخول.';
      }
      return 'تأكد من صحة البريد الإلكتروني أو كلمة المرور.';
    }
    
    if (statusCode == 403) return 'عذراً، هذا الحساب معطل حالياً من قبل الإدارة.';
    if (statusCode == 429) return 'محاولات كثيرة جداً! يرجى الانتظار قليلاً قبل المحاولة مجدداً.';
    if (statusCode == 0) return 'فشل الاتصال بالخادم، يرجى التأكد من اتصالك بالإنترنت.';
    
    return 'فشل تنفيذ الطلب (رمز الخطأ: $statusCode)';
  }

  Future<void> _loadRecentUsernames() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _recentUsernames = prefs.getStringList(keyRecentUsernames) ?? [];
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _saveRecentUsername(String identifier) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> current = prefs.getStringList(keyRecentUsernames) ?? [];
      
      current.remove(identifier); // Move to top if already exists
      current.insert(0, identifier);
      
      if (current.length > 5) current = current.sublist(0, 5); // Keep last 5
      
      await prefs.setStringList(keyRecentUsernames, current);
      _recentUsernames = current;
      notifyListeners();
    } catch (e) {
      print('Failed to save recent username: $e');
    }
  }

  Future<void> removeRecentUsername(String identifier) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> current = prefs.getStringList(keyRecentUsernames) ?? [];
      
      current.remove(identifier);
      
      await prefs.setStringList(keyRecentUsernames, current);
      _recentUsernames = current;
      notifyListeners();
    } catch (e) {
      print('Failed to remove recent username: $e');
    }
  }

  // ====================== محاكاة حساب المشترك (Impersonation) ======================
  UserModel? _backupAdminUser;
  String? _backupAdminToken;
  bool _isSimulating = false;

  bool get isSimulating => _isSimulating;

  /// تفعيل وضع محاكاة حساب مشترك
  Future<void> simulateUser(UserModel targetUser) async {
    if (_isSimulating) return;
    _backupAdminUser = _user;
    _backupAdminToken = PocketBaseClient.instance.pb.authStore.token;
    _isSimulating = true;

    _user = targetUser;
    
    // محاكاة وتمرير التوكن الفعلي للمشرف العام لكي تقبل القاعدة الطلبات من المشرف
    final pb = PocketBaseClient.instance.pb;
    final userRecord = RecordModel({
      'id': targetUser.id,
      'collectionId': '_pb_users_auth_',
      'collectionName': 'users',
      'data': {
        'username': targetUser.username,
        'email': targetUser.email,
        'name': targetUser.name,
        'role': targetUser.role,
      }
    });
    pb.authStore.save(_backupAdminToken ?? '', userRecord);

    _status = AuthStatus.authenticated;
    notifyListeners();
  }

  /// إنهاء وضع المحاكاة والعودة لحساب المشرف الأصلي
  Future<void> stopSimulation() async {
    if (!_isSimulating) return;
    _isSimulating = false;
    _user = _backupAdminUser;

    final pb = PocketBaseClient.instance.pb;
    if (_backupAdminUser != null && _backupAdminToken != null) {
      final adminRecord = RecordModel({
        'id': _backupAdminUser!.id,
        'collectionId': '_pb_users_auth_',
        'collectionName': 'users',
        'data': {
          'username': _backupAdminUser!.username,
          'email': _backupAdminUser!.email,
          'name': _backupAdminUser!.name,
          'role': _backupAdminUser!.role,
        }
      });
      pb.authStore.save(_backupAdminToken!, adminRecord);
    }

    _backupAdminUser = null;
    _backupAdminToken = null;
    _status = AuthStatus.authenticated;
    notifyListeners();
  }

  /// 🛡️ فحص صلاحية التوكن محلياً عبر فك تشفير JWT
  bool _isTokenExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      
      final payload = parts[1];
      final normalized = base64.normalize(payload);
      final resp = utf8.decode(base64.decode(normalized));
      final payloadMap = json.decode(resp);
      
      if (payloadMap is Map<String, dynamic> && payloadMap.containsKey('exp')) {
        final exp = payloadMap['exp'] as int;
        final expiryDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
        return DateTime.now().isAfter(expiryDate);
      }
    } catch (e) {
      debugPrint('❌ Error checking token expiration: $e');
    }
    return true; // في حال الخطأ نعتبره منتهياً لزيادة الأمان
  }

  Future<UserModel> _attachRoleMetadata(UserModel user) async {
    try {
      final cachedRoles = await _roleService.getCachedUserRoles();
      if (cachedRoles.isNotEmpty) {
        final matchingRole = cachedRoles.firstWhere(
          (r) => r.key == user.role,
          orElse: () => getDefaultRoleMetadata(user.role),
        );
        return user.copyWith(roleMetadata: matchingRole);
      }
    } catch (_) {}
    return user;
  }

  // ====================== إدارة أصناف وصلاحيات المستخدمين ======================

  /// تقديم طلب ترقية الحساب
  Future<bool> requestRoleUpgrade(String requestedRole, String userNotes) async {
    if (_user == null) return false;
    _updateState(loading: true);
    try {
      await _roleService.createUpgradeRequest(
        userId: _user!.id,
        requestedRole: requestedRole,
        userNotes: userNotes,
      );
      _updateState(loading: false);
      return true;
    } catch (e) {
      _updateState(loading: false, error: e.toString());
      return false;
    }
  }

  /// جلب طلبات الترقية الخاصة بي
  Future<List<RecordModel>> getMyUpgradeRequests() async {
    if (_user == null) return [];
    try {
      return await _roleService.fetchMyUpgradeRequests(_user!.id);
    } catch (_) {
      return [];
    }
  }

  /// للمشرفين: جلب كافة الطلبات المعلقة لمراجعتها
  Future<List<RecordModel>> getPendingUpgradeRequests() async {
    if (_user == null || _user!.role != 'admin') return [];
    try {
      return await _roleService.fetchPendingUpgradeRequests();
    } catch (_) {
      return [];
    }
  }

  /// للمشرفين: قبول طلب الترقية وتعديل رول المستخدم
  Future<bool> approveUpgrade(String requestId, String targetUserId, String requestedRole, String adminNotes) async {
    if (_user == null || _user!.role != 'admin') return false;
    _updateState(loading: true);
    try {
      await _roleService.approveUpgradeRequest(
        requestId: requestId,
        targetUserId: targetUserId,
        requestedRole: requestedRole,
        adminId: _user!.id,
        adminNotes: adminNotes,
      );
      // تحديث قائمة الأدوار المتاحة وعكسها محلياً إذا كان المستخدم المستهدف هو الحالي
      if (_user!.id == targetUserId) {
        final refreshedUser = _user!.copyWith(role: requestedRole);
        await _updateUserLocally(refreshedUser);
      }
      _updateState(loading: false);
      return true;
    } catch (e) {
      _updateState(loading: false, error: e.toString());
      return false;
    }
  }

  /// للمشرفين: رفض طلب ترقية
  Future<bool> rejectUpgrade(String requestId, String adminNotes) async {
    if (_user == null || _user!.role != 'admin') return false;
    _updateState(loading: true);
    try {
      await _roleService.rejectUpgradeRequest(
        requestId: requestId,
        adminId: _user!.id,
        adminNotes: adminNotes,
      );
      _updateState(loading: false);
      return true;
    } catch (e) {
      _updateState(loading: false, error: e.toString());
      return false;
    }
  }
}