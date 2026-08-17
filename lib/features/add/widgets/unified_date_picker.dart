import 'package:flutter/material.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';

class UnifiedDatePicker extends StatefulWidget {
  final DateTime initialDate;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<bool> onModeChanged; // true = Hijri, false = Gregorian
  final bool initialMode;
  final int hijriAdjustment;

  final DateTime? endDate;
  final ValueChanged<DateTime>? onEndDateChanged;
  final bool showEndDate;

  const UnifiedDatePicker({
    super.key,
    required this.initialDate,
    required this.onDateChanged,
    required this.onModeChanged,
    this.initialMode = false,
    this.hijriAdjustment = 0,
    this.endDate,
    this.onEndDateChanged,
    this.showEndDate = false,
  });

  static Future<DateTime?> showGregorianPicker(BuildContext context, {required DateTime initialDate}) {
    return showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _GregorianPickerSheet(initialDate: initialDate),
    );
  }

  static Future<DateTime?> showHijriPicker(BuildContext context, {required DateTime initialDate, int hijriAdjustment = 0}) async {
    HijriCalendar.setLocal(Localizations.localeOf(context).languageCode);
    final adjusted = hijriAdjustment != 0 ? initialDate.add(Duration(days: hijriAdjustment)) : initialDate;
    final hDate = HijriCalendar.fromDate(adjusted);
    final pickedHijri = await showModalBottomSheet<HijriCalendar>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _HijriPickerSheet(initialDate: hDate),
    );
    if (pickedHijri != null) {
      DateTime g = pickedHijri.hijriToGregorian(pickedHijri.hYear, pickedHijri.hMonth, pickedHijri.hDay);
      if (hijriAdjustment != 0) {
        g = g.subtract(Duration(days: hijriAdjustment));
      }
      return g;
    }
    return null;
  }

  @override
  State<UnifiedDatePicker> createState() => _UnifiedDatePickerState();
}

