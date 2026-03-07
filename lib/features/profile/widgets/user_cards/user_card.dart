import 'package:flutter/material.dart';
import 'package:sijilli/models/user.dart';
import 'package:sijilli/core/widgets/pulse_avatar.dart';
import 'package:sijilli/features/profile/widgets/user_cards/base_user_card.dart';
import 'package:sijilli/features/profile/widgets/user_cards/user_card_policy.dart';
import 'package:sijilli/features/profile/widgets/user_cards/policies/standard_user_policy.dart';
import 'package:sijilli/features/profile/widgets/user_cards/policies/selection_user_policy.dart';
import 'package:sijilli/features/profile/widgets/user_cards/policies/follow_list_policy.dart';

enum UserCardMode {
  standard,   // Search/Discovery (Follow button)
  selection,  // Invite sheet (Add/+ icon, conflict awareness)
  followList  // Manage friends (Remove/Unfollow)
}

class UserCard extends StatelessWidget {
  final UserModel user;
  final UserCardMode mode;
  final AvatarStatus? overrideStatus;
  
  // Selection specific
  final bool hasConflict;
  final bool isHost;
  final bool isFollowed;
  final VoidCallback? onSelected;
  
  // FollowList specific
  final Widget? actionWidget;

  const UserCard({
    super.key,
    required this.user,
    this.mode = UserCardMode.standard,
    this.overrideStatus,
    this.hasConflict = false,
    this.isHost = false,
    this.isFollowed = false,
    this.onSelected,
    this.actionWidget,
  });

  @override
  Widget build(BuildContext context) {
    UserCardPolicy policy;

    switch (mode) {
      case UserCardMode.selection:
        policy = SelectionUserPolicy(
          user,
          context,
          hasConflict: hasConflict,
          isHost: isHost,
          isFollowed: isFollowed,
          onSelected: onSelected ?? () {},
          overrideStatus: overrideStatus,
        );
        break;
      case UserCardMode.followList:
        policy = FollowListPolicy(
          user,
          context,
          actionWidget: actionWidget,
          overrideStatus: overrideStatus,
        );
        break;
      case UserCardMode.standard:
      default:
        policy = StandardUserPolicy(
          user,
          context,
          overrideStatus: overrideStatus,
        );
        break;
    }

    return BaseUserCard(policy: policy);
  }
}
