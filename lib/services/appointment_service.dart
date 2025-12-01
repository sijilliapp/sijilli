import 'package:uuid/uuid.dart';
import '../config/constants.dart';
import '../models/appointment_model.dart';
import '../models/invitation_model.dart';
import '../services/auth_service.dart';

class AppointmentService {
  final AuthService _authService;
  final _uuid = const Uuid();

  AppointmentService(this._authService);

  // إنشاء موعد جديد مع دعوات الضيوف
  Future<AppointmentModel> createAppointment({
    required String title,
    String? region,
    String? building,
    required String privacy,
    required DateTime appointmentDate,
    String? dateType,
    int? hijriDay,
    int? hijriMonth,
    int? hijriYear,
    String? timeString,
    int? duration,
    String? streamLink,
    String? noteShared,
    List<String> guestIds = const [],
  }) async {
    final currentUserId = _authService.currentUser?.id;
    if (currentUserId == null) {
      throw Exception('لا يوجد مستخدم مسجل دخول');
    }

    try {
      // 1. إنشاء UUID مشترك للموعد
      final appointmentGroupId = _uuid.v4();

      // 2. إنشاء سجل المضيف في appointments
      final hostRecord = await _authService.pb
          .collection(AppConstants.appointmentsCollection)
          .create(
            body: {
              'userId': currentUserId,
              'appointmentGroupId': appointmentGroupId,
              'isHost': true,
              'status': 'active',
              'title': title,
              'region': region,
              'building': building,
              'privacy': privacy,
              'appointment_date': appointmentDate.toIso8601String(),
              'date_type': dateType,
              'hijri_day': hijriDay,
              'hijri_month': hijriMonth,
              'hijri_year': hijriYear,
              'time_string': timeString,
              'duration': duration,
              'stream_link': streamLink,
              'note_shared': noteShared,
            },
          );

      print('✅ تم إنشاء سجل المضيف: ${hostRecord.id}');

      // 3. إنشاء دعوات للضيوف
      for (final guestId in guestIds) {
        await _authService.pb
            .collection(AppConstants.invitationsCollection)
            .create(
              body: {
                'appointmentGroupId': appointmentGroupId,
                'appointment': null, // null لأنه لم يقبل بعد
                'guest': guestId,
                'status': 'pending',
              },
            );
      }

      print('✅ تم إنشاء ${guestIds.length} دعوة للضيوف');

      return AppointmentModel.fromJson(hostRecord.toJson());
    } catch (e) {
      print('❌ خطأ في إنشاء الموعد: $e');
      rethrow;
    }
  }

  // قبول دعوة وإنشاء سجل للضيف
  Future<AppointmentModel> acceptInvitation({
    required String invitationId,
    required String appointmentGroupId,
    required String title,
    String? region,
    String? building,
    required String privacy,
    required DateTime appointmentDate,
    String? dateType,
    int? hijriDay,
    int? hijriMonth,
    int? hijriYear,
    String? timeString,
    int? duration,
    String? streamLink,
    String? noteShared,
  }) async {
    final currentUserId = _authService.currentUser?.id;
    if (currentUserId == null) {
      throw Exception('لا يوجد مستخدم مسجل دخول');
    }

    try {
      // 1. إنشاء سجل للضيف في appointments
      final guestRecord = await _authService.pb
          .collection(AppConstants.appointmentsCollection)
          .create(
            body: {
              'userId': currentUserId,
              'appointmentGroupId': appointmentGroupId,
              'isHost': false,
              'status': 'active',
              'title': title,
              'region': region,
              'building': building,
              'privacy': privacy, // الضيف يبدأ بخصوصية عامة
              'appointment_date': appointmentDate.toIso8601String(),
              'date_type': dateType,
              'hijri_day': hijriDay,
              'hijri_month': hijriMonth,
              'hijri_year': hijriYear,
              'time_string': timeString,
              'duration': duration,
              'stream_link': streamLink,
              'note_shared': noteShared,
            },
          );

      print('✅ تم إنشاء سجل الضيف: ${guestRecord.id}');

      // 2. تحديث الدعوة
      await _authService.pb
          .collection(AppConstants.invitationsCollection)
          .update(
            invitationId,
            body: {
              'appointment': guestRecord.id,
              'status': 'accepted',
              'respondedAt': DateTime.now().toIso8601String(),
            },
          );

      print('✅ تم تحديث حالة الدعوة إلى accepted');

      return AppointmentModel.fromJson(guestRecord.toJson());
    } catch (e) {
      print('❌ خطأ في قبول الدعوة: $e');
      rethrow;
    }
  }

