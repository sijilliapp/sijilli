import 'package:pocketbase/pocketbase.dart';
import '../../../core/services/pocketbase_client.dart';

class PbModerationService {
  final PocketBase pb = PocketBaseClient.instance.pb;

  /// Block a user
  Future<void> blockUser(String userId) async {
    final currentUserId = pb.authStore.record?.id;
    if (currentUserId == null) return;

    // Use alphabetical ordering to ensure one record
    final pair = currentUserId.compareTo(userId) < 0 
        ? {'a': currentUserId, 'b': userId} 
        : {'a': userId, 'b': currentUserId};
    
    final isUserA = pair['a'] == currentUserId;

    try {
      final record = await pb.collection('friendship').getFirstListItem(
        'user_a = "${pair['a']}" && user_b = "${pair['b']}"',
      );
      await pb.collection('friendship').update(record.id, body: {
        isUserA ? 'a_status' : 'b_status': 'blocked',
        isUserA ? 'b_status' : 'a_status': 'none',
        'last_action_by': currentUserId,
      });
    } catch (e) {
      await pb.collection('friendship').create(body: {
        'user_a': pair['a'],
        'user_b': pair['b'],
        isUserA ? 'a_status' : 'b_status': 'blocked',
        isUserA ? 'b_status' : 'a_status': 'none',
        'last_action_by': currentUserId,
      });
    }
  }

  /// Unblock a user
  Future<void> unblockUser(String targetUserId) async {
    final currentUserId = pb.authStore.record?.id;
    if (currentUserId == null) return;

    final pair = currentUserId.compareTo(targetUserId) < 0 
        ? {'a': currentUserId, 'b': targetUserId} 
        : {'a': targetUserId, 'b': currentUserId};
    
    final isUserA = pair['a'] == currentUserId;

    try {
      final record = await pb.collection('friendship').getFirstListItem(
        'user_a = "${pair['a']}" && user_b = "${pair['b']}"',
      );
      await pb.collection('friendship').update(record.id, body: {
        isUserA ? 'a_status' : 'b_status': 'none',
        'last_action_by': currentUserId,
      });
    } catch (e) {
      // Record not found
    }
  }

  /// Get list of blocked users by current user
  Future<List<String>> getBlockedUserIds() async {
    final currentUserId = pb.authStore.record?.id;
    if (currentUserId == null) return [];

    try {
      final records = await pb.collection('friendship').getFullList(
        filter: '(user_a = "$currentUserId" && a_status = "blocked") || (user_b = "$currentUserId" && b_status = "blocked")',
      );
      return records.map((record) {
        final isUserA = record.getStringValue('user_a') == currentUserId;
        return record.getStringValue(isUserA ? 'user_b' : 'user_a');
      }).toList();
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
    final currentUserId = pb.authStore.record?.id;
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
    final currentUserId = pb.authStore.record?.id;
    if (currentUserId == null) return false;

    final pair = currentUserId.compareTo(targetUserId) < 0 
        ? {'a': currentUserId, 'b': targetUserId} 
        : {'a': targetUserId, 'b': currentUserId};
    
    final isUserA = pair['a'] == currentUserId;

    try {
      final record = await pb.collection('friendship').getFirstListItem(
        'user_a = "${pair['a']}" && user_b = "${pair['b']}"',
      );
      return record.getStringValue(isUserA ? 'a_status' : 'b_status') == 'blocked';
    } catch (e) {
      return false;
    }
  }

  /// Check if the current user is blocked BY the target user
  Future<bool> isBlockedBy(String targetUserId) async {
    final currentUserId = pb.authStore.record?.id;
    if (currentUserId == null) return false;

    final pair = currentUserId.compareTo(targetUserId) < 0 
        ? {'a': currentUserId, 'b': targetUserId} 
        : {'a': targetUserId, 'b': currentUserId};
    
    final isUserA = pair['a'] == currentUserId;

    try {
      final record = await pb.collection('friendship').getFirstListItem(
        'user_a = "${pair['a']}" && user_b = "${pair['b']}"',
      );
      return record.getStringValue(isUserA ? 'b_status' : 'a_status') == 'blocked';
    } catch (e) {
      return false;
    }
  }

  /// Get list of IDs of users who have blocked the current user
  Future<List<String>> getUsersBlockingMe() async {
    final currentUserId = pb.authStore.record?.id;
    if (currentUserId == null) return [];

    try {
      final records = await pb.collection('friendship').getFullList(
        filter: '(user_a = "$currentUserId" && b_status = "blocked") || (user_b = "$currentUserId" && a_status = "blocked")',
      );
      return records.map((record) {
        final isUserA = record.getStringValue('user_a') == currentUserId;
        return record.getStringValue(isUserA ? 'user_b' : 'user_a');
      }).toList();
    } catch (e) {
      return [];
    }
  }
}
