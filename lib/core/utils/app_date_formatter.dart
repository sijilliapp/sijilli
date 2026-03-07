import 'package:intl/intl.dart';
import 'package:hijri/hijri_calendar.dart';
import '../../l10n/app_localizations.dart';
import '../../models/appointment.dart';

class DateStrategyResult {
  final String dayName;
  final String primaryDate;
  final String secondaryDate;
  final int? primaryHijriYear; // To avoid importing HijriCalendar in UI

  DateStrategyResult({
    required this.dayName,
    required this.primaryDate,
    required this.secondaryDate,
    this.primaryHijriYear,
  });
}

class AppDateFormatter {
  // Prevent instantiation
  AppDateFormatter._();

  /// Format: 08 Jan 2026
  static String formatMediumDate(DateTime date, [String locale = 'ar']) {
    return DateFormat('dd MMM yyyy', locale).format(date);
  }

  /// Format: 8/01/2026
  static String formatShortDate(DateTime date, [String locale = 'ar']) {
    return DateFormat('d/MM/yyyy', locale).format(date);
  }

  /// Format: 10:30 AM (12-hour, no leading zero)
  static String formatTime(DateTime date, [String locale = 'ar']) {
    return DateFormat('h:mm a', locale).format(date);
  }

  /// Format: 10:30 ص (Arabic)
  static String formatTime12h(DateTime date, [String locale = 'ar']) {
    // Ensuring Arabic AM/PM
    return DateFormat('h:mm a', locale).format(date);
  }

  /// Format: Thursday, 08 Jan
  static String formatDayDate(DateTime date, [String locale = 'ar']) {
    return DateFormat('EEEE, dd MMM', locale).format(date);
  }

  /// Format: الخميس 17 ديسمبر 2026
  static String formatFullDate(DateTime date, [String locale = 'ar']) {
    return DateFormat('EEEE dd MMMM yyyy', locale).format(date);
  }

  /// Format: الخميس 17 ديسمبر 2026 - 08:30 مساءً
  static String formatFullDateTime(DateTime date, [String locale = 'ar']) {
    return '${formatFullDate(date, locale)}  -  ${formatTime12h(date, locale)}';
  }

