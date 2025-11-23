import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/appointment_model.dart';
import '../models/user_model.dart';
import '../models/invitation_model.dart';
import '../models/user_appointment_status_model.dart';
import '../config/constants.dart';
import '../services/timezone_service.dart';
import '../services/sunset_service.dart';
import '../services/auth_service.dart';
import '../services/user_appointment_status_service.dart';
import '../utils/date_converter.dart';
import 'main_screen.dart';

class AppointmentDetailsScreen extends StatefulWidget {
  final AppointmentModel appointment;
  final List<UserModel> guests;
  final List<InvitationModel> invitations;
  final UserModel? host;
  final Map<String, UserAppointmentStatusModel>? participantsStatus;
  final bool isFromArchive; // ✅ علامة أن الموعد من الأرشيف

  const AppointmentDetailsScreen({
    super.key,
    required this.appointment,
    required this.guests,
    required this.invitations,
    this.host,
    this.participantsStatus,
    this.isFromArchive = false, // افتراضياً ليس من الأرشيف
  });

  @override
  State<AppointmentDetailsScreen> createState() =>
      _AppointmentDetailsScreenState();
}

class _AppointmentDetailsScreenState extends State<AppointmentDetailsScreen> {
  final AuthService _authService = AuthService();
  late final UserAppointmentStatusService _statusService;
  bool _isPrivate = false; // حالة الخصوصية
  
  // حالة الملاحظة الخاصة
  final TextEditingController _noteController = TextEditingController();
  String _noteSaveStatus = 'saved'; // saved, saving, unsaved
  String? _initialNote;

  @override
  void initState() {
    super.initState();
    _statusService = UserAppointmentStatusService(_authService);
    _loadPrivacyStatus(); // تحميل حالة الخصوصية
    _loadPrivateNote(); // تحميل الملاحظة الخاصة
  }
  
  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  // تحميل حالة الخصوصية من participantsStatus
  void _loadPrivacyStatus() {
    final currentUserId = _authService.currentUser?.id;
    if (currentUserId != null && widget.participantsStatus != null) {
      final userStatus = widget.participantsStatus![currentUserId];
      if (userStatus != null) {
        setState(() {
          _isPrivate = userStatus.privacy == 'private';
        });
      }
    }
  }
  
  // تحميل الملاحظة الخاصة
  Future<void> _loadPrivateNote() async {
    final currentUserId = _authService.currentUser?.id;
    if (currentUserId == null) return;
    
    try {
      // جلب الملاحظة من قاعدة البيانات مباشرة
      final userStatus = await _statusService.getUserAppointmentStatus(
        userId: currentUserId,
        appointmentId: widget.appointment.id,
      );
      
      if (userStatus != null && mounted) {
        setState(() {
          _initialNote = userStatus.myNote;
          _noteController.text = _initialNote ?? '';
          _noteSaveStatus = 'saved';
        });
      }
    } catch (e) {
      print('⚠️ خطأ في تحميل الملاحظة الخاصة: $e');
      // fallback: استخدم البيانات من participantsStatus
      if (widget.participantsStatus != null) {
        final userStatus = widget.participantsStatus![currentUserId];
        if (userStatus != null && mounted) {
          setState(() {
            _initialNote = userStatus.myNote;
            _noteController.text = _initialNote ?? '';
            _noteSaveStatus = 'saved';
          });
        }
      }
    }
  }
  
  // حفظ الملاحظة الخاصة
  Future<void> _savePrivateNote(String note) async {
    if (_initialNote == note) return; // لا تغيير
    
    setState(() {
      _noteSaveStatus = 'saving';
    });
    
    try {
      await _statusService.updateUserAppointmentNote(
        widget.appointment.id,
        note.isEmpty ? null : note,
      );
      
      if (mounted) {
        setState(() {
          _noteSaveStatus = 'saved';
          _initialNote = note;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _noteSaveStatus = 'unsaved';
        });
      }
    }
  }

  bool get _isCurrentUserHost {
    final currentUserId = _authService.currentUser?.id;
    return currentUserId == widget.appointment.hostId;
  }