  // رفض دعوة
  Future<void> rejectInvitation(String invitationId) async {
    try {
      await _authService.pb
          .collection(AppConstants.invitationsCollection)
          .update(
            invitationId,
            body: {
              'status': 'rejected',
              'respondedAt': DateTime.now().toIso8601String(),
            },
          );

      print('✅ تم رفض الدعوة');
    } catch (e) {
      print('❌ خطأ في رفض الدعوة: $e');
      rethrow;
    }
  }

  // حذف موعد (soft delete)
  Future<void> deleteAppointment(String appointmentId, bool isHost) async {
    try {
      // 1. تحديث حالة السجل إلى deleted
      await _authService.pb
          .collection(AppConstants.appointmentsCollection)
          .update(
            appointmentId,
            body: {
              'status': 'deleted',
              'deletedAt': DateTime.now().toIso8601String(),
            },
          );

      print('✅ تم حذف الموعد (soft delete)');

      // 2. إذا كان ضيف، تحديث حالة الدعوة
      if (!isHost) {
        final currentUserId = _authService.currentUser?.id;
        if (currentUserId != null) {
          // البحث عن الدعوة
          final invitations = await _authService.pb
              .collection(AppConstants.invitationsCollection)
              .getFullList(
                filter:
                    'appointment = "$appointmentId" && guest = "$currentUserId"',
              );

          if (invitations.isNotEmpty) {
            await _authService.pb
                .collection(AppConstants.invitationsCollection)
                .update(
                  invitations.first.id,
                  body: {'status': 'deleted_after_accepted'},
                );
            print('✅ تم تحديث حالة الدعوة إلى deleted_after_accepted');
          }
        }
      }
    } catch (e) {
      print('❌ خطأ في حذف الموعد: $e');
      rethrow;
    }
  }

  // استرجاع موعد محذوف
  Future<void> restoreAppointment(String appointmentId, bool isHost) async {
    try {
      // 1. تحديث حالة السجل إلى active
      await _authService.pb
          .collection(AppConstants.appointmentsCollection)
          .update(appointmentId, body: {'status': 'active', 'deletedAt': null});

      print('✅ تم استرجاع الموعد');

      // 2. إذا كان ضيف، تحديث حالة الدعوة
      if (!isHost) {
        final currentUserId = _authService.currentUser?.id;
        if (currentUserId != null) {
          final invitations = await _authService.pb
              .collection(AppConstants.invitationsCollection)
              .getFullList(
                filter:
                    'appointment = "$appointmentId" && guest = "$currentUserId"',
              );

          if (invitations.isNotEmpty) {
            await _authService.pb
                .collection(AppConstants.invitationsCollection)
                .update(invitations.first.id, body: {'status': 'accepted'});
            print('✅ تم تحديث حالة الدعوة إلى accepted');
          }
        }
      }
    } catch (e) {
      print('❌ خطأ في استرجاع الموعد: $e');
      rethrow;
    }
  }

  // أرشفة موعد
  Future<void> archiveAppointment(String appointmentId) async {
    try {
      await _authService.pb
          .collection(AppConstants.appointmentsCollection)
          .update(appointmentId, body: {'status': 'archived'});

      print('✅ تم أرشفة الموعد');
    } catch (e) {
      print('❌ خطأ في أرشفة الموعد: $e');
      rethrow;
    }
  }

  // تحديث خصوصية موعد
  Future<void> updateAppointmentPrivacy(
    String appointmentId,
    String privacy,
  ) async {
    try {
      await _authService.pb
          .collection(AppConstants.appointmentsCollection)
          .update(appointmentId, body: {'privacy': privacy});

      print('✅ تم تحديث خصوصية الموعد إلى $privacy');
    } catch (e) {
      print('❌ خطأ في تحديث خصوصية الموعد: $e');
      rethrow;
    }
  }

