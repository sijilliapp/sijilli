import 'package:pocketbase/pocketbase.dart';
import '../../../core/services/pocketbase_client.dart';
import '../../../models/appointment.dart';
import '../../../models/user.dart';
import '../../../models/notification.dart';
import '../../notifications/services/notification_service.dart';

class PbAppointmentService {
  final PocketBase _pb = PocketBaseClient.instance.pb;
  final NotificationService _notificationService = NotificationService();
  PocketBase get pb => _pb;
  
  static const String collectionAppointments = 'appointments';
  static const String collectionInvitations = 'invitations';

  /// جلب جميع المواعيد التي يكون المستخدم جزءاً منها (من خلال جدول الدعوات/النسخ)
  Future<List<Appointment>> getAppointments({
    int page = 1, 
    int perPage = 50, 
    bool includePast = false, 
    String? userId,
    PostStatus status = PostStatus.published,
    int contextAdjustment = 0,
  }) async {
    try {
      final effectiveUserId = userId ?? _pb.authStore.record?.id;
      if (effectiveUserId == null) return [];

      String statusStr = status.toString().split('.').last;
      String filter = 'user = "$effectiveUserId" && post_status = "$statusStr"';

      final resultList = await _pb.collection(collectionInvitations).getList(
        page: page,
        perPage: perPage,
        filter: filter,
        sort: '+appointment.start_at', 
        expand: 'appointment,appointment.host,appointment.invitations_via_appointment.user,appointment.invitations_via_appointment.categories,categories',
      );

      final appointments = resultList.items.map((record) {
        final invitationJson = record.toJson();
        var appData = invitationJson['expand']?['appointment'];
        if (appData is List && appData.isNotEmpty) appData = appData.first;
        final appointmentJson = appData is Map<String, dynamic> ? appData : null;
        
        if (appointmentJson == null) return null;
        appointmentJson['currentUserInvitation'] = invitationJson;
        
        var invExpand = invitationJson['expand'];
        if (invExpand != null) {
           var appExpand = invExpand['appointment'];
           if (appExpand is List && appExpand.isNotEmpty) appExpand = appExpand.first;
           
           if (appExpand is Map<String, dynamic> && appExpand['expand'] != null) {
             var sourceExpand = appExpand['expand'] as Map<String, dynamic>;
             var currentExpand = appointmentJson['expand'];
             
             if (currentExpand is Map<String, dynamic>) {
               currentExpand.addAll(sourceExpand);
             } else {
               appointmentJson['expand'] = sourceExpand;
             }
           }
        }

        return Appointment.fromJson(appointmentJson, contextAdjustment: contextAdjustment);
      }).whereType<Appointment>().toList();

      for (var i = 0; i < appointments.length; i++) {
        if (appointments[i].host == null && appointments[i].hostId.isNotEmpty) {
          try {
            final hostRecord = await _pb.collection('users').getFirstListItem(
              'id = "${appointments[i].hostId}"',
            );
            appointments[i] = appointments[i].copyWith(
              host: UserModel.fromJson(hostRecord.toJson()),
            );
          } catch (e) {}
        }
      }

      return appointments;
    } catch (e) {
      print('⚠️ Failed to fetch appointments: $e');
      rethrow;
    }
  }

  /// إنشاء موعد جديد (سجل واحد رئيسي - Master Record)
  Future<Appointment> createAppointment(Appointment appointment, {List<String>? inviteeIds, String? inviteTitle, String? inviteMessage, int contextAdjustment = 0}) async {
    try {
      final userId = _pb.authStore.record?.id;
      if (userId == null) throw Exception('User not authenticated');

      int count = appointment.recurrenceCount ?? 1;
      if (count < 1) count = 1;
      if (count > 365) count = 365; 

      final String groupId = appointment.appointmentGroupId ?? 'group_${DateTime.now().millisecondsSinceEpoch}';

      final body = appointment.toJson();
      body.remove('id');
      body.remove('created');
      body.remove('updated');
      body['host'] = userId;
      body['appointmentGroupId'] = groupId;
      body['recurrence_type'] = appointment.recurrenceType ?? 'none';
      body['recurrence_count'] = count;
      body['recurrence_index'] = 1;
      
      final apptRecord = await _pb.collection(collectionAppointments).create(body: body);
      final apptId = apptRecord.id;

      final hostInv = await _pb.collection(collectionInvitations).create(body: {
        'appointment': apptId,
        'user': userId,
        'status': 'accepted',
        'post_status': 'published',
        'privacy': appointment.privacy,
        'accepted_at': DateTime.now().toIso8601String(),
      }, expand: 'appointment,appointment.host,categories');

      if (inviteeIds != null) {
        for (final guestId in inviteeIds) {
          await _pb.collection(collectionInvitations).create(body: {
            'appointment': apptId,
            'user': guestId,
            'status': 'pending',
            'post_status': 'published',
            'privacy': appointment.privacy,
          });

          final hostName = _pb.authStore.record?.data['name'] ?? 'User';
          try {
            await _notificationService.createNotification(
              targetUserId: guestId,
              title: inviteTitle ?? 'New Invitation',
              message: inviteMessage ?? '$hostName invited you to an appointment: ${appointment.title}',
              type: NotificationType.invite,
              relatedId: apptId,
            );
          } catch (e) {}
        }
      }

      final resultJson = apptRecord.toJson();
      resultJson['currentUserInvitation'] = hostInv.toJson();
      return Appointment.fromJson(resultJson, contextAdjustment: contextAdjustment);

    } catch (e) {
      print('⚠️ Failed to create appointment: $e');
      rethrow;
    }
  }

