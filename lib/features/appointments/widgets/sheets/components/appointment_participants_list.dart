import 'package:flutter/material.dart';
import 'package:sijilli/core/constants/app_colors.dart';
import 'package:sijilli/core/constants/app_dimens.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';
import 'package:sijilli/models/appointment.dart';
import 'package:sijilli/core/widgets/pulse_avatar.dart';
import 'package:sijilli/core/utils/app_date_formatter.dart';
import 'package:sijilli/features/articles/screens/article_details_screen.dart';

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
        Builder(
          builder: (context) {
            final hostP = participants?.firstWhere(
              (p) => p.userId == hostId, 
              orElse: () => Invitation(id: '', appointmentId: '', userId: '', status: InvitationStatus.accepted)
            );
            
            AvatarStatus hostAvatarStatus = AvatarStatus.upcoming;
            if (hostP?.status == InvitationStatus.deletedAfterAccept) {
              hostAvatarStatus = viewerStatus == InvitationStatus.accepted ? AvatarStatus.deleted : AvatarStatus.none;
            }

            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: PulseAvatar(
                imageUrl: hostAvatar != null && hostAvatar!.isNotEmpty ? hostAvatar : null,
                size: 40,
                status: hostAvatarStatus, 
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 0.5),
                    ),
                    child: Text(
                      context.l10n.detailsOrganizer,
                      style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (createdAt != null)
                      Text(
                        context.l10n.detailsCreatedBy(_formatTimelineDate(createdAt!.toLocal(), context)),
                        style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 11, height: 1.4),
                      ),
                    if (hostP?.deletedAt != null)
                      Text(
                        context.l10n.detailsDeletedAt(_formatTimelineDate(hostP!.deletedAt!.toLocal(), context)),
                        style: const TextStyle(color: Colors.red, fontSize: 11, height: 1.4, fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
              ),
              trailing: (hostP?.linkedArticle != null && hostP!.linkedArticle!.isPublished)
                  ? IconButton(
                      icon: const Icon(Icons.article_rounded, color: AppColors.primary),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ArticleDetailsScreen(article: hostP.linkedArticle!),
                          ),
                        );
                      },
                    )
                  : null,
            );
          },
        ),

        // 2. Guests
        if (guests.isNotEmpty) ...[
          ...guests.map((p) {
             AvatarStatus status = AvatarStatus.none;
             if (p.status == InvitationStatus.accepted) status = AvatarStatus.upcoming;
             else if (p.status == InvitationStatus.declined || p.status == InvitationStatus.deletedAfterAccept) status = AvatarStatus.deleted;
             
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
                p.user?.name ?? p.invitedName ?? context.l10n.detailsGuest,
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 14),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: _buildGuestStatusTimeline(p, context),
              ),
              trailing: (p.linkedArticle != null && p.linkedArticle!.isPublished)
                  ? IconButton(
                      icon: const Icon(Icons.article_rounded, color: AppColors.primary),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ArticleDetailsScreen(article: p.linkedArticle!),
                          ),
                        );
                      },
                    )
                  : null,
            );
          }).toList(),
        ],
      ],
    );
  }

  Widget _buildGuestStatusTimeline(Invitation invitation, BuildContext context) {
    final acceptedAt = invitation.acceptedAt?.toLocal();
    final deletedAt = invitation.deletedAt?.toLocal() ?? invitation.declinedAt?.toLocal();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (invitation.status == InvitationStatus.pending)
          Text(context.l10n.detailsPending, style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 11)),
        
        if (acceptedAt != null)
          Text(
            context.l10n.detailsAcceptedAt(_formatTimelineDate(acceptedAt, context)),
            style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 11),
          ),
          
        if (deletedAt != null)
          Row(
            children: [
              Text(
                context.l10n.detailsDeletedAt(_formatTimelineDate(deletedAt, context)),
                style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              if (acceptedAt != null) ...[
                const SizedBox(width: 8),
                Builder(
                  builder: (context) {
                    final duration = deletedAt.difference(acceptedAt);
                    if (duration.inMinutes <= 0) return const SizedBox.shrink();
                    final durationStr = AppDateFormatter.formatDuration(duration, context.l10n.localeName, context.l10n);
                    return Text(
                      context.l10n.detailsStayDuration(durationStr),
                      style: TextStyle(color: AppColors.getTextSecondary(context).withValues(alpha: 0.7), fontSize: 10),
                    );
                  }
                ),
              ],
            ],
          ),

        if (invitation.status == InvitationStatus.accepted && isPast && deletedAt == null)
          Text(context.l10n.detailsDone, style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
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