  // تحديث ملاحظة خاصة
  Future<void> updatePrivateNote(String appointmentId, String? note) async {
    try {
      await _authService.pb
          .collection(AppConstants.appointmentsCollection)
          .update(appointmentId, body: {'myNote': note});

      print('✅ تم تحديث الملاحظة الخاصة');
    } catch (e) {
      print('❌ خطأ في تحديث الملاحظة الخاصة: $e');
      rethrow;
    }
  }

  // جلب المواعيد النشطة للمستخدم الحالي
  Future<List<AppointmentModel>> getActiveAppointments() async {
    final currentUserId = _authService.currentUser?.id;
    if (currentUserId == null) return [];

    try {
      final records = await _authService.pb
          .collection(AppConstants.appointmentsCollection)
          .getFullList(
            filter: 'userId = "$currentUserId" && status = "active"',
            sort: '-appointment_date',
          );

      return records
          .map((record) => AppointmentModel.fromJson(record.toJson()))
          .toList();
    } catch (e) {
      print('❌ خطأ في جلب المواعيد النشطة: $e');
      return [];
    }
  }

  // جلب المواعيد المحذوفة للمستخدم الحالي
  Future<List<AppointmentModel>> getDeletedAppointments() async {
    final currentUserId = _authService.currentUser?.id;
    if (currentUserId == null) return [];

    try {
      final records = await _authService.pb
          .collection(AppConstants.appointmentsCollection)
          .getFullList(
            filter: 'userId = "$currentUserId" && status = "deleted"',
            sort: '-deletedAt',
          );

      return records
          .map((record) => AppointmentModel.fromJson(record.toJson()))
          .toList();
    } catch (e) {
      print('❌ خطأ في جلب المواعيد المحذوفة: $e');
      return [];
    }
  }

  // جلب المواعيد المؤرشفة للمستخدم الحالي
  Future<List<AppointmentModel>> getArchivedAppointments() async {
    final currentUserId = _authService.currentUser?.id;
    if (currentUserId == null) return [];

    try {
      final records = await _authService.pb
          .collection(AppConstants.appointmentsCollection)
          .getFullList(
            filter: 'userId = "$currentUserId" && status = "archived"',
            sort: '-appointment_date',
          );

      return records
          .map((record) => AppointmentModel.fromJson(record.toJson()))
          .toList();
    } catch (e) {
      print('❌ خطأ في جلب المواعيد المؤرشفة: $e');
      return [];
    }
  }

  // جلب موعد واحد بواسطة ID
  Future<AppointmentModel?> getAppointmentById(String appointmentId) async {
    try {
      final record = await _authService.pb
          .collection(AppConstants.appointmentsCollection)
          .getOne(appointmentId);

      return AppointmentModel.fromJson(record.toJson());
    } catch (e) {
      print('❌ خطأ في جلب الموعد: $e');
      return null;
    }
  }

  // جلب جميع سجلات موعد معين (مضيف + ضيوف)
  Future<List<AppointmentModel>> getAppointmentGroupRecords(
    String appointmentGroupId,
  ) async {
    try {
      final records = await _authService.pb
          .collection(AppConstants.appointmentsCollection)
          .getFullList(filter: 'appointmentGroupId = "$appointmentGroupId"');

      return records
          .map((record) => AppointmentModel.fromJson(record.toJson()))
          .toList();
    } catch (e) {
      print('❌ خطأ في جلب سجلات المجموعة: $e');
      return [];
    }
  }

  // حذف نهائي لموعد
  Future<void> permanentlyDeleteAppointment(String appointmentId) async {
    try {
      await _authService.pb
          .collection(AppConstants.appointmentsCollection)
          .delete(appointmentId);

      print('✅ تم الحذف النهائي للموعد');
    } catch (e) {
      print('❌ خطأ في الحذف النهائي: $e');
      rethrow;
    }
  }

  // حذف نهائي لجميع المواعيد المحذوفة
  Future<void> permanentlyDeleteAllDeletedAppointments() async {
    final currentUserId = _authService.currentUser?.id;
    if (currentUserId == null) {
      throw Exception('لا يوجد مستخدم مسجل دخول');
    }

    try {
      final deletedAppointments = await getDeletedAppointments();

      for (final appointment in deletedAppointments) {
        await permanentlyDeleteAppointment(appointment.id);
      }

      print('✅ تم الحذف النهائي لجميع المواعيد المحذوفة');
    } catch (e) {
      print('❌ خطأ في الحذف النهائي الجماعي: $e');
      rethrow;
    }
  }
}
