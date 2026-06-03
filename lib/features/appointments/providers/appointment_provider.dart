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
import '../../../models/user.dart';
import '../../../models/article.dart';

class AppointmentProvider extends ChangeNotifier {
  final PbAppointmentService _apptService = PbAppointmentService();
  final PbAppointmentBrowseService _browseService = PbAppointmentBrowseService();
  final PbInvitationService _invitationService = PbInvitationService();
  final PbAppointmentRecurrenceService _recurrenceService = PbAppointmentRecurrenceService();
  final LocalDbService _localDb = LocalDbService.instance;
  
  List<Appointment> _appointments = [];
  List<Appointment> _archivedAppointments = [];
  List<Appointment> _trashedAppointments = [];
  List<Appointment> _bookmarkedAppointments = []; // قائمة المحفوظات الخاصة
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _refreshTimer;
  Timer? _fetchDebounceTimer;
  UnsubscribeFunc? _unsubscribeInvitations;
  String? _currentUserId;
  int? _currentHijriAdjustment;
  ModerationProvider? _moderation;
  bool _isAdmin = false;

  bool get isAdmin => _isAdmin;

  AppointmentProvider() {
    _startRefreshTimer();
  }

  /// تحديث المزود عند تغيير حالة المصادقة أو المستخدم
  void update(String? userId, int? hijriAdjustment, ModerationProvider? moderation, {bool isAdmin = false}) {
    bool changed = false;
    
    if (userId != _currentUserId || hijriAdjustment != _currentHijriAdjustment || isAdmin != _isAdmin) {
      print('🔄 AppointmentProvider: User/Adjustment/Admin changed from $_currentUserId to $userId (Admin: $isAdmin)');
      _currentUserId = userId;
      _currentHijriAdjustment = hijriAdjustment;
      _isAdmin = isAdmin;
      
      // ⚠️ Wipe local memory to avoid stale data mixing
      _appointments = [];
      _archivedAppointments = [];
      _trashedAppointments = [];
      _bookmarkedAppointments = [];
      
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
      fetchBookmarkedAppointments();
    } else if (changed && userId == null) {
      notifyListeners();
    }
  }
  
  String _searchQuery = '';

  /// الحصول على قائمة أسماء المناطق في الصفحة للبحث
  List<String> get searchRegionKeywords {
    final Set<String> regions = {};
    final mainAppointments = appointments.where((a) {
      final isHostedByMe = a.hostId == _currentUserId;
      final isAcceptedByMe = a.viewerRecord?.status == InvitationStatus.accepted;
      return isHostedByMe || isAcceptedByMe;
    }).toList();

    for (var a in mainAppointments) {
      if (a.region != null && a.region!.trim().isNotEmpty) {
        regions.add(a.region!.trim());
      }
    }
    return regions.toList()..sort();
  }

  /// الحصول على قائمة أسماء التصنيفات في الصفحة للبحث (مع كلمة معتمدون)
  List<String> get searchCategoryKeywords {
    final Set<String> categoryNames = {};
    final mainAppointments = appointments.where((a) {
      final isHostedByMe = a.hostId == _currentUserId;
      final isAcceptedByMe = a.viewerRecord?.status == InvitationStatus.accepted;
      return isHostedByMe || isAcceptedByMe;
    }).toList();

    for (var a in mainAppointments) {
      if (a.currentUserInvitation?.categories?.name != null && a.currentUserInvitation!.categories!.name.trim().isNotEmpty) {
        categoryNames.add(a.currentUserInvitation!.categories!.name.trim());
      }
    }
    final sortedCategories = categoryNames.toList()..sort();
    return [...sortedCategories, 'معتمدون'];
  }

  /// الكلمات المفتاحية لمجال البحث (المناطق المتوفرة في الصفحة أولاً، ثم التصنيفات categories، ثم كلمة معتمدون)
  List<String> get searchKeywords {
    return [...searchRegionKeywords, ...searchCategoryKeywords];
  }

