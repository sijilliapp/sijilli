import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../utils/date_converter.dart';
import '../utils/arabic_search_utils.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/connectivity_service.dart';
import '../services/timezone_service.dart';
import '../services/sunset_service.dart';
import '../services/user_appointment_status_service.dart';
import '../models/user_model.dart';
import '../models/appointment_model.dart';
import '../config/constants.dart';
import '../widgets/appointment_confirmation_dialog.dart';
import 'home_screen.dart';
import 'notifications_screen.dart';
import 'editable_settings_screen.dart';
import 'user_profile_screen.dart';

class MainScreen extends StatefulWidget {
  final int initialTabIndex;
  final String? clonedTitle;
  final String? clonedRegion;
  final String? clonedBuilding;
  final DateTime? clonedDate;
  final DateTime? clonedTime;

  const MainScreen({
    super.key,
    this.initialTabIndex = 0,
    this.clonedTitle,
    this.clonedRegion,
    this.clonedBuilding,
    this.clonedDate,
    this.clonedTime,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _currentIndex;
  final GlobalKey<_AddAppointmentScreenState> _addAppointmentKey =
      GlobalKey<_AddAppointmentScreenState>();

  // نظام تتبع الإشعارات الجديدة
  bool _hasUnreadNotifications = false;
  bool _isCheckingNotifications = false; // منع الفحص المتكرر
  bool _isInitializing = true; // مؤشر التحميل الأولي
  final AuthService _authService = AuthService();

  // Temporary placeholder screens
  List<Widget> get _screens => [
    const HomeScreen(), // الرئيسية
    const NotificationsScreen(), // الإشعارات
    AddAppointmentScreen(
      key: _addAppointmentKey,
      clonedTitle: widget.clonedTitle,
      clonedRegion: widget.clonedRegion,
      clonedBuilding: widget.clonedBuilding,
      clonedDate: widget.clonedDate,
      clonedTime: widget.clonedTime,
    ), // إضافة
    const SearchScreen(), // البحث
    const EditableSettingsScreen(), // الإعدادات
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex; // ✅ تهيئة _currentIndex
    print('🚀 === MainScreen initState - بداية تحميل الشاشة الرئيسية ===');

    // تحميل البيانات فوراً بعد بناء الواجهة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startDataPreloading();
    });
  }

  // بدء تحميل البيانات المسبق
  void _startDataPreloading() {
    print('🚀 === بدء تحميل البيانات المسبق ===');

    // ✅ تحميل البيانات فوراً بدون تأخير
    if (mounted && _authService.isAuthenticated) {
      _loadAllDataInBackground();
    }

  }

  // تهيئة التطبيق وجلب البيانات
  Future<void> _initializeApp() async {
    print('🚀 === بداية تهيئة التطبيق في MainScreen ===');

    // انتظار قصير للتأكد من تحميل AuthService
    await Future.delayed(const Duration(milliseconds: 500));

    final currentUser = _authService.currentUser;
    if (currentUser != null) {
      print('✅ المستخدم مسجل دخول: ${currentUser.name}');

      // تحميل جميع البيانات بالتوازي لتحسين الأداء
      await Future.wait([
        _loadNotificationsInBackground(),
        _preloadHomeScreenData(),
      ]);

      print('✅ تم تحميل جميع البيانات بنجاح');
    } else {
      print('❌ لا يوجد مستخدم مسجل دخول');
    }

    // إنهاء حالة التحميل
    if (mounted) {
      setState(() {
        _isInitializing = false;
      });
    }

    print('✅ === انتهاء تهيئة التطبيق في MainScreen ===');
  }

  // تحميل جميع البيانات في الخلفية
  Future<void> _loadAllDataInBackground() async {
    try {
      final currentUserId = _authService.currentUser?.id;
      if (currentUserId == null) {
        print('❌ لا يوجد مستخدم مسجل دخول لتحميل البيانات');
        return;
      }

      print('🚀 === بداية تحميل جميع البيانات في الخلفية ===');

      // تحميل الإشعارات والمواعيد بالتوازي
      await Future.wait([
        _loadNotificationsInBackground(),
        _preloadHomeScreenData(),
      ]);

      print('✅ === تم تحميل جميع البيانات بنجاح ===');
    } catch (e) {
      print('❌ خطأ في تحميل البيانات في الخلفية: $e');
    }
  }

  // تحميل بيانات الشاشة الرئيسية مسبقاً
  Future<void> _preloadHomeScreenData() async {
    try {
      final currentUserId = _authService.currentUser?.id;
      if (currentUserId == null) return;

      print('🏠 تحميل بيانات الشاشة الرئيسية مسبقاً...');

      // جلب المواعيد التي أنا مضيفها
      final myHostedAppointments = await _authService.pb
          .collection(AppConstants.appointmentsCollection)
          .getFullList(filter: 'host = "$currentUserId"', sort: '-created');

      // جلب الدعوات المقبولة
      final acceptedInvitations = await _authService.pb
          .collection(AppConstants.invitationsCollection)
          .getFullList(
            filter: 'guest = "$currentUserId" && status = "accepted"',
            expand: 'appointment',
          );

      print(
        '📊 تم تحميل ${myHostedAppointments.length} موعد مضيف و ${acceptedInvitations.length} دعوة مقبولة',
      );

      // حفظ البيانات في التخزين المحلي
      final prefs = await SharedPreferences.getInstance();

      // حفظ المواعيد المضيفة
      final hostedAppointmentsJson = myHostedAppointments
          .map((record) => record.data)
          .toList();
      await prefs.setString(
        'hosted_appointments_$currentUserId',
        json.encode(hostedAppointmentsJson),
      );

      // حفظ الدعوات المقبولة
      final acceptedInvitationsJson = acceptedInvitations
          .map((record) => record.data)
          .toList();
      await prefs.setString(
        'accepted_invitations_$currentUserId',
        json.encode(acceptedInvitationsJson),
      );

      print('💾 تم حفظ بيانات الشاشة الرئيسية في التخزين المحلي');
    } catch (e) {
      print('❌ خطأ في تحميل بيانات الشاشة الرئيسية: $e');
    }
  }

  // جلب الإشعارات في الخلفية
  Future<void> _loadNotificationsInBackground() async {
    try {
      final currentUserId = _authService.currentUser?.id;
      if (currentUserId == null) {
        print('❌ لا يوجد مستخدم مسجل دخول');
        return;
      }

      print('🔔 جلب الإشعارات في الخلفية للمستخدم: $currentUserId');

      // جلب الدعوات من قاعدة البيانات مع تحسين الاستعلام
      final invitationResult = await _authService.pb
          .collection('invitations')
          .getList(
            page: 1,
            perPage: 30, // تقليل العدد لتحسين الأداء
            sort: '-created',
            expand: 'appointment,appointment.host,guest',
            filter:
                'guest = "$currentUserId" || appointment.host = "$currentUserId"',
          );

      print('📊 تم جلب ${invitationResult.items.length} دعوة');

      // تحويل الدعوات إلى إشعارات (نفس الطريقة المستخدمة في notifications_screen.dart)
      List<Map<String, dynamic>> notifications = [];

      for (final record in invitationResult.items) {
        try {
          // إشعار للضيف عن الدعوة
          if (record.data['guest'] == currentUserId) {
            final appointmentExpand = record.expand['appointment'];
            final hostExpand = appointmentExpand?.first.expand['host'];

            if (appointmentExpand != null && appointmentExpand.isNotEmpty &&
                hostExpand != null && hostExpand.isNotEmpty) {
              final appointment = appointmentExpand.first;
              final host = hostExpand.first;

              final hostName = host.data['name'] ?? 'مستخدم';
              final appointmentTitle = appointment.data['title'] ?? 'موعد';

              // ✅ فقط الدعوات التي لم يتم الرد عليها (invited) تكون غير مقروءة
              if (record.data['status'] == 'invited') {
                notifications.add({
                  'id': record.id,
                  'title': 'دعوة جديدة',
                  'message': 'دعاك $hostName لموعد $appointmentTitle',
                  'type': 'NotificationType.invitation',
                  'isRead': false, // غير مقروء - يحتاج رد
                  'createdAt': record.data['created'],
                  'senderId': host.id,
                  'senderName': hostName,
                  'senderAvatar': host.data['avatar'] ?? '',
                  'invitationData': record.data,
                });
              }
              // الحالات الأخرى (accepted, rejected, deleted_after_accept) لا تُنشئ إشعارات للضيف
            }
          }

          // إشعار للمضيف عن استجابة الضيف
          final appointmentExpand = record.expand['appointment'];
          if (appointmentExpand != null && appointmentExpand.isNotEmpty) {
            final appointment = appointmentExpand.first;
            if (appointment.data['host'] == currentUserId &&
                (record.data['status'] == 'accepted' ||
                    record.data['status'] == 'rejected')) {
              final guestExpand = record.expand['guest'];
              if (guestExpand != null && guestExpand.isNotEmpty) {
                final guest = guestExpand.first;
                final guestName = guest.data['name'] ?? 'ضيف';
                final appointmentTitle = appointment.data['title'] ?? 'موعد';

                final title = record.data['status'] == 'accepted'
                    ? 'تم قبول الدعوة'
                    : 'تم رفض الدعوة';
                final message = record.data['status'] == 'accepted'
                    ? 'وافق $guestName على دعوتك لموعد $appointmentTitle'
                    : 'رفض $guestName دعوتك لموعد $appointmentTitle';

                notifications.add({
                  'id': '${record.id}_response',
                  'title': title,
                  'message': message,
                  'type': 'NotificationType.response',
                  'isRead': false, // جميع الإشعارات الجديدة غير مقروءة
                  'createdAt': record.data['updated'],
                  'senderId': guest.id,
                  'senderName': guestName,
                  'senderAvatar': guest.data['avatar'] ?? '',
                  'invitationData': record.data,
                });
              }
            }
          }
        } catch (e) {
          // تجاهل الأخطاء في معالجة دعوة واحدة
          print('⚠️ خطأ في معالجة دعوة: $e');
          continue;
        }
      }

      print('✅ تم إنشاء ${notifications.length} إشعار');

      // 🔍 DEBUG: طباعة تفاصيل الإشعارات قبل الحفظ
      for (var i = 0; i < notifications.length && i < 5; i++) {
        print('   📋 إشعار $i: ${notifications[i]['title']} - isRead: ${notifications[i]['isRead']}');
      }

      // حفظ الإشعارات في SharedPreferences
      if (notifications.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final cacheKey = 'notifications_$currentUserId';
        await prefs.setString(cacheKey, json.encode(notifications));
        print('💾 تم حفظ ${notifications.length} إشعار في التخزين المحلي');
        
        // ✅ تحديث النقطة الحمراء بعد حفظ الإشعارات
        _checkUnreadNotifications();
      } else {
        print('⚠️ لا توجد إشعارات لحفظها - النقطة الحمراء يجب أن تكون مخفية');
      }
    } catch (e) {
      print('❌ خطأ في جلب الإشعارات في الخلفية: $e');
    }
  }

