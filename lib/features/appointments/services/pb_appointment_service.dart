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
  static final Set<String> _activeClaims = {};

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
      // ملاحظة: نعرض المواعيد حتى لو كانت is_cancelled أو is_deleted على السجل المركزي
      // لأن الضيوف يجب أن يروا الطوق الأحمر/الرمادي — نسخهم الشخصية لم تُحذف

      final resultList = await _pb.collection(collectionInvitations).getList(
        page: page,
        perPage: perPage,
        filter: filter,
        sort: '+appointment.start_at', 
        expand: 'appointment,appointment.host,appointment.invitations_via_appointment.user,appointment.invitations_via_appointment.categories,categories,appointment.invitations_via_appointment.linked_article',
      );

      final Set<String> seenApptIds = {};
      final List<Appointment> appointments = [];

      for (var record in resultList.items) {
        final invitationJson = record.toJson();
        var appData = invitationJson['expand']?['appointment'];
        if (appData is List && appData.isNotEmpty) appData = appData.first;
        final appointmentJson = appData is Map<String, dynamic> ? appData : null;
        
        if (appointmentJson == null) continue;

        final apptId = appointmentJson['id'] as String?;
        if (apptId == null) continue;
        if (seenApptIds.contains(apptId)) continue;
        seenApptIds.add(apptId);

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

        appointments.add(Appointment.fromJson(appointmentJson, contextAdjustment: contextAdjustment));
      }

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
  Future<Appointment> createAppointment(
    Appointment appointment, {
    List<String>? inviteeIds,
    List<Map<String, String>>? phoneInvitees,
    String? inviteTitle,
    String? inviteMessage,
    int contextAdjustment = 0,
  }) async {
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
      // الخصوصية تُخزَّن في الموعد الرئيسي (appointments) أيضاً لتفعيل قواعد العرض للزوار
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
        'accepted_at': DateTime.now().toUtc().toIso8601String(),
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

      if (phoneInvitees != null) {
        for (final guest in phoneInvitees) {
          final phone = guest['phone'];
          final name = guest['name'] ?? '';
          if (phone != null && phone.isNotEmpty) {
            await _pb.collection(collectionInvitations).create(body: {
              'appointment': apptId,
              'invited_phone': phone,
              'invited_name': name,
              'user': null,
              'status': 'pending',
              'post_status': 'published',
              'privacy': appointment.privacy,
            });
          }
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

  /// إلغاء/حذف الموعد من قِبل المستضيف
  /// القاعدة: المستضيف يحذف نسخته الشخصية فقط.
  /// التغيير الوحيد على الآخرين هو تحديث السجل المركزي (is_cancelled أو is_deleted)
  /// بحيث يرون الطوق الأحمر/الرمادي — لكن نسخهم لا تُحذف أبداً.
  Future<void> cancelAppointment(String id, {String? cancelTitle, String? cancelMessage, String? personalNote}) async {
    try {
      final invites = await _pb.collection(collectionInvitations).getFullList(
        filter: 'appointment = "$id"',
      );

      // هل وافق أحد الضيوف؟ (غير المستضيف)
      final hostId = _pb.authStore.record?.id;
      final hasAcceptedGuest = invites.any((inv) =>
        inv.data['status'] == 'accepted' &&
        inv.data['user'] != hostId,
      );

      // تحديث السجل المركزي فقط:
      // - لا أحد قبل → is_cancelled (طوق رمادي عند الضيوف)
      // - أحدهم قبل  → is_deleted  (طوق أحمر عند الضيوف)
      await _pb.collection(collectionAppointments).update(id, body: {
        'is_cancelled': !hasAcceptedGuest,
        'is_deleted': hasAcceptedGuest,
      });

      // حذف نسخة المستضيف الشخصية فقط
      final hostInvite = invites.firstWhere(
        (inv) => inv.data['user'] == hostId,
        orElse: () => invites.first, // fallback آمن
      );

      try {
        await _pb.collection(collectionInvitations).update(hostInvite.id, body: {
          'post_status': 'trash',
          'deleted_at': DateTime.now().toUtc().toIso8601String(),
        });
      } catch (e) {
        print('⚠️ Could not trash host invitation: $e');
      }

      // إرسال إشعار للضيوف الذين قبلوا فقط
      for (final inv in invites) {
        final userId = inv.data['user'];
        if (userId != null && userId != hostId) {
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

  Future<Appointment> getAppointmentById(String id, {int contextAdjustment = 0}) async {
    final record = await _pb.collection(collectionAppointments).getOne(
      id,
      expand: 'host,invitations_via_appointment.user,invitations_via_appointment.linked_article',
    );
    return Appointment.fromJson(record.toJson(), contextAdjustment: contextAdjustment);
  }

  /// تحديث حالة نشاط رابط الدعوة (تفعيل أو تعطيل)
  Future<bool> updateInviteLinkStatus(String appointmentId, bool active, {String? inviteToken}) async {
    try {
      final body = <String, dynamic>{
        'invite_link_active': active,
      };
      if (inviteToken != null) {
        body['invite_token'] = inviteToken;
      }
      await _pb.collection(collectionAppointments).update(appointmentId, body: body);
      return true;
    } catch (e) {
      print('⚠️ Failed to update invite link status: $e');
      return false;
    }
  }

  /// ربط المستخدم الجديد بالموعد من خلال التوكن
  Future<bool> claimAppointmentByToken(String token, String userId) async {
    final lockKey = '$token-$userId';
    if (_activeClaims.contains(lockKey)) {
      print('🔒 Claim already in progress for $lockKey. Skipping duplicate call.');
      return true;
    }
    _activeClaims.add(lockKey);
    try {
      // 1. Get the appointment by token
      final result = await _pb.collection(collectionAppointments).getFirstListItem(
        'invite_token = "$token" && invite_link_active = true',
        expand: 'host',
      );
      
      final apptId = result.id;
      final hostId = result.getStringValue('host');

      // 2. Check if an invitation already exists to avoid duplicates
      try {
        final existing = await _pb.collection(collectionInvitations).getFirstListItem(
          'appointment = "$apptId" && user = "$userId"',
        );
        if (existing.id.isNotEmpty) {
          final String status = existing.getStringValue('status');
          // وثيقة مرصودة ومقدسة (accepted or deleted_after_accept): لا تنعش ولا تتكرر
          if (status == 'accepted' || status == 'deleted_after_accept') {
            return true;
          }
          // الحالة الوحيدة التي تنعش الطلب ويتم تحديثها هي الحذف/الرفض قبل القبول
          await _pb.collection(collectionInvitations).update(existing.id, body: {
            'status': 'pending',
            'post_status': 'published',
          });
          return true;
        }
      } catch (_) {}

      // 3. Create a new invitation for the user
      await _pb.collection(collectionInvitations).create(body: {
        'appointment': apptId,
        'user': userId,
        'status': 'pending',
        'post_status': 'published',
        'privacy': 'private',
      });

      // 4. Send a notification to the host
      final guestRecord = await _pb.collection('users').getOne(userId);
      final guestName = guestRecord.data['name'] ?? 'عضو جديد';
      final apptTitle = result.getStringValue('title');
      
      try {
        await _notificationService.createNotification(
          targetUserId: hostId,
          title: 'تسجيل ضيف جديد للموعد',
          message: 'سجل الضيف ($guestName) حسابه من خلال رابط دعوتك لموعد: $apptTitle',
          type: NotificationType.invite,
          relatedId: apptId,
        );
      } catch (_) {}

      return true;
    } catch (e) {
      print('⚠️ Failed to claim appointment by token: $e');
      return false;
    } finally {
      _activeClaims.remove(lockKey);
    }
  }

  /// إرسال نكزة (PING) إلى مستخدم معين
  Future<bool> sendPing({
    required String appointmentId,
    required String targetUserId,
    required String hostName,
  }) async {
    try {
      final appt = await getAppointmentById(appointmentId);
      final apptTitle = appt.title;
      
      await _notificationService.createNotification(
        targetUserId: targetUserId,
        title: 'PING!!! ⚡',
        message: 'ينكزك ($hostName) للرد على دعوة الموعد: $apptTitle',
        type: NotificationType.invite,
        relatedId: appointmentId,
      );
      return true;
    } catch (e) {
      print('⚠️ Failed to send ping notification: $e');
      return false;
    }
  }
}
