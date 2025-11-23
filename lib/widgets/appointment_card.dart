import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import '../models/appointment_model.dart';
import '../models/user_model.dart';
import '../models/invitation_model.dart';
import '../models/user_appointment_status_model.dart';
import '../services/auth_service.dart';
import '../services/timezone_service.dart';
import '../services/user_appointment_status_service.dart';
import '../utils/arabic_search_utils.dart';
import '../utils/date_converter.dart';
import '../config/constants.dart';

class AppointmentCard extends StatefulWidget {
  final AppointmentModel appointment;
  final List<UserModel> guests;
  final List<InvitationModel> invitations;
  final UserModel? host; // معلومات منشئ الموعد
  final Map<String, UserAppointmentStatusModel>?
  participantsStatus; // حالات المشاركين
  final bool isPastAppointment;
  final VoidCallback? onTap;
  final Function(String)? onPrivacyChanged;
  final Function(List<String>)? onGuestsChanged;
  final String?
  userPrivacy; // خصوصية نسخة المستخدم (تتجاوز خصوصية الموعد الأصلي)

  const AppointmentCard({
    super.key,
    required this.appointment,
    this.guests = const [],
    this.invitations = const [],
    this.host,
    this.participantsStatus,
    this.isPastAppointment = false,
    this.onTap,
    this.onPrivacyChanged,
    this.onGuestsChanged,
    this.userPrivacy,
  });

  @override
  State<AppointmentCard> createState() => _AppointmentCardState();
}

class _AppointmentCardState extends State<AppointmentCard> {
  final AuthService _authService = AuthService();
  late final UserAppointmentStatusService _statusService;
  Timer? _countdownTimer;

  // ثابت ارتفاع عناصر الهيدر - كبسولات حقيقية
  static const double headerElementHeight = 28;

  // متغيرات التخزين المحلي
  UserModel? _cachedHost;
  List<UserModel> _cachedGuests = [];
  List<InvitationModel> _cachedInvitations = [];
  bool _isDataLoaded = false;

  // حالة الخصوصية المحلية للتحديث الفوري
  String? _localPrivacy;

  // دوال مساعدة للحصول على البيانات الصحيحة (محلية أو مُمررة)
  // أولوية للبيانات المُمررة إذا كانت أحدث، وإلا البيانات المحفوظة محلياً
  UserModel? get _effectiveHost {
    // إذا كانت البيانات المُمررة متوفرة، استخدمها
    if (widget.host != null) return widget.host;
    // وإلا استخدم البيانات المحفوظة محلياً
    return _cachedHost;
  }

  List<UserModel> get _effectiveGuests {
    // إذا كانت البيانات المُمررة متوفرة، استخدمها
    if (widget.guests.isNotEmpty) return widget.guests;
    // وإلا استخدم البيانات المحفوظة محلياً
    return _cachedGuests;
  }

  List<InvitationModel> get _effectiveInvitations {
    // إذا كانت البيانات المُمررة متوفرة، استخدمها
    if (widget.invitations.isNotEmpty) return widget.invitations;
    // وإلا استخدم البيانات المحفوظة محلياً
    return _cachedInvitations;
  }

  // التحقق من أن المستخدم الحالي هو مالك الموعد
  bool _isCurrentUserHost() {
    return _authService.currentUser?.id == widget.appointment.hostId;
  }

  @override
  void initState() {
    super.initState();
    _statusService = UserAppointmentStatusService(_authService);
    _startCountdownTimer();
    _loadCachedData();
    _updateCachedDataFromProps();
  }

  @override
  void didUpdateWidget(AppointmentCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    // إعادة تعيين _localPrivacy إذا تغيرت userPrivacy من الخارج
    if (oldWidget.userPrivacy != widget.userPrivacy) {
      _localPrivacy = null; // إعادة تعيين لاستخدام القيمة الجديدة
      print('🔄 تحديث userPrivacy: ${widget.userPrivacy}');
    }

    // تحديث البيانات المحفوظة عند تغيير البيانات المُمررة
    if (oldWidget.host != widget.host ||
        oldWidget.guests != widget.guests ||
        oldWidget.invitations != widget.invitations) {
      _updateCachedDataFromProps();
    }
  }

  // تحديث البيانات المحفوظة محلياً من البيانات المُمررة
  void _updateCachedDataFromProps() {
    bool hasUpdates = false;

    // تحديث بيانات المنشئ إذا كانت متوفرة ومختلفة
    if (widget.host != null &&
        (_cachedHost == null || _cachedHost!.id != widget.host!.id)) {
      _cachedHost = widget.host;
      hasUpdates = true;
      print('🔄 تحديث بيانات المنشئ: ${widget.host!.name}');
    }

    // تحديث بيانات الضيوف إذا كانت متوفرة ومختلفة
    if (widget.guests.isNotEmpty &&
        (_cachedGuests.isEmpty ||
            _cachedGuests.length != widget.guests.length ||
            (_cachedGuests.isNotEmpty &&
                widget.guests.isNotEmpty &&
                _cachedGuests.first.id != widget.guests.first.id))) {
      _cachedGuests = List.from(widget.guests);
      hasUpdates = true;
      print('🔄 تحديث بيانات ${widget.guests.length} ضيف');
    }

    // تحديث بيانات الدعوات إذا كانت متوفرة ومختلفة
    if (widget.invitations.isNotEmpty &&
        (_cachedInvitations.isEmpty ||
            _cachedInvitations.length != widget.invitations.length)) {
      _cachedInvitations = List.from(widget.invitations);
      hasUpdates = true;
      print('🔄 تحديث بيانات ${widget.invitations.length} دعوة');
    }

    // حفظ التحديثات وتحديث الواجهة
    if (hasUpdates) {
      _saveCachedData();
      if (mounted) setState(() {});
    }
  }

