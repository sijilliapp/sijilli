// 📍 lib/core/services/pocketbase_client.dart
// 🔌 العميل الموحد للاتصال بـ PocketBase

import 'package:pocketbase/pocketbase.dart';
import '../../models/user.dart';

class PocketBaseClient {
  static PocketBaseClient? _instance;
  static PocketBaseClient get instance => _instance ??= PocketBaseClient._();
  
  PocketBaseClient._();
  
  static const String _defaultUrl = 'https://sijilli.pockethost.io';
  late PocketBase pb;
  
  void initialize({String? customUrl}) {
    pb = PocketBase(customUrl ?? _defaultUrl);
  }

  /// الحصول على المستخدم الحالي من الـ AuthStore
  UserModel? get currentUser {
    if (!pb.authStore.isValid) return null;
    try {
      final record = pb.authStore.model;
      if (record != null) {
        return UserModel.fromJson(record.toJson(), token: pb.authStore.token);
      }
    } catch (e) {
      print('❌ Error parsing current user: $e');
    }
    return null;
  }
}