class _UnifiedDatePickerState extends State<UnifiedDatePicker> {
  late DateTime _selectedDate;
  late DateTime _selectedEndDate;
  late HijriCalendar _hijriDate;
  late HijriCalendar _endHijriDate;
  bool _isHijriMode = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _selectedEndDate = widget.endDate ?? widget.initialDate;
    _isHijriMode = widget.initialMode;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateHijriDate();
  }

  @override
  void didUpdateWidget(UnifiedDatePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialDate != oldWidget.initialDate || widget.hijriAdjustment != oldWidget.hijriAdjustment) {
       _selectedDate = widget.initialDate;
       _updateHijriDate();
    }
    if (widget.endDate != oldWidget.endDate) {
       _selectedEndDate = widget.endDate ?? widget.initialDate;
       _updateHijriDate();
    }
    if (widget.initialMode != oldWidget.initialMode) {
      _isHijriMode = widget.initialMode;
    }
  }

  void _updateHijriDate() {
    HijriCalendar.setLocal(Localizations.localeOf(context).languageCode);
    _hijriDate = HijriCalendar.fromDate(_selectedDate);
    _endHijriDate = HijriCalendar.fromDate(_selectedEndDate);
    
    if (widget.hijriAdjustment != 0) {
      final adjustedGregorian = _selectedDate.add(Duration(days: widget.hijriAdjustment));
      _hijriDate = HijriCalendar.fromDate(adjustedGregorian);
      final adjustedEnd = _selectedEndDate.add(Duration(days: widget.hijriAdjustment));
      _endHijriDate = HijriCalendar.fromDate(adjustedEnd);
    }
  }

  void _onGregorianChanged(DateTime date) {
    setState(() {
      _selectedDate = date;
      _updateHijriDate();
      widget.onDateChanged(_selectedDate);
    });
  }

  void _onHijriChanged(HijriCalendar hijri) {
    setState(() {
      _hijriDate = hijri;
      DateTime gregorian = hijri.hijriToGregorian(hijri.hYear, hijri.hMonth, hijri.hDay);
      
      if (widget.hijriAdjustment != 0) {
        gregorian = gregorian.subtract(Duration(days: widget.hijriAdjustment));
      }

      _selectedDate = gregorian;
      widget.onDateChanged(_selectedDate);
    });
  }

  Future<void> _showEndGregorianPicker() async {
    final picked = await showGregorianPicker(context, initialDate: _selectedEndDate);
    if (picked != null) {
      setState(() {
        _selectedEndDate = picked;
        _updateHijriDate();
        widget.onEndDateChanged?.call(_selectedEndDate);
      });
    }
  }

  Future<void> _showEndHijriPicker() async {
    final picked = await showHijriPicker(
      context,
      initialDate: _selectedEndDate,
      hijriAdjustment: widget.hijriAdjustment,
    );
    if (picked != null) {
      setState(() {
        _selectedEndDate = picked;
        _updateHijriDate();
        widget.onEndDateChanged?.call(_selectedEndDate);
      });
    }
  }

  Widget _buildDateBox({
    required BuildContext context,
    required String label,
    required String dateStr,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? Theme.of(context).cardColor : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          ),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, size: 18, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      dateStr,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Row(
              children: [
                Text(
                  context.l10n.localeName == 'ar' ? 'تغيير' : 'Change',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.primary),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final startDateStr = _isHijriMode 
        ? '${_hijriDate.hDay} ${_hijriDate.longMonthName} ${_hijriDate.hYear} هـ'
        : DateFormat('EEEE، d MMMM yyyy', Localizations.localeOf(context).languageCode).format(_selectedDate);

    final endDateStr = _isHijriMode 
        ? '${_endHijriDate.hDay} ${_endHijriDate.longMonthName} ${_endHijriDate.hYear} هـ'
        : DateFormat('EEEE، d MMMM yyyy', Localizations.localeOf(context).languageCode).format(_selectedEndDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 📅 حاوية تاريخ البدء
        _buildDateBox(
          context: context,
          label: context.l10n.localeName == 'ar' ? 'تاريخ البدء' : 'Start Date',
          dateStr: startDateStr,
          icon: Icons.edit_calendar_rounded,
          onTap: () {
            if (_isHijriMode) {
              _showHijriPicker();
            } else {
              _showGregorianPicker();
            }
          },
        ),

        // 📅 حاوية تاريخ الانتهاء (تنسدل فقط عند اختيار اليوم كله لتكون توأم حاوية تاريخ البدء)
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: widget.showEndDate
              ? Column(
                  key: const ValueKey('end_date_container'),
                  children: [
                    const SizedBox(height: 8),
                    _buildDateBox(
                      context: context,
                      label: context.l10n.localeName == 'ar' ? 'تاريخ الانتهاء' : 'End Date',
                      dateStr: endDateStr,
                      icon: Icons.event_available_rounded,
                      onTap: () {
                        if (_isHijriMode) {
                          _showEndHijriPicker();
                        } else {
                          _showEndGregorianPicker();
                        }
                      },
                    ),
                  ],
                )
              : const SizedBox.shrink(key: ValueKey('no_end_date_container')),
        ),

        const SizedBox(height: 10),

        // قطار سكرول التواريخ الأفقية
        _buildWeekDaysStrip(),
      ],
    );
  }

  Widget _buildWeekDaysStrip() {
    final today = DateTime.now();
    final weekDays = List.generate(30, (index) => today.add(Duration(days: index)));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 75,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: 31, // 1 toggle brick + 30 date bricks
        separatorBuilder: (context, index) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          if (index == 0) {
            // أول طوبة من طوب التواريخ: اختيار عمودي بين ميلادي وهجري
            return Container(
              width: 58,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                ),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        if (_isHijriMode) {
                          setState(() => _isHijriMode = false);
                          widget.onModeChanged(false);
                        } else {
                          _showGregorianPicker();
                        }
                      },
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(11),
                        topRight: Radius.circular(11),
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: !_isHijriMode ? AppColors.primary : Colors.transparent,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(11),
                            topRight: Radius.circular(11),
                          ),
                        ),
                        child: Text(
                          context.l10n.localeName == 'ar' ? 'ميلادي' : 'Greg',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: !_isHijriMode
                                ? Colors.white
                                : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Divider(height: 1, color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        if (!_isHijriMode) {
                          setState(() => _isHijriMode = true);
                          widget.onModeChanged(true);
                        } else {
                          _showHijriPicker();
                        }
                      },
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(11),
                        bottomRight: Radius.circular(11),
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _isHijriMode ? AppColors.primary : Colors.transparent,
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(11),
                            bottomRight: Radius.circular(11),
                          ),
                        ),
                        child: Text(
                          context.l10n.localeName == 'ar' ? 'هجري' : 'Hijri',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _isHijriMode
                                ? Colors.white
                                : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          final date = weekDays[index - 1];
          final isSelected = DateUtils.isSameDay(date, _selectedDate);
          
          HijriCalendar.setLocal(context.l10n.localeName);
          
          final adjustedDate = widget.hijriAdjustment != 0 
              ? date.add(Duration(days: widget.hijriAdjustment))
              : date;
          final hDate = HijriCalendar.fromDate(adjustedDate);

          return GestureDetector(
            onTap: () => _onGregorianChanged(date),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 52,
              decoration: BoxDecoration(
                color: isSelected 
                    ? AppColors.primary 
                    : (isDark ? Colors.grey.shade900 : Colors.white),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected 
                      ? AppColors.primary 
                      : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                ),
                boxShadow: isSelected ? [
                  BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 2))
                ] : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('E', context.l10n.localeName).format(date),
                    style: TextStyle(
                      fontSize: 10,
                      color: isSelected ? Colors.white70 : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                    ),
                  ),
                  const SizedBox(height: 2),
                  
                  // اليوم الميلادي الرئيسي
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                  
                  const SizedBox(height: 2),
                  // اليوم الهجري الثانوي المعروض دائماً مع الميلادي في كل طوبة
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? Colors.white.withValues(alpha: 0.2) 
                          : (isDark ? Colors.grey.shade800 : Colors.grey.shade100),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${hDate.hDay}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static Future<DateTime?> showGregorianPicker(BuildContext context, {required DateTime initialDate}) {
    return showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _GregorianPickerSheet(initialDate: initialDate),
    );
  }

  static Future<DateTime?> showHijriPicker(BuildContext context, {required DateTime initialDate, int hijriAdjustment = 0}) async {
    HijriCalendar.setLocal(Localizations.localeOf(context).languageCode);
    final adjusted = hijriAdjustment != 0 ? initialDate.add(Duration(days: hijriAdjustment)) : initialDate;
    final hDate = HijriCalendar.fromDate(adjusted);
    final pickedHijri = await showModalBottomSheet<HijriCalendar>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _HijriPickerSheet(initialDate: hDate),
    );
    if (pickedHijri != null) {
      DateTime g = pickedHijri.hijriToGregorian(pickedHijri.hYear, pickedHijri.hMonth, pickedHijri.hDay);
      if (hijriAdjustment != 0) {
        g = g.subtract(Duration(days: hijriAdjustment));
      }
      return g;
    }
    return null;
  }

  void _showGregorianPicker() async {
    final picked = await showGregorianPicker(context, initialDate: _selectedDate);
    if (picked != null) {
      _onGregorianChanged(picked);
    }
  }

  void _showHijriPicker() async {
    final picked = await showHijriPicker(context, initialDate: _selectedDate, hijriAdjustment: widget.hijriAdjustment);
    if (picked != null) {
      _onGregorianChanged(picked);
    }
  }
}

