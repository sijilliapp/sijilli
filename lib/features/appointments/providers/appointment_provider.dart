import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';
import '../../../core/local/local_db_service.dart';
import '../../../models/appointment.dart';
import '../../../core/widgets/pulse_avatar.dart';
import '../../profile/providers/moderation_provider.dart';
import '../services/pb_appointment_service.dart';
import '../services/pb_appointment_browse_service.dart';
import '../services/pb_invitation_service.dart';
import '../services/pb_appointment_recurrence_service.dart';

class AppointmentProvider extends ChangeNotifier {
  final PbAppointmentService _apptService = PbAppointmentService();
  final PbAppointmentBrowseService _browseService = PbAppointmentBrowseService();
  final PbInvitationService _invitationService = PbInvitationService();
  final PbAppointmentRecurrenceService _recurrenceService = PbAppointmentRecurrenceService();
  final LocalDbService _localDb = LocalDbService.instance;
  
  List<Appointment> _appointments = [];
  List<Appointment> _archivedAppointments = [];
  List<Appointment> _trashedAppointments = [];
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _refreshTimer;
  Timer? _fetchDebounceTimer;
  UnsubscribeFunc? _unsubscribeInvitations;
  String? _currentUserId;
  int? _currentHijriAdjustment;
  ModerationProvider? _moderation;

  AppointmentProvider() {
    _startRefreshTimer();
  }

  /// تحديث المزود عند تغيير حالة المصادقة أو المستخدم
  void update(String? userId, int? hijriAdjustment, ModerationProvider? moderation) {
    bool changed = false;
    
    if (userId != _currentUserId || hijriAdjustment != _currentHijriAdjustment) {
      debugPrint('🔄 AppointmentProvider: User/Adjustment changed from $_currentUserId to $userId');
      _currentUserId = userId;
      _currentHijriAdjustment = hijriAdjustment;
      
      // ⚠️ Wipe local memory to avoid stale data mixing
      _appointments = [];
      _archivedAppointments = [];
      _trashedAppointments = [];
      
      _unsubscribeInvitations?.call();
      _unsubscribeInvitations = null;
      _errorMessage = null;
      changed = true;
    }

    if (moderation != _moderation) {
      _moderation = moderation;
      changed = true;
    }

    if (changed && userId != null) {
      _loadLocalAppointments(); 
    } else if (changed && userId == null) {
      notifyListeners();
    }
  }
  
  // Getters (Filter out blocked users)
  List<Appointment> get appointments {
    if (_moderation == null) return _appointments;
    return _appointments.where((a) => !_moderation!.isUserBlocked(a.hostId)).toList();
  }
  
  List<Appointment> get archivedAppointments {
    if (_moderation == null) return _archivedAppointments;
    return _archivedAppointments.where((a) => !_moderation!.isUserBlocked(a.hostId)).toList();
  }
  
  List<Appointment> get trashedAppointments {
    if (_moderation == null) return _trashedAppointments;
    return _trashedAppointments.where((a) => !_moderation!.isUserBlocked(a.hostId)).toList();
  }

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// عدد الدعوات المعلقة (الواردة)
  int get pendingInvitationsCount {
    if (_currentUserId == null) return 0;
    return _appointments.where((a) => 
      a.hostId != _currentUserId && 
      a.currentUserInvitation?.status == InvitationStatus.pending &&
      a.currentUserInvitation?.postStatus == PostStatus.published &&
      !a.isPast &&
      !a.isCancelled &&
      !a.isDeleted
    ).length;
  }

  /// حالة الأفاتار بناءً على المواعيد الحالية
  AvatarStatus get avatarStatus {
    // Ensure we only consider PUBLISHED and ACCEPTED appointments
    final activeAppointments = _appointments.where((a) => 
      a.currentUserInvitation?.postStatus == PostStatus.published &&
      a.currentUserInvitation?.status == InvitationStatus.accepted
    );

    if (activeAppointments.any((a) => a.isNow && !a.isCancelled && !a.isUserDeleted)) {
      return AvatarStatus.active; // Pulse
    }
    if (activeAppointments.any((a) => a.isUpcoming && !a.isCancelled && !a.isUserDeleted)) {
      return AvatarStatus.upcoming; // Blue ring
    }
    return AvatarStatus.none;
  }

