import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:hijri/hijri_calendar.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../models/user.dart';
import '../../../../core/constants/app_dimens.dart';
import 'package:sijilli/l10n/app_localizations.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';

class DateTimeSection extends StatelessWidget {
  final bool isHijri;
  final int duration;
  final TimeOfDay? selectedTime;
  final VoidCallback onSelectTime;
  final List<Map<String, dynamic>> durationOptions;
  final Function(int) onDurationChanged;
  final String endDisplay;
  final VoidCallback onSelectEndDate;
  final TimeOfDay? sunsetTime; 

  const DateTimeSection({
    super.key,
    required this.isHijri,
    required this.duration,
    required this.selectedTime,
    required this.onSelectTime,
    required this.durationOptions,
    required this.onDurationChanged,
    required this.endDisplay,
    required this.onSelectEndDate,
    this.sunsetTime,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).cardColor : Colors.white,
        border: Border.all(color: isDark ? Colors.transparent : Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          if (!isDark)
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IgnorePointer(
            ignoring: duration == 0,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: duration == 0 ? 0.4 : 1.0,
              child: InkWell(
                onTap: onSelectTime,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.access_time_filled, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            duration == 0 ? context.l10n.durationAllDay : (selectedTime != null ? selectedTime!.format(context) : context.l10n.selectTime),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: (selectedTime != null || duration == 0) 
                                  ? (isDark ? Colors.white : Colors.black87) 
                                  : Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (duration != 0) Icon(Icons.arrow_drop_down, color: Colors.grey.shade400),
                  ],
                ),
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
          ),

          Text(
            context.l10n.durationLabel,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: durationOptions.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final opt = durationOptions[index];
                final isSelected = duration == opt['value'];
                return InkWell(
                  onTap: () => onDurationChanged(opt['value']),
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? AppColors.primary 
                          : (isDark ? Colors.grey.shade800 : Colors.grey.shade50),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected 
                            ? AppColors.primary 
                            : (isDark ? Colors.grey.shade700 : Colors.grey.shade200),
                      ),
                    ),
                    child: Text(
                      opt['label'],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.white : (isDark ? Colors.grey.shade300 : Colors.black87),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1),
          ),

