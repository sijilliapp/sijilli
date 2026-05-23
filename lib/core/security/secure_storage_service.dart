// 📍 lib/core/security/secure_storage_service.dart
// 🔒 خدمة التخزين المشفر للبيانات الحساسة

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

class SecureStorageService {
  static SecureStorageService? _instance;
  static SecureStorageService get instance => _instance ??= SecureStorageService._();
  
  SecureStorageService._();
  
  // 🔐 Secure Storage Instance
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );
  
  // ====================== Keys ======================
  static const String keyAuthToken = 'auth_token';
  static const String keyUserId = 'user_id';
  static const String keyRefreshToken = 'refresh_token';
  
  // ====================== Auth Token Operations ======================
  
  /// Save auth token securely
  Future<void> saveAuthToken(String token) async {
    try {
      await _storage.write(key: keyAuthToken, value: token);
      debugPrint('✅ Auth token saved securely');
    } catch (e) {
      debugPrint('❌ Error saving auth token: $e');
      rethrow;
    }
  }
  
  /// Get auth token securely
  Future<String?> getAuthToken() async {
    try {
      final token = await _storage.read(key: keyAuthToken);
      return token;
    } catch (e) {
      debugPrint('❌ Error reading auth token: $e');
      return null;
    }
  }
  
  /// Delete auth token securely
  Future<void> deleteAuthToken() async {
    try {
      await _storage.delete(key: keyAuthToken);
      debugPrint('✅ Auth token deleted securely');
    } catch (e) {
      debugPrint('❌ Error deleting auth token: $e');
    }
  }
  
  // ====================== User ID Operations ======================
  
  /// Save user ID securely
  Future<void> saveUserId(String userId) async {
    try {
      await _storage.write(key: keyUserId, value: userId);
      debugPrint('✅ User ID saved securely');
    } catch (e) {
      debugPrint('❌ Error saving user ID: $e');
      rethrow;
    }
  }
  
  /// Get user ID securely
  Future<String?> getUserId() async {
    try {
      final userId = await _storage.read(key: keyUserId);
      return userId;
    } catch (e) {
      debugPrint('❌ Error reading user ID: $e');
      return null;
    }
  }
  
  /// Delete user ID securely
  Future<void> deleteUserId() async {
    try {
      await _storage.delete(key: keyUserId);
      debugPrint('✅ User ID deleted securely');
    } catch (e) {
      debugPrint('❌ Error deleting user ID: $e');
    }
  }
  
  // ====================== Refresh Token Operations ======================
  
  /// Save refresh token securely
  Future<void> saveRefreshToken(String token) async {
    try {
      await _storage.write(key: keyRefreshToken, value: token);
      debugPrint('✅ Refresh token saved securely');
    } catch (e) {
      debugPrint('❌ Error saving refresh token: $e');
      rethrow;
    }
  }
  
  /// Get refresh token securely
  Future<String?> getRefreshToken() async {
    try {
      final token = await _storage.read(key: keyRefreshToken);
      return token;
    } catch (e) {
      debugPrint('❌ Error reading refresh token: $e');
      return null;
    }
  }
  
  /// Delete refresh token securely
  Future<void> deleteRefreshToken() async {
    try {
      await _storage.delete(key: keyRefreshToken);
      debugPrint('✅ Refresh token deleted securely');
    } catch (e) {
      debugPrint('❌ Error deleting refresh token: $e');
    }
  }
  
  // ====================== Bulk Operations ======================
  
  /// Clear all sensitive data (on logout)
  Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
      debugPrint('✅ All secure storage cleared');
    } catch (e) {
      debugPrint('❌ Error clearing secure storage: $e');
    }
  }
  
  /// Check if auth token exists
  Future<bool> hasAuthToken() async {
    try {
      final token = await _storage.read(key: keyAuthToken);
      return token != null && token.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Error checking auth token: $e');
      return false;
    }
  }
}
