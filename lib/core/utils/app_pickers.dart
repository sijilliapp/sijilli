import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AppPickers {
  static Future<TimeOfDay?> showStyledTimePicker(BuildContext context, {TimeOfDay? initialTime}) async {
    return await showTimePicker(
      context: context,
      initialTime: initialTime ?? TimeOfDay.now(),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: isDark 
            ? ThemeData.dark().copyWith(
                colorScheme: const ColorScheme.dark(
                  primary: AppColors.primary,
                  onPrimary: Colors.white,
                  surface: AppColors.darkSurface,
                  onSurface: Colors.white,
                ),
                timePickerTheme: TimePickerThemeData(
                   dayPeriodBorderSide: const BorderSide(color: AppColors.primary),
                   dayPeriodColor: AppColors.primary.withValues(alpha: 0.2),
                   dayPeriodTextColor: Colors.white,
                   dialHandColor: AppColors.primary,
                   dialBackgroundColor: Colors.grey.shade800,
                )
              )
            : ThemeData.light().copyWith(
               colorScheme: const ColorScheme.light(primary: AppColors.primary),
               timePickerTheme: TimePickerThemeData(
                 dayPeriodBorderSide: const BorderSide(color: AppColors.primary),
                 dayPeriodColor: AppColors.primary.withValues(alpha: 0.1),
                 dayPeriodTextColor: AppColors.primary,
                 dialHandColor: AppColors.primary,
                 dialBackgroundColor: AppColors.primary.withValues(alpha: 0.05),
               )
            ),
          child: child!,
        );
      },
    );
  }

  static Future<DateTime?> showStyledDatePicker({
    required BuildContext context,
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
  }) async {
    return await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: isDark 
            ? ThemeData.dark().copyWith(
                colorScheme: const ColorScheme.dark(
                  primary: AppColors.primary,
                  onPrimary: Colors.white,
                  surface: AppColors.darkSurface,
                  onSurface: Colors.white,
                )) 
            : ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: AppColors.primary)),
          child: child!,
        );
      },
    );
  }
}