  /// Relative time (e.g., "منذ ساعة", "منذ يومين")
  static String timeAgo(DateTime date, String locale, [AppLocalizations? l10n]) {
    final now = DateTime.now();
    final diff = now.difference(date);

    // 1. Use Localized Strings if Provided
    if (l10n != null) {
      String result;
      if (diff.inSeconds < 60) {
        result = l10n.timeAgoJustNow;
      } else if (diff.inMinutes < 60) {
        result = l10n.timeAgoMinutes(diff.inMinutes);
      } else if (diff.inHours < 24) {
        result = l10n.timeAgoHours(diff.inHours);
      } else if (diff.inDays < 7) {
        result = l10n.timeAgoDays(diff.inDays);
      } else {
        result = formatShortDate(date, locale);
      }
      return locale == 'ar' ? toEasternArabicDigits(result) : result;
    }

    // 2. Fallback to Hardcoded Strings if no l10n provided
    if (locale != 'ar') {
      if (diff.inSeconds < 60) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return formatShortDate(date, locale);
    }

    String result;
    if (diff.inSeconds < 60) {
      result = 'الآن';
    } else if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      if (m == 1) result = 'منذ دقيقة';
      else if (m == 2) result = 'منذ دقيقتين';
      else if (m <= 10) result = 'منذ $m دقائق';
      else result = 'منذ $m دقيقة';
    } else if (diff.inHours < 24) {
      final h = diff.inHours;
      if (h == 1) result = 'منذ ساعة';
      else if (h == 2) result = 'منذ ساعتين';
      else if (h <= 10) result = 'منذ $h ساعات';
      else result = 'منذ $h ساعة';
    } else if (diff.inDays < 7) {
      final d = diff.inDays;
      if (d == 1) result = 'منذ يوم';
      else if (d == 2) result = 'منذ يومين';
      else if (d <= 10) result = 'منذ $d أيام';
      else result = 'منذ $d يوماً';
    } else {
      result = formatShortDate(date, locale);
    }
    return locale == 'ar' ? toEasternArabicDigits(result) : result;
  }

  /// Calculate difference compatible with timeline requirements
  static String formatDuration(Duration duration, String locale, [AppLocalizations? l10n]) {
    if (l10n == null) {
      final days = duration.inDays;
      if (locale != 'ar') {
        if (days > 0) return '$days days';
        final hours = duration.inHours;
        if (hours > 0) return '$hours hours';
        return 'less than an hour';
      }

      String result;
      if (days > 0) {
        result = days == 1 
            ? 'يوم واحد' 
            : days == 2 
              ? 'يومين'
              : days <= 10 
                ? '$days أيام' 
                : '$days يوماً';
      } else {
        final hours = duration.inHours;
        if (hours > 0) {
          result = hours == 1
              ? 'ساعة واحدة'
              : hours == 2
                ? 'ساعتين'
                : hours <= 10
                  ? '$hours ساعات'
                  : '$hours ساعة';
        } else {
          result = 'أقل من ساعة';
        }
      }
      return locale == 'ar' ? toEasternArabicDigits(result) : result;
    }

    final days = duration.inDays;
    final hours = duration.inHours;

    String result;
    if (days > 0) {
      result = l10n.durationDays(days);
    } else if (hours > 0) {
      result = l10n.durationHours(hours);
    } else {
      result = l10n.durationLessThanHour;
    }

    return locale == 'ar' ? toEasternArabicDigits(result) : result;
  }

  /// Converts English digits to Eastern Arabic Digits (Hindi numerals)
  /// e.g. 123 -> ١٢٣
  static String toEasternArabicDigits(String input) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    for (int i = 0; i < english.length; i++) {
      input = input.replaceAll(english[i], arabic[i]);
    }
    return input;
  }

  /// Returns the current Hijri Year (for comparison/hiding year)
  static int getCurrentHijriYear() {
    HijriCalendar.setLocal('ar');
    return HijriCalendar.now().hYear;
  }

  // ---------------------------------------------------------------------------
  // 🔒 STRICT HIJRI CORRECTION STRATEGY (PRD COMPLIANT)
  // This is the SINGLE SOURCE OF TRUTH for date calculations.
  // ---------------------------------------------------------------------------
  static DateStrategyResult formatAppointmentDateStrategy(Appointment appointment, int adjustment, [String locale = 'ar']) {
    final isHijri = appointment.dateType == 'hijri';
    HijriCalendar.setLocal(locale);

    String dayName;
    String primaryDate = '';
    String secondaryDate;
    int? primaryHijriYear;

    if (isHijri) {
      // 1. Primary Date (Hijri) - FIXED DOCUMENT
      final stored = appointment.hijriDate;
      bool formatted = false;
      
      if (stored != null) {
        try {
           final parts = stored.replaceAll('/', '-').split('-');
           if (parts.length == 3) {
              final h = HijriCalendar();
              if (parts[0].length == 4) {
                h.hYear = int.parse(parts[0].trim());
                h.hMonth = int.parse(parts[1].trim());
                h.hDay = int.parse(parts[2].trim().split(' ')[0]);
              } else {
                h.hDay = int.parse(parts[0].trim());
                h.hMonth = int.parse(parts[1].trim());
                h.hYear = int.parse(parts[2].trim().split(' ')[0]);
              }
              // Fix: Use toFormat to ensure internal state is initialized and avoid LateInitializationError
              primaryDate = h.toFormat(locale == 'ar' ? 'd MMMM yyyy' : 'yyyy/MM/dd');
              primaryHijriYear = h.hYear;
              formatted = true;
           } else if (stored.contains(' ') && !stored.contains('-')) {
             primaryDate = stored;
             try {
                final yearPart = stored.trim().split(' ').last;
                primaryHijriYear = int.tryParse(yearPart);
             } catch (_) {}
             formatted = true;
           }
        } catch (_) {}
      }

      if (!formatted) {
         // Fallback: Fixed Document -> Calc from Gregorian WITH Adjustment
         // appointment.date is already physically shifted, so we add adjustment back to get the pure Hijri
         final hDate = HijriCalendar.fromDate(appointment.date.add(Duration(days: adjustment)));
         primaryDate = locale == 'ar' 
             ? '${hDate.hDay} ${hDate.longMonthName} ${hDate.hYear}'
             : '${hDate.hYear}/${hDate.hMonth}/${hDate.hDay}';
         primaryHijriYear = hDate.hYear;
      }

      // 2. Secondary Date (Gregorian) - NO ADDITIONAL ADJUSTMENT
      // The `appointment.date` is already the absolute physical execution date,
      // representing the true Gregorian equivalent of the fixed Hijri document at creation time.
      // Applying `-adjustment` here again would shift it away from physical reality.
      final adjustedGregorian = appointment.date;
      secondaryDate = DateFormat('d MMMM yyyy', locale).format(adjustedGregorian);

      // 3. Day Name - MUST REFLECT THE DISPLAYED GREGORIAN PREVIEW
      // Since Gregorian is secondary and is shifted by adjustment, the day name must shift to match it.
      dayName = DateFormat('EEEE', locale).format(adjustedGregorian);

    } else {
      // 1. Primary Date (Gregorian) - FIXED DOCUMENT
      primaryDate = DateFormat('d MMMM yyyy', locale).format(appointment.date);

      // 2. Secondary Date (Hijri) - ADJUSTED DIRECTLY
      // PRD: Primary Gregorian Fixed -> Secondary Hijri Direct Adjustment
      final adjustedDate = appointment.date.add(Duration(days: adjustment));
      final hDate = HijriCalendar.fromDate(adjustedDate);
      secondaryDate = locale == 'ar'
          ? '${hDate.hDay} ${hDate.longMonthName} ${hDate.hYear}'
          : '${hDate.hYear}/${hDate.hMonth}/${hDate.hDay}';
      primaryHijriYear = hDate.hYear;

      // 3. Day Name - REFLECTS REALITY (FIXED GREGORIAN)
      dayName = DateFormat('EEEE', locale).format(appointment.date);
    }

    return DateStrategyResult(
      dayName: dayName,
      primaryDate: primaryDate,
      secondaryDate: secondaryDate,
      primaryHijriYear: primaryHijriYear,
    );
  }

  // Legacy/Helper Methods (Can be deprecated or redirected)
  static String formatSmartDate(DateTime date, {bool isHijri = false, int adjustment = 0, String locale = 'ar'}) {
     if (!isHijri) return formatFullDate(date, locale);
     final hDate = HijriCalendar.fromDate(date.add(Duration(days: adjustment)));
     return locale == 'ar'
         ? '${hDate.hDay} ${hDate.longMonthName} ${hDate.hYear}'
         : '${hDate.hYear}/${hDate.hMonth}/${hDate.hDay}';
  }

  static String formatHijriDate(DateTime date, int adjustment, [String locale = 'ar']) {
    final hDate = HijriCalendar.fromDate(date.add(Duration(days: adjustment)));
     return locale == 'ar'
         ? '${hDate.hDay} ${hDate.longMonthName} ${hDate.hYear}'
         : '${hDate.hYear}/${hDate.hMonth}/${hDate.hDay}';
  }

  static String formatCustom(String pattern, DateTime date) {
    return DateFormat(pattern, 'ar').format(date);
  }
}
