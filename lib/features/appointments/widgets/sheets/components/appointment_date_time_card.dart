import 'package:flutter/material.dart';
import 'package:sijilli/core/constants/app_colors.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';


class AppointmentDateTimeCard extends StatelessWidget {
  final String dayName;
  final String datesLine;
  final String timeLine;
  
  // All Day Extensions
  final bool isAllDay;
  final String? startDay;
  final String? startGreg;
  final String? startHijri;
  final String? endDay;
  final String? endGreg;
  final String? endHijri;

  const AppointmentDateTimeCard({
    super.key,
    required this.dayName,
    required this.datesLine,
    required this.timeLine,
    this.isAllDay = false,
    this.startDay,
    this.startGreg,
    this.startHijri,
    this.endDay,
    this.endGreg,
    this.endHijri,
  });

  @override
  Widget build(BuildContext context) {
    if (isAllDay && startDay != null && endDay != null) {
      return _buildAllDayLayout(context);
    }
    return _buildStandardLayout(context);
  }

  Widget _buildAllDayLayout(BuildContext context) {
    // 3 Columns: Day | Gregorian | Hijri
    // Plus Labels "From/To"
    
    final style = TextStyle(
       fontSize: 14, // Slightly smaller to fit 3 cols 
       fontWeight: FontWeight.bold,
       color: AppColors.getTextPrimary(context),
       height: 1.5,
    );

    final labelStyle = TextStyle(
       fontSize: 14, 
       fontWeight: FontWeight.normal,
       color: AppColors.getTextSecondary(context),
       height: 1.5,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Col 1: Labels
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.detailsFrom, style: labelStyle),
            Text(context.l10n.detailsTo, style: labelStyle),
          ],
        ),
        const SizedBox(width: 12),
        
        // Col 2: Days
        Expanded(
          flex: 2,
          child: Container( // Transparent Container
             color: Colors.transparent,
             child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(startDay!, style: style, maxLines: 1, overflow: TextOverflow.visible),
                Text(endDay!, style: style, maxLines: 1, overflow: TextOverflow.visible),
              ],
             ),
          ),
        ),
        const SizedBox(width: 8),

        // Col 3: Gregorian
        Expanded(
          flex: 3,
          child: Container( // Transparent Container
             color: Colors.transparent,
             child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(startGreg!, style: style, maxLines: 1, overflow: TextOverflow.visible),
                Text(endGreg!, style: style, maxLines: 1, overflow: TextOverflow.visible),
              ],
             ),
          ),
        ),
        const SizedBox(width: 8),

        // Col 4: Hijri
        Expanded(
          flex: 3,
          child: Container( // Transparent Container
             color: Colors.transparent,
             child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(startHijri!, style: style, maxLines: 1, overflow: TextOverflow.visible),
                Text(endHijri!, style: style, maxLines: 1, overflow: TextOverflow.visible),
              ],
             ),
          ),
        ),
      ],
    );
  }

  Widget _buildStandardLayout(BuildContext context) {
    // Parse Time
    final timeParts = timeLine.split(' ');
    final timeDigits = timeParts.isNotEmpty ? timeParts[0].trim() : timeLine;
    final timePeriod = timeParts.length > 1 ? timeParts.sublist(1).join(' ').trim() : '';

    // Parse Dates
    final dateParts = datesLine.split(' - ');
    final date1 = dateParts.isNotEmpty ? dateParts[0].trim() : '';
    final date2 = dateParts.length > 1 ? dateParts[1].trim() : '';

    final timeWidget = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          timeDigits,
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w900,
            color: AppColors.getTextPrimary(context),
            height: 1.0,
          ),
          textDirection: TextDirection.ltr,
        ),
        const SizedBox(height: 2),
        Text(
          timePeriod,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.getTextSecondary(context),
            height: 1.0,
          ),
        ),
      ],
    );

    final dateWidget = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          dayName,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: AppColors.getTextPrimary(context),
            height: 1.2,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (date1.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            date1,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: AppColors.getTextPrimary(context),
              height: 1.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (date2.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            date2,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: AppColors.getTextPrimary(context),
              height: 1.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: dateWidget),
        const SizedBox(width: 24),
        timeWidget,
      ],
    );
  }
}
