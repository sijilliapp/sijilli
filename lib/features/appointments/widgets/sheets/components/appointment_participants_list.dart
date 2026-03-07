import 'package:flutter/material.dart';
import 'package:sijilli/core/constants/app_colors.dart';
import 'package:sijilli/core/constants/app_dimens.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';
import 'package:sijilli/models/appointment.dart';
import 'package:sijilli/core/widgets/pulse_avatar.dart';
import 'package:sijilli/core/utils/app_date_formatter.dart';
import 'package:sijilli/l10n/app_localizations.dart';

class AppointmentParticipantsList extends StatelessWidget {
  final String? hostId;
  final String? hostName;
  final String? hostAvatar;
  final List<Invitation>? participants;
  final bool isPast;
  final DateTime? createdAt;
  final InvitationStatus? viewerStatus;

  const AppointmentParticipantsList({
    super.key,
    this.hostId,
    this.hostName,
    this.hostAvatar,
    this.participants,
    this.isPast = false,
    this.createdAt,
    this.viewerStatus,
  });

  @override
  Widget build(BuildContext context) {
    // Filter out host from participants to avoid duplication
    final guests = participants?.where((p) => p.userId != hostId).toList() ?? [];

    // Determine Host Status
    AvatarStatus hostStatus = AvatarStatus.upcoming; // Default Blue
    if (participants != null && hostId != null) {
       final hostP = participants!.firstWhere(
          (p) => p.userId == hostId, 
          orElse: () => Invitation(id: '', appointmentId: '', userId: '', status: InvitationStatus.accepted)
       );
       if (hostP.status == InvitationStatus.deletedAfterAccept) {
          if (viewerStatus == InvitationStatus.accepted) {
             hostStatus = AvatarStatus.deleted; // Red
          } else {
             hostStatus = AvatarStatus.none; // Grey
          }
       }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Unified Header
        Text(context.l10n.detailsParticipantsLabel, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.getTextPrimary(context))),
        const SizedBox(height: AppDimens.space),
        
        // 1. Host (Organizer)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: PulseAvatar(
            imageUrl: hostAvatar != null && hostAvatar!.isNotEmpty ? hostAvatar : null,
            size: 40,
            status: hostStatus, 
            showGlow: false,
            ringThickness: 2,
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  hostName ?? context.l10n.detailsHost, 
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              // Organizer Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.primary.withOpacity(0.5), width: 0.5),
                ),
                child: Text(
                  context.l10n.detailsOrganizer,
                  style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          subtitle: createdAt != null ? Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              context.l10n.detailsCreatedBy(_formatTimelineDate(createdAt!.toLocal(), context)),
              style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 11, height: 1.4),
            ),
          ) : null,
        ),

        // 2. Guests
        if (guests.isNotEmpty) ...[
          ...guests.map((p) {
             // Determine Status
             AvatarStatus status = AvatarStatus.none; // Default Grey
             if (p.status == InvitationStatus.accepted) status = AvatarStatus.upcoming; // Blue
             else if (p.status == InvitationStatus.declined) status = AvatarStatus.deleted; // Red
             
             return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: PulseAvatar(
                imageUrl: p.user?.getAvatarUrl('https://sijilli.pockethost.io', thumb: '100x100'),
                size: 40,
                status: status,
                showGlow: false,
                ringThickness: 2,
              ),
              title: Text(
                p.user?.name ?? context.l10n.detailsGuest,
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 14),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _getStatusText(p, context),
                  style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 11, height: 1.4),
                ),
              ),
            );
          }).toList(),
        ],
      ],
    );
  }

  String _getStatusText(Invitation invitation, BuildContext context) {
    if (invitation.status == InvitationStatus.pending) {
      return context.l10n.detailsPending;
    }

    final StringBuffer buffer = StringBuffer();
    final acceptedAt = invitation.acceptedAt?.toLocal();
    final deletedAt = invitation.deletedAt?.toLocal() ?? invitation.declinedAt?.toLocal();

    // 1. Accepted Time
    if (acceptedAt != null) {
      buffer.write(context.l10n.detailsAcceptedAt(_formatTimelineDate(acceptedAt, context)));
    }

    // 2. Deleted/Declined Time
    if (deletedAt != null) {
      if (buffer.isNotEmpty) buffer.write('   ');
      buffer.write(context.l10n.detailsDeletedAt(_formatTimelineDate(deletedAt, context)));

      // 3. Duration (Stayed)
      if (acceptedAt != null) {
         final duration = deletedAt.difference(acceptedAt);
         if (duration.inMinutes > 0) {
            final durationStr = AppDateFormatter.formatDuration(duration, context.l10n.localeName, context.l10n);

            if (buffer.isNotEmpty) buffer.write('  ');
            buffer.write(context.l10n.detailsStayDuration(durationStr));
         }
      }
    } 
    // 4. Completed (Accepted + Past + Not Deleted)
    else if (invitation.status == InvitationStatus.accepted && isPast) {
       if (buffer.isNotEmpty) {
          buffer.write('                                     ${context.l10n.detailsDone}'); 
       } else {
         buffer.write(context.l10n.detailsDone);
       }
    }

    return buffer.toString();
  }

  String _formatTimelineDate(DateTime date, BuildContext context) {
    // Format: 7:30pm 14-09
    final locale = context.l10n.localeName;
    // Time
    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? context.l10n.pm : context.l10n.am;
    
    // Date
    final day = date.day;
    final month = date.month.toString().padLeft(2, '0'); // Show number 01-12

    String result = '$hour:$minute$period $day-$month';
    if (locale == 'ar') result = AppDateFormatter.toEasternArabicDigits(result);
    return result;
  }
}
