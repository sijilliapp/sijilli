// 📍 lib/features/auth/providers/auth_provider.dart
// 🔐 إدارة حالة المصادقة في التطبيق

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/pocketbase_client.dart';
import '../services/pb_auth_service.dart';
import '../../settings/services/pb_user_service.dart';
import '../../../core/local/local_db_service.dart';
import '../../../models/user.dart';
import 'package:pocketbase/pocketbase.dart';

enum AuthStatus {
  initial,      // الحالة الأولية
  loading,      // جاري التحميل
  authenticated, // مسجل الدخول
  unauthenticated, // غير مسجل
  error,        // خطأ
}

class AuthProvider extends ChangeNotifier {
  // ====================== الحالة ======================
  AuthStatus _status = AuthStatus.initial;
  UserModel? _user;
  String? _errorMessage;
  bool _isLoading = false;
  
  // ====================== Recent Usernames ======================
  static const String keyRecentUsernames = 'recent_usernames';
  List<String> _recentUsernames = [];
  List<String> get recentUsernames => _recentUsernames;
  
  // ====================== الخدمات ======================
  final PbAuthService _authService = PbAuthService();
  final PbUserService _userService = PbUserService();
  final LocalDbService _localDb = LocalDbService.instance;
  
  // ====================== Getters ======================
  AuthStatus get status => _status;
  UserModel? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _status == AuthStatus.authenticated && _user != null;
  bool get isUnauthenticated => _status == AuthStatus.unauthenticated;
  
  // ====================== التهيئة ======================
  
  /// تهيئة المصادقة - فحص الجلسة المحلية أولاً ثم السحابية
  Future<void> initialize() async {
    _setStatus(AuthStatus.loading);
    
    try {
      // 1. محاولة استرجاع البيانات من قاعدة البيانات المحلية (سريع جداً)
      final localUser = await _localDb.getUser();
      if (localUser != null) {
        _user = localUser;
        _setStatus(AuthStatus.authenticated);
      }

      // Load recent usernames
      await _loadRecentUsernames();

      // 2. تهيئة PocketBase (تتم الآن في main.dart)
      
      // إذا وجدنا مستخدم محلي، نقوم بتحميل التوكن إلى PocketBase
      if (_user != null && _user!.token != null) {
        // تحميل التوكن للمزامنة السحابية
        try {
           final pb = PocketBaseClient.instance.pb;
           // نكتفي بشحن التوكن حالياً لضمان صلاحية الطلبات، وسيتم تحديث الموديل في الخطوة التالية
           pb.authStore.save(_user!.token!, null); 
           debugPrint('✅ AuthProvider: Restored local token to PocketBase AuthStore');
        } catch (e) {
           debugPrint('⚠️ Failed to restore cloud session: $e');
        }
      }
      
      // 3. فحص الجلسة مع الخادم (في الخلفية أو إذا لم يوجد بيانات محلية)
      await _checkSavedSession();
      
    } catch (e) {
      // في حال الخطأ، إذا كان لدينا بيانات محلية، نبقي المستخدم مسجل الدخول
      if (_user == null) {
        _setError('خطأ في تهيئة التطبيق: $e');
      }
    }
  }
  
  /// فحص الجلسة المحفوظة وتحديث البيانات
  Future<void> _checkSavedSession() async {
    // إذا لم يكن لدينا اتصال (توكن)، لا داعي للمحاولة
    if (!PocketBaseClient.instance.pb.authStore.isValid && _user == null) {
      _setStatus(AuthStatus.unauthenticated);
      return;
    }

    try {
      // محاولة تحديث التوكن إذا كان لدينا اتصال
      // حتى لو كان التوكن منتهي الصلاحية، refreshAuth قد تنجح إذا كان لا يزال ضمن فترة السماح
      // أو ستفشل ونقوم بتسجيل الخروج
      // Final check with server (refresh)
      // PB Client handles refresh
      final authData = await PocketBaseClient.instance.pb.collection('users').authRefresh();
      final user = UserModel.fromJson(authData.record!.toJson(), token: authData.token);
      await _updateUserLocally(user);
      debugPrint('✅ AuthProvider: Session refreshed successfully');
    } catch (e) {
      debugPrint('⚠️ Session refresh failed: $e');
      
      // المميز هنا: إذا فشل التحديث بسبب انقطاع الإنترنت (0) أو توقف الخادم (5xx)،
      // لا نقوم بتسجيل الخروج! بل نبقي الجلسة المحلية تعمل حالياً.
      
      bool isPermanentError = false;
      if (e is ClientException) {
         if (e.statusCode == 401 || e.statusCode == 403) {
            isPermanentError = true;
         }
      }

      if (isPermanentError) {
         debugPrint('❌ Token invalid/expired permanently, logging out...');
         await logout(); 
      } else {
        // خطأ مؤقت (شبكة/خادم)، نبقي البيانات المحلية ولا نغير الحالة لـ unauthenticated
        debugPrint('ℹ️ Keeping local session active despite temporary refresh error');
      }
    }
  }
  
  // ====================== تسجيل الدخول ======================
  
