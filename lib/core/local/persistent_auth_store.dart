// 📍 lib/core/local/persistent_auth_store.dart
// 🔐 مخزن المصادقة المستمر - يحفظ التوكن وبيانات المستخدم في ذاكرة الهاتف

import 'dart:convert';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PersistentAuthStore extends AsyncAuthStore {
  final String _key = 'pb_auth';

  PersistentAuthStore() : super(
    save: (String data) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pb_auth', data);
    },
    initial: null, // We'll load it manually in initialize
  );

  /// تحميل البيانات المحفوظة مسبقاً
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? data = prefs.getString(_key);
      if (data != null && data.isNotEmpty) {
        final decoded = jsonDecode(data);
        save(
          decoded['token'] ?? '',
          decoded['model'] != null ? RecordModel.fromJson(decoded['model'] as Map<String, dynamic>) : null,
        );
        print('🔐 AuthStore: Session loaded successfully');
      }
    } catch (e) {
      print('🔐 AuthStore: Failed to load session: $e');
    }
  }

  /// مسح البيانات (تسجيل الخروج)
  @override
  void clear() {
    super.clear();
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove(_key);
    });
    print('🔐 AuthStore: Session cleared');
  }
}
