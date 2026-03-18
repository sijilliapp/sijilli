import 'package:flutter/material.dart';
import 'package:sijilli/l10n/app_localizations.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/app_date_formatter.dart';
import '../../../../models/appointment.dart';
import '../../../../models/invitation.dart';
import '../../../../core/widgets/pulse_avatar.dart';
import '../../../auth/providers/auth_provider.dart';

class AppointmentCardHelper {
  static String formatTimeText(Appointment appointment, BuildContext context) {
    final durationMins = appointment.duration;
    
    if (durationMins > 1440) {
      final days = (durationMins / 1440).ceil();
      final daysLabel = context.l10n.daysLeft(days);
      
      final dateText = formatDateText(appointment, context, forceYear: false);
      return '$dateText | $daysLabel';
    }

    final dateText = formatDateText(appointment, context, forceYear: true);
    final locale = Localizations.localeOf(context).languageCode;
    
    String timeStr = appointment.isAllDay 
        ? '$dateText | ${context.l10n.durationAllDay}'
        : '$dateText | ${AppDateFormatter.formatTime12h(appointment.fullDateTime, locale)}';
    
    return locale == 'ar' ? AppDateFormatter.toEasternArabicDigits(timeStr) : timeStr;
  }

  static String formatDateText(Appointment appointment, BuildContext context, {bool forceYear = true}) {
    final adjustment = appointment.contextAdjustment;
    final locale = Localizations.localeOf(context).languageCode;

    final strategy = AppDateFormatter.formatAppointmentDateStrategy(appointment, adjustment, locale);

    if (appointment.dateType == 'hijri') {
       final parts = strategy.primaryDate.split(' ');
       String displayDate = strategy.primaryDate;
       if (!forceYear && parts.length >= 3 && strategy.primaryHijriYear != null) {
          try {
             final currentHYear = AppDateFormatter.getCurrentHijriYear();
             if (strategy.primaryHijriYear == currentHYear) {
                displayDate = parts.sublist(0, parts.length - 1).join(' ');
             }
          } catch (_) {}
       }
       
       String fullResult = '${strategy.dayName} $displayDate';
       return locale == 'ar' ? AppDateFormatter.toEasternArabicDigits(fullResult) : fullResult;
    }

    String result;
    if (forceYear) {
       result = AppDateFormatter.formatFullDate(appointment.date, locale);
    } else {
       result = AppDateFormatter.formatSmartDate(appointment.date, locale: locale);
    }
    
    return locale == 'ar' ? AppDateFormatter.toEasternArabicDigits(result) : result;
  }

  static AvatarStatus getAvatarStatus(Appointment appointment) {
    if (appointment.isDeleted || appointment.isCancelled) {
      return AvatarStatus.deleted;
    }
    
    final hostParticipant = appointment.participants?.firstWhere(
      (p) => p.userId == appointment.hostId, 
      orElse: () => Invitation(id: '', appointmentId: '', userId: '', status: InvitationStatus.accepted)
    );

    if (hostParticipant?.status == InvitationStatus.deletedAfterAccept) {
       if (appointment.hostId == appointment.currentUserInvitation?.userId) {
          return AvatarStatus.deleted; 
       }
       final myStatus = appointment.currentUserInvitation?.status;
       if (myStatus == InvitationStatus.accepted) {
         return AvatarStatus.deleted; 
       }
       return AvatarStatus.none; 
    }

    if (appointment.isNow) {
      return AvatarStatus.active;
    }
    
    final myStatus = appointment.currentUserInvitation?.status;
    if (myStatus == InvitationStatus.pending) {
      return AvatarStatus.none;
    }
    
    return AvatarStatus.upcoming;
  }

  static Color getHostNameColor(BuildContext context, AvatarStatus status) {
    switch (status) {
      case AvatarStatus.deleted:
        return AppColors.warning;
      case AvatarStatus.upcoming:
      case AvatarStatus.active:
        return AppColors.primary;
      case AvatarStatus.none:
      default:
        return AppColors.getTextSecondary(context);
    }
  }

  static String getRemainingTimeText(Appointment appointment, BuildContext context) {
    final result = _getRawRemainingTimeText(appointment, context);
    final locale = Localizations.localeOf(context).languageCode;
    return locale == 'ar' ? AppDateFormatter.toEasternArabicDigits(result) : result;
  }

  static String _getRawRemainingTimeText(Appointment appointment, BuildContext context) {
    if (appointment.isPast) return context.l10n.statusPast;
    if (appointment.isNow) return context.l10n.now;

    final now = DateTime.now().toUtc();
    final diff = appointment.startAt.difference(now);

    if (diff.isNegative) return context.l10n.now;

    // Years
    final years = (diff.inDays / 365).floor();
    if (years >= 1) return context.l10n.inYear;

    // Months
    final months = (diff.inDays / 30).floor();
    if (months >= 1) return context.l10n.inMonths(months);

    // Days
    final days = diff.inDays;
    if (days >= 1) return context.l10n.inDays(days);

    // Hours
    final hours = diff.inHours;
    if (hours >= 1) return context.l10n.withinHours(hours);

    // Minutes
    final minutes = diff.inMinutes;
    if (minutes >= 1) return context.l10n.withinMinutes(minutes);

    return context.l10n.momentsLeft;
  }

  static String getStatusText(Appointment appointment, BuildContext context) {
    if (appointment.isCancelled) return context.l10n.statusPast;
    if (appointment.isDeleted) return context.l10n.statusDeleted;
    if (appointment.isArchived) return context.l10n.statusArchived;
    if (appointment.isNow) return context.l10n.statusActiveNow;
    if (appointment.isPast) return context.l10n.statusPast;
    if (appointment.isUpcoming) return context.l10n.statusUpcoming;
    return context.l10n.statusFuture;
  }
}