  /// تسجيل الدخول بالبريد الإلكتروني
  Future<bool> loginWithEmail({
    required String email,
    required String password,
  }) async {
    if (_isLoading) return false;
    return _performLogin(() async {
      return await _authService.loginWithEmail(
        email: email,
        password: password,
      );
    });
  }
  
  /// تسجيل الدخول باسم المستخدم
  Future<bool> loginWithUsername({
    required String username,
    required String password,
  }) async {
    if (_isLoading) return false;
    return _performLogin(() async {
      return await _authService.loginWithUsername(
        username: username,
        password: password,
      );
    });
  }
  
  /// تسجيل الدخول التلقائي (بريد أو اسم مستخدم)
  Future<bool> login({
    required String identifier, // بريد أو اسم مستخدم
    required String password,
  }) async {
    if (_isLoading) return false;
    // تحديد نوع المعرف
    final isEmail = identifier.contains('@');
    
    if (isEmail) {
      return await loginWithEmail(email: identifier, password: password);
    } else {
      return await loginWithUsername(username: identifier, password: password);
    }
  }
  
  /// دالة مساعدة لتنفيذ تسجيل الدخول
  Future<bool> _performLogin(Future<UserModel> Function() loginFunction) async {
    _setLoading(true);
    _clearError();
    
    try {
      final user = await loginFunction();
      await _updateUserLocally(user);
      
      // Save recent username
      await _saveRecentUsername(user.username ?? user.email ?? '');
      
      return true;
    } catch (e) {
      String message = 'Unknown error occurred';
      
      if (e is ClientException) {
        final statusCode = e.statusCode;
        final responseData = e.response;
        
        if (statusCode == 400 || statusCode == 401) {
          message = 'Invalid credentials. Please check your email/username and password.';
          // التحقق من حالات خاصة في البيانات الراجعة
          final errorData = responseData['data'] as Map<String, dynamic>?;
          if (errorData != null) {
             if (errorData.containsKey('email') && errorData['email']['code'] == 'validation_is_not_verified') {
               message = 'Please verify your email first to be able to login.';
             }
          }
        } else if (statusCode == 403) {
          message = 'Sorry, this account is currently disabled.';
        } else if (statusCode == 429) {
          message = 'Too many failed attempts! Please wait a while.';
        } else if (statusCode == 0) {
          message = 'Failed to connect to server. Please check your internet.';
        }
      } else {
        message = 'Unknown error: ${e.toString()}';
      }
      
      _setError(message);
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // ====================== التسجيل ======================
  
  /// إنشاء حساب جديد
  Future<bool> register({
    required String username,
    required String email,
    required String password,
    required String passwordConfirm,
    required String name,
    String? phone,
  }) async {
    _setLoading(true);
    _clearError();
    
    try {
      final user = await _authService.register(
        username: username,
        email: email,
        password: password,
        passwordConfirm: passwordConfirm,
        name: name,
        phone: phone,
      );
      
      await _updateUserLocally(user);
      
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // ====================== تسجيل الخروج ======================
  
  /// تسجيل الخروج
  Future<void> logout() async {
    _setLoading(true);
    debugPrint('🚪 AuthProvider: performing logout...');
    
    try {
      try {
        _authService.logout();
        debugPrint('✅ AuthService logout done');
      } catch (e) {
        debugPrint('⚠️ AuthService logout failed: $e');
      }
      
      try {
        await _clearSession();
        debugPrint('✅ Session cleared');
      } catch (e) {
        debugPrint('⚠️ Clear session failed: $e');
      }
      
      try {
        await _localDb.clearUser();
         debugPrint('✅ Local DB cleared');
      } catch (e) {
        debugPrint('⚠️ Local DB clear failed: $e');
      }
      
      _setUser(null);
      _setStatus(AuthStatus.unauthenticated);
      debugPrint('✅ AuthStatus set to unauthenticated');
      
    } catch (e) {
      debugPrint('❌ Logout critical error: $e');
      _setError('Logout error: $e');
      // Force unauthenticated even on error to prevent being stuck
      _setUser(null);
      _setStatus(AuthStatus.unauthenticated);
    } finally {
      _setLoading(false);
    }
  }
  
  // ====================== إعادة تعيين كلمة المرور ======================
  
  /// إرسال رابط إعادة تعيين كلمة المرور
  Future<bool> requestPasswordReset(String email) async {
    _setLoading(true);
    _clearError();
    
    try {
      await _authService.requestPasswordReset(email);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // ====================== تحديث البيانات ======================
  
  /// تحديث بيانات المستخدم
  Future<bool> updateUser(Map<String, dynamic> data, {String? avatarPath}) async {
    // إذا كنت غير متصل وحاولت التحديث، يمكنك تنفيذ حفظ محلي "تفاؤلي"
    // ولكن حالياً سنطلب الاتصال
    // TODO: Implement optimistic UI updates properly queueing requests
    
    if (!isAuthenticated) return false;
    
    _setLoading(true);
    _clearError();
    
    try {
      final updatedUser = await _userService.updateCurrentUser(data, avatarPath: avatarPath);
      await _updateUserLocally(updatedUser);
      return true;
    } catch (e) {
      // إذا كان الخطأ بسبب انتهاء التوكن (401/403)
      bool isAuthError = false;
      if (e is ClientException) {
         if (e.statusCode == 401 || e.statusCode == 403) {
            isAuthError = true;
         }
      }
      
      if (isAuthError) {
        
        print('🔄 Token expired during update, attempting refresh...');
        try {
          // محاولة تحديث التوكن
          final authData = await PocketBaseClient.instance.pb.collection('users').authRefresh();
          final refreshedUser = UserModel.fromJson(authData.record!.toJson(), token: authData.token);
          
          // إعادة المحاولة بالتوكن الجديد
          final retryUserResult = await _userService.updateCurrentUser(data, avatarPath: avatarPath);
          // دمج البيانات الجديدة مع التوكن الجديد
          final finalUser = retryUserResult.copyWith(token: authData.token);
          
          await _updateUserLocally(finalUser);
          return true;
        } catch (retryError) {
          print('❌ Refresh failed or retry failed: $retryError');
          
          // فقط إذا كان الخطأ هو عدم صلاحية التوكن (401/403) نقوم بتسجيل الخروج
          bool isRetryAuthError = false;
          if (retryError is ClientException) {
             if (retryError.statusCode == 401 || retryError.statusCode == 403) {
                isRetryAuthError = true;
             }
          }
          
          if (isRetryAuthError) {
            await logout();
            _setError('Please login again (session expired).');
          } else {
             _setError('Update failed: $retryError');
          }
          return false;
        }
      }
      
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // ====================== التحقق من البيانات ======================
  
  /// التحقق من توفر اسم المستخدم
  Future<bool> isUsernameAvailable(String username) async {
    try {
      return await _authService.isUsernameAvailable(username);
    } catch (e) {
      return false;
    }
  }
  
  /// التحقق من توفر البريد الإلكتروني
  Future<bool> isEmailAvailable(String email) async {
    try {
      return await _authService.isEmailAvailable(email);
    } catch (e) {
      return false;
    }
  }
  
  // ====================== إدارة الجلسة ======================
  
  Future<void> _updateUserLocally(UserModel user) async {
    // 🔑 الحفاظ على التوكن القديم إذا كان الجديد فارغاً (يحدث عند التحديث العادي للبيانات)
    final userWithToken = (user.token == null && _user?.token != null)
        ? user.copyWith(token: _user!.token)
        : user;

    _setUser(userWithToken);
    _setStatus(AuthStatus.authenticated);
    // الحفظ في قاعدة البيانات المحلية (Isar)
    await _localDb.saveUser(userWithToken);
  }
  
  /// حفظ معلومات الجلسة (قديم - لم نعد بحاجة له مع Isar لكن نتركه احتياطاً)
  Future<void> _saveSession() async {
    // تم استبداله بـ _localDb.saveUser(user)
  }
  
  /// مسح معلومات الجلسة المحلية
  Future<void> _clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_id');
      await prefs.remove('user_data');
    } catch (e) {
      print('❌ خطأ في مسح الجلسة: $e');
    }
  }
  
  // ====================== إدارة الحالة ======================
  
  void _setStatus(AuthStatus status) {
    _status = status;
    notifyListeners();
  }
  
  void _setUser(UserModel? user) {
    _user = user;
    notifyListeners();
  }
  
  void _setError(String error) {
    _errorMessage = error;
    _status = AuthStatus.error;
    notifyListeners();
  }
  
  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }
  
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  // ====================== حذف الحساب ======================

  /// حذف الحساب نهائياً
  Future<bool> deleteAccount({bool performLogout = true}) async {
    if (_user == null) return false;
    
    _setLoading(true);
    _clearError();
    
    final userId = _user!.id; // Capture ID before potential logout side effects
    debugPrint('🗑️ Attempting to delete user account: $userId');
    
    try {
      debugPrint('🗑️ Calling PocketBase delete service...');
      await _authService.deleteAccount(userId);
      debugPrint('✅ PocketBase delete successful (no exception thrown)');
      
      if (performLogout) {
        debugPrint('🗑️ Performing logout...');
        await logout(); // تسجيل الخروج ومسح البيانات
      }
      
      return true;
    } catch (e) {
      debugPrint('❌ DELETE ACCOUNT FAILED: $e');
      _setError('فشل حذف الحساب: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ====================== Recent Usernames Logic ======================
  
  Future<void> _loadRecentUsernames() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _recentUsernames = prefs.getStringList(keyRecentUsernames) ?? [];
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ Error loading recent usernames: $e');
    }
  }

  Future<void> _saveRecentUsername(String identifier) async {
    if (identifier.trim().isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> current = prefs.getStringList(keyRecentUsernames) ?? [];
      current.remove(identifier);
      current.insert(0, identifier);
      if (current.length > 5) current = current.sublist(0, 5);
      await prefs.setStringList(keyRecentUsernames, current);
      _recentUsernames = current;
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ Error saving recent username: $e');
    }
  }

  // ====================== التنظيف ======================
  
  @override
  void dispose() {
    super.dispose();
  }
}