  // فحص الإشعارات غير المقروءة
  Future<void> _checkUnreadNotifications() async {
    // منع الفحص المتكرر
    if (_isCheckingNotifications) return;
    _isCheckingNotifications = true;

    try {
      final currentUserId = _authService.currentUser?.id;
      if (currentUserId == null) {
        print('❌ لا يوجد مستخدم مسجل دخول لفحص الإشعارات');
        return;
      }

      print('🔍 فحص الإشعارات غير المقروءة للمستخدم: $currentUserId');

      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'notifications_$currentUserId';
      final cachedData = prefs.getString(cacheKey);

      if (cachedData != null) {
        final List<dynamic> jsonList = json.decode(cachedData);
        
        // 🔍 DEBUG: طباعة تفاصيل الإشعارات
        print('📊 عدد الإشعارات: ${jsonList.length}');
        for (var i = 0; i < jsonList.length && i < 3; i++) {
          print('   إشعار $i: isRead = ${jsonList[i]['isRead']}');
        }
        
        final hasUnread = jsonList.any((json) => json['isRead'] == false);
        print('🔴 يوجد إشعارات غير مقروءة: $hasUnread');
        print('🔴 الحالة الحالية: $_hasUnreadNotifications');

        if (mounted && _hasUnreadNotifications != hasUnread) {
          setState(() {
            _hasUnreadNotifications = hasUnread;
          });
          print('✅ تم تحديث حالة النقطة الحمراء: $_hasUnreadNotifications');
        }
      } else {
        print('❌ لا توجد إشعارات محفوظة في التخزين المحلي');
        // إذا لا توجد إشعارات، النقطة الحمراء يجب أن تكون false
        if (mounted && _hasUnreadNotifications) {
          setState(() {
            _hasUnreadNotifications = false;
          });
        }
      }
    } catch (e) {
      print('❌ خطأ في فحص الإشعارات غير المقروءة: $e');
    } finally {
      _isCheckingNotifications = false;
    }
  }

  // تحديث حالة الإشعارات عند الانتقال لصفحة الإشعارات
  void _onNotificationsTabSelected() {
    if (_hasUnreadNotifications) {
      setState(() {
        _hasUnreadNotifications = false;
      });
      _markAllNotificationsAsRead();
    }
  }

  // تحديد جميع الإشعارات كمقروءة
  Future<void> _markAllNotificationsAsRead() async {
    try {
      final currentUserId = _authService.currentUser?.id;
      if (currentUserId == null) return;

      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'notifications_$currentUserId';
      final cachedData = prefs.getString(cacheKey);

      if (cachedData != null) {
        final List<dynamic> jsonList = json.decode(cachedData);

        // تحديث جميع الإشعارات لتصبح مقروءة
        for (var json in jsonList) {
          json['isRead'] = true;
        }

        // حفظ التحديث
        await prefs.setString(cacheKey, json.encode(jsonList));
      }
    } catch (e) {
      print('❌ خطأ في تحديد الإشعارات كمقروءة: $e');
    }
  }

