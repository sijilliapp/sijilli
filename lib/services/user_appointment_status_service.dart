import '../config/constants.dart';
import '../models/user_appointment_status_model.dart';
import '../services/auth_service.dart';

class UserAppointmentStatusService {
  final AuthService _authService;

  UserAppointmentStatusService(this._authService);

  // إنشاء حالة جديدة للمستخدم مع الموعد
  Future<UserAppointmentStatusModel> createUserAppointmentStatus({
    required String userId,
    required String appointmentId,
    String status = 'active',
    String? privacy, // null = يرث من الموعد الأصلي
  }) async {
    try {
      final body = {
        'user': userId,
        'appointment': appointmentId,
        'status': status,
      };
      
      // إضافة privacy فقط إذا كان محدداً
      if (privacy != null) {
        body['privacy'] = privacy;
      }
      
      final record = await _authService.pb
          .collection(AppConstants.userAppointmentStatusCollection)
          .create(body: body);

      return UserAppointmentStatusModel.fromJson(record.toJson());
    } catch (e) {
      print('❌ خطأ في إنشاء حالة المستخدم للموعد: $e');
      rethrow;
    }
  }

  // إنشاء حالات لجميع المشاركين في الموعد (المنشئ + الضيوف)
  Future<void> createStatusForAllParticipants({
    required String appointmentId,
    required String hostId,
    required List<String> guestIds,
  }) async {
    try {
      // إنشاء حالة للمنشئ (عامة بشكل افتراضي)
      await createUserAppointmentStatus(
        userId: hostId,
        appointmentId: appointmentId,
        status: 'active',
        privacy: 'public',
      );

      // إنشاء حالة لكل ضيف (عامة بشكل افتراضي)
      for (final guestId in guestIds) {
        await createUserAppointmentStatus(
          userId: guestId,
          appointmentId: appointmentId,
          status: 'active',
          privacy: 'public',
        );
      }

      print(
        '✅ تم إنشاء حالات ${guestIds.length + 1} مشارك للموعد $appointmentId',
      );
    } catch (e) {
      print('❌ خطأ في إنشاء حالات المشاركين: $e');
      rethrow;
    }
  }

  // جلب حالة مستخدم معين مع موعد معين
  Future<UserAppointmentStatusModel?> getUserAppointmentStatus({
    required String userId,
    required String appointmentId,
  }) async {
    try {
      final records = await _authService.pb
          .collection(AppConstants.userAppointmentStatusCollection)
          .getFullList(
            filter: 'user = "$userId" && appointment = "$appointmentId"',
          );

      if (records.isEmpty) return null;

      return UserAppointmentStatusModel.fromJson(records.first.toJson());
    } catch (e) {
      print('❌ خطأ في جلب حالة المستخدم للموعد: $e');
      return null;
    }
  }

  // جلب حالات جميع المشاركين في موعد معين
  Future<Map<String, UserAppointmentStatusModel>> getAllParticipantsStatus(
    String appointmentId,
  ) async {
    try {
      print('🔍 جلب حالات المشاركين للموعد: $appointmentId');
      
      // جلب كل الحالات (active, deleted, archived) بشكل صريح
      final records = await _authService.pb
          .collection(AppConstants.userAppointmentStatusCollection)
          .getFullList(
            filter: 'appointment = "$appointmentId" && (status = "active" || status = "deleted" || status = "archived")',
            expand: 'user',
          );

      print('📥 تم جلب ${records.length} سجل من قاعدة البيانات');

      final statusMap = <String, UserAppointmentStatusModel>{};
      for (final record in records) {
        final status = UserAppointmentStatusModel.fromJson(record.toJson());
        statusMap[status.userId] = status;
        print('👤 مشارك: ${status.userId} - حالة: ${status.status}');
      }

      // إضافة حالات افتراضية للمشاركين المفقودين
      await _addDefaultStatusForMissingParticipants(appointmentId, statusMap);

      print('📊 إجمالي المشاركين في الـ Map: ${statusMap.length}');
      return statusMap;
    } catch (e) {
      print('❌ خطأ في جلب حالات المشاركين: $e');
      return {};
    }
  }
  