  @override
  Widget build(BuildContext context) {
    final localDate = TimezoneService.toLocal(
      widget.appointment.appointmentDate,
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'تفاصيل الموعد',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          actions: [
            // سويتش الخصوصية
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isPrivate ? Icons.lock : Icons.public,
                    color: _isPrivate
                        ? const Color(0xFF2196F3)
                        : Colors.grey.shade600,
                    size: 20,
                  ),
                  const SizedBox(width: 4),
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
                  Switch(
                    value: _isPrivate,
                    onChanged: widget.isFromArchive ? null : (value) async {
                      // تحديث الـ UI فوراً (Optimistic Update)
                      setState(() {
                        _isPrivate = value;
                      });
                      
                      // تحديث الخصوصية في الخلفية
                      try {
                        await _statusService.updateUserAppointmentPrivacy(
                          widget.appointment.id,
                          value ? 'private' : 'public',
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                value
                                    ? 'تم تغيير الموعد إلى خاص'
                                    : 'تم تغيير الموعد إلى عام',
                              ),
                              backgroundColor: Colors.green,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('خطأ في تحديث الخصوصية: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    activeThumbColor: const Color(0xFF2196F3),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // موضوع النشرة (التايتل) في الأعلى - موسط
              Center(
                child: Text(
                  widget.appointment.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // الكنتينرات الرئيسية
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // الكنتينر الأيمن - الوسوم (عرض تلقائي)
                  _buildTagsContainer(localDate),
                  const SizedBox(width: 16),
                  // الكنتينر الأيسر - المحتوى (يملأ المساحة المتبقية)
                  Expanded(child: _buildContentContainer()),
                ],
              ),

              const SizedBox(height: 16),

              // الكنتينر السفلي الممتد - المشاركون
              _buildBottomContainer(),

              const SizedBox(height: 16),

              // رابط الموعد
              if (widget.appointment.streamLink?.isNotEmpty ?? false) ...[
                _buildStreamLinkSection(),
                const SizedBox(height: 16),
              ],

              // ملاحظة عامة
              if (widget.appointment.noteShared?.isNotEmpty ?? false) ...[
                _buildSharedNoteSection(),
                const SizedBox(height: 16),
              ],

              // ملاحظة خاصة
              _buildPrivateNoteSection(),
              const SizedBox(height: 24),

              // أزرار الإجراءات
              _buildActionButtons(),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // بناء الكنتينر الأيمن - الوسوم فقط
  Widget _buildTagsContainer(DateTime localDate) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: const BoxDecoration(color: Colors.white),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // المنطقة
            _buildTagLabel(':المنطقة'),
            const SizedBox(height: 12),

            // المبنى
            _buildTagLabel(':المبنى'),
            const SizedBox(height: 12),

            // التاريخ الميلادي
            _buildTagLabel(':التاريخ الميلادي'),
            const SizedBox(height: 12),

            // التاريخ الهجري
            _buildTagLabel(':التاريخ الهجري'),
            const SizedBox(height: 12),

            // الوقت
            _buildTagLabel(':الوقت'),
            const SizedBox(height: 12),

            // المدة
            _buildTagLabel(':المدة'),
            const SizedBox(height: 12),

            // الغروب
            _buildTagLabel(':الغروب'),
          ],
        ),
      ),
    );
  }

  // بناء اسم الوسم فقط
  Widget _buildTagLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 15, // تكبير من 14 إلى 15
        color: Colors.grey.shade700,
        fontWeight: FontWeight.w600,
        height: 1.0,
      ),
    );
  }

  // بناء الكنتينر الأيسر - البيانات فقط
  Widget _buildContentContainer() {
    final localDate = TimezoneService.toLocal(
      widget.appointment.appointmentDate,
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(color: Colors.white),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // المنطقة
          _buildDataValue(widget.appointment.region ?? '-'),
          const SizedBox(height: 12),

          // المبنى
          _buildDataValue(widget.appointment.building ?? '-'),
          const SizedBox(height: 12),

          // التاريخ الميلادي
          _buildDataValue(_formatGregorianDate(localDate)),
          const SizedBox(height: 12),

          // التاريخ الهجري
          _buildDataValue(_formatHijriDate(localDate)),
          const SizedBox(height: 12),

          // الوقت
          _buildDataValue(TimezoneService.formatTime12Hour(localDate)),
          const SizedBox(height: 12),

          // المدة
          _buildDataValue(_formatDuration(widget.appointment.duration)),
          const SizedBox(height: 12),

          // الغروب
          _buildDataValue(_getSunsetTime(localDate)),
        ],
      ),
    );
  }

  // بناء قيمة البيانات (سطر واحد مع اختصار)
  Widget _buildDataValue(String value) {
    return Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 15, // تكبير من 14 إلى 15
        color: Colors.black87,
        fontWeight: FontWeight.w500,
        height: 1.0,
      ),
    );
  }

  // بناء الكنتينر السفلي الممتد
  Widget _buildBottomContainer() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'المشاركون:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade900,
            ),
          ),
          const SizedBox(height: 10),

          // المنظم (المنشئ) أولاً
          if (widget.host != null)
            _buildParticipantStatus(widget.host!, isHost: true),

          // باقي الضيوف
          ...widget.guests.map(
            (guest) => Padding(
              padding: const EdgeInsets.only(top: 6),
              child: _buildParticipantStatus(guest),
            ),
          ),

          // زر إضافة مشارك (فقط للمضيف)
          if (_isCurrentUserHost && !widget.isFromArchive) ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: _showAddParticipantDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade300, width: 1.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_add, color: Colors.green.shade700, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'إضافة مشارك',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // بناء حالة مشارك
  Widget _buildParticipantStatus(UserModel user, {bool isHost = false}) {
    final invitation = widget.invitations.firstWhere(
      (inv) => inv.guestId == user.id,
      orElse: () => InvitationModel(
        id: '',
        appointmentId: widget.appointment.id,
        guestId: user.id,
        status: 'invited',
        created: DateTime.now(),
        updated: DateTime.now(),
      ),
    );

    // الحصول على حالة المشارك من participantsStatus
    final participantStatus = widget.participantsStatus?[user.id];
    
    // تحديد اللون بناءً على الحالة
    final appointmentDate = widget.appointment.appointmentDate;
    final now = DateTime.now();
    final appointmentPassed = now.isAfter(appointmentDate);
    
    Color ringColor;
    if (participantStatus != null) {
      if (participantStatus.status.toLowerCase() == 'deleted') {
        // فحص إذا حذف قبل أو بعد الموعد
        final deletedBeforeAppointment = participantStatus.deletedAt != null && 
                                         participantStatus.deletedAt!.isBefore(appointmentDate);
        
        if (deletedBeforeAppointment) {
          ringColor = const Color(0xFFE57373); // أحمر: غائب (حذف قبل الموعد)
        } else if (appointmentPassed) {
          ringColor = Colors.green; // أخضر: منجز (حذف بعد الموعد)
        } else {
          ringColor = Colors.blue; // أزرق: نشط
        }
      } else if (participantStatus.status.toLowerCase() == 'archived') {
        ringColor = Colors.grey; // رمادي: مؤرشف
      } else {
        // active
        if (appointmentPassed) {
          ringColor = Colors.green; // أخضر: منجز
        } else {
          ringColor = Colors.blue; // أزرق: نشط
        }
      }
    } else {
      // إذا لم تكن البيانات متاحة، استخدم حالة الدعوة
      if (invitation.status == 'invited') {
        ringColor = Colors.grey; // رمادي: انتظار
      } else if (invitation.status == 'accepted') {
        if (appointmentPassed) {
          ringColor = Colors.green; // أخضر: منجز
        } else {
          ringColor = Colors.blue; // أزرق: وافق
        }
      } else if (invitation.status == 'rejected') {
        ringColor = Colors.grey; // رمادي: رفض
      } else {
        ringColor = Colors.grey; // رمادي: افتراضي
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // اسم المشارك مع الصورة
        Row(
          children: [
            // صورة المشارك
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: ringColor,
                  width: 2,
                ),
              ),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey.shade100,
                backgroundImage: (user.avatar?.isNotEmpty ?? false)
                    ? NetworkImage(_getUserAvatarUrl(user))
                    : null,
                child: (user.avatar?.isEmpty ?? true)
                    ? Icon(Icons.person, size: 20, color: Colors.grey.shade400)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            // الاسم مع اللقب
            Expanded(
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: user.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    if (isHost)
                      TextSpan(
                        text: ' (المنظم)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: Colors.grey.shade500,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        // التسجيلات
        Padding(
          padding: const EdgeInsets.only(right: 52),
          child: _buildStatusTimeline(user, invitation),
        ),
      ],
    );
  }

  // بناء سطر التسجيلات
  Widget _buildStatusTimeline(UserModel user, InvitationModel invitation) {
    final participantStatus = widget.participantsStatus?[user.id];
    final isHost = user.id == widget.appointment.hostId;
    
    // ✅ تحويل جميع التواريخ للتوقيت المحلي
    final localAppointmentDate = TimezoneService.toLocal(widget.appointment.appointmentDate);
    final now = DateTime.now();
    final appointmentPassed = now.isAfter(localAppointmentDate);
    
    List<InlineSpan> eventSpans = [];

    if (isHost) {
      // المضيف: متى أنشأ (دائماً)
      eventSpans.add(WidgetSpan(
        child: Icon(Icons.add_circle_outline, size: 14, color: Colors.green),
      ));
      eventSpans.add(TextSpan(text: ' أنشأ: ${_getTimeRelativeToAppointmentShort(widget.appointment.created)}'));
      
      // فحص إذا حذف قبل الموعد (مع تحويل deletedAt للتوقيت المحلي)
      final localDeletedAt = participantStatus?.deletedAt != null 
          ? TimezoneService.toLocal(participantStatus!.deletedAt!)
          : null;
      final deletedBeforeAppointment = localDeletedAt != null && 
                                       localDeletedAt.isBefore(localAppointmentDate);
      
      if (deletedBeforeAppointment) {
        // حذف قبل الموعد = غائب (نسجل الحذف فقط)
        eventSpans.add(TextSpan(text: '، '));
        eventSpans.add(WidgetSpan(
          child: Icon(Icons.cancel, size: 14, color: Colors.red),
        ));
        eventSpans.add(TextSpan(text: ' حذف: ${_getTimeRelativeToAppointmentShort(participantStatus!.deletedAt!)}'));
      } else if (appointmentPassed) {
        // أدرك الموعد = منجز (لا نسجل الحذف بعد الموعد)
        eventSpans.add(TextSpan(text: '، '));
        eventSpans.add(WidgetSpan(
          child: Icon(Icons.check_circle, size: 14, color: Colors.green),
        ));
        eventSpans.add(TextSpan(text: ' منجز'));
      }
    } else {
      // الضيف
      print('🔍 ضيف: ${user.name}');
      print('   invitation.status: ${invitation.status}');
      print('   invitation.respondedAt: ${invitation.respondedAt}');
      print('   participantStatus?.deletedAt: ${participantStatus?.deletedAt}');
      
      // الضيف: متى وافق (دائماً إذا وافق)
      if (invitation.respondedAt != null && invitation.status == 'accepted') {
        eventSpans.add(WidgetSpan(
          child: Icon(Icons.check_circle_outline, size: 14, color: Colors.blue),
        ));
        eventSpans.add(TextSpan(text: ' وافق: ${_getTimeRelativeToAppointmentShort(invitation.respondedAt!)}'));
      }
      
      // فحص إذا حذف قبل الموعد (مع تحويل deletedAt للتوقيت المحلي)
      final localDeletedAt = participantStatus?.deletedAt != null 
          ? TimezoneService.toLocal(participantStatus!.deletedAt!)
          : null;
      final deletedBeforeAppointment = localDeletedAt != null && 
                                       localDeletedAt.isBefore(localAppointmentDate);
      
      if (deletedBeforeAppointment) {
        // حذف قبل الموعد = غائب (نسجل الحذف فقط)
        if (eventSpans.isNotEmpty) {
          eventSpans.add(TextSpan(text: '، '));
        }
        eventSpans.add(WidgetSpan(
          child: Icon(Icons.cancel, size: 14, color: Colors.red),
        ));
        eventSpans.add(TextSpan(text: ' حذف: ${_getTimeRelativeToAppointmentShort(participantStatus!.deletedAt!)}'));
      } else if (appointmentPassed && invitation.status == 'accepted') {
        // أدرك الموعد = منجز (لا نسجل الحذف بعد الموعد)
        if (eventSpans.isNotEmpty) {
          eventSpans.add(TextSpan(text: '، '));
        }
        eventSpans.add(WidgetSpan(
          child: Icon(Icons.check_circle, size: 14, color: Colors.green),
        ));
        eventSpans.add(TextSpan(text: ' منجز'));
      }
      
      print('   عدد الأحداث: ${eventSpans.length}');
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: RichText(
        text: TextSpan(
          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          children: eventSpans,
        ),
      ),
    );
  }

  // بناء عنصر في التايملاين
  Widget _buildTimelineItem(
    IconData icon,
    Color color,
    String label,
    DateTime date,
  ) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          '$label: ${_getTimeRelativeToAppointment(date)}',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
        ),
      ],
    );
  }

  // معلومات الحالة
  Map<String, dynamic> _getStatusInfo(String status) {
    switch (status) {
      case 'accepted':
        return {
          'icon': Icons.check_circle,
          'color': Colors.green,
          'text': 'وافق',
        };
      case 'declined':
        return {'icon': Icons.cancel, 'color': Colors.red, 'text': 'رفض'};
      case 'deleted':
        return {'icon': Icons.delete, 'color': Colors.orange, 'text': 'حذف'};
      case 'invited':
      default:
        return {
          'icon': Icons.schedule,
          'color': Colors.grey,
          'text': 'لم يرد بعد',
        };
    }
  }

  // حساب المدة بالنسبة لوقت الموعد (نسخة مختصرة)
  String _getTimeRelativeToAppointmentShort(DateTime actionDate) {
    try {
      // ✅ تحويل التواريخ للتوقيت المحلي أولاً
      final localAppointmentDate = TimezoneService.toLocal(widget.appointment.appointmentDate);
      final localActionDate = TimezoneService.toLocal(actionDate);
      
      final difference = localAppointmentDate.difference(localActionDate);

      if (difference.isNegative) {
        // الإجراء حدث بعد الموعد
        final absDiff = difference.abs();
        if (absDiff.inDays > 0) {
          final hours = absDiff.inHours % 24;
          if (hours > 0) {
            return 'بعد بـ${absDiff.inDays}ي و${hours}س';
          }
          return 'بعد بـ${absDiff.inDays}ي';
        } else if (absDiff.inHours > 0) {
          final minutes = absDiff.inMinutes % 60;
          if (minutes > 0) {
            return 'بعد بـ${absDiff.inHours}س و${minutes}د';
          }
          return 'بعد بـ${absDiff.inHours}س';
        } else {
          return 'بعد بـ${absDiff.inMinutes}د';
        }
      } else {
        // الإجراء حدث قبل الموعد
        if (difference.inDays > 0) {
          final hours = difference.inHours % 24;
          if (hours > 0) {
            return 'قبل بـ${difference.inDays}ي و${hours}س';
          }
          return 'قبل بـ${difference.inDays}ي';
        } else if (difference.inHours > 0) {
          final minutes = difference.inMinutes % 60;
          if (minutes > 0) {
            return 'قبل بـ${difference.inHours}س و${minutes}د';
          }
          return 'قبل بـ${difference.inHours}س';
        } else {
          return 'قبل بـ${difference.inMinutes}د';
        }
      }
    } catch (e) {
      return 'غير متاح';
    }
  }

  // حساب المدة بالنسبة لوقت الموعد (ثابتة)
  String _getTimeRelativeToAppointment(DateTime actionDate) {
    try {
      final appointmentDate = widget.appointment.appointmentDate;
      final difference = appointmentDate.difference(actionDate);

      if (difference.isNegative) {
        // الإجراء حدث بعد الموعد
        final absDiff = difference.abs();
        if (absDiff.inDays > 0) {
          return 'بعد الموعد بـ ${absDiff.inDays} ${absDiff.inDays == 1 ? 'يوم' : 'أيام'}';
        } else if (absDiff.inHours > 0) {
          return 'بعد الموعد بـ ${absDiff.inHours} ${absDiff.inHours == 1 ? 'ساعة' : 'ساعات'}';
        } else {
          return 'بعد الموعد';
        }
      } else {
        // الإجراء حدث قبل الموعد
        if (difference.inDays > 0) {
          return 'قبل الموعد بـ ${difference.inDays} ${difference.inDays == 1 ? 'يوم' : 'أيام'}';
        } else if (difference.inHours > 0) {
          return 'قبل الموعد بـ ${difference.inHours} ${difference.inHours == 1 ? 'ساعة' : 'ساعات'}';
        } else {
          return 'قبل الموعد';
        }
      }
    } catch (e) {
      return 'غير متاح';
    }
  }

  // دالة الحصول على وقت الغروب
  String _getSunsetTime(DateTime date) {
    try {
      // استخدام SunsetService للحصول على وقت الغروب الفعلي
      final sunsetTime = SunsetService.getSunsetTime(date);
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
    } catch (e) {
      print('❌ خطأ في الحصول على وقت الغروب: $e');
      return 'غير متاح';
    }
  }

  // تنسيق التاريخ الميلادي
  String _formatGregorianDate(DateTime date) {
    const weekdays = [
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد',
    ];
    
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
    
    // فحص نوع التاريخ الأساسي
    final dateType = widget.appointment.dateType ?? 'gregorian';
    
    DateTime displayDate;
    
    if (dateType == 'hijri' || dateType == 'هجري') {
      // ✅ التاريخ الأساسي هجري → الميلادي ثانوي (نحسبه من الهجري مع عكس التصحيح)
      final hijriDay = widget.appointment.hijriDay;
      final hijriMonth = widget.appointment.hijriMonth;
      final hijriYear = widget.appointment.hijriYear;
      
      if (hijriDay != null && hijriMonth != null && hijriYear != null) {
        final currentUserAdjustment = _authService.currentUser?.hijriAdjustment ?? 0;
        // نحول الهجري إلى ميلادي مع عكس إشارة التصحيح
        displayDate = DateConverter.componentsToGregorian(
          hijriYear,
          hijriMonth, 
          hijriDay,
          adjustment: -currentUserAdjustment, // عكس الإشارة
        );
      } else {
        displayDate = date; // fallback
      }
    } else {
      // ✅ التاريخ الأساسي ميلادي → نعرضه كما هو (الوثيقة المخزنة)
      displayDate = date;
    }
    
    final weekday = weekdays[displayDate.weekday - 1];
    return '$weekday ${displayDate.day} ${months[displayDate.month - 1]} ${displayDate.year} ميلادي';
  }

  // تنسيق مدة الموعد
  String _formatDuration(int? minutes) {
    // إذا كانت null أو 0، استخدم 45 دقيقة كقيمة افتراضية
    if (minutes == null || minutes == 0) return '45 دقيقة';

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

  // تنسيق التاريخ الهجري
  String _formatHijriDate(DateTime date) {
    try {
      final hijriMonths = [
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

      // فحص نوع التاريخ الأساسي
      final dateType = widget.appointment.dateType ?? 'gregorian';
      
      print('🔍 DEBUG: dateType = $dateType');
      print('🔍 DEBUG: hijriDay = ${widget.appointment.hijriDay}');
      print('🔍 DEBUG: hijriMonth = ${widget.appointment.hijriMonth}');
      print('🔍 DEBUG: hijriYear = ${widget.appointment.hijriYear}');
      
      if (dateType == 'hijri' || dateType == 'هجري') {
        // ✅ التاريخ الأساسي هجري → نعرضه كما هو (الوثيقة المقدسة - بدون تصحيح أبداً)
        final hijriDay = widget.appointment.hijriDay;
        final hijriMonth = widget.appointment.hijriMonth;
        final hijriYear = widget.appointment.hijriYear;

        if (hijriDay != null && hijriMonth != null && hijriYear != null &&
            hijriDay > 0 && hijriMonth > 0 && hijriYear > 0) {
          print('✅ عرض الهجري الأساسي: $hijriDay ${hijriMonths[hijriMonth - 1]} $hijriYear');
          return '$hijriDay ${hijriMonths[hijriMonth - 1]} $hijriYear هـ';
        }
      } else {
        // ✅ التاريخ الأساسي ميلادي → الهجري ثانوي (يتأثر بتصحيح المستخدم الحالي)
        final currentUserAdjustment = _authService.currentUser?.hijriAdjustment ?? 0;
        print('✅ عرض الهجري الثانوي مع تصحيح: $currentUserAdjustment');
        final hijriDate = DateConverter.toHijri(
          date,
          adjustment: currentUserAdjustment,
        );
        return '${hijriDate.hDay} ${hijriMonths[hijriDate.hMonth - 1]} ${hijriDate.hYear} هـ';
      }

      // fallback
      return 'غير متاح';
    } catch (e) {
      return 'غير متاح';
    }
  }

  // بناء قسم رابط البث
  Widget _buildStreamLinkSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.link, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'رابط الموعد',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => _copyToClipboard(widget.appointment.streamLink!),
            child: Text(
              widget.appointment.streamLink!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.blue.shade700,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // بناء قسم الملاحظة العامة
  Widget _buildSharedNoteSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.note, color: Colors.amber.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'ملاحظة عامة',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.appointment.noteShared ?? '',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // بناء قسم الملاحظة الخاصة
  Widget _buildPrivateNoteSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.shade200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lock_outline, color: Colors.purple.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'ملاحظتي الخاصة',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple.shade900,
                ),
              ),
              const Spacer(),
              // مؤشر حالة الحفظ
              _buildSaveStatusIcon(),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            maxLines: 3,
            enabled: !widget.isFromArchive,
            decoration: InputDecoration(
              hintText: 'أضف ملاحظة خاصة...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.purple.shade200),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (value) {
              setState(() {
                _noteSaveStatus = 'unsaved';
              });
              // حفظ تلقائي بعد ثانية من التوقف عن الكتابة
              Future.delayed(const Duration(seconds: 1), () {
                if (_noteController.text == value) {
                  _savePrivateNote(value);
                }
              });
            },
          ),
        ],
      ),
    );
  }

  // بناء أيقونة حالة الحفظ
  Widget _buildSaveStatusIcon() {
    switch (_noteSaveStatus) {
      case 'saving':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.purple.shade700),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'جاري الحفظ...',
              style: TextStyle(
                fontSize: 12,
                color: Colors.purple.shade700,
              ),
            ),
          ],
        );
      case 'saved':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade600, size: 16),
            const SizedBox(width: 4),
            Text(
              'محفوظ',
              style: TextStyle(
                fontSize: 12,
                color: Colors.green.shade600,
              ),
            ),
          ],
        );
      case 'unsaved':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit, color: Colors.orange.shade600, size: 16),
            const SizedBox(width: 4),
            Text(
              'غير محفوظ',
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange.shade600,
              ),
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  // بناء أزرار الإجراءات
  Widget _buildActionButtons() {
    return Column(
      children: [
        // زر الأرشفة / إلغاء الأرشفة
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: widget.isFromArchive ? _handleUnarchive : _handleArchive,
            icon: Icon(widget.isFromArchive ? Icons.unarchive_outlined : Icons.archive_outlined),
            label: Text(
              widget.isFromArchive ? 'إلغاء الأرشفة' : 'أرشفة',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.isFromArchive ? Colors.green.shade400 : Colors.orange.shade400,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // زر الاستنساخ
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _handleClone,
            icon: const Icon(Icons.copy_outlined),
            label: const Text(
              'استنساخ',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade400,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // زر الحذف
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _handleDelete,
            icon: const Icon(Icons.delete_outline),
            label: const Text(
              'حذف',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // معالج الأرشفة
  Future<void> _handleArchive() async {
    // إظهار حوار التأكيد
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('أرشفة الموعد'),
        content: const Text(
          'هل أنت متأكد من أرشفة هذا الموعد؟\nسيتم نقله إلى الأرشيف ويمكنك استرجاعه لاحقاً.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('أرشفة'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // أرشفة الموعد للمستخدم الحالي
        await _statusService.archiveAppointmentForCurrentUser(
          widget.appointment.id,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ تم أرشفة الموعد بنجاح'),
              backgroundColor: Colors.orange,
            ),
          );

          // العودة للصفحة السابقة
          Navigator.pop(context, true); // true يعني تم الأرشفة
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ خطأ في أرشفة الموعد: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // معالج إلغاء الأرشفة
  Future<void> _handleUnarchive() async {
    // إظهار حوار التأكيد
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إلغاء أرشفة الموعد'),
        content: const Text(
          'هل أنت متأكد من إلغاء أرشفة هذا الموعد؟\nسيتم إرجاعه إلى قائمة المواعيد النشطة.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.green),
            child: const Text('إلغاء الأرشفة'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // إلغاء أرشفة الموعد للمستخدم الحالي
        await _statusService.restoreAppointmentForCurrentUser(
          widget.appointment.id,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ تم إلغاء أرشفة الموعد بنجاح'),
              backgroundColor: Colors.green,
            ),
          );

          // العودة للصفحة السابقة
          Navigator.pop(context, true); // true يعني تم إلغاء الأرشفة
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ خطأ في إلغاء أرشفة الموعد: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // معالج الاستنساخ
  void _handleClone() {
    // ✅ استنساخ ذكي للمواعيد السنوية
    // الفكرة: نستنسخ التاريخ الميلادي دائماً (اليوم والشهر فقط)
    // المستخدم يختار "هجري" إذا أراد، فيتحول تلقائياً في صفحة الإضافة
    
    // الانتقال إلى صفحة الإضافة مع البيانات المستنسخة
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => MainScreen(
          initialTabIndex: 2, // تبويب الإضافة
          clonedTitle: widget.appointment.title,
          clonedRegion: widget.appointment.region,
          clonedBuilding: widget.appointment.building,
          // ✅ نمرر التاريخ الميلادي دائماً (بغض النظر عن النوع الأصلي)
          clonedDate: widget.appointment.appointmentDate,
          clonedTime: TimezoneService.toLocal(
            widget.appointment.appointmentDate,
          ),
        ),
      ),
    );
  }

  // معالج الحذف
  Future<void> _handleDelete() async {
    // إظهار حوار التأكيد
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الموعد'),
        content: const Text(
          'هل أنت متأكد من حذف هذا الموعد؟\nلن يتم حذفه نهائياً، بل سينتقل إلى سلة المحذوفات.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // حذف الموعد للمستخدم الحالي
        await _statusService.deleteAppointmentForCurrentUser(
          widget.appointment.id,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ تم نقل الموعد إلى سلة المحذوفات'),
              backgroundColor: Colors.green,
            ),
          );

          // العودة للصفحة السابقة
          Navigator.pop(context, true); // true يعني تم الحذف
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ خطأ في حذف الموعد: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم نسخ: $text'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // عرض قائمة الأصدقاء لإضافة مشارك
  Future<void> _showAddParticipantDialog() async {
    try {
      // جلب قائمة الأصدقاء
      final currentUserId = _authService.currentUser?.id;
      if (currentUserId == null) return;

      final friendsResult = await _authService.pb.collection(AppConstants.friendshipCollection).getFullList(
        filter: '(follower = "$currentUserId" || following = "$currentUserId") && status = "approved"',
        expand: 'follower,following',
      );

      // استخراج الأصدقاء
      List<UserModel> friends = [];
      for (var record in friendsResult) {
        final followerId = record.data['follower'] as String;
        final followingId = record.data['following'] as String;
        
        // الصديق هو الطرف الآخر
        final friendId = followerId == currentUserId ? followingId : followerId;
        
        // التحقق من أنه ليس مشاركاً بالفعل
        final isAlreadyParticipant = widget.guests.any((g) => g.id == friendId) || 
                                      widget.host?.id == friendId;
        
        if (!isAlreadyParticipant) {
          final expand = record.expand;
          if (expand != null) {
            final friendData = followerId == currentUserId 
                ? expand['following']?.first 
                : expand['follower']?.first;
            
            if (friendData != null) {
              friends.add(UserModel.fromJson(friendData.toJson()));
            }
          }
        }
      }

      if (!mounted) return;

      if (friends.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا يوجد أصدقاء متاحين للإضافة'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // عرض قائمة الأصدقاء
      await showDialog(
        context: context,
        builder: (context) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('إضافة مشارك'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: friends.length,
                itemBuilder: (context, index) {
                  final friend = friends[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: (friend.avatar?.isNotEmpty ?? false)
                          ? NetworkImage(_getUserAvatarUrl(friend))
                          : null,
                      child: (friend.avatar?.isEmpty ?? true)
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    title: Text(friend.name),
                    subtitle: Text('@${friend.username}'),
                    onTap: () {
                      Navigator.pop(context);
                      _inviteFriend(friend);
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ خطأ في جلب الأصدقاء: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // دعوة صديق للموعد
  Future<void> _inviteFriend(UserModel friend) async {
    try {
      // إنشاء دعوة جديدة
      await _authService.pb.collection(AppConstants.invitationsCollection).create(
        body: {
          'appointment': widget.appointment.id,
          'guest': friend.id,
          'status': 'invited',
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ تمت دعوة ${friend.name} بنجاح'),
            backgroundColor: Colors.green,
          ),
        );

        // إعادة تحميل الصفحة
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ خطأ في إرسال الدعوة: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // دوال مساعدة
  String _getUserAvatarUrl(UserModel user) {
    if (user.avatar?.isEmpty ?? true) return '';
    return '${AppConstants.pocketbaseUrl}/api/files/users/${user.id}/${user.avatar}';
  }
}
