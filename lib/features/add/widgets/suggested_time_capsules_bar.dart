import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/app_date_formatter.dart';

class SuggestedTimeCapsulesBar extends StatelessWidget {
  final TimeOfDay? selectedTime;
  final VoidCallback onSelectTime;
  final List<TimeOfDay> frequentTimes;
  final Function(TimeOfDay) onTimePicked;
  final bool hasError;

  const SuggestedTimeCapsulesBar({
    super.key,
    required this.selectedTime,
    required this.onSelectTime,
    required this.frequentTimes,
    required this.onTimePicked,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final localeCode = Localizations.localeOf(context).languageCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: Text(
            localeCode == 'ar' ? 'الوقت المحدد والمقترحات الأكثر استخداماً:' : 'Selected time & frequent picks:',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: hasError 
                  ? Colors.red.shade600 
                  : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
            ),
          ),
        ),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: frequentTimes.length + 1,
            separatorBuilder: (context, index) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              if (index == 0) {
                // الكبسولة الأولى: كبسولة الساعة الدوارة التفاعلية (--:--)
                final hasTime = selectedTime != null;
                final displayStr = hasTime
                    ? AppDateFormatter.formatTime12hFromValues(selectedTime!.hour, selectedTime!.minute, localeCode)
                    : '--:--';

                Color bgColor;
                Color borderColor;
                Color textColor;
                Color iconColor;

                if (hasTime) {
                  bgColor = AppColors.primary.withValues(alpha: 0.15);
                  borderColor = AppColors.primary;
                  textColor = AppColors.primary;
                  iconColor = AppColors.primary;
                } else if (hasError) {
                  bgColor = isDark ? Colors.grey.shade900 : Colors.grey.shade100;
                  borderColor = Colors.red.shade600;
                  textColor = isDark ? Colors.grey.shade300 : Colors.grey.shade800;
                  iconColor = Colors.grey;
                } else {
                  bgColor = isDark ? Colors.grey.shade900 : Colors.grey.shade100;
                  borderColor = isDark ? Colors.grey.shade700 : Colors.grey.shade300;
                  textColor = isDark ? Colors.grey.shade300 : Colors.grey.shade800;
                  iconColor = Colors.grey;
                }

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onSelectTime,
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: bgColor,
                        border: Border.all(
                          color: borderColor,
                          width: (hasTime || hasError) ? 1.5 : 1.0,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.access_time_filled,
                            size: 14,
                            color: iconColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            displayStr,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              // الكبسولات المقترحة مضغوطة ومصغرة بحسب الأكثر استخداماً للمستخدم
              final tod = frequentTimes[index - 1];
              final isSelected = selectedTime != null && 
                  selectedTime!.hour == tod.hour && 
                  selectedTime!.minute == tod.minute;

              final formattedStr = AppDateFormatter.formatTime12hFromValues(tod.hour, tod.minute, localeCode);

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onTimePicked(tod),
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : (isDark ? Colors.grey.shade900 : Colors.grey.shade100),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                        width: 1.0,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      formattedStr,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.grey.shade300 : Colors.grey.shade800),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
