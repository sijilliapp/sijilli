import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import '../services/auth_service.dart';
import '../services/hijri_service.dart';
import '../services/connectivity_service.dart';
import '../services/user_appointment_status_service.dart';
import '../models/user_model.dart';
import '../models/appointment_model.dart';
import '../models/invitation_model.dart';
import '../models/user_appointment_status_model.dart';
import '../widgets/appointment_card.dart';
import '../config/constants.dart';
import '../utils/date_converter.dart';
import 'draft_forms_screen.dart';

/// صفحة الملف الشخصي للمستخدمين
///
/// يمكن الوصول إليها بطريقتين:
/// 1. عبر معرف المستخدم: UserProfileScreen.fromUserId('user_id')
/// 2. عبر اسم المستخدم: UserProfileScreen.fromUsername('username')
///
/// مثال للاستخدام:
/// ```dart
/// // الوصول عبر معرف المستخدم
/// Navigator.push(context, MaterialPageRoute(
///   builder: (context) => UserProfileScreen.fromUserId('abc123'),
/// ));
///
/// // الوصول عبر اسم المستخدم (للروابط المباشرة)
/// Navigator.push(context, MaterialPageRoute(
///   builder: (context) => UserProfileScreen.fromUsername('falah_alazmi'),
/// ));
/// ```
///
/// الميزات:
/// - عرض المواعيد العامة فقط (ليس الخاصة)
/// - نظام تبويبات (المواعيد / المتابعات)
/// - بحث في المواعيد
/// - عرض الروابط الشخصية
/// - نظام المتابعة
/// - دعم الأوفلاين مع مؤشرات الاتصال

class UserProfileScreen extends StatefulWidget {
  final String userId;
  final String? username;

  const UserProfileScreen({super.key, required this.userId, this.username});

  // دالة مساعدة لإنشاء صفحة ملف شخصي من اسم المستخدم
  static Widget fromUsername(String username) {
    return UserProfileScreen(
      userId: '', // سيتم تجاهله
      username: username,
    );
  }

  // دالة مساعدة لإنشاء صفحة ملف شخصي من معرف المستخدم
  static Widget fromUserId(String userId) {
    return UserProfileScreen(userId: userId, username: null);
  }

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final HijriService _hijriService = HijriService();
  final ConnectivityService _connectivityService = ConnectivityService();
  late final UserAppointmentStatusService _statusService;

