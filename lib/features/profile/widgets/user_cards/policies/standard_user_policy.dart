import 'package:flutter/material.dart';
import 'package:sijilli/features/profile/widgets/user_cards/user_card_policy.dart';
import 'package:sijilli/features/profile/widgets/user_follow_button.dart';
import 'package:sijilli/features/home/screens/public_profile_screen.dart';
import 'package:sijilli/core/services/pocketbase_client.dart';

class StandardUserPolicy extends UserCardPolicy {
  StandardUserPolicy(super.user, super.context, {super.overrideStatus});

  @override
  Widget? buildAction() {
    final currentUserId = PocketBaseClient.instance.pb.authStore.model?.id;
    if (user.id == currentUserId) return null;

    return UserFollowButton(
      userId: user.id,
      isCompact: true,
      isPublic: user.isPublic,
    );
  }

  @override
  VoidCallback? get onTap => () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PublicProfileScreen(usernameOrId: user.username),
          ),
        );
      };
}