  // إضافة حالات افتراضية للمشاركين المفقودين
  // بدلاً من إنشاء سجلات في قاعدة البيانات (قد يفشل بسبب قواعد الوصول)
  // نضيف حالات افتراضية في الذاكرة فقط
  Future<void> _addDefaultStatusForMissingParticipants(
    String appointmentId,
    Map<String, UserAppointmentStatusModel> existingStatuses,
  ) async {
    try {
      // جلب معلومات الموعد
      final appointment = await _authService.pb
          .collection(AppConstants.appointmentsCollection)
          .getOne(appointmentId);
      
      final hostId = appointment.data['host'] as String;
      
      // جلب جميع الدعوات (accepted و deleted_after_accept)
      final invitations = await _authService.pb
          .collection(AppConstants.invitationsCollection)
          .getFullList(
        filter: 'appointment = "$appointmentId" && (status = "accepted" || status = "deleted_after_accept")',
      );
      
      // قائمة المشاركين (المضيف + الضيوف)
      final participantIds = <String>{hostId};
      final deletedGuestIds = <String>{}; // الضيوف الذين حذفوا الموعد
      
      for (final invitation in invitations) {
        final guestId = invitation.data['guest'] as String;
        participantIds.add(guestId);
        
        // إذا كانت الدعوة deleted_after_accept، فهذا يعني أن الضيف حذف الموعد
        if (invitation.data['status'] == 'deleted_after_accept') {
          deletedGuestIds.add(guestId);
        }
      }
      
      print('🔍 المشاركون المتوقعون: ${participantIds.length} (مضيف + ${invitations.length} ضيف)');
      print('🗑️ ضيوف حذفوا الموعد: ${deletedGuestIds.length}');
      
      // إضافة حالات افتراضية للمشاركين المفقودين
      for (final participantId in participantIds) {
        if (!existingStatuses.containsKey(participantId)) {
          // تحديد الحالة بناءً على حالة الدعوة
          final isDeleted = deletedGuestIds.contains(participantId);
          final status = isDeleted ? 'deleted' : 'active';
          
          print('⚠️ مشارك بدون سجل: $participantId - إضافة حالة افتراضية ($status, public)');
          
          // إنشاء حالة افتراضية في الذاكرة فقط
          final now = DateTime.now();
          existingStatuses[participantId] = UserAppointmentStatusModel(
            id: 'default_$participantId', // معرف مؤقت
            userId: participantId,
            appointmentId: appointmentId,
            status: status,
            privacy: 'public',
            deletedAt: isDeleted ? now : null,
            myNote: null,
            created: now,
            updated: now,
          );
          print('✅ تمت إضافة حالة افتراضية للمشارك: $participantId ($status)');
        }
      }
    } catch (e) {
      print('⚠️ خطأ في إضافة الحالات الافتراضية: $e');
      // لا نرمي الخطأ لأن هذه عملية اختيارية
    }
  }

  // تحديث حالة المستخدم مع الموعد
  Future<void> updateUserAppointmentStatus({
    required String userId,
    required String appointmentId,
    required String newStatus,
  }) async {
    try {
      // البحث عن السجل الموجود
      final existingStatus = await getUserAppointmentStatus(
        userId: userId,
        appointmentId: appointmentId,
      );

      if (existingStatus == null) {
        // إنشاء سجل جديد إذا لم يكن موجود
        await createUserAppointmentStatus(
          userId: userId,
          appointmentId: appointmentId,
          status: newStatus,
        );
        return;
      }

      // تحديث السجل الموجود
      final updateData = <String, dynamic>{'status': newStatus};

      // إضافة تاريخ الحذف إذا كانت الحالة محذوفة
      if (newStatus == 'deleted') {
        updateData['deleted_at'] = DateTime.now().toIso8601String();
      } else {
        updateData['deleted_at'] = null;
      }

      await _authService.pb
          .collection(AppConstants.userAppointmentStatusCollection)
          .update(existingStatus.id, body: updateData);

      print(
        '✅ تم تحديث حالة المستخدم $userId للموعد $appointmentId إلى $newStatus',
      );
    } catch (e) {
      print('❌ خطأ في تحديث حالة المستخدم: $e');
      rethrow;
    }
  }

