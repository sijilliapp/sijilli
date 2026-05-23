import 'package:pocketbase/pocketbase.dart';
import '../../../core/services/pocketbase_client.dart';
import '../../../models/appointment.dart';
import '../../../models/notification.dart';
import '../../notifications/services/notification_service.dart';

class PbInvitationService {
  final PocketBase _pb = PocketBaseClient.instance.pb;
  final NotificationService _notificationService = NotificationService();
  static const String collectionAppointments = 'appointments';
  static const String collectionInvitations = 'invitations';

  Future<void> updateInvitationStatus(
    String invitationId, 
    InvitationStatus status, {
    PostStatus? postStatus,
    String? privacy,
    String? categoryId,
    String? personalNote,
    DateTime? acceptedAt,
    DateTime? declinedAt,
    DateTime? deletedAt,
    DateTime? archivedAt,
    String? linkedArticleId,
    
    // Multi-language support for system messages
    String? fcfsNote,
    String? fcfsHostNote,
    String? acceptanceTitle,
    String? acceptanceMsg,
  }) async {
    try {
      final body = {
        'status': status.toString(),
        'privacy': privacy ?? 'public',
      };
      
      if (personalNote != null) body['personal_note'] = personalNote;

      if (postStatus != null) body['post_status'] = postStatus.toString();
      if (categoryId != null) body['categories'] = categoryId;
      if (acceptedAt != null) body['accepted_at'] = acceptedAt.toUtc().toIso8601String();
      if (declinedAt != null) body['declined_at'] = declinedAt.toUtc().toIso8601String();
      if (deletedAt != null) body['deleted_at'] = deletedAt.toUtc().toIso8601String();
      if (archivedAt != null) body['archived_at'] = archivedAt.toUtc().toIso8601String();
      if (linkedArticleId != null) body['linked_article'] = linkedArticleId;

      await _pb.collection(collectionInvitations).update(invitationId, body: body, expand: 'categories');

      if (status == InvitationStatus.accepted) {
        final inv = await _pb.collection(collectionInvitations).getOne(
          invitationId, 
          expand: 'appointment,user'
        );
        
        final dynamic expandedAppt = inv.expand['appointment'];
        RecordModel? apptData;
        
        if (expandedAppt is List && expandedAppt.isNotEmpty) {
          apptData = expandedAppt.first;
        } else if (expandedAppt is RecordModel) {
          apptData = expandedAppt;
        }
        
        final String? apptId = apptData?.id;
        final bool isFCFS = apptData?.getBoolValue('is_first_come') == true;

        if (apptId != null && apptId.isNotEmpty && isFCFS) {
          try {
            await _pb.collection(collectionAppointments).update(apptId, body: {
              'is_confirmed': true,
            });
          } catch (e) {
            print('❌ [FCFS] Failed to confirm appointment: $e');
          }

          final allApptInvites = await _pb.collection(collectionInvitations).getFullList(
            filter: 'appointment = "$apptId"',
          );

          final String? hostId = apptData?.getStringValue('host');
          final List<RecordModel>? userList = inv.expand['user'];
          final String accepterName = (userList != null && userList.isNotEmpty) ? userList.first.getStringValue('name') : '...';

          for (final invRecord in allApptInvites) {
            if (invRecord.id == invitationId) continue;

            final String recordUserId = invRecord.getStringValue('user');
            final String recordStatus = invRecord.getStringValue('status');

            if (recordUserId == hostId) {
              await _pb.collection(collectionInvitations).update(invRecord.id, body: {
                // Translated: "Appointment booked by $accepterName"
                'personal_note': fcfsHostNote ?? 'Booked by $accepterName',
              });
            } else if (recordStatus == 'pending') {
              await _pb.collection(collectionInvitations).update(invRecord.id, body: {
                'status': 'declined',
                // Translated: "Auto-declined due to FCFS"
                'personal_note': fcfsNote ?? 'FCFS: Appointment full',
              });
            }
          }
          return; 
        }
      }

      if (status == InvitationStatus.accepted || status == InvitationStatus.declined) {
        final inv = await _pb.collection(collectionInvitations).getOne(
          invitationId, 
          expand: 'appointment'
        );
        
        final List<RecordModel>? apptList = inv.expand['appointment'];
        final RecordModel? apptData = (apptList != null && apptList.isNotEmpty) ? apptList.first : null;
        final String? apptId = apptData?.id;

        if (apptId != null) {
          // Check confirmation dynamically based on the updated statuses
          await evaluateAppointmentConfirmation(apptId);
        }
      }

      if (status == InvitationStatus.accepted) {
        try {
           final invWithAppt = await _pb.collection(collectionInvitations).getOne(
              invitationId,
              expand: 'appointment,user',
           );
           
           final apptList = invWithAppt.expand['appointment'];
           final userList = invWithAppt.expand['user'];
           final appt = (apptList != null && apptList.isNotEmpty) ? apptList.first : null;
           final guestUser = (userList != null && userList.isNotEmpty) ? userList.first : null;
           
           if (appt != null && guestUser != null) {
             final hostId = appt.data['host'];
             final guestName = guestUser.data['name'] ?? 'User';
             final apptTitle = appt.data['title'] ?? 'Appointment';
             
             if (hostId != _pb.authStore.record?.id) {
               await _notificationService.createNotification(
                  targetUserId: hostId,
                  title: acceptanceTitle ?? 'Invitation Accepted',
                  message: acceptanceMsg ?? '$guestName accepted your invitation',
                  type: NotificationType.invite, 
                  relatedId: appt.id,
               );
             }
           }
        } catch (e) {
          print('⚠️ Failed to send acceptance notification: $e');
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> inviteGuestByPhone(String appointmentId, String phone, String placeholderName) async {
    if (!_pb.authStore.isValid) {
      throw Exception('Login required');
    }

    try {
      final normalizedPhone = phone.replaceAll(RegExp(r'\D'), '');
      
      // ⚠️ Check if already invited by phone
      final existing = await _pb.collection(collectionInvitations).getList(
        filter: 'appointment = "$appointmentId" && invited_phone ~ "${normalizedPhone.substring(normalizedPhone.length > 9 ? normalizedPhone.length - 9 : 0)}"',
        perPage: 1,
      );

      if (existing.items.isNotEmpty) {
        throw 'تمت دعوة هذا الرقم مسبقاً لهذا الموعد';
      }

      final appt = await _pb.collection(collectionAppointments).getOne(appointmentId);
      final globalPrivacy = appt.getStringValue('privacy', 'public');

      await _pb.collection(collectionInvitations).create(body: {
        'appointment': appointmentId,
        'invited_phone': phone,
        'invited_name': placeholderName,
        'user': null,
        'status': 'pending',
        'post_status': 'published',
        'privacy': globalPrivacy,
      });
      
      await evaluateAppointmentConfirmation(appointmentId);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> inviteGuest(String appointmentId, String userId, {String? title, String? message}) async {
    if (!_pb.authStore.isValid) {
      throw Exception('Login required');
    }

    try {
      // ⚠️ Check if already invited
      final existing = await _pb.collection(collectionInvitations).getList(
        filter: 'appointment = "$appointmentId" && user = "$userId"',
        perPage: 1,
      );

      if (existing.items.isNotEmpty) {
        throw 'هذا المستخدم مدعو مسبقاً لهذا الموعد';
      }

      // Fetch the appointment to get its global privacy
      final appt = await _pb.collection(collectionAppointments).getOne(appointmentId);
      final globalPrivacy = appt.getStringValue('privacy', 'public');

      await _pb.collection(collectionInvitations).create(body: {
        'appointment': appointmentId,
        'user': userId,
        'status': 'pending',
        'post_status': 'published',
        'privacy': globalPrivacy,
      });

      try {
        await _notificationService.createNotification(
          targetUserId: userId,
          title: title ?? 'New Invitation',
          message: message ?? 'You have been invited to an appointment',
          type: NotificationType.invite,
          relatedId: appointmentId,
        );
      } catch (e) {
        print('⚠️ Failed to send invite notification: $e');
      }
      
      // Check confirmation dynamically
      await evaluateAppointmentConfirmation(appointmentId);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> requestToJoin(Appointment appointment, {String? title, String? message}) async {
    if (!_pb.authStore.isValid) {
      throw Exception('Login required');
    }

    try {
      final currentUserId = _pb.authStore.record?.id;
      final globalPrivacy = appointment.privacy;
      
      await _pb.collection(collectionInvitations).create(body: {
        'appointment': appointment.id,
        'user': currentUserId,
        'status': 'pending',
        'post_status': 'published',
        'privacy': globalPrivacy,
      });

      try {
        await _notificationService.createNotification(
          targetUserId: appointment.hostId,
          title: title ?? 'Join Request',
          message: message ?? 'Someone wants to join your appointment',
          type: NotificationType.approvalRequest,
          relatedId: appointment.id, 
        );
      } catch (e) {
        print('⚠️ Failed to send join request notification: $e');
      }
      
      // Check confirmation dynamically
      await evaluateAppointmentConfirmation(appointment.id);
    } catch (e) {
       rethrow;
    }
  }

  Future<bool> toggleBookmark(String appointmentId, String userId) async {
    if (!_pb.authStore.isValid) {
      throw Exception('Login required');
    }

    try {
      // 1. Check if already bookmarked
      final existing = await _pb.collection(collectionInvitations).getList(
        filter: 'appointment = "$appointmentId" && user = "$userId" && post_status = "bookmarked"',
        perPage: 1,
      );

      final appt = await _pb.collection(collectionAppointments).getOne(appointmentId);
      int currentSaves = appt.getIntValue('saves_count', 0);

      if (existing.items.isNotEmpty) {
        // Remove Bookmark
        await _pb.collection(collectionInvitations).delete(existing.items.first.id);
        
        // Decrement counter (safety check for zero)
        try {
          await _pb.collection(collectionAppointments).update(appointmentId, body: {
            'saves_count': (currentSaves > 0) ? currentSaves - 1 : 0,
          });
        } catch (e) {
          print('⚠️ Note: saves_count field might be missing in DB, skipping update.');
        }
        
        return false; // Un-bookmarked
      } else {
        // Create Shadow Record (Bookmark)
        await _pb.collection(collectionInvitations).create(body: {
          'appointment': appointmentId,
          'user': userId,
          'status': 'accepted', 
          'post_status': 'bookmarked', 
          'privacy': 'private', 
          'accepted_at': DateTime.now().toUtc().toIso8601String(),
        });

        // Increment counter
        try {
          await _pb.collection(collectionAppointments).update(appointmentId, body: {
            'saves_count': currentSaves + 1,
          });
        } catch (e) {
          print('⚠️ Note: saves_count field might be missing in DB, skipping update.');
        }

        return true; // Bookmarked
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> syncPublicAppointment(String appointmentId, String userId) async {
    if (!_pb.authStore.isValid) {
      throw Exception('Login required');
    }

    try {
      // Check if already exists (any status)
      final existing = await _pb.collection(collectionInvitations).getList(
        filter: 'appointment = "$appointmentId" && user = "$userId"',
        perPage: 1,
      );

      if (existing.items.isNotEmpty) {
        // If it exists but is trashed, we might want to "restore" it, 
        // but for a public sync, we'll just return or update status.
        final record = existing.items.first;
        if (record.getStringValue('post_status') != 'published' || record.getStringValue('status') != 'accepted') {
          await _pb.collection(collectionInvitations).update(record.id, body: {
            'status': 'accepted',
            'post_status': 'published',
            'accepted_at': DateTime.now().toUtc().toIso8601String(),
          });
        }
        return;
      }

      // Fetch appointment to get privacy
      final appt = await _pb.collection(collectionAppointments).getOne(appointmentId);
      final privacy = appt.getStringValue('privacy', 'public');

      await _pb.collection(collectionInvitations).create(body: {
        'appointment': appointmentId,
        'user': userId,
        'status': 'accepted',
        'post_status': 'published',
        'privacy': privacy,
        'accepted_at': DateTime.now().toUtc().toIso8601String(),
      });
      
      await evaluateAppointmentConfirmation(appointmentId);
    } catch (e) {
      rethrow;
    }
  }

  /// Evaluates and dynamically updates the `is_confirmed` property of an appointment
  /// based on its current participants.
  Future<void> evaluateAppointmentConfirmation(String appointmentId) async {
    try {
      // 1. Fetch the appointment to check if it's FCFS
      final apptRecord = await _pb.collection(collectionAppointments).getOne(appointmentId);
      final bool isFCFS = apptRecord.getBoolValue('is_first_come');
      final String hostId = apptRecord.getStringValue('host');

      // 2. Fetch ALL invitations for this appointment
      // We look at all invitations because deleted_after_accept (post_status=trash) still technically exists
      // but means the user dropped out.
      final allApptInvites = await _pb.collection(collectionInvitations).getFullList(
        filter: 'appointment = "$appointmentId"',
      );

      if (allApptInvites.isEmpty) {
         // No guests yet (or only host), unconfirmed.
         await _pb.collection(collectionAppointments).update(appointmentId, body: {
            'is_confirmed': false,
         });
         return;
      }

      // Filter out the host's own automatically-accepted invitation (if it exists)
      final hostInvites = allApptInvites.where((inv) => inv.getStringValue('user') == hostId).toList();
      final guestInvites = allApptInvites.where((inv) => inv.getStringValue('user') != hostId).toList();

      // If the host has deleted/archived their copy, the appointment cannot be confirmed.
      if (hostInvites.isNotEmpty) {
         final hostInv = hostInvites.first;
         if (hostInv.getStringValue('post_status') != 'published') {
            await _pb.collection(collectionAppointments).update(appointmentId, body: {
               'is_confirmed': false,
            });
            return;
         }
      }

      if (guestInvites.isEmpty) {
         await _pb.collection(collectionAppointments).update(appointmentId, body: {
            'is_confirmed': false,
         });
         return;
      }

      bool shouldBeConfirmed = false;

      if (isFCFS) {
         // FCFS: Confirmed if AT LEAST ONE guest is currently accepted and published
         shouldBeConfirmed = guestInvites.any((inv) => 
           inv.getStringValue('status') == 'accepted' && inv.getStringValue('post_status') == 'published'
         );
      } else {
         // Normal: Confirmed ONLY if ALL active guests are accepted and published.
         // If a guest drops out (trashed) or is newly added (pending), they break the unanimity.
         shouldBeConfirmed = guestInvites.every((inv) => 
           inv.getStringValue('status') == 'accepted' && inv.getStringValue('post_status') == 'published'
         );
      }

      // 3. Apply the decided state
      await _pb.collection(collectionAppointments).update(appointmentId, body: {
         'is_confirmed': shouldBeConfirmed,
      });
      
    } catch (e) {
      print('❌ Failed to evaluate confirmation for $appointmentId: $e');
    }
  }

  Future<UnsubscribeFunc> subscribeToInvitations(String userId, Function(RecordSubscriptionEvent) onEvent) async {
    return await _pb.collection(collectionInvitations).subscribe('*', onEvent);
  }
}
