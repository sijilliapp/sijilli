import 'package:pocketbase/pocketbase.dart';
import '../../models/broadcast.dart';
import './pocketbase_client.dart';

class PbBroadcastService {
  PocketBase get _pb => PocketBaseClient.instance.pb;

  /// جلب النشرات العامة النشطة التي لم تنتهي صلاحيتها بعد
  Future<List<Broadcast>> fetchActiveBroadcasts() async {
    try {
      final records = await _pb.collection('broadcasts').getFullList(
        filter: 'expires_at = "" || expires_at = null || expires_at > "${DateTime.now().toUtc().toIso8601String()}"',
        sort: '-created',
      );
      return records.map((r) => Broadcast.fromJson(r.toJson())).toList();
    } catch (e) {
      print('⚠️ Failed to fetch broadcasts: $e');
      return [];
    }
  }

  /// إنشاء نشرة عامة جديدة
  Future<Broadcast?> createBroadcast({
    required String title,
    required String content,
    required String type,
    DateTime? expiresAt,
    required List<String> targetRoles,
  }) async {
    try {
      final record = await _pb.collection('broadcasts').create(body: {
        'title': title,
        'content': content,
        'type': type,
        'expires_at': expiresAt?.toUtc().toIso8601String(),
        'target_roles': targetRoles,
      });
      return Broadcast.fromJson(record.toJson());
    } catch (e) {
      print('⚠️ Failed to create broadcast: $e');
      return null;
    }
  }

  /// حذف نشرة عامة بواسطة المعرف
  Future<bool> deleteBroadcast(String id) async {
    try {
      await _pb.collection('broadcasts').delete(id);
      return true;
    } catch (e) {
      print('⚠️ Failed to delete broadcast: $e');
      return false;
    }
  }
}
