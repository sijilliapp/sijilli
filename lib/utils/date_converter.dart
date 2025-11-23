import 'package:hijri/hijri_calendar.dart';

/// 🔄 CENTRALIZED DATE CONVERTER - محول التاريخ المركزي 🔄
/// 
/// Central utility for converting between Gregorian and Hijri dates
/// with user-specific adjustment support.
/// 
/// This replaces all direct HijriCalendar conversions throughout the app
/// to ensure consistent application of user's hijri_adjustment preference.
class DateConverter {
  /// Convert Gregorian date to Hijri with user adjustment
  /// 
  /// The adjustment is added to the Gregorian date before conversion,
  /// effectively shifting the Hijri date forward or backward.
  /// 
  /// Example:
  /// - Gregorian: 2025-10-16
  /// - Adjustment: +1
  /// - Result: Hijri date for 2025-10-17
  /// 
  /// Parameters:
  /// - [gregorian]: The Gregorian date to convert
  /// - [adjustment]: Days to adjust (±2 range, default: 0)
  static HijriCalendar toHijri(DateTime gregorian, {int adjustment = 0}) {
    final adjustedDate = gregorian.add(Duration(days: adjustment));
    return HijriCalendar.fromDate(adjustedDate);
  }

  /// Convert Hijri date to Gregorian with reverse adjustment
  /// 
  /// The adjustment is subtracted from the result to reverse the
  /// correction applied during Hijri->Gregorian conversion.
  /// 
  /// Example:
  /// - Hijri: 24 Rabi' al-Akhir 1447
  /// - Adjustment: +1
  /// - Result: Gregorian date - 1 day (to reverse the +1)
  /// 
  /// Parameters:
  /// - [hijri]: The Hijri calendar date to convert
  /// - [adjustment]: Days to reverse-adjust (±2 range, default: 0)
  static DateTime toGregorian(HijriCalendar hijri, {int adjustment = 0}) {
    // Convert Hijri to Gregorian using hijriToGregorian method
    final tempHijri = HijriCalendar();
    final gregorianDate = tempHijri.hijriToGregorian(
      hijri.hYear,
      hijri.hMonth,
      hijri.hDay,
    );
    // Subtract the adjustment to reverse the correction
    return gregorianDate.subtract(Duration(days: adjustment));
  }

  /// Convert Hijri components (year, month, day) to Gregorian with adjustment
  /// 
  /// Convenience method for when you have separate Hijri components
  /// instead of a HijriCalendar object.
  /// 
  /// Parameters:
  /// - [year]: Hijri year
  /// - [month]: Hijri month (1-12)
  /// - [day]: Hijri day (1-30)
  /// - [adjustment]: Days to reverse-adjust (±2 range, default: 0)
  static DateTime componentsToGregorian(
    int year,
    int month,
    int day, {
    int adjustment = 0,
  }) {
    final hijri = HijriCalendar()
      ..hYear = year
      ..hMonth = month
      ..hDay = day;
    return toGregorian(hijri, adjustment: adjustment);
  }

  /// Format Hijri date as Arabic string
  /// 
  /// Example output: "24 ربيع الآخر 1447 هـ"
  static String formatHijri(HijriCalendar hijri) {
    const monthNames = [
      'محرم', 'صفر', 'ربيع 1', 'ربيع 2',
      'جمادى 1', 'جمادى 2', 'رجب', 'شعبان',
      'رمضان', 'شوال', 'ذو القعدة', 'ذو الحجة'
    ];
    
    final monthName = monthNames[hijri.hMonth - 1];
    return '\u200E${hijri.hDay} $monthName ${hijri.hYear} هـ';
  }

  /// Format Gregorian date as Arabic string
  /// 
  /// Example output: "16 أكتوبر 2025 م"
  static String formatGregorian(DateTime gregorian) {
    const monthNames = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    
    final monthName = monthNames[gregorian.month - 1];
    return '${gregorian.day} $monthName ${gregorian.year} م';
  }

  /// Get today's Hijri date with adjustment
  static HijriCalendar todayHijri({int adjustment = 0}) {
    return toHijri(DateTime.now(), adjustment: adjustment);
  }

  /// Get today's Hijri date as formatted string
  static String todayHijriString({int adjustment = 0}) {
    return formatHijri(todayHijri(adjustment: adjustment));
  }
}
