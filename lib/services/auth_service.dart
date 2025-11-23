import 'dart:convert';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';
import '../models/user_model.dart';

class AuthService {
  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final PocketBase _pb = PocketBase(AppConstants.pocketbaseUrl);
  UserModel? _currentUser;
  bool _needsSync = false; // Flag to track if data needs syncing

  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get needsSync => _needsSync;

  // Initialize and check saved session (Local-First)
  Future<bool> initAuth({bool forceRefresh = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(AppConstants.authTokenKey);
      final userData = prefs.getString(AppConstants.userDataKey);
      final lastSync = prefs.getInt('last_sync_timestamp') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      // Load local data first (Local-First approach)
      if (token != null && userData != null && !forceRefresh) {
        _currentUser = UserModel.fromJson(jsonDecode(userData));
        // Create a RecordModel from user data for authStore
        final userJson = jsonDecode(userData);
        final recordModel = RecordModel.fromJson(userJson);
        _pb.authStore.save(token, recordModel);
        print('📱 تم تحميل البيانات من الذاكرة المحلية');
        print('👤 المستخدم في authStore: ${_pb.authStore.model?.id}');

        // Check if we need to sync (every 5 minutes or on force refresh)
        final syncInterval = 5 * 60 * 1000; // 5 minutes
        if (now - lastSync > syncInterval || forceRefresh) {
          // Try background sync without blocking the UI
          _backgroundSync();
        }

        return true;
      }

      // No local data, try network
      if (token != null && userData != null) {
        _currentUser = UserModel.fromJson(jsonDecode(userData));
        // Create a RecordModel from user data for authStore
        final userJson = jsonDecode(userData);
        final recordModel = RecordModel.fromJson(userJson);
        _pb.authStore.save(token, recordModel);

        try {
          print('🌐 محاولة المزامنة مع الخادم');
          final authData = await _pb
              .collection(AppConstants.usersCollection)
              .authRefresh();
          _currentUser = UserModel.fromJson(authData.record.toJson());
          await _saveSession(authData.token, _currentUser!);
          await _updateLastSync();
          print('✅ تم المزامنة بنجاح');
          return true;
        } catch (e) {
          print('❌ فشلت المزامنة: $e');
          // Try to use cached data
          _currentUser = UserModel.fromJson(jsonDecode(userData));
          _needsSync = true;
          print('💾 استخدام البيانات المحفوظة - مطلوب مزامنة');
          return true;
                  // Token expired or invalid, clear session
          await clearSession();
          return false;
        }
      }
      return false;
    } catch (e) {
      print('❌ خطأ في initAuth: $e');
      return false;
    }
  }

  // Register new user
  Future<UserModel> register({
    required String email,
    required String username,
    required String name,
    required String password,
    required String passwordConfirm,
  }) async {
    try {
      final body = {
        'email': email.toLowerCase(),
        'username': username.toLowerCase(),
        'name': name,
        'password': password,
        'passwordConfirm': passwordConfirm,
        // إضافة القيم الافتراضية للمشتركين الجدد
        'role': 'user', // الخطة الافتراضية: user
        'isPublic': true, // الحساب عام افتراضياً
      };

      final record = await _pb
          .collection(AppConstants.usersCollection)
          .create(body: body);

      // Auto login after registration
      final authData = await _pb
          .collection(AppConstants.usersCollection)
          .authWithPassword(email.toLowerCase(), password);

      _currentUser = UserModel.fromJson(authData.record.toJson());
      await _saveSession(authData.token, _currentUser!);

      return _currentUser!;
    } catch (e) {
      throw _handleError(e);
    }
  }

