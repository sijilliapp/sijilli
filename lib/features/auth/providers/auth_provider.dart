// 📍 lib/features/auth/providers/auth_provider.dart
// 🔐 إدارة حالة المصادقة في التطبيق

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
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
      // 1. استرجاع البيانات المحلية (سريع جداً)
      final localUser = await _localDb.getUser();
      if (localUser != null) {
        _user = localUser;
        _setStatus(AuthStatus.authenticated);
      }

      await _loadRecentUsernames();

      // 2. استعادة التوكن في PocketBase AuthStore
      if (_user != null && _user!.token != null) {
        try {
          PocketBaseClient.instance.pb.authStore.save(_user!.token!, null);
        } catch (_) {}
      }
      
      // 3. فحص الجلسة مع الخادم (مع timeout)
      await _checkSavedSession();
      
    } catch (e) {
      // أي خطأ غير متوقع: لا نترك التطبيق في حالة loading
      if (_user != null) {
        _setStatus(AuthStatus.authenticated);
      } else {
        _setStatus(AuthStatus.unauthenticated);
      }
    }
  }
  
  /// فحص الجلسة المحفوظة وتحديث البيانات
  Future<void> _checkSavedSession() async {
    if (!PocketBaseClient.instance.pb.authStore.isValid && _user == null) {
      _setStatus(AuthStatus.unauthenticated);
      return;
    }

    try {
      final authData = await PocketBaseClient.instance.pb
          .collection('users')
          .authRefresh()
          .timeout(const Duration(seconds: 10));
      final user = UserModel.fromJson(authData.record.toJson(), token: authData.token);
      await _updateUserLocally(user);
    } catch (e) {
      // أخطاء الشبكة أو الـ timeout: نحتفظ بالجلسة المحلية
      bool isPermanentError = false;
      if (e is ClientException) {
        if (e.statusCode == 401 || e.statusCode == 403) {
          isPermanentError = true;
        }
      }

      if (isPermanentError) {
        // التوكن منتهي الصلاحية نهائياً
        await logout();
      }
      // أخطاء الشبكة: نبقى على الحالة المحلية (authenticated إذا كان هناك مستخدم محلي)
    }
  }
  
  // ====================== تسجيل الدخول ======================
  
  Future<bool> loginWithEmail({required String email, required String password}) async {
    return _performLogin(() => _authService.loginWithEmail(email: email, password: password));
  }
  
  Future<bool> loginWithUsername({required String username, required String password}) async {
    return _performLogin(() => _authService.loginWithUsername(username: username, password: password));
  }
  
  Future<bool> login({required String identifier, required String password}) async {
    final isEmail = identifier.contains('@');
    if (isEmail) {
      return await loginWithEmail(email: identifier, password: password);
    } else {
      return await loginWithUsername(username: identifier, password: password);
    }
  }
  
  Future<bool> _performLogin(Future<UserModel> Function() loginFunction) async {
    _setLoading(true);
    _clearError();
    try {
      final user = await loginFunction();
      await _updateUserLocally(user);
      await _saveRecentUsername(user.username ?? user.email ?? '');
      return true;
    } catch (e) {
      _setError(_parsePbError(e));
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // ====================== التسجيل ======================
  
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
      _setError(_parsePbError(e));
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // ====================== تسجيل الخروج ======================
  
  Future<void> logout() async {
    _setLoading(true);
    try {
      _authService.logout();
      await _clearSession();
      await _localDb.clearUser();
      _setUser(null);
      _setStatus(AuthStatus.unauthenticated);
    } catch (e) {
      _setError('Logout error: $e');
      _setUser(null);
      _setStatus(AuthStatus.unauthenticated);
    } finally {
      _setLoading(false);
    }
  }
  
  Future<void> _clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_id');
      await prefs.remove('user_data');
    } catch (e) {
      print('❌ Error clearing session: $e');
    }
  }

  // ====================== إعادة تعيين كلمة المرور ======================
  
  Future<bool> requestPasswordReset(String email) async {
    _setLoading(true);
    _clearError();
    try {
      await _authService.requestPasswordReset(email);
      return true;
    } catch (e) {
      _setError(_parsePbError(e));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ====================== تحديث البيانات ======================
  
  Future<bool> updateUser(Map<String, dynamic> data, {XFile? avatarFile}) async {
    if (!isAuthenticated) return false;
    _setLoading(true);
    _clearError();
    try {
      final updatedUser = await _userService.updateCurrentUser(data, avatarFile: avatarFile);
      
      // 🔄 Sync AuthStore with new record to prevent session mismatch (403 in Realtime)
      final pb = PocketBaseClient.instance.pb;
      if (pb.authStore.isValid) {
         // This is important because updating the user model locally isn't enough,
         // the client's internal AuthStore must also reflect the new data.
         final Map<String, dynamic> rawJson = updatedUser.toJson();
         rawJson['collectionId'] = '_pb_users_auth_';
         rawJson['collectionName'] = 'users';
         pb.authStore.save(pb.authStore.token, RecordModel.fromJson(rawJson));
      }
      
      await _updateUserLocally(updatedUser);
      return true;
    } catch (e) {
      if (e is ClientException && (e.statusCode == 401 || e.statusCode == 403)) {
        try {
          final authData = await PocketBaseClient.instance.pb.collection('users').authRefresh();
          final retryUserResult = await _userService.updateCurrentUser(data, avatarFile: avatarFile);
          final finalUser = retryUserResult.copyWith(token: authData.token);
          
          await _updateUserLocally(finalUser);
          return true;
        } catch (retryError) {
          if (retryError is ClientException && (retryError.statusCode == 401 || retryError.statusCode == 403)) {
            await logout();
            _setError('انتهت الجلسة، يرجى تسجيل الدخول مجدداً.');
          } else {
            _setError(_parsePbError(retryError));
          }
          return false;
        }
      }
      _setError(_parsePbError(e));
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // ====================== إدارة الجلسة ======================
  
  Future<void> _updateUserLocally(UserModel user) async {
    final userWithToken = (user.token == null && _user?.token != null)
        ? user.copyWith(token: _user!.token)
        : user;
    _setUser(userWithToken);
    _setStatus(AuthStatus.authenticated);
    await _localDb.saveUser(userWithToken);
  }
  
  // ====================== حذف الحساب ======================

  Future<bool> deleteAccount({bool performLogout = true}) async {
    if (_user == null) return false;
    _setLoading(true);
    _clearError();
    final userId = _user!.id;
    try {
      await _authService.deleteAccount(userId);
      if (performLogout) await logout();
      return true;
    } catch (e) {
      _setError(_parsePbError(e));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ====================== Recent Usernames ======================
  
  Future<void> _loadRecentUsernames() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _recentUsernames = prefs.getStringList(keyRecentUsernames) ?? [];
      notifyListeners();
    } catch (e) {
      print('⚠️ Error loading recent usernames: $e');
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
      print('⚠️ Error saving recent username: $e');
    }
  }

  // ====================== مساعدات ======================
  
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
}