  // دالة عامة لتحديث حالة الإشعارات (تستدعى من الخارج)
  void updateNotificationsBadge() {
    _checkUnreadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        body: _screens[_currentIndex],
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(
                    icon: Icons.home_rounded,
                    label: 'الرئيسية',
                    index: 0,
                  ),
                  _buildNavItem(
                    icon: Icons.notifications_rounded,
                    label: 'الإشعارات',
                    index: 1,
                  ),
                  _buildNavItem(
                    icon: Icons.add_circle_rounded,
                    label: 'إضافة',
                    index: 2,
                    isCenter: true,
                  ),
                  _buildNavItem(
                    icon: Icons.search_rounded,
                    label: 'البحث',
                    index: 3,
                  ),
                  _buildNavItem(
                    icon: Icons.settings_rounded,
                    label: 'الإعدادات',
                    index: 4,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    bool isCenter = false,
  }) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? const Color(0xFF2196F3) : Colors.grey.shade600;

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            // إذا كان المستخدم ينتقل من الإعدادات إلى صفحة الإضافة، قم بتحديث التواريخ
            if (_currentIndex == 4 && index == 2) {
              // تحديث التواريخ في صفحة الإضافة عند العودة من الإعدادات
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _addAppointmentKey.currentState?._refreshDatesFromSettings();
              });
            }

            // إذا انتقل المستخدم لصفحة الإشعارات، قم بإزالة النقطة الحمراء
            if (index == 1) {
              _onNotificationsTabSelected();
            }

            _currentIndex = index;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // إضافة النقطة الحمراء للإشعارات
              index == 1 && _hasUnreadNotifications
                  ? Stack(
                      children: [
                        Icon(icon, color: color, size: isCenter ? 32 : 26),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Icon(icon, color: color, size: isCenter ? 32 : 26),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Placeholder Screens
class AddAppointmentScreen extends StatefulWidget {
  final String? clonedTitle;
  final String? clonedRegion;
  final String? clonedBuilding;
  final DateTime? clonedDate;
  final DateTime? clonedTime;

  const AddAppointmentScreen({
    super.key,
    this.clonedTitle,
    this.clonedRegion,
    this.clonedBuilding,
    this.clonedDate,
    this.clonedTime,
  });

  @override
  State<AddAppointmentScreen> createState() => _AddAppointmentScreenState();
}

class _AddAppointmentScreenState extends State<AddAppointmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _regionController = TextEditingController();
  final _buildingController = TextEditingController();
  final _searchController = TextEditingController();
  final _notesController = TextEditingController();
  final AuthService _authService = AuthService();
  final DatabaseService _dbService = DatabaseService();
  final ConnectivityService _connectivityService = ConnectivityService();

  bool _isPrivate = false;
  bool _isSaving = false;
  String _dateType = 'ميلادي';
  String _selectedMonth = 'يناير';
  int _selectedDay = DateTime.now().day;
  int _selectedYear = DateTime.now().year;
  String _selectedWeekday = 'السبت';
  int _selectedHour = 6; // الوقت الافتراضي 6:00 مساءً
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

  // Guest management
  List<String> _selectedGuests = [];
  String _searchQuery = '';

  // Real friends data from follows/followers
  List<UserModel> _availableFriends = [];
  List<UserModel> _filteredFriends = [];
  bool _isLoadingFriends = false;

  // Conflict checking data
  Map<String, List<AppointmentModel>> _friendAppointments = {};
  Map<String, List<Map<String, dynamic>>> _friendInvitations = {};
  List<AppointmentModel> _allAppointments = [];

  bool _hasInitialized = false; // Flag لمنع إعادة التهيئة

  @override
  void initState() {
    super.initState();

    // فقط إذا لم يكن هناك بيانات مستنسخة، نهيئ التواريخ
    if (widget.clonedDate == null && widget.clonedTime == null) {
      _initializeDates();
    }

    _loadFriends();

    // ✅ تطبيق البيانات المستنسخة
    if (widget.clonedTitle != null) {
      _titleController.text = widget.clonedTitle!;
      print('✅ استنساخ عنوان: ${widget.clonedTitle}');
    }
    if (widget.clonedRegion != null) {
      _regionController.text = widget.clonedRegion!;
      print('✅ استنساخ منطقة: ${widget.clonedRegion}');
    }
    if (widget.clonedBuilding != null) {
      _buildingController.text = widget.clonedBuilding!;
      print('✅ استنساخ مبنى: ${widget.clonedBuilding}');
    }
    if (widget.clonedTime != null) {
      final clonedTime = widget.clonedTime!;
      _selectedHour = clonedTime.hour > 12
          ? clonedTime.hour - 12
          : clonedTime.hour;
      if (_selectedHour == 0) _selectedHour = 12;
      _selectedMinute = clonedTime.minute;
      _selectedPeriod = clonedTime.hour >= 12 ? 'مساءً' : 'صباحاً';
      print('✅ استنساخ وقت: $_selectedHour:$_selectedMinute $_selectedPeriod');
    }

    // ✅ استنساخ التاريخ الميلادي (اليوم والشهر فقط، مع السنة الحالية)
    // دائماً نستنسخ كتاريخ ميلادي، والمستخدم يمكنه تغييره يدوياً للهجري
    if (widget.clonedDate != null) {
      final clonedDate = widget.clonedDate!;
      final currentYear = DateTime.now().year;
      final userAdjustment = _authService.currentUser?.hijriAdjustment ?? 0;

      // إنشاء تاريخ ميلادي جديد مع السنة الحالية
      _selectedGregorianDate = DateTime(
        currentYear,
        clonedDate.month,
        clonedDate.day,
      );

      // تحديث التاريخ الهجري المقابل
      _selectedHijriDate = DateConverter.toHijri(
        _selectedGregorianDate,
        adjustment: userAdjustment,
      );

      // ضبط المتغيرات للتاريخ الميلادي
      _selectedDay = clonedDate.day;
      _selectedMonth = _getMonthName(clonedDate.month);
      _selectedYear = currentYear;
      _selectedWeekday = _getWeekdayName(_selectedGregorianDate.weekday);

      print(
        '✅ استنساخ تاريخ ميلادي: $_selectedDay $_selectedMonth $currentYear',
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-initialize dates only if not already initialized (to preserve cloned data)
    if (!_hasInitialized) {
      // فقط إذا لم يكن هناك بيانات مستنسخة، نهيئ التواريخ
      if (widget.clonedDate == null && widget.clonedTime == null) {
        _initializeDates();
      }
      _hasInitialized = true;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _regionController.dispose();
    _buildingController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Initialize dates with current user adjustment via DateConverter
  void _initializeDates() {
    final today = DateTime.now();
    _selectedGregorianDate = today;

    // Apply user's Hijri adjustment using centralized DateConverter
    final userAdjustment = _authService.currentUser?.hijriAdjustment ?? 0;
    _selectedHijriDate = DateConverter.toHijri(
      today,
      adjustment: userAdjustment,
    );

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

  // Method to refresh dates when returning from settings
  void _refreshDatesFromSettings() {
    setState(() {
      _initializeDates();
    });
  }

  // تحميل الأصدقاء (المتابعات + المتبوعين) - Offline First
  Future<void> _loadFriends() async {
    if (!mounted) return;

    try {
      // 1. Load from Cache FIRST (instant) ⚡
      await _loadFriendsFromCache();

      // 2. Check internet connection
      final isOnline = await _connectivityService.hasConnection();

      // 3. If online, update from PocketHost in background
      if (isOnline && _authService.isAuthenticated) {
        try {
          final currentUserId = _authService.currentUser?.id;
          if (currentUserId == null) return;

          // جلب الأصدقاء (علاقة متبادلة مقبولة من جدول friendship)
          final friendshipRecords = await _authService.pb
              .collection(AppConstants.friendshipCollection)
              .getFullList(
                filter:
                    '(follower = "$currentUserId" || following = "$currentUserId") && status = "approved"',
              );

          print('📊 عدد سجلات الأصدقاء: ${friendshipRecords.length}');

          // جمع معرفات الأصدقاء (الطرف الآخر من العلاقة)
          Set<String> friendIds = {};

          for (var record in friendshipRecords) {
            final followerId = record.data['follower'] as String;
            final followingId = record.data['following'] as String;
            // إضافة الطرف الآخر من العلاقة
            final friendId = followerId == currentUserId
                ? followingId
                : followerId;
            friendIds.add(friendId);
          }

          // جلب بيانات المستخدمين
          if (friendIds.isNotEmpty) {
            final friendsFilter = friendIds
                .map((id) => 'id = "$id"')
                .join(' || ');
            final usersRecords = await _authService.pb
                .collection(AppConstants.usersCollection)
                .getFullList(filter: '($friendsFilter)', sort: 'name');

            print('📊 عدد الأصدقاء المسترجعين: ${usersRecords.length}');

            final friends = usersRecords
                .map((record) => UserModel.fromJson(record.toJson()))
                .toList();

            // Save to Cache for next time ⚡
            await _saveFriendsToCache(friends);

            // Update UI with fresh data
            if (!mounted) return;
            setState(() {
              _availableFriends = friends;
              _filteredFriends = friends;
              _isLoadingFriends = false;
            });

            // جلب مواعيد الأصدقاء لفحص التعارض
            await _loadFriendsAppointments(friends);

            // جلب مواعيدي أيضاً لفحص التعارض مع نفسي
            await _loadMyAppointments();
          } else {
            // Save empty list to cache
            await _saveFriendsToCache([]);

            if (!mounted) return;
            setState(() {
              _availableFriends = [];
              _filteredFriends = [];
              _isLoadingFriends = false;
            });
          }
        } catch (e) {
          print('خطأ في تحميل الأصدقاء من الخادم: $e');
          // Keep showing cached data (already loaded)
          if (mounted) {
            setState(() => _isLoadingFriends = false);
          }
        }
      } else {
        // Offline - just show cached data (already loaded in step 1)
        if (mounted) {
          setState(() => _isLoadingFriends = false);
        }
      }
    } catch (e) {
      print('خطأ عام في تحميل الأصدقاء: $e');
      if (mounted) {
        setState(() {
          _availableFriends = [];
          _filteredFriends = [];
          _isLoadingFriends = false;
        });
      }
    }
  }

  // دوال Cache للأصدقاء
  Future<void> _loadFriendsFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = _authService.currentUser?.id;
      if (userId == null) return;

      final cachedData = prefs.getString('friends_$userId');
      if (cachedData != null) {
        final List<dynamic> jsonList = jsonDecode(cachedData);
        final friends = jsonList
            .map((json) => UserModel.fromJson(json))
            .toList();
        if (mounted) {
          setState(() {
            _availableFriends = friends;
            _filteredFriends = friends;
            _isLoadingFriends = false;
          });
        }
      }
    } catch (e) {
      // Ignore cache errors
      print('خطأ في تحميل الأصدقاء من الذاكرة: $e');
    }
  }

  Future<void> _saveFriendsToCache(List<UserModel> friends) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = _authService.currentUser?.id;
      if (userId == null) return;

      final jsonList = friends.map((friend) => friend.toJson()).toList();
      await prefs.setString('friends_$userId', jsonEncode(jsonList));
    } catch (e) {
      // Ignore cache errors
      print('خطأ في حفظ الأصدقاء في الذاكرة: $e');
    }
  }

  // فلترة الأصدقاء بناءً على البحث
  void _filterFriends(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredFriends = _availableFriends;
      } else {
        _filteredFriends = _availableFriends.where((friend) {
          return ArabicSearchUtils.searchInUserFields(
            friend.name,
            friend.username,
            friend.bio ?? '',
            query,
          );
        }).toList();
      }
    });
  }

  // الحصول على رابط الصورة الشخصية
  String _getUserAvatarUrl(UserModel user) {
    if (user.avatar == null || user.avatar!.isEmpty) {
      return '';
    }

    final cleanAvatar = user.avatar!
        .replaceAll('[', '')
        .replaceAll(']', '')
        .replaceAll('"', '');
    return '${AppConstants.pocketbaseUrl}/api/files/${AppConstants.usersCollection}/${user.id}/$cleanAvatar';
  }

  // تحديد لون الطوق للأصدقاء في صندوق الإضافة
  Color _getFriendRingColor(UserModel friend) {
    // فحص تعارض المواعيد أولاً
    if (_hasAppointmentConflict(friend)) {
      return Colors.red; // أحمر للتعارض في المواعيد
    }

    // الافتراضي: رمادي
    return Colors.grey.shade400;
  }

  // فحص تعارض المواعيد مع الصديق
  bool _hasAppointmentConflict(UserModel friend) {
    try {
      // بناء تاريخ ووقت الموعد الحالي
      final currentAppointmentStart = _buildAppointmentDateTime();

      // حساب مدة الموعد بالدقائق
      int durationMinutes = _getDurationInMinutes() ?? 45;

      final currentAppointmentEnd = currentAppointmentStart.add(
        Duration(minutes: durationMinutes),
      );

      // فحص التعارض مع مواعيد الصديق
      return _checkFriendAppointmentConflict(
        friend.id,
        currentAppointmentStart,
        currentAppointmentEnd,
      );
    } catch (e) {
      // في حالة خطأ، لا نعتبر أن هناك تعارض
      return false;
    }
  }

  // فحص التعارض مع مواعيد صديق معين
  bool _checkFriendAppointmentConflict(
    String friendId,
    DateTime start,
    DateTime end,
  ) {
    // فحص مواعيد الصديق كمضيف
    for (final appointment in _friendAppointments[friendId] ?? []) {
      final appointmentStart = appointment.appointmentDate;
      // افتراض مدة 45 دقيقة للمواعيد الموجودة (يمكن تحسينها لاحقاً)
      final appointmentEnd = appointmentStart.add(const Duration(minutes: 45));

      // فحص التداخل الزمني
      if (start.isBefore(appointmentEnd) && end.isAfter(appointmentStart)) {
        return true; // يوجد تعارض
      }
    }

    // فحص دعوات الصديق للمواعيد الأخرى
    for (final invitation in _friendInvitations[friendId] ?? []) {
      // البحث عن الموعد المرتبط بالدعوة
      try {
        final appointment = _allAppointments.firstWhere(
          (apt) => apt.id == invitation['appointment'],
        );

        final appointmentStart = appointment.appointmentDate;
        final appointmentEnd = appointmentStart.add(
          const Duration(minutes: 45),
        );

        if (start.isBefore(appointmentEnd) && end.isAfter(appointmentStart)) {
          return true; // يوجد تعارض
        }
      } catch (e) {
        // الموعد غير موجود، تجاهل
        continue;
      }
    }

    return false; // لا يوجد تعارض
  }

  // جلب مواعيد الأصدقاء لفحص التعارض
  Future<void> _loadFriendsAppointments(List<UserModel> friends) async {
    try {
      // مسح البيانات السابقة
      _friendAppointments.clear();
      _friendInvitations.clear();
      _allAppointments.clear();

      final appointmentRecords = await _authService.pb
          .collection(AppConstants.appointmentsCollection)
          .getFullList(sort: 'appointment_date');

      _allAppointments = appointmentRecords
          .map((record) => AppointmentModel.fromJson(record.toJson()))
          .toList();

      // تصنيف المواعيد حسب المضيف
      for (final friend in friends) {
        final friendAppointments = _allAppointments
            .where((apt) => apt.hostId == friend.id)
            .toList();
        _friendAppointments[friend.id] = friendAppointments;
      }

      // جلب دعوات الأصدقاء
      for (final friend in friends) {
        try {
          final invitationRecords = await _authService.pb
              .collection(AppConstants.invitationsCollection)
              .getFullList(
                filter: 'guest = "${friend.id}" && status = "accepted"',
              );

          _friendInvitations[friend.id] = invitationRecords
              .map((record) => record.toJson())
              .toList();
        } catch (e) {
          // في حالة خطأ، استخدم قائمة فارغة
          _friendInvitations[friend.id] = [];
        }
      }

      // تحديث الواجهة لإعادة حساب الألوان
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      // في حالة خطأ، استخدم بيانات فارغة
      _friendAppointments.clear();
      _friendInvitations.clear();
      _allAppointments.clear();
    }
  }

  // فحص تعارض مواعيدي - دالة بسيطة
  bool _hasMyTimeConflict() {
    try {
      // إذا كان الموعد "عدة أيام" فلا يوجد وقت محدد للفحص
      if (_selectedDuration == 'عدة أيام') return false;

      final myId = _authService.currentUser?.id;
      if (myId == null) return false;

      final start = _buildAppointmentDateTime();
      final durationMinutes = _getDurationInMinutes() ?? 45;
      final end = start.add(Duration(minutes: durationMinutes));

      return _checkFriendAppointmentConflict(myId, start, end);
    } catch (e) {
      return false;
    }
  }

  // جلب مواعيدي لفحص التعارض
  Future<void> _loadMyAppointments() async {
    try {
      final myId = _authService.currentUser?.id;
      if (myId == null) return;

      final myAppointments = await _authService.pb
          .collection(AppConstants.appointmentsCollection)
          .getFullList(filter: 'host = "$myId"', sort: 'appointment_date');

      // إضافة مواعيدي إلى قائمة مواعيد الأصدقاء
      _friendAppointments[myId] = myAppointments
          .map((record) => AppointmentModel.fromJson(record.toJson()))
          .toList();

      // جلب دعواتي المقبولة
      final myInvitations = await _authService.pb
          .collection(AppConstants.invitationsCollection)
          .getFullList(filter: 'guest = "$myId" && status = "accepted"');

      _friendInvitations[myId] = myInvitations
          .map((record) => record.toJson())
          .toList();

      if (mounted) setState(() {});
    } catch (e) {
      // في حالة خطأ، تجاهل
    }
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
      final hijriDate = DateConverter.toHijri(
        gregorianDate,
        adjustment: userAdjustment,
      );

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
      final gregorianDate = DateConverter.toGregorian(
        hijriDate,
        adjustment: userAdjustment,
      );

      setState(() {
        _selectedHijriDate = hijriDate;
        _selectedGregorianDate = gregorianDate;
        _selectedWeekday = _getWeekdayName(gregorianDate.weekday);
      });
    } catch (e) {
      // Handle invalid date
    }
  }

  // Helper method to update date to match selected weekday
  void _updateDateToMatchWeekday(String weekdayName) {
    final targetWeekday = _getWeekdayNumber(weekdayName);
    final currentWeekday = _selectedGregorianDate.weekday;
    final daysDifference = targetWeekday - currentWeekday;

    final newDate = _selectedGregorianDate.add(Duration(days: daysDifference));

    setState(() {
      _selectedGregorianDate = newDate;
      // Apply user adjustment via DateConverter
      final userAdjustment = _authService.currentUser?.hijriAdjustment ?? 0;
      _selectedHijriDate = DateConverter.toHijri(
        newDate,
        adjustment: userAdjustment,
      );

      _selectedDay = newDate.day;
      _selectedMonth = _getMonthName(newDate.month);
      _selectedYear = newDate.year;
    });
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
    '5 دقائق',
    '10 دقائق',
    '15 دقيقة',
    '30 دقيقة',
    '45 دقيقة',
    '60 دقيقة',
    '90 دقيقة',
    '120 دقيقة',
    'عدة أيام',
  ];

  // تنسيق مدة الموعد
  String _formatDuration(int? minutes) {
    if (minutes == null) return '45 دقيقة'; // القيمة الافتراضية

    if (minutes < 60) {
      return '$minutes دقيقة';
    } else if (minutes == 60) {
      return 'ساعة';
    } else if (minutes == 120) {
      return 'ساعتين';
    } else if (minutes >= 1440) {
      // يوم كامل أو أكثر - عدة أيام
      final days = (minutes / 1440).ceil();
      return 'عدة أيام ($days)';
    } else {
      // ساعات ودقائق
      final hours = (minutes / 60).floor();
      final remainingMinutes = minutes % 60;
      if (remainingMinutes == 0) {
        return '$hours ساعات';
      }
      return '$hours ساعة و $remainingMinutes دقيقة';
    }
  }

  // تحويل المدة المختارة إلى رقم (دقائق)
  int? _getDurationInMinutes() {
    if (_selectedDuration == 'عدة أيام') {
      return 2880; // يومان كقيمة افتراضية
    }

    // استخراج الرقم من النص
    final match = RegExp(r'\d+').firstMatch(_selectedDuration);
    if (match != null) {
      return int.parse(match.group(0)!);
    }

    return 45; // قيمة افتراضية
  }

  // دالة حفظ الموعد
  Future<void> _saveAppointment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_authService.isAuthenticated) {
      _showErrorMessage('يجب تسجيل الدخول أولاً');
      return;
    }

    // تحويل التاريخ والوقت إلى DateTime المحلي
    final localAppointmentDateTime = _buildAppointmentDateTime();

    // الحصول على أسماء الضيوف إن وجدوا
    List<String>? guestNames;
    if (_selectedGuests.isNotEmpty) {
      try {
        guestNames = [];
        for (final guestId in _selectedGuests) {
          final guestRecord = await _authService.pb
              .collection(AppConstants.usersCollection)
              .getOne(guestId);
          final name = guestRecord.data['name'] as String?;
          if (name != null) {
            guestNames.add(name);
          }
        }
      } catch (e) {
        // في حالة الخطأ، نتجاهل ونكمل بدون أسماء الضيوف
        guestNames = null;
      }
    }

    // تجهيز معلومات المكان
    final region = _regionController.text.trim();
    final building = _buildingController.text.trim();
    String? location;
    if (region.isNotEmpty && building.isNotEmpty) {
      location = '$region، $building';
    } else if (region.isNotEmpty) {
      location = region;
    } else if (building.isNotEmpty) {
      location = building;
    }

    // تجهيز قائمة الضيوف الكاملة
    final selectedGuestModels = _selectedGuests
        .map(
          (guestId) => _availableFriends.firstWhere(
            (f) => f.id == guestId,
            orElse: () => UserModel(
              id: guestId,
              email: '',
              username: '',
              name:
                  guestNames?.firstWhere(
                    (name) => name.isNotEmpty,
                    orElse: () => 'ضيف',
                  ) ??
                  'ضيف',
              verified: false,
            ),
          ),
        )
        .toList();

    // إظهار مربع حوار التأكيد
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AppointmentConfirmationDialog(
        title: _titleController.text.trim(),
        guestNames: guestNames,
        guests: selectedGuestModels,
        appointmentDateTime: localAppointmentDateTime,
        location: location,
        dateType: _dateType, // تمرير نوع التاريخ المختار
        onConfirm: () async {
          // تنفيذ الحفظ الفعلي
          await _performSaveAppointment(localAppointmentDateTime);
        },
        onReview: () {
          // المستخدم اختار مراجعة الطلب - لا نفعل شيء
        },
      ),
    );

    // إذا تم التأكيد، نعيد التوجيه للصفحة الرئيسية
    if (confirmed == true) {
      _navigateToHome();
    }
  }

  // دالة تنفيذ الحفظ الفعلي
  Future<void> _performSaveAppointment(
    DateTime localAppointmentDateTime,
  ) async {
    try {
      // تحويل الوقت المحلي إلى UTC للحفظ في قاعدة البيانات
      final utcAppointmentDateTime = TimezoneService.toUtc(
        localAppointmentDateTime,
      );

      // إنشاء بيانات الموعد
      final appointmentData = {
        'title': _titleController.text.trim(),
        'region': _regionController.text.trim().isEmpty
            ? null
            : _regionController.text.trim(),
        'building': _buildingController.text.trim().isEmpty
            ? null
            : _buildingController.text.trim(),
        'privacy': _isPrivate ? 'private' : 'public',
        'status': 'active',
        'appointment_date': utcAppointmentDateTime
            .toIso8601String(), // حفظ بتوقيت UTC
        'date_type': _dateType == 'هجري'
            ? 'hijri'
            : 'gregorian', // نوع التاريخ الأساسي
        // حفظ التاريخ الهجري دائماً (سواء اختار المستخدم هجري أو ميلادي)
        'hijri_day': _dateType == 'هجري'
            ? _selectedHijriDate.hDay
            : DateConverter.toHijri(
                localAppointmentDateTime,
                adjustment: _authService.currentUser?.hijriAdjustment ?? 0,
              ).hDay,
        'hijri_month': _dateType == 'هجري'
            ? _selectedHijriDate.hMonth
            : DateConverter.toHijri(
                localAppointmentDateTime,
                adjustment: _authService.currentUser?.hijriAdjustment ?? 0,
              ).hMonth,
        'hijri_year': _dateType == 'هجري'
            ? _selectedHijriDate.hYear
            : DateConverter.toHijri(
                localAppointmentDateTime,
                adjustment: _authService.currentUser?.hijriAdjustment ?? 0,
              ).hYear,
        'host': _authService.currentUser!.id,
        'duration': _getDurationInMinutes(), // حفظ مدة الموعد
        'stream_link': null,
        'note_shared': _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      };

      // فحص الاتصال بالإنترنت
      final isOnline = await _connectivityService.hasConnection();

      if (isOnline) {
        // حفظ الموعد في PocketBase (أونلاين)
        final record = await _authService.pb
            .collection(AppConstants.appointmentsCollection)
            .create(body: appointmentData);

        // إنشاء سجلات user_appointment_status للمنشئ والضيوف
        await _createUserAppointmentStatusRecords(
          record.id,
          _selectedGuests,
          _isPrivate ? 'private' : 'public',
          // ✅ تمرير بيانات الموعد الأساسية
          _titleController.text.trim(),
          _regionController.text.trim().isEmpty
              ? null
              : _regionController.text.trim(),
          _buildingController.text.trim().isEmpty
              ? null
              : _buildingController.text.trim(),
          utcAppointmentDateTime,
        );

        // إضافة الضيوف إذا كانوا موجودين
        if (_selectedGuests.isNotEmpty) {
          await _saveGuestInvitations(record.id);
        }
      } else {
        // حفظ الموعد محلياً (أوفلاين)
        await _saveAppointmentOffline(appointmentData);
      }

      // إعادة تعيين النموذج
      _resetForm();
    } catch (e) {
      // في حالة الخطأ، نرمي الاستثناء ليتم التعامل معه في الحوار
      rethrow;
    }
  }

  // حفظ الموعد محلياً عند عدم وجود اتصال
  Future<void> _saveAppointmentOffline(
    Map<String, dynamic> appointmentData,
  ) async {
    try {
      // إضافة معرف مؤقت للموعد
      final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
      appointmentData['id'] = tempId;
      appointmentData['temp_id'] = tempId;
      appointmentData['sync_status'] = 'pending'; // في انتظار المزامنة
      appointmentData['created_offline'] = true;

      // حفظ في SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final offlineAppointments =
          prefs.getStringList('offline_appointments') ?? [];
      offlineAppointments.add(jsonEncode(appointmentData));
      await prefs.setStringList('offline_appointments', offlineAppointments);

      // حفظ الضيوف المحددين أيضاً
      if (_selectedGuests.isNotEmpty) {
        final guestData = {
          'appointment_temp_id': tempId,
          'guests': _selectedGuests,
          'sync_status': 'pending',
        };

        final offlineInvitations =
            prefs.getStringList('offline_invitations') ?? [];
        offlineInvitations.add(jsonEncode(guestData));
        await prefs.setStringList('offline_invitations', offlineInvitations);
      }
    } catch (e) {
      print('خطأ في حفظ الموعد محلياً: $e');
      rethrow;
    }
  }

  // دالة حفظ الموعد مع البقاء في الصفحة (للضغط المطول)
  Future<void> _saveAppointmentAndStay() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_authService.isAuthenticated) {
      _showErrorMessage('يجب تسجيل الدخول أولاً');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // تحويل التاريخ والوقت إلى DateTime المحلي
      final localAppointmentDateTime = _buildAppointmentDateTime();

      // تحويل الوقت المحلي إلى UTC للحفظ في قاعدة البيانات
      final utcAppointmentDateTime = TimezoneService.toUtc(
        localAppointmentDateTime,
      );

      // إنشاء بيانات الموعد
      final appointmentData = {
        'title': _titleController.text.trim(),
        'region': _regionController.text.trim().isEmpty
            ? null
            : _regionController.text.trim(),
        'building': _buildingController.text.trim().isEmpty
            ? null
            : _buildingController.text.trim(),
        'privacy': _isPrivate ? 'private' : 'public',
        'status': 'active',
        'appointment_date': utcAppointmentDateTime
            .toIso8601String(), // حفظ بتوقيت UTC
        'date_type': _dateType == 'هجري'
            ? 'hijri'
            : 'gregorian', // نوع التاريخ الأساسي
        // حفظ التاريخ الهجري دائماً (سواء اختار المستخدم هجري أو ميلادي)
        'hijri_day': _dateType == 'هجري'
            ? _selectedHijriDate.hDay
            : DateConverter.toHijri(
                localAppointmentDateTime,
                adjustment: _authService.currentUser?.hijriAdjustment ?? 0,
              ).hDay,
        'hijri_month': _dateType == 'هجري'
            ? _selectedHijriDate.hMonth
            : DateConverter.toHijri(
                localAppointmentDateTime,
                adjustment: _authService.currentUser?.hijriAdjustment ?? 0,
              ).hMonth,
        'hijri_year': _dateType == 'هجري'
            ? _selectedHijriDate.hYear
            : DateConverter.toHijri(
                localAppointmentDateTime,
                adjustment: _authService.currentUser?.hijriAdjustment ?? 0,
              ).hYear,
        'host': _authService.currentUser!.id,
        'duration': _getDurationInMinutes(), // حفظ مدة الموعد
        'stream_link': null,
        'note_shared': _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      };

      // فحص الاتصال بالإنترنت
      final isOnline = await _connectivityService.hasConnection();

      if (isOnline) {
        // حفظ الموعد في PocketBase (أونلاين)
        final record = await _authService.pb
            .collection(AppConstants.appointmentsCollection)
            .create(body: appointmentData);

        // إنشاء سجلات user_appointment_status للمنشئ والضيوف
        await _createUserAppointmentStatusRecords(
          record.id,
          _selectedGuests,
          _isPrivate ? 'private' : 'public',
          // ✅ تمرير بيانات الموعد الأساسية
          _titleController.text.trim(),
          _regionController.text.trim().isEmpty
              ? null
              : _regionController.text.trim(),
          _buildingController.text.trim().isEmpty
              ? null
              : _buildingController.text.trim(),
          utcAppointmentDateTime,
        );

        // إضافة الضيوف إذا كانوا موجودين
        if (_selectedGuests.isNotEmpty) {
          await _saveGuestInvitations(record.id);
        }

        // إظهار رسالة نجاح
        _showSuccessMessage('تم حفظ الموعد بنجاح - يمكنك إضافة موعد آخر');
      } else {
        // حفظ الموعد محلياً (أوفلاين)
        await _saveAppointmentOffline(appointmentData);

        // إظهار رسالة نجاح مع تنبيه الأوفلاين
        _showSuccessMessage(
          'تم حفظ الموعد محلياً - سيتم رفعه عند الاتصال بالإنترنت',
        );
      }

      // إعادة تعيين النموذج فقط (البقاء في الصفحة)
      _resetForm();
    } catch (e) {
      _showErrorMessage('حدث خطأ أثناء حفظ الموعد: ${e.toString()}');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  // الانتقال للصفحة الرئيسية
  void _navigateToHome() {
    // العثور على MainScreen والانتقال للصفحة الرئيسية
    final mainScreenState = context.findAncestorStateOfType<_MainScreenState>();
    if (mainScreenState != null) {
      mainScreenState.setState(() {
        mainScreenState._currentIndex = 0; // الصفحة الرئيسية
      });
    }
  }

  // تحديث الصفحة الرئيسية
  void _refreshHomeScreen() {
    // سيتم تحديث الصفحة الرئيسية تلقائياً عند الانتقال إليها
    // لأن HomeScreen تستخدم initState و didChangeDependencies
  }

  // الحصول على وقت الغروب للتاريخ المحدد (للعرض فقط)
  String _getSunsetTimeForSelectedDate() {
    final sunsetTime = SunsetService.getSunsetTime(_selectedGregorianDate);
    if (sunsetTime != null) {
      // تحويل من "5:04 PM" إلى "5:04 مساءً"
      final parts = sunsetTime.split(' ');
      if (parts.length == 2) {
        final time = parts[0];
        final period = parts[1] == 'PM' ? 'مساءً' : 'صباحاً';
        return '$time $period';
      }
      return sunsetTime;
    }
    return 'غير متاح';
  }

  // بناء تاريخ ووقت الموعد
  DateTime _buildAppointmentDateTime() {
    // ✅ إذا كانت المدة "عدة أيام"، استخدم 12:00 AM (منتصف الليل)
    int hour, minute;
    if (_selectedDuration == 'عدة أيام') {
      hour = 0; // 12:00 AM
      minute = 0;
    } else {
      hour = _selectedHour;
      minute = _selectedMinute;
      if (_selectedPeriod == 'مساءً' && hour != 12) {
        hour += 12;
      } else if (_selectedPeriod == 'صباحاً' && hour == 12) {
        hour = 0;
      }
    }

    if (_dateType == 'ميلادي') {
      return DateTime(
        _selectedYear,
        _getMonthNumber(_selectedMonth),
        _selectedDay,
        hour,
        minute,
      );
    } else {
      // تحويل التاريخ الهجري إلى ميلادي
      final userAdjustment = _authService.currentUser?.hijriAdjustment ?? 0;
      final gregorianDate = DateConverter.toGregorian(
        _selectedHijriDate,
        adjustment: userAdjustment,
      );
      return DateTime(
        gregorianDate.year,
        gregorianDate.month,
        gregorianDate.day,
        hour,
        minute,
      );
    }
  }

  // حفظ دعوات الضيوف
  Future<void> _saveGuestInvitations(String appointmentId) async {
    try {
      for (String guestId in _selectedGuests) {
        await _authService.pb
            .collection(AppConstants.invitationsCollection)
            .create(
              body: {
                'appointment': appointmentId,
                'guest': guestId,
                'status': 'invited',
                'invited_by': _authService.currentUser!.id,
              },
            );
      }
    } catch (e) {
      print('خطأ في حفظ دعوات الضيوف: $e');
    }
  }

  // إنشاء سجلات user_appointment_status للمنشئ فقط
  // الضيوف سيحصلون على سجلاتهم عند قبول الدعوة
  Future<void> _createUserAppointmentStatusRecords(
    String appointmentId,
    List<String> guestIds,
    String privacy, // إضافة معامل الخصوصية
    // ✅ إضافة بيانات الموعد الأساسية
    String title,
    String? region,
    String? building,
    DateTime appointmentDate,
  ) async {
    try {
      final statusService = UserAppointmentStatusService(_authService);

      // إنشاء سجل للمنشئ (المستخدم الحالي) فقط
      // نسخة المنشئ تأخذ الخصوصية من الموعد
      await statusService.createUserAppointmentStatus(
        userId: _authService.currentUser!.id,
        appointmentId: appointmentId,
        status: 'active',
        privacy: privacy, // استخدام الخصوصية الممررة
        // ✅ نسخ بيانات الموعد الأساسية
        title: title,
        region: region,
        building: building,
        appointmentDate: appointmentDate,
      );

      // ملاحظة: لا ننشئ سجلات للضيوف هنا
      // سيتم إنشاؤها عند قبولهم للدعوة في صفحة الإشعارات

      print(
        '✅ تم إنشاء سجل user_appointment_status للمنشئ في الموعد: $appointmentId',
      );
    } catch (e) {
      print('⚠️ خطأ في إنشاء سجل user_appointment_status للمنشئ: $e');
      // لا نرمي الخطأ لأن هذا fallback - الموعد تم إنشاؤه بنجاح
    }
  }

  // إعادة تعيين النموذج
  void _resetForm() {
    _titleController.clear();
    _regionController.clear();
    _buildingController.clear();
    _searchController.clear();
    _notesController.clear();

    setState(() {
      _isPrivate = false;
      _selectedGuests.clear();
      _dateType = 'ميلادي';
      _selectedMonth = 'يناير';
      _selectedDay = DateTime.now().day;
      _selectedYear = DateTime.now().year;
      _selectedWeekday = 'السبت';
      _selectedHour = 6; // الوقت الافتراضي 6:00 مساءً
      _selectedMinute = 0;
      _selectedPeriod = 'مساءً';
      _selectedDuration = '45 دقيقة';
      _initializeDates();
    });
  }

  // إظهار رسالة نجاح
  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // إظهار رسالة خطأ
  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: SafeArea(
          child: Column(
            children: [
              // AppBar with Save Button
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Text(
                            'إضافة موعد جديد',
                            style: TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                          if ((_authService.currentUser?.hijriAdjustment ??
                                  0) !=
                              0)
                            ...[],
                        ],
                      ),
                    ),
                    // زر الخصوصية
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isPrivate ? Icons.lock : Icons.public,
                          color: _isPrivate
                              ? const Color(0xFF2196F3)
                              : Colors.grey.shade600,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isPrivate ? 'خاص' : 'عام',
                          style: TextStyle(
                            color: _isPrivate
                                ? const Color(0xFF2196F3)
                                : Colors.grey.shade600,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Switch(
                          value: _isPrivate,
                          onChanged: (value) {
                            setState(() {
                              _isPrivate = value;
                            });
                          },
                          activeThumbColor: const Color(0xFF2196F3),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Form Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // حقل العنوان
                        TextFormField(
                          controller: _titleController,
                          decoration: InputDecoration(
                            labelText: 'موضوع الموعد',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            prefixIcon: const Icon(Icons.title),
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
                                        _selectedYear =
                                            _selectedGregorianDate.year;
                                        _selectedMonth = _getMonthName(
                                          _selectedGregorianDate.month,
                                        );
                                        _selectedDay =
                                            _selectedGregorianDate.day;

                                        // Update end date to Gregorian
                                        _endYear = _selectedGregorianDate.year;
                                        _endMonth = _getMonthName(
                                          _selectedGregorianDate.month,
                                        );
                                        _endDay = _selectedGregorianDate.day;
                                      } else {
                                        // Switch to Hijri - use current hijri date
                                        _selectedYear =
                                            _selectedHijriDate.hYear;
                                        _selectedMonth = _getHijriMonthName(
                                          _selectedHijriDate.hMonth,
                                        );
                                        _selectedDay = _selectedHijriDate.hDay;

                                        // Update end date to Hijri
                                        _endHijriYear =
                                            _selectedHijriDate.hYear;
                                        _endHijriMonth = _getHijriMonthName(
                                          _selectedHijriDate.hMonth,
                                        );
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
                                        // Switch to Hijri - use current hijri date with user adjustment
                                        final userAdjustment =
                                            _authService
                                                .currentUser
                                                ?.hijriAdjustment ??
                                            0;
                                        final adjustedHijriDate =
                                            DateConverter.toHijri(
                                              _selectedGregorianDate,
                                              adjustment: userAdjustment,
                                            );

                                        _selectedYear = adjustedHijriDate.hYear;
                                        _selectedMonth = _getHijriMonthName(
                                          adjustedHijriDate.hMonth,
                                        );
                                        _selectedDay = adjustedHijriDate.hDay;
                                        _selectedHijriDate = adjustedHijriDate;

                                        // Update end date to Hijri
                                        _endHijriYear = adjustedHijriDate.hYear;
                                        _endHijriMonth = _getHijriMonthName(
                                          adjustedHijriDate.hMonth,
                                        );
                                        _endHijriDay = adjustedHijriDate.hDay;
                                      } else {
                                        // Switch to Gregorian - use current gregorian date
                                        _selectedYear =
                                            _selectedGregorianDate.year;
                                        _selectedMonth = _getMonthName(
                                          _selectedGregorianDate.month,
                                        );
                                        _selectedDay =
                                            _selectedGregorianDate.day;

                                        // Update end date to Gregorian
                                        _endYear = _selectedGregorianDate.year;
                                        _endMonth = _getMonthName(
                                          _selectedGregorianDate.month,
                                        );
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
                                  color: _dateType == 'ميلادي'
                                      ? Colors.blue.shade700
                                      : Colors.grey.shade400,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'التاريخ الميلادي',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _dateType == 'ميلادي'
                                        ? Colors.blue.shade700
                                        : Colors.grey.shade400,
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
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                      enabled: _dateType == 'ميلادي',
                                    ),
                                    items:
                                        List.generate(31, (index) => index + 1)
                                            .map(
                                              (day) => DropdownMenuItem(
                                                value: day,
                                                child: Text(
                                                  day.toString(),
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: _dateType == 'ميلادي'
                                                        ? Colors.black
                                                        : Colors.grey.shade400,
                                                  ),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                    onChanged: _dateType == 'ميلادي'
                                        ? (value) {
                                            setState(() {
                                              _selectedGregorianDate = DateTime(
                                                _selectedGregorianDate.year,
                                                _selectedGregorianDate.month,
                                                value!,
                                              );
                                              final userAdjustment =
                                                  _authService
                                                      .currentUser
                                                      ?.hijriAdjustment ??
                                                  0;
                                              _selectedDay = value;
                                              _updateDateFromGregorian();
                                            });
                                          }
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // شهر ميلادي
                                Expanded(
                                  flex: 3,
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _getMonthName(
                                      _selectedGregorianDate.month,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'الشهر',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
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
                                                color: _dateType == 'ميلادي'
                                                    ? Colors.black
                                                    : Colors.grey.shade400,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: _dateType == 'ميلادي'
                                        ? (value) {
                                            setState(() {
                                              final monthIndex =
                                                  _gregorianMonths.indexOf(
                                                    value!,
                                                  ) +
                                                  1;
                                              _selectedGregorianDate = DateTime(
                                                _selectedGregorianDate.year,
                                                monthIndex,
                                                _selectedGregorianDate.day,
                                              );
                                              final userAdjustment =
                                                  _authService
                                                      .currentUser
                                                      ?.hijriAdjustment ??
                                                  0;
                                              _selectedMonth = value;
                                              _updateDateFromGregorian();
                                            });
                                          }
                                        : null,
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
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                      enabled: _dateType == 'ميلادي',
                                    ),
                                    items:
                                        List.generate(
                                              10,
                                              (index) =>
                                                  DateTime.now().year + index,
                                            )
                                            .map(
                                              (year) => DropdownMenuItem(
                                                value: year,
                                                child: Text(
                                                  year.toString(),
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: _dateType == 'ميلادي'
                                                        ? Colors.black
                                                        : Colors.grey.shade400,
                                                  ),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                    onChanged: _dateType == 'ميلادي'
                                        ? (value) {
                                            setState(() {
                                              _selectedGregorianDate = DateTime(
                                                value!,
                                                _selectedGregorianDate.month,
                                                _selectedGregorianDate.day,
                                              );
                                              final userAdjustment =
                                                  _authService
                                                      .currentUser
                                                      ?.hijriAdjustment ??
                                                  0;
                                              _selectedYear = value;
                                              _updateDateFromGregorian();
                                            });
                                          }
                                        : null,
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
                                  color: _dateType == 'هجري'
                                      ? Colors.orange.shade700
                                      : Colors.grey.shade400,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'التاريخ الهجري',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _dateType == 'هجري'
                                        ? Colors.orange.shade700
                                        : Colors.grey.shade400,
                                  ),
                                ),
                                // Hijri adjustment badge
                                if ((_authService
                                            .currentUser
                                            ?.hijriAdjustment ??
                                        0) !=
                                    0) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: Colors.green.shade300,
                                      ),
                                    ),
                                    child: Text(
                                      'تصحيح هجري: ${(_authService.currentUser?.hijriAdjustment ?? 0) >= 0 ? '+' : ''}${_authService.currentUser?.hijriAdjustment ?? 0}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.green.shade700,
                                        fontWeight: FontWeight.w600,
                                      ),
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
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                      enabled: _dateType == 'هجري',
                                    ),
                                    items:
                                        List.generate(30, (index) => index + 1)
                                            .map(
                                              (day) => DropdownMenuItem(
                                                value: day,
                                                child: Text(
                                                  day.toString(),
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: _dateType == 'هجري'
                                                        ? Colors.black
                                                        : Colors.grey.shade400,
                                                  ),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                    onChanged: _dateType == 'هجري'
                                        ? (value) {
                                            setState(() {
                                              _selectedDay = value!;
                                              _selectedYear =
                                                  _selectedHijriDate.hYear;
                                              _selectedMonth =
                                                  _getHijriMonthName(
                                                    _selectedHijriDate.hMonth,
                                                  );
                                              _updateDateFromHijri();
                                            });
                                          }
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // شهر هجري
                                Expanded(
                                  flex: 3,
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _getHijriMonthName(
                                      _selectedHijriDate.hMonth,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'الشهر',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
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
                                                color: _dateType == 'هجري'
                                                    ? Colors.black
                                                    : Colors.grey.shade400,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: _dateType == 'هجري'
                                        ? (value) {
                                            setState(() {
                                              _selectedMonth = value!;
                                              _selectedYear =
                                                  _selectedHijriDate.hYear;
                                              _selectedDay =
                                                  _selectedHijriDate.hDay;
                                              _updateDateFromHijri();
                                            });
                                          }
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // سنة هجري
                                Expanded(
                                  flex: 2,
                                  child: DropdownButtonFormField<int>(
                                    value: _dateType == 'هجري'
                                        ? _selectedYear
                                        : null,
                                    decoration: InputDecoration(
                                      labelText: 'السنة',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                      enabled: _dateType == 'هجري',
                                    ),
                                    items:
                                        List.generate(
                                              10,
                                              (index) => 1446 + index,
                                            )
                                            .map(
                                              (year) => DropdownMenuItem(
                                                value: year,
                                                child: Text(
                                                  year.toString(),
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: _dateType == 'هجري'
                                                        ? Colors.black
                                                        : Colors.grey.shade400,
                                                  ),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                    onChanged: _dateType == 'هجري'
                                        ? (value) {
                                            setState(() {
                                              _selectedYear = value!;
                                              _selectedMonth =
                                                  _getHijriMonthName(
                                                    _selectedHijriDate.hMonth,
                                                  );
                                              _selectedDay =
                                                  _selectedHijriDate.hDay;
                                              _updateDateFromHijri();
                                            });
                                          }
                                        : null,
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
                                    color: _dateType == 'ميلادي'
                                        ? null
                                        : Colors.grey.shade400,
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
                                            color: _dateType == 'ميلادي'
                                                ? Colors.black
                                                : Colors.grey.shade400,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: _dateType == 'ميلادي'
                                    ? (value) {
                                        setState(() {
                                          _selectedWeekday = value!;
                                          // Update date to match the selected weekday
                                          _updateDateToMatchWeekday(value);
                                        });
                                      }
                                    : null,
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

                        // اختيار الوقت (لا يظهر عند اختيار "عدة أيام")
                        if (_selectedDuration != 'عدة أيام')
                          Column(
                            children: [
                              // الدقيقة والساعة في صف واحد (معكوس)
                              Row(
                                children: [
                                  // الدقيقة أولاً (على اليسار)
                                  Expanded(
                                    flex: 2,
                                    child: DropdownButtonFormField<int>(
                                      initialValue: _selectedMinute,
                                      menuMaxHeight: 300,
                                      decoration: InputDecoration(
                                        labelText: 'الدقيقة',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                          borderSide: BorderSide(
                                            color: _hasMyTimeConflict()
                                                ? Colors.red
                                                : Colors.grey,
                                            width: _hasMyTimeConflict() ? 2 : 1,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                          borderSide: BorderSide(
                                            color: _hasMyTimeConflict()
                                                ? Colors.red
                                                : Colors.grey,
                                            width: _hasMyTimeConflict() ? 2 : 1,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                          borderSide: BorderSide(
                                            color: _hasMyTimeConflict()
                                                ? Colors.red
                                                : Colors.blue,
                                            width: 2,
                                          ),
                                        ),
                                        isDense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                      ),
                                      selectedItemBuilder: (context) {
                                        // ✅ استخدام نفس الترتيب المخصص للمعاينة
                                        final commonMinutes = [0, 15, 30, 45];
                                        final otherMinutes = List.generate(60, (i) => i)
                                            .where((m) => !commonMinutes.contains(m))
                                            .toList();
                                        final sortedMinutes = [...commonMinutes, ...otherMinutes];
                                        
                                        return sortedMinutes.map((minute) => Text(
                                              minute.toString().padLeft(2, '0'),
                                              style: const TextStyle(fontSize: 14),
                                            )).toList();
                                      },
                                      items: () {
                                        // ترتيب مخصص: الدقائق الشائعة أولاً ثم الباقي
                                        final commonMinutes = [0, 15, 30, 45];
                                        final otherMinutes = List.generate(60, (i) => i)
                                            .where((m) => !commonMinutes.contains(m))
                                            .toList();
                                        final sortedMinutes = [...commonMinutes, ...otherMinutes];
                                        
                                        return sortedMinutes.map(
                                          (minute) => DropdownMenuItem(
                                            value: minute,
                                            child: Container(
                                              width: 40,
                                              alignment: Alignment.center,
                                              child: Text(
                                                minute.toString().padLeft(2, '0'),
                                                style: const TextStyle(fontSize: 14),
                                              ),
                                            ),
                                          ),
                                        ).toList();
                                      }(),
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedMinute = value!;
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // الساعة ثانياً (على اليمين)
                                  Expanded(
                                    flex: 2,
                                    child: DropdownButtonFormField<int>(
                                      initialValue: _selectedHour,
                                      decoration: InputDecoration(
                                        labelText: 'الساعة',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                          borderSide: BorderSide(
                                            color: _hasMyTimeConflict()
                                                ? Colors.red
                                                : Colors.grey,
                                            width: _hasMyTimeConflict() ? 2 : 1,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                          borderSide: BorderSide(
                                            color: _hasMyTimeConflict()
                                                ? Colors.red
                                                : Colors.grey,
                                            width: _hasMyTimeConflict() ? 2 : 1,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                          borderSide: BorderSide(
                                            color: _hasMyTimeConflict()
                                                ? Colors.red
                                                : Colors.blue,
                                            width: 2,
                                          ),
                                        ),
                                        isDense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                      ),
                                      items:
                                          List.generate(
                                                12,
                                                (index) => index + 1,
                                              )
                                              .map(
                                                (hour) => DropdownMenuItem(
                                                  value: hour,
                                                  child: Text(
                                                    hour.toString(),
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                    ),
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
                                    flex: 3,
                                    child: DropdownButtonFormField<String>(
                                      initialValue: _selectedPeriod,
                                      decoration: InputDecoration(
                                        labelText: 'فترة',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                        ),
                                        isDense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
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
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                ),
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
                        
                        // عرض وقت الغروب للتاريخ المحدد
                        if (_selectedDuration != 'عدة أيام')
                          Column(
                            children: [
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.amber.shade200,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.wb_twilight,
                                      size: 16,
                                      color: Colors.amber.shade700,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'غروب الشمس لهذا اليوم: ${_getSunsetTimeForSelectedDate()}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.amber.shade900,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        if (_selectedDuration != 'عدة أيام')
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
                                      initialValue: _dateType == 'ميلادي'
                                          ? _endDay
                                          : _endHijriDay,
                                      decoration: InputDecoration(
                                        labelText: 'اليوم',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                        ),
                                        isDense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                      ),
                                      items:
                                          List.generate(
                                                _dateType == 'ميلادي' ? 31 : 30,
                                                (index) => index + 1,
                                              )
                                              .map(
                                                (day) => DropdownMenuItem(
                                                  value: day,
                                                  child: Text(
                                                    day.toString(),
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
                                      initialValue: _dateType == 'ميلادي'
                                          ? _endMonth
                                          : _endHijriMonth,
                                      decoration: InputDecoration(
                                        labelText: 'الشهر',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                        ),
                                        isDense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
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
                                      initialValue: _dateType == 'ميلادي'
                                          ? _endYear
                                          : _endHijriYear,
                                      decoration: InputDecoration(
                                        labelText: 'السنة',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                        ),
                                        isDense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                      ),
                                      items: _dateType == 'ميلادي'
                                          ? List.generate(
                                                  10,
                                                  (index) =>
                                                      DateTime.now().year +
                                                      index,
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
                                                  (index) => 1446 + index,
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
                        if (_selectedDuration == 'عدة أيام')
                          const SizedBox(height: 16),

                        _buildGuestSection(),
                        const SizedBox(height: 16),

                        // حقل الملاحظات
                        _buildNotesSection(),
                        const SizedBox(height: 16),

                        // زر الحفظ
                        GestureDetector(
                          onTap: _isSaving ? null : _saveAppointment,
                          onLongPress: _isSaving
                              ? null
                              : _saveAppointmentAndStay,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: _isSaving
                                  ? Colors.grey
                                  : const Color(0xFF2196F3),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _isSaving
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                    : const Icon(
                                        Icons.save,
                                        color: Colors.white,
                                      ),
                                const SizedBox(width: 8),
                                Text(
                                  _isSaving ? 'جاري الحفظ...' : 'حفظ الموعد',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // تلميح للمستخدم
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.blue.shade600,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'اضغط للحفظ والانتقال للرئيسية • اضغط مطولاً للحفظ وإضافة موعد آخر',
                                  style: TextStyle(
                                    color: Colors.blue.shade700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper methods and sections will be added in the next file

  Widget _buildGuestSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.people, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              Text(
                'دعوة الضيوف',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _searchController,
            textAlign: TextAlign.right,
            decoration: InputDecoration(
              labelText: 'البحث عن ضيوف',
              hintText: 'ابحث بالاسم أو اسم المستخدم...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              prefixIcon: const Icon(Icons.search),
            ),
            onChanged: _filterFriends,
          ),
          const SizedBox(height: 16),
          if (_selectedGuests.isNotEmpty) ...[
            Text(
              'الضيوف المدعوون (${_selectedGuests.length}):',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _selectedGuests.map((guestId) {
                final guest = _availableFriends.firstWhere(
                  (f) => f.id == guestId,
                  orElse: () => UserModel(
                    id: guestId,
                    email: '',
                    username: 'غير معروف',
                    name: 'غير معروف',
                    verified: false,
                    avatar: '',
                    bio: '',
                    socialLink: '',
                    phone: '',
                    role: 'user',
                    joiningDate: DateTime.now().toIso8601String(),
                    hijriAdjustment: 0,
                    createdDate: DateTime.now(),
                  ),
                );
                return Chip(
                  avatar: CircleAvatar(
                    radius: 12,
                    backgroundImage: (guest.avatar?.isNotEmpty ?? false)
                        ? NetworkImage(_getUserAvatarUrl(guest))
                        : null,
                    child: (guest.avatar?.isEmpty ?? true)
                        ? const Icon(Icons.person, size: 16)
                        : null,
                  ),
                  label: Text(guest.name, style: const TextStyle(fontSize: 12)),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () =>
                      setState(() => _selectedGuests.remove(guestId)),
                  backgroundColor: Colors.orange.shade100,
                );
              }).toList(),
            ),
            const Divider(height: 24),
          ],
          SizedBox(
            height: 150,
            child: _isLoadingFriends
                ? const Center(child: CircularProgressIndicator())
                : _filteredFriends.isEmpty
                ? Center(
                    child: Text(
                      _searchQuery.isEmpty
                          ? 'لا توجد متابعات'
                          : 'لا توجد نتائج',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredFriends.length,
                    itemBuilder: (context, index) {
                      final friend = _filteredFriends[index];
                      final isSelected = _selectedGuests.contains(friend.id);
                      return ListTile(
                        dense: true,
                        leading: Container(
                          width: 36, // 32 + (2 * 2) للطوق
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _getFriendRingColor(
                                friend,
                              ), // لون ديناميكي
                              width: 2,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(
                              2,
                            ), // الفجوة بين الصورة والطوق
                            child: CircleAvatar(
                              radius: 14,
                              backgroundImage:
                                  _getUserAvatarUrl(friend).isNotEmpty
                                  ? NetworkImage(_getUserAvatarUrl(friend))
                                  : null,
                              backgroundColor: Colors.grey.shade200,
                              child: _getUserAvatarUrl(friend).isEmpty
                                  ? const Icon(Icons.person, size: 14)
                                  : null,
                            ),
                          ),
                        ),
                        title: Text(
                          friend.name,
                          style: const TextStyle(fontSize: 14),
                        ),
                        subtitle: Text(
                          '@${friend.username}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        trailing: Checkbox(
                          value: isSelected,
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                _selectedGuests.add(friend.id);
                              } else {
                                _selectedGuests.remove(friend.id);
                              }
                            });
                          },
                          activeColor: Colors.orange,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // حقل الملاحظات
  Widget _buildNotesSection() {
    return TextFormField(
      controller: _notesController,
      minLines: 1,
      maxLines: null, // يتوسع حسب المحتوى
      decoration: InputDecoration(
        labelText: 'ملاحظات الموعد',
        hintText: 'أضف ملاحظات أو روابط مفيدة للموعد...',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
        prefixIcon: const Icon(Icons.note_alt),
      ),
    );
  }
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final AuthService _authService = AuthService();

  List<UserModel> _searchResults = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _hasSearched = false;
        _searchQuery = '';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _searchQuery = query;
    });

    try {
      // البحث في قاعدة البيانات مع تضمين المستخدمين العامين
      final records = await _authService.pb
          .collection(AppConstants.usersCollection)
          .getFullList(
            // البحث في الاسم واسم المستخدم للمستخدمين العامين أو المستخدم الحالي
            filter:
                '(isPublic = true || id = "${_authService.currentUser?.id}") && (name ~ "$query" || username ~ "$query")',
            sort: 'name',
          );

      List<UserModel> users = records.map((record) {
        return UserModel.fromJson(record.toJson());
      }).toList();

      // تطبيق البحث المحلي مع التطبيع العربي
      users = users.where((user) {
        return ArabicSearchUtils.searchInUserFields(
          user.name,
          user.username,
          user.bio,
          query,
        );
      }).toList();

      setState(() {
        _searchResults = users;
        _isLoading = false;
        _hasSearched = true;
      });
    } catch (e) {
      setState(() {
        _searchResults = [];
        _isLoading = false;
        _hasSearched = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Column(
          children: [
            // AppBar with Search
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'البحث عن المستخدمين',
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchController,
                    textAlign: TextAlign.right,
                    decoration: InputDecoration(
                      hintText: 'ابحث بالاسم أو اسم المستخدم...',
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, color: Colors.grey[600]),
                              onPressed: () {
                                _searchController.clear();
                                _performSearch('');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(color: Colors.grey.shade600),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(color: Color(0xFF2196F3)),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (value) {
                      setState(() {});
                      // تأخير البحث لتجنب الكثير من الطلبات
                      Future.delayed(const Duration(milliseconds: 500), () {
                        if (_searchController.text == value) {
                          _performSearch(value);
                        }
                      });
                    },
                    onSubmitted: _performSearch,
                  ),
                ],
              ),
            ),

            // Search Results
            Expanded(child: _buildSearchContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF2196F3)),
      );
    }

    if (!_hasSearched) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 20),
            Text(
              'ابحث عن المستخدمين',
              style: TextStyle(
                fontSize: 20,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'اكتب اسم المستخدم أو الاسم الظاهر للبحث',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 20),
            Text(
              'لا توجد نتائج',
              style: TextStyle(
                fontSize: 20,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'لم يتم العثور على مستخدمين بهذا الاسم',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        return _buildUserCard(user);
      },
    );
  }

  Widget _buildUserCard(UserModel user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 64, // 60 + (2 * 2) للطوق
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: _getSearchUserRingColor(user), // لون ديناميكي
              width: 2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(2), // الفجوة بين الصورة والطوق
            child: CircleAvatar(
              radius: 28,
              backgroundImage: _getUserAvatarUrl(user).isNotEmpty
                  ? NetworkImage(_getUserAvatarUrl(user))
                  : null,
              backgroundColor: Colors.grey.shade200,
              child: _getUserAvatarUrl(user).isEmpty
                  ? Icon(Icons.person, color: Colors.grey.shade600, size: 28)
                  : null,
            ),
          ),
        ),
        title: Text(
          user.name.isNotEmpty ? user.name : user.username,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '@${user.username}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            if (user.bio != null && user.bio!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                user.bio!,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.grey.shade400,
        ),
        onTap: () => _openUserProfile(user),
      ),
    );
  }

  // الحصول على رابط الصورة الشخصية
  String _getUserAvatarUrl(UserModel user) {
    if (user.avatar == null || user.avatar!.isEmpty) {
      return '';
    }

    final cleanAvatar = user.avatar!
        .replaceAll('[', '')
        .replaceAll(']', '')
        .replaceAll('"', '');
    return '${AppConstants.pocketbaseUrl}/api/files/${AppConstants.usersCollection}/${user.id}/$cleanAvatar';
  }

  // تحديد لون الطوق للمستخدمين في نتائج البحث
  Color _getSearchUserRingColor(UserModel user) {
    // حالياً: رمادي دائماً في نتائج البحث
    Color ringColor = Colors.grey.shade400;

    // متاح للتطوير المستقبلي:
    // if (user.verified) ringColor = const Color(0xFF2196F3); // أزرق للمتحققين
    // if (user.isOnline) ringColor = Colors.green; // أخضر للمتصلين
    // if (user.isFriend) ringColor = Colors.purple; // بنفسجي للأصدقاء
    // if (user.isPremium) ringColor = Colors.amber; // أصفر للمميزين

    return ringColor;
  }

  void _openUserProfile(UserModel user) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            UserProfileScreen(userId: user.id, username: user.username),
      ),
    );
  }
}
