import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sijilli/core/constants/app_colors.dart';
import 'package:sijilli/models/user.dart';
import 'package:sijilli/features/settings/services/pb_user_service.dart';
import 'package:sijilli/features/profile/widgets/user_cards/user_card.dart';
import 'package:sijilli/features/profile/widgets/user_follow_button.dart';
import 'package:sijilli/features/auth/providers/auth_provider.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:sijilli/l10n/app_localizations.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';

class FollowsScreen extends StatefulWidget {
  final String userId;
  final int initialIndex;

  const FollowsScreen({
    super.key,
    required this.userId,
    this.initialIndex = 0,
  });

  @override
  State<FollowsScreen> createState() => _FollowsScreenState();
}

class _FollowsScreenState extends State<FollowsScreen> {
  final PbUserService _userService = PbUserService();

  List<UserModel> _accredited = [];
  List<RecordModel> _incomingRequests = [];
  List<RecordModel> _outgoingRequests = [];
  List<UserModel> _unansweredFollowers = [];
  bool _isLoading = true;
  bool _isCurrentUser = false;

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _isCurrentUser = widget.userId == authProvider.user?.id;
    _fetchAll();
  }

  Future<void> _fetchAll({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      if (_isCurrentUser) {
        final results = await Future.wait([
          _userService.getIncomingFollowRequests(),
          _userService.getOutgoingFollowRequests(),
          _userService.getFollowedUsers(userId: widget.userId),
          _userService.getFollowers(userId: widget.userId),
        ]);

        final incoming = results[0] as List<RecordModel>;
        final outgoing = results[1] as List<RecordModel>;
        final following = results[2] as List<UserModel>;
        final followers = results[3] as List<UserModel>;

        final followingIds = following.map((u) => u.id).toSet();
        final accredited = followers.where((u) => followingIds.contains(u.id)).toList();
        final unanswered = followers.where((u) => !followingIds.contains(u.id)).toList();

        if (mounted) {
          setState(() {
            _incomingRequests = incoming;
            _outgoingRequests = outgoing;
            _accredited = accredited;
            _unansweredFollowers = unanswered;
            _isLoading = false;
          });
        }
      } else {
        final users = await _userService.getFollowedUsers(userId: widget.userId);
        if (mounted) {
          setState(() {
            _accredited = users;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _respondToRequest(String requestId, bool accept) async {
    try {
      if (accept) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.l10n.accreditEntity),
            content: Text(
              context.l10n.accreditDesc,
              style: const TextStyle(fontSize: 14),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.l10n.close)),
              TextButton(onPressed: () => Navigator.pop(context, true), child: Text(context.l10n.confirm)),
            ],
          ),
        );
        if (confirm != true) return;
      }

      // ⚡ Optimistic UI Update
      setState(() {
        final index = _incomingRequests.indexWhere((r) => r.id == requestId);
        if (index != -1) {
          final req = _incomingRequests.removeAt(index);
          if (accept && req.expand['follower']?.isNotEmpty == true) {
            final userJson = req.expand['follower']?.first.toJson();
            if (userJson != null) {
              _accredited.insert(0, UserModel.fromJson(userJson));
            }
          }
        }
      });

      await _userService.respondToFollowRequest(requestId, accept);
      _fetchAll(silent: true);
    } catch (e) {
      if (mounted) {
        _fetchAll(silent: true); // Revert on failure
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.errorProcessingRequest)),
        );
      }
    }
  }

  Future<void> _cancelRequest(String requestId) async {
    try {
       final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.l10n.withdrawRequest),
            content: Text(context.l10n.withdrawDesc),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.l10n.keepRequest)),
              TextButton(onPressed: () => Navigator.pop(context, true), child: Text(context.l10n.yes)),
            ],
          ),
        );
        if (confirm != true) return;

      // ⚡ Optimistic UI Update
      setState(() {
        _outgoingRequests.removeWhere((r) {
          final userJson = r.expand['following']?.first.toJson();
          if (userJson == null) return false;
          final user = UserModel.fromJson(userJson);
          return user.id == requestId;
        });
      });

      await _userService.unfollowUser(requestId);
      _fetchAll(silent: true);
    } catch (e) {
      if (mounted) _fetchAll(silent: true); // Revert
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(context.l10n.accreditations),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : AppColors.primary,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchAll,
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  if (_incomingRequests.isNotEmpty || _unansweredFollowers.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(context.l10n.waitingYourAccreditation, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    ),
                    ..._buildIncomingItems(),
                    ..._buildUnansweredItems(),
                  ],
                  if (_outgoingRequests.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(context.l10n.waitingTheirAccreditation, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    ),
                    ..._buildOutgoingItems(),
                  ],
                  if (_accredited.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(context.l10n.accreditedEntities, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    ),
                    ..._buildAccreditedItems(),
                  ],
                  if (_incomingRequests.isEmpty && _outgoingRequests.isEmpty && _accredited.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Text(context.l10n.noContactsYet),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  List<Widget> _buildIncomingItems() {
    return _incomingRequests.map((request) {
      final userJson = request.expand['follower']?.first.toJson();
      if (userJson == null) return const SizedBox();
      final user = UserModel.fromJson(userJson);
      return UserCard(
        user: user,
        mode: UserCardMode.followList,
        actionWidget: ElevatedButton(
          onPressed: () => _respondToRequest(request.id, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            minimumSize: const Size(80, 32),
          ),
          child: Text(context.l10n.accreditAction),
        ),
      );
    }).toList();
  }

  List<Widget> _buildUnansweredItems() {
    return _unansweredFollowers.map((user) {
      return UserCard(
        user: user,
        mode: UserCardMode.followList,
        actionWidget: ElevatedButton(
          onPressed: () => _accreditUnanswered(user),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            minimumSize: const Size(80, 32),
          ),
          child: Text(context.l10n.accreditAction),
        ),
      );
    }).toList();
  }

  Future<void> _accreditUnanswered(UserModel user) async {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.accreditEntity),
          content: Text(
            context.l10n.accreditDesc,
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.l10n.close)),
            TextButton(onPressed: () => Navigator.pop(context, true), child: Text(context.l10n.confirm)),
          ],
        ),
      );
      if (confirm != true) return;

      // ⚡ Optimistic UI Update
      setState(() {
        _unansweredFollowers.removeWhere((u) => u.id == user.id);
        _accredited.insert(0, user);
      });
      try {
         await _userService.accreditUser(user.id);
         _fetchAll(silent: true);
      } catch(e) {
         if (mounted) _fetchAll(silent: true); // revert on failure
      }
  }

  List<Widget> _buildOutgoingItems() {
    return _outgoingRequests.map((request) {
      final userJson = request.expand['following']?.first.toJson();
      if (userJson == null) return const SizedBox();
      final user = UserModel.fromJson(userJson);
      return UserCard(
        user: user,
        mode: UserCardMode.followList,
        actionWidget: OutlinedButton(
          onPressed: () => _cancelRequest(user.id),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            minimumSize: const Size(80, 32),
          ),
          child: Text(context.l10n.waitingAction),
        ),
      );
    }).toList();
  }

  List<Widget> _buildAccreditedItems() {
    return _accredited.map((user) {
      return UserCard(
        user: user,
        mode: UserCardMode.followList,
        actionWidget: UserFollowButton(
          userId: user.id,
          isCompact: true,
          initialStatusData: const {
            'status': 'accepted',
            'isFriend': true,
            'isBeingFollowed': true,
          },
        ),
      );
    }).toList();
  }

  @override
  void dispose() {
    super.dispose();
  }
}
