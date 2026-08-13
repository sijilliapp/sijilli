// 📍 lib/core/services/pocketbase_client.dart
// 🔌 العميل الموحد للاتصال بـ PocketBase

import 'package:pocketbase/pocketbase.dart';
import 'package:http/http.dart' as http;
import '../../models/user.dart';
import '../local/persistent_auth_store.dart';

class PocketBaseClient {
  static PocketBaseClient? _instance;
  static PocketBaseClient get instance => _instance ??= PocketBaseClient._();
  
  PocketBaseClient._();
  
  static const String _defaultUrl = 'https://sijilli.pockethost.io';
  late PocketBase pb;
  late PersistentAuthStore _store;
  
  Future<void> initialize({String? customUrl}) async {
    _store = PersistentAuthStore();
    await _store.load();
    pb = PocketBase(
      customUrl ?? _defaultUrl,
      authStore: _store,
    );
  }

  /// إيقاظ الخادم بشكل مباشر في بداية تشغيل التطبيق
  Future<void> wakeUpServer() async {
    final client = http.Client();
    final healthUrl = Uri.parse('${pb.baseURL}/api/health');
    int retries = 5;
    
    while (retries > 0) {
      try {
        print('⏰ [PocketBaseClient] Sending wake up ping to $healthUrl (retries left: $retries)...');
        final res = await client.get(healthUrl).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          print('✅ [PocketBaseClient] Server is awake and healthy!');
          break;
        }
      } catch (e) {
        print('⏳ [PocketBaseClient] Wake up ping failed, retrying in 1.5s: $e');
      }
      retries--;
      if (retries > 0) {
        await Future.delayed(const Duration(milliseconds: 1500));
      }
    }
    client.close();
  }

  /// الحصول على المستخدم الحالي من الـ AuthStore
  UserModel? get currentUser {
    if (!pb.authStore.isValid) return null;
    try {
      final record = pb.authStore.record;
      if (record != null) {
        return UserModel.fromJson(record.toJson(), token: pb.authStore.token);
      }
    } catch (e) {
      print('❌ Error parsing current user: $e');
    }
    return null;
  }

  /// قطع كافة الاتصالات اللحظية (مهم عند تسجيل الخروج لمنع أخطاء 403)
  Future<void> disconnectRealtime() async {
    try {
      await pb.realtime.unsubscribe();
      print('🔌 [PocketBaseClient] Realtime disconnected and unsubscribed from all.');
    } catch (e) {
      print('⚠️ [PocketBaseClient] Error during realtime disconnect: $e');
    }
  }
}
