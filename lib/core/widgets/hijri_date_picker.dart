import 'package:flutter/material.dart';
import 'package:hijri/hijri_calendar.dart';
import '../constants/app_colors.dart';
import '../../core/extensions/context_l10n.dart';
import '../utils/app_date_formatter.dart';

class HijriDatePicker extends StatefulWidget {
  final DateTime? initialDate;
  final ValueChanged<DateTime> onDateSelected;

  const HijriDatePicker({
    Key? key,
    this.initialDate,
    required this.onDateSelected,
  }) : super(key: key);

  @override
  State<HijriDatePicker> createState() => _HijriDatePickerState();
}

class _HijriDatePickerState extends State<HijriDatePicker> {
  late HijriCalendar _selectedHijriDate;

  @override
  void initState() {
    super.initState();
    final date = widget.initialDate ?? DateTime.now();
    _selectedHijriDate = HijriCalendar.fromDate(date);
    // Setting locale to arabic
    HijriCalendar.setLocal('ar');
  }

  Future<void> _selectDate(BuildContext context) async {
    final HijriCalendar? picked = await showHijriDatePicker(
      context: context,
      initialDate: _selectedHijriDate,
      lastDate: HijriCalendar()
        ..hYear = 1460, // ~10 years in future
      firstDate: HijriCalendar()
        ..hYear = 1440, // ~5 years in past
      initialDatePickerMode: DatePickerMode.day,
    );

    if (picked != null) {
      setState(() {
        _selectedHijriDate = picked;
      });
      
      // Convert back to Gregorian for storage
      final gregorianDate = picked.hijriToGregorian(picked.hYear, picked.hMonth, picked.hDay);
      widget.onDateSelected(gregorianDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _selectDate(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.hijri,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getFormattedDate(context),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  String _getFormattedDate(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    String formatted = _selectedHijriDate.toFormat("dd MMMM yyyy");
    if (locale == 'ar') {
      formatted = AppDateFormatter.toEasternArabicDigits(formatted);
    } else {
      formatted = '${_selectedHijriDate.hYear}/${_selectedHijriDate.hMonth}/${_selectedHijriDate.hDay}';
    }
    return formatted;
  }
  
  // Custom dialog function if package doesn't provide a good one, 
  // but 'hijri' usually doesn't have a visual picker built-in like showDatePicker.
  // Wait, 'hijri' package does NOT have showHijriDatePicker natively in the core package usually,
  // typically people use 'hijri_picker'. 
  // Let me double check if I should implement a simple dropdown or use an external package.
  // Since I cannot check package contents easily, and 'hijri' is usually just logic.
  // I will check if 'hijri_picker' is available or implement a simple selector (Day/Month/Year dropdowns).
  //
  // Re-evaluating: implementation plan said 'jhijri' which has widgets. 'hijri' is likely logic only.
  // I will implement a simple visual picker using 3 dropdowns for H-Day, H-Month, H-Year.
  
  Future<HijriCalendar?> showHijriDatePicker({
    required BuildContext context,
    required HijriCalendar initialDate,
    required HijriCalendar firstDate,
    required HijriCalendar lastDate,
    DatePickerMode initialDatePickerMode = DatePickerMode.day,
  }) async {
    return await showModalBottomSheet<HijriCalendar>(
      context: context,
      builder: (context) => _HijriPickerSheet(
        initialDate: initialDate,
      ),
    );
  }
}

class _HijriPickerSheet extends StatefulWidget {
  final HijriCalendar initialDate;
  const _HijriPickerSheet({required this.initialDate});

  @override
  State<_HijriPickerSheet> createState() => _HijriPickerSheetState();
}

class _HijriPickerSheetState extends State<_HijriPickerSheet> {
  late int _selectedDay;
  late int _selectedMonth;
  late int _selectedYear;

  final FixedExtentScrollController _dayController = FixedExtentScrollController();
  final FixedExtentScrollController _monthController = FixedExtentScrollController();
  final FixedExtentScrollController _yearController = FixedExtentScrollController();

  List<String> _getMonths(String locale) {
    if (locale == 'ar') {
      return [
        "محرم", "صفر", "ربيع الأول", "ربيع الثاني", 
        "جمادى الأولى", "جمادى الآخرة", "رجب", "شعبان", 
        "رمضان", "شوال", "ذو القعدة", "ذو الحجة"
      ];
    }
    return [
      "Muharram", "Safar", "Rabi' I", "Rabi' II",
      "Jumada I", "Jumada II", "Rajab", "Sha'ban",
      "Ramadan", "Shawwal", "Dhu al-Qi'dah", "Dhu al-Hijjah"
    ];
  }

  @override
  void initState() {
    super.initState();
    _selectedDay = widget.initialDate.hDay;
    _selectedMonth = widget.initialDate.hMonth;
    _selectedYear = widget.initialDate.hYear;

    // Initialize controllers
    // Note: Indexes are 0-based. Days 1-30 -> Index 0-29. Months 1-12 -> Index 0-11.
    // Years relative to start year (e.g. 1440).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_dayController.hasClients) _dayController.jumpToItem(_selectedDay - 1);
      if (_monthController.hasClients) _monthController.jumpToItem(_selectedMonth - 1);
      if (_yearController.hasClients) _yearController.jumpToItem(_selectedYear - 1440);
    });
  }

  void _onConfirm() {
    final result = HijriCalendar()
      ..hYear = _selectedYear
      ..hMonth = _selectedMonth
      ..hDay = _selectedDay;
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 350,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context), 
                  child: Text(context.l10n.cancel, style: const TextStyle(color: Colors.red))
                ),
                 Text(
                   context.l10n.hijriDatePickerTitle,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: _onConfirm, 
                  child: Text(context.l10n.confirm, style: const TextStyle(fontWeight: FontWeight.bold))
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          
          // Pickers
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Selection Overlay
                Container(
                  height: 40,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                
                Row(
                  children: [
                    // Days
                    Expanded(
                      child: _buildScrollPicker(
                        controller: _dayController,
                        itemCount: 30, // Hijri days approx 30
                        onSelectedItemChanged: (index) {
                          setState(() => _selectedDay = index + 1);
                        },
                        itemBuilder: (index) {
                           String text = '${index + 1}';
                           if (Localizations.localeOf(context).languageCode == 'ar') {
                              text = AppDateFormatter.toEasternArabicDigits(text);
                           }
                           return Center(child: Text(text));
                        },
                      ),
                    ),
                    // Months
                    Expanded(
                      flex: 2,
                      child: _buildScrollPicker(
                        controller: _monthController,
                        itemCount: 12,
                        onSelectedItemChanged: (index) {
                          setState(() => _selectedMonth = index + 1);
                        },
                        itemBuilder: (index) => Center(child: Text(_getMonths(Localizations.localeOf(context).languageCode)[index])),
                      ),
                    ),
                    // Years (Range 1440 - 1460 for demo)
                    Expanded(
                      child: _buildScrollPicker(
                        controller: _yearController,
                        itemCount: 21,
                        onSelectedItemChanged: (index) {
                          setState(() => _selectedYear = 1440 + index);
                        },
                        itemBuilder: (index) {
                           String text = '${1440 + index}';
                           if (Localizations.localeOf(context).languageCode == 'ar') {
                              text = AppDateFormatter.toEasternArabicDigits(text);
                           }
                           return Center(child: Text(text));
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollPicker({
    required FixedExtentScrollController controller,
    required int itemCount,
    required ValueChanged<int> onSelectedItemChanged,
    required Widget Function(int) itemBuilder,
  }) {
    return ListWheelScrollView.useDelegate(
      controller: controller,
      itemExtent: 40,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: onSelectedItemChanged,
      childDelegate: ListWheelChildBuilderDelegate(
        builder: (context, index) => itemBuilder(index),
        childCount: itemCount,
      ),
    );
  }
}
