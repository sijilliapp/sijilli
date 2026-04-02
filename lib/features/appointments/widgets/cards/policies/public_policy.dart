import 'package:flutter/material.dart';
import 'package:sijilli/core/constants/app_colors.dart';
import 'package:sijilli/models/appointment.dart';
import 'package:sijilli/core/constants/app_dimens.dart';
import 'package:sijilli/features/appointments/widgets/cards/appointment_card_policy.dart';
import 'package:sijilli/core/widgets/pulse_avatar.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';

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
  VoidCallback? get onCardTap => customOnTap ?? () {}; // Ensure ripple even if no action

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
}
