import 'package:flutter/material.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../../core/utils/app_date_formatter.dart';
import '../../../core/constants/app_dimens.dart';

class DateHeader extends StatelessWidget {
  final int hijriAdjustment;

  const DateHeader({
    super.key,
    this.hijriAdjustment = 0,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Get current time
    final now = DateTime.now();
    final locale = Localizations.localeOf(context).languageCode;

    // 2. Format Gregorian Date
    final gregorianText = DateFormat('d MMM yyyy', locale).format(now);

    // 3. Format Hijri Date
    final adjustedDate = now.add(Duration(days: hijriAdjustment));
    
    HijriCalendar.setLocal(locale);
    final hijriDate = HijriCalendar.fromDate(adjustedDate);
    
    final hDay = hijriDate.hDay;
    final hYear = hijriDate.hYear;
    final monthName = hijriDate.longMonthName;
    // VERY IMPORTANT: The physical weekday name MUST ALWAYS be tied to the absolute Gregorian reality
    // The user's manual Hijri adjustment should ONLY shift the numbered date, never the day of the week.
    final dayName = DateFormat('EEEE', locale).format(now); 
    
    // Construct Hijri string
    final hijriText = locale == 'ar'
        ? '$dayName $hDay $monthName $hYear'
        : '$dayName ${hijriDate.hYear}/${hijriDate.hMonth}/${hijriDate.hDay}';

    return Padding(
      padding: const EdgeInsets.only(top: AppDimens.spaceXXS), // إزالة bottom padding
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Right: Hijri Date (RTL -> First child)
          Row(
            children: [
              Text(
                locale == 'ar' ? AppDateFormatter.toEasternArabicDigits(hijriText) : hijriText,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),

          // Left: Gregorian Date (LTR -> Second child)
          Text(
            locale == 'ar' ? AppDateFormatter.toEasternArabicDigits(gregorianText) : gregorianText,
            textDirection: TextDirection.ltr,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.normal,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}
