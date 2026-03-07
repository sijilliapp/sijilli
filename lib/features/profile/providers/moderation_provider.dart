import 'package:flutter/material.dart';
import '../../../../models/user.dart';
import '../../settings/services/pb_moderation_service.dart';
import '../../settings/services/pb_user_service.dart';
import '../../../core/services/pocketbase_client.dart';

class ModerationProvider with ChangeNotifier {
  final PbModerationService _service = PbModerationService();
  
  List<UserModel> _blockedUsers = [];
  bool _isLoading = false;

  List<UserModel> get blockedUsers => _blockedUsers;
  List<String> get blockedUserIds => _blockedUsers.map((u) => u.id).toList();
  bool get isLoading => _isLoading;

  ModerationProvider() {
    fetchBlockedUsers();
  }

  Future<void> fetchBlockedUsers() async {
    _isLoading = true;
    notifyListeners();

    try {
      // We need to fetch the actual user models or at least their basic info
      // Let's modify the service or fetch them here
      final records = await PocketBaseClient.instance.pb.collection('blocks').getFullList(
        filter: 'user = "${PocketBaseClient.instance.pb.authStore.model?.id}"',
        expand: 'blocked_user',
      );
      
      _blockedUsers = records
          .where((r) => r.expand['blocked_user'] != null)
          .map((r) => UserModel.fromJson(r.expand['blocked_user']!.first.toJson()))
          .toList();
    } catch (e) {
      debugPrint('Error fetching blocked users: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> blockUser(UserModel user) async {
    try {
      // 1. Unfollow both ways
      final userService = PbUserService();
      await Future.wait([
        userService.unfollowUser(user.id).catchError((_) {}), // Ignore errors if not following
        userService.removeFollower(user.id).catchError((_) {}), // Ignore errors if not followed
      ]);

      // 2. Perform Block
      await _service.blockUser(user.id);
      
      if (!isUserBlocked(user.id)) {
        _blockedUsers.add(user);
        notifyListeners();
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> unblockUser(String userId) async {
    try {
      await _service.unblockUser(userId);
      _blockedUsers.removeWhere((u) => u.id == userId);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> reportContent({
    required String subjectType,
    required String subjectId,
    required String reason,
  }) async {
    await _service.reportContent(
      subjectType: subjectType,
      subjectId: subjectId,
      reason: reason,
    );
  }

  bool isUserBlocked(String userId) {
    return blockedUserIds.contains(userId);
  }
  
  /// Helper to filter a list of items that have a userId or hostId
  List<T> filterBlockedContent<T>(List<T> items, String Function(T) getUserId) {
    return items.where((item) => !isUserBlocked(getUserId(item))).toList();
  }
}
