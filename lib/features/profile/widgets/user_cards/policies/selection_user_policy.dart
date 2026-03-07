import 'package:flutter/material.dart';
import 'package:sijilli/core/constants/app_colors.dart';
import 'package:sijilli/core/widgets/pulse_avatar.dart';
import 'package:sijilli/features/profile/widgets/user_cards/user_card_policy.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';

class SelectionUserPolicy extends UserCardPolicy {
  final bool hasConflict;
  final bool isHost;
  final bool isFollowed;
  final VoidCallback onSelected;

  SelectionUserPolicy(
    super.user,
    super.context, {
    this.hasConflict = false,
    this.isHost = false,
    this.isFollowed = false,
    required this.onSelected,
    super.overrideStatus,
  });

  @override
  bool get shouldFetchStatus => false;

  @override
  AvatarStatus get avatarStatus =>
      isHost ? AvatarStatus.none : (hasConflict ? AvatarStatus.deleted : AvatarStatus.none);

  @override
  Widget? buildSubtitle() {
    if (isHost || isFollowed || hasConflict) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isHost)
            _buildBadge('أنت (المنشئ)', AppColors.primary),
          if (isFollowed && !isHost) ...[
            Icon(Icons.star, color: Colors.amber.shade400, size: 12),
            const SizedBox(width: 4),
          ],
          if (hasConflict)
            _buildBadge('تعارض', Colors.red),
        ],
      );
    }
    return null;
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget? buildAction() {
    if (isHost) {
      return Icon(Icons.check_circle, color: Colors.grey.shade400);
    }

    if (!isFollowed) {
      return SizedBox(
        height: 32,
        child: ElevatedButton(
          onPressed: onSelected,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Text(
            context.l10n.hostAndConnect,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    return const Icon(Icons.add_circle_outline, color: AppColors.primary);
  }

  @override
  VoidCallback? get onTap => isHost ? null : onSelected;
}
