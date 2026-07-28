import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimens.dart';
import '../../../../core/widgets/pulse_avatar.dart';
import '../../../../models/appointment.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../profile/providers/moderation_provider.dart';
import '../../../home/screens/public_profile_screen.dart';
import 'appointment_card_helper.dart';
import 'appointment_card_policy.dart';
import '../atomic/appointment_privacy_badge.dart';
import '../atomic/interaction_capsule.dart';
import '../atomic/now_pulse_capsule.dart';
import '../../../../core/widgets/sheets/app_action_sheet.dart';
import '../atomic/guest_capsule.dart';
import '../atomic/appointment_detail_item.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';
import 'package:sijilli/core/utils/app_date_formatter.dart';
import 'package:sijilli/features/appointments/providers/appointment_provider.dart';

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

    return Container(
      margin: policy.margin,
      child: Material(
        elevation: appointment.isNow ? AppDimens.appointmentCardElevationNow : policy.elevation,
        shadowColor: Colors.black.withValues(alpha: 0.12),
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
            onLongPress: () {
              final auth = context.read<AuthProvider>();
              final moderation = context.read<ModerationProvider>();
              final isOwner = appointment.hostId == auth.user?.id;
              final isAdmin = auth.user?.isAdmin == true;
              // canDeleteFromLongPress = false في الصفحات العامة (PublicPolicy, FeaturedPolicy)
              // لمنع أي مستخدم من حذف سجلات الآخرين عبر اللمس المطول
              final canDelete = (isOwner || isAdmin) && policy.canDeleteFromLongPress;
              
              if (!canDelete && !policy.canReport) return;

              final isBookmarked = appointment.currentUserInvitation?.postStatus == PostStatus.bookmarked;
              AppActionSheet.show(
                context,
                actions: [
                  AppActionItem(
                    label: isBookmarked ? 'إلغاء الحفظ' : context.l10n.save,
                    icon: isBookmarked ? Icons.bookmark_added_rounded : Icons.bookmark_border_rounded,
                    onTap: () async {
                      final appointmentProvider = context.read<AppointmentProvider>();
                      final success = await appointmentProvider.toggleBookmark(appointment, auth.user!);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(success ? 'تم الحفظ في المحفوظات' : 'تمت الإزالة من المحفوظات'),
                            backgroundColor: AppColors.primary,
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
                  if (canDelete)
                    AppActionItem(
                      label: context.l10n.delete,
                      icon: Icons.delete_outline,
                      isDestructive: true,
                      onTap: () async {
                        final hasAnyAcceptedGuest = appointment.participants?.any((p) => p.userId != appointment.hostId && p.status == InvitationStatus.accepted) ?? false;
                        final showHostWarning = isOwner && !hasAnyAcceptedGuest;

                        final String titleText;
                        final String confirmText;

                        if (showHostWarning) {
                          titleText = context.l10n.detailsDeleteTitleHost;
                          confirmText = context.l10n.detailsDeleteConfirmHost;
                        } else {
                          final isAr = context.l10n.localeName == 'ar';
                          titleText = isAr ? 'حذف الموعد' : 'Delete Appointment';
                          confirmText = isAr 
                              ? 'هذا قرار نهائي، سوف يؤدي إلى حذف سجل الموعد من صفحتك الشخصية.\nهل أنت متأكد؟'
                              : 'This is a final decision, it will lead to deleting the appointment record from your personal page.\nAre you sure?';
                        }

                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            title: Text(titleText),
                            content: Text(confirmText),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(context.l10n.cancel)),
                              TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(context.l10n.delete, style: const TextStyle(color: Colors.red))),
                            ],
                          ),
                        );
                        if (confirm == true && context.mounted) {
                          context.read<AppointmentProvider>().deleteInvitation(appointment.id);
                        }
                      },
                    )
                  else
                    AppActionItem(
                      label: context.l10n.reportAppointment,
                      icon: Icons.report_problem_outlined,
                      isDestructive: true,
                      onTap: () async {
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
                        if (reason != null && reason.isNotEmpty && context.mounted) {
                          await moderation.reportContent(
                            subjectType: 'appointment',
                            subjectId: appointment.id,
                            reason: reason,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.reportSent)));
                          }
                        }
                      },
                    ),
                ],
              );
            },
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
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
    
    Color textColor = isDark ? Colors.blue.shade300 : Colors.blue.shade700;
    Color bgColor = isDark ? Colors.blue.shade900.withValues(alpha: 0.3) : Colors.blue.shade50;
    Color borderColor = isDark ? Colors.blue.shade300.withValues(alpha: 0.5) : Colors.blue.shade300; 
    FontWeight fontWeight = FontWeight.w600;

    if (appointment.isUrgent) {
      textColor = isDark ? Colors.orange.shade300 : Colors.orange.shade800;
      bgColor = isDark ? Colors.orange.shade900.withValues(alpha: 0.3) : Colors.orange.shade50;
      borderColor = isDark ? Colors.orange.shade300.withValues(alpha: 0.5) : Colors.orange.shade300.withValues(alpha: 0.5);
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

    final statusCapsule = InteractionCapsule(
      borderColor: borderColor,
      borderOpacity: appointment.isNow ? 0.0 : 1.0,
      backgroundColor: bgColor,
      boxShadow: appointment.isNow ? null : [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
      child: Text(
        AppointmentCardHelper.getRemainingTimeText(appointment, context), 
        maxLines: 1,
        softWrap: false,
        style: TextStyle(
          fontSize: 13, 
          color: textColor,
          fontWeight: fontWeight,
        ),
      ),
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Left side (Privacy + Timer) - Stays as small as needed
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (policy.showPrivacyCapsule) ...[
              AppointmentPrivacyBadge(appointment: appointment),
              const SizedBox(width: 4),
            ],
            appointment.isNow ? NowPulseCapsule(child: statusCapsule) : statusCapsule,
          ],
        ),
        const SizedBox(width: 8),
        // Right side (Menu + Guest) - Hugs content but shrinks if needed
        Flexible(
          fit: FlexFit.loose,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                  child: Builder(
                    key: ValueKey(appointment.participants?.length ?? 0),
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
                        final moderation = context.read<ModerationProvider>();
                        if (moderation.isUserBlocked(firstGuest.userId)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('هذا الحساب غير متاح حالياً')),
                          );
                          return;
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PublicProfileScreen(usernameOrId: firstGuest.userId),
                          ),
                        );
                      },
                    );
                  }
                ),
              ),
            ),
            ],
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
    
    // Scale vertical gaps based on system text scale to prevent ugly gaps on smaller fonts
    final textScale = MediaQuery.textScaleFactorOf(context).clamp(0.7, 1.3);
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
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
                    height: 1.1, 
                    color: policy.hostNameColor, 
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(height: 8 * textScale),
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
              SizedBox(height: 12 * textScale),
              
              if (appointment.hasLocation && policy.showLocation) ...[
                AppointmentDetailItem(
                  icon: Icons.location_on, 
                  text: appointment.smartLocation!,
                  color: policy.iconColor == Colors.red ? Colors.red : null,
                ),
                SizedBox(height: 2 * textScale),
              ],

              _buildTimeRow(appointment, context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimeRow(Appointment appointment, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locale = Localizations.localeOf(context).languageCode;
    
    final datePart = appointment.duration > 1440 
        ? AppointmentCardHelper.formatDateText(appointment, context, forceYear: false)
        : AppointmentCardHelper.formatDateText(appointment, context, forceYear: true);
        
    final timePart = appointment.duration > 1440
        ? context.l10n.daysLeft((appointment.duration / 1440).ceil())
        : (appointment.isAllDay 
            ? context.l10n.durationAllDay 
            : AppDateFormatter.formatTime12h(appointment.fullDateTime, locale));

    final displayTime = locale == 'ar' ? AppDateFormatter.toEasternArabicDigits(timePart) : timePart;
    
    final iconColor = policy.iconColor == Colors.red ? Colors.red : (isDark ? Colors.grey.shade400 : Colors.grey.shade600);
    final dateColor = isDark ? Colors.grey.shade300 : Colors.grey.shade700;
    final timeColor = isDark ? Colors.white : Colors.black;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(Icons.access_time_filled, size: 16, color: iconColor),
        const SizedBox(width: 6),
        Flexible(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Logic for "Smart Truncation":
              // If space is tight, we use the short version (م/ص)
              // Otherwise, we use the full version (مساءً/صباحاً)
              // Threshold is roughly based on character count and typical widths
              final bool isTight = constraints.maxWidth < 180; // Estimated threshold for card layout
              
              String finalTimePart = displayTime;
              if (isTight && locale == 'ar') {
                finalTimePart = displayTime
                  .replaceAll('صباحًا', 'ص')
                  .replaceAll('ظهرًا', 'ظ')
                  .replaceAll('عصرًا', 'ع')
                  .replaceAll('مساءً', 'م')
                  .replaceAll('ليلاً', 'ل');
              }

              return RichText(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 13, 
                    height: 1.2,
                    fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
                  ),
                  children: [
                    TextSpan(
                      text: datePart,
                      style: TextStyle(color: dateColor),
                    ),
                    const TextSpan(text: '      '), 
                    TextSpan(
                      text: finalTimePart,
                      style: TextStyle(
                        color: timeColor, 
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        if (appointment.recurrenceCount != null && appointment.recurrenceCount! > 1) ...[
          const SizedBox(width: 8),
          _buildRecurrenceIndicator(appointment, context),
        ],
      ],
    );
  }

  Widget _buildRecurrenceIndicator(Appointment appointment, BuildContext context) {
    return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.repeat, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            Localizations.localeOf(context).languageCode == 'ar'
                ? AppDateFormatter.toEasternArabicDigits('${appointment.recurrenceIndex ?? 1} ${context.l10n.recurrenceOf} ${appointment.recurrenceCount}')
                : '${appointment.recurrenceIndex ?? 1} ${context.l10n.recurrenceOf} ${appointment.recurrenceCount}',
            style: const TextStyle(
              fontSize: 12, 
              height: 1.2,
              fontWeight: FontWeight.w600, 
              color: AppColors.textSecondary,
            ),
          ),
        ],
    );
  }
}
