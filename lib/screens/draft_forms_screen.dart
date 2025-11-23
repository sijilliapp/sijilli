import 'package:flutter/material.dart';
import 'package:hijri/hijri_calendar.dart';
import '../utils/date_converter.dart';
import '../services/auth_service.dart';

// نموذج بيانات المسودة
class FormDraft {
  final String title;
  final String description;
  final String status;
  final Widget widget;
  final DateTime createdAt;

  FormDraft({
    required this.title,
    required this.description,
    required this.widget,
    this.status = 'قيد التطوير',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

class DraftFormsScreen extends StatefulWidget {
  const DraftFormsScreen({super.key});

  @override
  State<DraftFormsScreen> createState() => _DraftFormsScreenState();
}

class _DraftFormsScreenState extends State<DraftFormsScreen> {
  // قائمة المسودات المتاحة - موحدة ومحسنة
  final List<FormDraft> drafts = [
    FormDraft(
      title: "نموذج إضافة موعد جديد",
      description: "نموذج أصلي محسّن مع تحويل التاريخ الهجري والتحكم بالخصوصية",
      widget: const AppointmentFormDraft(),
      status: "محسن",
    ),
    FormDraft(
      title: "نموذج موعد مع الضيوف",
      description: "نموذج متقدم للمواعيد مع نظام الضيوف والخصوصية المتطورة",
      widget: const AppointmentWithGuestsForm(),
      status: "جديد",
    ),
    FormDraft(
      title: "نموذج تحديث الملف الشخصي",
      description: "نموذج محسن لتحديث بيانات المستخدم مع واجهة تفاعلية",
      widget: const ProfileUpdateFormDraft(),
      status: "مستقر",
    ),
    FormDraft(
      title: "نموذج تقييم الخدمة",
      description: "نموذج لتقييم جودة الخدمة المقدمة مع نظام النجوم",
      widget: const ServiceRatingFormDraft(),
      status: "قيد التطوير",
    ),
    FormDraft(
      title: "غرفة تحويل التاريخ",
      description: "تحويل دقيق بين التقويم الميلادي والهجري مع تصحيح المستخدم",
      widget: const DateConversionRoom(),
      status: "متقدم",
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'مسودات النماذج',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF2196F3),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: () {
              _showAddDraftDialog();
            },
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'إضافة مسودة جديدة',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // معلومات النظام
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'نظام المسودات',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'مكان آمن لتطوير واختبار النماذج الجديدة قبل إضافتها للتطبيق الرئيسي',
                    style: TextStyle(fontSize: 14, color: Colors.blue.shade600),
                  ),
                ],
              ),
            ),

            // قائمة المسودات
            Expanded(
              child: drafts.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: drafts.length,
                      itemBuilder: (context, index) {
                        final draft = drafts[index];
                        return _buildDraftCard(draft, index);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDraftCard(FormDraft draft, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // العنوان والحالة
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    draft.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(draft.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    draft.status,
                    style: TextStyle(
                      fontSize: 12,
                      color: _getStatusColor(draft.status),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // الوصف
            Text(
              draft.description,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),

            // معلومات إضافية
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  'تم الإنشاء: ${_formatDate(draft.createdAt)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // أزرار الإجراءات
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _previewDraft(draft),
                    icon: const Icon(Icons.visibility, size: 18),
                    label: const Text('معاينة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2196F3),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _editDraft(draft, index),
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('تحرير'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2196F3),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _deleteDraft(index),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.all(12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Icon(Icons.delete_outline, size: 18),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.description_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد مسودات بعد',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'اضغط على + لإضافة مسودة جديدة',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  void _previewDraft(FormDraft draft) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => DraftPreviewScreen(draft: draft)),
    );
  }

  void _editDraft(FormDraft draft, int index) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تحرير ${draft.title}'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _deleteDraft(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المسودة'),
        content: const Text('هل أنت متأكد من حذف هذه المسودة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                drafts.removeAt(index);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم حذف المسودة'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  void _showAddDraftDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('إضافة مسودة جديدة - قريباً'),
        backgroundColor: Colors.green,
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'محسن':
        return Colors.blue.shade700;
      case 'جديد':
        return Colors.green.shade700;
      case 'مستقر':
        return Colors.teal.shade700;
      case 'قيد التطوير':
        return Colors.orange.shade700;
      case 'متقدم':
        return Colors.purple.shade700;
      default:
        return Colors.grey.shade700;
    }
  }
}

// شاشة معاينة المسودة
class DraftPreviewScreen extends StatelessWidget {
  final FormDraft draft;

  const DraftPreviewScreen({super.key, required this.draft});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          draft.title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF2196F3),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: () => _exportDraft(context),
            icon: const Icon(Icons.file_download),
            tooltip: 'تصدير للمشروع الرئيسي',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // معلومات المسودة
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      draft.description,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'الحالة: ${draft.status}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // النموذج المعاين
              draft.widget,
            ],
          ),
        ),
      ),
    );
  }

  void _exportDraft(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تصدير المسودة'),
        content: const Text('هل تريد نقل هذه المسودة إلى المشروع الرئيسي؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم تصدير المسودة - تحتاج لتطبيق يدوي'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('تصدير'),
          ),
        ],
      ),
    );
  }
}

// مسودات النماذج - أمثلة للتطوير
class AppointmentFormDraft extends StatefulWidget {
  const AppointmentFormDraft({super.key});

  @override
  State<AppointmentFormDraft> createState() => _AppointmentFormDraftState();
}