  // Login with email/username and password
  Future<UserModel> login(String identity, String password) async {
    try {
      print('🔄 محاولة تسجيل الدخول: $identity');

      // Normalize identity (email or username) to lowercase
      final normalizedIdentity = identity.toLowerCase();

      final authData = await _pb
          .collection(AppConstants.usersCollection)
          .authWithPassword(normalizedIdentity, password);

      print('✅ تم تسجيل الدخول بنجاح');
      print('📊 بيانات المستخدم: ${authData.record.toJson()}');

      _currentUser = UserModel.fromJson(authData.record.toJson());
      await _saveSession(authData.token, _currentUser!);

      return _currentUser!;
    } catch (e) {
      print('❌ خطأ في تسجيل الدخول: $e');
      if (e is ClientException) {
        print('🔍 تفاصيل الخطأ: ${e.response}');
      }
      throw _handleError(e);
    }
  }

  // Request password reset
  Future<void> requestPasswordReset(String email) async {
    try {
      await _pb
          .collection(AppConstants.usersCollection)
          .requestPasswordReset(email.toLowerCase());
    } catch (e) {
      throw _handleError(e);
    }
  }

  // Update current user data locally (without network call)
  void updateUserLocally(UserModel updatedUser) {
    _currentUser = updatedUser;
    _needsSync = true;
    _saveUserDataLocally(updatedUser);
    print('📱 تم تحديث البيانات محلياً - مطلوب مزامنة');
  }

  // Force sync with server
  Future<bool> forceSyncWithServer() async {
    if (!isAuthenticated) return false;

    try {
      print('🔄 بدء مزامنة إجبارية مع الخادم');
      final userData = await _pb
          .collection(AppConstants.usersCollection)
          .getOne(_currentUser!.id);

      final updatedUser = UserModel.fromJson(userData.toJson());
      _currentUser = updatedUser;
      _needsSync = false;

      await _saveUserDataLocally(updatedUser);
      await _updateLastSync();

      print('✅ تمت المزامنة بنجاح');
      return true;
    } catch (e) {
      print('❌ فشلت المزامنة: $e');
      return false;
    }
  }

  // Background sync (non-blocking)
  Future<void> _backgroundSync() async {
    if (!isAuthenticated) return;

    try {
      print('🔄 مزامنة خلفية مع الخادم');
      final userData = await _pb
          .collection(AppConstants.usersCollection)
          .getOne(_currentUser!.id);

      final serverUser = UserModel.fromJson(userData.toJson());

      // Only update if server data is different
      if (_isUserDataDifferent(_currentUser!, serverUser)) {
        _currentUser = serverUser;
        await _saveUserDataLocally(serverUser);
        print('🔄 تم تحديث البيانات من الخادم');
      }

      _needsSync = false;
      await _updateLastSync();
    } catch (e) {
      print('❌ فشلت المزامنة الخلفية: $e');
      _needsSync = true;
    }
  }

  // Check if user data is different
  bool _isUserDataDifferent(UserModel local, UserModel server) {
    return local.name != server.name ||
        local.avatar != server.avatar ||
        local.phone != server.phone ||
        local.socialLink != server.socialLink ||
        local.bio != server.bio ||
        local.joiningDate != server.joiningDate ||
        local.hijriAdjustment != server.hijriAdjustment;
  }