  // Cache للمستخدمين المزارين مؤخراً (لتسريع التحميل)
  static final Map<String, UserModel> _userCache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};

  UserModel? _user;
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

  bool _isLoading = true;
  bool _isLoadingAppointmentDetails = false; // تحميل تفاصيل المواعيد
  bool _isFollowing = false; // سيتم استبداله بنظام الصداقة
  String _friendshipStatus = 'none'; // none, pending_sent, pending_received, friends
  String _friendshipRecordId = '';
  bool _isFriendshipLoading = false; // loading خاص بزر الصداقة فقط
  bool _isOnline = true;

  // متغيرات التبويبات
  late TabController _tabController;

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
    _loadUserProfile();
    _listenToConnectivity();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _listenToConnectivity() {
    _connectivityService.onConnectivityChanged.listen((isConnected) {
      if (mounted) {
        setState(() => _isOnline = isConnected);
        if (isConnected) {
          _loadUserProfile();
        }
      }
    });
  }

  Future<void> _loadUserProfile() async {
    try {
      setState(() => _isLoading = true);

      // 1. محاولة التحميل من الـ cache أولاً
      final userId = widget.userId.isNotEmpty ? widget.userId : widget.username ?? '';
      final cachedUser = _userCache[userId];
      final cacheTime = _cacheTimestamps[userId];
      
      // استخدام الـ cache إذا كان حديثاً (أقل من 5 دقائق)
      if (cachedUser != null && 
          cacheTime != null && 
          DateTime.now().difference(cacheTime).inMinutes < 5) {
        _user = cachedUser;
        print('✅ تم تحميل المستخدم من الـ cache');
        
        if (mounted) {
          setState(() => _isLoading = false);
        }
        
        // تحميل باقي البيانات في الخلفية
        _loadBackgroundData();
        return;
      }

      // 2. تحميل بيانات المستخدم من السيرفر
      if (widget.username != null && widget.username!.isNotEmpty) {
        await _loadUserByUsername(widget.username!);
      } else {
        final userRecord = await _authService.pb
            .collection(AppConstants.usersCollection)
            .getOne(widget.userId);

        _user = UserModel.fromJson(userRecord.toJson());
      }

      if (_user == null) {
        throw Exception('المستخدم غير موجود');
      }

      // حفظ في الـ cache
      _userCache[userId] = _user!;
      _cacheTimestamps[userId] = DateTime.now();

      // 3. عرض الصفحة فوراً مع البيانات الأساسية
      if (mounted) {
        setState(() => _isLoading = false);
      }

      // 4. تحميل باقي البيانات في الخلفية (بدون انتظار)
      _loadBackgroundData();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل البيانات: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // تحميل البيانات الثانوية في الخلفية
  Future<void> _loadBackgroundData() async {
    // تشغيل العمليات بالتوازي
    await Future.wait([
      _trackVisit(), // تسجيل الزيارة (غير مهم للعرض)
      _checkFollowStatus(), // حالة الصداقة
      _loadUserAppointments(), // المواعيد
    ]);
  }

  // تحميل المستخدم بواسطة اسم المستخدم (للوصول عبر الرابط المباشر)
  Future<void> _loadUserByUsername(String username) async {
    try {
      final userRecords = await _authService.pb
          .collection(AppConstants.usersCollection)
          .getFullList(filter: 'username = "$username"');

      if (userRecords.isNotEmpty) {
        _user = UserModel.fromJson(userRecords.first.toJson());
        print('✅ تم العثور على المستخدم بواسطة اسم المستخدم: $username');
      } else {
        throw Exception('لم يتم العثور على مستخدم باسم المستخدم: $username');
      }
    } catch (e) {
      print('❌ خطأ في البحث عن المستخدم بواسطة اسم المستخدم: $e');
      throw e;
    }
  }

  // تسجيل الزيارة
  Future<void> _trackVisit() async {
    try {
      final currentUserId = _authService.currentUser?.id;

      // لا تسجل إذا كان المستخدم يزور ملفه الشخصي
      if (currentUserId == null ||
          _user == null ||
          currentUserId == _user!.id) {
        return;
      }

      // تسجيل الزيارة في قاعدة البيانات
      await _authService.pb
          .collection(AppConstants.visitsCollection)
          .create(
            body: {
              'visitor': currentUserId,
              'visited': _user!.id,
              'date_time': DateTime.now().toIso8601String(),
              'profile_section': 'profile',
              'visit_type': 'direct',
              'is_read': false,
            },
          );

      print('✅ تم تسجيل الزيارة لملف ${_user!.name}');
    } catch (e) {
      // تجاهل الأخطاء (لا نريد إزعاج المستخدم)
      print('❌ خطأ في تسجيل الزيارة: $e');
    }
  }

  Future<void> _loadUserAppointments() async {
    try {
      if (_user == null) return;

      final currentUserId = _authService.currentUser?.id;
      final isOwnProfile = currentUserId == _user!.id;

      List<AppointmentModel> appointments = [];

      if (isOwnProfile) {
        // صاحب الحساب: جلب جميع مواعيده (المستضافة + المدعو إليها)
        print('🏠 جلب مواعيد صاحب الحساب: ${_user!.id}');
        
        // 1. جلب المواعيد المستضافة
        final hostedAppointments = await _authService.pb
            .collection(AppConstants.appointmentsCollection)
            .getFullList(
          filter: 'host = "${_user!.id}"',
          sort: '-appointment_date',
        );
        
        print('📊 المواعيد المستضافة: ${hostedAppointments.length}');
        
        // 2. جلب المواعيد المدعو إليها (مقبولة فقط، ليس deleted_after_accept)
        // لأن deleted_after_accept يعني أن الضيف حذف الموعد ويجب ألا يظهر
        final acceptedInvitations = await _authService.pb
            .collection(AppConstants.invitationsCollection)
            .getFullList(
          filter: 'guest = "${_user!.id}" && status = "accepted"',
          expand: 'appointment',
        );
        
        print('📊 الدعوات المقبولة: ${acceptedInvitations.length}');
        
        // جمع المواعيد
        final appointmentsMap = <String, AppointmentModel>{};
        
        // إضافة المواعيد المستضافة
        for (final record in hostedAppointments) {
          final appointment = AppointmentModel.fromJson(record.toJson());
          appointmentsMap[appointment.id] = appointment;
        }
        
        // إضافة المواعيد من الدعوات
        for (final invitation in acceptedInvitations) {
          try {
            final expandData = invitation.data['expand'];
            if (expandData != null && expandData['appointment'] != null) {
              final appointmentData = expandData['appointment'];
              final appointment = AppointmentModel.fromJson(appointmentData);
              appointmentsMap[appointment.id] = appointment;
            }
          } catch (e) {
            print('⚠️ خطأ في معالجة دعوة: $e');
          }
        }
        
        print('📊 إجمالي المواعيد الفريدة: ${appointmentsMap.length}');
        
        // فلترة المواعيد المحذوفة/المؤرشفة من user_appointment_status
        if (appointmentsMap.isNotEmpty) {
          final appointmentIds = appointmentsMap.keys.toList();
          
          try {
            final statusRecords = await _authService.pb
                .collection(AppConstants.userAppointmentStatusCollection)
                .getFullList(
              filter: 'user = "$currentUserId" && (${appointmentIds.map((id) => 'appointment = "$id"').join(' || ')})',
            );
            
            // إزالة المواعيد المحذوفة أو المؤرشفة
            final hiddenIds = statusRecords
                .where((record) => record.data['status'] == 'deleted' || record.data['status'] == 'archived')
                .map((record) => record.data['appointment'] as String)
                .toSet();
            
            print('🗑️ مواعيد محذوفة/مؤرشفة: ${hiddenIds.length}');
            
            appointments = appointmentsMap.values
                .where((apt) => !hiddenIds.contains(apt.id))
                .toList();
          } catch (e) {
            print('⚠️ خطأ في جلب حالات المواعيد: $e');
            // في حالة الخطأ، نعرض جميع المواعيد
            appointments = appointmentsMap.values.toList();
          }
        }
        
        print('✅ إجمالي المواعيد المعروضة: ${appointments.length}');
      } else {
        // الزائر: يرى المواعيد بناءً على قواعد الرؤية
        try {
          print('🔍 جلب مواعيد المستخدم: ${_user!.id}');
          print('🔍 الزائر الحالي: $currentUserId');
          
          // جلب جميع المواعيد التي المستخدم منشئ لها (بدون فلترة بالحالة)
          final hostedAppointments = await _authService.pb
              .collection(AppConstants.appointmentsCollection)
              .getFullList(
            filter: 'host = "${_user!.id}"',
            sort: '-appointment_date',
          );
          
          print('📊 عدد المواعيد المستضافة: ${hostedAppointments.length}');
          
          // جلب المواعيد التي المستخدم ضيف فيها (من invitations)
          // ملاحظة: نجلب حتى deleted_after_accept لأن الفلترة النهائية ستحدد إذا كان يجب عرضها
          final guestInvitations = await _authService.pb
              .collection(AppConstants.invitationsCollection)
              .getFullList(
            filter: 'guest = "${_user!.id}" && (status = "accepted" || status = "deleted_after_accept")',
            expand: 'appointment',
          );
          
          print('📊 عدد الدعوات المقبولة: ${guestInvitations.length}');
          
          // جمع المواعيد من كلا المصدرين
          final appointmentsMap = <String, AppointmentModel>{};
          
          // إضافة المواعيد المستضافة
          for (final record in hostedAppointments) {
            final appointment = AppointmentModel.fromJson(record.toJson());
            appointmentsMap[appointment.id] = appointment;
          }
          
          // إضافة المواعيد من الدعوات
          for (final invitation in guestInvitations) {
            try {
              final expandData = invitation.data['expand'];
              if (expandData != null && expandData['appointment'] != null) {
                final appointmentData = expandData['appointment'];
                final appointment = AppointmentModel.fromJson(appointmentData);
                appointmentsMap[appointment.id] = appointment;
              }
            } catch (e) {
              print('⚠️ خطأ في معالجة دعوة: $e');
            }
          }
          
          print('📥 إجمالي المواعيد الفريدة: ${appointmentsMap.length}');
          
          if (appointmentsMap.isEmpty) {
            print('⚠️ لا توجد مواعيد للمستخدم');
            appointments = [];
          } else {
            final appointmentIds = appointmentsMap.keys.toList();
            
            // جلب خصوصية المستخدم لجميع المواعيد من user_appointment_status
            final allStatusRecords = await _authService.pb
                .collection(AppConstants.userAppointmentStatusCollection)
                .getFullList(
              filter: 'user = "${_user!.id}" && (${appointmentIds.map((id) => 'appointment = "$id"').join(' || ')})',
            );
            
            print('📊 عدد سجلات user_appointment_status: ${allStatusRecords.length}');
            
            // إنشاء map لسهولة البحث عن خصوصية وحالة المستخدم
            final userStatusMap = <String, Map<String, dynamic>>{};
            for (var record in allStatusRecords) {
              final appointmentId = record.data['appointment'] as String;
              userStatusMap[appointmentId] = {
                'privacy': record.data['privacy'] as String?,
                'status': record.data['status'] as String,
              };
            }
            
            print('📊 خريطة الحالات: ${userStatusMap.length} سجل');
            
            // فحص دور المستخدم الحالي ودور صاحب الصفحة
            final currentUserRole = _authService.currentUser?.role ?? 'user';
            final profileOwnerRole = _user!.role ?? 'user';
            final isCurrentUserApproved = currentUserRole == 'approved' || currentUserRole == 'admin';
            final isProfileOwnerApproved = profileOwnerRole == 'approved' || profileOwnerRole == 'admin';
            
            print('👤 دور الزائر: $currentUserRole (${isCurrentUserApproved ? "معتمد/أدمن" : "عادي"})');
            print('👤 دور صاحب الصفحة: $profileOwnerRole (${isProfileOwnerApproved ? "معتمد/أدمن" : "عادي"})');
            
            // فحص الصداقة (علاقة متبادلة)
            bool areFriends = false;
            if (currentUserId != null) {
              // البحث عن علاقة صداقة مقبولة في أي اتجاه
              final friendshipRecords = await _authService.pb
                  .collection(AppConstants.friendshipCollection)
                  .getFullList(
                filter: '((follower = "$currentUserId" && following = "${_user!.id}") || (follower = "${_user!.id}" && following = "$currentUserId")) && status = "approved"',
              );
              areFriends = friendshipRecords.isNotEmpty;
              print('👥 الصداقة: ${areFriends ? "أصدقاء ✅" : "ليسوا أصدقاء ❌"}');
            }
            
            // فحص إذا كان الزائر الحالي مدعواً في أي من المواعيد
            List<String> currentUserInvitedAppointmentIds = [];
            if (currentUserId != null) {
              final currentUserInvitations = await _authService.pb
                  .collection(AppConstants.invitationsCollection)
                  .getFullList(
                filter: 'guest = "$currentUserId" && (${appointmentIds.map((id) => 'appointment = "$id"').join(' || ')}) && (status = "accepted" || status = "invited")',
              );
              
              currentUserInvitedAppointmentIds = currentUserInvitations
                  .map((r) => r.data['appointment'] as String)
                  .toList();
              
              print('📨 الزائر الحالي مدعو في ${currentUserInvitedAppointmentIds.length} موعد');
            }
            
            // فلترة المواعيد بناءً على قواعد الرؤية الجديدة (نظام الصداقة)
            for (final appointmentId in appointmentIds) {
              final appointment = appointmentsMap[appointmentId];
              
              if (appointment != null) {
                // فحص حالة صاحب الصفحة في الموعد
                final ownerStatus = userStatusMap[appointmentId];
                final ownerPrivacy = ownerStatus?['privacy'] as String?;
                final ownerAppointmentStatus = ownerStatus?['status'] as String? ?? 'active';
                
                // تجاهل المواعيد المحذوفة أو المؤرشفة من قبل صاحب الصفحة
                // هذا يعني أن صاحب الصفحة لا يريد عرض هذا الموعد في بروفايله
                if (ownerAppointmentStatus == 'deleted' || ownerAppointmentStatus == 'archived') {
                  print('📋 موعد ${appointment.title}: تم تجاهله (صاحب الصفحة ${ownerAppointmentStatus})');
                  continue;
                }
                
                // الخصوصية من user_appointment_status لصاحب الصفحة، الافتراضي: عام
                final effectivePrivacy = ownerPrivacy ?? 'public';
                
                // قواعد الرؤية الجديدة (نظام الصداقة):
                // 1. المواعيد الخاصة: فقط الضيوف المدعوون يرونها
                // 2. المواعيد العامة:
                //    - إذا كان أحدهما approved → يرى الموعد
                //    - إذا كلاهما user → يحتاج صداقة مقبولة
                final isCurrentUserInvited = currentUserInvitedAppointmentIds.contains(appointmentId);
                final isCurrentUserHost = appointment.hostId == currentUserId;
                final isPublic = effectivePrivacy == 'public';
                
                print('📋 موعد ${appointment.title}: privacy=$effectivePrivacy, ownerStatus=$ownerAppointmentStatus, currentRole=$currentUserRole, ownerRole=$profileOwnerRole, friends=$areFriends, invited=$isCurrentUserInvited, isHost=$isCurrentUserHost');
                
                // فحص إذا كان الموعد خاص
                if (!isPublic) {
                  // موعد خاص: فقط المدعوون والمضيف يرونه
                  if (isCurrentUserInvited || isCurrentUserHost) {
                    appointments.add(appointment);
                    print('   ✅ تمت إضافة الموعد (خاص - ${isCurrentUserHost ? "مضيف" : "مدعو"})');
                  } else {
                    print('   ❌ تم تجاهل الموعد (خاص - لا مدعو ولا مضيف)');
                  }
                } else if (isPublic) {
                  // القاعدة 2: موعد عام
                  bool canView = false;
                  String reason = '';
                  
                  if (isCurrentUserApproved || isProfileOwnerApproved) {
                    // أحدهما approved → يرى الموعد
                    canView = true;
                    reason = isCurrentUserApproved ? 'الزائر معتمد' : 'صاحب الصفحة معتمد';
                  } else if (areFriends) {
                    // كلاهما user + أصدقاء → يرى الموعد
                    canView = true;
                    reason = 'أصدقاء';
                  } else if (currentUserId == null) {
                    // زائر غير مسجل → لا يرى (تغيير من النظام القديم)
                    canView = false;
                    reason = 'زائر غير مسجل - يحتاج صداقة';
                  } else {
                    // كلاهما user + ليسوا أصدقاء → لا يرى
                    canView = false;
                    reason = 'user عادي - يحتاج صداقة';
                  }
                  
                  if (canView) {
                    appointments.add(appointment);
                    print('   ✅ تمت إضافة الموعد (عام - $reason)');
                  } else {
                    print('   ❌ تم تجاهل الموعد (عام - $reason)');
                  }
                }
              }
            }
            
            print('✅ عدد المواعيد المرئية: ${appointments.length}');
          }
        } catch (e) {
          print('❌ خطأ في جلب مواعيد المستخدم: $e');
          appointments = [];
        }
        
        // ملاحظة: لا نفلتر المواعيد المحذوفة من قبل الزائر الحالي
        // لأن الزائر يجب أن يرى مواعيد صاحب الصفحة حتى لو الزائر حذفها من حسابه
        // البطاقة ستعرض حالة الزائر (أحمر) بناءً على participantsStatus
      }

      // عرض المواعيد فوراً
      if (mounted) {
        setState(() {
          _appointments = appointments;
          _applyFilters();
          _isLoadingAppointmentDetails = true;
        });
      }

      // تحميل تفاصيل الضيوف والمنشئين في الخلفية
      await Future.wait([
        _loadGuestsAndInvitations(appointments),
        _loadAppointmentHosts(appointments),
        _loadParticipantsStatus(appointments),
      ]);

      // تحديث الواجهة بعد تحميل التفاصيل
      if (mounted) {
        setState(() {
          _isLoadingAppointmentDetails = false;
        });
      }
    } catch (e) {
      print('❌ خطأ في تحميل مواعيد المستخدم: $e');
    }
  }

  // جلب الضيوف والدعوات للمواعيد
  Future<void> _loadGuestsAndInvitations(
    List<AppointmentModel> appointments,
  ) async {
    try {
      _appointmentGuests.clear();
      _appointmentInvitations.clear();

      if (appointments.isEmpty) return;

      // جلب جميع الدعوات في طلب واحد
      final appointmentIds = appointments.map((apt) => apt.id).toList();
      final filterConditions = appointmentIds
          .map((id) => 'appointment = "$id"')
          .join(' || ');

      // جلب الدعوات فقط للمواعيد التي المستخدم الحالي يستطيع رؤيتها
      // نفلتر الدعوات بناءً على خصوصية الموعد
      final currentUserId = _authService.currentUser?.id;
      final isOwnProfile = currentUserId == _user?.id;
      
      final allInvitationRecords = await _authService.pb
          .collection(AppConstants.invitationsCollection)
          .getFullList(filter: '($filterConditions)', expand: 'guest');

      print('📨 إجمالي الدعوات المسترجعة: ${allInvitationRecords.length}');

      // تجميع الدعوات والضيوف حسب الموعد
      for (final appointment in appointments) {
        final invitations = <InvitationModel>[];
        final guests = <UserModel>[];

        // فلترة الدعوات الخاصة بهذا الموعد
        final appointmentInvitations = allInvitationRecords
            .where((record) => record.data['appointment'] == appointment.id)
            .toList();

        print('📨 موعد ${appointment.title}: ${appointmentInvitations.length} دعوة');

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
              print('   ✅ ضيف: ${guest.name} (${invitation.status})');
            } else {
              print('   ⚠️ لا توجد بيانات expand للضيف');
            }
          } catch (e) {
            print('   ❌ خطأ في معالجة دعوة: $e');
            continue;
          }
        }

        _appointmentInvitations[appointment.id] = invitations;
        _appointmentGuests[appointment.id] = guests;
        
        print('   📊 النتيجة: ${guests.length} ضيف، ${invitations.length} دعوة');
      }
    } catch (e) {
      print('❌ خطأ في جلب الضيوف والدعوات: $e');
    }
  }

  // جلب معلومات منشئي المواعيد
  Future<void> _loadAppointmentHosts(
    List<AppointmentModel> appointments,
  ) async {
    try {
      _appointmentHosts.clear();

      if (appointments.isEmpty) return;

      // جمع معرفات المنشئين الفريدة
      final hostIds = appointments.map((apt) => apt.hostId).toSet().toList();

      if (hostIds.isEmpty) return;

      // جلب معلومات جميع المنشئين في طلب واحد
      final filterConditions = hostIds.map((id) => 'id = "$id"').join(' || ');

      final hostRecords = await _authService.pb
          .collection(AppConstants.usersCollection)
          .getFullList(filter: '($filterConditions)');

      // تحويل البيانات وربطها بالمواعيد
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

      // ربط كل موعد بمنشئه
      for (final appointment in appointments) {
        final host = hostsMap[appointment.hostId];
        if (host != null) {
          _appointmentHosts[appointment.id] = host;
        }
      }
    } catch (e) {
      print('❌ خطأ في جلب معلومات المنشئين: $e');
    }
  }

  // جلب حالات المشاركين للمواعيد
  Future<void> _loadParticipantsStatus(
    List<AppointmentModel> appointments,
  ) async {
    try {
      _participantsStatus.clear();

      if (appointments.isEmpty) return;

      // جلب حالات المشاركين بالتوازي
      final statusFutures = appointments.map((appointment) async {
        try {
          final participantsStatus = await _statusService
              .getAllParticipantsStatus(appointment.id);
          _participantsStatus[appointment.id] = participantsStatus;
          print('📊 حالات المشاركين للموعد ${appointment.title}: ${participantsStatus.length} مشارك');
        } catch (e) {
          print('⚠️ خطأ في جلب حالات المشاركين للموعد ${appointment.id}: $e');
        }
      });
      
      await Future.wait(statusFutures);
    } catch (e) {
      print('❌ خطأ في جلب حالات المشاركين: $e');
    }
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

    // تطبيق البحث النصي
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((apt) {
        return apt.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (apt.region?.toLowerCase().contains(_searchQuery.toLowerCase()) ??
                false) ||
            (apt.building?.toLowerCase().contains(_searchQuery.toLowerCase()) ??
                false);
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

  void _toggleSearch() {
    setState(() {
      _showSearch = !_showSearch;
      if (!_showSearch) {
        _searchController.clear();
        _searchQuery = '';
        _applyFilters();
      }
    });
  }

  Future<void> _checkFriendshipStatus() async {
    try {
      final currentUserId = _authService.currentUser?.id;
      if (currentUserId == null || _user == null) return;

      // البحث عن علاقة صداقة في كلا الاتجاهين
      final records = await _authService.pb
          .collection(AppConstants.friendshipCollection)
          .getFullList(
            filter: '((follower = "$currentUserId" && following = "${_user!.id}") || (follower = "${_user!.id}" && following = "$currentUserId"))',
          );

      if (mounted) {
        if (records.isEmpty) {
          setState(() {
            _friendshipStatus = 'none';
            _friendshipRecordId = '';
            _isFollowing = false;
          });
        } else {
          final record = records.first;
          final status = record.data['status'] as String? ?? 'pending';
          final followerId = record.data['follower'] as String;
          
          if (status == 'approved') {
            setState(() {
              _friendshipStatus = 'friends';
              _friendshipRecordId = record.id;
              _isFollowing = true; // للتوافق مع الكود القديم
            });
          } else if (status == 'pending') {
            // فحص من أرسل الطلب
            if (followerId == currentUserId) {
              setState(() {
                _friendshipStatus = 'pending_sent';
                _friendshipRecordId = record.id;
                _isFollowing = false;
              });
            } else {
              setState(() {
                _friendshipStatus = 'pending_received';
                _friendshipRecordId = record.id;
                _isFollowing = false;
              });
            }
          } else {
            setState(() {
              _friendshipStatus = 'none';
              _friendshipRecordId = '';
              _isFollowing = false;
            });
          }
        }
      }
    } catch (e) {
      print('❌ خطأ في فحص حالة الصداقة: $e');
    }
  }
  
  // للتوافق مع الكود القديم
  Future<void> _checkFollowStatus() async {
    await _checkFriendshipStatus();
  }

  // نظام الصداقة الجديد
  Future<void> _toggleFriendship() async {
    try {
      final currentUserId = _authService.currentUser?.id;
      if (currentUserId == null || _user == null) return;

      // صناديق حوار التأكيد
      if (_friendshipStatus == 'pending_sent') {
        // تأكيد إلغاء الطلب
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('إلغاء طلب الصداقة'),
            content: Text('هل تريد إلغاء طلب الصداقة المرسل إلى ${_user!.name}؟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('لا'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('نعم', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        if (confirm != true) return;
      } else if (_friendshipStatus == 'friends') {
        // تأكيد إنهاء الصداقة
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('إنهاء الصداقة'),
            content: Text('هل تريد إنهاء الصداقة مع ${_user!.name}؟\nلن تتمكنا من رؤية مواعيد بعضكما البعض.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('إنهاء الصداقة', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        if (confirm != true) return;
      }

      // إظهار loading
      setState(() => _isLoading = true);

      if (_friendshipStatus == 'none') {
        // إرسال طلب صداقة
        await _authService.pb.collection(AppConstants.friendshipCollection).create(
          body: {
            'follower': currentUserId,
            'following': _user!.id,
            'status': 'pending',
          },
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم إرسال طلب الصداقة إلى ${_user!.name}'),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else if (_friendshipStatus == 'pending_sent') {
        // إلغاء طلب الصداقة
        await _authService.pb
            .collection(AppConstants.friendshipCollection)
            .delete(_friendshipRecordId);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إلغاء طلب الصداقة'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else if (_friendshipStatus == 'pending_received') {
        // قبول طلب الصداقة
        await _authService.pb
            .collection(AppConstants.friendshipCollection)
            .update(_friendshipRecordId, body: {'status': 'approved'});
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('أصبحت أنت و${_user!.name} أصدقاء! 🎉'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else if (_friendshipStatus == 'friends') {
        // إنهاء الصداقة
        await _authService.pb
            .collection(AppConstants.friendshipCollection)
            .delete(_friendshipRecordId);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إنهاء الصداقة'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }

      // تحديث الحالة
      await _checkFriendshipStatus();
      
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // للتوافق مع الكود القديم
  Future<void> _toggleFollow() async {
    await _toggleFriendship();
  }

  Future<void> _copyProfileLink() async {
    if (_user != null) {
      final profileLink = 'sijilli.com/${_user!.username}';
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

  String? _getUserAvatarUrl(UserModel? user) {
    if (user?.avatar == null || user!.avatar?.isEmpty == true) {
      return null;
    }

    final cleanAvatar = user.avatar!
        .replaceAll('[', '')
        .replaceAll(']', '')
        .replaceAll('"', '');
    return '${AppConstants.pocketbaseUrl}/api/files/${AppConstants.usersCollection}/${user.id}/$cleanAvatar';
  }

  // دوال فحص حالة مواعيد اليوزر
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
      final duration = appointment.duration ?? 45; // القيمة الافتراضية 45 دقيقة
      final appointmentEnd = appointmentDate.add(Duration(minutes: duration));
      return now.isAfter(appointmentDate) && now.isBefore(appointmentEnd);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    widget.username != null
                        ? 'جاري البحث عن @${widget.username}...'
                        : 'جاري تحميل الملف الشخصي...',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                ],
              ),
            )
          : _user == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_off, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'لم يتم العثور على المستخدم',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                  ),
                  if (widget.username != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'اسم المستخدم @${widget.username} غير موجود',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('العودة'),
                  ),
                ],
              ),
            )
          : SafeArea(
              child: Stack(
                children: [
                  // المحتوى الرئيسي - CustomScrollView مع RefreshIndicator
                  RefreshIndicator(
                    onRefresh: _loadUserProfile,
                    child: CustomScrollView(
                      slivers: [
                      // Header Section
                      SliverToBoxAdapter(
                        child: Column(
                          children: [
                            // مسافة للشريط العلوي
                            const SizedBox(height: 48),

                            // User Header
                            _buildUserHeader(),

                            // Tab Bar
                            _buildTabBar(),

                            // هيدر التاريخ (يظهر فقط في تبويب المواعيد)
                            if (_tabController.index == 0) _buildDateHeader(),

                            // Search Section (يظهر فقط في تبويب المواعيد)
                            if (_showSearch && _tabController.index == 0)
                              _buildSearchSection(),
                          ],
                        ),
                      ),

                      // Content Section
                      _buildContentSliver(),
                    ],
                    ),
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // ← زر الرجوع
                          IconButton(
                            icon: Icon(
                              Icons.arrow_back,
                              size: 24,
                              color: Colors.grey.shade700,
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
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

  Widget _buildUserHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // User Profile Picture
          Container(
            padding: const EdgeInsets.only(top: 10, bottom: 12),
            child: _buildUserProfilePicture(),
          ),

          // User Info Section
          _buildUserInfoSection(),

          // Action Buttons
          _buildActionButtons(),
        ],
      ),
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
        labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
        ? _buildAppointmentsSliverList()
        : _buildPostsSliverList();
  }

  // Widget قسم البحث
  Widget _buildSearchSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'البحث في المواعيد...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF2196F3)),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
      ),
    );
  }

  // Widget هيدر التاريخ
  Widget _buildDateHeader() {
    // استخدام تاريخ اليوم مع تصحيح صاحب الصفحة
    final todayDate = DateTime.now();
    final userAdjustment = _user?.hijriAdjustment ?? 0;

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

  // Widget تبويب المواعيد كـ SliverList
  Widget _buildAppointmentsSliverList() {
    if (_filteredAppointments.isEmpty) {
      return SliverFillRemaining(
        child: Container(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.event_outlined, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                _searchQuery.isNotEmpty
                    ? 'لا توجد مواعيد تطابق البحث'
                    : 'لا توجد مواعيد عامة',
                style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
              ),
              if (_searchQuery.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'المواعيد الخاصة لا تظهر في الملفات الشخصية',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      );
    }

    // بناء البطاقات مع التايم لاين
    final widgets = _buildAppointmentsWithTimeline();

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => widgets[index],
        childCount: widgets.length,
      ),
    );
  }

  // بناء المواعيد مع التايم لاين
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
      final currentUserId = _authService.currentUser?.id;
      final isOwnProfile = currentUserId == _user?.id;
      
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          child: AppointmentCard(
            appointment: appointment,
            guests: _appointmentGuests[appointment.id] ?? [],
            invitations: _appointmentInvitations[appointment.id] ?? [],
            host: _appointmentHosts[appointment.id],
            participantsStatus: _participantsStatus[appointment.id],
            // تمرير خصوصية نسخة صاحب الصفحة (المستخدم المعروض)
            // هذا يحدد كيف يظهر الموعد في بروفايل صاحب الصفحة
            userPrivacy: _participantsStatus[appointment.id]?[_user!.id]?.privacy,
            isPastAppointment: appointment.appointmentDate.isBefore(
              DateTime.now(),
            ),
            // السماح بالتفاعل فقط لصاحب الحساب
            onTap: isOwnProfile ? () {
              // يمكن إضافة navigation للتفاصيل هنا لاحقاً
            } : null,
            onPrivacyChanged: isOwnProfile ? (newPrivacy) {
              // تحديث الخصوصية في الـ state
              setState(() {
                if (_participantsStatus[appointment.id] != null) {
                  final status = _participantsStatus[appointment.id]![_user!.id];
                  if (status != null) {
                    _participantsStatus[appointment.id]![_user!.id] = status.copyWith(
                      privacy: newPrivacy,
                    );
                  }
                }
              });
            } : null,
            onGuestsChanged: null,
          ),
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
            lines[0],
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
          ),
          // عدد الأيام (على اليسار)
          Text(
            lines[1],
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  // تنسيق تاريخ التايم لاين
  String _formatTimelineDate(DateTime appointmentDate, int daysDifference) {
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

    // التاريخ الميلادي
    final dayName = arabicDays[appointmentDate.weekday - 1];
    final gregorianMonth = gregorianMonths[appointmentDate.month - 1];
    final gregorianDateStr =
        '$dayName ${appointmentDate.day} $gregorianMonth ${appointmentDate.year}';

    // عدد الأيام (القيمة المطلقة)
    final absDays = daysDifference.abs();
    String daysText;
    if (absDays == 0) {
      daysText = 'اليوم';
    } else if (absDays == 1) {
      daysText = 'بعد يوم';
    } else if (absDays == 2) {
      daysText = 'بعد يومين';
    } else {
      daysText = 'بعد $absDays أيام';
    }

    return '$gregorianDateStr\n$daysText';
  }

  // Widget تبويب المتابعات كـ SliverList
  Widget _buildPostsSliverList() {
    return SliverFillRemaining(
      child: Container(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.article_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'المقالات',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'لا توجد مقالات حالياً',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Widget صورة المستخدم
  Widget _buildUserProfilePicture() {
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
              child: _getUserAvatarUrl(_user) == null
                  ? Icon(Icons.person, size: 70, color: Colors.grey.shade500)
                  : ClipOval(
                      child: Image.network(
                        _getUserAvatarUrl(_user)!,
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

  // Widget رابط الحساب
  Widget _buildProfileLink() {
    if (_user == null) return const SizedBox.shrink();

    final profileLink = 'sijilli.com/${_user!.username}';

    return Center(
      child: GestureDetector(
        onTap: _copyProfileLink,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              profileLink,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w400,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.copy, size: 14, color: Colors.grey.shade600),
          ],
        ),
      ),
    );
  }

  // Widget اسم المستخدم
  Widget _buildUserDisplayName() {
    if (_user?.name == null || _user!.name.isEmpty) {
      return const SizedBox.shrink();
    }

    return Center(
      child: Text(
        _user!.name,
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
    if (_user == null || _user!.bio == null || _user!.bio!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Text(
          _user!.bio!,
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
    if (_user == null) return const SizedBox(height: 20);

    final hasProfileLink = _user!.username.isNotEmpty;
    final hasDisplayName = _user!.name.isNotEmpty;
    final hasBio = _user!.bio != null && _user!.bio!.isNotEmpty;

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

  // زر الصداقة الموحد
  Widget _buildFriendshipButton() {
    String buttonText;
    Color buttonColor;
    Color textColor;
    IconData icon;
    
    switch (_friendshipStatus) {
      case 'none':
        buttonText = 'طلب صداقة';
        buttonColor = const Color(0xFF2196F3);
        textColor = Colors.white;
        icon = Icons.person_add;
        break;
      case 'pending_sent':
        buttonText = 'انتظار';
        buttonColor = Colors.orange.shade50;
        textColor = Colors.orange.shade700;
        icon = Icons.schedule;
        break;
      case 'pending_received':
        buttonText = 'قبول';
        buttonColor = Colors.green;
        textColor = Colors.white;
        icon = Icons.check;
        break;
      case 'friends':
        buttonText = 'صديق';
        buttonColor = Colors.grey.shade200;
        textColor = Colors.grey.shade700;
        icon = Icons.check_circle;
        break;
      default:
        buttonText = 'طلب صداقة';
        buttonColor = const Color(0xFF2196F3);
        textColor = Colors.white;
        icon = Icons.person_add;
    }
    
    return Container(
      width: 130,
      height: 32,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: buttonColor,
        border: _friendshipStatus == 'pending_sent' || _friendshipStatus == 'friends'
            ? Border.all(color: Colors.grey.shade300, width: 1)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : _toggleFriendship,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: _isLoading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(textColor),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 16, color: textColor),
                      const SizedBox(width: 6),
                      Text(
                        buttonText,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // Widget الأزرار
  Widget _buildActionButtons() {
    final currentUserId = _authService.currentUser?.id;
    final isOwnProfile = currentUserId == _user?.id;

    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // الزر الدائري للروابط الشخصية
          Tooltip(
            message: 'الروابط الشخصية',
            child: Container(
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
          ),

          const SizedBox(width: 6),

          // زر الصداقة الجديد
          if (!isOwnProfile) _buildFriendshipButton(),
        ],
      ),
    );
  }

  // دالة عرض الروابط الشخصية
  void _showPersonalLinks() {
    if (_user == null) return;

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
              Text(
                'الروابط الشخصية - ${_user!.name}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
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

  // Widget قائمة الروابط الشخصية
  Widget _buildSocialLinksList(ScrollController scrollController) {
    if (_user == null) {
      return const Center(child: Text('لا يمكن تحميل البيانات'));
    }

    // تحليل الروابط الاجتماعية
    List<Map<String, String>> socialLinks = [];

    if (_user!.socialLink != null && _user!.socialLink!.isNotEmpty) {
      try {
        // إذا كانت الروابط في صيغة JSON
        final dynamic linksData = jsonDecode(_user!.socialLink!);
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
        if (_user!.socialLink!.contains('http')) {
          socialLinks.add({
            'platform': 'رابط',
            'url': _user!.socialLink!,
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
              'لم يضف ${_user!.name} أي روابط شخصية بعد',
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

  // الحصول على أيقونة المنصة الاجتماعية
  String _getSocialIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'instagram':
      case 'انستغرام':
        return '📷';
      case 'twitter':
      case 'تويتر':
        return '🐦';
      case 'youtube':
      case 'يوتيوب':
        return '📺';
      case 'facebook':
      case 'فيسبوك':
        return '📘';
      case 'linkedin':
      case 'لينكد إن':
        return '💼';
      case 'tiktok':
      case 'تيك توك':
        return '🎵';
      case 'snapchat':
      case 'سناب شات':
        return '👻';
      case 'whatsapp':
      case 'واتساب':
        return '💬';
      case 'telegram':
      case 'تيليغرام':
        return '✈️';
      default:
        return '🔗';
    }
  }

  // فتح الرابط
  void _openUrl(String url) {
    // TODO: استخدام url_launcher لفتح الرابط
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('فتح الرابط: $url'), backgroundColor: Colors.blue),
    );
  }

  // نسخ الرابط
  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم نسخ الرابط'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  // إنشاء موعد جديد مع هذا المستخدم
  void _createAppointmentWithUser() {
    if (_user == null) return;

    // الانتقال مباشرة لصفحة إضافة موعد
    _navigateToAddAppointment();
  }

  // الانتقال لصفحة إضافة موعد
  void _navigateToAddAppointment() {
    // العودة للصفحة الرئيسية مع تحديد تبويب الإضافة
    Navigator.of(context).popUntil((route) => route.isFirst);

    // إظهار رسالة تأكيد أن المستخدم تم تحديده مسبقاً
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم تحديد ${_user!.name} كضيف للموعد الجديد'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'موافق',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );

    // TODO: إضافة منطق لتمرير بيانات المستخدم المحدد مسبقاً للصفحة الرئيسية
    // هذا يتطلب تعديل في MainScreen لاستقبال المعاملات وتحديد التبويب
  }

  // بناء عناصر قائمة الإجراءات
  List<PopupMenuEntry<String>> _buildMenuItems() {
    final currentUserId = _authService.currentUser?.id;
    final isOwnProfile = currentUserId == _user?.id;
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

    if (isOwnProfile) {
      // قائمة المستخدم الحالي
      items.add(
        const PopupMenuItem<String>(
          value: 'back',
          child: Row(
            children: [
              Icon(Icons.arrow_back, size: 20),
              SizedBox(width: 8),
              Text('العودة'),
            ],
          ),
        ),
      );

      // زر المسودات للآدمن فقط
      if (isAdmin) {
        items.add(
          const PopupMenuItem<String>(
            value: 'drafts',
            child: Row(
              children: [
                Icon(
                  Icons.description_outlined,
                  size: 20,
                  color: Color(0xFF2196F3),
                ),
                SizedBox(width: 8),
                Text('المسودات'),
              ],
            ),
          ),
        );
      }
    } else {
      // قائمة المستخدمين الآخرين
      items.add(
        const PopupMenuItem<String>(
          value: 'back',
          child: Row(
            children: [
              Icon(Icons.arrow_back, size: 20),
              SizedBox(width: 8),
              Text('العودة'),
            ],
          ),
        ),
      );

      if (_isFollowing) {
        items.add(
          const PopupMenuItem<String>(
            value: 'unfollow',
            child: Row(
              children: [
                Icon(Icons.person_remove, size: 20, color: Colors.orange),
                SizedBox(width: 8),
                Text('إلغاء المتابعة'),
              ],
            ),
          ),
        );
      }

      items.add(
        const PopupMenuItem<String>(
          value: 'report',
          child: Row(
            children: [
              Icon(Icons.report_outlined, size: 20, color: Colors.red),
              SizedBox(width: 8),
              Text('الإبلاغ'),
            ],
          ),
        ),
      );

      items.add(
        const PopupMenuItem<String>(
          value: 'block',
          child: Row(
            children: [
              Icon(Icons.block, size: 20, color: Colors.red),
              SizedBox(width: 8),
              Text('حظر'),
            ],
          ),
        ),
      );
    }

    return items;
  }

  // معالجة إجراءات القائمة
  void _handleMenuAction(String action) {
    switch (action) {
      case 'search':
        _toggleSearch();
        break;
      case 'back':
        Navigator.of(context).pop();
        break;
      case 'drafts':
        _navigateToDrafts();
        break;
      case 'unfollow':
        _toggleFollow();
        break;
      case 'report':
        _showReportDialog();
        break;
      case 'block':
        _showBlockDialog();
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

  // إظهار حوار الإبلاغ
  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('الإبلاغ عن المستخدم'),
        content: Text('هل تريد الإبلاغ عن ${_user?.name ?? 'هذا المستخدم'}؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم إرسال البلاغ - سيتم مراجعته قريباً'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('إبلاغ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // إظهار حوار الحظر
  void _showBlockDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حظر المستخدم'),
        content: Text(
          'هل تريد حظر ${_user?.name ?? 'هذا المستخدم'}؟\nلن تتمكن من رؤية مواعيده أو التفاعل معه.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('تم حظر ${_user?.name ?? 'المستخدم'}'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حظر', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // دالة تنسيق التاريخ
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      // للتواريخ الأقدم من يوم، اعرض التاريخ الهجري مع تصحيح صاحب الملف الشخصي
      final hijriDate = _hijriService.convertGregorianToHijri(date);
      final hijriString = _hijriService.formatHijriDate(hijriDate);
      return '${difference.inDays} يوم ($hijriString)';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ساعة';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} دقيقة';
    } else {
      return 'الآن';
    }
  }
}