  Future<void> _loadLocalAppointments() async {
    _isLoading = true;
    notifyListeners();
    try {
      final cached = await _localDb.getAppointments();
      if (cached.isNotEmpty) {
        debugPrint('📦 Loaded ${cached.length} appointments from local DB');
        _appointments = cached;
        _sortAppointments();
      } else {
         debugPrint('📦 Local DB empty');
      }
    } catch (e) {
      debugPrint('Failed to load local appointments: $e');
    } finally {
      // Don't set loading false yet, we chain fetch immediately
      notifyListeners();
      fetchAppointments();
    }
  }

  void _sortAppointments() {
    _appointments.sort((a, b) {
      // 1. الترتيب الأساسي حسب وزن الحالة (جاري > قادم > مستقبلي > منتهي)
      final weightCompare = a.sortWeight.compareTo(b.sortWeight);
      if (weightCompare != 0) return weightCompare;

      // 2. عند تساوي الوزن، يرتب حسب القرب الزمني
      return a.startAt.compareTo(b.startAt);
    });
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      notifyListeners(); // Refresh UI for "isNow" checks
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _unsubscribeInvitations?.call();
    super.dispose();
  }

  Future<void> fetchAppointments() async {
    // Debounce to prevent rapid sequential fetches
    if (_fetchDebounceTimer?.isActive ?? false) {
       _fetchDebounceTimer!.cancel();
    }
    
    final completer = Completer<void>();
    
    _fetchDebounceTimer = Timer(const Duration(milliseconds: 600), () async {
      // Keep local data visible while loading ONLY if we have some. 
      // If empty, show loader.
      final hasData = _appointments.isNotEmpty;
      if (!hasData) {
        _isLoading = true;
        notifyListeners();
      }
      _errorMessage = null;

      try {
        final fresh = await _apptService.getAppointments(
          userId: _currentUserId,
          contextAdjustment: _currentHijriAdjustment ?? 0,
        );
        
        // ⚠️ IMPORTANT: Always overwrite with fresh data from server
        debugPrint('☁️ Fetched ${fresh.length} fresh appointments from server');
        _appointments = fresh;
        _sortAppointments();
        
        // Save to cache (replaces old cache)
        await _localDb.saveAppointments(_appointments);

        // إعداد الاشتراك اللحظي إذا لم يكن موجوداً
        if (_unsubscribeInvitations == null) {
          final userId = _currentUserId;
          if (userId != null) {
            try {
              _unsubscribeInvitations = await _invitationService.subscribeToInvitations(userId, (e) {
                // التحقق من أن التغيير يخص المستخدم الحالي (user field in invitation)
                final eventUser = e.record?.data['user']?.toString();
                if (eventUser == userId) {
                  debugPrint('🔔 Realtime Event for me: ${e.action}');
                  // Add a small delay robustly to avoid fetching mid-transaction
                  Future.delayed(const Duration(milliseconds: 500), () {
                    fetchAllInvitations();
                  });
                } else {
                  debugPrint('🔔 Realtime Event for others (${e.record?.id}), ignoring.');
                }
              });
            } catch (e) {
               debugPrint('⚠️ Realtime subscription failed (non-fatal): $e');
            }
          }
        }
        // Trigger maintenance (Rollover) if needed
        await checkAndRolloverAppointments();
        completer.complete();
      } catch (e) {
        if (e.toString().contains('isAbort: true')) {
          completer.complete();
          return;
        }
        debugPrint('❌ Fetch Appointments Error: $e');
        _errorMessage = e.toString();
        // ⚠️ Keep old data if fetch fails
        completer.completeError(e);
      } finally {
        _isLoading = false;
        notifyListeners();
      }
    });

    return completer.future;
  }

