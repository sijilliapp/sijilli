import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/app_date_formatter.dart';

class SuggestedTimeCapsulesBar extends StatelessWidget {
  final TimeOfDay? selectedTime;
  final VoidCallback onSelectTime;
  final List<TimeOfDay> frequentTimes;
  final Function(TimeOfDay) onTimePicked;

  const SuggestedTimeCapsulesBar({
    super.key,
    required this.selectedTime,
    required this.onSelectTime,
    required this.frequentTimes,
    required this.onTimePicked,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final localeCode = Localizations.localeOf(context).languageCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6.0),
          child: Text(
            localeCode == 'ar' ? 'تحديد الوقت أو اختيار الوقت المقترح:' : 'Select time or pick suggested:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
        ),
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: frequentTimes.length + 1,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              if (index == 0) {
                // الكبسولة الأولى: كبسولة الساعة الدوارة التفاعلية (--:--)
                final hasTime = selectedTime != null;
                final displayStr = hasTime
                    ? AppDateFormatter.formatTime12hFromValues(selectedTime!.hour, selectedTime!.minute, localeCode)
                    : '--:--';

                return InkWell(
                  onTap: onSelectTime,
                  borderRadius: BorderRadius.circular(20),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: hasTime 
                          ? AppColors.primary.withValues(alpha: 0.15) 
                          : (isDark ? Colors.grey.shade900 : Colors.grey.shade100),
                      border: Border.all(
                        color: hasTime ? AppColors.primary : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                        width: hasTime ? 1.5 : 1.0,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.access_time_filled,
                          size: 16,
                          color: hasTime ? AppColors.primary : Colors.grey,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          displayStr,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: hasTime ? AppColors.primary : (isDark ? Colors.grey.shade300 : Colors.grey.shade800),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // الكبسولات المقترحة مرتبة بحسب الأكثر استخداماً
              final tod = frequentTimes[index - 1];
              final isSelected = selectedTime != null && 
                  selectedTime!.hour == tod.hour && 
                  selectedTime!.minute == tod.minute;

              final formattedStr = AppDateFormatter.formatTime12hFromValues(tod.hour, tod.minute, localeCode);

              return InkWell(
                onTap: () => onTimePicked(tod),
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : (isDark ? Colors.grey.shade900 : Colors.grey.shade100),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                      width: 1.0,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    formattedStr,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.grey.shade300 : Colors.grey.shade800),
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
