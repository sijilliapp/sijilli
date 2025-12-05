import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/connectivity_service.dart';
import '../services/user_appointment_status_service.dart';
import '../models/appointment_model.dart';
import '../models/user_model.dart';
import '../models/invitation_model.dart';
import '../models/user_appointment_status_model.dart';
import '../models/article_model.dart';
import '../config/constants.dart';
import '../widgets/appointment_card.dart';
import '../utils/arabic_search_utils.dart';
import '../utils/date_converter.dart';
import 'draft_forms_screen.dart';
import 'friends_screen.dart';
import 'login_screen.dart';
import 'archive_screen.dart';
import 'appointment_details_screen.dart';
import 'add_article_screen.dart';
import 'article_details_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final DatabaseService _dbService = DatabaseService();
  final ConnectivityService _connectivityService = ConnectivityService();
  late final UserAppointmentStatusService _statusService;

  List<AppointmentModel> _appointments = [];
  List<AppointmentModel> _filteredAppointments = [];
  Map<String, List<UserModel>> _appointmentGuests =
      {}; // معرف الموعد -> قائمة الضيوف
  Map<String, List<InvitationModel>> _appointmentInvitations =
      {}; // معرف الموعد -> قائمة الدعوات
  Map<String, UserModel> _appointmentHosts =
      {}; // معرف الموعد -> معلومات المنشئ
  Map<String, Map<String, UserAppointmentStatusModel>> _participantsStatus =
      {}; // معرف الموعد -> حالات المشاركين
  bool _isOnline = true;
  late TabController _tabController;
  
  // متغيرات المقالات
  List<ArticleModel> _articles = [];
  bool _isLoadingArticles = false;

  // متغيرات البحث
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _statusService = UserAppointmentStatusService(_authService);
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // لتحديث المحتوى عند تغيير التبويب
    });
    _searchController.addListener(_onSearchChanged);
    // تهيئة القائمة المفلترة
    _filteredAppointments = List.from(_appointments);
    _initializeData();
    _listenToConnectivity();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    // تحميل المواعيد فوراً (Local-First) - المصادقة تمت بالفعل في SplashScreen
    await _loadAppointments();
    // تحميل المقالات
    await _loadArticles();
  }

  void _listenToConnectivity() {
    _connectivityService.onConnectivityChanged.listen((isConnected) {
      if (mounted) {
        setState(() => _isOnline = isConnected);
        if (isConnected) {
          _loadAppointments();
          _syncOfflineAppointments(); // مزامنة المواعيد المحفوظة أوفلاين
        }
      }
    });
  }

  Future<void> _loadAppointments() async {
    if (!mounted) return;

    try {
      // 1. Load from Cache FIRST (instant) ⚡
      await _loadAppointmentsFromCache();

      // 2. Check internet connection
      final isOnline = await _connectivityService.hasConnection();
      if (!mounted) return;
      setState(() => _isOnline = isOnline);

      // 3. If online, update from PocketHost in background
      if (isOnline && _authService.isAuthenticated) {
        try {
          final currentUserId = _authService.currentUser?.id;
          if (currentUserId == null) return;

          print('🔄 تحديث البيانات من الخادم...');

          // جلب المواعيد النشطة فقط (بدون المحذوفة أو المؤرشفة)
          List<String> activeAppointmentIds = [];
          try {
            activeAppointmentIds = await _statusService
                .getActiveAppointmentIdsForCurrentUser();
          } catch (e) {
            print('⚠️ النظام الجديد غير متاح، استخدام النظام القديم: $e');
            // العودة للنظام القديم إذا لم يكن الجدول الجديد موجود
            final myHostedAppointments = await _authService.pb
                .collection(AppConstants.appointmentsCollection)
                .getList(
                  page: 1,
                  perPage: 20,
                  filter: 'host = "$currentUserId"',
                  sort: '-appointment_date',
                );

            // جلب الدعوات المقبولة فقط - الضيوف المدعوون والذين لم يقرروا بعد لا يجب أن يروا الموعد
            final acceptedInvitations = await _authService.pb
                .collection(AppConstants.invitationsCollection)
                .getList(
                  page: 1,
                  perPage: 20,
                  filter: 'guest = "$currentUserId" && status = "accepted"',
                  expand: 'appointment',
                );

            // معالجة النظام القديم
            await _processOldSystemAppointments(
              myHostedAppointments,
              acceptedInvitations,
            );
            return;
          }

          // جلب كل المواعيد باستخدام النظام الجديد
          if (activeAppointmentIds.isNotEmpty) {
            final appointmentFilter = activeAppointmentIds
                .map((id) => 'id = "$id"')
                .join(' || ');
            final activeAppointments = await _authService.pb
                .collection(AppConstants.appointmentsCollection)
                .getList(
                  page: 1,
                  perPage: 50,
                  filter: '($appointmentFilter)',
                  sort: '-appointment_date',
                );

            final allAppointments = activeAppointments.items
                .map((record) => AppointmentModel.fromJson(record.toJson()))
                .toList();

            // ✅ جلب حالات المشاركين بالتوازي (أسرع بكثير!)
            final statusFutures = allAppointments.map((appointment) async {
              final participantsStatus = await _statusService
                  .getAllParticipantsStatus(appointment.id);
              _participantsStatus[appointment.id] = participantsStatus;
              print('📊 حالات المشاركين للموعد ${appointment.title}: ${participantsStatus.length} مشارك');
            });
            await Future.wait(statusFutures);

            await _processNewSystemAppointments(allAppointments);
          }

          // إذا لم تكن هناك مواعيد نشطة من السيرفر
          if (activeAppointmentIds.isEmpty) {
            print('⚠️ لا توجد مواعيد نشطة من السيرفر');
            // لا نفرغ القائمة إذا كان لدينا بيانات محفوظة
            if (_appointments.isEmpty && mounted) {
              setState(() {
                _appointments = [];
                _filteredAppointments = [];
              });
            }
            return;
          }

          // لا نحتاج لمعالجة إضافية هنا - تم التعامل مع كل شيء في النظام الجديد
          
          // 🔄 الإعداد المسبق لبيانات الأرشيف في الخلفية (بدون انتظار)
          ArchiveScreen.prefetchArchiveData(_authService).then((_) {
            print('✅ تم الإعداد المسبق للأرشيف');
          }).catchError((e) {
            print('⚠️ فشل الإعداد المسبق للأرشيف: $e');
          });
        } catch (e) {
          print('⚠️ خطأ في تحديث البيانات من السيرفر: $e');
          // If server error, keep showing cached data (already loaded)
          // No need to do anything
        }
      }
      // If offline, just show cached data (already loaded in step 1)
    } catch (e) {
      print('❌ خطأ في تحميل المواعيد: $e');
      // If any error, keep showing cached data if available
      // Don't clear the list if we have cached data
      if (_appointments.isEmpty && mounted) {
        setState(() {
          _appointments = [];
          _filteredAppointments = [];
        });
      }
    }
  }

  // دوال Cache للمواعيد
  Future<void> _loadAppointmentsFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = _authService.currentUser?.id;
      if (userId == null) return;

      final cachedData = prefs.getString('appointments_$userId');
      if (cachedData != null) {
        final List<dynamic> jsonList = jsonDecode(cachedData);
        final appointments = jsonList
            .map((json) => AppointmentModel.fromJson(json))
            .toList();
        if (mounted) {
          setState(() {
            _appointments = appointments;
            _applyFilters();
          });

          // جلب معلومات المنشئين والضيوف للبيانات المحملة من الكاش
          await _loadAppointmentHostsFromCache();
          await _loadGuestsAndInvitationsFromCache();

          // تحديث الواجهة فوراً بالبيانات المحفوظة
          if (mounted) setState(() {});
          
          // ملاحظة: لا نستدعي _loadAppointmentHosts و _loadGuestsAndInvitations هنا
          // لأنهم سيتم استدعاؤهم في _processNewSystemAppointments
        }
      }
    } catch (e) {
      // Ignore cache errors
    }
  }

  Future<void> _saveAppointmentsToCache(
    List<AppointmentModel> appointments,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = _authService.currentUser?.id;
      if (userId == null) return;

      final jsonList = appointments
          .map((appointment) => appointment.toJson())
          .toList();
      await prefs.setString('appointments_$userId', jsonEncode(jsonList));

      // حفظ بيانات المنشئين أيضاً
      await _saveAppointmentHostsToCache();
    } catch (e) {
      // Ignore cache errors
    }
  }

  // حفظ بيانات المنشئين في التخزين المحلي
  Future<void> _saveAppointmentHostsToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = _authService.currentUser?.id;
      if (userId == null) return;

      final hostsJson = <String, dynamic>{};
      _appointmentHosts.forEach((appointmentId, host) {
        hostsJson[appointmentId] = host.toJson();
      });

      await prefs.setString('appointment_hosts_$userId', jsonEncode(hostsJson));
      print(
        '💾 تم حفظ معلومات ${_appointmentHosts.length} منشئ في التخزين المحلي',
      );
    } catch (e) {
      print('❌ خطأ في حفظ معلومات المنشئين: $e');
    }
  }

  // تحميل بيانات المنشئين من التخزين المحلي
  Future<void> _loadAppointmentHostsFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = _authService.currentUser?.id;
      if (userId == null) return;

      final cachedHostsData = prefs.getString('appointment_hosts_$userId');
      if (cachedHostsData != null) {
        final hostsJson = jsonDecode(cachedHostsData) as Map<String, dynamic>;

        _appointmentHosts.clear();
        hostsJson.forEach((appointmentId, hostJson) {
          try {
            final host = UserModel.fromJson(hostJson as Map<String, dynamic>);
            _appointmentHosts[appointmentId] = host;
          } catch (e) {
            print('خطأ في معالجة بيانات منشئ محفوظ: $e');
          }
        });

        print(
          '📱 تم تحميل معلومات ${_appointmentHosts.length} منشئ من التخزين المحلي',
        );

        // تحديث الواجهة فوراً
        if (mounted) setState(() {});
      }
    } catch (e) {
      print('❌ خطأ في تحميل معلومات المنشئين من التخزين المحلي: $e');
    }
  }

  // تحميل بيانات الضيوف والدعوات من التخزين المحلي
  Future<void> _loadGuestsAndInvitationsFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = _authService.currentUser?.id;
      if (userId == null) return;

      // تحميل الضيوف
      final cachedGuestsData = prefs.getString('appointment_guests_$userId');
      if (cachedGuestsData != null) {
        final guestsJson = jsonDecode(cachedGuestsData) as Map<String, dynamic>;

        _appointmentGuests.clear();
        guestsJson.forEach((appointmentId, guestsList) {
          final guests = (guestsList as List)
              .map((g) => UserModel.fromJson(g))
              .toList();
          _appointmentGuests[appointmentId] = guests;
        });

        print(
          '📱 تم تحميل ضيوف ${_appointmentGuests.length} موعد من التخزين المحلي',
        );

        // تحديث الواجهة فوراً
        if (mounted) setState(() {});
      }

      // تحميل الدعوات
      final cachedInvitationsData = prefs.getString(
        'appointment_invitations_$userId',
      );
      if (cachedInvitationsData != null) {
        final invitationsJson =
            jsonDecode(cachedInvitationsData) as Map<String, dynamic>;

        _appointmentInvitations.clear();
        invitationsJson.forEach((appointmentId, invitationsList) {
          final invitations = (invitationsList as List)
              .map((i) => InvitationModel.fromJson(i))
              .toList();
          _appointmentInvitations[appointmentId] = invitations;
        });

        print(
          '📱 تم تحميل دعوات ${_appointmentInvitations.length} موعد من التخزين المحلي',
        );

        // تحديث الواجهة فوراً
        if (mounted) setState(() {});
      }
    } catch (e) {
      print('❌ خطأ في تحميل بيانات الضيوف والدعوات من التخزين المحلي: $e');
    }
  }

  // حفظ بيانات الضيوف والدعوات في التخزين المحلي
  Future<void> _saveGuestsAndInvitationsToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = _authService.currentUser?.id;
      if (userId == null) return;

      // حفظ الضيوف
      final guestsJson = <String, dynamic>{};
      _appointmentGuests.forEach((appointmentId, guests) {
        guestsJson[appointmentId] = guests.map((g) => g.toJson()).toList();
      });
      await prefs.setString(
        'appointment_guests_$userId',
        jsonEncode(guestsJson),
      );

      // حفظ الدعوات
      final invitationsJson = <String, dynamic>{};
      _appointmentInvitations.forEach((appointmentId, invitations) {
        invitationsJson[appointmentId] = invitations
            .map((i) => i.toJson())
            .toList();
      });
      await prefs.setString(
        'appointment_invitations_$userId',
        jsonEncode(invitationsJson),
      );

      print('📱 تم حفظ بيانات الضيوف والدعوات في التخزين المحلي');
    } catch (e) {
      print('❌ خطأ في حفظ بيانات الضيوف والدعوات: $e');
    }
  }

  // جلب الضيوف والدعوات للمواعيد (محسن للأداء)
  Future<void> _loadGuestsAndInvitations(
    List<AppointmentModel> appointments,
  ) async {
    try {
      if (appointments.isEmpty) return;

      // جلب جميع الدعوات في طلب واحد (أسرع بكثير)
      final appointmentIds = appointments.map((apt) => apt.id).toList();
      final filterConditions = appointmentIds
          .map((id) => 'appointment = "$id"')
          .join(' || ');

      print('🔄 جلب دعوات ${appointments.length} موعد في طلب واحد...');

      final allInvitationRecords = await _authService.pb
          .collection(AppConstants.invitationsCollection)
          .getFullList(filter: '($filterConditions)', expand: 'guest');

      print('📊 تم جلب ${allInvitationRecords.length} دعوة');

      // تجميع الدعوات والضيوف حسب الموعد في خرائط مؤقتة
      final tempGuests = <String, List<UserModel>>{};
      final tempInvitations = <String, List<InvitationModel>>{};

      for (final appointment in appointments) {
        final invitations = <InvitationModel>[];
        final guests = <UserModel>[];

        // فلترة الدعوات الخاصة بهذا الموعد
        final appointmentInvitations = allInvitationRecords
            .where((record) => record.data['appointment'] == appointment.id)
            .toList();

        for (final record in appointmentInvitations) {
          try {
            final invitation = InvitationModel.fromJson(record.toJson());
            invitations.add(invitation);

            // جلب بيانات الضيف من expand
            final expandData = record.data['expand'];
            if (expandData != null && expandData['guest'] != null) {
              final guestData = expandData['guest'];
              final guest = UserModel.fromJson(guestData);
              guests.add(guest);
            }
          } catch (e) {
            print('خطأ في معالجة دعوة: $e');
            continue;
          }
        }

        tempInvitations[appointment.id] = invitations;
        tempGuests[appointment.id] = guests;
      }

      // استبدال البيانات دفعة واحدة (بدون مسح أولاً)
      _appointmentInvitations = tempInvitations;
      _appointmentGuests = tempGuests;

      // تحديث الواجهة فوراً
      if (mounted) setState(() {});

      // حفظ في الكاش
      await _saveGuestsAndInvitationsToCache();

      print('✅ تم تحميل ضيوف ${appointments.length} موعد بنجاح');
    } catch (e) {
      print('❌ خطأ في جلب الضيوف والدعوات: $e');
    }
  }

  // جلب معلومات منشئي المواعيد (المضيفين/الدعاة)
  Future<void> _loadAppointmentHosts(
    List<AppointmentModel> appointments,
  ) async {
    print('🏠🏠 بدء جلب معلومات منشئي المواعيد...');
    try {
      if (appointments.isEmpty) {
        print('⚠️ لا توجد مواعيد لجلب منشئيها');
        return;
      }

      // جمع معرفات المنشئين الفريدة
      final hostIds = appointments.map((apt) => apt.hostId).toSet().toList();

      if (hostIds.isEmpty) return;

      print('🔄 جلب معلومات ${hostIds.length} منشئ موعد...');

      // جلب معلومات جميع المنشئين في طلب واحد
      final filterConditions = hostIds.map((id) => 'id = "$id"').join(' || ');

      final hostRecords = await _authService.pb
          .collection(AppConstants.usersCollection)
          .getFullList(filter: '($filterConditions)');

      print('📊 تم جلب معلومات ${hostRecords.length} منشئ');

      // تحويل البيانات وربطها بالمواعيد في خريطة مؤقتة
      final hostsMap = <String, UserModel>{};
      for (final record in hostRecords) {
        try {
          final host = UserModel.fromJson(record.toJson());
          hostsMap[host.id] = host;
        } catch (e) {
          print('خطأ في معالجة بيانات منشئ: $e');
          continue;
        }
      }

      // إنشاء خريطة مؤقتة للمنشئين حسب الموعد
      final tempHosts = <String, UserModel>{};
      for (final appointment in appointments) {
        final host = hostsMap[appointment.hostId];
        if (host != null) {
          tempHosts[appointment.id] = host;
        }
      }

      // استبدال البيانات دفعة واحدة (بدون مسح أولاً)
      _appointmentHosts = tempHosts;

      // تحديث الواجهة فوراً
      if (mounted) setState(() {});

      print('✅ تم تحميل معلومات منشئي ${_appointmentHosts.length} موعد بنجاح');

      // حفظ بيانات المنشئين في التخزين المحلي
      await _saveAppointmentHostsToCache();
    } catch (e) {
      print('❌ خطأ في جلب معلومات المنشئين: $e');
    }
  }

  // دالة نسخ رابط الحساب
  Future<void> _copyProfileLink() async {
    final user = _authService.currentUser;
    if (user != null) {
      final profileLink = 'sijilli.com/${user.username}';
      await Clipboard.setData(ClipboardData(text: profileLink));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم نسخ الرابط: $profileLink'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // دالة مساعدة لرابط الصورة
  String? _getUserAvatarUrl(dynamic user) {
    if (user?.avatar == null || user.avatar?.isEmpty == true) {
      return null;
    }

    final cleanAvatar = user.avatar!
        .replaceAll('[', '')
        .replaceAll(']', '')
        .replaceAll('"', '');
    return '${AppConstants.pocketbaseUrl}/api/files/${AppConstants.usersCollection}/${user.id}/$cleanAvatar';
  }

  // دوال فحص حالة المواعيد
  bool _hasTodayAppointments() {
    final today = DateTime.now();
    return _appointments.any((appointment) {
      final appointmentDate = appointment.appointmentDate;
      return appointmentDate.year == today.year &&
          appointmentDate.month == today.month &&
          appointmentDate.day == today.day;
    });
  }

  bool _hasActiveAppointment() {
    final now = DateTime.now();
    return _appointments.any((appointment) {
      final appointmentDate = appointment.appointmentDate;
      final appointmentEnd = appointmentDate.add(const Duration(hours: 1));
      return now.isAfter(appointmentDate) && now.isBefore(appointmentEnd);
    });
  }

  // دوال البحث والفلترة
  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
      _applyFilters();
    });
  }

  void _applyFilters() {
    List<AppointmentModel> filtered = List.from(_appointments);

    // تطبيق البحث النصي مع التطبيع العربي
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((apt) {
        return ArabicSearchUtils.matchesArabicSearch(apt.title, _searchQuery) ||
            ArabicSearchUtils.matchesArabicSearch(
              apt.region ?? '',
              _searchQuery,
            ) ||
            ArabicSearchUtils.matchesArabicSearch(
              apt.building ?? '',
              _searchQuery,
            );
      }).toList();
    }

    // ترتيب المواعيد: النشطة في الأعلى (الأقرب أولاً)، ثم الفائتة (الأحدث أولاً)
    final now = DateTime.now();
    
    // فصل المواعيد إلى نشطة وفائتة
    final activeAppointments = filtered.where((apt) => apt.appointmentDate.isAfter(now)).toList();
    final pastAppointments = filtered.where((apt) => !apt.appointmentDate.isAfter(now)).toList();
    
    // ترتيب النشطة: الأقرب أولاً (تصاعدي)
    activeAppointments.sort((a, b) => a.appointmentDate.compareTo(b.appointmentDate));
    
    // ترتيب الفائتة: الأحدث أولاً (تنازلي)
    pastAppointments.sort((a, b) => b.appointmentDate.compareTo(a.appointmentDate));
    
    // دمج القوائم: النشطة أولاً ثم الفائتة
    _filteredAppointments = [...activeAppointments, ...pastAppointments];
  }

  // فحص إذا كان الموعد نشط (جاري حالياً)
  bool _isAppointmentActive(AppointmentModel appointment, DateTime now) {
    final appointmentStart = appointment.appointmentDate;
    final appointmentEnd = appointmentStart.add(
      Duration(hours: 2),
    ); // افتراض مدة الموعد ساعتين

    return now.isAfter(appointmentStart) && now.isBefore(appointmentEnd);
  }

  // فحص تداخل الموعد مع مواعيد أخرى
  bool _hasTimeConflict(AppointmentModel appointment) {
    final appointmentStart = appointment.appointmentDate;
    final appointmentEnd = appointmentStart.add(const Duration(minutes: 45));

    return _appointments.any((otherAppointment) {
      // تجاهل نفس الموعد
      if (otherAppointment.id == appointment.id) return false;

      final otherStart = otherAppointment.appointmentDate;
      final otherEnd = otherStart.add(const Duration(minutes: 45));

      // فحص التداخل الزمني
      return appointmentStart.isBefore(otherEnd) &&
          appointmentEnd.isAfter(otherStart);
    });
  }

  // معالجة المواعيد باستخدام النظام القديم (fallback)
  Future<void> _processOldSystemAppointments(
    dynamic myHostedAppointments,
    dynamic acceptedInvitations,
  ) async {
    // جمع المواعيد من الدعوات المقبولة (محسن)
    List<AppointmentModel> invitedAppointments = [];
    for (final invitation in acceptedInvitations.items) {
      try {
        // استخدام expand بدلاً من طلبات منفصلة
        final expandData = invitation.data['expand'];
        if (expandData != null && expandData['appointment'] != null) {
          final appointmentData = expandData['appointment'];
          final appointment = AppointmentModel.fromJson(appointmentData);

          // إضافة الموعد (الفلترة تتم عبر user_appointment_status)
          invitedAppointments.add(appointment);
        }
      } catch (e) {
        print('خطأ في معالجة موعد مدعو: $e');
        continue;
      }
    }

    // دمج المواعيد (المضيفة + المدعو إليها)
    final allAppointments = <AppointmentModel>[];
    allAppointments.addAll(
      myHostedAppointments.items.map(
        (record) => AppointmentModel.fromJson(record.toJson()),
      ),
    );
    allAppointments.addAll(invitedAppointments);

    // ترتيب حسب التاريخ وإزالة المكررات
    final uniqueAppointments = <String, AppointmentModel>{};
    for (final appointment in allAppointments) {
      uniqueAppointments[appointment.id] = appointment;
    }

    final appointments = uniqueAppointments.values.toList();
    appointments.sort((a, b) => b.appointmentDate.compareTo(a.appointmentDate));

    // ✅ تحديث الواجهة فوراً بالمواعيد (بدون انتظار الضيوف والمنشئين)
    if (mounted) {
      setState(() {
        _appointments = appointments;
        _applyFilters();
      });
    }

    // Save to Cache for next time ⚡
    await _saveAppointmentsToCache(appointments);

    // ✅ جلب الضيوف والمنشئين بالتوازي (أسرع بكثير!)
    await Future.wait([
      _loadGuestsAndInvitations(appointments),
      _loadAppointmentHosts(appointments),
    ]);

    // حفظ البيانات الجديدة في التخزين المحلي
    await Future.wait([
      _saveGuestsAndInvitationsToCache(),
      _saveAppointmentHostsToCache(),
    ]);

    // ✅ تحديث الواجهة مرة أخرى بعد جلب الضيوف والمنشئين
    if (mounted) {
      setState(() {});
    }
  }

  // معالجة المواعيد باستخدام النظام الجديد
  Future<void> _processNewSystemAppointments(
    List<AppointmentModel> appointments,
  ) async {
    // ترتيب حسب التاريخ
    appointments.sort((a, b) => b.appointmentDate.compareTo(a.appointmentDate));

    // ✅ تحديث الواجهة فوراً بالمواعيد (بدون انتظار الضيوف والمنشئين)
    if (mounted) {
      setState(() {
        _appointments = appointments;
        _applyFilters();
      });
    }

    // Save to Cache for next time ⚡
    await _saveAppointmentsToCache(appointments);

    // ✅ جلب الضيوف والمنشئين بالتوازي (أسرع بكثير!)
    await Future.wait([
      _loadGuestsAndInvitations(appointments),
      _loadAppointmentHosts(appointments),
    ]);

    // حفظ البيانات الجديدة في التخزين المحلي
    await Future.wait([
      _saveGuestsAndInvitationsToCache(),
      _saveAppointmentHostsToCache(),
    ]);

    // ✅ تحديث الواجهة مرة أخرى بعد جلب الضيوف والمنشئين
    if (mounted) {
      setState(() {});
    }
  }

  // Widget صورة المستخدم
  Widget _buildUserProfilePicture() {
    final user = _authService.currentUser;
    final hasToday = _hasTodayAppointments();
    final hasActive = _hasActiveAppointment();

    // تحديد لون الطوق
    Color ringColor = Colors.grey.shade400; // الوضع الاعتيادي
    List<BoxShadow> shadows = [];

    if (hasActive) {
      // أزرق مشع للخارج عند وجود موعد نشط
      ringColor = const Color(0xFF2196F3);
      shadows = [
        BoxShadow(
          color: const Color(0xFF2196F3).withValues(alpha: 0.4),
          blurRadius: 20,
          spreadRadius: 5,
        ),
        BoxShadow(
          color: const Color(0xFF2196F3).withValues(alpha: 0.2),
          blurRadius: 40,
          spreadRadius: 10,
        ),
      ];
    } else if (hasToday) {
      // أزرق عندما يكون عنده موعد في نفس اليوم
      ringColor = const Color(0xFF2196F3);
    }

    return Center(
      child: Container(
        width: 146, // 140 + (3 * 2) للطوق والفجوة
        height: 146,
        decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: shadows),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: ringColor, width: 3),
          ),
          child: Padding(
            padding: const EdgeInsets.all(3), // الفجوة بين الصورة والطوق
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey.shade200,
              ),
              child: _getUserAvatarUrl(user) == null
                  ? Icon(Icons.person, size: 70, color: Colors.grey.shade500)
                  : ClipOval(
                      child: Image.network(
                        _getUserAvatarUrl(user)!,
                        width: 140,
                        height: 140,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) {
                            return child;
                          }
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                  : null,
                              strokeWidth: 3,
                              color: const Color(0xFF2196F3),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.person,
                            size: 70,
                            color: Colors.grey.shade500,
                          );
                        },
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  // Widget رابط الحساب - تصميم تيك توك
  Widget _buildProfileLink() {
    final user = _authService.currentUser;
    if (user == null) return const SizedBox.shrink();

    final profileLink = 'sijilli.com/${user.username}';

    return Center(
      child: GestureDetector(
        onTap: _copyProfileLink,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              profileLink,
              style: TextStyle(
                fontSize: 14, // أصغر
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w400,
                fontStyle: FontStyle.italic, // مائل
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.copy,
              size: 14, // أصغر أيضاً
              color: Colors.grey.shade600,
            ),
          ],
        ),
      ),
    );
  }

  // Widget اسم المستخدم
  Widget _buildUserDisplayName() {
    final user = _authService.currentUser;
    if (user?.name == null || user!.name.isEmpty) {
      return const SizedBox.shrink();
    }

    return Center(
      child: Text(
        user.name,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  // Widget السيرة الذاتية
  Widget _buildUserBio() {
    final user = _authService.currentUser;
    if (user == null || user.bio == null || user.bio!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Text(
          user.bio!,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w400,
            height: 1.3,
          ),
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  // Widget مرن لمعلومات المستخدم
  Widget _buildUserInfoSection() {
    final user = _authService.currentUser;
    if (user == null) return const SizedBox(height: 20);

    final hasProfileLink = user.username.isNotEmpty;
    final hasDisplayName = user.name.isNotEmpty;
    final hasBio = user.bio != null && user.bio!.isNotEmpty;

    // إذا لم يكن هناك أي محتوى، أرجع مسافة صغيرة فقط
    if (!hasProfileLink && !hasDisplayName && !hasBio) {
      return const SizedBox(height: 20);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Profile Link
        if (hasProfileLink) ...[
          _buildProfileLink(),
          if (hasDisplayName || hasBio) const SizedBox(height: 4),
        ],

        // User Display Name
        if (hasDisplayName) ...[
          _buildUserDisplayName(),
          if (hasBio) const SizedBox(height: 8),
        ],

        // User Bio
        if (hasBio) _buildUserBio(),

        // مسافة نهائية
        const SizedBox(height: 20),
      ],
    );
  }

  // Widget الأزرار (دائري + كبسولة)
  Widget _buildActionButtons() {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // الزر الدائري للروابط الشخصية
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade300, width: 1),
              color: Colors.white,
            ),
            child: InkWell(
              onTap: _showPersonalLinks,
              borderRadius: BorderRadius.circular(15),
              child: Icon(Icons.link, size: 16, color: Colors.grey.shade600),
            ),
          ),

          const SizedBox(width: 6),

          // كبسولة الأصدقاء
          Container(
            width: 120,
            height: 30,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.grey.shade300, width: 1),
              color: Colors.white,
            ),
            child: InkWell(
              onTap: _showFriends,
              borderRadius: BorderRadius.circular(15),
              child: Center(
                child: Text(
                  'الأصدقاء',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // دالة عرض الروابط الشخصية
  void _showPersonalLinks() {
    final user = _authService.currentUser;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              const Text(
                'الروابط الشخصية',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // Social Links List
              Expanded(child: _buildSocialLinksList(scrollController)),
            ],
          ),
        ),
      ),
    );
  }

  // دالة عرض الأصدقاء
  void _showFriends() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FriendsScreen()),
    );
  }

  // Widget قائمة الروابط الشخصية
  Widget _buildSocialLinksList(ScrollController scrollController) {
    final user = _authService.currentUser;
    if (user == null) {
      return const Center(child: Text('لا يمكن تحميل البيانات'));
    }

    // تحليل الروابط الاجتماعية
    List<Map<String, String>> socialLinks = [];

    if (user.socialLink != null && user.socialLink!.isNotEmpty) {
      try {
        // إذا كانت الروابط في صيغة JSON
        final dynamic linksData = jsonDecode(user.socialLink!);
        if (linksData is Map<String, dynamic>) {
          linksData.forEach((platform, url) {
            if (url != null && url.toString().isNotEmpty) {
              socialLinks.add({
                'platform': platform,
                'url': url.toString(),
                'icon': _getSocialIcon(platform),
              });
            }
          });
        }
      } catch (e) {
        // إذا كانت الروابط في صيغة نص بسيط
        if (user.socialLink!.contains('http')) {
          socialLinks.add({
            'platform': 'رابط',
            'url': user.socialLink!,
            'icon': '🔗',
          });
        }
      }
    }

    if (socialLinks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.link_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'لا توجد روابط شخصية',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'أضف روابطك الاجتماعية في الإعدادات',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      itemCount: socialLinks.length,
      itemBuilder: (context, index) {
        final link = socialLinks[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  link['icon']!,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),
            title: Text(
              link['platform']!,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            subtitle: Text(
              link['url']!,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              icon: Icon(
                Icons.open_in_new,
                color: Colors.blue.shade600,
                size: 20,
              ),
              onPressed: () => _openUrl(link['url']!),
            ),
            onTap: () => _copyToClipboard(link['url']!),
          ),
        );
      },
    );
  }

  // Widget التبويبات
  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: TabBar(
        controller: _tabController,
        labelColor: const Color(0xFF2196F3),
        unselectedLabelColor: Colors.grey.shade600,
        indicatorColor: const Color(0xFF2196F3),
        indicatorWeight: 2,
        labelStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
        tabs: const [
          Tab(text: 'المواعيد'),
          Tab(text: 'المقالات'),
        ],
      ),
    );
  }

  // Widget المحتوى كـ Sliver حسب التبويب المختار
  Widget _buildContentSliver() {
    return _tabController.index == 0
        ? _buildAppointmentsSliver()
        : _buildArticlesSliver();
  }

  // Widget تبويب المواعيد كـ Sliver
  Widget _buildAppointmentsSliver() {
    return SliverList(
      delegate: SliverChildListDelegate([
        // شريط البحث المخفي (يظهر دائماً عند التفعيل)
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: _showSearch ? 60 : 0,
          child: _showSearch ? _buildSearchBar() : const SizedBox.shrink(),
        ),

        // المحتوى حسب حالة المواعيد
        if (_filteredAppointments.isEmpty) ...[
          // رسالة عدم وجود مواعيد أو نتائج بحث
          _buildEmptyState(),
        ] else ...[
          // عرض التاريخ في أعلى المواعيد
          _buildDateHeader(),

          // قائمة المواعيد مع التايم لاين
          ..._buildAppointmentsWithTimeline(),
        ],
      ]),
    );
  }

  // Widget هيدر التاريخ
  Widget _buildDateHeader() {
    // استخدام تاريخ اليوم دائماً مع تصحيح المستخدم الحالي
    final todayDate = DateTime.now();
    final userAdjustment = _authService.currentUser?.hijriAdjustment ?? 0;

    const arabicDays = [
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد',
    ];

    const gregorianMonths = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    const hijriMonths = [
      'محرم',
      'صفر',
      'ربيع 1',
      'ربيع 2',
      'جمادى 1',
      'جمادى 2',
      'رجب',
      'شعبان',
      'رمضان',
      'شوال',
      'ذو القعدة',
      'ذو الحجة',
    ];

    // التاريخ الميلادي (بدون اسم اليوم)
    final gregorianMonth = gregorianMonths[todayDate.month - 1];
    final gregorianDateStr =
        '${todayDate.day} $gregorianMonth ${todayDate.year}';

    // التاريخ الهجري مع التصحيح واسم اليوم
    final dayName = arabicDays[todayDate.weekday - 1];
    final hijriDate = DateConverter.toHijri(
      todayDate,
      adjustment: userAdjustment,
    );
    final hijriMonth = hijriMonths[hijriDate.hMonth - 1];
    final adjustmentText = userAdjustment != 0
        ? '(${userAdjustment > 0 ? '+' : ''}$userAdjustment) '
        : '';
    final hijriDateStr =
        '$adjustmentText$dayName ${hijriDate.hDay} $hijriMonth ${hijriDate.hYear}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // التاريخ الميلادي (على اليمين)
          Text(
            gregorianDateStr,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),

          // التاريخ الهجري (على اليسار) - مع فرض الاتجاه LTR
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              hijriDateStr,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }

  // Widget حالة فارغة (لا توجد مواعيد أو نتائج بحث)
  Widget _buildEmptyState() {
    final bool isSearching = _searchQuery.isNotEmpty;
    final String title = isSearching ? 'لا توجد نتائج للبحث' : 'لا توجد مواعيد';
    final String subtitle = isSearching
        ? 'جرب البحث بكلمات أخرى أو امسح النص لرؤية كل المواعيد'
        : 'ابدأ بإنشاء موعدك الأول';
    final IconData icon = isSearching
        ? Icons.search_off
        : Icons.calendar_today_outlined;

    return Container(
      height: 400, // ارتفاع ثابت للحالة الفارغة
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // أيقونة مختلفة حسب الحالة
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 40, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  // تحميل المقالات
  Future<void> _loadArticles() async {
    setState(() => _isLoadingArticles = true);
    
    try {
      final currentUserId = _authService.currentUser?.id;
      if (currentUserId == null) return;

      final records = await _authService.pb
          .collection('articles')
          .getList(
            page: 1,
            perPage: 50,
            sort: '-created',
            filter: 'is_public = true || author = "$currentUserId"',
          );

      final articles = records.items
          .map((record) => ArticleModel.fromJson(record.toJson()))
          .toList();

      if (mounted) {
        setState(() {
          _articles = articles;
          _isLoadingArticles = false;
        });
      }
    } catch (e) {
      print('❌ خطأ في تحميل المقالات: $e');
      if (mounted) {
        setState(() => _isLoadingArticles = false);
      }
    }
  }

  // Widget تبويب المقالات كـ Sliver
  Widget _buildArticlesSliver() {
    if (_isLoadingArticles) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_articles.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.article_outlined, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'لا توجد مقالات',
                style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              Text(
                'اضغط على + لإضافة مقال جديد',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildListDelegate([
        // هيدر المقالات
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // زر الإضافة على اليسار (LTR)
              IconButton(
                icon: const Icon(Icons.add, color: Color(0xFF2196F3), size: 28),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddArticleScreen(),
                    ),
                  ).then((_) => _loadArticles());
                },
              ),
              // عنوان "المقالات" على اليمين
              const Text(
                'المقالات',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
        // قائمة المقالات
        ..._articles.map((article) => _buildArticleCard(article)),
      ]),
    );
  }

  // بطاقة المقال - قائمة عمودية بسيطة
  Widget _buildArticleCard(ArticleModel article) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ArticleDetailsScreen(article: article),
            ),
          ).then((deleted) {
            if (deleted == true) {
              _loadArticles(); // إعادة تحميل المقالات إذا تم الحذف
            }
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // المحتوى - سطر واحد فقط
              Expanded(
                child: Text(
                  article.content,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(width: 12),
              // أيقونة النقاط الثلاث
              Icon(
                Icons.more_horiz,
                size: 20,
                color: Colors.grey.shade600,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatArticleDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'اليوم';
    } else if (diff.inDays == 1) {
      return 'أمس';
    } else if (diff.inDays < 7) {
      return 'منذ ${diff.inDays} أيام';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  // Widget شريط البحث المخفي
  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        textDirection: TextDirection.rtl,
        decoration: InputDecoration(
          hintText: 'البحث في المواعيد...',
          hintStyle: TextStyle(color: Colors.grey.shade500),
          prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: Colors.grey.shade500),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                      _applyFilters();
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  // تبديل إظهار شريط البحث
  void _toggleSearch() {
    setState(() {
      _showSearch = !_showSearch;
      if (!_showSearch) {
        // عند إخفاء البحث، امسح النص وأظهر كل المواعيد
        _searchController.clear();
        _searchQuery = '';
        _applyFilters();
      } else {
        // عند إظهار البحث، تأكد من تطبيق الفلاتر الحالية
        _applyFilters();
      }
    });
  }

  // تنسيق التاريخ بالشكل المطلوب: ميلادي على اليمين، هجري على اليسار
  String _formatAppointmentDate(AppointmentModel appointment, UserModel? host) {
    // استخدام تصحيح صاحب الموعد (وليس المستخدم الحالي)
    final hostAdjustment = host?.hijriAdjustment ?? 0;
    final appointmentDate = appointment.appointmentDate;

    // أسماء الأيام بالعربية
    const arabicDays = [
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد',
    ];

    // أسماء الشهور الميلادية بالعربية
    const gregorianMonths = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    // أسماء الشهور الهجرية بالعربية
    const hijriMonths = [
      'محرم',
      'صفر',
      'ربيع 1',
      'ربيع 2',
      'جمادى 1',
      'جمادى 2',
      'رجب',
      'شعبان',
      'رمضان',
      'شوال',
      'ذو القعدة',
      'ذو الحجة',
    ];

    // التاريخ الميلادي (على اليمين)
    final dayName = arabicDays[appointmentDate.weekday - 1];
    final gregorianMonth = gregorianMonths[appointmentDate.month - 1];
    final gregorianDateStr =
        '$dayName ${appointmentDate.day} $gregorianMonth ${appointmentDate.year}';

    // التاريخ الهجري (على اليسار) مع التصحيح
    final hijriDate = DateConverter.toHijri(
      appointmentDate,
      adjustment: hostAdjustment,
    );
    final hijriMonth = hijriMonths[hijriDate.hMonth - 1];
    final adjustmentText = hostAdjustment != 0
        ? '(${hostAdjustment > 0 ? '+' : ''}$hostAdjustment) '
        : '';
    final hijriDateStr =
        '$adjustmentText${hijriDate.hDay} $hijriMonth ${hijriDate.hYear}';

    return '$gregorianDateStr\n$hijriDateStr';
  }

  // تنسيق التاريخ للتايم لاين: عدد الأيام على اليسار، ميلادي على اليمين
  String _formatTimelineDate(DateTime appointmentDate, int daysDifference) {
    // أسماء الأيام بالعربية
    const arabicDays = [
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد',
    ];

    // أسماء الشهور الميلادية بالعربية
    const gregorianMonths = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    // التاريخ الميلادي (على اليمين)
    final dayName = arabicDays[appointmentDate.weekday - 1];
    final gregorianMonth = gregorianMonths[appointmentDate.month - 1];
    final gregorianDateStr =
        '$dayName ${appointmentDate.day} $gregorianMonth ${appointmentDate.year}';

    // عدد الأيام (على اليسار)
    final daysText = daysDifference == 1 ? 'يوم واحد' : '$daysDifference أيام';

    return '$gregorianDateStr\n$daysText';
  }

  // بناء قائمة المواعيد مع التايم لاين
  List<Widget> _buildAppointmentsWithTimeline() {
    List<Widget> widgets = [];

    for (int i = 0; i < _filteredAppointments.length; i++) {
      final appointment = _filteredAppointments[i];

      // إضافة فاصل التايم لاين إذا تغير التاريخ
      if (i > 0) {
        final previousAppointment = _filteredAppointments[i - 1];

        // مقارنة التاريخ فقط (بدون الوقت)
        final currentDate = DateTime(
          appointment.appointmentDate.year,
          appointment.appointmentDate.month,
          appointment.appointmentDate.day,
        );
        final previousDate = DateTime(
          previousAppointment.appointmentDate.year,
          previousAppointment.appointmentDate.month,
          previousAppointment.appointmentDate.day,
        );

        // إذا تغير التاريخ
        if (!currentDate.isAtSameMomentAs(previousDate)) {
          final daysDifference = currentDate.difference(previousDate).inDays;
          widgets.add(
            _buildTimelineSeparator(
              appointment.appointmentDate,
              daysDifference,
            ),
          );
        }
      }

      // إضافة بطاقة الموعد
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          child: _buildAppointmentCard(appointment),
        ),
      );
    }

    return widgets;
  }

  // بناء فاصل التايم لاين
  Widget _buildTimelineSeparator(DateTime appointmentDate, int daysDifference) {
    final formattedDate = _formatTimelineDate(appointmentDate, daysDifference);
    final lines = formattedDate.split('\n');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // التاريخ الميلادي (على اليمين)
          Text(
            lines[0], // التاريخ الميلادي
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade400, // تفتيح أكثر
            ),
          ),

          // عدد الأيام (على اليسار)
          Text(
            lines[1], // عدد الأيام
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade400, // تفتيح أكثر
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Stack(
          children: [
            // المحتوى الرئيسي
            CustomScrollView(
              slivers: [
                // Header Section (Profile + Info + Buttons)
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      // مسافة للشريط العلوي
                      const SizedBox(height: 48),

                      // أزرار التحكم والصورة الرئيسية
                      Container(
                        padding: const EdgeInsets.only(top: 8, bottom: 12),
                        child: _buildUserProfilePicture(),
                      ),

                      // User Info Section (Flexible)
                      _buildUserInfoSection(),

                      // Action Buttons (دائري + كبسولة)
                      _buildActionButtons(),
                      const SizedBox(height: 20),

                      // Tab Bar
                      _buildTabBar(),
                    ],
                  ),
                ),

                // Content Section (Based on selected tab)
                _buildContentSliver(),
              ],
            ),

            // الشريط العلوي الشفاف
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // قائمة الإجراءات في الشريط العلوي
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        size: 24,
                        color: Colors.grey.shade700,
                      ),
                      onSelected: _handleMenuAction,
                      itemBuilder: (context) => _buildMenuItems(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // دالة الحصول على أيقونة المنصة الاجتماعية
  String _getSocialIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'twitter':
      case 'x':
        return '🐦';
      case 'instagram':
        return '📷';
      case 'facebook':
        return '📘';
      case 'linkedin':
        return '💼';
      case 'youtube':
        return '📺';
      case 'tiktok':
        return '🎵';
      case 'snapchat':
        return '👻';
      case 'telegram':
        return '✈️';
      case 'whatsapp':
        return '💬';
      case 'github':
        return '🐙';
      case 'website':
      case 'site':
        return '🌐';
      default:
        return '🔗';
    }
  }

  // دالة فتح الرابط (نسخ للحافظة)
  void _openUrl(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم نسخ الرابط: $url'),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'فتح',
            textColor: Colors.white,
            onPressed: () {
              // يمكن إضافة url_launcher لاحقاً
            },
          ),
        ),
      );
    }
  }

  // دالة نسخ الرابط
  void _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم نسخ الرابط: $text'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildAppointmentCard(AppointmentModel appointment) {
    final guests = _appointmentGuests[appointment.id] ?? [];
    final invitations = _appointmentInvitations[appointment.id] ?? [];
    final host = _appointmentHosts[appointment.id]; // معلومات المنشئ/المضيف
    final now = DateTime.now();
    final isPastAppointment =
        appointment.appointmentDate.isBefore(now) &&
        !_isAppointmentActive(appointment, now);
    
    // الحصول على خصوصية نسخة المستخدم من participantsStatus
    final currentUserId = _authService.currentUser?.id;
    final userStatus = _participantsStatus[appointment.id]?[currentUserId ?? ''];
    final userPrivacy = userStatus?.privacy;

    return Opacity(
      opacity: isPastAppointment ? 0.6 : 1.0, // بطاقات فائتة باهتة
      child: AppointmentCard(
        appointment: appointment,
        guests: guests,
        invitations: invitations,
        host: host, // تمرير معلومات المنشئ
        participantsStatus:
            _participantsStatus[appointment.id], // تمرير حالات المشاركين
        userPrivacy: userPrivacy, // تمرير خصوصية نسخة المستخدم
        isPastAppointment: isPastAppointment, // تمرير حالة الموعد الفائت
        onTap: () {
          // التنقل لصفحة تفاصيل الموعد
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AppointmentDetailsScreen(
                appointment: appointment,
                guests: guests,
                invitations: invitations,
                host: host,
                participantsStatus: _participantsStatus[appointment.id],
              ),
            ),
          ).then((result) {
            // إذا تم حذف أو أرشفة الموعد، نحذفه من القائمة فوراً
            if (result == true) {
              setState(() {
                _appointments.removeWhere((a) => a.id == appointment.id);
                _applyFilters();
              });
              // تحديث الكاش
              _saveAppointmentsToCache(_appointments);
              // إعادة تحميل من السيرفر في الخلفية
              _loadAppointments();
            }
          });
        },
        onPrivacyChanged: (newPrivacy) {
          // تحديث خصوصية نسخة المستخدم في participantsStatus فوراً
          final currentUserId = _authService.currentUser?.id;
          if (currentUserId != null && _participantsStatus[appointment.id] != null) {
            final userStatus = _participantsStatus[appointment.id]![currentUserId];
            if (userStatus != null) {
              setState(() {
                // تحديث الخصوصية في participantsStatus
                _participantsStatus[appointment.id]![currentUserId] = userStatus.copyWith(
                  privacy: newPrivacy,
                );
              });
              
              print('✅ تم تحديث خصوصية نسخة المستخدم إلى: $newPrivacy');
            }
          }
        },
        onGuestsChanged: (selectedGuestIds) async {
          // تحديث دعوات الضيوف
          await _updateAppointmentGuests(appointment.id, selectedGuestIds);
        },
      ),
    );
  }

  // تحديث ضيوف الموعد
  Future<void> _updateAppointmentGuests(
    String appointmentId,
    List<String> selectedGuestIds,
  ) async {
    try {
      // الحصول على الدعوات الحالية
      final currentInvitations = _appointmentInvitations[appointmentId] ?? [];
      final currentGuestIds = currentInvitations
          .map((inv) => inv.guestId)
          .toSet();
      final newGuestIds = selectedGuestIds.toSet();

      // إضافة دعوات جديدة
      for (final guestId in newGuestIds.difference(currentGuestIds)) {
        await _authService.pb
            .collection(AppConstants.invitationsCollection)
            .create(
              body: {
                'appointment': appointmentId,
                'guest': guestId,
                'status': 'invited',
              },
            );
      }

      // حذف الدعوات المحذوفة
      for (final guestId in currentGuestIds.difference(newGuestIds)) {
        final invitation = currentInvitations.firstWhere(
          (inv) => inv.guestId == guestId,
        );
        await _authService.pb
            .collection(AppConstants.invitationsCollection)
            .delete(invitation.id);
      }

      // إعادة تحميل الضيوف والدعوات
      await _loadGuestsAndInvitations(_appointments);

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('خطأ في تحديث ضيوف الموعد: $e');
    }
  }

  // مزامنة المواعيد المحفوظة أوفلاين
  Future<void> _syncOfflineAppointments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final offlineAppointments =
          prefs.getStringList('offline_appointments') ?? [];
      final offlineInvitations =
          prefs.getStringList('offline_invitations') ?? [];

      if (offlineAppointments.isEmpty) return;

      print('🔄 بدء مزامنة ${offlineAppointments.length} موعد محفوظ أوفلاين');

      List<String> syncedAppointments = [];
      List<String> syncedInvitations = [];

      // مزامنة المواعيد
      for (String appointmentJson in offlineAppointments) {
        try {
          final appointmentData = jsonDecode(appointmentJson);
          final tempId = appointmentData['temp_id'];

          // إزالة البيانات المؤقتة
          appointmentData.remove('id');
          appointmentData.remove('temp_id');
          appointmentData.remove('sync_status');
          appointmentData.remove('created_offline');

          // رفع الموعد للخادم
          final record = await _authService.pb
              .collection(AppConstants.appointmentsCollection)
              .create(body: appointmentData);

          print('✅ تم رفع الموعد: ${appointmentData['title']}');

          // البحث عن الدعوات المرتبطة بهذا الموعد
          final relatedInvitations = offlineInvitations.where((invJson) {
            final invData = jsonDecode(invJson);
            return invData['appointment_temp_id'] == tempId;
          }).toList();

          // رفع الدعوات
          for (String invJson in relatedInvitations) {
            try {
              final invData = jsonDecode(invJson);
              final guests = List<String>.from(invData['guests']);

              for (String guestId in guests) {
                await _authService.pb
                    .collection(AppConstants.invitationsCollection)
                    .create(
                      body: {
                        'appointment': record.id,
                        'guest': guestId,
                        'status': 'invited',
                      },
                    );
              }

              syncedInvitations.add(invJson);
              print('✅ تم رفع دعوات الموعد');
            } catch (e) {
              print('❌ خطأ في رفع دعوة: $e');
            }
          }

          syncedAppointments.add(appointmentJson);
        } catch (e) {
          print('❌ خطأ في رفع موعد: $e');
        }
      }

      // إزالة المواعيد المرفوعة من التخزين المحلي
      if (syncedAppointments.isNotEmpty) {
        final remainingAppointments = offlineAppointments
            .where((apt) => !syncedAppointments.contains(apt))
            .toList();
        await prefs.setStringList(
          'offline_appointments',
          remainingAppointments,
        );

        final remainingInvitations = offlineInvitations
            .where((inv) => !syncedInvitations.contains(inv))
            .toList();
        await prefs.setStringList('offline_invitations', remainingInvitations);

        print('🎉 تم رفع ${syncedAppointments.length} موعد بنجاح');

        // إعادة تحميل المواعيد لعرض البيانات المحدثة
        _loadAppointments();
      }
    } catch (e) {
      print('❌ خطأ في مزامنة المواعيد: $e');
    }
  }

  // بناء عناصر قائمة الإجراءات
  List<PopupMenuEntry<String>> _buildMenuItems() {
    final isAdmin = _authService.currentUser?.role == 'admin';
    List<PopupMenuEntry<String>> items = [];

    // زر البحث (يظهر فقط في تبويب المواعيد)
    if (_tabController.index == 0) {
      items.add(
        PopupMenuItem<String>(
          value: 'search',
          child: Row(
            children: [
              Icon(
                _showSearch ? Icons.search_off : Icons.search,
                size: 20,
                color: _showSearch
                    ? const Color(0xFF2196F3)
                    : Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
              Text(_showSearch ? 'إخفاء البحث' : 'إظهار البحث'),
            ],
          ),
        ),
      );
    }

    // زر الأرشيف
    items.add(
      const PopupMenuItem<String>(
        value: 'archive',
        child: Row(
          children: [
            Icon(
              Icons.archive_outlined,
              size: 20,
              color: Colors.grey,
            ),
            SizedBox(width: 8),
            Text('الأرشيف'),
          ],
        ),
      ),
    );

    // تبديل المستخدمين (للأدمن فقط)
    if (isAdmin) {
      items.add(
        const PopupMenuItem<String>(
          value: 'switch_user',
          child: Row(
            children: [
              Icon(Icons.switch_account, size: 20, color: Colors.orange),
              SizedBox(width: 8),
              Text('تبديل المستخدم'),
            ],
          ),
        ),
      );
    }

    // تسجيل الخروج
    items.add(
      const PopupMenuItem<String>(
        value: 'logout',
        child: Row(
          children: [
            Icon(Icons.logout, size: 20, color: Colors.red),
            SizedBox(width: 8),
            Text('تسجيل الخروج'),
          ],
        ),
      ),
    );

    return items;
  }

  // معالجة إجراءات القائمة
  void _handleMenuAction(String action) {
    switch (action) {
      case 'search':
        _toggleSearch();
        break;
      case 'archive':
        _navigateToArchive();
        break;
      case 'switch_user':
        _showSwitchUserDialog();
        break;
      case 'logout':
        _showLogoutDialog();
        break;
    }
  }

  // الانتقال لصفحة المسودات
  void _navigateToDrafts() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DraftFormsScreen()),
    );
  }

  // إظهار حوار تبديل المستخدم
  void _showSwitchUserDialog() async {
    final savedUsers = await _getSavedUsers();

    if (savedUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا توجد حسابات محفوظة أخرى'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تبديل المستخدم'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('اختر حساباً للتبديل إليه:'),
            const SizedBox(height: 16),
            ...savedUsers.map(
              (user) => ListTile(
                leading: CircleAvatar(
                  child: Text(user['name']?.substring(0, 1) ?? '؟'),
                ),
                title: Text(user['name'] ?? 'مستخدم'),
                subtitle: Text(user['username'] ?? ''),
                onTap: () {
                  Navigator.of(context).pop();
                  _switchToUser(user);
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );
  }

  // إظهار حوار تسجيل الخروج
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل تريد تسجيل الخروج من حسابك؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _logout();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'تسجيل الخروج',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // الحصول على المستخدمين المحفوظين
  Future<List<Map<String, dynamic>>> _getSavedUsers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUsersJson = prefs.getStringList('saved_users') ?? [];

      return savedUsersJson
          .map((userJson) => jsonDecode(userJson) as Map<String, dynamic>)
          .where(
            (user) => user['id'] != _authService.currentUser?.id,
          ) // استبعاد المستخدم الحالي
          .toList();
    } catch (e) {
      print('خطأ في جلب المستخدمين المحفوظين: $e');
      return [];
    }
  }

  // التبديل إلى مستخدم آخر
  Future<void> _switchToUser(Map<String, dynamic> userData) async {
    try {
      // حفظ بيانات المستخدم الحالي قبل التبديل
      await _saveCurrentUser();

      // تسجيل الدخول بالمستخدم الجديد
      await _authService.loginWithSavedData(userData);

      // إعادة تحميل البيانات
      _loadAppointments();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم التبديل إلى ${userData['name']}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في التبديل: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // حفظ بيانات المستخدم الحالي
  Future<void> _saveCurrentUser() async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) return;

      final prefs = await SharedPreferences.getInstance();
      final savedUsersJson = prefs.getStringList('saved_users') ?? [];

      // تحويل إلى قائمة من الخرائط
      final savedUsers = savedUsersJson
          .map((userJson) => jsonDecode(userJson) as Map<String, dynamic>)
          .toList();

      // إزالة المستخدم الحالي إذا كان موجوداً
      savedUsers.removeWhere((user) => user['id'] == currentUser.id);

      // إضافة المستخدم الحالي في المقدمة
      savedUsers.insert(0, currentUser.toJson());

      // الاحتفاظ بآخر 5 مستخدمين فقط
      if (savedUsers.length > 5) {
        savedUsers.removeRange(5, savedUsers.length);
      }

      // حفظ القائمة المحدثة
      final updatedUsersJson = savedUsers
          .map((user) => jsonEncode(user))
          .toList();
      await prefs.setStringList('saved_users', updatedUsersJson);
    } catch (e) {
      print('خطأ في حفظ المستخدم الحالي: $e');
    }
  }

  // تسجيل الخروج
  Future<void> _logout() async {
    try {
      // حفظ بيانات المستخدم الحالي قبل الخروج
      await _saveCurrentUser();

      // تسجيل الخروج
      await _authService.logout();

      // الانتقال لصفحة تسجيل الدخول
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في تسجيل الخروج: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // الانتقال إلى صفحة الأرشيف
  void _navigateToArchive() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ArchiveScreen(),
      ),
    );
  }
}
