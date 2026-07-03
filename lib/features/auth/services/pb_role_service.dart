// 📍 lib/features/auth/services/pb_role_service.dart
// 👑 خدمة إدارة الأدوار وطلبات الترقية عبر PocketBase

import 'dart:convert';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/pocketbase_client.dart';
import '../../../models/user.dart';

class PbRoleService {
  final PocketBase _pb = PocketBaseClient.instance.pb;

  static const String collectionUserRoles = 'user_roles';
  static const String collectionUpgradeRequests = 'role_upgrade_requests';
  static const String collectionUsers = 'users';

  /// جلب كافة الأدوار وتحديث الكاش المحلي
  Future<List<UserRoleMetadata>> fetchAndCacheUserRoles() async {
    try {
      final records = await _pb.collection(collectionUserRoles).getFullList();
      final List<UserRoleMetadata> roles = records.map((record) {
        return UserRoleMetadata(
          key: record.getStringValue('key'),
          displayNameAr: record.getStringValue('display_name_ar'),
          displayNameEn: record.getStringValue('display_name_en'),
          badgeTextAr: record.getStringValue('badge_text_ar'),
          badgeColor: record.getStringValue('badge_color'),
          badgeIcon: record.getStringValue('badge_icon'),
          permissions: record.getDataValue<Map<String, dynamic>>('permissions') ?? {},
        );
      }).toList();

      // تخزين الكاش المحلي في SharedPreferences
      if (roles.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final String encoded = jsonEncode(roles.map((r) => r.toJson()).toList());
        await prefs.setString('user_roles_config', encoded);
      }
      return roles;
    } catch (e) {
      // تجاهل أخطاء الشبكة والعودة للقائمة الفارغة
      return [];
    }
  }

  /// الحصول على الأدوار من الكاش المحلي
  Future<List<UserRoleMetadata>> getCachedUserRoles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString('user_roles_config');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> list = jsonDecode(jsonStr);
        return list.map((item) => UserRoleMetadata.fromJson(Map<String, dynamic>.from(item))).toList();
      }
    } catch (_) {}
    return [];
  }

  /// إنشاء طلب ترقية حساب جديد
  Future<RecordModel> createUpgradeRequest({
    required String userId,
    required String requestedRole,
    String? userNotes,
  }) async {
    final body = {
      'user': userId,
      'requested_role': requestedRole,
      'status': 'pending',
      'user_notes': userNotes ?? '',
    };
    return await _pb.collection(collectionUpgradeRequests).create(body: body);
  }

  /// جلب طلبات الترقية الخاصة بمستخدم معين
  Future<List<RecordModel>> fetchMyUpgradeRequests(String userId) async {
    return await _pb.collection(collectionUpgradeRequests).getList(
      page: 1,
      perPage: 50,
      filter: 'user = "$userId"',
      sort: '-created',
    ).then((result) => result.items);
  }

  /// للمشرفين: جلب كافة الطلبات المعلقة
  Future<List<RecordModel>> fetchPendingUpgradeRequests() async {
    return await _pb.collection(collectionUpgradeRequests).getList(
      page: 1,
      perPage: 100,
      filter: 'status = "pending"',
      sort: '-created',
      expand: 'user',
    ).then((result) => result.items);
  }

  /// للمشرفين: قبول طلب ترقية وتعديل رول المستخدم
  Future<void> approveUpgradeRequest({
    required String requestId,
    required String targetUserId,
    required String requestedRole,
    required String adminId,
    String? adminNotes,
  }) async {
    // 1. تحديث حالة الطلب إلى مقبول
    final requestBody = {
      'status': 'approved',
      'reviewed_by': adminId,
      'admin_notes': adminNotes ?? '',
    };
    await _pb.collection(collectionUpgradeRequests).update(requestId, body: requestBody);

    // 2. تحديث دور (role) المستخدم في جدول المستخدمين
    final userBody = {
      'role': requestedRole,
    };
    await _pb.collection(collectionUsers).update(targetUserId, body: userBody);
  }

  /// للمشرفين: رفض طلب الترقية
  Future<void> rejectUpgradeRequest({
    required String requestId,
    required String adminId,
    String? adminNotes,
  }) async {
    final body = {
      'status': 'rejected',
      'reviewed_by': adminId,
      'admin_notes': adminNotes ?? '',
    };
    await _pb.collection(collectionUpgradeRequests).update(requestId, body: body);
  }
}