  // Getters (Filter out blocked users and bookmarked items)
  List<Appointment> get appointments {
    List<Appointment> base;
    if (_moderation == null) {
      base = _appointments.where((a) => a.viewerRecord?.postStatus != PostStatus.bookmarked).toList();
    } else {
      base = _appointments.where((a) => 
        !_moderation!.isUserBlocked(a.hostId) && 
        a.viewerRecord?.postStatus != PostStatus.bookmarked
      ).toList();
    }

    if (_searchQuery.isEmpty) return base;

    final rawQuery = _searchQuery.trim().toLowerCase();
    
    // الفلترة الفورية بناءً على الكبسولات المحددة بالكامل
    if (rawQuery == '(عام)') {
      return base.where((a) => a.privacy == 'public').toList();
    }
    if (rawQuery == '(خاص)') {
      return base.where((a) => a.privacy == 'private').toList();
    }
    if (rawQuery == '(معتمدون)' || rawQuery == 'معتمدون') {
      return base.where((a) => a.host?.role == 'approved' || a.host?.role == 'admin').toList();
    }

    // دالة مساعدة لتوحيد النصوص وإزالة التشكيل العربي لتبسيط البحث والتوثيق
    String normalize(String? text) {
      if (text == null) return '';
      // إزالة علامات التشكيل العربية (الضمة، الفتحة، الكسرة، إلخ)
      final diacritics = RegExp(r'[\u064B-\u0652\u065F\u0670\u06D6-\u06ED]');
      return text.toLowerCase()
                 .replaceAll(diacritics, '')
                 .replaceAll(RegExp(r'[_\-\.,/\\|]'), ' ');
    }

    final q = normalize(rawQuery);
    final queryWords = q.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    if (queryWords.isEmpty) return base;

    // الفلترة بناءً على الكلمات المتعددة في الاستعلام مع دعم ذكي لكلمة "معتمدون" أو "معتمد"
    return base.where((a) {
      // يجب أن تتحقق كل كلمة في الاستعلام داخل الموعد
      return queryWords.every((word) {
        // إذا كتب المستخدم كلمة "معتمدون" أو "معتمد"، نتحقق مما إذا كان المضيف معتمداً/مشرفاً أولاً
        if (word == 'معتمدون' || word == 'معتمد') {
          final isHostApproved = a.host?.role == 'approved' || a.host?.role == 'admin';
          if (isHostApproved) return true;
        }
        
        final titleMatch = normalize(a.title).contains(word);
        final regionMatch = normalize(a.region).contains(word);
        final buildingMatch = normalize(a.building).contains(word);
        final hostMatch = normalize(a.host?.name).contains(word);
        final categoryMatch = normalize(a.currentUserInvitation?.categories?.name).contains(word);
        final participantsMatch = a.participants?.any((p) => 
          normalize(p.user?.name).contains(word)
        ) ?? false;
        
        return titleMatch || regionMatch || buildingMatch || hostMatch || categoryMatch || participantsMatch;
      });
    }).toList();
  }

  void filterAppointments(String query) {
    _searchQuery = query;
    notifyListeners();
  }
  
  List<Appointment> get archivedAppointments {
    if (_moderation == null) return _archivedAppointments;
    return _archivedAppointments.where((a) => !_moderation!.isUserBlocked(a.hostId)).toList();
  }
  
  List<Appointment> get trashedAppointments {
    if (_moderation == null) return _trashedAppointments;
    return _trashedAppointments.where((a) => !_moderation!.isUserBlocked(a.hostId)).toList();
  }

  List<Appointment> get bookmarkedAppointments {
    return _bookmarkedAppointments.where((a) {
      final isBlocked = _moderation?.isUserBlocked(a.hostId) ?? false;
      final isSourceDead = a.isCancelled || a.isDeleted;
      return !isBlocked && !isSourceDead;
    }).toList();
  }

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// عدد الدعوات المعلقة (الواردة)
  int get pendingInvitationsCount {
    if (_currentUserId == null) return 0;
    return _appointments.where((a) {
      // Actionable for me as a GUEST (Invite received)
      final isIncomingInvite = a.hostId != _currentUserId && 
                               a.viewerRecord?.status == InvitationStatus.pending;
      
      if (!isIncomingInvite) return false;

      // Global safety filters
      return a.viewerRecord?.postStatus == PostStatus.published &&
             !a.isPast &&
             !a.isCancelled &&
             !a.isDeleted;
    }).length;
  }