  /// جلب جميع المواعيد (بما فيها القديمة) لتحديث الإشعارات
  Future<void> fetchAllInvitations() async {
    if (_fetchDebounceTimer?.isActive ?? false) {
       _fetchDebounceTimer!.cancel();
    }
    
    final completer = Completer<void>();
    
    _fetchDebounceTimer = Timer(const Duration(milliseconds: 600), () async {
      if (_appointments.isEmpty) {
        _isLoading = true;
        notifyListeners();
      }
      _errorMessage = null;

      try {
        final fresh = await _apptService.getAppointments(
          includePast: true, 
          userId: _currentUserId,
          contextAdjustment: _currentHijriAdjustment ?? 0,
        );
        _appointments = fresh;
        _sortAppointments();
        completer.complete();
      } catch (e) {
        if (e.toString().contains('isAbort: true')) {
           completer.complete();
           return;
        }
        debugPrint('❌ Fetch All Invitations Error: $e');
        _errorMessage = e.toString();
        completer.completeError(e);
      } finally {
        _isLoading = false;
        notifyListeners();
      }
    });
    
    return completer.future;
  }

  Future<void> createAppointment(Appointment appointment, {List<String>? inviteeIds, String? inviteTitle, String? inviteMessage}) async {
    // Optimistic Update: Add to list immediately
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final tempAppt = appointment.copyWith(id: tempId);
    
    _appointments.add(tempAppt);
    _sortAppointments();
    notifyListeners(); // Update UI instantly

    try {
      final newAppt = await _apptService.createAppointment(
        appointment, 
        inviteeIds: inviteeIds,
        inviteTitle: inviteTitle,
        inviteMessage: inviteMessage,
      );
      
      // Replace temp with real
      final index = _appointments.indexWhere((a) => a.id == tempId);
      if (index != -1) {
        _appointments[index] = newAppt;
      }
      _sortAppointments();
      _errorMessage = null;
    } catch (e) {
      // Keep local copy but show format error
      _errorMessage = 'Saved locally (sync failed): $e';
      print('Sync Error: $e');
    } finally {
      notifyListeners();
    }
  }

  /// الرد على دعوة (قبول/رفض)
  Future<void> respondToInvitation(
    String appointmentId, 
    InvitationStatus status, {
    String? fcfsNote,
    String? fcfsHostNote,
    String? acceptanceTitle,
    String? acceptanceMsg,
  }) async {
    final index = _appointments.indexWhere((a) => a.id == appointmentId);
    if (index == -1) return;

    final appointment = _appointments[index];
    final invitationId = appointment.currentUserInvitation?.id;
    if (invitationId == null) return;

    final now = DateTime.now();
    DateTime? acceptedAt;
    DateTime? declinedAt;

    if (status == InvitationStatus.accepted) acceptedAt = now;
    if (status == InvitationStatus.declined) declinedAt = now;

    try {
      await _invitationService.updateInvitationStatus(
        invitationId, 
        status,
        acceptedAt: acceptedAt,
        declinedAt: declinedAt,
        fcfsNote: fcfsNote,
        fcfsHostNote: fcfsHostNote,
        acceptanceTitle: acceptanceTitle,
        acceptanceMsg: acceptanceMsg,
      );
      
      final updatedInv = appointment.currentUserInvitation!.copyWith(
        status: status,
        acceptedAt: acceptedAt,
        declinedAt: declinedAt,
      );
      
      _appointments[index] = appointment.copyWith(currentUserInvitation: updatedInv);
      notifyListeners();

      // Delay fetching to allow PocketBase to process hooks and evaluation logic
      Future.delayed(const Duration(milliseconds: 500), () {
        fetchAppointments();
      });
    } catch (e) {
      _errorMessage = 'Failed to update status: $e';
      notifyListeners();
    }
  }

