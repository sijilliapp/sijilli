import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimens.dart';
import '../../../../core/widgets/pulse_avatar.dart';
import '../../../../models/appointment.dart';
import '../../../../models/invitation.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../profile/providers/moderation_provider.dart';
import '../../../home/screens/public_profile_screen.dart';
import 'appointment_card_helper.dart';
import 'appointment_card_policy.dart';
import '../atomic/appointment_privacy_badge.dart';
import '../atomic/interaction_capsule.dart';
import '../atomic/guest_capsule.dart';
import '../atomic/appointment_detail_item.dart';
import 'package:sijilli/l10n/app_localizations.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';
import 'package:sijilli/core/utils/app_date_formatter.dart';

class BaseAppointmentCard extends StatelessWidget {
  final AppointmentCardPolicy policy;

  const BaseAppointmentCard({
    super.key,
    required this.policy,
  });

  @override
  Widget build(BuildContext context) {
    final appointment = policy.appointment;

    final category = appointment.currentUserInvitation?.categories;
    final categoryColor = category?.getColor();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: AppDimens.spaceS),
      child: Material(
        elevation: appointment.isNow ? AppDimens.appointmentCardElevationNow : policy.elevation,
        shadowColor: Colors.black.withOpacity(0.12),
        color: policy.cardColor,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: policy.borderColor, width: policy.borderWidth),
          ),
          child: InkWell(
            onTap: policy.onCardTap ?? () {}, // Ensure ripple even if no action
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _AppointmentCardHeader(policy: policy),
                  const SizedBox(height: 12),
                  _AppointmentCardBody(policy: policy),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppointmentCardHeader extends StatelessWidget {
  final AppointmentCardPolicy policy;
  const _AppointmentCardHeader({required this.policy});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appointment = policy.appointment;
    
    final bool isUnified = appointment.isPublic && 
        appointment.startAt.difference(DateTime.now()).inHours >= 24;

    Color textColor = isDark ? Colors.blue.shade300 : Colors.blue.shade700;
    Color bgColor = isDark ? Colors.blue.shade900.withOpacity(0.3) : Colors.blue.shade50;
    Color borderColor = isDark ? Colors.blue.shade300.withOpacity(0.5) : Colors.blue.shade300; 
    FontWeight fontWeight = FontWeight.w600;

    if (appointment.isUrgent) {
      textColor = isDark ? Colors.orange.shade300 : Colors.orange.shade800;
      bgColor = isDark ? Colors.orange.shade900.withOpacity(0.3) : Colors.orange.shade50;
      borderColor = isDark ? Colors.orange.shade300.withOpacity(0.5) : Colors.orange.shade300.withOpacity(0.5);
    } else if (appointment.isPast) {
      textColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
      bgColor = isDark ? Colors.grey.shade800 : Colors.grey.shade50;
      borderColor = isDark ? Colors.grey.shade600 : Colors.grey.shade400;
    } else if (appointment.isNow) {
      textColor = Colors.white;
      bgColor = AppColors.primary;
      borderColor = Colors.transparent;
      fontWeight = FontWeight.bold;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            if (policy.showPrivacyCapsule) ...[
              AppointmentPrivacyBadge(appointment: appointment),
              const SizedBox(width: 4),
            ],
            InteractionCapsule(
              borderColor: borderColor,
              borderOpacity: 1.0,
              backgroundColor: bgColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!appointment.isNow)
                    Icon(appointment.isPast ? Icons.check_circle_outline : Icons.access_time, 
                         size: 10, color: textColor),
                  if (!appointment.isNow) const SizedBox(width: 4),
                  Text(
                    AppointmentCardHelper.getRemainingTimeText(appointment, context), 
                    style: TextStyle(
                      fontSize: 10, 
                      color: textColor,
                      fontWeight: fontWeight,
                    ),
                  ),
                ],
              ),
            ),
            if (appointment.hostId != Provider.of<AuthProvider>(context, listen: false).user?.id)
            Consumer<ModerationProvider>(
              builder: (context, moderation, _) {
                return SizedBox(
                  width: 24,
                  height: 24,
                  child: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_horiz, size: 20, color: AppColors.primary),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 120),
                    onSelected: (val) async {
                      if (val == 'report') {
                         final reason = await showDialog<String>(
                          context: context,
                          builder: (context) {
                            final controller = TextEditingController();
                            return AlertDialog(
                              title: Text(context.l10n.reportAppointment),
                              content: TextField(
                                controller: controller,
                                decoration: InputDecoration(hintText: context.l10n.reportReason),
                                maxLines: 3,
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.cancel)),
                                TextButton(onPressed: () => Navigator.pop(context, controller.text), child: Text(context.l10n.send)),
                              ],
                            );
                          },
                        );
                        if (reason != null && reason.isNotEmpty) {
                          await moderation.reportContent(
                            subjectType: 'appointment',
                            subjectId: appointment.id,
                            reason: reason,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.reportSent)));
                          }
                        }
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'report',
                        child: Row(
                          children: [
                            const Icon(Icons.report_problem_outlined, size: 18),
                            const SizedBox(width: 8),
                            Text(context.l10n.report, style: const TextStyle(fontSize: 14)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        Flexible(
          child: Builder(
            builder: (context) {
              var guests = appointment.participants?.where(
                (p) => p.userId != appointment.hostId && (
                  p.status != InvitationStatus.declined || 
                  appointment.isDeleted || 
                  appointment.isCancelled
                )
              ).toList() ?? [];

              if (appointment.isConfirmed) {
                final acceptedOnes = guests.where((p) => p.status == InvitationStatus.accepted).toList();
                if (acceptedOnes.isNotEmpty) {
                  guests = [acceptedOnes.first];
                }
              }

              if (guests.isEmpty) {
                if (policy.guestActionText.isEmpty) {
                  return const SizedBox.shrink();
                }
                return GuestCapsule(
                  name: policy.guestActionText,
                  status: InvitationStatus.pending,
                  icon: policy.guestActionIcon,
                  onTap: policy.onGuestActionTap,
                );
              }

              final firstGuest = guests.first;
              final extraCount = guests.length > 1 ? guests.length - 1 : null;

              return GuestCapsule(
                avatarUrl: firstGuest.user?.getAvatarUrl('https://sijilli.pockethost.io'), 
                name: firstGuest.user?.name ?? context.l10n.guest,
                status: firstGuest.status,
                extraGuests: extraCount,
                onTap: policy.onGuestTap ?? () {
                  if (firstGuest.userId != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PublicProfileScreen(usernameOrId: firstGuest.userId!),
                      ),
                    );
                  }
                },
              );
            }
          ),
        ),
      ],
    );
  }
}