  Future<void> updateAppointment(String id, Map<String, dynamic> data) async {
    await _pb.collection(collectionAppointments).update(id, body: data);
  }

  /// إلغاء الموعد وتنبيه كافة الضيوف (للمضيف)
  Future<void> cancelAppointment(String id, {String? cancelTitle, String? cancelMessage, String? personalNote}) async {
    try {
      final invites = await _pb.collection(collectionInvitations).getFullList(
        filter: 'appointment = "$id"',
      );

      bool hasAcceptance = false;
      for (final inv in invites) {
        if (inv.data['status'] == 'accepted' && inv.data['user'] != _pb.authStore.record?.id) {
          hasAcceptance = true;
          break;
        }
      }

      await _pb.collection(collectionAppointments).update(id, body: {
        'is_deleted': hasAcceptance,
        'is_cancelled': !hasAcceptance,
      });

      for (final inv in invites) {
        try {
          String newStatus = 'declined';
          if (inv.data['status'] == 'accepted') {
            newStatus = 'deleted_after_accept';
          }

          await _pb.collection(collectionInvitations).update(inv.id, body: {
            'status': newStatus, 
            'post_status': 'trash',
            'personal_note': personalNote ?? 'Appointment cancelled by organizer',
          });
        } catch (e) {}

        final userId = inv.data['user'];
        if (userId != _pb.authStore.record?.id) {
           _sendCancelNotification(userId, id, title: cancelTitle, message: cancelMessage);
        }
      }
    } catch (e) {
      print('❌ Failed to cancel appointment: $e');
      rethrow;
    }
  }

  Future<void> _sendCancelNotification(String userId, String apptId, {String? title, String? message}) async {
    try {
      await _notificationService.createNotification(
        targetUserId: userId,
        title: title ?? 'Appointment Cancelled',
        message: message ?? 'The appointment was cancelled by the organizer',
        type: NotificationType.cancel,
        relatedId: apptId,
      );
    } catch (e) {}
  }

  Future<void> hardDeleteAppointment(String id) async {
    await _pb.collection(collectionAppointments).delete(id);
  }

  Future<Set<String>> getConflictingUserIds(List<String> userIds, DateTime start, int duration) async {
    try {
      if (userIds.isEmpty) return {};
      final end = start.add(Duration(minutes: duration));
      final endStr = end.toUtc().toIso8601String();
      final userFilter = userIds.map((id) => 'user = "$id"').join(' || ');
      final searchStartWindow = start.subtract(const Duration(hours: 24)).toUtc().toIso8601String();

      final resultList = await _pb.collection(collectionInvitations).getList(
        filter: '($userFilter) && post_status = "published" && status = "accepted" && appointment.start_at < "$endStr" && appointment.start_at > "$searchStartWindow"',
        expand: 'appointment',
        perPage: 100,
      );

      final Set<String> conflictingIds = {};
      for (final record in resultList.items) {
        final invJson = record.toJson();
        final apptJson = invJson['expand']?['appointment'] as Map<String, dynamic>?;
        if (apptJson == null) continue;
        
        try {
          final startAtStr = apptJson['start_at']?.toString();
          if (startAtStr == null || startAtStr.isEmpty) continue;
          final apptStart = DateTime.parse(startAtStr);
          final apptDuration = apptJson['duration'] as int? ?? 45;
          final apptEnd = apptStart.add(Duration(minutes: apptDuration));

          if (start.toUtc().isBefore(apptEnd) && end.toUtc().isAfter(apptStart)) {
            conflictingIds.add(invJson['user'] as String);
          }
        } catch (e) {}
      }
      return conflictingIds;
    } catch (e) {
      return {};
    }
  }

  Future<Set<String>> getInactiveAppointmentIds(List<String> appointmentIds) async {
    if (appointmentIds.isEmpty) return {};
    try {
      final filter = appointmentIds.map((id) => 'id="$id"').join('||');
      final result = await _pb.collection(collectionAppointments).getList(
        filter: '($filter)',
        fields: 'id,is_cancelled,is_deleted,start_at,duration',
      );
      final now = DateTime.now().toUtc();
      final inactiveIds = <String>{};
      for (var record in result.items) {
        final isCancelled = record.getBoolValue('is_cancelled');
        final isDeleted = record.getBoolValue('is_deleted');
        final startAt = DateTime.parse(record.getStringValue('start_at'));
        final duration = record.getIntValue('duration');
        final endAt = startAt.add(Duration(minutes: duration));
        if (isCancelled || isDeleted || now.isAfter(endAt)) {
          inactiveIds.add(record.id);
        }
      }
      return inactiveIds;
    } catch (e) {
      return {};
    }
  }

  Future<Set<String>> getArchivedOrTrashedIds(String userId, List<String> appointmentIds) async {
    if (appointmentIds.isEmpty) return {};
    try {
      final idsFilter = appointmentIds.map((id) => 'appointment = "$id"').join(' || ');
      final filter = 'user = "$userId" && ($idsFilter) && post_status != "published"';
      final records = await _pb.collection(collectionInvitations).getFullList(
        filter: filter,
        fields: 'appointment',
      );
      return records.map((r) => r.getStringValue('appointment')).toSet();
    } catch (e) {
      return {};
    }
  }
}