class _GregorianPickerSheet extends StatefulWidget {
  final DateTime initialDate;
  const _GregorianPickerSheet({required this.initialDate});

  @override
  State<_GregorianPickerSheet> createState() => _GregorianPickerSheetState();
}

class _GregorianPickerSheetState extends State<_GregorianPickerSheet> {
  late int _day;
  late int _month;
  late int _year;

  late FixedExtentScrollController _dayCont;
  late FixedExtentScrollController _monthCont;
  late FixedExtentScrollController _yearCont;

  @override
  void initState() {
    super.initState();
    _day = widget.initialDate.day;
    _month = widget.initialDate.month;
    _year = widget.initialDate.year;
    
    _dayCont = FixedExtentScrollController(initialItem: _day - 1);
    _monthCont = FixedExtentScrollController(initialItem: _month - 1);
    _yearCont = FixedExtentScrollController(initialItem: _year - DateTime.now().year); 
  }

  @override
  Widget build(BuildContext context) {
    return _BasePickerSheet(
      title: context.l10n.selectGregorianDate,
      onConfirm: () {
        Navigator.pop(context, DateTime(_year, _month, _day));
      },
      child: Row(
        children: [
          Expanded(
            child: _WheelPicker(
              controller: _dayCont,
              itemCount: 31,
              onChanged: (i) => setState(() => _day = i + 1),
              builder: (i) => Text('${i + 1}'),
            ),
          ),
          Expanded(
            flex: 2,
            child: _WheelPicker(
              controller: _monthCont,
              itemCount: 12,
              onChanged: (i) => setState(() => _month = i + 1),
              builder: (i) {
                // Using a reference date for month names
                final date = DateTime(2024, i + 1, 1);
                return Text(DateFormat('MMMM', context.l10n.localeName).format(date));
              },
            ),
          ),
          Expanded(
            child: _WheelPicker(
              controller: _yearCont,
              itemCount: 10,
              onChanged: (i) => setState(() => _year = DateTime.now().year + i),
              builder: (i) => Text('${DateTime.now().year + i}'),
            ),
          ),
        ],
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
  late int _day;
  late int _month;
  late int _year;

  late FixedExtentScrollController _dayCont;
  late FixedExtentScrollController _monthCont;
  late FixedExtentScrollController _yearCont;

  @override
  void initState() {
    super.initState();
    _day = widget.initialDate.hDay;
    _month = widget.initialDate.hMonth;
    _year = widget.initialDate.hYear;
    
    _dayCont = FixedExtentScrollController(initialItem: _day - 1);
    _monthCont = FixedExtentScrollController(initialItem: _month - 1);
    _yearCont = FixedExtentScrollController(initialItem: _year - 1445); 
  }

  @override
  Widget build(BuildContext context) {
    return _BasePickerSheet(
      title: context.l10n.selectHijriDate,
      onConfirm: () {
        final h = HijriCalendar();
        h.hYear = _year;
        h.hMonth = _month;
        h.hDay = _day;
        Navigator.pop(context, h);
      },
      child: Row(
        children: [
          Expanded(
            child: _WheelPicker(
              controller: _dayCont,
              itemCount: 30,
              onChanged: (i) => setState(() => _day = i + 1),
              builder: (i) => Text('${i + 1}'),
            ),
          ),
          Expanded(
            flex: 2,
            child: _WheelPicker(
              controller: _monthCont,
              itemCount: 12,
              onChanged: (i) => setState(() => _month = i + 1),
              builder: (i) => Text(_getHijriMonthName(i + 1, context)),
            ),
          ),
          Expanded(
            child: _WheelPicker(
              controller: _yearCont,
              itemCount: 20, 
              onChanged: (i) => setState(() => _year = 1445 + i),
              builder: (i) => Text('${1445 + i}'),
            ),
          ),
        ],
      ),
    );
  }

  String _getHijriMonthName(int month, BuildContext context) {
    // Basic implementation, ideally these should be in ARB or from a helper
    // For now keeping them as they were but could be translated if needed
    final monthsAr = ["محرم", "صفر", "ربيع الأول", "ربيع الثاني", "جمادى الأولى", "جمادى الآخرة", "رجب", "شعبان", "رمضان", "شوال", "ذو القعدة", "ذو الحجة"];
    final monthsEn = ["Muharram", "Safar", "Rabi' I", "Rabi' II", "Jumada I", "Jumada II", "Rajab", "Sha'ban", "Ramadan", "Shawwal", "Dhu'l-Qi'dah", "Dhu'l-Hijjah"];
    return context.l10n.localeName == 'ar' ? monthsAr[month - 1] : monthsEn[month - 1];
  }
}

class _BasePickerSheet extends StatelessWidget {
  final String title;
  final VoidCallback onConfirm;
  final Widget child;
  
  const _BasePickerSheet({required this.title, required this.onConfirm, required this.child});

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
                TextButton(
                  onPressed: () => Navigator.pop(context), 
                  child: Text(context.l10n.cancel, style: const TextStyle(color: Colors.red))
                ),
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: onConfirm, 
                  child: Text(context.l10n.confirm, style: const TextStyle(fontWeight: FontWeight.bold))
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: 46,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WheelPicker extends StatelessWidget {
  final FixedExtentScrollController controller;
  final int itemCount;
  final ValueChanged<int> onChanged;
  final Widget Function(int) builder;

  const _WheelPicker({
    required this.controller,
    required this.itemCount,
    required this.onChanged,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return ListWheelScrollView.useDelegate(
      controller: controller,
      itemExtent: 46,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: onChanged,
      childDelegate: ListWheelChildBuilderDelegate(
        builder: (context, index) => Center(child: builder(index)),
        childCount: itemCount,
      ),
    );
  }
}