  // تحميل البيانات المحفوظة محلياً
  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // تحميل بيانات المنشئ
      final hostData = prefs.getString('host_${widget.appointment.hostId}');
      if (hostData != null) {
        final hostJson = json.decode(hostData);
        _cachedHost = UserModel.fromJson(hostJson);
        print(
          '📱 تم تحميل بيانات المنشئ من التخزين المحلي: ${_cachedHost!.name}',
        );
      }

      // تحميل بيانات الضيوف
      final guestsData = prefs.getString('guests_${widget.appointment.id}');
      if (guestsData != null) {
        final guestsList = json.decode(guestsData) as List;
        _cachedGuests = guestsList.map((g) => UserModel.fromJson(g)).toList();
        print('📱 تم تحميل ${_cachedGuests.length} ضيف من التخزين المحلي');
      }

      // تحميل بيانات الدعوات
      final invitationsData = prefs.getString(
        'invitations_${widget.appointment.id}',
      );
      if (invitationsData != null) {
        final invitationsList = json.decode(invitationsData) as List;
        _cachedInvitations = invitationsList
            .map((i) => InvitationModel.fromJson(i))
            .toList();
        print(
          '📱 تم تحميل ${_cachedInvitations.length} دعوة من التخزين المحلي',
        );
      }

      _isDataLoaded = true;
      if (mounted) setState(() {});
    } catch (e) {
      print('❌ خطأ في تحميل البيانات المحفوظة: $e');
    }
  }

  // حفظ البيانات محلياً
  Future<void> _saveCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // حفظ بيانات المنشئ
      if (_cachedHost != null) {
        await prefs.setString(
          'host_${widget.appointment.hostId}',
          json.encode(_cachedHost!.toJson()),
        );
        print('💾 تم حفظ بيانات المنشئ محلياً: ${_cachedHost!.name}');
      }

      // حفظ بيانات الضيوف
      if (_cachedGuests.isNotEmpty) {
        final guestsJson = _cachedGuests.map((g) => g.toJson()).toList();
        await prefs.setString(
          'guests_${widget.appointment.id}',
          json.encode(guestsJson),
        );
        print('💾 تم حفظ ${_cachedGuests.length} ضيف محلياً');
      }

      // حفظ بيانات الدعوات
      if (_cachedInvitations.isNotEmpty) {
        final invitationsJson = _cachedInvitations
            .map((i) => i.toJson())
            .toList();
        await prefs.setString(
          'invitations_${widget.appointment.id}',
          json.encode(invitationsJson),
        );
        print('💾 تم حفظ ${_cachedInvitations.length} دعوة محلياً');
      }
    } catch (e) {
      print('❌ خطأ في حفظ البيانات: $e');
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  // بدء مؤقت العد التنازلي
  void _startCountdownTimer() {
    final now = DateTime.now();
    final appointmentTime = widget.appointment.appointmentDate;
    final difference = appointmentTime.difference(now);

    // تحديث كل ثانية فقط إذا كان الموعد خلال ساعة
    if (!difference.isNegative && difference.inHours < 1) {
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            // تحديث العد التنازلي
          });

          // إيقاف المؤقت إذا انتهى الموعد (بعد 45 دقيقة من بدايته)
          final now = DateTime.now();
          final appointmentEndTime = widget.appointment.appointmentDate.add(
            const Duration(minutes: 45),
          );
          final endDifference = appointmentEndTime.difference(now);
          if (endDifference.isNegative) {
            timer.cancel();
          }
        } else {
          timer.cancel();
        }
      });
    }
  }

  // الحصول على حالة الضيف من الدعوة
  String _getGuestStatus(UserModel guest) {
    final invitation = _effectiveInvitations.firstWhere(
      (inv) => inv.guestId == guest.id,
      orElse: () => InvitationModel(
        id: '',
        appointmentId: widget.appointment.id,
        guestId: guest.id,
        status: 'invited',
        created: DateTime.now(),
        updated: DateTime.now(),
      ),
    );
    return invitation.ringStatus;
  }

  // الحصول على لون الطوق حسب الحالة مع دعم النظام الجديد
  Color _getRingColor(String status, String guestId) {
    // فحص حالة الضيف من النظام الجديد أولاً
    final guestStatus = widget.participantsStatus?[guestId];

    if (guestStatus != null) {
      // لدينا بيانات من النظام الجديد
      switch (guestStatus.status.toLowerCase()) {
        case 'deleted': // الضيف حذف الموعد من حسابه
          return const Color(0xFFC62828); // أحمر داكن ناعم: الضيف حذف الموعد
        case 'archived': // الضيف أرشف الموعد
          return Colors.grey; // رمادي: الضيف أرشف الموعد
        case 'active': // الضيف نشط في الموعد
          return Colors.blue; // أزرق: الضيف نشط
        default:
          return Colors.grey; // رمادي: حالة غير معروفة
      }
    }

    // لا توجد بيانات من النظام الجديد، نستخدم النظام القديم (invitations)
    // status هنا هو ringStatus من InvitationModel (active, deleted, cancelled, pending)
    switch (status.toLowerCase()) {
      case 'active': // accepted -> active (وافق على الموعد)
        return Colors.blue; // أزرق: وافق على الموعد
      case 'deleted': // deleted_after_accept -> deleted (وافق ثم حذف)
        return const Color(0xFFC62828); // أحمر داكن ناعم: وافق ثم حذف الموعد
      case 'cancelled': // rejected -> cancelled (رفض الدعوة - مخفي)
        return Colors.transparent; // مخفي
      case 'pending': // invited -> pending (لم يقرر بعد)
      default:
        return Colors.grey; // رمادي: لم يقرر بعد
    }
  }

  // الحصول على لون طوق المنشئ حسب حالة المنشئ الفردية
  Color _getHostRingColor() {
    // فحص حالة المنشئ من user_appointment_status (المصدر الوحيد)
    final hostStatus = widget.participantsStatus?[widget.appointment.hostId];

    if (hostStatus != null) {
      switch (hostStatus.status.toLowerCase()) {
        case 'deleted': // المنشئ حذف الموعد من حسابه
          return const Color(0xFFE57373); // أحمر ناعم: المنشئ حذف الموعد
        case 'archived': // المنشئ أرشف الموعد
          return Colors.grey; // رمادي: المنشئ أرشف الموعد
        case 'active': // المنشئ نشط في الموعد
        default:
          return Colors.blue; // أزرق: المنشئ نشط
      }
    }

    // إذا لم تكن البيانات متاحة بعد، افتراضي: أزرق (نشط)
    return Colors.blue;
  }

  // الحصول على لون اسم المنشئ حسب حالة المنشئ الفردية
  Color _getHostNameColor() {
    // فحص حالة المنشئ من user_appointment_status (المصدر الوحيد)
    final hostStatus = widget.participantsStatus?[widget.appointment.hostId];

    if (hostStatus != null) {
      switch (hostStatus.status.toLowerCase()) {
        case 'deleted': // المنشئ حذف الموعد من حسابه
          return const Color(0xFFC62828); // أحمر داكن ناعم: المنشئ حذف الموعد
        case 'archived': // المنشئ أرشف الموعد
          return Colors.grey.shade600; // رمادي: المنشئ أرشف الموعد
        case 'active': // المنشئ نشط في الموعد
        default:
          return Colors.blue.shade700; // أزرق: المنشئ نشط
      }
    }

    // إذا لم تكن البيانات متاحة بعد، افتراضي: أزرق (نشط)
    return Colors.blue.shade700;
  }

  // حذف الموعد للمستخدم الحالي فقط
  Future<void> _deleteAppointmentForCurrentUser() async {
    try {
      await _statusService.deleteAppointmentForCurrentUser(
        widget.appointment.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حذف الموعد من حسابك - سيبقى مرئي للآخرين'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في حذف الموعد: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // تبديل الخصوصية - تحديث نسخة المستخدم فقط
  Future<void> _togglePrivacy() async {
    // الخصوصية من user_appointment_status فقط
    final currentPrivacy = _localPrivacy ?? widget.userPrivacy ?? 'public';
    final newPrivacy = currentPrivacy == 'public' ? 'private' : 'public';

    print('🔄 تبديل الخصوصية:');
    print('  _localPrivacy: $_localPrivacy');
    print('  widget.userPrivacy: ${widget.userPrivacy}');
    print('  currentPrivacy: $currentPrivacy');
    print('  newPrivacy: $newPrivacy');

    // 🚀 تحديث فوري في الـ UI
    setState(() {
      _localPrivacy = newPrivacy;
    });

    try {
      // إخطار الـ parent (اختياري)
      widget.onPrivacyChanged?.call(newPrivacy);

      // تحديث الخصوصية في نسخة المستخدم (user_appointment_status)
      await _statusService.updateUserAppointmentPrivacy(
        widget.appointment.id,
        newPrivacy,
      );

      // إظهار بنر التنبيه
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newPrivacy == 'public'
                  ? 'تم تغيير نسختك من الموعد إلى عام'
                  : 'تم تغيير نسختك من الموعد إلى خاص',
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: newPrivacy == 'public'
                ? Colors.green
                : Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('❌ Error updating user appointment privacy: $e');

      // ❗ Rollback - إعادة الحالة السابقة عند الفشل
      final oldPrivacy = newPrivacy == 'public' ? 'private' : 'public';

      if (mounted) {
        setState(() {
          _localPrivacy = oldPrivacy;
        });

        widget.onPrivacyChanged?.call(oldPrivacy);

        String errorMessage = 'خطأ في تحديث الخصوصية';

        // Check if user status was deleted (404 error)
        if (e.toString().contains('404') ||
            e.toString().contains("wasn't found")) {
          errorMessage = 'هذا الموعد لم يعد موجوداً. سيتم تحديث القائمة.';

          // Clean up local cache by marking as deleted
          _statusService
              .deleteAppointmentForCurrentUser(widget.appointment.id)
              .catchError((err) {
                print('❌ Error cleaning up deleted appointment: $err');
              });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // إظهار قائمة إضافة الضيوف مع البحث
  void _showAddGuestsDialog() {
    showDialog(
      context: context,
      builder: (context) => _GuestSelectionDialog(
        appointmentId: widget.appointment.id,
        currentGuests: widget.guests.map((g) => g.id).toList(),
        onGuestsSelected: (selectedGuestIds) {
          widget.onGuestsChanged?.call(selectedGuestIds);
        },
      ),
    );
  }

  // بناء كبسولة العد التنازلي
  Widget _buildCountdownCapsule() {
    final now = DateTime.now();
    final appointmentTime = widget.appointment.appointmentDate;
    final difference = appointmentTime.difference(now);

    String countdownText;
    Color backgroundColor;
    Color textColor;
    Color borderColor;

    // حساب نهاية الموعد (45 دقيقة من بداية الموعد)
    final appointmentEndTime = appointmentTime.add(const Duration(minutes: 45));
    final endDifference = appointmentEndTime.difference(now);

    if (endDifference.isNegative) {
      // الموعد انتهى (مضى أكثر من 45 دقيقة)
      countdownText = 'انتهى';
      backgroundColor = Colors.grey.shade100;
      textColor = Colors.grey.shade600;
      borderColor = Colors.grey.shade300;
    } else if (difference.isNegative || difference.inSeconds == 0) {
      // الموعد الآن (بدأ ولم ينته بعد)
      countdownText = 'الآن';
      backgroundColor = Colors.green.shade50;
      textColor = Colors.green.shade700;
      borderColor = Colors.green.shade200;
    } else if (difference.inSeconds < 60) {
      // أقل من دقيقة - عداد الثواني
      countdownText = '${difference.inSeconds}ث';
      backgroundColor = Colors.red.shade50;
      textColor = Colors.red.shade700;
      borderColor = Colors.red.shade200;
    } else if (difference.inMinutes < 60) {
      // أقل من ساعة - عداد الدقائق
      countdownText = 'بعد ${difference.inMinutes}د';
      backgroundColor = Colors.orange.shade50;
      textColor = Colors.orange.shade700;
      borderColor = Colors.orange.shade200;
    } else if (difference.inHours < 24) {
      // أقل من يوم - عداد الساعات
      countdownText = 'بعد ${difference.inHours}س';
      backgroundColor = Colors.yellow.shade50;
      textColor = Colors.yellow.shade800;
      borderColor = Colors.yellow.shade300;
    } else if (difference.inDays < 30) {
      // أقل من شهر - عداد الأيام
      countdownText = 'بعد ${difference.inDays}ي';
      backgroundColor = Colors.blue.shade50;
      textColor = Colors.blue.shade700;
      borderColor = Colors.blue.shade200;
    } else if (difference.inDays < 365) {
      // أقل من سنة - عداد الأشهر
      final months = (difference.inDays / 30).floor();
      countdownText = 'بعد ${months}ش';
      backgroundColor = Colors.purple.shade50;
      textColor = Colors.purple.shade700;
      borderColor = Colors.purple.shade200;
    } else {
      // أكثر من سنة - عداد السنوات
      final years = (difference.inDays / 365).floor();
      countdownText = 'بعد ${years}سنة';
      backgroundColor = Colors.indigo.shade50;
      textColor = Colors.indigo.shade700;
      borderColor = Colors.indigo.shade200;
    }

    return Container(
      height: headerElementHeight,
      padding: const EdgeInsets.symmetric(horizontal: 8), // تقليل padding
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(
          headerElementHeight / 2,
        ), // كبسولة حقيقية
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Center(
        child: Text(
          countdownText,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
    );
  }

  // بناء كبسولة الخصوصية (رمز فقط)
  Widget _buildPrivacyCapsule() {
    // الأولوية: الحالة المحلية > خصوصية المستخدم > خصوصية الموعد
    // الافتراضي: عام (للسجلات القديمة)
    // الخصوصية من user_appointment_status فقط
    final currentPrivacy = _localPrivacy ?? widget.userPrivacy ?? 'public';
    final isPublic = currentPrivacy == 'public';

    // تحديد إذا كانت البطاقة تفاعلية (يمكن تغيير الخصوصية)
    final isInteractive = widget.onPrivacyChanged != null;

    return GestureDetector(
      // السماح بالتفاعل فقط إذا كان onPrivacyChanged موجود
      onTap: isInteractive ? _togglePrivacy : null,
      child: Container(
        height: headerElementHeight,
        width: headerElementHeight, // عرض مربع للرمز فقط
        decoration: BoxDecoration(
          color: isPublic
              ? Colors.blue.shade50
              : Colors.orange.shade50, // أزرق عندما عام
          borderRadius: BorderRadius.circular(
            headerElementHeight / 2,
          ), // كبسولة حقيقية
          border: Border.all(
            color: isPublic
                ? Colors.blue.shade200
                : Colors.orange.shade200, // أزرق عندما عام
            width: 1,
          ),
        ),
        child: Center(
          child: Icon(
            isPublic ? Icons.public : Icons.lock,
            size: 14, // حجم أكبر قليلاً للرمز المنفرد
            color: isPublic
                ? Colors.blue.shade700
                : Colors.orange.shade700, // أزرق عندما عام
          ),
        ),
      ),
    );
  }

  // بناء صورة الضيف مع الطوق الديناميكي - بنفس ارتفاع الكبسولات
  Widget _buildGuestAvatar(UserModel guest) {
    // استخدام النظام الجديد أولاً للحصول على حالة الضيف
    final guestStatus = widget.participantsStatus?[guest.id];
    Color ringColor;

    if (guestStatus != null) {
      // لدينا بيانات من النظام الجديد - هذا هو المصدر الموثوق
      switch (guestStatus.status.toLowerCase()) {
        case 'deleted': // الضيف حذف الموعد من حسابه
          ringColor = const Color(0xFFE57373); // أحمر ناعم: الضيف حذف الموعد
          break;
        case 'archived': // الضيف أرشف الموعد
          ringColor = Colors.grey; // رمادي: الضيف أرشف الموعد
          break;
        case 'active': // الضيف نشط في الموعد
          ringColor = Colors.blue; // أزرق: الضيف نشط
          break;
        default:
          ringColor = Colors.grey; // رمادي: حالة غير معروفة
      }
    } else {
      // لا يوجد سجل في user_appointment_status - نستخدم حالة الدعوة
      final status = _getGuestStatus(guest);
      switch (status.toLowerCase()) {
        case 'active': // accepted -> active (وافق على الموعد)
          ringColor = Colors.blue; // أزرق: وافق على الموعد
          break;
        case 'deleted': // deleted_after_accept -> deleted (وافق ثم حذف)
          ringColor = const Color(0xFFE57373); // أحمر ناعم: وافق ثم حذف الموعد
          break;
        case 'cancelled': // rejected -> cancelled (رفض الدعوة)
          return const SizedBox.shrink(); // نخفي الضيوف الذين رفضوا
        case 'pending': // invited -> pending (لم يقرر بعد)
        default:
          ringColor = Colors.grey; // رمادي: لم يقرر بعد
      }
    }

    // تحديد سمك الطوق بناءً على اللون
    final isActive = ringColor == Colors.blue;
    final isDeleted = ringColor == const Color(0xFFE57373);

    return Container(
      width: headerElementHeight,
      height: headerElementHeight,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: ringColor,
          width: isActive ? 2 : 1.5, // طوق أسمك للنشطين
        ),
        // إضافة ظل للطوق النشط
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: ringColor.withValues(alpha: 0.3),
                  blurRadius: 3,
                  spreadRadius: 0.5,
                ),
              ]
            : null,
      ),
      child: CircleAvatar(
        radius:
            (headerElementHeight - 4) / 2, // تقليل الراديوس ليناسب الحجم الجديد
        backgroundColor: Colors.grey.shade100,
        backgroundImage: (guest.avatar?.isNotEmpty ?? false)
            ? NetworkImage(_getUserAvatarUrl(guest))
            : null,
        child: (guest.avatar?.isEmpty ?? true)
            ? Icon(
                Icons.person,
                size: 14, // أيقونة أصغر
                color: Colors.grey.shade600,
              )
            : null,
      ),
    );
  }

  // بناء اسم أول ضيف مع اللون المناسب - كبسولة
  Widget _buildFirstGuestName() {
    if (_effectiveGuests.isEmpty) return const SizedBox.shrink();

    final firstGuest = _effectiveGuests.first;

    Color backgroundColor;
    Color textColor;
    Color borderColor;

    // فحص حالة الضيف من النظام الجديد أولاً
    final guestStatus = widget.participantsStatus?[firstGuest.id];

    if (guestStatus != null) {
      // لدينا بيانات من النظام الجديد
      switch (guestStatus.status.toLowerCase()) {
        case 'deleted': // الضيف حذف الموعد من حسابه
          backgroundColor = const Color(0xFFFFEBEE);
          textColor = const Color(0xFFC62828);
          borderColor = const Color(0xFFFFCDD2);
          break;
        case 'archived': // الضيف أرشف الموعد
          backgroundColor = Colors.grey.shade50;
          textColor = Colors.grey.shade600;
          borderColor = Colors.grey.shade300;
          break;
        case 'active': // الضيف نشط في الموعد
        default:
          backgroundColor = Colors.blue.shade50;
          textColor = Colors.blue.shade700;
          borderColor = Colors.blue.shade200;
          break;
      }
    } else {
      // العودة للنظام القديم كـ fallback
      final status = _getGuestStatus(firstGuest);
      switch (status) {
        case 'active':
          backgroundColor = Colors.blue.shade50;
          textColor = Colors.blue.shade700;
          borderColor = Colors.blue.shade200;
          break;
        case 'deleted':
          backgroundColor = const Color(0xFFFFEBEE);
          textColor = const Color(0xFFC62828);
          borderColor = const Color(0xFFFFCDD2);
          break;
        case 'cancelled':
          backgroundColor = Colors.grey.shade50;
          textColor = Colors.grey.shade400;
          borderColor = Colors.grey.shade300;
          break;
        default:
          backgroundColor = Colors.grey.shade50;
          textColor = Colors.grey.shade600;
          borderColor = Colors.grey.shade300;
      }
    }

    return IntrinsicWidth(
      child: Container(
        height: headerElementHeight,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(
            headerElementHeight / 2,
          ), // كبسولة حقيقية
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Center(
          child: Text(
            firstGuest.name,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor,
              fontStyle: widget.isPastAppointment
                  ? FontStyle.italic
                  : FontStyle.normal,
            ),
            overflow: TextOverflow.ellipsis, // اختصار بالنقاط إذا طال النص
            maxLines: 1, // سطر واحد فقط
          ),
        ),
      ),
    );
  }

  // بناء زر إضافة الضيوف الجديد
  Widget _buildNewAddGuestButton() {
    final guestCount = _effectiveGuests.length;

    return GestureDetector(
      onTap: _showAddGuestsDialog,
      child: Container(
        height: headerElementHeight,
        padding: const EdgeInsets.symmetric(horizontal: 8), // تقليل padding
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(
            headerElementHeight / 2,
          ), // كبسولة حقيقية
          border: Border.all(color: Colors.blue.shade300, width: 1),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 14, color: Colors.blue.shade700),
              if (guestCount > 0) ...[
                const SizedBox(width: 4),
                Text(
                  '$guestCount',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // بناء زر الرابط
  Widget _buildStreamLinkButton() {
    return GestureDetector(
      onTap: () {
        // فتح الرابط
        // يمكن إضافة url_launcher هنا
      },
      child: Container(
        height: headerElementHeight,
        width: headerElementHeight, // مربع للأيقونة فقط
        decoration: BoxDecoration(
          color: Colors.purple.shade50,
          borderRadius: BorderRadius.circular(
            headerElementHeight / 2,
          ), // كبسولة حقيقية
          border: Border.all(color: Colors.purple.shade200, width: 1),
        ),
        child: Center(
          child: Icon(Icons.link, size: 14, color: Colors.purple.shade700),
        ),
      ),
    );
  }

  // تنسيق التاريخ بالعربية - عرض الأساسي والمعاين
  String _formatDateInArabic(DateTime dateTime) {
    final localDate = TimezoneService.toLocal(dateTime);
    final appointment = widget.appointment;
    final host = _effectiveHost;
    final hostAdjustment = host?.hijriAdjustment ?? 0;

    // أسماء الشهور
    const gregorianMonths = [
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

    // التاريخ الأساسي (بدون تصحيح - كما حفظه المنشئ)
    String basicDate;
    if (appointment.dateType == 'hijri' &&
        appointment.hijriDay != null &&
        appointment.hijriMonth != null &&
        appointment.hijriYear != null) {
      // الأساسي هجري - يُعرض كما هو من قاعدة البيانات
      final monthName = hijriMonths[appointment.hijriMonth! - 1];
      basicDate =
          '\u200E${appointment.hijriDay} $monthName ${appointment.hijriYear}';
    } else {
      // الأساسي ميلادي - يُعرض من appointmentDate
      final monthName = gregorianMonths[localDate.month - 1];
      basicDate = '${localDate.day} - $monthName - ${localDate.year}';
    }

    return basicDate;
  }

  // بناء تاريخ يوم واحد (مع الوقت)
  Widget _buildSingleDayDate() {
    return Row(
      textDirection: TextDirection.rtl,
      mainAxisSize: MainAxisSize.min,
      children: [
        // رمز التاريخ
        Icon(
          Icons.calendar_today_outlined,
          size: 16,
          color: Colors.grey.shade600,
        ),
        const SizedBox(width: 8),
        // التاريخ
        Text(
          _formatDateInArabic(widget.appointment.appointmentDate),
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
            fontStyle: widget.isPastAppointment
                ? FontStyle.italic
                : FontStyle.normal,
          ),
          textDirection: TextDirection.rtl,
        ),
        const SizedBox(width: 16),
        // رمز الوقت
        Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        // الوقت
        Text(
          TimezoneService.formatTime12Hour(
            TimezoneService.toLocal(widget.appointment.appointmentDate),
          ),
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
            fontStyle: widget.isPastAppointment
                ? FontStyle.italic
                : FontStyle.normal,
          ),
          textDirection: TextDirection.rtl,
        ),
      ],
    );
  }

  // بناء تاريخ متعدد الأيام (بدون وقت)
  Widget _buildMultiDayDate() {
    const gregorianMonths = [
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
    const hijriMonths = [
      'محرم',
      'صفر',
      'ربيع الأول',
      'ربيع الثاني',
      'جمادى الأولى',
      'جمادى الثانية',
      'رجب',
      'شعبان',
      'رمضان',
      'شوال',
      'ذو القعدة',
      'ذو الحجة',
    ];

    final appointment = widget.appointment;
    // استخدام 45 كقيمة افتراضية إذا كان duration فارغاً
    final duration = appointment.duration ?? 45;

    final startDate = TimezoneService.toLocal(
      widget.appointment.appointmentDate,
    );
    final endDate = startDate.add(Duration(minutes: duration));

    String dateRangeText;

    // التحقق من نوع التاريخ (هجري أو ميلادي)
    if (appointment.dateType == 'hijri' &&
        appointment.hijriDay != null &&
        appointment.hijriMonth != null &&
        appointment.hijriYear != null) {
      // تاريخ هجري - استخدام البيانات المحفوظة
      final startDay = appointment.hijriDay!;
      final startMonth = hijriMonths[appointment.hijriMonth! - 1];
      final startYear = appointment.hijriYear!;

      // حساب التاريخ الهجري للنهاية (تقريبي)
      final durationInDays = (duration / 1440).ceil();

      // حساب تقريبي للتاريخ الهجري النهائي
      int endDay = startDay + durationInDays;
      int endMonth = appointment.hijriMonth!;
      int endYear = appointment.hijriYear!;

      // تعديل إذا تجاوز نهاية الشهر
      while (endDay > 30) {
        endDay -= 30;
        endMonth++;
        if (endMonth > 12) {
          endMonth = 1;
          endYear++;
        }
      }

      final endMonthName = hijriMonths[endMonth - 1];
      dateRangeText =
          '$startDay $startMonth $startYear إلى $endDay $endMonthName $endYear';
    } else {
      // تاريخ ميلادي
      final startDay = startDate.day;
      final startMonth = gregorianMonths[startDate.month - 1];
      final startYear = startDate.year;

      final endDay = endDate.day;
      final endMonth = gregorianMonths[endDate.month - 1];
      final endYear = endDate.year;

      dateRangeText =
          '$startDay $startMonth $startYear إلى $endDay $endMonth $endYear';
    }

    return Row(
      textDirection: TextDirection.rtl,
      mainAxisSize: MainAxisSize.min,
      children: [
        // رمز التاريخ
        Icon(
          Icons.calendar_today_outlined,
          size: 16,
          color: Colors.grey.shade600,
        ),
        const SizedBox(width: 8),
        // نطاق التاريخ
        Flexible(
          child: Text(
            dateRangeText,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              fontStyle: widget.isPastAppointment
                  ? FontStyle.italic
                  : FontStyle.normal,
            ),
            textDirection: TextDirection.rtl,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // بناء صورة منشئ الموعد مع سياسة الألوان والطوق
  Widget _buildHostAvatar() {
    final hostAvatarSize = headerElementHeight * 2; // ضعف حجم صورة الضيف

    // الطوق يتبع حالة الموعد - أحمر إذا حذفه المنشئ، أزرق إذا نشط
    Color ringColor = _getHostRingColor();

    return Container(
      width: hostAvatarSize,
      height: hostAvatarSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: ringColor, // لون الطوق حسب حالة الموعد
          width: 3, // طوق أكثر وضوحاً
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: CircleAvatar(
        radius: (hostAvatarSize - 6) / 2, // تعديل نصف القطر للطوق الأكبر
        backgroundColor: Colors.grey.shade100,
        backgroundImage: (_effectiveHost?.avatar?.isNotEmpty ?? false)
            ? NetworkImage(_getUserAvatarUrl(_effectiveHost!))
            : null,
        child: (_effectiveHost?.avatar?.isEmpty ?? true)
            ? Icon(
                Icons.person,
                size: hostAvatarSize * 0.4,
                color: Colors.grey.shade400,
              )
            : null,
      ),
    );
  }

  // الحصول على رابط صورة المستخدم
  String _getUserAvatarUrl(UserModel user) {
    if (user.avatar?.isEmpty ?? true) return '';
    return '${AppConstants.pocketbaseUrl}/api/files/users/${user.id}/${user.avatar}';
  }

  @override
  Widget build(BuildContext context) {
    // تحديد لون البوردر حسب حالة الموعد
    final borderColor = widget.isPastAppointment
        ? Colors
              .grey
              .shade300 // بوردر رمادي للمواعيد الفائتة
        : Colors.blue.shade300; // بوردر أزرق للمواعيد القادمة

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: 1),
      ),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // الهيدر الجديد
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // من اليسار: صورة أول ضيف + اسمه (ملتصقين)
                  if (_effectiveGuests.isNotEmpty)
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // صورة أول ضيف
                          _buildGuestAvatar(_effectiveGuests.first),
                          const SizedBox(width: 6),
                          // اسم أول ضيف - يتمدد بحسب طول الاسم مع الاختصار عند التزاحم
                          Flexible(child: _buildFirstGuestName()),
                        ],
                      ),
                    )
                  else
                    const Spacer(),

                  const SizedBox(width: 6),

                  // من اليمين: زر الرابط + العد التنازلي + الخصوصية
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // زر الرابط (إن وُجد)
                      if (widget.appointment.streamLink != null &&
                          widget.appointment.streamLink!.isNotEmpty) ...[
                        _buildStreamLinkButton(),
                        const SizedBox(width: 4),
                      ],
                      // كبسولة العد التنازلي
                      _buildCountdownCapsule(),
                      const SizedBox(width: 4),
                      // كبسولة الخصوصية (أقصى اليمين)
                      _buildPrivacyCapsule(),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // تخطيط جديد: صورة كبيرة على اليمين والنصوص بجانبها
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                textDirection: TextDirection.rtl, // اتجاه الصف من اليمين لليسار
                children: [
                  // صورة المنشئ الكبيرة على اليمين
                  _buildHostAvatar(),
                  const SizedBox(width: 12), // مساحة بين الصورة والنصوص
                  // النصوص بجانب الصورة
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.end, // محاذاة النصوص لليمين
                      children: [
                        // اسم المنشئ مع سياسة الألوان حسب حالة الموعد والاختصار
                        Text(
                          _effectiveHost?.name ?? 'غير معروف',
                          style: TextStyle(
                            fontSize: 11, // نفس حجم اسم الضيف
                            fontWeight: FontWeight.w600, // نفس وزن اسم الضيف
                            color:
                                _getHostNameColor(), // لون حسب حالة الموعد - أحمر إذا محذوف، أزرق إذا نشط
                            fontStyle: widget.isPastAppointment
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
                          textDirection:
                              TextDirection.rtl, // اتجاه النص من اليمين لليسار
                          textAlign: TextAlign.right, // محاذاة النص لليمين
                          overflow: TextOverflow
                              .ellipsis, // اختصار بالنقاط إذا طال النص
                          maxLines: 1, // سطر واحد فقط
                        ),
                        const SizedBox(height: 4),

                        // عنوان الموعد مع سياسة الاختصار
                        Text(
                          widget.appointment.title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            fontStyle: widget.isPastAppointment
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
                          textDirection:
                              TextDirection.rtl, // اتجاه النص من اليمين لليسار
                          textAlign: TextAlign.right, // محاذاة النص لليمين
                          overflow: TextOverflow
                              .ellipsis, // اختصار بالنقاط إذا طال النص
                          maxLines:
                              1, // سطر واحد فقط - لا نريد العنوان يتكون من سطرين
                        ),
                        const SizedBox(height: 6), // تقليل المسافة من 12 إلى 6
                        // المكان (إذا موجود) مع الرمز في البداية
                        if (widget.appointment.region?.isNotEmpty ?? false) ...[
                          Row(
                            textDirection: TextDirection
                                .rtl, // اتجاه الصف من اليمين لليسار
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 16,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  widget.appointment.region! +
                                      (widget
                                                  .appointment
                                                  .building
                                                  ?.isNotEmpty ??
                                              false
                                          ? '، ${widget.appointment.building}'
                                          : ''),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade700,
                                    fontStyle: widget.isPastAppointment
                                        ? FontStyle.italic
                                        : FontStyle.normal,
                                  ),
                                  textDirection: TextDirection.rtl,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],

                        // التاريخ والوقت في سطر واحد مع الرموز في البداية
                        (widget.appointment.duration ?? 45) >= 1440
                            ? _buildMultiDayDate() // موعد متعدد الأيام
                            : _buildSingleDayDate(), // موعد يوم واحد
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// مكون حوار اختيار الضيوف مع البحث
class _GuestSelectionDialog extends StatefulWidget {
  final String appointmentId;
  final List<String> currentGuests;
  final Function(List<String>) onGuestsSelected;

  const _GuestSelectionDialog({
    required this.appointmentId,
    required this.currentGuests,
    required this.onGuestsSelected,
  });

  @override
  State<_GuestSelectionDialog> createState() => _GuestSelectionDialogState();
}

class _GuestSelectionDialogState extends State<_GuestSelectionDialog> {
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();

  List<UserModel> _allFriends = [];
  List<UserModel> _filteredFriends = [];
  List<String> _selectedGuests = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedGuests = List.from(widget.currentGuests);
    _loadFriends();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
      _filterFriends();
    });
  }

  void _filterFriends() {
    if (_searchQuery.isEmpty) {
      _filteredFriends = List.from(_allFriends);
    } else {
      _filteredFriends = _allFriends.where((friend) {
        return ArabicSearchUtils.searchInUserFields(
          friend.name,
          friend.username,
          friend.bio ?? '',
          _searchQuery,
        );
      }).toList();
    }
  }

  Future<void> _loadFriends() async {
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

      // جمع معرفات الأصدقاء (الطرف الآخر من العلاقة)
      Set<String> friendIds = {};

      for (var record in friendshipRecords) {
        final followerId = record.data['follower'] as String;
        final followingId = record.data['following'] as String;
        // إضافة الطرف الآخر من العلاقة
        final friendId = followerId == currentUserId ? followingId : followerId;
        friendIds.add(friendId);
      }

      // جلب بيانات المستخدمين
      final friends = <UserModel>[];
      if (friendIds.isNotEmpty) {
        final friendsFilter = friendIds.map((id) => 'id = "$id"').join(' || ');
        final usersRecords = await _authService.pb
            .collection(AppConstants.usersCollection)
            .getFullList(filter: '($friendsFilter)', sort: 'name');

        friends.addAll(
          usersRecords
              .map((record) => UserModel.fromJson(record.toJson()))
              .toList(),
        );
      }

      setState(() {
        _allFriends = friends;
        _filterFriends();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _toggleGuestSelection(String guestId) {
    setState(() {
      if (_selectedGuests.contains(guestId)) {
        _selectedGuests.remove(guestId);
      } else {
        _selectedGuests.add(guestId);
      }
    });
  }

  void _saveSelection() {
    widget.onGuestsSelected(_selectedGuests);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة ضيوف'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            // شريط البحث
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'البحث عن الأصدقاء...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // قائمة الأصدقاء
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredFriends.isEmpty
                  ? Center(
                      child: Text(
                        _searchQuery.isEmpty
                            ? 'لا توجد متابعات'
                            : 'لا توجد نتائج للبحث',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredFriends.length,
                      itemBuilder: (context, index) {
                        final friend = _filteredFriends[index];
                        final isSelected = _selectedGuests.contains(friend.id);

                        return CheckboxListTile(
                          secondary: CircleAvatar(
                            radius: 20,
                            backgroundImage:
                                (friend.avatar?.isNotEmpty ?? false)
                                ? NetworkImage(
                                    '${AppConstants.pocketbaseUrl}/api/files/users/${friend.id}/${friend.avatar}',
                                  )
                                : null,
                            child: (friend.avatar?.isEmpty ?? true)
                                ? const Icon(Icons.person, size: 20)
                                : null,
                          ),
                          title: Text(friend.name),
                          subtitle: Text('@${friend.username}'),
                          value: isSelected,
                          onChanged: (value) =>
                              _toggleGuestSelection(friend.id),
                          activeColor: Colors.blue,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _saveSelection,
          child: Text('حفظ (${_selectedGuests.length})'),
        ),
      ],
    );
  }
}
