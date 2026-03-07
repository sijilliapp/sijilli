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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Right: Date Stack (Expanded)
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Line 1: Day Name (Standalone)
              Text(
                dayName,
                style: TextStyle(
                  fontSize: 18, 
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextPrimary(context),
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              // Line 2: Dates (Primary - Secondary) - Matched Style
              Text(
                datesLine,
                style: TextStyle(
                  fontSize: 18, // Matched DayName
                  fontWeight: FontWeight.bold, // Matched DayName
                  color: AppColors.getTextPrimary(context), // Matched DayName
                  height: 1.2,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1, 
              ),
            ],
          ),
        ),

        const SizedBox(width: 16),

        // Left: Time (Big, Black, Hindi)
        Text(
          timeLine,
          style: TextStyle(
            fontSize: 40, 
            fontWeight: FontWeight.w900,
            // Force Black in Light Mode, White in Dark Mode (TextPrimary usually handles this, 
            // but user asked for "Black". I'll use TextPrimary which is standard for "Black" in light theme)
            color: AppColors.getTextPrimary(context), 
            height: 1.0,
          ),
          textDirection: TextDirection.ltr, 
        ),
      ],
    );
  }
}
