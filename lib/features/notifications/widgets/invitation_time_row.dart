import 'package:flutter/material.dart';
import '../../../models/appointment.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/utils/app_date_formatter.dart';
import '../../../core/extensions/context_l10n.dart';

class InvitationTimeRow extends StatelessWidget {
  final Appointment appointment;
  final InvitationStatus status;

  const InvitationTimeRow({
    super.key,
    required this.appointment,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark 
            ? Colors.white.withValues(alpha: 0.05) 
            : (status == InvitationStatus.pending ? Colors.white.withValues(alpha: 0.95) : Colors.grey.shade50),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: isDark 
              ? Colors.white.withValues(alpha: 0.1) 
              : (status == InvitationStatus.pending ? Colors.transparent : Colors.grey.shade200)
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.calendar_today_outlined, 
            size: 14, 
            color: isDark 
                ? Colors.grey.shade500 
                : (status == InvitationStatus.pending ? Colors.black54 : Colors.grey.shade500),
          ),
          const SizedBox(width: 8),
          // Dynamic Date Text
          Expanded(
            child: Builder(
              builder: (context) {
                final hijriOffset = appointment.contextAdjustment;

                // Use Central Strategy
                final locale = Localizations.localeOf(context).languageCode;
                final strategy = AppDateFormatter.formatAppointmentDateStrategy(appointment, hijriOffset, locale);
                
                // Determine Text
                // If Multi-day (>= 24 hours)
                final duration = appointment.duration;
                if (duration >= 1440) {
                   final days = (duration / 1440).ceil();
                   final fullDate = '${strategy.dayName}, ${strategy.primaryDate}';
                   
                   final textColor = isDark 
                      ? Colors.grey.shade300 
                      : (status == InvitationStatus.pending ? Colors.black87 : Colors.grey.shade700);

                   return Text(
                     locale == 'ar' 
                       ? AppDateFormatter.toEasternArabicDigits('$fullDate ($days ${context.l10n.days})')
                       : '$fullDate ($days ${context.l10n.days})',
                     style: TextStyle(
                       fontSize: 13, 
                       fontWeight: FontWeight.bold,
                       color: textColor,
                     ),
                     maxLines: 1,
                     overflow: TextOverflow.ellipsis,
                     textAlign: TextAlign.center,
                   );
                }

                // Single Day
                final timeStr = AppDateFormatter.formatTime12h(appointment.startAt.toLocal(), locale);
                final fullDateStr = '${strategy.dayName} ${strategy.primaryDate}  $timeStr';

                final textColor = isDark 
                      ? Colors.grey.shade300 
                      : (status == InvitationStatus.pending ? Colors.black87 : Colors.grey.shade700);

                return Text(
                  locale == 'ar' ? AppDateFormatter.toEasternArabicDigits(fullDateStr) : fullDateStr,
                   style: TextStyle(
                    fontSize: 13, 
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                  maxLines: 1, 
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                );
              }
            ),
          ),

          // Recurrence Badge (Unified Style)
          if (appointment.recurrenceType != null &&
              appointment.recurrenceType != 'none' &&
              (appointment.recurrenceCount ?? 0) > 1) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(AppDimens.radiusCircle),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Text(
                Localizations.localeOf(context).languageCode == 'ar'
                    ? AppDateFormatter.toEasternArabicDigits('${appointment.recurrenceIndex ?? 1}/${appointment.recurrenceCount}')
                    : '${appointment.recurrenceIndex ?? 1}/${appointment.recurrenceCount}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
