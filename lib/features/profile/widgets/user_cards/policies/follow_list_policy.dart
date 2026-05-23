import 'package:flutter/material.dart';
import 'package:sijilli/features/profile/widgets/user_cards/user_card_policy.dart';
import 'package:sijilli/features/home/screens/public_profile_screen.dart';
import 'package:provider/provider.dart';
import 'package:sijilli/features/profile/providers/moderation_provider.dart';
import 'package:sijilli/core/utils/app_date_formatter.dart';
import 'package:sijilli/core/constants/app_colors.dart';

class FollowListPolicy extends UserCardPolicy {
  final Widget? actionWidget;
  final VoidCallback? _customOnTap;

  FollowListPolicy(super.user, super.context, {this.actionWidget, super.overrideStatus, VoidCallback? onTap})
    : _customOnTap = onTap;

  @override
  Widget? buildAction() => actionWidget;

  @override
  EdgeInsets get padding => const EdgeInsets.all(8);

  @override
  EdgeInsets get margin => const EdgeInsets.symmetric(horizontal: 8, vertical: 4);

  @override
  Widget buildSecondaryText() {
    final lastSeen = AppDateFormatter.formatLastSeen(user.lastActive);
    return Text(
      lastSeen ?? '@${user.username}',
      style: lastSeen != null 
          ? usernameStyle.copyWith(
              fontSize: 11.5,
              fontStyle: FontStyle.italic,
              color: Theme.of(context).brightness == Brightness.dark 
                  ? AppColors.primary.withValues(alpha: 0.8)
                  : AppColors.primary,
            )
          : usernameStyle,
    );
  }

  @override
  Widget? buildSubtitle() => null; // No extra lines!

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