  /// تحديث إعدادات النسخة الشخصية (الخصوصية، التصنيف، الملاحظة الخاصة)
  Future<void> updateInvitationSettings(String appointmentId, {
    String? privacy, 
    AppointmentCategory? categories,
    String? personalNote,
  }) async {
    final index = _appointments.indexWhere((a) => a.id == appointmentId);
    if (index == -1) return;

    final appointment = _appointments[index];
    final invitationId = appointment.currentUserInvitation?.id;
    if (invitationId == null) return;

    try {
      await _invitationService.updateInvitationStatus(
        invitationId, 
        appointment.currentUserInvitation!.status,
        privacy: privacy,
        categoryId: categories?.id,
        personalNote: personalNote,
      );
      
      final updatedInv = appointment.currentUserInvitation!.copyWith(
        privacy: privacy,
        categories: categories,
        personalNote: personalNote,
      );
      
      _appointments[index] = appointment.copyWith(currentUserInvitation: updatedInv);
      
      await _localDb.saveAppointments(_appointments);
      
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to update settings: $e';
      notifyListeners();
    }
  }

  /// أرشفة الموعد (أرشفة النسخة الشخصية)
  Future<void> archiveInvitation(String appointmentId) async {
    final index = _appointments.indexWhere((a) => a.id == appointmentId);
    if (index == -1) return;

    final appointment = _appointments[index];
    final invitationId = appointment.currentUserInvitation?.id;
    if (invitationId == null) return;

    try {
      await _invitationService.updateInvitationStatus(
        invitationId, 
        appointment.currentUserInvitation!.status, 
        postStatus: PostStatus.archived
      );
      
      final updatedInv = appointment.currentUserInvitation!.copyWith(postStatus: PostStatus.archived);
      _appointments[index] = appointment.copyWith(currentUserInvitation: updatedInv);
      _appointments.removeAt(index);
      
      notifyListeners();
      
      fetchArchivedAppointments();
    } catch (e) {
      _errorMessage = 'Failed to archive invitation: $e';
      notifyListeners();
    }
  }

  Future<void> unarchiveInvitation(String appointmentId) async {
    final index = _archivedAppointments.indexWhere((a) => a.id == appointmentId);
    if (index == -1) return;

    final appointment = _archivedAppointments[index];
    final invitationId = appointment.currentUserInvitation?.id;
    if (invitationId == null) return;

    try {
      await _invitationService.updateInvitationStatus(
        invitationId, 
        appointment.currentUserInvitation!.status, 
        postStatus: PostStatus.published
      );
      
      _archivedAppointments.removeAt(index);
      
      notifyListeners();
      
      fetchAppointments();
    } catch (e) {
      _errorMessage = 'Failed to unarchive invitation: $e';
      debugPrint('Error unarchiving: $e');
      notifyListeners();
    }
  }

  Future<void> fetchArchivedAppointments() async {
    if (_currentUserId == null) return;
    try {
      _archivedAppointments = await _apptService.getAppointments(
        userId: _currentUserId,
        status: PostStatus.archived,
        includePast: true,
        perPage: 100,
        contextAdjustment: _currentHijriAdjustment ?? 0,
      );
      _archivedAppointments.sort((a, b) => a.startAt.compareTo(b.startAt));
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to fetch archived: $e');
    }
  }

  Future<void> fetchTrashedAppointments() async {
    if (_currentUserId == null) return;
    try {
      _trashedAppointments = await _apptService.getAppointments(
        userId: _currentUserId,
        status: PostStatus.trash,
        includePast: true,
        perPage: 100,
        contextAdjustment: _currentHijriAdjustment ?? 0,
      );
      _trashedAppointments.sort((a, b) => a.startAt.compareTo(b.startAt));
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to fetch trash: $e');
    }
  }

