import 'package:pocketbase/pocketbase.dart';
import 'package:flutter/foundation.dart';
import '../../../core/services/pocketbase_client.dart';
import '../../../models/appointment.dart';

class PbAppointmentBrowseService {
  final PocketBase _pb = PocketBaseClient.instance.pb;
  static const String collectionAppointments = 'appointments';
  static const String collectionInvitations = 'invitations';

  /// جلب مواعيد الحسابات المعتمدة (تبويب الأخبار)
  /// الشروط: عام، منشور، مؤكد، من حساب معتمد، مستقبلي أو جاري (آخر ساعتين)
  /// يستعلم عبر invitations لأن privacy موجود هناك فقط
  Future<List<Appointment>> getExploreAppointments({String? userRegion, int page = 1, int perPage = 50, int contextAdjustment = 0}) async {
    try {
      final now = DateTime.now().toUtc();
      final ongoingThreshold = now.subtract(const Duration(hours: 2)).toIso8601String();

      // نستعلم من invitations حيث privacy = "public"
      // ونتحقق من شروط الموعد المركزي عبر العلاقة appointment.*
      String filter = 'privacy = "public" && status = "accepted" && post_status = "published"'
          ' && appointment.is_confirmed = true'
          ' && appointment.host.isPublic = true'
          ' && appointment.start_at > "$ongoingThreshold"'
          ' && appointment.is_cancelled = false'
          ' && appointment.is_deleted = false';

      if (userRegion != null && userRegion.isNotEmpty) {
        filter += ' && (appointment.host.role = "approved" || appointment.host.role = "writer"'
            ' || appointment.host.role = "organization" || appointment.host.role = "admin"'
            ' || appointment.region = "$userRegion")';
      } else {
        filter += ' && (appointment.host.role = "approved" || appointment.host.role = "writer"'
            ' || appointment.host.role = "organization" || appointment.host.role = "admin")';
      }

      final resultList = await _pb.collection(collectionInvitations).getList(
        page: page,
        perPage: perPage,
        filter: filter,
        sort: '+appointment.start_at',
        expand: 'appointment,appointment.host,appointment.invitations_via_appointment.user,appointment.invitations_via_appointment.linked_article',
      );

      // بناء قائمة مواعيد مع deduplication
      final Set<String> seen = {};
      final List<Appointment> appointments = [];

      for (final record in resultList.items) {
        final invJson = record.toJson();
        var apptData = invJson['expand']?['appointment'];
        if (apptData is List && apptData.isNotEmpty) apptData = apptData.first;
        final Map<String, dynamic>? apptJson = apptData is Map<String, dynamic> ? apptData : null;
        if (apptJson == null) continue;

        final apptId = apptJson['id'] as String? ?? '';
        if (seen.contains(apptId)) continue;
        seen.add(apptId);

        apptJson['currentUserInvitation'] = invJson;
        appointments.add(Appointment.fromJson(apptJson, contextAdjustment: contextAdjustment));
      }

      return appointments;
    } catch (e) {
      print('⚠️ Failed to fetch explore appointments: $e');
      return [];
    }
  }

  /// جلب مواعيد الأصدقاء (تبويب المتابعات)
  /// الشروط: أي موعد عام ومؤكد لأحد المتابعين (ضيف أو مضيف)، مستقبلي أو جاري
  Future<List<Appointment>> getFollowedAppointments({int page = 1, int perPage = 50, int contextAdjustment = 0}) async {
    try {
      final currentUserId = _pb.authStore.record?.id;
      if (currentUserId == null) return [];

      final now = DateTime.now().toUtc();
      final ongoingThreshold = now.subtract(const Duration(hours: 2)).toIso8601String();

      // 1. جلب الأشخاص الذين أتابعهم (حتى لو لم يبادلوني المتابعة)
      final friendshipRecords = await _pb.collection('friendship').getFullList(
        filter: '(user_a = "$currentUserId" && a_status = "accepted") || (user_b = "$currentUserId" && b_status = "accepted")',
      );

      final friendIds = friendshipRecords.map((record) {
        final isUserA = record.getStringValue('user_a') == currentUserId;
        return record.getStringValue(isUserA ? 'user_b' : 'user_a');
      }).where((id) => id.isNotEmpty).toList();
      
      if (friendIds.isEmpty) return [];
      
      // 2. البحث في جدول الدعوات
      final userIdsFilter = friendIds.map((id) => 'user = "$id"').join(' || ');
      
      // الشروط: المواعيد العامة (Public) أو للمتابعين (followers)
      // privacy هنا من جدول invitations وليس appointments
      final filter = '($userIdsFilter) && status = "accepted" && post_status = "published" && (privacy = "public" || privacy = "followers") && appointment.is_confirmed = true && appointment.start_at > "$ongoingThreshold"';
      
      final records = await _pb.collection(collectionInvitations).getFullList(
        filter: filter,
        expand: 'appointment,appointment.host,appointment.invitations_via_appointment.user,appointment.invitations_via_appointment.linked_article',
      );

      final List<Appointment> appointments = [];
      final Set<String> seenApptIds = {};

      for (var record in records) {
        final apptList = record.expand['appointment'];
        final apptData = (apptList != null && apptList.isNotEmpty) ? apptList.first : null;
        if (apptData == null) continue;
        
        // Deduplication: One card per appointment
        if (seenApptIds.contains(apptData.id)) continue;
        seenApptIds.add(apptData.id);

        final apptJson = apptData.toJson();
        
        // العثور على دعوة المستخدم الحالي إن وجدت ضمن التوسع لضمان الخصوصية الصحيحة والتحكم
        final List<dynamic>? allInvites = apptData.expand['invitations_via_appointment'];
        final matches = allInvites?.where((i) {
          if (i is RecordModel) return i.getStringValue('user') == currentUserId;
          if (i is Map) return i['user'] == currentUserId;
          return false;
        });
        final myInv = (matches != null && matches.isNotEmpty) ? matches.first : null;
        
        // Always use the friend's invitation as the primary record for display privacy
        final friendInv = record.toJson();
        apptJson['currentUserInvitation'] = friendInv;

        if (myInv != null) {
          apptJson['viewerInvitation'] = myInv is RecordModel ? myInv.toJson() : myInv;
        }
        
        appointments.add(Appointment.fromJson(apptJson, contextAdjustment: contextAdjustment));
      }

      // ترتيب حسب التاريخ
      appointments.sort((a, b) => a.startAt.compareTo(b.startAt));

      return appointments;
    } catch (e, stack) {
      print('⚠️ Failed to fetch followed appointments: $e');
      print(stack);
      return [];
    }
  }

