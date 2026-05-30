import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../../models/user.dart';
import '../../../../models/appointment.dart';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';

import '../../settings/services/pb_user_service.dart';
import '../../appointments/services/pb_appointment_browse_service.dart';
import '../../settings/services/pb_moderation_service.dart';
import '../../notifications/services/notification_service.dart';
import '../../../../models/notification.dart';

class PublicProfileProvider extends ChangeNotifier {
  final PbUserService _userService = PbUserService();
  final PbAppointmentBrowseService _appointmentBrowseService = PbAppointmentBrowseService();
  final PbModerationService _moderationService = PbModerationService();

  UserModel? _user;
  List<Appointment> _appointments = [];
  bool _isLoading = true;
  bool _isFollowing = false;
  bool _isFriend = false;
  String? _error;

  UserModel? get user => _user;
  List<Appointment> get appointments => _appointments;
  bool get isLoading => _isLoading;
  bool get isFollowing => _isFollowing;
  bool get isFriend => _isFriend;
  String? get error => _error;

  Future<void> fetchData(String usernameOrId, {String? currentUserId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = await _userService.getPublicProfile(usernameOrId);
      
      if (user == null) {
        _error = 'المستخدم غير موجود';
        _isLoading = false;
        notifyListeners();
        return;
      }

      _user = user;
      
      // 1.5 Check if Viewer is Blocked BY the target user
      if (currentUserId != null && currentUserId != user.id) {
        final blockedByOther = await _moderationService.isBlockedBy(user.id);
        if (blockedByOther) {
           _error = 'BLOCK_RESTRICTED'; 
           _isLoading = false;
           notifyListeners();
           return;
        }
      }

      // 2. Fetch Relationship Status and Appointments Concurrently
      final isSelf = user.id == currentUserId;
      final int hijriAdj = (user.hijriAdjustment ?? 0).toInt();

      Future<Map<String, dynamic>> statusFuture = isSelf || currentUserId == null 
          ? Future.value({'status': 'none', 'isFriend': false, 'isBeingFollowed': false}) 
          : _userService.getAccreditationStatus(user.id);
          
      // Fetch both public and follower appointments. 
      // We will filter out follower ones later if not a friend in memory.
      Future<List<Appointment>> apptsFuture = _appointmentBrowseService.getPublicAppointments(
        user.id,
        viewerId: currentUserId,
        includeFollowers: true, // Fetch optimistically
        includePrivate: isSelf,
        contextAdjustment: hijriAdj,
      );

      final results = await Future.wait([statusFuture, apptsFuture]);
      final statusData = results[0] as Map<String, dynamic>;
      final allAppts = results[1] as List<Appointment>;

      _isFollowing = statusData['status'] == 'accepted';
      _isFriend = isSelf ? true : (statusData['isFriend'] as bool);
      
      List<Appointment> appts = [];
      
      if (user.isPublic || _isFollowing || isSelf) {
        // Filter out followers-only appointments if not a friend
        if (!_isFriend && !isSelf) {
          appts = allAppts.where((a) => 
              a.effectivePrivacy == 'public' || 
              (a.effectivePrivacy == 'followers' && _isFriend) || 
              a.viewerInvitation != null
          ).toList();
        } else {
          appts = allAppts;
        }
      }

      // Priority sorting: Now > Upcoming > Past
      appts.sort((a, b) {
        int score(Appointment app) {
          if (app.isNow) return 0;
          if (app.isUpcoming) return 1;
          return 2;
        }
        
        int sA = score(a);
        int sB = score(b);
        if (sA != sB) return sA.compareTo(sB);
        
        if (sA == 2) {
          return b.fullDateTime.compareTo(a.fullDateTime);
        }
        return a.fullDateTime.compareTo(b.fullDateTime);
      });

      _appointments = appts;
      
      if (kDebugMode) {
        print('📱 [PublicProfileProvider] Fetched ${allAppts.length} total, showing ${appts.length} after filter');
        print('   - isSelf: $isSelf, isFriend: $_isFriend, isFollowing: $_isFollowing, currentUserId: $currentUserId');
        print('   - User ID: ${user?.id}, Username: ${user?.username}');
        print('   - Accreditation status data: $statusData');
        print('   - Total appointments: ${allAppts.length}');
        print('   - Followers appointments: ${allAppts.where((a) => a.effectivePrivacy == "followers").length}');
        print('   - Public appointments: ${allAppts.where((a) => a.effectivePrivacy == "public").length}');
        print('   - Private appointments: ${allAppts.where((a) => a.effectivePrivacy == "private").length}');
        
        for (var a in allAppts) {
          print('   - Appt: ${a.title}, ID: ${a.id}');
          print('     ↳ Global Privacy: ${a.privacy}, Effective: ${a.effectivePrivacy}');
          print('     ↳ Invited: ${a.viewerInvitation != null}, Host: ${a.host?.id}');
          if (a.effectivePrivacy == 'followers') {
            print('     ↳ [FOLLOWERS] Should be visible only if isFriend: $_isFriend');
            if (!_isFriend && !isSelf) {
              print('     ↳ [FILTERED OUT] Because isFriend=$_isFriend and isSelf=$isSelf');
            }
          }
        }
      }

      _isLoading = false;
      notifyListeners();

      if (currentUserId == null && user.isPublic) {
        _trackAnonymousVisit(user.id);
      }
    } catch (e) {
      _error = 'حدث خطأ في جلب البيانات';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _trackAnonymousVisit(String targetUserId) async {
    try {
      final now = DateTime.now().toUtc();
      final dateStr = '${now.year}-${now.month}-${now.day}';
      
      String deviceName = 'جهاز غير معروف';
      String deviceType = 'عابر';
      
      final deviceInfoPlugin = DeviceInfoPlugin();
      
      if (kIsWeb) {
        final webInfo = await deviceInfoPlugin.webBrowserInfo;
        deviceName = webInfo.browserName.toString().replaceAll('BrowserName.', '');
        deviceType = 'متصفح';
      } else {
        if (Platform.isIOS) {
          final iosInfo = await deviceInfoPlugin.iosInfo;
          deviceName = iosInfo.name;
          deviceType = 'آيفون';
        } else if (Platform.isAndroid) {
          final androidInfo = await deviceInfoPlugin.androidInfo;
          deviceName = androidInfo.model;
          deviceType = 'أندرويد';
        } else if (Platform.isMacOS) {
          deviceName = 'ماك';
          deviceType = 'حاسب';
        } else if (Platform.isWindows) {
          deviceName = 'ويندوز';
          deviceType = 'حاسب';
        }
      }

      final rawString = '$dateStr-$deviceName';
      final bytes = utf8.encode(rawString);
      final hash = sha256.convert(bytes).toString();
      
      final notificationService = NotificationService();
      
      final existing = await notificationService.getNotifications(
        filter: 'user = "$targetUserId" && type = "visit" && related_id = "$hash"',
        perPage: 1
      );
      
      if (existing.isEmpty) {
        await notificationService.createNotification(
          targetUserId: targetUserId,
          title: 'زيارة مجهولة',
          message: 'قام $deviceType ($deviceName) باستعراض صفحتك الشخصية للتو.',
          type: NotificationType.visit,
          relatedId: hash,
        );
      } else {
        // Option: Update the time of the existing visit?
        // In PocketBase, we can't easily "touch" updated_at without changing data, 
        // but for now 1 notification per day per device is perfect to avoid spam.
      }
      
    } catch (e) {
      print('⚠️ Failed to track anonymous visit: $e');
    }
  }

  void reset() {
    _user = null;
    _appointments = [];
    _isLoading = true;
    _isFollowing = false;
    _isFriend = false;
    _error = null;
  }
}
