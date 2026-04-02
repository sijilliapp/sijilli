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

  const UnifiedDatePicker({
    super.key,
    required this.initialDate,
    required this.onDateChanged,
    required this.onModeChanged,
    this.initialMode = false,
    this.hijriAdjustment = 0,
  });

  @override
  State<UnifiedDatePicker> createState() => _UnifiedDatePickerState();
}

class _UnifiedDatePickerState extends State<UnifiedDatePicker> {
  late DateTime _selectedDate;
  late HijriCalendar _hijriDate;
  bool _isHijriMode = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
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
    if (widget.initialMode != oldWidget.initialMode) {
      _isHijriMode = widget.initialMode;
    }
  }

  void _updateHijriDate() {
    HijriCalendar.setLocal(Localizations.localeOf(context).languageCode);
    _hijriDate = HijriCalendar.fromDate(_selectedDate);
    
    if (widget.hijriAdjustment != 0) {
      final adjustedGregorian = _selectedDate.add(Duration(days: widget.hijriAdjustment));
      _hijriDate = HijriCalendar.fromDate(adjustedGregorian);
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? Theme.of(context).cardColor : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.transparent : Colors.grey.shade200),
            boxShadow: [
              if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildDateRow(
                isHijri: false,
                isActive: !_isHijriMode,
                onTap: () {
                  if (_isHijriMode) {
                    setState(() => _isHijriMode = false);
                    widget.onModeChanged(false);
                  } else {
                    _showGregorianPicker();
                  }
                },
              ),
              
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1, color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
              ),

              _buildDateRow(
                isHijri: true,
                isActive: _isHijriMode,
                onTap: () {
                   if (!_isHijriMode) {
                    setState(() => _isHijriMode = true);
                    widget.onModeChanged(true);
                  } else {
                    _showHijriPicker();
                  }
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        _buildWeekDaysStrip(),
      ],
    );
  }

  Widget _buildDateRow({
    required bool isHijri,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: isActive 
              ? AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.04) 
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isActive ? Border.all(color: AppColors.primary.withValues(alpha: isDark ? 0.3 : 0.1)) : null,
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isActive ? AppColors.primary : (isDark ? Colors.grey.shade600 : Colors.grey.shade300),
                  width: isActive ? 6 : 2,
                ),
              ),
            ),
            const SizedBox(width: 12),
            
            Text(
              isHijri ? context.l10n.hijri : context.l10n.gregorian,
              style: TextStyle(
                fontSize: 14,
                color: isActive ? AppColors.primary : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              ),
            ),
            
            const Spacer(),
            
            Text(
              isHijri 
                  ? _hijriDate.toFormat("dd MMMM yyyy") 
                  : DateFormat('dd MMMM yyyy', context.l10n.localeName).format(_selectedDate),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isActive ? (isDark ? Colors.white : Colors.black87) : (isDark ? Colors.grey.shade600 : Colors.grey.shade400),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekDaysStrip() {
    final today = DateTime.now();
    final weekDays = List.generate(30, (index) => today.add(Duration(days: index)));

    return SizedBox(
      height: 80, 
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: 30,
        separatorBuilder: (context, index) => const SizedBox(width: 4),
        itemBuilder: (context, index) {
          final date = weekDays[index];
          final isSelected = DateUtils.isSameDay(date, _selectedDate);
          
          HijriCalendar.setLocal(context.l10n.localeName);
          
          final adjustedDate = widget.hijriAdjustment != 0 
              ? date.add(Duration(days: widget.hijriAdjustment))
              : date;
          final hDate = HijriCalendar.fromDate(adjustedDate);
          
          final displayedHijriDay = hDate.hDay;

          final isInteractable = true; 
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return GestureDetector(
            onTap: () => _onGregorianChanged(date),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 50,
              decoration: BoxDecoration(
                color: isSelected 
                    ? AppColors.primary 
                    : (isDark ? Colors.grey.shade800 : Colors.white),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected 
                      ? AppColors.primary 
                      : (isDark ? Colors.grey.shade700 : Colors.grey.shade200),
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
                      color: isSelected ? Colors.white70 : (isInteractable ? (isDark ? Colors.grey.shade400 : Colors.grey.shade600) : Colors.grey.shade400),
                    ),
                  ),
                  const SizedBox(height: 2),
                  
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                       color: isSelected ? Colors.white : (isInteractable ? (isDark ? Colors.white : Colors.black87) : Colors.grey.shade300),
                    ),
                  ),
                  
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? Colors.white.withValues(alpha: 0.2) 
                          : (isDark ? Colors.grey.shade700 : Colors.grey.shade100),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '$displayedHijriDay',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : (isDark ? Colors.grey.shade400 : Colors.grey.shade500),
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

  void _showGregorianPicker() async {
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      builder: (context) => _GregorianPickerSheet(initialDate: _selectedDate),
    );
    if (picked != null) {
      _onGregorianChanged(picked);
    }
  }

  void _showHijriPicker() async {
     final picked = await showModalBottomSheet<HijriCalendar>(
      context: context,
      builder: (context) => _HijriPickerSheet(initialDate: _hijriDate),
    );
    if (picked != null) {
      _onHijriChanged(picked);
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
