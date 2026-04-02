import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sijilli/core/constants/app_colors.dart';
import 'package:sijilli/models/appointment.dart';
import 'package:sijilli/features/home/screens/public_profile_screen.dart';
import 'package:sijilli/features/appointments/providers/appointment_provider.dart';
import 'package:sijilli/features/appointments/widgets/atomic/user_invitee_sheet.dart';
import 'package:sijilli/core/constants/app_dimens.dart';
import 'package:sijilli/features/appointments/widgets/cards/appointment_card_policy.dart';
import 'package:sijilli/core/widgets/pulse_avatar.dart';
import 'package:sijilli/features/appointments/widgets/sheets/appointment_details_sheet.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';

class StandardPolicy extends AppointmentCardPolicy {
  StandardPolicy(super.appointment, super.context, {super.customOnTap});

  InvitationStatus get _invStatus => appointment.currentUserInvitation?.status ?? InvitationStatus.pending;
  bool get _isHost => appointment.hostId == (appointment.currentUserInvitation?.userId ?? '');

  @override
  Color get mainStatusColor {
    // Standard color for all states
    if (_invStatus == InvitationStatus.pending) return Colors.grey.shade400; // Pending is grey
    return AppColors.primary;
  }

  @override
  Color get borderColor {
    if (appointment.isNow) return AppColors.appointmentCardBorderNow;
    if (appointment.isUpcoming || appointment.isFuture) return AppColors.appointmentCardBorderUpcoming;
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.grey.shade700 : AppColors.appointmentCardBorderPast;
  }

  @override
  double get borderWidth => AppDimens.appointmentCardBorderWidth;

  @override
  Color get cardColor {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_invStatus == InvitationStatus.pending && !appointment.isDeleted && !_isHost) {
      return isDark 
          ? AppColors.alert.withValues(alpha: 0.15) 
          : AppColors.alertLight.withValues(alpha: 0.12);
    }
    return isDark ? AppColors.darkCardBackground : AppColors.appointmentCardBackground;
  }

  @override
  Color get shadowColor => Colors.transparent;

  @override
  double get elevation => 0;

  @override
  Color get iconColor {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.grey.shade400 : Colors.grey.shade500;
  }

  @override
  Color get statusCapsuleBorderColor => appointment.isNow 
      ? AppColors.primary 
      : (appointment.isUrgent ? AppColors.alert : mainStatusColor);

  @override
  String get hostName => appointment.host?.name ?? context.l10n.hostNameDefault;

  @override
  Color get hostNameColor {
    // 🔒 FINAL LOGIC: MATCHING CARD AVATAR RING EXACTLY
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
  Color get statusCapsuleBackgroundColor {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (appointment.isNow) return AppColors.primary;
    if (appointment.isUrgent) return AppColors.alert.withValues(alpha: isDark ? 0.2 : 0.1);
    return mainStatusColor.withValues(alpha: isDark ? 0.15 : 0.05);
  }

  @override
  Color get statusCapsuleTextColor => appointment.isNow ? Colors.white : (appointment.isUrgent ? AppColors.alert : mainStatusColor);

  @override
  String get guestActionText => context.l10n.hostAction;
  
  @override
  IconData? get guestActionIcon => null;

  @override
  bool get canInviteGuest => true;

  @override
  VoidCallback? get onCardTap => customOnTap ?? () {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AppointmentDetailsSheet(appointment: appointment),
    );
  };

  @override
  VoidCallback? get onHostTap => () {
    Navigator.push(context, MaterialPageRoute(builder: (context) => PublicProfileScreen(usernameOrId: appointment.hostId)));
  };

  @override
  VoidCallback? get onGuestTap => null;

  @override
  VoidCallback? get onGuestActionTap => () {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => UserInviteeSheet(
        appointment: appointment,
        onUserSelected: (user) {
          Navigator.pop(context);
          context.read<AppointmentProvider>().inviteGuest(appointment.id, user.id);
        },
      ),
    );
  };

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
    
    // In StandardPolicy, the avatar is generally the Host.
    // The Host is implicitly "Accepted" and part of an active/upcoming appointment.
    // We should not drop the host's styling to AvatarStatus.none just because the 
    // *viewer's* currentUserInvitation is pending.
    return AvatarStatus.upcoming;
  }
}
