import 'package:flutter/material.dart';
import 'package:sijilli/features/profile/widgets/user_cards/user_card_policy.dart';
import 'package:sijilli/features/profile/widgets/user_follow_button.dart';
import 'package:sijilli/features/home/screens/public_profile_screen.dart';
import 'package:sijilli/core/services/pocketbase_client.dart';
import 'package:provider/provider.dart';
import 'package:sijilli/features/profile/providers/moderation_provider.dart';

class StandardUserPolicy extends UserCardPolicy {
  final VoidCallback? _customOnTap;
  final Map<String, dynamic>? initialStatusData;

  StandardUserPolicy(
    super.user, 
    super.context, {
    super.overrideStatus, 
    VoidCallback? onTap,
    this.initialStatusData,
  }) : _customOnTap = onTap;

  @override
  Widget? buildAction() {
    final currentUserId = PocketBaseClient.instance.pb.authStore.record?.id;
    if (user.id == currentUserId) return null;

    return UserFollowButton(
      userId: user.id,
      isCompact: true,
      isPublic: user.isPublic,
      initialStatusData: initialStatusData,
    );
  }

  @override
  VoidCallback? get onTap => _customOnTap ?? () {
        final moderation = context.read<ModerationProvider>();
        if (moderation.isUserBlocked(user.id)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('هذا الحساب غير متاح حالياً')),
          );
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PublicProfileScreen(usernameOrId: user.username),
          ),
        );
      };
}
