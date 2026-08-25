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
import '../../../../core/services/pocketbase_client.dart';
import '../../../../core/local/local_db_service.dart';

class PublicProfileProvider extends ChangeNotifier {
  final PbUserService _userService = PbUserService();
  final PbAppointmentBrowseService _appointmentBrowseService = PbAppointmentBrowseService();
  final PbModerationService _moderationService = PbModerationService();

  UserModel? _user;
  List<Appointment> _appointments = [];
  bool _isLoading = true;
  bool _isFollowing = false;
  bool _isFriend = false;
  String _relationStatus = 'none';
  String? _error;
  String _searchQuery = '';

  UserModel? get user => _user;
  String get relationStatus => _relationStatus;
  
  List<Appointment> get appointments {
    if (_searchQuery.isEmpty) return _appointments;

    final rawQuery = _searchQuery.trim().toLowerCase();
    
    // الفلترة الفورية بناءً على الكبسولات المحددة بالكامل
    if (rawQuery == '(عام)') {
      return _appointments.where((a) => a.effectivePrivacy == 'public').toList();
    }
    if (rawQuery == '(خاص)') {
      return _appointments.where((a) => a.effectivePrivacy == 'private').toList();
    }
    if (rawQuery == '(معتمدون)' || rawQuery == 'معتمدون') {
      return _appointments.where((a) => a.host?.isApproved == true).toList();
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

    if (queryWords.isEmpty) return _appointments;

    // الفلترة بناءً على الكلمات المتعددة في الاستعلام مع دعم ذكي لكلمة "معتمدون" أو "معتمد"
    return _appointments.where((a) {
      // يجب أن تتحقق كل كلمة في الاستعلام داخل الموعد
      return queryWords.every((word) {
        // إذا كتب المستخدم كلمة "معتمدون" أو "معتمد"، نتحقق مما إذا كان المضيف معتمداً/مشرفاً أولاً
        if (word == 'معتمدون' || word == 'معتمد') {
          final isHostApproved = a.host?.isApproved == true;
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

  bool get isLoading => _isLoading;
  bool get isFollowing => _isFollowing;
  bool get isFriend => _isFriend;
  String? get error => _error;
  String get searchQuery => _searchQuery;

  void filterAppointments(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> fetchData(String usernameOrId, {String? currentUserId}) async {
    _isLoading = true;
    _error = null;
    _searchQuery = '';
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
      
      // تسجيل الدخول على الملف الشخصي لزيادة عداد الزيارات محلياً
      try {
        await LocalDbService.instance.incrementUserClickCount(user.id);
        await LocalDbService.instance.saveUserLastVisit(user.id);
      } catch (e) {
        debugPrint('Error tracking profile click locally: $e');
      }

      // 1. Fetch Relationship Status, Block Status, and Appointments Concurrently
      final isSelf = user.id == currentUserId;
      final int hijriAdj = (user.hijriAdjustment ?? 0).toInt();

      Future<Map<String, dynamic>> statusFuture = isSelf || currentUserId == null 
          ? Future.value({'status': 'none', 'isFriend': false, 'isBeingFollowed': false, 'isBlocked': false, 'isBlockingMe': false}) 
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

      // Check if Viewer is Blocked BY the target user or vice versa
      if (statusData['isBlockingMe'] == true || statusData['isBlocked'] == true) {
         _error = 'BLOCK_RESTRICTED'; 
         _isLoading = false;
         notifyListeners();
         return;
      }

      _isFollowing = statusData['status'] == 'accepted';
      _isFriend = isSelf ? true : (statusData['isFriend'] as bool);
      _relationStatus = statusData['status'] ?? 'none';
      
      // هل صاحب الحساب اعتمد الزائر فعلاً؟
      // من منظور getAccreditationStatus:
      //   status       = myStatus (حالة الزائر تجاه صاحب الحساب)
      //   isBeingFollowed = theirStatus == accepted || pending (هل صاحب الحساب يتابعني)
      //   isFriend     = كلانا accepted
      // الزائر معتمد لدى صاحب الحساب = theirStatus == accepted
      //                                = isFriend (كلانا accepted)
      //                                أو isBeingFollowed فقط إذا كان theirStatus accepted وليس pending
      // أبسط تعبير: isFriend أو (isBeingFollowed && أنا accepted عنده = isFriend) →
      // في الواقع: صاحب الحساب قبل الزائر = isFriend (متبادل) أو عندما قبلني هو بدون أن أكون قبلته
      // لكن هذا لا يحدث في نظام الاعتمادات المتبادل — القبول دائماً يُنتج isFriend
      // إذن: isAccreditedByOwner = _isFriend
      final bool isAccreditedByOwner = isSelf ? true : _isFriend;
      
      List<Appointment> appts = [];
      
      if (user.isPublic || _isFollowing || isSelf) {
        // إظهار مواعيد "معتمدون" فقط للزوار المعتمدين لدى صاحب الحساب
        if (!isSelf) {
          appts = allAppts.where((a) => 
              a.effectivePrivacy == 'public' || 
              (a.effectivePrivacy == 'followers' && isAccreditedByOwner) || 
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
      final deviceInfoPlugin = DeviceInfoPlugin();
      
      // التحقق من حالة تسجيل دخول الزائر
      final pb = PocketBaseClient.instance.pb;
      final currentUser = pb.authStore.model;
      final isLoggedIn = pb.authStore.isValid && currentUser != null;

      if (isLoggedIn) {
        final name = currentUser.getStringValue('name');
        final username = currentUser.getStringValue('username');
        deviceName = name.isNotEmpty ? name : (username.isNotEmpty ? username : 'عضو');
      } else {
        if (kIsWeb) {
          final webInfo = await deviceInfoPlugin.webBrowserInfo;
          final userAgent = webInfo.userAgent?.toLowerCase() ?? '';
          final browser = webInfo.browserName.toString().replaceAll('BrowserName.', '');
          String browserName = browser;
          if (browser.isNotEmpty) {
            browserName = browser[0].toUpperCase() + browser.substring(1);
          }
          if (browserName == 'Safari') browserName = 'سفاري';
          if (browserName == 'Chrome') browserName = 'كروم';
          if (browserName == 'Firefox') browserName = 'فايرفوكس';

          if (userAgent.contains('iphone')) {
            deviceName = 'آيفون ($browserName)';
          } else if (userAgent.contains('ipad')) {
            deviceName = 'آيباد ($browserName)';
          } else if (userAgent.contains('android')) {
            deviceName = 'أندرويد ($browserName)';
          } else if (userAgent.contains('macintosh') || userAgent.contains('mac os')) {
            deviceName = 'ماك ($browserName)';
          } else if (userAgent.contains('windows')) {
            deviceName = 'ويندوز ($browserName)';
          } else {
            deviceName = 'متصفح $browserName';
          }
        } else {
          if (Platform.isIOS) {
            final iosInfo = await deviceInfoPlugin.iosInfo;
            deviceName = iosInfo.name;
          } else if (Platform.isAndroid) {
            final androidInfo = await deviceInfoPlugin.androidInfo;
            deviceName = androidInfo.model;
          } else if (Platform.isMacOS) {
            deviceName = 'ماك';
          } else if (Platform.isWindows) {
            deviceName = 'ويندوز';
          }
        }
      }

      final uniqueIdentifier = isLoggedIn ? currentUser.id : deviceName;
      final rawString = '$dateStr-$uniqueIdentifier';
      final bytes = utf8.encode(rawString);
      final hash = sha256.convert(bytes).toString();
      
      final notificationService = NotificationService();
      
      final existing = await notificationService.getNotifications(
        filter: 'user = "$targetUserId" && type = "visit" && related_id = "${isLoggedIn ? currentUser.id : hash}" && created >= "$dateStr 00:00:00"',
        perPage: 1
      );
      
      if (existing.isEmpty) {
        final message = isLoggedIn 
            ? 'قام العضو $deviceName بتصفح ملفك الشخصي.' 
            : 'قام $deviceName بتصفح ملفك الشخصي.';

        await notificationService.createNotification(
          targetUserId: targetUserId,
          title: 'توافد الجمهور',
          message: message,
          type: NotificationType.visit,
          relatedId: isLoggedIn ? currentUser.id : hash, // Store user ID if logged in so profile avatar shows!
        );
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
    _searchQuery = '';
  }

  void clear() {
    reset();
    notifyListeners();
  }
}
