import 'package:pocketbase/pocketbase.dart';
import '../../../core/services/pocketbase_client.dart';

class PbModerationService {
  final PocketBase pb = PocketBaseClient.instance.pb;

  /// Block a user
  Future<void> blockUser(String userId) async {
    final currentUserId = pb.authStore.model?.id;
    if (currentUserId == null) return;

    await pb.collection('blocks').create(body: {
      'user': currentUserId,
      'blocked_user': userId,
    });
  }

  /// Unblock a user
  Future<void> unblockUser(String targetUserId) async {
    final currentUserId = pb.authStore.model?.id;
    if (currentUserId == null) return;

    try {
      final record = await pb.collection('blocks').getFirstListItem(
        'user = "$currentUserId" && blocked_user = "$targetUserId"',
      );
      await pb.collection('blocks').delete(record.id);
    } catch (e) {
      // Record might not exist or already deleted
    }
  }

  /// Get list of blocked users by current user
  Future<List<String>> getBlockedUserIds() async {
    final currentUserId = pb.authStore.model?.id;
    if (currentUserId == null) return [];

    try {
      final records = await pb.collection('blocks').getFullList(
        filter: 'user = "$currentUserId"',
      );
      return records.map((r) => r.getStringValue('blocked_user')).toList();
    } catch (e) {
      return [];
    }
  }

  /// Report content (User or Appointment)
  Future<void> reportContent({
    required String subjectType, // 'user' or 'appointment'
    required String subjectId,
    required String reason,
  }) async {
    final currentUserId = pb.authStore.model?.id;
    if (currentUserId == null) return;

    await pb.collection('reports').create(body: {
      'reporter': currentUserId,
      'subject_type': subjectType,
      'subject_id': subjectId,
      'reason': reason,
      'status': 'pending',
    });
  }

  /// Check if a user is blocked
  Future<bool> isBlocked(String targetUserId) async {
    final currentUserId = pb.authStore.model?.id;
    if (currentUserId == null) return false;

    try {
      final record = await pb.collection('blocks').getFirstListItem(
        'user = "$currentUserId" && blocked_user = "$targetUserId"',
      );
      return record != null;
    } catch (e) {
      return false;
    }
  }
}