  // تحديث خصوصية نسخة المستخدم من الموعد
  Future<void> updateUserAppointmentPrivacy(
    String appointmentId,
    String privacy,
  ) async {
    final currentUserId = _authService.currentUser?.id;
    if (currentUserId == null) {
      throw Exception('لا يوجد مستخدم مسجل دخول');
    }

    try {
      // البحث عن السجل الموجود
      final existingStatus = await getUserAppointmentStatus(
        userId: currentUserId,
        appointmentId: appointmentId,
      );

      if (existingStatus == null) {
        // إنشاء سجل جديد إذا لم يكن موجود
        await _authService.pb
            .collection(AppConstants.userAppointmentStatusCollection)
            .create(
              body: {
                'user': currentUserId,
                'appointment': appointmentId,
                'status': 'active',
                'privacy': privacy,
              },
            );
        print('✅ تم إنشاء سجل جديد مع خصوصية $privacy');
        return;
      }

      // تحديث السجل الموجود
      await _authService.pb
          .collection(AppConstants.userAppointmentStatusCollection)
          .update(existingStatus.id, body: {'privacy': privacy});

      print(
        '✅ تم تحديث خصوصية نسخة المستخدم $currentUserId للموعد $appointmentId إلى $privacy',
      );
    } catch (e) {
      print('❌ خطأ في تحديث خصوصية نسخة المستخدم: $e');
      rethrow;
    }
  }

  // تحديث الملاحظة الخاصة للمستخدم
  Future<void> updateUserAppointmentNote(
    String appointmentId,
    String? note,
  ) async {
    final currentUserId = _authService.currentUser?.id;
    if (currentUserId == null) {
      throw Exception('لا يوجد مستخدم مسجل دخول');
    }

    try {
      // البحث عن السجل الموجود
      final existingStatus = await getUserAppointmentStatus(
        userId: currentUserId,
        appointmentId: appointmentId,
      );

      if (existingStatus == null) {
        // إنشاء سجل جديد إذا لم يكن موجود
        await _authService.pb
            .collection(AppConstants.userAppointmentStatusCollection)
            .create(
              body: {
                'user': currentUserId,
                'appointment': appointmentId,
                'status': 'active',
                'my_note': note,
              },
            );
        print('✅ تم إنشاء سجل جديد مع ملاحظة');
        return;
      }

      // تحديث السجل الموجود
      await _authService.pb
          .collection(AppConstants.userAppointmentStatusCollection)
          .update(existingStatus.id, body: {'my_note': note});

      print('✅ تم تحديث الملاحظة الخاصة للموعد $appointmentId');
    } catch (e) {
      print('❌ خطأ في تحديث الملاحظة الخاصة: $e');
      rethrow;
    }
  }

  // حذف الموعد للمستخدم الحالي
  Future<void> deleteAppointmentForCurrentUser(String appointmentId) async {
    final currentUserId = _authService.currentUser?.id;
    if (currentUserId == null) {
      throw Exception('لا يوجد مستخدم مسجل دخول');
    }

    await updateUserAppointmentStatus(
      userId: currentUserId,
      appointmentId: appointmentId,
      newStatus: 'deleted',
    );
    
    // تحديث حالة الدعوة أيضاً (للتوافق مع النظام القديم)
    try {
      final invitationRecords = await _authService.pb
          .collection(AppConstants.invitationsCollection)
          .getFullList(
        filter: 'appointment = "$appointmentId" && guest = "$currentUserId"',
      );
      
      if (invitationRecords.isNotEmpty) {
        final invitationId = invitationRecords.first.id;
        await _authService.pb
            .collection(AppConstants.invitationsCollection)
            .update(invitationId, body: {
          'status': 'deleted_after_accept',
        });
        print('✅ تم تحديث حالة الدعوة إلى deleted_after_accept');
      }
    } catch (e) {
      print('⚠️ لم نتمكن من تحديث حالة الدعوة: $e');
    }
  }

  // أرشفة الموعد للمستخدم الحالي
  Future<void> archiveAppointmentForCurrentUser(String appointmentId) async {
    final currentUserId = _authService.currentUser?.id;
    if (currentUserId == null) {
      throw Exception('لا يوجد مستخدم مسجل دخول');
    }

    await updateUserAppointmentStatus(
      userId: currentUserId,
      appointmentId: appointmentId,
      newStatus: 'archived',
    );
  }