          if (!(isHijri && duration == 0)) 
          InkWell(
            onTap: onSelectEndDate,
            borderRadius: BorderRadius.circular(8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.04),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  if (!isHijri) 
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary,
                        width: 6,
                      ),
                    ),
                  ),
                  if (!isHijri) const SizedBox(width: 12),
                  
                  Text(
                    isHijri ? context.l10n.hijri : context.l10n.gregorian,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  const Spacer(),
                  
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        duration == 0 ? context.l10n.endsAt : context.l10n.endTime,
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                      ),
                      Text(
                        endDisplay,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RecurrenceSection extends StatelessWidget {
  final bool isRecurring;
  final ValueChanged<bool> onToggle;
  final String recurrenceType;
  final int recurrenceCount;
  final List<Map<String, String>> recurrenceOptions;
  final Function(String) onTypeChanged;
  final Function(int) onCountChanged;

  const RecurrenceSection({
    super.key,
    required this.isRecurring,
    required this.onToggle,
    required this.recurrenceType,
    required this.recurrenceCount,
    required this.recurrenceOptions,
    required this.onTypeChanged,
    required this.onCountChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).cardColor : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.transparent : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.repeat, color: AppColors.primary, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    context.l10n.eventRecurrence,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
              Switch.adaptive(
                value: isRecurring, 
                onChanged: onToggle,
                activeColor: AppColors.primary,
              ),
            ],
          ),
          
          if (isRecurring) ...[
            const SizedBox(height: 16),
            Divider(height: 1, color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
            const SizedBox(height: 16),
            
            Text(
              context.l10n.recurrenceType,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: recurrenceOptions.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final opt = recurrenceOptions[index];
                  final isSelected = recurrenceType == opt['value'];
                  return InkWell(
                    onTap: () => onTypeChanged(opt['value']!),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? AppColors.primary.withOpacity(0.1) 
                            : (isDark ? Colors.grey.shade800 : Colors.grey.shade50),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected 
                              ? AppColors.primary 
                              : (isDark ? Colors.grey.shade700 : Colors.grey.shade200),
                        ),
                      ),
                      child: Text(
                        opt['label']!,
                        style: TextStyle(
                          color: isSelected 
                              ? AppColors.primary 
                              : (isDark ? Colors.grey.shade300 : Colors.black87),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            
            const SizedBox(height: 16),
            
            Row(
              children: [
                Text(
                  context.l10n.recurrenceCount,
                  style: const TextStyle(fontSize: 14),
                ),
                const Spacer(),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, size: 18),
                        onPressed: recurrenceCount > 1 
                            ? () => onCountChanged(recurrenceCount - 1)
                            : null,
                      ),
                      Text(
                        recurrenceCount.toString(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, size: 18),
                        onPressed: recurrenceCount < 50 
                            ? () => onCountChanged(recurrenceCount + 1)
                            : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class SimpleHijriPicker extends StatefulWidget {
  final HijriCalendar initialDate;
  const SimpleHijriPicker({super.key, required this.initialDate});

  @override
  State<SimpleHijriPicker> createState() => _SimpleHijriPickerState();
}

class _SimpleHijriPickerState extends State<SimpleHijriPicker> {
  late int _day;
  late int _month;
  late int _year;

  @override
  void initState() {
    super.initState();
    _day = widget.initialDate.hDay;
    _month = widget.initialDate.hMonth;
    _year = widget.initialDate.hYear;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 350,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.cancel, style: const TextStyle(color: Colors.red))),
                Text(context.l10n.selectHijriDate, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                TextButton(onPressed: () {
                  final h = HijriCalendar();
                  h.hYear = _year;
                  h.hMonth = _month;
                  h.hDay = _day;
                  Navigator.pop(context, h);
                }, child: Text(context.l10n.confirm, style: const TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Row(
              children: [
                Expanded(child: SimpleWheelPicker(itemCount: 30, initialItem: _day - 1, onChanged: (i) => _day = i + 1, itemBuilder: (i) => Text('${i+1}'))),
                Expanded(child: SimpleWheelPicker(itemCount: 12, initialItem: _month - 1, onChanged: (i) => _month = i + 1, itemBuilder: (i) => Text(_getMonthName(i+1)))),
                Expanded(child: SimpleWheelPicker(itemCount: 10, initialItem: _year - 1445, onChanged: (i) => _year = 1445 + i, itemBuilder: (i) => Text('${1445 + i}'))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = ["محرم", "صفر", "ربيع الأول", "ربيع الثاني", "جمادى الأولى", "جمادى الآخرة", "رجب", "شعبان", "رمضان", "شوال", "ذو القعدة", "ذو الحجة"];
    return months[month - 1];
  }
}

class SimpleWheelPicker extends StatelessWidget {
  final int itemCount;
  final int initialItem;
  final ValueChanged<int> onChanged;
  final Widget Function(int) itemBuilder;

  const SimpleWheelPicker({super.key, required this.itemCount, required this.initialItem, required this.onChanged, required this.itemBuilder});

  @override
  Widget build(BuildContext context) {
    return ListWheelScrollView.useDelegate(
      controller: FixedExtentScrollController(initialItem: initialItem),
      itemExtent: 46,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: onChanged,
      childDelegate: ListWheelChildBuilderDelegate(builder: (context, index) => Center(child: itemBuilder(index)), childCount: itemCount),
    );
  }
}

class PrayerTimesRow extends StatelessWidget {
  final TimeOfDay? sunriseTime;
  final TimeOfDay? dhuhrTime;
  final TimeOfDay? sunsetTime;

  const PrayerTimesRow({
    super.key,
    this.sunriseTime,
    this.dhuhrTime,
    this.sunsetTime,
  });

  @override
  Widget build(BuildContext context) {
    if (sunriseTime == null && dhuhrTime == null && sunsetTime == null) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(top: 4.0, bottom: 0.0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (sunriseTime != null) ...[
              const Icon(Icons.wb_sunny_outlined, size: 12, color: Colors.orange),
              const SizedBox(width: 4),
              Text(
                '${context.l10n.sunriseTime}: ${sunriseTime!.format(context)}',
                style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
              ),
            ],
            if (sunriseTime != null && dhuhrTime != null) ...[
              const SizedBox(width: 12),
              Container(width: 1, height: 12, color: Colors.grey.shade400),
              const SizedBox(width: 12),
            ],
            if (dhuhrTime != null) ...[
              const Icon(Icons.sunny, size: 12, color: Colors.amber),
              const SizedBox(width: 4),
              Text(
                '${context.l10n.dhuhrTime}: ${dhuhrTime!.format(context)}',
                style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
              ),
            ],
            if ((sunriseTime != null || dhuhrTime != null) && sunsetTime != null) ...[
              const SizedBox(width: 12),
              Container(width: 1, height: 12, color: Colors.grey.shade400),
              const SizedBox(width: 12),
            ],
            if (sunsetTime != null) ...[
              const Icon(Icons.wb_twilight, size: 12, color: Colors.deepOrange),
              const SizedBox(width: 4),
              Text(
                '${context.l10n.sunsetTime}: ${sunsetTime!.format(context)}',
                style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
