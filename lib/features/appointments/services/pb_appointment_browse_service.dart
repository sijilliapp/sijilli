import 'package:pocketbase/pocketbase.dart';
import '../../../core/services/pocketbase_client.dart';
import '../../../models/appointment.dart';
import '../../../models/user.dart';

class PbAppointmentBrowseService {
  final PocketBase _pb = PocketBaseClient.instance.pb;
  static const String collectionAppointments = 'appointments';
  static const String collectionInvitations = 'invitations';

  /// جلب مواعيد الحسابات المعتمدة (تبويب الأخبار)
  /// الشروط: عام، منشور، مؤكد، من حساب معتمد/مشرف، مستقبلي أو جاري (آخر ساعتين)
  Future<List<Appointment>> getExploreAppointments({String? userRegion, int page = 1, int perPage = 50, int contextAdjustment = 0}) async {
    try {
      // السماح بظهور المواعيد التي بدأت خلال آخر ساعتين (جارية)
      final now = DateTime.now().toUtc();
      final ongoingThreshold = now.subtract(const Duration(hours: 2)).toIso8601String();
      
      // الشروط:
      // 1. الخصوصية عام (public)
      // 2. الموعد مؤكد (is_confirmed)
      // 3. المضيف خصوصية حسابه عام (isPublic)
      // 4. الموعد مستقبلي أو جاري (start_at > threshold)
      // 5. غير ملغى وغير محذوف
      // 6. الأولوية (أو): مضيف معتمد/مشرف OR الموعد في نفس منطقة المستخدم
      
      String filter = 'privacy = "public" && is_confirmed = true && host.isPublic = true && start_at > "$ongoingThreshold" && is_cancelled = false && is_deleted = false';
      
      if (userRegion != null && userRegion.isNotEmpty) {
        filter += ' && (host.role = "approved" || host.role = "admin" || region = "$userRegion")';
      } else {
        filter += ' && (host.role = "approved" || host.role = "admin")';
      }

      final resultList = await _pb.collection(collectionAppointments).getList(
        page: page,
        perPage: perPage,
        filter: filter,
        sort: '+start_at',
        expand: 'host,invitations_via_appointment.user',
      );

      return resultList.items.map((record) => Appointment.fromJson(record.toJson(), contextAdjustment: contextAdjustment)).toList();
    } catch (e) {
      print('⚠️ Failed to fetch explore appointments: $e');
      return [];
    }
  }

  /// جلب مواعيد الأصدقاء (تبويب المتابعات)
  /// الشروط: أي موعد عام ومؤكد لأحد المتابعين (ضيف أو مضيف)، مستقبلي أو جاري
  Future<List<Appointment>> getFollowedAppointments({int page = 1, int perPage = 50, int contextAdjustment = 0}) async {
    try {
      final currentUserId = _pb.authStore.model?.id;
      if (currentUserId == null) return [];

      final now = DateTime.now().toUtc();
      final ongoingThreshold = now.subtract(const Duration(hours: 2)).toIso8601String();

      // 1. جلب المتابعين والمتابَعين للتحقق من التبادلية (الصداقة)
      final results = await Future.wait([
        _pb.collection('follows').getFullList(
          filter: 'follower = "$currentUserId" && status = "accepted"',
        ),
        _pb.collection('follows').getFullList(
          filter: 'following = "$currentUserId" && status = "accepted"',
        ),
      ]);

      final iFollow = results[0].map((r) => r.getStringValue('following')).toSet();
      final followMe = results[1].map((r) => r.getStringValue('follower')).toSet();

      // الأصدقاء هم من اتابعهم ويتابعونني (التبادلية)
      final friendIds = iFollow.intersection(followMe).where((id) => id.isNotEmpty).toList();
      
      if (friendIds.isEmpty) return [];
      
      // 2. البحث في جدول الدعوات
      final userIdsFilter = friendIds.map((id) => 'user = "$id"').join(' || ');
      
      final filter = '($userIdsFilter) && user.role = "user" && status = "accepted" && post_status = "published" && (appointment.privacy = "public" || appointment.privacy = "followers") && appointment.is_confirmed = true && appointment.start_at > "$ongoingThreshold" && appointment.is_cancelled = false && appointment.is_deleted = false';
      
      final records = await _pb.collection(collectionInvitations).getFullList(
        filter: filter,
        expand: 'appointment,appointment.host,appointment.invitations_via_appointment.user',
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
        
        if (myInv != null) {
          apptJson['currentUserInvitation'] = myInv is RecordModel ? myInv.toJson() : myInv;
        } else {
          // إذا لم يكن المستخدم جزءاً من الموعد، نستخدم دعوة الصديق كمرجع
          // مع التأكد من أن خصوصية الموعد تسمح للمتابعين بالرؤية
          final friendInv = record.toJson();
          // ملاحظة: لا نحتاج لإزالة 'privacy' لأن Appointment.fromJson يعالج تعارض الخصوصية
          apptJson['currentUserInvitation'] = friendInv;
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
      
      // بناء الفلتر الأساسي للرؤية بناءً على العلاقة والخصوصية
      String visibilityCriteria = 'privacy = "public"';
      if (includeFollowers) visibilityCriteria += ' || privacy = "followers"';
      if (includePrivate) visibilityCriteria += ' || privacy = "private"';
      
      // Filter: Target User + Published + Accepted (Host is auto-accepted)
      String filter = 'user = "$targetUserId" && status = "accepted" && post_status = "published"';
      
      // Privacy & Relationship Check
      String privacyFilter = '($visibilityCriteria)';
      
      if (viewerId != null) {
         // Check if Viewer is Host OR Viewer is in invitations
         privacyFilter += ' || appointment.host = "$viewerId" || appointment.invitations_via_appointment.user ?= "$viewerId"';
      }
      
      filter += ' && ($privacyFilter)';

      final resultList = await _pb.collection(collectionInvitations).getList(
        filter: filter,
        sort: '+appointment.start_at',
        expand: 'appointment,appointment.host,appointment.invitations_via_appointment.user,categories',
      );

      final List<Appointment> appointments = [];

      for (final record in resultList.items) {
        final invJson = record.toJson();
        final apptJson = invJson['expand']?['appointment'] as Map<String, dynamic>?;
        
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
                viewersInvitationJson.remove('privacy');
             }
           }
        }
        
        // حقن خصوصية المضيف في الموعد (لكي يرى الزائر نفس الكبسولة التي اختارها المضيف)
        final hostPrivacy = invJson['privacy'];
        if (hostPrivacy != null) {
           apptJson['privacy'] = hostPrivacy;
        }
        
        apptJson['currentUserInvitation'] = viewersInvitationJson;

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