  // Save user data locally only
  Future<void> _saveUserDataLocally(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.userDataKey, jsonEncode(user.toJson()));
  }

  // Update last sync timestamp
  Future<void> _updateLastSync() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      'last_sync_timestamp',
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  // Update current user with server data (for editing operations)
  Future<UserModel> updateUser({
    String? name,
    String? phone,
    String? socialLink,
    String? bio,
    int? hijriAdjustment,
    dynamic avatar,
  }) async {
    try {
      if (!isAuthenticated) {
        throw 'المستخدم غير مسجل الدخول';
      }

      print('🔄 تحديث بيانات المستخدم على الخادم');

      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (phone != null) body['phone'] = phone;
      if (socialLink != null) body['social_link'] = socialLink;
      if (bio != null) body['bio'] = bio;
      if (hijriAdjustment != null) body['hijri_adjustment'] = hijriAdjustment;

      RecordModel record;

      if (avatar != null) {
        // Upload with both body data and file
        print('📤 رفع الصورة مع البيانات');
        record = await _pb
            .collection(AppConstants.usersCollection)
            .update(_currentUser!.id, body: body, files: [avatar]);
      } else {
        // Update only body data
        print('📝 تحديث البيانات فقط');
        record = await _pb
            .collection(AppConstants.usersCollection)
            .update(_currentUser!.id, body: body);
      }

      final updatedUser = UserModel.fromJson(record.toJson());
      _currentUser = updatedUser;
      _needsSync = false;

      // Save updated data locally
      await _saveUserDataLocally(updatedUser);
      await _updateLastSync();

      print('✅ تم تحديث البيانات بنجاح');
      return updatedUser;
    } catch (e) {
      print('❌ خطأ في تحديث البيانات: $e');
      if (e is ClientException) {
        print('🔍 تفاصيل الخطأ: ${e.response}');
      }
      throw _handleError(e);
    }
  }

  // Login with saved user data (for user switching)
  Future<void> loginWithSavedData(Map<String, dynamic> userData) async {
    try {
      // استخراج بيانات تسجيل الدخول
      final username = userData['username'] as String?;
      final email = userData['email'] as String?;
      
      if (username == null && email == null) {
        throw Exception('بيانات المستخدم غير مكتملة');
      }

      // محاولة تسجيل الدخول باستخدام البيانات المحفوظة
      // ملاحظة: هذا يتطلب كلمة المرور، لذا سنستخدم البيانات المحفوظة مباشرة
      _currentUser = UserModel.fromJson(userData);
      
      // حفظ الجلسة الجديدة
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.userDataKey, jsonEncode(userData));
      
      print('✅ تم التبديل إلى المستخدم: ${_currentUser!.name}');
    } catch (e) {
      print('❌ خطأ في تسجيل الدخول بالبيانات المحفوظة: $e');
      throw e;
    }
  }

  // Logout
  Future<void> logout() async {
    _pb.authStore.clear();
    await clearSession();
    _currentUser = null;
    _needsSync = false;
  }

  // Save session to local storage
  Future<void> _saveSession(String token, UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.authTokenKey, token);
    await prefs.setString(AppConstants.userDataKey, jsonEncode(user.toJson()));
  }

  // Clear session from local storage
  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.authTokenKey);
    await prefs.remove(AppConstants.userDataKey);
    await prefs.remove('last_sync_timestamp');
  }

  // Handle errors
  String _handleError(dynamic error) {
    if (error is ClientException) {
      if (error.statusCode == 400) {
        // Check if it's a validation error or authentication error
        final response = error.response;
        if (response['data'] != null) {
          final data = response['data'] as Map<String, dynamic>;

          // Username already exists
          if (data['username'] != null) {
            return 'اسم المستخدم موجود بالفعل، الرجاء اختيار اسم آخر';
          }

          // Email already exists
          if (data['email'] != null) {
            return 'البريد الإلكتروني موجود بالفعل، الرجاء استخدام بريد آخر أو تسجيل الدخول';
          }

          // Password confirmation doesn't match
          if (data['passwordConfirm'] != null) {
            return 'كلمة المرور وتأكيد كلمة المرور غير متطابقين';
          }

          // Avatar/file upload errors
          if (data['avatar'] != null) {
            return 'خطأ في رفع الصورة، تأكد من حجم ونوع الملف';
          }
        }

        return 'البريد الإلكتروني أو اسم المستخدم أو كلمة المرور غير صحيحة';
      } else if (error.statusCode == 404) {
        return 'المستخدم غير موجود';
      } else if (error.statusCode == 413) {
        return 'حجم الصورة كبير جدا، الرجاء اختيار صورة أصغر';
      } else if (error.statusCode == 0) {
        return 'لا يوجد اتصال بالإنترنت';
      }
      return error.response['message'] ?? 'حدث خطأ غير متوقع';
    }
    return 'حدث خطأ غير متوقع';
  }

  // Get PocketBase instance for other services
  PocketBase get pb => _pb;
}
