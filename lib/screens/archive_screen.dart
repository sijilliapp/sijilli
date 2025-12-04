import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../services/auth_service.dart';
import '../services/user_appointment_status_service.dart';
import '../models/appointment_model.dart';
import '../models/user_model.dart';
import '../models/invitation_model.dart';
import '../models/user_appointment_status_model.dart';
import '../config/constants.dart';
import '../widgets/appointment_card.dart';
import 'appointment_details_screen.dart';

class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key});

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();

  // 🔄 دالة ثابتة للإعداد المسبق (prefetch) - يمكن استدعاؤها من أي مكان
  static Future<void> prefetchArchiveData(AuthService authService) async {
    try {
      final currentUserId = authService.currentUser?.id;
      if (currentUserId == null) return;

      print('🔄 بدء الإعداد المسبق لبيانات الأرشيف...');

      final statusService = UserAppointmentStatusService(authService);

      // 1. جلب المواعيد المؤرشفة
      final archivedIds = await statusService.getArchivedAppointmentIdsForCurrentUser();
      
      // 2. جلب المواعيد المنتهية
      final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));
      
      List<AppointmentModel> archived = [];
      List<AppointmentModel> expired = [];

      if (archivedIds.isNotEmpty) {
        final appointmentFilter = archivedIds.map((id) => 'id = "$id"').join(' || ');
        final archivedRecords = await authService.pb
            .collection(AppConstants.appointmentsCollection)
            .getFullList(filter: '($appointmentFilter)');

        archived = archivedRecords
            .map((record) => AppointmentModel.fromJson(record.toJson()))
            .toList();
      }

      // جلب المواعيد النشطة المنتهية
      final activeIds = await statusService.getActiveAppointmentIdsForCurrentUser();
      if (activeIds.isNotEmpty) {
        final appointmentFilter = activeIds.map((id) => 'id = "$id"').join(' || ');
        final activeRecords = await authService.pb
            .collection(AppConstants.appointmentsCollection)
            .getFullList(filter: '($appointmentFilter)');

        for (final record in activeRecords) {
          final appointment = AppointmentModel.fromJson(record.toJson());
          final duration = appointment.duration ?? 45;
          final endDate = appointment.appointmentDate.add(Duration(minutes: duration));
          
          if (endDate.isBefore(threeDaysAgo)) {
            expired.add(appointment);
          }
        }
      }

      // جلب تفاصيل المواعيد
      final allAppointments = [...archived, ...expired];
      final appointmentHosts = <String, UserModel>{};
      final appointmentGuests = <String, List<UserModel>>{};
      final appointmentInvitations = <String, List<InvitationModel>>{};

      for (final appointment in allAppointments) {
        // جلب المنشئ
        try {
          final hostRecord = await authService.pb
              .collection(AppConstants.usersCollection)
              .getOne(appointment.hostId);
          appointmentHosts[appointment.id] = UserModel.fromJson(hostRecord.toJson());
        } catch (e) {
          // تجاهل أخطاء الشبكة الشائعة
          if (!e.toString().contains('isAbort: true')) {
            print('خطأ في جلب المنشئ: $e');
          }
        }

        // جلب الضيوف والدعوات
        try {
          final invitations = await authService.pb
              .collection(AppConstants.invitationsCollection)
              .getFullList(filter: 'appointment = "${appointment.id}"');

          appointmentInvitations[appointment.id] = invitations
              .map((record) => InvitationModel.fromJson(record.toJson()))
              .toList();

          final guestIds = invitations.map((inv) => inv.data['guest'] as String).toList();
          if (guestIds.isNotEmpty) {
            final guestsFilter = guestIds.map((id) => 'id = "$id"').join(' || ');
            final guestsRecords = await authService.pb
                .collection(AppConstants.usersCollection)
                .getFullList(filter: '($guestsFilter)');

            appointmentGuests[appointment.id] = guestsRecords
                .map((record) => UserModel.fromJson(record.toJson()))
                .toList();
          }
        } catch (e) {
          // تجاهل أخطاء الشبكة الشائعة
          if (!e.toString().contains('isAbort: true')) {
            print('خطأ في جلب الضيوف: $e');
          }
        }
      }

      // حفظ في الكاش
      final prefs = await SharedPreferences.getInstance();

      final archivedJson = jsonEncode(archived.map((a) => a.toJson()).toList());
      await prefs.setString('archive_archived_$currentUserId', archivedJson);

      final expiredJson = jsonEncode(expired.map((a) => a.toJson()).toList());
      await prefs.setString('archive_expired_$currentUserId', expiredJson);

      final hostsJson = jsonEncode(
        appointmentHosts.map((key, value) => MapEntry(key, value.toJson())),
      );
      await prefs.setString('archive_hosts_$currentUserId', hostsJson);

      final guestsJson = jsonEncode(
        appointmentGuests.map(
          (key, value) => MapEntry(key, value.map((g) => g.toJson()).toList()),
        ),
      );
      await prefs.setString('archive_guests_$currentUserId', guestsJson);

      final invitationsJson = jsonEncode(
        appointmentInvitations.map(
          (key, value) => MapEntry(key, value.map((i) => i.toJson()).toList()),
        ),
      );
      await prefs.setString('archive_invitations_$currentUserId', invitationsJson);

      print('✅ تم الإعداد المسبق لبيانات الأرشيف وحفظها في الكاش');
    } catch (e) {
      print('❌ خطأ في الإعداد المسبق للأرشيف: $e');
    }
  }
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  final AuthService _authService = AuthService();
  late final UserAppointmentStatusService _statusService;

  List<AppointmentModel> _archivedAppointments = [];
  List<AppointmentModel> _expiredAppointments = [];
  Map<String, List<UserModel>> _appointmentGuests = {};
  Map<String, List<InvitationModel>> _appointmentInvitations = {};
  Map<String, UserModel> _appointmentHosts = {};
  Map<String, Map<String, UserAppointmentStatusModel>> _participantsStatus = {};

  bool _isLoading = true;
  bool _isAscending = false; // ترتيب تنازلي افتراضياً (الأحدث أولاً)

  @override
  void initState() {
    super.initState();
    _statusService = UserAppointmentStatusService(_authService);
    _loadArchivedAppointments();
  }

  Future<void> _loadArchivedAppointments() async {
    if (!mounted) return;

    // تحميل من الكاش أولاً
    await _loadFromCache();
    
    // إذا كان هناك كاش، نعرضه ونحدث في الخلفية
    final hasCache = _archivedAppointments.isNotEmpty || _expiredAppointments.isNotEmpty;
    
    if (!hasCache) {
      setState(() => _isLoading = true);
    }

    try {
      final currentUserId = _authService.currentUser?.id;
      if (currentUserId == null) return;

      // 1. جلب المواعيد المؤرشفة
      final archivedIds = await _statusService.getArchivedAppointmentIdsForCurrentUser();
      
      // 2. جلب المواعيد المنتهية (مضى عليها 3 أيام)
      final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));
      
      List<AppointmentModel> archived = [];
      List<AppointmentModel> expired = [];

      if (archivedIds.isNotEmpty) {
        final appointmentFilter = archivedIds.map((id) => 'id = "$id"').join(' || ');
        final archivedRecords = await _authService.pb
            .collection(AppConstants.appointmentsCollection)
            .getFullList(filter: '($appointmentFilter)');

        archived = archivedRecords
            .map((record) => AppointmentModel.fromJson(record.toJson()))
            .toList();
      }

      // جلب المواعيد النشطة المنتهية
      final activeIds = await _statusService.getActiveAppointmentIdsForCurrentUser();
      if (activeIds.isNotEmpty) {
        final appointmentFilter = activeIds.map((id) => 'id = "$id"').join(' || ');
        final activeRecords = await _authService.pb
            .collection(AppConstants.appointmentsCollection)
            .getFullList(filter: '($appointmentFilter)');

        for (final record in activeRecords) {
          final appointment = AppointmentModel.fromJson(record.toJson());
          final duration = appointment.duration ?? 45;
          final endDate = appointment.appointmentDate.add(Duration(minutes: duration));
          
          // إذا انتهى الموعد منذ أكثر من 3 أيام
          if (endDate.isBefore(threeDaysAgo)) {
            expired.add(appointment);
          }
        }
      }

      // عرض المواعيد فوراً
      if (mounted) {
        setState(() {
          _archivedAppointments = archived;
          _expiredAppointments = expired;
          _sortAppointments();
          _isLoading = false;
        });
      }

      // جلب تفاصيل المواعيد في الخلفية
      final allAppointments = [...archived, ...expired];
      _loadAppointmentDetails(allAppointments).then((_) {
        if (mounted) {
          setState(() {});
          // حفظ في الكاش بعد جلب التفاصيل
          _saveToCache();
        }
      });
    } catch (e) {
      print('❌ خطأ في تحميل الأرشيف: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadAppointmentDetails(List<AppointmentModel> appointments) async {
    for (final appointment in appointments) {
      // جلب المنشئ
      try {
        final hostRecord = await _authService.pb
            .collection(AppConstants.usersCollection)
            .getOne(appointment.hostId);
        _appointmentHosts[appointment.id] = UserModel.fromJson(hostRecord.toJson());
      } catch (e) {
        print('خطأ في جلب المنشئ: $e');
      }

      // جلب الضيوف والدعوات
      try {
        final invitations = await _authService.pb
            .collection(AppConstants.invitationsCollection)
            .getFullList(filter: 'appointment = "${appointment.id}"');

        _appointmentInvitations[appointment.id] = invitations
            .map((record) => InvitationModel.fromJson(record.toJson()))
            .toList();

        // جلب بيانات الضيوف
        final guestIds = invitations.map((inv) => inv.data['guest'] as String).toList();
        if (guestIds.isNotEmpty) {
          final guestsFilter = guestIds.map((id) => 'id = "$id"').join(' || ');
          final guestsRecords = await _authService.pb
              .collection(AppConstants.usersCollection)
              .getFullList(filter: '($guestsFilter)');

          _appointmentGuests[appointment.id] = guestsRecords
              .map((record) => UserModel.fromJson(record.toJson()))
              .toList();
        }
      } catch (e) {
        print('خطأ في جلب الضيوف: $e');
      }
    }
  }

  void _sortAppointments() {
    final comparator = _isAscending
        ? (AppointmentModel a, AppointmentModel b) => a.appointmentDate.compareTo(b.appointmentDate)
        : (AppointmentModel a, AppointmentModel b) => b.appointmentDate.compareTo(a.appointmentDate);

    _archivedAppointments.sort(comparator);
    _expiredAppointments.sort(comparator);
  }

  void _toggleSortOrder() {
    setState(() {
      _isAscending = !_isAscending;
      _sortAppointments();
    });
  }

  @override
  Widget build(BuildContext context) {
    // ✅ تحديد لون الخلفية حسب نوع المحتوى
    final hasExpired = _expiredAppointments.isNotEmpty;
    final hasArchived = _archivedAppointments.isNotEmpty;
    
    Color backgroundColor;
    if (hasExpired && !hasArchived) {
      // فقط منتهية - خلفية حمراء فاتحة جداً
      backgroundColor = const Color(0xFFFFF5F5);
    } else if (hasArchived && !hasExpired) {
      // فقط مؤرشفة - خلفية رمادية فاتحة
      backgroundColor = const Color(0xFFF5F5F5);
    } else {
      // كلاهما أو لا شيء - خلفية عادية
      backgroundColor = Colors.grey.shade50;
    }
    
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'الأرشيف',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(
                _isAscending ? Icons.arrow_upward : Icons.arrow_downward,
                color: const Color(0xFF2196F3),
              ),
              onPressed: _toggleSortOrder,
              tooltip: _isAscending ? 'ترتيب تنازلي' : 'ترتيب تصاعدي',
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _archivedAppointments.isEmpty && _expiredAppointments.isEmpty
                ? _buildEmptyState()
                : _buildAppointmentsList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.archive_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد مواعيد مؤرشفة',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'المواعيد المؤرشفة والمنتهية ستظهر هنا',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentsList() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // المواعيد المؤرشفة
        if (_archivedAppointments.isNotEmpty) ...[
          _buildSectionHeader('المواعيد المؤرشفة', _archivedAppointments.length),
          const SizedBox(height: 12),
          ..._archivedAppointments.map((appointment) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildAppointmentCard(appointment, isArchived: true),
              )),
          const SizedBox(height: 24),
        ],

        // المواعيد المنتهية
        if (_expiredAppointments.isNotEmpty) ...[
          _buildSectionHeader('المواعيد المنتهية (أكثر من 3 أيام)', _expiredAppointments.length),
          const SizedBox(height: 12),
          ..._expiredAppointments.map((appointment) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildAppointmentCard(appointment, isExpired: true),
              )),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            count.toString(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppointmentCard(AppointmentModel appointment, {bool isArchived = false, bool isExpired = false}) {
    return AppointmentCard(
      appointment: appointment,
      guests: _appointmentGuests[appointment.id] ?? [],
      invitations: _appointmentInvitations[appointment.id] ?? [],
      host: _appointmentHosts[appointment.id],
      participantsStatus: _participantsStatus[appointment.id],
      isPastAppointment: true, // كل المواعيد في الأرشيف تعتبر ماضية
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AppointmentDetailsScreen(
              appointment: appointment,
              guests: _appointmentGuests[appointment.id] ?? [],
              invitations: _appointmentInvitations[appointment.id] ?? [],
              host: _appointmentHosts[appointment.id],
              participantsStatus: _participantsStatus[appointment.id],
              isFromArchive: true,
            ),
          ),
        ).then((_) => _loadArchivedAppointments());
      },
    );
  }

  // 🔄 تحديث البيانات في الخلفية (بدون blocking)
  Future<void> _updateArchiveInBackground() async {
    try {
      final currentUserId = _authService.currentUser?.id;
      if (currentUserId == null) return;

      print('🔄 تحديث الأرشيف في الخلفية...');

      // 1. جلب المواعيد المؤرشفة
      final archivedIds = await _statusService.getArchivedAppointmentIdsForCurrentUser();
      
      // 2. جلب المواعيد المنتهية
      final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));
      
      List<AppointmentModel> archived = [];
      List<AppointmentModel> expired = [];

      if (archivedIds.isNotEmpty) {
        final appointmentFilter = archivedIds.map((id) => 'id = "$id"').join(' || ');
        final archivedRecords = await _authService.pb
            .collection(AppConstants.appointmentsCollection)
            .getFullList(filter: '($appointmentFilter)');

        archived = archivedRecords
            .map((record) => AppointmentModel.fromJson(record.toJson()))
            .toList();
      }

      final activeIds = await _statusService.getActiveAppointmentIdsForCurrentUser();
      if (activeIds.isNotEmpty) {
        final appointmentFilter = activeIds.map((id) => 'id = "$id"').join(' || ');
        final activeRecords = await _authService.pb
            .collection(AppConstants.appointmentsCollection)
            .getFullList(filter: '($appointmentFilter)');

        for (final record in activeRecords) {
          final appointment = AppointmentModel.fromJson(record.toJson());
          final duration = appointment.duration ?? 45;
          final endDate = appointment.appointmentDate.add(Duration(minutes: duration));
          
          if (endDate.isBefore(threeDaysAgo)) {
            expired.add(appointment);
          }
        }
      }

      // جلب التفاصيل
      final allAppointments = [...archived, ...expired];
      await _loadAppointmentDetails(allAppointments);

      if (mounted) {
        setState(() {
          _archivedAppointments = archived;
          _expiredAppointments = expired;
          _sortAppointments();
        });
        
        await _saveToCache();
        print('✅ تم تحديث الأرشيف في الخلفية');
      }
    } catch (e) {
      print('❌ خطأ في تحديث الأرشيف في الخلفية: $e');
    }
  }

  // 📱 تحميل البيانات من الكاش
  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUserId = _authService.currentUser?.id;
      if (currentUserId == null) {
        print('⚠️ لا يوجد مستخدم مسجل دخول');
        return;
      }

      print('📱 محاولة تحميل بيانات الأرشيف من الكاش للمستخدم: $currentUserId');

      // تحميل المواعيد المؤرشفة
      final archivedJson = prefs.getString('archive_archived_$currentUserId');
      if (archivedJson != null) {
        final List<dynamic> archivedList = jsonDecode(archivedJson);
        _archivedAppointments = archivedList
            .map((json) => AppointmentModel.fromJson(json))
            .toList();
        print('✅ تم تحميل ${_archivedAppointments.length} موعد مؤرشف من الكاش');
      } else {
        print('⚠️ لا توجد مواعيد مؤرشفة في الكاش');
      }

      // تحميل المواعيد المنتهية
      final expiredJson = prefs.getString('archive_expired_$currentUserId');
      if (expiredJson != null) {
        final List<dynamic> expiredList = jsonDecode(expiredJson);
        _expiredAppointments = expiredList
            .map((json) => AppointmentModel.fromJson(json))
            .toList();
        print('✅ تم تحميل ${_expiredAppointments.length} موعد منتهي من الكاش');
      } else {
        print('⚠️ لا توجد مواعيد منتهية في الكاش');
      }

      // تحميل المنشئين
      final hostsJson = prefs.getString('archive_hosts_$currentUserId');
      if (hostsJson != null) {
        final Map<String, dynamic> hostsMap = jsonDecode(hostsJson);
        _appointmentHosts = hostsMap.map(
          (key, value) => MapEntry(key, UserModel.fromJson(value)),
        );
        print('✅ تم تحميل ${_appointmentHosts.length} منشئ من الكاش');
      }

      // تحميل الضيوف
      final guestsJson = prefs.getString('archive_guests_$currentUserId');
      if (guestsJson != null) {
        final Map<String, dynamic> guestsMap = jsonDecode(guestsJson);
        _appointmentGuests = guestsMap.map(
          (key, value) => MapEntry(
            key,
            (value as List).map((json) => UserModel.fromJson(json)).toList(),
          ),
        );
        print('✅ تم تحميل ضيوف ${_appointmentGuests.length} موعد من الكاش');
      }

      // تحميل الدعوات
      final invitationsJson = prefs.getString('archive_invitations_$currentUserId');
      if (invitationsJson != null) {
        final Map<String, dynamic> invitationsMap = jsonDecode(invitationsJson);
        _appointmentInvitations = invitationsMap.map(
          (key, value) => MapEntry(
            key,
            (value as List).map((json) => InvitationModel.fromJson(json)).toList(),
          ),
        );
        print('✅ تم تحميل دعوات ${_appointmentInvitations.length} موعد من الكاش');
      }

      if (mounted) setState(() {});
      print('✅ تم تحميل بيانات الأرشيف من الكاش بنجاح');
    } catch (e) {
      print('❌ خطأ في تحميل الكاش: $e');
    }
  }

  // 💾 حفظ البيانات في الكاش
  Future<void> _saveToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUserId = _authService.currentUser?.id;
      if (currentUserId == null) return;

      // حفظ المواعيد المؤرشفة
      final archivedJson = jsonEncode(
        _archivedAppointments.map((a) => a.toJson()).toList(),
      );
      await prefs.setString('archive_archived_$currentUserId', archivedJson);

      // حفظ المواعيد المنتهية
      final expiredJson = jsonEncode(
        _expiredAppointments.map((a) => a.toJson()).toList(),
      );
      await prefs.setString('archive_expired_$currentUserId', expiredJson);

      // حفظ المنشئين
      final hostsJson = jsonEncode(
        _appointmentHosts.map((key, value) => MapEntry(key, value.toJson())),
      );
      await prefs.setString('archive_hosts_$currentUserId', hostsJson);

      // حفظ الضيوف
      final guestsJson = jsonEncode(
        _appointmentGuests.map(
          (key, value) => MapEntry(key, value.map((g) => g.toJson()).toList()),
        ),
      );
      await prefs.setString('archive_guests_$currentUserId', guestsJson);

      // حفظ الدعوات
      final invitationsJson = jsonEncode(
        _appointmentInvitations.map(
          (key, value) => MapEntry(key, value.map((i) => i.toJson()).toList()),
        ),
      );
      await prefs.setString('archive_invitations_$currentUserId', invitationsJson);

      print('💾 تم حفظ بيانات الأرشيف في الكاش');
    } catch (e) {
      print('❌ خطأ في حفظ الكاش: $e');
    }
  }
}
