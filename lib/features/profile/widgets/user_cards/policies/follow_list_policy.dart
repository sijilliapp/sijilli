import 'package:flutter/material.dart';
import 'package:sijilli/features/profile/widgets/user_cards/user_card_policy.dart';
import 'package:sijilli/features/home/screens/public_profile_screen.dart';

class FollowListPolicy extends UserCardPolicy {
  final Widget? actionWidget;

  FollowListPolicy(super.user, super.context, {this.actionWidget, super.overrideStatus});

  @override
  Widget? buildAction() => actionWidget;

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