  /// حذف النسخة الشخصية من الموعد (حذف بعد القبول)
  Future<void> deleteInvitation(String appointmentId) async {
    var index = _appointments.indexWhere((a) => a.id == appointmentId);
    var listType = 'active';

    if (index == -1) {
      index = _archivedAppointments.indexWhere((a) => a.id == appointmentId);
      if (index != -1) listType = 'archived';
    }

    if (index == -1) return;

    final appointment = listType == 'active' 
        ? _appointments[index] 
        : _archivedAppointments[index];
        
    final invitationId = appointment.currentUserInvitation?.id;
    if (invitationId == null) return;

    final bool isHost = appointment.hostId == _currentUserId;

    try {
      if (isHost) {
        await _apptService.updateAppointment(appointmentId, {'is_deleted': true});
      }

      var newStatus = appointment.currentUserInvitation!.status;
      if (newStatus == InvitationStatus.accepted) {
         newStatus = InvitationStatus.deletedAfterAccept; 
      }

      await _invitationService.updateInvitationStatus(
        invitationId, 
        newStatus, 
        postStatus: PostStatus.trash
      );
      
      if (listType == 'active') {
        _appointments.removeAt(index);
      } else {
        _archivedAppointments.removeAt(index);
      }
      
      notifyListeners();
      
      fetchAppointments();
      fetchTrashedAppointments();
    } catch (e) {
      _errorMessage = 'Failed to delete appointment: $e';
      notifyListeners();
    }
  }

  /// دعوة مستخدم للموعد
  Future<void> inviteGuest(String appointmentId, String userId, {String? title, String? message}) async {
    try {
      await _invitationService.inviteGuest(appointmentId, userId, title: title, message: message);
      await fetchAppointments();
    } catch (e) {
      _errorMessage = 'Failed to send invite: $e';
      notifyListeners();
    }
  }


  /// التحقق من المواعيد المكررة المنتهية وتدويرها
  Future<void> checkAndRolloverAppointments() async {
    if (_appointments.isEmpty) return;

    final now = DateTime.now();
    bool didRollover = false;

    final candidates = _appointments.where((appt) {
       final isRecurring = appt.recurrenceType != null && appt.recurrenceType != 'none';
       final hasMore = (appt.recurrenceCount == null) || ((appt.recurrenceIndex ?? 1) < appt.recurrenceCount!);
       final isEnded = appt.startAt.add(Duration(minutes: appt.duration)).isBefore(now);
       final isHost = appt.hostId == _currentUserId;
       
       return isRecurring && hasMore && isEnded && isHost;
    }).toList();

    for (final appt in candidates) {
      try {
        await _recurrenceService.performRollover(appt);
        didRollover = true;
      } catch (e) {
        print('⚠️ Failed to rollover ${appt.id}: $e');
      }
    }

    if (didRollover) {
      fetchAppointments();
    }
  }

  Future<void> requestToJoin(Appointment appointment, {String? title, String? message}) async {
    try {
      await _invitationService.requestToJoin(appointment, title: title, message: message);
      await fetchAppointments(); 
    } catch (e) {
      _errorMessage = 'Failed to request join: $e';
      notifyListeners();
      rethrow;
    }
  }
  /// التحقق من وجود تعارض في المواعيد
  List<Appointment> getConflictingAppointments(DateTime startAt, int durationMinutes, {String? excludeId}) {
    final newStart = startAt;
    final newEnd = startAt.add(Duration(minutes: durationMinutes));
    
    return _appointments.where((appt) {
      if (appt.id == excludeId) return false;
      
      if (appt.isCancelled || appt.isDeleted || appt.isUserDeleted) return false;
      if (appt.currentUserInvitation?.postStatus == PostStatus.trash) return false;
      
      if (appt.currentUserInvitation?.status == InvitationStatus.declined) return false;
      
      final apptStart = appt.startAt;
      final apptEnd = appt.startAt.add(Duration(minutes: appt.duration));
      
      return newStart.isBefore(apptEnd) && newEnd.isAfter(apptStart);
    }).toList();
  }
}