  /// جلب المواعيد العامة لمستخدم معين (للجمهور) مع احترام الخصوصية وقاعدة "الأطراف المشتركة"
  Future<List<Appointment>> getPublicAppointments(
    String targetUserId, {
    String? query,
    String? viewerId,
    bool includeFollowers = false,
    bool includePrivate = false,
    int contextAdjustment = 0,
  }) async {
    try {
      final nowObj = DateTime.now();
      final startOfDayLocal = DateTime(nowObj.year, nowObj.month, nowObj.day);
      final filterDate = startOfDayLocal.toUtc().toIso8601String();
      
      // بناء الفلتر الأساسي للرؤية بناءً على حقل privacy في invitations (نسخة صاحب الحساب)
      // وليس appointments.privacy — لأن صاحب الحساب يحدد خصوصية نسخته الشخصية
      String visibilityCriteria = 'privacy = "public"';
      if (includeFollowers) visibilityCriteria += ' || privacy = "followers"';
      if (includePrivate) visibilityCriteria += ' || privacy = "private"';
      
      // Filter: Target User + Published + Accepted (Host is auto-accepted)
      String filter = 'user = "$targetUserId" && status = "accepted" && post_status = "published"';
      
      // Privacy & Relationship Check
      String privacyFilter = '($visibilityCriteria)';
      
      if (viewerId != null) {
         // If viewer is specifically invited, they see it regardless of privacy
         privacyFilter += ' || appointment.invitations_via_appointment.user ?= "$viewerId"';
      }
      
      filter += ' && ($privacyFilter)';

      if (kDebugMode) {
        print('🔍 [PbAppointmentBrowseService] Fetching with filter: $filter');
      }

      final resultList = await _pb.collection(collectionInvitations).getList(
        filter: filter,
        sort: '+appointment.start_at',
        expand: 'appointment,appointment.host,appointment.invitations_via_appointment.user,appointment.invitations_via_appointment.linked_article,categories',
      );

      if (kDebugMode) {
        print('🌐 [PbAppointmentBrowseService] Found ${resultList.items.length} invitations for $targetUserId');
        for (var item in resultList.items) {
           final appt = item.expand['appointment']?[0];
           print('   - Inv ID: ${item.id}, Privacy: ${item.getStringValue('privacy')}, Appt Title: ${appt?.getStringValue('title')}');
        }
      }

      final List<Appointment> appointments = [];

      for (final record in resultList.items) {
        final invJson = record.toJson();
        
        // PB 0.22+ expand is always a list
        final expandedAppt = invJson['expand']?['appointment'];
        Map<String, dynamic>? apptJson = (expandedAppt is List && expandedAppt.isNotEmpty)
            ? expandedAppt[0] as Map<String, dynamic>?
            : (expandedAppt is Map<String, dynamic> ? expandedAppt : null);
        
        if (apptJson == null) continue;

        Map<String, dynamic>? viewersInvitationJson;
        
        if (viewerId != null) {
          // Try to find viewer's invitation in the expansion
           final List<dynamic>? allInvites = apptJson['expand']?['invitations_via_appointment'];
           if (allInvites != null) {
             final matches = allInvites.where((i) {
               if (i is RecordModel) return i.getStringValue('user') == viewerId;
               if (i is Map) return i['user'] == viewerId;
               return false;
             });
             final originalInv = matches.isNotEmpty ? matches.first : null;
             if (originalInv != null) {
                viewersInvitationJson = Map<String, dynamic>.from(
                  originalInv is RecordModel ? originalInv.toJson() : originalInv as Map
                );
                // We keep privacy here because it will be stored in viewerInvitation
             }
           }
        }
        
        // The primary record for display is the target user's invitation (the one we fetched)
        apptJson['currentUserInvitation'] = invJson;
        
        // The viewer's information for interaction logic
        apptJson['viewerInvitation'] = viewersInvitationJson;

        appointments.add(Appointment.fromJson(apptJson, contextAdjustment: contextAdjustment));
      }

      // Sort by date
      appointments.sort((a, b) => a.startAt.compareTo(b.startAt));

      return appointments;
    } catch (e) {
      print('⚠️ Failed to fetch public appointments: $e');
      return [];
    }
  }
}
