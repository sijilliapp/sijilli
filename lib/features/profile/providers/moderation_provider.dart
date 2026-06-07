import 'package:flutter/material.dart';
import '../../../../models/user.dart';
import '../../settings/services/pb_moderation_service.dart';
import '../../settings/services/pb_user_service.dart';
import '../../../core/services/pocketbase_client.dart';

class ModerationProvider with ChangeNotifier {
  final PbModerationService _service = PbModerationService();
  
  List<UserModel> _blockedUsers = [];
  List<String> _idsBlockingMe = [];
  bool _isLoading = false;

  List<UserModel> get blockedUsers => _blockedUsers;
  List<String> get blockedUserIds => _blockedUsers.map((u) => u.id).toList();
  List<String> get idsBlockingMe => _idsBlockingMe;
  bool get isLoading => _isLoading;

  String? _currentUserId;

  ModerationProvider();

  void updateAuth(String? userId) {
    if (_currentUserId != userId) {
      _currentUserId = userId;
      if (userId != null) {
        fetchBlockedUsers();
      } else {
        clear();
      }
    }
  }

  void clear() {
    _blockedUsers = [];
    _idsBlockingMe = [];
    _currentUserId = null;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchBlockedUsers() async {
    _isLoading = true;
    notifyListeners();

    try {
      final currentUserId = PocketBaseClient.instance.pb.authStore.record?.id;
      if (currentUserId == null) return;

      final records = await PocketBaseClient.instance.pb.collection('friendship').getFullList(
        filter: '(user_a = "$currentUserId" && a_status = "blocked") || (user_b = "$currentUserId" && b_status = "blocked")',
        expand: 'user_a,user_b',
      );
      
      _blockedUsers = records.map((r) {
        final isUserA = r.getStringValue('user_a') == currentUserId;
        final targetUserJson = r.expand[isUserA ? 'user_b' : 'user_a']?.first.toJson();
        return targetUserJson != null ? UserModel.fromJson(targetUserJson) : null;
      }).whereType<UserModel>().toList();

      _idsBlockingMe = await _service.getUsersBlockingMe();
    } catch (e) {
      print('Error fetching blocked users: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> blockUser(UserModel user) async {
    try {
      // 1. Unfollow both ways
      final userService = PbUserService();
      await Future.wait<dynamic>([
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
    return blockedUserIds.contains(userId) || idsBlockingMe.contains(userId);
  }
  
  /// Helper to filter a list of items that have a userId or hostId
  List<T> filterBlockedContent<T>(List<T> items, String Function(T) getUserId) {
    return items.where((item) => !isUserBlocked(getUserId(item))).toList();
  }
}
