import 'package:flutter/material.dart';
import 'package:sijilli/core/constants/app_colors.dart';
import 'package:sijilli/models/appointment.dart';
import 'package:sijilli/core/constants/app_dimens.dart';
import 'package:sijilli/features/appointments/widgets/cards/appointment_card_policy.dart';
import 'package:sijilli/core/widgets/pulse_avatar.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';
import 'package:provider/provider.dart';
import 'package:sijilli/features/auth/providers/auth_provider.dart';
import 'package:sijilli/features/profile/providers/moderation_provider.dart';
import 'package:sijilli/features/appointments/providers/appointment_provider.dart';
import 'package:sijilli/features/add/screens/add_event_screen.dart';
import 'package:sijilli/core/widgets/auth_wrapper.dart';
import 'package:sijilli/core/widgets/sheets/app_action_sheet.dart';
import 'package:sijilli/core/providers/settings_provider.dart';
class PublicPolicy extends AppointmentCardPolicy {
  PublicPolicy(super.appointment, super.context, {super.customOnTap});

  @override
  Color get mainStatusColor {
    final invStatus = appointment.currentUserInvitation?.status ?? InvitationStatus.accepted;
    if (invStatus == InvitationStatus.deletedAfterAccept || appointment.isUserDeleted) return Colors.red;
    if (appointment.isCancelled) return Colors.grey.shade400;
    return AppColors.primary;
  }

  @override
  Color get borderColor {
    // Removed isCancelled/isUserDeleted check to normalize appearance
    if (appointment.isNow) return AppColors.appointmentCardBorderNow;
    if (appointment.isUpcoming || appointment.isFuture) return AppColors.appointmentCardBorderUpcoming;
    return AppColors.appointmentCardBorderPast;
  }

  @override
  double get borderWidth => AppDimens.appointmentCardBorderWidth;

  @override
  Color get cardColor => Theme.of(context).brightness == Brightness.dark 
      ? AppColors.darkCardBackground 
      : AppColors.appointmentCardBackground;

  @override
  Color get shadowColor => Colors.transparent;

  @override
  double get elevation => 0;

  @override
  String get hostName => appointment.host?.name ?? context.l10n.user;

  @override
  Color get hostNameColor {
    // 🔒 FINAL LOGIC: MATCHING CARD AVATAR RING EXACTLY
    // PublicPolicy 'mainStatusColor' is already almost aligned, but let's be explicit like StandardPolicy
    // to avoid any drift.
    final status = hostAvatarStatus;
    switch (status) {
      case AvatarStatus.deleted:
        return AppColors.warning; // Red
      case AvatarStatus.active:
      case AvatarStatus.upcoming:
        return AppColors.primary; // Blue
      case AvatarStatus.none:
      default:
        return Colors.grey.shade500; // Grey
    }
  }

  @override
  Color get iconColor => Colors.grey.shade500;

  @override
  Color get statusCapsuleBorderColor => appointment.isNow 
      ? AppColors.primary 
      : (appointment.isUrgent ? AppColors.alert : mainStatusColor);

  @override
  Color get statusCapsuleBackgroundColor => appointment.isNow 
      ? AppColors.primary 
      : (appointment.isUrgent ? AppColors.alert.withValues(alpha: 0.1) : mainStatusColor.withValues(alpha: 0.05));

  @override
  Color get statusCapsuleTextColor => appointment.isNow ? Colors.white : (appointment.isUrgent ? AppColors.alert : mainStatusColor);

  @override
  String get guestActionText => context.l10n.hostAction;
  
  @override
  IconData? get guestActionIcon => null;

  @override
  bool get canInviteGuest => false;

  @override
  VoidCallback? get onCardTap => customOnTap ?? () {
    final auth = context.read<AuthProvider>();
    if (auth.user == null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AuthWrapper()),
      );
      return;
    }
    final moderation = context.read<ModerationProvider>();
    final appointmentProvider = context.read<AppointmentProvider>();
    
    final isOwner = appointment.hostId == auth.user?.id;
    final isAdmin = auth.user?.isAdmin == true;
    final canDelete = isOwner || isAdmin;
    final isBookmarked = appointment.currentUserInvitation?.postStatus == PostStatus.bookmarked;

    AppActionSheet.show(
      context,
      actions: [
        AppActionItem(
          label: context.l10n.detailsClone,
          icon: Icons.copy_rounded,
          onTap: () {
            final stripped = Appointment(
              id: '',
              title: appointment.title,
              hostId: '', 
              startAt: appointment.startAt,
              date: appointment.date,
              time: appointment.time,
              dateType: appointment.dateType,
              hijriDate: appointment.hijriDate,
              hijriMonth: appointment.hijriMonth,
              duration: appointment.duration,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddEventScreen(initialAppointment: stripped),
              ),
            );
          },
        ),
        AppActionItem(
          label: isBookmarked ? 'إلغاء الحفظ' : context.l10n.save,
          icon: isBookmarked ? Icons.bookmark_added_rounded : Icons.bookmark_border_rounded,
          onTap: () async {
            if (auth.user == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.l10n.pleaseLoginFirst)),
              );
              return;
            }
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
            label: context.l10n.detailsDeleteTitleHost,
            icon: Icons.delete_outline,
            isDestructive: true,
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: Text(context.l10n.detailsDeleteTitleHost),
                  content: Text(context.l10n.detailsDeleteConfirmHost),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(context.l10n.cancel)),
                    TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(context.l10n.delete, style: const TextStyle(color: Colors.red))),
                  ],
                ),
              );
              if (confirm == true && context.mounted) {
                await appointmentProvider.deleteInvitation(appointment.id);
                if (context.mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.appointmentCancelled), backgroundColor: AppColors.success));
                }
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
  };

  @override
  VoidCallback? get onHostTap => () {}; // Explicitly No-Op (Disable Navigation)

  @override
  VoidCallback? get onGuestTap => () {}; // Explicitly No-Op (Disable Navigation)

  @override
  VoidCallback? get onGuestActionTap => null;

  @override
  AvatarStatus get hostAvatarStatus {
    if (appointment.isUserDeleted || 
        appointment.isDeleted || 
        appointment.isCancelled) {
      return AvatarStatus.deleted;
    }
    
    if (appointment.isNow) {
      return AvatarStatus.active;
    }
    
    // In PublicProfile, the avatar is always the Host.
    // The Host is implicitly "Accepted" and part of an active/upcoming appointment.
    // We should not rely on the *viewer's* currentUserInvitation status to color the *Host's* ring.
    return AvatarStatus.upcoming;
  }
  
  @override
  bool get showLocation {
    final auth = context.read<AuthProvider>();
    if (auth.user == null) return false;
    try {
      return Provider.of<SettingsProvider>(context, listen: false).showLocationInfo;
    } catch (_) {
      return true;
    }
  }

  @override
  bool get canReport => false;
}
