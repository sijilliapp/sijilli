import 'package:flutter/material.dart';
import 'package:sijilli/models/user.dart';
import 'package:sijilli/core/widgets/pulse_avatar.dart';

abstract class UserCardPolicy {
  final UserModel user;
  final BuildContext context;
  final AvatarStatus? overrideStatus;

  /// Whether to automatically fetch user status (Active/Upcoming) from the server.
  /// Defaults to true. Subclasses can override to false to prevent API spam (e.g. in Selection lists).
  bool get shouldFetchStatus => true;

  UserCardPolicy(this.user, this.context, {this.overrideStatus});

  // --- Visuals ---
  Color get backgroundColor => Theme.of(context).cardColor;
  double get elevation => 0;
  EdgeInsets get padding => const EdgeInsets.symmetric(horizontal: 16, vertical: 12);

  // --- Avatar Logic ---
  /// The status of the ring around the avatar.
  /// Defaults to overrideStatus or derived status.
  AvatarStatus get avatarStatus => overrideStatus ?? AvatarStatus.none;

  // --- Text Styles ---
  TextStyle get nameStyle => TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 15,
        color: Theme.of(context).colorScheme.onSurface,
      );

  TextStyle get usernameStyle => TextStyle(
        fontSize: 13,
        color: Theme.of(context).brightness == Brightness.dark 
            ? Colors.grey.shade400 
            : Colors.grey.shade500,
      );

  TextStyle get bioStyle => TextStyle(
        fontSize: 12,
        color: Theme.of(context).brightness == Brightness.dark 
            ? Colors.grey.shade400 
            : Colors.grey.shade600,
        height: 1.2,
      );

  // --- Secondary Info (Optional) ---
  Widget? buildSubtitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (user.bio != null && user.bio!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 4),
            child: Text(
              user.bio!,
              style: bioStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        if (!user.isPublic) _buildPrivateBadge(),
      ],
    );
  }

  Widget _buildPrivateBadge() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline, size: 10, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            'حساب خاص',
            style: TextStyle(
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget? buildBadges() {
    if (user.isApproved || user.isOfficial) {
      return Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Icon(
          Icons.verified,
          size: 14,
          color: Theme.of(context).primaryColor,
        ),
      );
    }
    return null;
  }

  // --- Action Button ---
  /// The widget shown on the far left (trailing).
  Widget? buildAction();

  // --- Interactions ---
  VoidCallback? get onTap;
}