class _AppointmentCardBody extends StatelessWidget {
  final AppointmentCardPolicy policy;
  const _AppointmentCardBody({required this.policy});

  @override
  Widget build(BuildContext context) {
    final appointment = policy.appointment;
    final category = appointment.currentUserInvitation?.categories;
    final categoryColor = category?.getColor();
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: InkWell(
            onTap: policy.onHostTap,
            borderRadius: BorderRadius.circular(22),
            child: PulseAvatar(
              imageUrl: appointment.host?.getAvatarUrl('https://sijilli.pockethost.io'),
              size: 46, 
              status: policy.hostAvatarStatus,
              showGlow: false, 
              ringThickness: 2.0, 
              gapThickness: 1.5,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: policy.onHostTap,
                child: Text(
                  policy.hostName,
                  style: TextStyle(
                    height: 1, 
                    color: policy.hostNameColor, 
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                appointment.title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).colorScheme.onSurface,
                  height: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              
              if (appointment.hasLocation) ...[
                AppointmentDetailItem(
                  icon: Icons.location_on, 
                  text: appointment.smartLocation!,
                  color: policy.iconColor == Colors.red ? Colors.red : null,
                ),
                const SizedBox(height: 6),
              ],

              AppointmentDetailItem(
                icon: Icons.access_time_filled, 
                text: AppointmentCardHelper.formatTimeText(appointment, context),
                color: policy.iconColor == Colors.red ? Colors.red : null,
                trailing: (appointment.recurrenceCount != null && appointment.recurrenceCount! > 1) 
                    ? _buildRecurrenceIndicator(appointment, context)
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecurrenceIndicator(Appointment appointment, BuildContext context) {
    return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.repeat, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            Localizations.localeOf(context).languageCode == 'ar'
                ? AppDateFormatter.toEasternArabicDigits('${appointment.recurrenceIndex ?? 1} ${context.l10n.recurrenceOf} ${appointment.recurrenceCount}')
                : '${appointment.recurrenceIndex ?? 1} ${context.l10n.recurrenceOf} ${appointment.recurrenceCount}',
            style: const TextStyle(
              fontSize: 12, 
              fontWeight: FontWeight.w600, 
              color: AppColors.textSecondary,
            ),
          ),
        ],
    );
  }
}