  // استرجاع الموعد للمستخدم الحالي
  Future<void> restoreAppointmentForCurrentUser(String appointmentId) async {
    final currentUserId = _authService.currentUser?.id;
    if (currentUserId == null) {
      throw Exception('لا يوجد مستخدم مسجل دخول');
    }

    await updateUserAppointmentStatus(
      userId: currentUserId,
      appointmentId: appointmentId,
      newStatus: 'active',
    );
    
    // تحديث حالة الدعوة أيضاً (للتوافق مع النظام القديم)
    try {
      final invitationRecords = await _authService.pb
          .collection(AppConstants.invitationsCollection)
          .getFullList(
        filter: 'appointment = "$appointmentId" && guest = "$currentUserId"',
      );
      
      if (invitationRecords.isNotEmpty) {
        final invitationId = invitationRecords.first.id;
        await _authService.pb
            .collection(AppConstants.invitationsCollection)
            .update(invitationId, body: {
          'status': 'accepted',
        });
        print('✅ تم تحديث حالة الدعوة إلى accepted');
      }
    } catch (e) {
      print('⚠️ لم نتمكن من تحديث حالة الدعوة: $e');
    }
  }

  // جلب المواعيد النشطة للمستخدم الحالي
  Future<List<String>> getActiveAppointmentIdsForCurrentUser() async {
    final currentUserId = _authService.currentUser?.id;
    if (currentUserId == null) return [];

    try {
      final records = await _authService.pb
          .collection(AppConstants.userAppointmentStatusCollection)
          .getFullList(filter: 'user = "$currentUserId" && status = "active"');

      final appointmentIds = records
          .map((record) => record.data['appointment'] as String)
          .toList();
      
      print('📊 المواعيد النشطة للمستخدم $currentUserId: ${appointmentIds.length} موعد');
      return appointmentIds;
    } catch (e) {
      print('❌ خطأ في جلب المواعيد النشطة: $e');
      return [];
    }
  }

  // جلب المواعيد المؤرشفة للمستخدم الحالي
  Future<List<String>> getArchivedAppointmentIdsForCurrentUser() async {
    final currentUserId = _authService.currentUser?.id;
    if (currentUserId == null) return [];

    try {
      final records = await _authService.pb
          .collection(AppConstants.userAppointmentStatusCollection)
          .getFullList(filter: 'user = "$currentUserId" && status = "archived"');

      return records
          .map((record) => record.data['appointment'] as String)
          .toList();
    } catch (e) {
      print('❌ خطأ في جلب المواعيد المؤرشفة: $e');
      return [];
    }
  }

  // جلب المواعيد المحذوفة للمستخدم الحالي
  Future<List<String>> getDeletedAppointmentIdsForCurrentUser() async {
    final currentUserId = _authService.currentUser?.id;
    if (currentUserId == null) return [];

    try {
      final records = await _authService.pb
          .collection(AppConstants.userAppointmentStatusCollection)
          .getFullList(filter: 'user = "$currentUserId" && status = "deleted"');

      return records
          .map((record) => record.data['appointment'] as String)
          .toList();
    } catch (e) {
      print('❌ خطأ في جلب المواعيد المحذوفة: $e');
      return [];
    }
  }

  // جلب كل المواعيد للمستخدم الحالي (نشطة، محذوفة، مؤرشفة)
  Future<List<String>> getAllAppointmentIdsForCurrentUser() async {
    final currentUserId = _authService.currentUser?.id;
    if (currentUserId == null) return [];

    try {
      final records = await _authService.pb
          .collection(AppConstants.userAppointmentStatusCollection)
          .getFullList(
            filter: 'user = "$currentUserId"', // ✅ بدون شرط status
          );

      return records
          .map((record) => record.data['appointment'] as String)
          .toList();
    } catch (e) {
      print('❌ خطأ في جلب كل المواعيد: $e');
      return [];
    }
  }

  // فحص إذا كان المستخدم حذف الموعد
  Future<bool> isAppointmentDeletedByUser({
    required String userId,
    required String appointmentId,
  }) async {
    final status = await getUserAppointmentStatus(
      userId: userId,
      appointmentId: appointmentId,
    );

    return status?.isDeleted ?? false;
  }

  // فحص إذا كان المستخدم الحالي حذف الموعد
  Future<bool> isAppointmentDeletedByCurrentUser(String appointmentId) async {
    final currentUserId = _authService.currentUser?.id;
    if (currentUserId == null) return false;

    return await isAppointmentDeletedByUser(
      userId: currentUserId,
      appointmentId: appointmentId,
    );
  }
}
