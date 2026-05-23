import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// 🔐 خدمة التخزين الآمن
/// تستخدم Keystore على Android و Keychain على iOS
class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );
  
  static const String _keyToken = 'auth_token';
  static const String _keyHiveEncryption = 'hive_encryption_key';

  /// حفظ قيمة بشكل آمن
  static Future<void> write(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  /// قراءة قيمة
  static Future<String?> read(String key) async {
    return await _storage.read(key: key);
  }

  /// حذف قيمة
  static Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }

  /// مسح الكل
  static Future<void> deleteAll() async {
    await _storage.deleteAll();
  }

  // --- دوال مساعدة مخصصة ---

  static Future<void> saveToken(String token) async => await write(_keyToken, token);
  static Future<String?> getToken() async => await read(_keyToken);
  static Future<void> deleteToken() async => await delete(_keyToken);

  static Future<void> saveHiveKey(String base64Key) async => await write(_keyHiveEncryption, base64Key);
  static Future<String?> getHiveKey() async => await read(_keyHiveEncryption);
}