  /// حالة الأفاتار بناءً على المواعيد الحالية
  AvatarStatus get avatarStatus {
    // Ensure we only consider PUBLISHED and ACCEPTED appointments
    final activeAppointments = _appointments.where((a) => 
      a.viewerRecord?.postStatus == PostStatus.published &&
      a.viewerRecord?.status == InvitationStatus.accepted
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
        print('📦 Loaded ${cached.length} appointments from local DB');
        _appointments = cached;
        _sortAppointments();
      } else {
         print('📦 Local DB empty');
      }
    } catch (e) {
      print('Failed to load local appointments: $e');
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
        print('☁️ Fetched ${fresh.length} fresh appointments from server');
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
                  print('🔔 Realtime Event for me: ${e.action}');
                  // Add a small delay robustly to avoid fetching mid-transaction
                  Future.delayed(const Duration(milliseconds: 500), () {
                    fetchAllInvitations();
                  });
                } else {
                  print('🔔 Realtime Event for others (${e.record?.id}), ignoring.');
                }
              });
            } catch (e) {
               print('⚠️ Realtime subscription failed (non-fatal): $e');
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
        print('❌ Fetch Appointments Error: $e');
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
        print('❌ Fetch All Invitations Error: $e');
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
    final invitationId = appointment.viewerRecord?.id;
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
      
      final updatedInv = appointment.viewerRecord!.copyWith(
        status: status,
        acceptedAt: acceptedAt,
        declinedAt: declinedAt,
      );
      
      _appointments[index] = appointment.copyWith(
        currentUserInvitation: appointment.currentUserInvitation == appointment.viewerRecord ? updatedInv : null,
        viewerInvitation: appointment.viewerInvitation == appointment.viewerRecord ? updatedInv : null,
      );
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
    String? linkedArticleId,
    Article? linkedArticle,
  }) async {
    final index = _appointments.indexWhere((a) => a.id == appointmentId);
    if (index == -1) return;

    final appointment = _appointments[index];
    final originalInv = appointment.viewerRecord;
    if (originalInv == null) return;

    // 1. Optimistic Update: Update local state immediately
    final updatedInv = originalInv.copyWith(
      privacy: privacy ?? originalInv.privacy,
      categories: categories ?? originalInv.categories,
      personalNote: personalNote ?? originalInv.personalNote,
      linkedArticleId: linkedArticleId ?? originalInv.linkedArticleId,
      linkedArticle: linkedArticle ?? originalInv.linkedArticle,
    );
    
    _appointments[index] = appointment.copyWith(
      currentUserInvitation: appointment.currentUserInvitation == originalInv ? updatedInv : null,
      viewerInvitation: appointment.viewerInvitation == originalInv ? updatedInv : null,
    );
    notifyListeners();

    try {
      // 2. Perform network request in the background
      await _invitationService.updateInvitationStatus(
        originalInv.id, 
        originalInv.status,
        privacy: privacy,
        categoryId: categories?.id,
        personalNote: personalNote,
        linkedArticleId: linkedArticleId,
      );
      
      // 3. If Host, ALSO update the Master Appointment Record for global consistency
      final bool isHost = appointment.hostId == _currentUserId;
      if (isHost && privacy != null) {
        await _apptService.updateAppointment(appointment.id, {'privacy': privacy});
      }

      // 4. Update local cache after successful network request
      await _localDb.saveAppointments(_appointments);
    } catch (e) {
      print('❌ Failed to update settings: $e');
      _errorMessage = 'Failed to update settings: $e';
      
      // 4. Revert state on error
      final currentIndex = _appointments.indexWhere((a) => a.id == appointmentId);
      if (currentIndex != -1) {
        _appointments[currentIndex] = appointment.copyWith(
          currentUserInvitation: appointment.currentUserInvitation == originalInv ? originalInv : null,
          viewerInvitation: appointment.viewerInvitation == originalInv ? originalInv : null,
        );
      }
      
      notifyListeners();
    }
  }

  /// أرشفة الموعد (أرشفة النسخة الشخصية)
  Future<void> archiveInvitation(String appointmentId) async {
    final indexBefore = _appointments.indexWhere((a) => a.id == appointmentId);
    if (indexBefore == -1) return;

    final appointment = _appointments[indexBefore];
    final invitationId = appointment.viewerRecord?.id;
    if (invitationId == null) return;

    final now = DateTime.now();

    // 1. Optimistic Update: Move from active to archived lists immediately
    _appointments.removeAt(indexBefore);
    
    final updatedInv = appointment.viewerRecord!.copyWith(
      postStatus: PostStatus.archived,
    );
    final archivedAppt = appointment.copyWith(
      currentUserInvitation: appointment.currentUserInvitation == appointment.viewerRecord ? updatedInv : null,
      viewerInvitation: appointment.viewerInvitation == appointment.viewerRecord ? updatedInv : null,
    );

    _archivedAppointments.add(archivedAppt);
    _archivedAppointments.sort((a, b) => b.startAt.compareTo(a.startAt));
    _sortAppointments();
    notifyListeners();

    try {
      // 2. Background API Call
      await _invitationService.updateInvitationStatus(
        invitationId, 
        appointment.viewerRecord!.status, 
        postStatus: PostStatus.archived,
        archivedAt: now,
      );
      
      // Save local cache state
      await _localDb.saveAppointments(_appointments);
      
      // Quiet background refresh of archive list to sync completely
      await fetchArchivedAppointments();
    } catch (e) {
      print('❌ Failed to archive invitation: $e');
      _errorMessage = 'Failed to archive invitation: $e';
      
      // 3. Rollback on failure
      _archivedAppointments.removeWhere((a) => a.id == appointmentId);
      if (indexBefore <= _appointments.length) {
        _appointments.insert(indexBefore, appointment);
      } else {
        _appointments.add(appointment);
      }
      _sortAppointments();
      notifyListeners();
    }
  }

  Future<void> unarchiveInvitation(String appointmentId) async {
    final indexBefore = _archivedAppointments.indexWhere((a) => a.id == appointmentId);
    if (indexBefore == -1) return;

    final appointment = _archivedAppointments[indexBefore];
    final invitationId = appointment.viewerRecord?.id;
    if (invitationId == null) return;

    // 1. Optimistic Update: Move from archived to active lists immediately
    _archivedAppointments.removeAt(indexBefore);
    
    final updatedInv = appointment.viewerRecord!.copyWith(
      postStatus: PostStatus.published,
    );
    final unarchivedAppt = appointment.copyWith(
      currentUserInvitation: appointment.currentUserInvitation == appointment.viewerRecord ? updatedInv : null,
      viewerInvitation: appointment.viewerInvitation == appointment.viewerRecord ? updatedInv : null,
    );

    _appointments.add(unarchivedAppt);
    _sortAppointments();
    notifyListeners();

    try {
      // 2. Background API Call
      await _invitationService.updateInvitationStatus(
        invitationId, 
        appointment.viewerRecord!.status, 
        postStatus: PostStatus.published
      );
      
      // Save local cache state
      await _localDb.saveAppointments(_appointments);
      
      // Quiet background refresh of active list
      await fetchAppointments();
    } catch (e) {
      print('❌ Failed to unarchive invitation: $e');
      _errorMessage = 'Failed to unarchive invitation: $e';
      
      // 3. Rollback on failure
      _appointments.removeWhere((a) => a.id == appointmentId);
      if (indexBefore <= _archivedAppointments.length) {
        _archivedAppointments.insert(indexBefore, appointment);
      } else {
        _archivedAppointments.add(appointment);
      }
      _archivedAppointments.sort((a, b) => b.startAt.compareTo(a.startAt));
      _sortAppointments();
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
      _archivedAppointments.sort((a, b) => b.startAt.compareTo(a.startAt));
      notifyListeners();
    } catch (e) {
      print('Failed to fetch archived: $e');
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
      _trashedAppointments.sort((a, b) => b.startAt.compareTo(a.startAt));
      notifyListeners();
    } catch (e) {
      print('Failed to fetch trash: $e');
    }
  }

  /// حذف النسخة الشخصية من الموعد (حذف بعد القبول)
  Future<void> deleteInvitation(String appointmentId) async {
    var indexBefore = _appointments.indexWhere((a) => a.id == appointmentId);
    var listType = 'active';

    if (indexBefore == -1) {
      indexBefore = _archivedAppointments.indexWhere((a) => a.id == appointmentId);
      if (indexBefore != -1) listType = 'archived';
    }

    if (indexBefore == -1 && !_isAdmin) return;

    final appointment = indexBefore != -1 
        ? (listType == 'active' ? _appointments[indexBefore] : _archivedAppointments[indexBefore])
        : null;

    final bool isHost = appointment?.hostId == _currentUserId;

    // 1. Optimistic Update: Remove from current list and add to trashed list
    if (appointment != null) {
      if (listType == 'active') {
        _appointments.removeAt(indexBefore);
      } else {
        _archivedAppointments.removeAt(indexBefore);
      }

      final now = DateTime.now();
      var newStatus = appointment.viewerRecord?.status ?? InvitationStatus.pending;
      if (!isHost && newStatus == InvitationStatus.accepted) {
        newStatus = InvitationStatus.deletedAfterAccept;
      }

      final updatedInv = appointment.viewerRecord?.copyWith(
        postStatus: PostStatus.trash,
        status: newStatus,
        deletedAt: now,
      );

      final trashedAppt = appointment.copyWith(
        isCancelled: (isHost || _isAdmin) ? true : appointment.isCancelled,
        isDeleted: (isHost || _isAdmin) ? true : appointment.isDeleted,
        currentUserInvitation: appointment.currentUserInvitation == appointment.viewerRecord ? updatedInv : null,
        viewerInvitation: appointment.viewerInvitation == appointment.viewerRecord ? updatedInv : null,
      );

      _trashedAppointments.add(trashedAppt);
      _trashedAppointments.sort((a, b) => b.startAt.compareTo(a.startAt));
      _sortAppointments();
      notifyListeners();
    }

    try {
      // 2. Perform Network Call
      if (isHost || _isAdmin) {
        await _apptService.cancelAppointment(appointmentId);
      } else {
        if (appointment != null) {
          final invitationId = appointment.viewerRecord?.id;
          if (invitationId != null) {
            var newStatus = appointment.viewerRecord!.status;
            if (newStatus == InvitationStatus.accepted) {
               newStatus = InvitationStatus.deletedAfterAccept; 
            }

            final now = DateTime.now();
            await _invitationService.updateInvitationStatus(
              invitationId, 
              newStatus, 
              postStatus: PostStatus.trash,
              deletedAt: now,
            );
          }
        }
      }

      // Save local cache state
      await _localDb.saveAppointments(_appointments);

      // Background sync to verify state
      await fetchAppointments();
      await fetchTrashedAppointments();
    } catch (e) {
      print('❌ Failed to delete appointment: $e');
      _errorMessage = 'Failed to delete appointment: $e';
      
      // 3. Rollback on failure
      if (appointment != null) {
        _trashedAppointments.removeWhere((a) => a.id == appointmentId);
        
        if (listType == 'active') {
          if (indexBefore <= _appointments.length) {
            _appointments.insert(indexBefore, appointment);
          } else {
            _appointments.add(appointment);
          }
        } else {
          if (indexBefore <= _archivedAppointments.length) {
            _archivedAppointments.insert(indexBefore, appointment);
          } else {
            _archivedAppointments.add(appointment);
          }
          _archivedAppointments.sort((a, b) => b.startAt.compareTo(a.startAt));
        }
        _sortAppointments();
        notifyListeners();
      }
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
       final isEnded = appt.startAt.add(Duration(minutes: appt.duration)).isBefore(now.toUtc());
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
    final newStart = startAt.toUtc();
    final newEnd = newStart.add(Duration(minutes: durationMinutes));
    
    return _appointments.where((appt) {
      if (appt.id == excludeId) return false;
      
      if (appt.isCancelled || appt.isDeleted || appt.isUserDeleted || appt.isArchived) return false;
      if (appt.viewerRecord?.postStatus == PostStatus.trash) return false;
      if (appt.viewerRecord?.status == InvitationStatus.declined) return false;
      
      // All-day event check (Synchronized with AddEventProvider)
      if (appt.duration <= 0 || appt.duration >= 1440) {
        final aDate = DateTime(appt.fullDateTime.year, appt.fullDateTime.month, appt.fullDateTime.day);
        final myDate = DateTime(startAt.year, startAt.month, startAt.day);
        return aDate.isAtSameMomentAs(myDate);
      }

      final apptStart = appt.startAt; // UTC
      final apptEnd = appt.startAt.add(Duration(minutes: appt.duration));
      
      return newStart.isBefore(apptEnd) && newEnd.isAfter(apptStart);
    }).toList();
  }

  /// مزامنة وحفظ مواعيد عامة في سجل المستخدم (بفلسفة الظل/البوك مارك)
  Future<bool> toggleBookmark(Appointment appointment, UserModel user) async {
    try {
      final isBookmarked = await _invitationService.toggleBookmark(appointment.id, user.id);
      
      // Refresh local lists
      await fetchAppointments();
      await fetchBookmarkedAppointments();
      
      return isBookmarked;
    } catch (e) {
      print('❌ Failed to toggle bookmark: $e');
      rethrow;
    }
  }

  Future<void> fetchBookmarkedAppointments() async {
    if (_currentUserId == null) return;
    try {
      _bookmarkedAppointments = await _apptService.getAppointments(
        userId: _currentUserId,
        status: PostStatus.bookmarked,
        includePast: true,
        perPage: 100,
        contextAdjustment: _currentHijriAdjustment ?? 0,
      );
      _bookmarkedAppointments.sort((a, b) => b.startAt.compareTo(a.startAt));
      notifyListeners();
    } catch (e) {
      print('Failed to fetch bookmarked: $e');
    }
  }
}