class _AppointmentFormDraftState extends State<AppointmentFormDraft> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _regionController = TextEditingController();
  final _buildingController = TextEditingController();

  bool _isPrivate = false;
  String _dateType = 'ميلادي';
  String _selectedMonth = 'يناير';
  int _selectedDay = DateTime.now().day;
  int _selectedYear = DateTime.now().year;
  String _selectedWeekday = 'السبت';
  int _selectedHour = 9;
  int _selectedMinute = 0;
  String _selectedPeriod = 'مساءً';
  String _selectedDuration = '45 دقيقة';
  int _endDay = DateTime.now().day;
  String _endMonth = 'يناير';
  int _endYear = DateTime.now().year;

  // متغيرات تاريخ الانتهاء الهجري
  int _endHijriDay = 1;
  String _endHijriMonth = 'محرم';
  int _endHijriYear = 1446;

  // Precise date conversion using centralized DateConverter
  late DateTime _selectedGregorianDate;
  late HijriCalendar _selectedHijriDate;
  final AuthService _authService = AuthService();

  // إدارة الضيوف للمواعيد
  final List<String> _selectedGuests = [];
  final List<Map<String, dynamic>> _availableFriends = [
    {'id': 'friend1', 'name': 'أحمد محمد', 'avatar': '👤'},
    {'id': 'friend2', 'name': 'فاطمة علي', 'avatar': '👤'},
    {'id': 'friend3', 'name': 'محمد السعيد', 'avatar': '👤'},
    {'id': 'friend4', 'name': 'نور الهدى', 'avatar': '👤'},
    {'id': 'friend5', 'name': 'عبد الله أحمد', 'avatar': '👤'},
  ];

  @override
  void initState() {
    super.initState();
    // Initialize with today's date
    final today = DateTime.now();
    _selectedGregorianDate = today;
    // Apply user's Hijri adjustment using centralized DateConverter
    final userAdjustment = _authService.currentUser?.hijriAdjustment ?? 0;
    _selectedHijriDate = DateConverter.toHijri(today, adjustment: userAdjustment);

    _selectedDay = today.day;
    _selectedMonth = _getMonthName(today.month);
    _selectedYear = today.year;
    _selectedWeekday = _getWeekdayName(today.weekday);

    _endDay = today.day;
    _endMonth = _selectedMonth;
    _endYear = today.year;

    // Initialize end Hijri date with user adjustment
    final hijriToday = DateConverter.toHijri(today, adjustment: userAdjustment);
    _endHijriDay = hijriToday.hDay;
    _endHijriMonth = _getHijriMonthName(hijriToday.hMonth);
    _endHijriYear = hijriToday.hYear;
  }

  // Helper methods for date conversion and display
  String _getMonthName(int month) {
    const months = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    return months[month - 1];
  }

  String _getHijriMonthName(int month) {
    const months = [
      'محرم',
      'صفر',
      'ربيع الأول',
      'ربيع الآخر',
      'جمادى الأولى',
      'جمادى الآخرة',
      'رجب',
      'شعبان',
      'رمضان',
      'شوال',
      'ذو القعدة',
      'ذو الحجة',
    ];
    return months[month - 1];
  }

  String _getWeekdayName(int weekday) {
    const weekdays = [
      'الإثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد',
    ];
    return weekdays[weekday - 1];
  }

  int _getMonthNumber(String monthName) {
    final gregorianMonths = _gregorianMonths;
    final hijriMonths = _hijriMonths;

    if (gregorianMonths.contains(monthName)) {
      return gregorianMonths.indexOf(monthName) + 1;
    } else if (hijriMonths.contains(monthName)) {
      return hijriMonths.indexOf(monthName) + 1;
    }
    return 1;
  }

  // Precise date update methods using centralized DateConverter
  void _updateDateFromGregorian() {
    try {
      final monthNumber = _getMonthNumber(_selectedMonth);
      final gregorianDate = DateTime(_selectedYear, monthNumber, _selectedDay);
      // Apply user adjustment via DateConverter
      final userAdjustment = _authService.currentUser?.hijriAdjustment ?? 0;
      final hijriDate = DateConverter.toHijri(gregorianDate, adjustment: userAdjustment);

      setState(() {
        _selectedGregorianDate = gregorianDate;
        _selectedHijriDate = hijriDate;
        _selectedWeekday = _getWeekdayName(gregorianDate.weekday);
      });
    } catch (e) {
      // Handle invalid date
    }
  }

  void _updateDateFromHijri() {
    try {
      final monthNumber = _getMonthNumber(_selectedMonth);
      final hijriDate = HijriCalendar()
        ..hYear = _selectedYear
        ..hMonth = monthNumber
        ..hDay = _selectedDay;

      // Convert Hijri to Gregorian with reverse adjustment via DateConverter
      final userAdjustment = _authService.currentUser?.hijriAdjustment ?? 0;
      final gregorianDate = DateConverter.toGregorian(hijriDate, adjustment: userAdjustment);

      setState(() {
        _selectedHijriDate = hijriDate;
        _selectedGregorianDate = gregorianDate;
        _selectedWeekday = _getWeekdayName(gregorianDate.weekday);
      });
    } catch (e) {
      // Handle invalid date
    }
  }

  // Update date to match selected weekday
  void _updateDateToMatchWeekday(String selectedWeekday) {
    try {
      // Get current date
      final currentDate = _dateType == 'ميلادي'
          ? _selectedGregorianDate
          : _selectedGregorianDate;

      // Get target weekday number (1=Monday, 7=Sunday)
      final targetWeekday = _getWeekdayNumber(selectedWeekday);
      final currentWeekday = currentDate.weekday;

      // Calculate days difference to reach target weekday
      int daysDifference = targetWeekday - currentWeekday;
      if (daysDifference < 0) {
        daysDifference += 7; // Move to next week
      }

      // Calculate new date
      final newGregorianDate = currentDate.add(Duration(days: daysDifference));
      // Apply user adjustment via DateConverter
      final userAdjustment = _authService.currentUser?.hijriAdjustment ?? 0;
      final newHijriDate = DateConverter.toHijri(newGregorianDate, adjustment: userAdjustment);

      setState(() {
        _selectedGregorianDate = newGregorianDate;
        _selectedHijriDate = newHijriDate;

        if (_dateType == 'ميلادي') {
          _selectedDay = newGregorianDate.day;
          _selectedMonth = _getMonthName(newGregorianDate.month);
          _selectedYear = newGregorianDate.year;
        } else {
          _selectedDay = newHijriDate.hDay;
          _selectedMonth = _getHijriMonthName(newHijriDate.hMonth);
          _selectedYear = newHijriDate.hYear;
        }
      });
    } catch (e) {
      // Handle invalid date
    }
  }

  // Helper method to get weekday number from Arabic name
  int _getWeekdayNumber(String weekdayName) {
    const weekdays = {
      'الإثنين': 1,
      'الثلاثاء': 2,
      'الأربعاء': 3,
      'الخميس': 4,
      'الجمعة': 5,
      'السبت': 6,
      'الأحد': 7,
    };
    return weekdays[weekdayName] ?? 1;
  }

  // قوائم البيانات
  final List<String> _gregorianMonths = [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];

  final List<String> _hijriMonths = [
    'محرم',
    'صفر',
    'ربيع الأول',
    'ربيع الآخر',
    'جمادى الأولى',
    'جمادى الآخرة',
    'رجب',
    'شعبان',
    'رمضان',
    'شوال',
    'ذو القعدة',
    'ذو الحجة',
  ];

  final List<String> _weekdays = [
    'السبت',
    'الأحد',
    'الإثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
  ];

  final List<String> _durations = [
    '15 دقيقة',
    '30 دقيقة',
    '45 دقيقة',
    '1 ساعة',
    '2 ساعتين',
    '3 ساعات',
    'عدة أيام',
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'إضافة موعد جديد',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'موضوع الموعد',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    prefixIcon: const Icon(Icons.title),
                    suffixIcon: Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: _isPrivate
                            ? Colors.orange.shade50
                            : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _isPrivate ? Colors.orange : Colors.green,
                          width: 1,
                        ),
                      ),
                      child: IconButton(
                        onPressed: () {
                          setState(() {
                            _isPrivate = !_isPrivate;
                          });
                        },
                        icon: Icon(
                          _isPrivate ? Icons.lock : Icons.public,
                          color: _isPrivate ? Colors.orange : Colors.green,
                          size: 20,
                        ),
                        tooltip: _isPrivate ? 'موعد خاص' : 'موعد عام',
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'الرجاء إدخال موضوع الموعد';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // السطر الثاني: المنطقة والمبنى
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _regionController,
                        decoration: InputDecoration(
                          labelText: 'المنطقة',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          prefixIcon: const Icon(Icons.location_on),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _buildingController,
                        decoration: InputDecoration(
                          labelText: 'المبنى',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          prefixIcon: const Icon(Icons.business),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // السطر الثالث: اختيار نوع التاريخ
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // اختيار نوع التاريخ
                    Row(
                      children: [
                        Radio<String>(
                          value: 'ميلادي',
                          groupValue: _dateType,
                          onChanged: (value) {
                            setState(() {
                              _dateType = value!;
                              if (value == 'ميلادي') {
                                // Switch to Gregorian - use current gregorian date
                                _selectedYear = _selectedGregorianDate.year;
                                _selectedMonth = _getMonthName(
                                  _selectedGregorianDate.month,
                                );
                                _selectedDay = _selectedGregorianDate.day;

                                // Update end date to Gregorian
                                _endYear = _selectedGregorianDate.year;
                                _endMonth = _getMonthName(_selectedGregorianDate.month);
                                _endDay = _selectedGregorianDate.day;
                              } else {
                                // Switch to Hijri - use current hijri date
                                _selectedYear = _selectedHijriDate.hYear;
                                _selectedMonth = _getHijriMonthName(
                                  _selectedHijriDate.hMonth,
                                );
                                _selectedDay = _selectedHijriDate.hDay;

                                // Update end date to Hijri
                                _endHijriYear = _selectedHijriDate.hYear;
                                _endHijriMonth = _getHijriMonthName(_selectedHijriDate.hMonth);
                                _endHijriDay = _selectedHijriDate.hDay;
                              }
                            });
                          },
                        ),
                        const Text('ميلادي'),
                        const SizedBox(width: 20),
                        Radio<String>(
                          value: 'هجري',
                          groupValue: _dateType,
                          onChanged: (value) {
                            setState(() {
                              _dateType = value!;
                              if (value == 'هجري') {
                                // Switch to Hijri - use current hijri date
                                _selectedYear = _selectedHijriDate.hYear;
                                _selectedMonth = _getHijriMonthName(
                                  _selectedHijriDate.hMonth,
                                );
                                _selectedDay = _selectedHijriDate.hDay;

                                // Update end date to Hijri
                                _endHijriYear = _selectedHijriDate.hYear;
                                _endHijriMonth = _getHijriMonthName(_selectedHijriDate.hMonth);
                                _endHijriDay = _selectedHijriDate.hDay;
                              } else {
                                // Switch to Gregorian - use current gregorian date
                                _selectedYear = _selectedGregorianDate.year;
                                _selectedMonth = _getMonthName(
                                  _selectedGregorianDate.month,
                                );
                                _selectedDay = _selectedGregorianDate.day;

                                // Update end date to Gregorian
                                _endYear = _selectedGregorianDate.year;
                                _endMonth = _getMonthName(_selectedGregorianDate.month);
                                _endDay = _selectedGregorianDate.day;
                              }
                            });
                          },
                        ),
                        const Text('هجري'),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // التاريخ الميلادي (نشط عند اختيار ميلادي)
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_month,
                          color: _dateType == 'ميلادي' ? Colors.blue.shade700 : Colors.grey.shade400,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'التاريخ الميلادي',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _dateType == 'ميلادي' ? Colors.blue.shade700 : Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // يوم ميلادي
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<int>(
                            initialValue: _selectedGregorianDate.day,
                            decoration: InputDecoration(
                              labelText: 'اليوم',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              enabled: _dateType == 'ميلادي',
                            ),
                            items: List.generate(31, (index) => index + 1)
                                .map(
                                  (day) => DropdownMenuItem(
                                    value: day,
                                    child: Text(
                                      day.toString(),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: _dateType == 'ميلادي' ? Colors.black : Colors.grey.shade400,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: _dateType == 'ميلادي' ? (value) {
                              setState(() {
                                _selectedGregorianDate = DateTime(
                                  _selectedGregorianDate.year,
                                  _selectedGregorianDate.month,
                                  value!,
                                );
                                _selectedDay = value;
                                _updateDateFromGregorian();
                              });
                            } : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // شهر ميلادي
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            initialValue: _getMonthName(_selectedGregorianDate.month),
                            decoration: InputDecoration(
                              labelText: 'الشهر',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              enabled: _dateType == 'ميلادي',
                            ),
                            items: _gregorianMonths
                                .map(
                                  (month) => DropdownMenuItem(
                                    value: month,
                                    child: Text(
                                      month,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: _dateType == 'ميلادي' ? Colors.black : Colors.grey.shade400,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: _dateType == 'ميلادي' ? (value) {
                              setState(() {
                                final monthIndex = _gregorianMonths.indexOf(value!) + 1;
                                _selectedGregorianDate = DateTime(
                                  _selectedGregorianDate.year,
                                  monthIndex,
                                  _selectedGregorianDate.day,
                                );
                                _selectedMonth = value;
                                _updateDateFromGregorian();
                              });
                            } : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // سنة ميلادي
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<int>(
                            initialValue: _selectedGregorianDate.year,
                            decoration: InputDecoration(
                              labelText: 'السنة',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              enabled: _dateType == 'ميلادي',
                            ),
                            items: List.generate(10, (index) => DateTime.now().year + index)
                                .map(
                                  (year) => DropdownMenuItem(
                                    value: year,
                                    child: Text(
                                      year.toString(),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: _dateType == 'ميلادي' ? Colors.black : Colors.grey.shade400,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: _dateType == 'ميلادي' ? (value) {
                              setState(() {
                                _selectedGregorianDate = DateTime(
                                  value!,
                                  _selectedGregorianDate.month,
                                  _selectedGregorianDate.day,
                                );
                                _selectedYear = value;
                                _updateDateFromGregorian();
                              });
                            } : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // التاريخ الهجري (نشط عند اختيار هجري)
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_month_outlined,
                          color: _dateType == 'هجري' ? Colors.orange.shade700 : Colors.grey.shade400,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'التاريخ الهجري',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _dateType == 'هجري' ? Colors.orange.shade700 : Colors.grey.shade400,
                          ),
                        ),
                        // Adjustment badge showing user's Hijri correction
                        if ((_authService.currentUser?.hijriAdjustment ?? 0) != 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.orange.shade300),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.tune, size: 14, color: Colors.orange.shade700),
                                const SizedBox(width: 4),
                                Text(
                                  'تصحيح: ${(_authService.currentUser?.hijriAdjustment ?? 0) > 0 ? '+' : ''}${_authService.currentUser?.hijriAdjustment ?? 0}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // يوم هجري
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<int>(
                            initialValue: _selectedHijriDate.hDay,
                            decoration: InputDecoration(
                              labelText: 'اليوم',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              enabled: _dateType == 'هجري',
                            ),
                            items: List.generate(30, (index) => index + 1)
                                .map(
                                  (day) => DropdownMenuItem(
                                    value: day,
                                    child: Text(
                                      day.toString(),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: _dateType == 'هجري' ? Colors.black : Colors.grey.shade400,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: _dateType == 'هجري' ? (value) {
                              setState(() {
                                _selectedHijriDate = HijriCalendar()
                                  ..hYear = _selectedHijriDate.hYear
                                  ..hMonth = _selectedHijriDate.hMonth
                                  ..hDay = value!;
                                _selectedDay = value;
                                _updateDateFromHijri();
                              });
                            } : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // شهر هجري
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            initialValue: _getHijriMonthName(_selectedHijriDate.hMonth),
                            decoration: InputDecoration(
                              labelText: 'الشهر',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              enabled: _dateType == 'هجري',
                            ),
                            items: _hijriMonths
                                .map(
                                  (month) => DropdownMenuItem(
                                    value: month,
                                    child: Text(
                                      month,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: _dateType == 'هجري' ? Colors.black : Colors.grey.shade400,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: _dateType == 'هجري' ? (value) {
                              setState(() {
                                final monthIndex = _hijriMonths.indexOf(value!) + 1;
                                _selectedHijriDate = HijriCalendar()
                                  ..hYear = _selectedHijriDate.hYear
                                  ..hMonth = monthIndex
                                  ..hDay = _selectedHijriDate.hDay;
                                _selectedMonth = value;
                                _updateDateFromHijri();
                              });
                            } : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // سنة هجري
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<int>(
                            initialValue: _selectedHijriDate.hYear,
                            decoration: InputDecoration(
                              labelText: 'السنة',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              enabled: _dateType == 'هجري',
                            ),
                            items: List.generate(10, (index) => HijriCalendar.now().hYear + index)
                                .map(
                                  (year) => DropdownMenuItem(
                                    value: year,
                                    child: Text(
                                      year.toString(),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: _dateType == 'هجري' ? Colors.black : Colors.grey.shade400,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: _dateType == 'هجري' ? (value) {
                              setState(() {
                                _selectedHijriDate = HijriCalendar()
                                  ..hYear = value!
                                  ..hMonth = _selectedHijriDate.hMonth
                                  ..hDay = _selectedHijriDate.hDay;
                                _selectedYear = value;
                                _updateDateFromHijri();
                              });
                            } : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // السطر الرابع: يوم الأسبوع ومدة الموعد
                Row(
                  children: [
                    // اختيار يوم الأسبوع
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedWeekday,
                        decoration: InputDecoration(
                          labelText: 'يوم الأسبوع',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          prefixIcon: Icon(
                            Icons.calendar_today,
                            color: _dateType == 'ميلادي' ? null : Colors.grey.shade400,
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          enabled: _dateType == 'ميلادي',
                        ),
                        items: _weekdays
                            .map(
                              (day) => DropdownMenuItem(
                                value: day,
                                child: Text(
                                  day,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _dateType == 'ميلادي' ? Colors.black : Colors.grey.shade400,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: _dateType == 'ميلادي' ? (value) {
                          setState(() {
                            _selectedWeekday = value!;
                            // Update date to match the selected weekday
                            _updateDateToMatchWeekday(value);
                          });
                        } : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // اختيار مدة الموعد
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedDuration,
                        decoration: InputDecoration(
                          labelText: 'مدة الموعد',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          prefixIcon: const Icon(Icons.timer),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: _durations
                            .map(
                              (duration) => DropdownMenuItem(
                                value: duration,
                                child: Text(
                                  duration,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedDuration = value!;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // تاريخ انتهاء الموعد (يظهر فقط عند اختيار "عدة أيام")
                if (_selectedDuration == 'عدة أيام')
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'تاريخ انتهاء الموعد',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          // يوم الانتهاء
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<int>(
                              initialValue: _dateType == 'ميلادي' ? _endDay : _endHijriDay,
                              decoration: InputDecoration(
                                labelText: 'اليوم',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              items: List.generate(_dateType == 'ميلادي' ? 31 : 30, (index) => index + 1)
                                  .map(
                                    (day) => DropdownMenuItem(
                                      value: day,
                                      child: Text(
                                        day.toString(),
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  if (_dateType == 'ميلادي') {
                                    _endDay = value!;
                                  } else {
                                    _endHijriDay = value!;
                                  }
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          // شهر الانتهاء
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<String>(
                              initialValue:
                                  (_dateType == 'ميلادي'
                                          ? _gregorianMonths
                                          : _hijriMonths)
                                      .contains(_dateType == 'ميلادي' ? _endMonth : _endHijriMonth)
                                  ? (_dateType == 'ميلادي' ? _endMonth : _endHijriMonth)
                                  : (_dateType == 'ميلادي'
                                        ? _gregorianMonths[0]
                                        : _hijriMonths[0]),
                              decoration: InputDecoration(
                                labelText: 'الشهر',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              items:
                                  (_dateType == 'ميلادي'
                                          ? _gregorianMonths
                                          : _hijriMonths)
                                      .map(
                                        (month) => DropdownMenuItem(
                                          value: month,
                                          child: Text(
                                            month,
                                            style: const TextStyle(
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                              onChanged: (value) {
                                setState(() {
                                  if (_dateType == 'ميلادي') {
                                    _endMonth = value!;
                                  } else {
                                    _endHijriMonth = value!;
                                  }
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          // سنة الانتهاء
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<int>(
                              initialValue: _dateType == 'ميلادي' ? _endYear : _endHijriYear,
                              decoration: InputDecoration(
                                labelText: 'السنة',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              items: _dateType == 'ميلادي'
                                  ? List.generate(
                                          10,
                                          (index) =>
                                              DateTime.now().year + index,
                                        )
                                        .map(
                                          (year) => DropdownMenuItem(
                                            value: year,
                                            child: Text(
                                              year.toString(),
                                              style: const TextStyle(
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList()
                                  : List.generate(
                                          10,
                                          (index) =>
                                              HijriCalendar.now().hYear + index,
                                        )
                                        .map(
                                          (year) => DropdownMenuItem(
                                            value: year,
                                            child: Text(
                                              year.toString(),
                                              style: const TextStyle(
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                              onChanged: (value) {
                                setState(() {
                                  if (_dateType == 'ميلادي') {
                                    _endYear = value!;
                                  } else {
                                    _endHijriYear = value!;
                                  }
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                if (_selectedDuration == 'عدة أيام') const SizedBox(height: 16),

                // اختيار الوقت (لا يظهر عند اختيار "عدة أيام")
                if (_selectedDuration != 'عدة أيام')
                  Column(
                    children: [
                      // الساعة والدقيقة في صف واحد
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<int>(
                              initialValue: _selectedHour,
                              decoration: InputDecoration(
                                labelText: 'الساعة',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              items: List.generate(12, (index) => index + 1)
                                  .map(
                                    (hour) => DropdownMenuItem(
                                      value: hour,
                                      child: Text(
                                        hour.toString(),
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedHour = value!;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<int>(
                              initialValue: _selectedMinute,
                              decoration: InputDecoration(
                                labelText: 'الدقيقة',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              items: [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55]
                                  .map(
                                    (minute) => DropdownMenuItem(
                                      value: minute,
                                      child: Text(
                                        minute.toString().padLeft(2, '0'),
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedMinute = value!;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedPeriod,
                              decoration: InputDecoration(
                                labelText: 'فترة',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              items: ['صباحاً', 'مساءً']
                                  .map(
                                    (period) => DropdownMenuItem(
                                      value: period,
                                      child: Text(
                                        period,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedPeriod = value!;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                const SizedBox(height: 24),

                // معاينة التاريخ بتحويل دقيق
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'معاينة التاريخ:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _dateType == 'ميلادي'
                            ? 'التاريخ الميلادي: ${_selectedGregorianDate.day}/${_getMonthName(_selectedGregorianDate.month)}/${_selectedGregorianDate.year}'
                            : 'التاريخ الهجري: ${_selectedHijriDate.hDay}/${_getHijriMonthName(_selectedHijriDate.hMonth)}/${_selectedHijriDate.hYear} هـ',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'اليوم: $_selectedWeekday',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Divider(),
                      const SizedBox(height: 4),
                      Text(
                        _dateType == 'ميلادي'
                            ? 'التاريخ الهجري المقابل: ${_selectedHijriDate.hDay}/${_getHijriMonthName(_selectedHijriDate.hMonth)}/${_selectedHijriDate.hYear} هـ'
                            : 'التاريخ الميلادي المقابل: ${_selectedGregorianDate.day}/${_getMonthName(_selectedGregorianDate.month)}/${_selectedGregorianDate.year}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'تحويل دقيق باستخدام مكتبة hijri مع تصحيح المستخدم',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // قسم إدارة الضيوف
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.people, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'إدارة الضيوف',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${_selectedGuests.length} مدعو',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // قائمة الضيوف المختارين
                      if (_selectedGuests.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _selectedGuests.map((guestId) {
                            final guest = _availableFriends.firstWhere(
                              (f) => f['id'] == guestId,
                              orElse: () => {'name': 'غير معروف', 'avatar': '❓'},
                            );
                            return Chip(
                              avatar: Text(guest['avatar']),
                              label: Text(guest['name']),
                              deleteIcon: const Icon(Icons.close, size: 18),
                              onDeleted: () {
                                setState(() {
                                  _selectedGuests.remove(guestId);
                                });
                              },
                            );
                          }).toList(),
                        ),

                      const SizedBox(height: 12),

                      // زر إضافة ضيوف
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _showGuestSelectionDialog,
                          icon: const Icon(Icons.person_add),
                          label: const Text('إضافة ضيوف'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blue.shade700,
                            side: BorderSide(color: Colors.blue.shade300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'تم حفظ الموعد (مسودة)\n'
                              'نوع: ${_isPrivate ? "خاص" : "عام"}\n'
                              'التاريخ: $_dateType - $_selectedMonth $_selectedDay, $_selectedYear\n'
                              'مدة الموعد: $_selectedDuration\n'
                              '${_selectedDuration == "عدة أيام" ? "تاريخ الانتهاء: ${_dateType == 'ميلادي' ? '$_endMonth $_endDay, $_endYear' : '$_endHijriMonth $_endHijriDay, $_endHijriYear هـ'}" : "الوقت: $_selectedHour:${_selectedMinute.toString().padLeft(2, '0')} $_selectedPeriod"}\n'
                              'عدد الضيوف: ${_selectedGuests.length}',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2196F3),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'حفظ الموعد',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showGuestSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اختيار الضيوف'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _availableFriends.length,
            itemBuilder: (context, index) {
              final friend = _availableFriends[index];
              final isSelected = _selectedGuests.contains(friend['id']);

              return CheckboxListTile(
                title: Text(friend['name']),
                subtitle: Text('ID: ${friend['id']}'),
                secondary: Text(friend['avatar'], style: const TextStyle(fontSize: 20)),
                value: isSelected,
                onChanged: (bool? value) {
                  setState(() {
                    if (value == true) {
                      _selectedGuests.add(friend['id']);
                    } else {
                      _selectedGuests.remove(friend['id']);
                    }
                  });
                  Navigator.pop(context);
                  _showGuestSelectionDialog(); // إعادة فتح الحوار لإظهار التحديث
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _regionController.dispose();
    _buildingController.dispose();
    super.dispose();
  }
}

class ProfileUpdateFormDraft extends StatelessWidget {
  const ProfileUpdateFormDraft({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'نموذج تحديث الملف الشخصي',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text('هذا النموذج قيد التطوير...'),
            SizedBox(height: 16),
            LinearProgressIndicator(value: 0.3),
          ],
        ),
      ),
    );
  }
}

class ServiceRatingFormDraft extends StatelessWidget {
  const ServiceRatingFormDraft({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'نموذج تقييم الخدمة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text('هذا النموذج قيد التطوير...'),
            SizedBox(height: 16),
            LinearProgressIndicator(value: 0.1),
          ],
        ),
      ),
    );
  }
}

// غرفة تحويل التاريخ - تحويل دقيق باستخدام مكتبة hijri
class DateConversionRoom extends StatefulWidget {
  const DateConversionRoom({super.key});

  @override
  State<DateConversionRoom> createState() => _DateConversionRoomState();
}

class _DateConversionRoomState extends State<DateConversionRoom> {
  DateTime _selectedGregorianDate = DateTime.now();
  HijriCalendar _selectedHijriDate = HijriCalendar.now();
  final AuthService _authService = AuthService();

  // Controllers for manual input
  final _gregorianDayController = TextEditingController();
  final _gregorianMonthController = TextEditingController();
  final _gregorianYearController = TextEditingController();
  final _hijriDayController = TextEditingController();
  final _hijriMonthController = TextEditingController();
  final _hijriYearController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeWithToday();
  }

  void _initializeWithToday() {
    final today = DateTime.now();
    _selectedGregorianDate = today;
    // Apply user adjustment via centralized DateConverter
    final userAdjustment = _authService.currentUser?.hijriAdjustment ?? 0;
    _selectedHijriDate = DateConverter.toHijri(today, adjustment: userAdjustment);
    _updateControllers();
  }

  void _updateControllers() {
    _gregorianDayController.text = _selectedGregorianDate.day.toString();
    _gregorianMonthController.text = _selectedGregorianDate.month.toString();
    _gregorianYearController.text = _selectedGregorianDate.year.toString();
    _hijriDayController.text = _selectedHijriDate.hDay.toString();
    _hijriMonthController.text = _selectedHijriDate.hMonth.toString();
    _hijriYearController.text = _selectedHijriDate.hYear.toString();
  }

  void _convertGregorianToHijri() {
    try {
      final day = int.parse(_gregorianDayController.text);
      final month = int.parse(_gregorianMonthController.text);
      final year = int.parse(_gregorianYearController.text);

      final gregorianDate = DateTime(year, month, day);
      // Apply user adjustment via centralized DateConverter
      final userAdjustment = _authService.currentUser?.hijriAdjustment ?? 0;
      final hijriDate = DateConverter.toHijri(gregorianDate, adjustment: userAdjustment);

      setState(() {
        _selectedGregorianDate = gregorianDate;
        _selectedHijriDate = hijriDate;
        _hijriDayController.text = hijriDate.hDay.toString();
        _hijriMonthController.text = hijriDate.hMonth.toString();
        _hijriYearController.text = hijriDate.hYear.toString();
      });
    } catch (e) {
      _showErrorDialog('خطأ في التاريخ الميلادي', 'يرجى إدخال تاريخ صحيح');
    }
  }

  void _convertHijriToGregorian() {
    try {
      final day = int.parse(_hijriDayController.text);
      final month = int.parse(_hijriMonthController.text);
      final year = int.parse(_hijriYearController.text);

      // Convert Hijri to Gregorian with reverse adjustment via centralized DateConverter
      final userAdjustment = _authService.currentUser?.hijriAdjustment ?? 0;
      final hijriDate = HijriCalendar()
        ..hYear = year
        ..hMonth = month
        ..hDay = day;
      final gregorianDate = DateConverter.toGregorian(hijriDate, adjustment: userAdjustment);
      // Re-convert to get properly adjusted Hijri date for display
      final adjustedHijriDate = DateConverter.toHijri(gregorianDate, adjustment: userAdjustment);

      setState(() {
        _selectedHijriDate = adjustedHijriDate;
        _selectedGregorianDate = gregorianDate;
        _gregorianDayController.text = gregorianDate.day.toString();
        _gregorianMonthController.text = gregorianDate.month.toString();
        _gregorianYearController.text = gregorianDate.year.toString();
      });
    } catch (e) {
      _showErrorDialog('خطأ في التاريخ الهجري', 'يرجى إدخال تاريخ هجري صحيح');
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  String _getGregorianMonthName(int month) {
    const months = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    return months[month - 1];
  }

  String _getHijriMonthName(int month) {
    const months = [
      'محرم',
      'صفر',
      'ربيع الأول',
      'ربيع الآخر',
      'جمادى الأولى',
      'جمادى الآخرة',
      'رجب',
      'شعبان',
      'رمضان',
      'شوال',
      'ذو القعدة',
      'ذو الحجة',
    ];
    return months[month - 1];
  }

  String _getWeekdayName(int weekday) {
    const weekdays = [
      'الإثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد',
    ];
    return weekdays[weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SingleChildScrollView(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.swap_horiz, color: Color(0xFF2196F3), size: 28),
                    const SizedBox(width: 8),
                    const Text(
                      'غرفة تحويل التاريخ',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2196F3),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'تحويل دقيق بين التقويم الميلادي والهجري مع تصحيح المستخدم',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            color: Colors.blue.shade700,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'التاريخ الميلادي',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _gregorianDayController,
                              decoration: InputDecoration(
                                labelText: 'اليوم',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _gregorianMonthController,
                              decoration: InputDecoration(
                                labelText: 'الشهر',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _gregorianYearController,
                              decoration: InputDecoration(
                                labelText: 'السنة',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'التاريخ بالتفصيل:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            Text(
                              '${_selectedGregorianDate.day} ${_getGregorianMonthName(_selectedGregorianDate.month)} ${_selectedGregorianDate.year}م',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              'يوم ${_getWeekdayName(_selectedGregorianDate.weekday)}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _convertGregorianToHijri,
                        icon: const Icon(Icons.arrow_downward),
                        label: const Text('تحويل إلى هجري'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2196F3),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _convertHijriToGregorian,
                        icon: const Icon(Icons.arrow_upward),
                        label: const Text('تحويل إلى ميلادي'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_month,
                            color: Colors.green.shade700,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'التاريخ الهجري',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _hijriDayController,
                              decoration: InputDecoration(
                                labelText: 'اليوم',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _hijriMonthController,
                              decoration: InputDecoration(
                                labelText: 'الشهر',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _hijriYearController,
                              decoration: InputDecoration(
                                labelText: 'السنة',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'التاريخ بالتفصيل:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            Text(
                              '${_selectedHijriDate.hDay} ${_getHijriMonthName(_selectedHijriDate.hMonth)} ${_selectedHijriDate.hYear}هـ',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info, color: Colors.blue.shade600),
                          const SizedBox(width: 8),
                          Text(
                            'معلومات إضافية',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• يستخدم هذا النموذج مكتبة hijri مع تصحيح المستخدم',
                        style: TextStyle(color: Colors.grey),
                      ),
                      Text(
                        '• التحويل دقيق ومعتمد على قواعد فلكية',
                        style: TextStyle(color: Colors.grey),
                      ),
                      Text(
                        '• يمكن استخدامه في المشاريع الرئيسية',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _initializeWithToday();
                          });
                        },
                        icon: const Icon(Icons.today),
                        label: const Text('العودة لليوم'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2196F3),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _gregorianDayController.dispose();
    _gregorianMonthController.dispose();
    _gregorianYearController.dispose();
    _hijriDayController.dispose();
    _hijriMonthController.dispose();
    _hijriYearController.dispose();
    super.dispose();
  }
}

// نموذج المواعيد المتقدم مع الضيوف
class AppointmentWithGuestsForm extends StatefulWidget {
  const AppointmentWithGuestsForm({super.key});

  @override
  State<AppointmentWithGuestsForm> createState() => _AppointmentWithGuestsFormState();
}

class _AppointmentWithGuestsFormState extends State<AppointmentWithGuestsForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _regionController = TextEditingController();
  final _buildingController = TextEditingController();

  bool _isPrivate = false;

  // إدارة الضيوف للمواعيد
  final List<String> _selectedGuests = [];
  final List<Map<String, dynamic>> _availableFriends = [
    {'id': 'friend1', 'name': 'أحمد محمد', 'avatar': '👤'},
    {'id': 'friend2', 'name': 'فاطمة علي', 'avatar': '👤'},
    {'id': 'friend3', 'name': 'محمد السعيد', 'avatar': '👤'},
    {'id': 'friend4', 'name': 'نور الهدى', 'avatar': '👤'},
    {'id': 'friend5', 'name': 'عبد الله أحمد', 'avatar': '👤'},
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'إضافة موعد مع الضيوف',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                // حقل العنوان مع زر الخصوصية
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'موضوع الموعد',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    prefixIcon: const Icon(Icons.title),
                    suffixIcon: Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: _isPrivate
                            ? Colors.orange.shade50
                            : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _isPrivate ? Colors.orange : Colors.green,
                          width: 1,
                        ),
                      ),
                      child: IconButton(
                        onPressed: () {
                          setState(() {
                            _isPrivate = !_isPrivate;
                          });
                        },
                        icon: Icon(
                          _isPrivate ? Icons.lock : Icons.public,
                          color: _isPrivate ? Colors.orange : Colors.green,
                          size: 20,
                        ),
                        tooltip: _isPrivate ? 'موعد خاص' : 'موعد عام',
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'الرجاء إدخال موضوع الموعد';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // المنطقة والمبنى
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _regionController,
                        decoration: InputDecoration(
                          labelText: 'المنطقة',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          prefixIcon: const Icon(Icons.location_on),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _buildingController,
                        decoration: InputDecoration(
                          labelText: 'المبنى',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          prefixIcon: const Icon(Icons.business),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // قسم إدارة الضيوف
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.people, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'إدارة الضيوف',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${_selectedGuests.length} مدعو',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // قائمة الضيوف المختارين
                      if (_selectedGuests.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _selectedGuests.map((guestId) {
                            final guest = _availableFriends.firstWhere(
                              (f) => f['id'] == guestId,
                              orElse: () => {'name': 'غير معروف', 'avatar': '❓'},
                            );
                            return Chip(
                              avatar: Text(guest['avatar']),
                              label: Text(guest['name']),
                              deleteIcon: const Icon(Icons.close, size: 18),
                              onDeleted: () {
                                setState(() {
                                  _selectedGuests.remove(guestId);
                                });
                              },
                            );
                          }).toList(),
                        ),

                      const SizedBox(height: 12),

                      // زر إضافة ضيوف
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _showGuestSelectionDialog,
                          icon: const Icon(Icons.person_add),
                          label: const Text('إضافة ضيوف'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blue.shade700,
                            side: BorderSide(color: Colors.blue.shade300),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // أزرار الإجراءات
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            _saveAppointment();
                          }
                        },
                        icon: const Icon(Icons.save),
                        label: const Text('حفظ الموعد'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2196F3),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _resetForm,
                        icon: const Icon(Icons.refresh),
                        label: const Text('إعادة تعيين'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showGuestSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اختيار الضيوف'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _availableFriends.length,
            itemBuilder: (context, index) {
              final friend = _availableFriends[index];
              final isSelected = _selectedGuests.contains(friend['id']);

              return CheckboxListTile(
                title: Text(friend['name']),
                subtitle: Text('ID: ${friend['id']}'),
                secondary: Text(friend['avatar'], style: const TextStyle(fontSize: 20)),
                value: isSelected,
                onChanged: (bool? value) {
                  setState(() {
                    if (value == true) {
                      _selectedGuests.add(friend['id']);
                    } else {
                      _selectedGuests.remove(friend['id']);
                    }
                  });
                  Navigator.pop(context);
                  _showGuestSelectionDialog(); // إعادة فتح الحوار لإظهار التحديث
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('تم'),
          ),
        ],
      ),
    );
  }

  void _saveAppointment() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم حفظ الموعد مع ${_selectedGuests.length} ضيف'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _resetForm() {
    setState(() {
      _titleController.clear();
      _regionController.clear();
      _buildingController.clear();
      _selectedGuests.clear();
      _isPrivate = false;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _regionController.dispose();
    _buildingController.dispose();
    super.dispose();
  }
}
