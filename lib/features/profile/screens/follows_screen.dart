import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sijilli/core/constants/app_colors.dart';
import 'package:sijilli/models/user.dart';
import 'package:sijilli/features/settings/services/pb_user_service.dart';
import 'package:sijilli/features/profile/widgets/user_cards/user_card.dart';
import 'package:sijilli/features/profile/widgets/user_follow_button.dart';
import 'package:sijilli/features/auth/providers/auth_provider.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';
import 'package:sijilli/core/services/pocketbase_client.dart';

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

  UnsubscribeFunc? _unsubscribeFunc;

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _isCurrentUser = widget.userId == authProvider.user?.id;
    _fetchAll();
    if (_isCurrentUser) {
      _subscribeToRealtime();
    }
  }

  Future<void> _subscribeToRealtime() async {
    try {
      final pb = PocketBaseClient.instance.pb;
      _unsubscribeFunc = await pb.collection('follows').subscribe('*', (e) {
        // Only refresh if the event involves the current user
        final record = e.record;
        if (record != null) {
          final follower = record.getStringValue('follower');
          final following = record.getStringValue('following');
          if (follower == widget.userId || following == widget.userId) {
            _fetchAll(silent: true);
          }
        }
      });
    } catch (e) {
      print('Error subscribing to follows realtime: $e');
    }
  }

  Future<void> _fetchAll({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final pb = PocketBaseClient.instance.pb;
      
      // Fetch all records where the user is involved
      final allFollows = await pb.collection('follows').getFullList(
        filter: 'follower = "${widget.userId}" || following = "${widget.userId}"',
        expand: 'follower,following',
      );

      final incomingList = <RecordModel>[]; // Pending requests TO me
      final outgoingList = <RecordModel>[]; // Pending requests FROM me
      final iFollowAcc = <UserModel>[]; // Ones I follow (accepted)
      final followsMeAcc = <UserModel>[]; // Ones following me (accepted)

      for (var record in allFollows) {
        final followerId = record.getStringValue('follower');
        final followingId = record.getStringValue('following');
        final status = record.getStringValue('status');

        if (followerId == widget.userId) {
          // I am the follower
          if (status == 'pending') {
            outgoingList.add(record);
          } else if (status == 'accepted') {
            final targetJson = record.expand['following']?.first.toJson();
            if (targetJson != null) iFollowAcc.add(UserModel.fromJson(targetJson));
          }
        } 
        
        if (followingId == widget.userId) {
          // I am the followed
          if (status == 'pending') {
            incomingList.add(record);
          } else if (status == 'accepted') {
            final sourceJson = record.expand['follower']?.first.toJson();
            if (sourceJson != null) followsMeAcc.add(UserModel.fromJson(sourceJson));
          }
        }
      }

      if (_isCurrentUser) {
        final followingIds = iFollowAcc.map((u) => u.id).toSet();
        
        final accredited = followsMeAcc.where((u) => followingIds.contains(u.id)).toList();
        final unanswered = followsMeAcc.where((u) => !followingIds.contains(u.id)).toList();
        
        // Find people I follow who don't follow me back yet
        final followsMeIds = followsMeAcc.map((u) => u.id).toSet();
        final waitingForThemAcc = iFollowAcc.where((u) => !followsMeIds.contains(u.id)).toList();

        if (mounted) {
          setState(() {
            _incomingRequests = incomingList;
            _outgoingRequests = outgoingList;
            // Also add the 'accepted but not mutual' to outgoing if we want them to show in waiting
            // but let's just keep _accredited clean
            _accredited = accredited;
            _unansweredFollowers = unanswered;
            
            // For those I follow who are accepted but don't follow me back yet,
            // they should appear in the "Waiting Their Accreditation" section.
            // But we need a custom list for them since they are UserModels, not RecordModels.
            // Actually, we can just fetch the record for them from allFollows!
            for (var u in waitingForThemAcc) {
               final rec = allFollows.firstWhere((r) => r.getStringValue('follower') == widget.userId && r.getStringValue('following') == u.id);
               _outgoingRequests.add(rec);
            }

            _isLoading = false;
          });
        }
      } else {
        // If not current user, maybe just show who they are accredited with (mutual)
        final followingIds = iFollowAcc.map((u) => u.id).toSet();
        final accredited = followsMeAcc.where((u) => followingIds.contains(u.id)).toList();
        
        if (mounted) {
          setState(() {
            _accredited = accredited;
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
    _unsubscribeFunc?.call();
    super.dispose();
  }
}
