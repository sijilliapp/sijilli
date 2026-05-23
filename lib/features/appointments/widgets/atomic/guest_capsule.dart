import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../models/appointment.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/app_date_formatter.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';
import 'interaction_capsule.dart';

class GuestCapsule extends StatelessWidget {
  final String? avatarUrl;
  final String name;
  final int? extraGuests;
  final InvitationStatus status;
  final VoidCallback? onTap;
  final IconData? icon;

  const GuestCapsule({
    super.key,
    this.avatarUrl,
    required this.name,
    this.extraGuests,
    this.status = InvitationStatus.pending,
    this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    // If status is declined, the capsule disappears per PRD
    if (status == InvitationStatus.declined) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAr = context.l10n.localeName == 'ar';

    final Color statusColor = status == InvitationStatus.accepted 
        ? AppColors.primary 
        : (status == InvitationStatus.deletedAfterAccept ? Colors.red : (isDark ? Colors.grey.shade400 : Colors.grey.shade400));
        // Keeping shade400 for grey status as it is readable in both.

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (extraGuests != null && extraGuests! > 0) ...[
          InteractionCapsule(
            borderColor: AppColors.primary,
            borderOpacity: 1.0,
            backgroundColor: AppColors.primary.withValues(alpha: isDark ? 0.1 : 0.05),
            padding: const EdgeInsets.symmetric(horizontal: 6), // 🌟 Custom horizontal padding for perfect circular aspect ratio
            child: Text(
              context.l10n.localeName == 'ar'
                  ? AppDateFormatter.toEasternArabicDigits(context.l10n.extraGuestsCount(extraGuests!))
                  : context.l10n.extraGuestsCount(extraGuests!),
              style: const TextStyle(
                fontSize: 12, // 🌟 Increased from 10 to 12 for high readability
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: InteractionCapsule(
            onTap: onTap,
            borderColor: statusColor,
            borderOpacity: 1.0, 
            backgroundColor: _getGuestBackgroundColor(status, isDark),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
            padding: const EdgeInsetsDirectional.fromSTEB(8, 2, 2, 2), 
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    name,
                    style: TextStyle(
                      fontSize: 12,
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                if (icon != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(icon, size: 14, color: statusColor),
                  )
                else
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: isDark ? const Color(0xFF374151) : Colors.grey.shade200,
                    backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl!) : null,
                    child: avatarUrl == null ? Icon(Icons.person, size: 12, color: isDark ? Colors.grey.shade400 : Colors.grey) : null,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Color _getGuestBackgroundColor(InvitationStatus status, bool isDark) {
    if (status == InvitationStatus.accepted) {
      return isDark ? Colors.blue.shade900.withValues(alpha: 0.3) : Colors.blue.shade50;
    }
    if (status == InvitationStatus.deletedAfterAccept) {
      return isDark ? Colors.red.shade900.withValues(alpha: 0.3) : Colors.red.shade50;
    }
    // Pending / Declined / Default
    return isDark ? Colors.grey.shade800 : Colors.grey.shade50;
  }
}
