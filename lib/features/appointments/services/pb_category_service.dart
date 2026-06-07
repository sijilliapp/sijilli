// 📍 lib/features/appointments/services/pb_category_service.dart
import 'package:pocketbase/pocketbase.dart';
import '../../../core/services/pocketbase_client.dart';
import '../../../models/appointment.dart';

class PbCategoryService {
  final PocketBase _pb = PocketBaseClient.instance.pb;
  static const String collectionName = 'categories';

  /// جلب التصنيفات الخاصة بالمستخدم + التصنيفات العامة
  Future<List<AppointmentCategory>> getCategories() async {
    try {
      final userId = _pb.authStore.record?.id;
      
      // نفلتر: إما التصنيفات العامة (user = null) أو الخاصة بالمستخد الحالي
      final filter = userId != null 
          ? 'user = null || user = "$userId"'
          : 'user = null';

      final result = await _pb.collection(collectionName).getFullList(
        filter: filter,
        sort: '+name',
      );

      return result.map((record) => AppointmentCategory.fromJson(record.toJson())).toList();
    } catch (e) {
      print('⚠️ Failed to fetch categories: $e');
      return [];
    }
  }

  /// إنشاء تصنيف جديد للمستخدم
  Future<AppointmentCategory> createCategory(String name, {String? color, String? icon}) async {
    try {
      final userId = _pb.authStore.record?.id;
      if (userId == null) throw Exception('User not authenticated');

      final body = {
        'name': name,
        'user': userId,
        'color': color,
        'icon': icon,
      };

      final record = await _pb.collection(collectionName).create(body: body);
      return AppointmentCategory.fromJson(record.toJson());
    } catch (e) {
      print('⚠️ Failed to create category: $e');
      rethrow;
    }
  }

  /// تحديث تصنيف للمستخدم
  Future<AppointmentCategory> updateCategory(String id, String name, {String? color, String? icon}) async {
    try {
      final body = {
        'name': name,
        if (color != null) 'color': color,
        if (icon != null) 'icon': icon,
      };

      final record = await _pb.collection(collectionName).update(id, body: body);
      return AppointmentCategory.fromJson(record.toJson());
    } catch (e) {
      print('⚠️ Failed to update category: $e');
      rethrow;
    }
  }

  /// حذف تصنيف
  Future<void> deleteCategory(String id) async {
    try {
      await _pb.collection(collectionName).delete(id);
    } catch (e) {
      print('⚠️ Failed to delete category: $e');
      rethrow;
    }
  }
}
