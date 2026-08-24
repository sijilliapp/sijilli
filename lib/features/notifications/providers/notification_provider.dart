import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../../../../models/notification.dart';
import '../../../../models/appointment.dart';
import '../services/notification_service.dart';
import '../../appointments/services/pb_appointment_service.dart';
import '../../../core/services/pocketbase_client.dart';
import '../../../../routes/app_router.dart';
import '../widgets/in_app_notification_banner.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationService _service = NotificationService();
  final PbAppointmentService _apptService = PbAppointmentService();
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  UnsubscribeFunc? _unsubscribeFunc;
  UnsubscribeFunc? _unsubscribeFriendshipFunc;
  String? _currentUserId;
  int _pendingFollowsCount = 0;
  bool _hasCheckedMissed = false;

  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  int get pendingFollowsCount => _pendingFollowsCount;

  /// Update provider state when authentication changes.
  /// This synchronously drops the realtime connection to prevent 403 mismatches
  /// when PocketBase's AuthStore is changed.
  void updateAuth(String? userId) {
    if (_currentUserId != userId) {
      _currentUserId = userId;
      // If logging out, clear memory and subscriptions immediately
      if (userId == null) {
        if (_unsubscribeFunc != null) {
          _unsubscribeFunc!(); // Unsubscribe fire-and-forget
          _unsubscribeFunc = null;
          print('🔌 [NotificationProvider] Dropped realtime subscription due to auth change.');
        }
        if (_unsubscribeFriendshipFunc != null) {
          _unsubscribeFriendshipFunc!();
          _unsubscribeFriendshipFunc = null;
        }
        _notifications = [];
        _pendingFollowsCount = 0;

        // Reset preferences to default values on logout
        _notifyAll = true;
        _notifyFollows = true;
        _notifyInvites = true;
        _notifyActive = true;
        _notifyOneDayBefore = true;
        _notifyVisits = true;
        _notifyBookmarks = true;
        _notifyBeforeOffset = true;
        _notifyBeforeOffsetMinutes = 15;
        _notifySalutes = true;
        _notifySystem = true;
        _notifyReminders = true;

        // Wipe preferences from SharedPreferences
        SharedPreferences.getInstance().then((prefs) {
          prefs.remove(_keyNotifyAll);
          prefs.remove(_keyNotifyFollows);
          prefs.remove(_keyNotifyInvites);
          prefs.remove(_keyNotifyActive);
          prefs.remove(_keyNotifyOneDayBefore);
          prefs.remove(_keyNotifyVisits);
          prefs.remove(_keyNotifyBookmarks);
          prefs.remove(_keyNotifyBeforeOffset);
          prefs.remove(_keyNotifyBeforeOffsetMinutes);
          prefs.remove(_keyNotifySalutes);
          prefs.remove(_keyNotifySystem);
          prefs.remove(_keyNotifyReminders);
        }).catchError((e) {
          print('⚠️ Failed to clear notification preferences: $e');
        });

        // Delay notifyListeners to avoid build phase conflicts
        Future.microtask(() => notifyListeners());
      }
    }
  }
  
  // Preference Keys
  static const String _keyNotifyAll = 'notify_all';
  static const String _keyNotifyFollows = 'notify_follows';
  static const String _keyNotifyInvites = 'notify_invites';
  static const String _keyNotifyActive = 'notify_active';
  static const String _keyNotifyOneDayBefore = 'notify_one_day_before';
  static const String _keyNotifyVisits = 'notify_visits';
  static const String _keyNotifyBookmarks = 'notify_bookmarks';
  static const String _keyNotifyBeforeOffset = 'notify_before_offset';
  static const String _keyNotifyBeforeOffsetMinutes = 'notify_before_offset_minutes';
  static const String _keyNotifySalutes = 'notify_salutes';
  static const String _keyNotifySystem = 'notify_system';
  static const String _keyNotifyReminders = 'notify_reminders';

  // Settings State
  bool _notifyAll = true;
  bool _notifyFollows = true;
  bool _notifyInvites = true;
  bool _notifyActive = true;
  bool _notifyOneDayBefore = true;
  bool _notifyVisits = true;
  bool _notifyBookmarks = true;
  bool _notifyBeforeOffset = true;
  int _notifyBeforeOffsetMinutes = 15;
  bool _notifySalutes = true;
  bool _notifySystem = true;
  bool _notifyReminders = true;

  bool get notifyAll => _notifyAll;
  bool get notifyFollows => _notifyFollows;
  bool get notifyInvites => _notifyInvites;
  bool get notifyActive => _notifyActive;
  bool get notifyOneDayBefore => _notifyOneDayBefore;
  bool get notifyVisits => _notifyVisits;
  bool get notifyBookmarks => _notifyBookmarks;
  bool get notifyBeforeOffset => _notifyBeforeOffset;
  int get notifyBeforeOffsetMinutes => _notifyBeforeOffsetMinutes;
  bool get notifySalutes => _notifySalutes;
  bool get notifySystem => _notifySystem;
  bool get notifyReminders => _notifyReminders;
  
  // Counts
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  NotificationProvider();

  Future<void> _initLocalNotifications() async {
    tz.initializeTimeZones();

    // Use the monochrome notification icon
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('ic_stat_onesignal_default');

    final DarwinInitializationSettings initializationSettingsDarwin =
        const DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _localNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        print('🔔 Notification tapped: ${response.payload}');
        if (response.payload != null && response.payload!.isNotEmpty) {
          try {
            final Map<String, dynamic> json = jsonDecode(response.payload!);
            final notification = NotificationModel.fromJson(json);
            AppRouter.handleNotificationTap(notification);
          } catch (e) {
            print('⚠️ Error handling notification response tap: $e');
          }
        }
      },
    );

    // Request permissions for Android 13+
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _localNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      final bool? granted = await androidImplementation.requestNotificationsPermission();
      print('🔔 Notification Permission Granted: $granted');
    }
  }

  /// Initialize and fetch notifications for a specific user
  Future<void> init(String userId) async {
    _hasCheckedMissed = false;
    await _loadSettings();
    await _initLocalNotifications();
    await fetchNotifications(userId);
    await fetchPendingFollowsCount(userId);
    await _subscribeToRealtime(userId);
    await _subscribeToFriendshipRealtime(userId);
    // Sync APNs token for iOS push notifications
    syncAPNSToken(userId);
    
    // Show missed notifications that occurred while app was offline
    _showMissedNotifications();
  }

  Future<void> syncAPNSToken(String userId) async {
    if (kIsWeb || !Platform.isIOS) return;
    try {
      const channel = MethodChannel('com.sijilli.app/apns');
      
      // Set handler to listen for dynamic callbacks from native code on first launch
      channel.setMethodCallHandler((call) async {
        if (call.method == 'onTokenReceived') {
          final String? token = call.arguments as String?;
          print('🔔 [NotificationProvider] Realtime APNs Token received: $token');
          if (token != null && token.isNotEmpty) {
            final pb = PocketBaseClient.instance.pb;
            await pb.collection('users').update(userId, body: {
              'apnsToken': token,
            });
            print('✅ [NotificationProvider] APNs Token synced to PocketBase in real-time.');
          }
        }
      });

      final String? token = await channel.invokeMethod<String>('getAPNSToken');
      print('🔔 [NotificationProvider] Retrieved APNs Token: $token');
      if (token != null && token.isNotEmpty) {
        final pb = PocketBaseClient.instance.pb;
        await pb.collection('users').update(userId, body: {
          'apnsToken': token,
        });
        print('✅ [NotificationProvider] APNs Token synced to PocketBase successfully.');
      }
    } catch (e) {
      print('⚠️ [NotificationProvider] Failed to sync APNs Token: $e');
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _notifyAll = prefs.getBool(_keyNotifyAll) ?? true;
    _notifyFollows = prefs.getBool(_keyNotifyFollows) ?? true;
    _notifyInvites = prefs.getBool(_keyNotifyInvites) ?? true;
    _notifyActive = prefs.getBool(_keyNotifyActive) ?? true;
    _notifyOneDayBefore = prefs.getBool(_keyNotifyOneDayBefore) ?? true;
    _notifyVisits = prefs.getBool(_keyNotifyVisits) ?? true;
    _notifyBookmarks = prefs.getBool(_keyNotifyBookmarks) ?? true;
    _notifyBeforeOffset = prefs.getBool(_keyNotifyBeforeOffset) ?? true;
    _notifyBeforeOffsetMinutes = prefs.getInt(_keyNotifyBeforeOffsetMinutes) ?? 15;
    _notifySalutes = prefs.getBool(_keyNotifySalutes) ?? true;
    _notifySystem = prefs.getBool(_keyNotifySystem) ?? true;
    _notifyReminders = prefs.getBool(_keyNotifyReminders) ?? true;

    // مزامنة حالة الاشتراك مع خوادم OneSignal عند تشغيل التطبيق
    try {
      if (_notifyAll) {
        OneSignal.User.pushSubscription.optIn();
      } else {
        OneSignal.User.pushSubscription.optOut();
      }
    } catch (_) {}

    notifyListeners();
  }

  Future<void> setNotifyAll(bool value) async {
    _notifyAll = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotifyAll, value);
    
    // تفعيل أو إيقاف اشتراك الإشعارات بالكامل على خادم OneSignal
    try {
      if (value) {
        await OneSignal.User.pushSubscription.optIn();
        print('🔔 [OneSignal] Opted in to push notifications');
      } else {
        await OneSignal.User.pushSubscription.optOut();
        print('🔇 [OneSignal] Opted out of push notifications');
      }
    } catch (e) {
      print('⚠️ [OneSignal] Failed to update push subscription status: $e');
    }

    notifyListeners();
  }

  Future<void> setNotifyFollows(bool value) async {
    _notifyFollows = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotifyFollows, value);
    notifyListeners();
  }

  Future<void> setNotifyInvites(bool value) async {
    _notifyInvites = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotifyInvites, value);
    notifyListeners();
  }

  Future<void> setNotifyActive(bool value) async {
    _notifyActive = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotifyActive, value);
    notifyListeners();
  }

  Future<void> setNotifyOneDayBefore(bool value) async {
    _notifyOneDayBefore = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotifyOneDayBefore, value);
    notifyListeners();
  }

  Future<void> setNotifyVisits(bool value) async {
    _notifyVisits = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotifyVisits, value);
    notifyListeners();
  }

  Future<void> setNotifyBookmarks(bool value) async {
    _notifyBookmarks = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotifyBookmarks, value);
    notifyListeners();
  }

  Future<void> setNotifyBeforeOffset(bool value) async {
    _notifyBeforeOffset = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotifyBeforeOffset, value);
    notifyListeners();
  }

  Future<void> setNotifyBeforeOffsetMinutes(int value) async {
    _notifyBeforeOffsetMinutes = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyNotifyBeforeOffsetMinutes, value);
    notifyListeners();
  }

  Future<void> setNotifySalutes(bool value) async {
    _notifySalutes = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotifySalutes, value);
    notifyListeners();
  }

  Future<void> setNotifySystem(bool value) async {
    _notifySystem = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotifySystem, value);
    notifyListeners();
  }

  Future<void> setNotifyReminders(bool value) async {
    _notifyReminders = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotifyReminders, value);
    notifyListeners();
  }

  /// Fetch initial list
  Future<void> fetchNotifications(String userId) async {
    // fetching always happens to show in-app list history 
    // regardless of push settings? Protocol usually implies "Push" settings.
    // In-app notifications usually persist.
    // I will keep fetch as is.
    _isLoading = true;
    notifyListeners();

    try {

      final rawNotifications = await _service.getNotifications(filter: 'user = "$userId"');

      // 🧹 Filter out notifications related to Archived/Trash appointments
      final apptRelatedIds = rawNotifications
          .where((n) => 
              n.type == NotificationType.invite || 
              n.type == NotificationType.reminder || 
              n.type == NotificationType.cancel || 
              n.type == NotificationType.approvalRequest)
          .map((n) => n.relatedId)
          .where((id) => id.isNotEmpty) // Safety check
          .toSet()
          .toList();

      if (apptRelatedIds.isNotEmpty) {
        // 1. Filter out Personal Archive/Trash
        final ignoredLocalIds = await _apptService.getArchivedOrTrashedIds(userId, apptRelatedIds);
        
        // 2. Filter out Inactive Assignments (Past/Cancelled/GlobalDeleted)
        final inactiveGlobalIds = await _apptService.getInactiveAppointmentIds(apptRelatedIds);
        
        // Combine sets
        final allIgnoredIds = {...ignoredLocalIds, ...inactiveGlobalIds};
        
        if (allIgnoredIds.isNotEmpty) {
          _notifications = rawNotifications.where((n) => !allIgnoredIds.contains(n.relatedId)).toList();
        } else {
          _notifications = rawNotifications;
        }
      } else {
        _notifications = rawNotifications;
      }

    } catch (e) {
      print('Error fetching notifications: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchPendingFollowsCount(String userId) async {
    try {
      final pb = PocketBaseClient.instance.pb;
      // Broaden filter to get all participations and filter in-memory for safety
      final results = await pb.collection('friendship').getFullList(
        filter: 'user_a = "$userId" || user_b = "$userId"',
      );
      
      int count = 0;
      for (final f in results) {
        final isUserA = f.data['user_a'] == userId;
        final myStatus = isUserA ? f.data['a_status'] : f.data['b_status'];
        final theirStatus = isUserA ? f.data['b_status'] : f.data['a_status'];
        
        if (myStatus == 'accepted' && theirStatus == 'accepted') {
          // Mutual - not pending
          continue;
        } 
        
        // Match FollowsScreen logic exactly for "Incoming":
        if (theirStatus == 'pending' || theirStatus == 'accepted') {
          count++;
        }
      }

      _pendingFollowsCount = count;
      notifyListeners();
    } catch (e) {
      print('Error fetching pending follows count: $e');
    }
  }

  /// Realtime subscription
  Future<void> _subscribeToRealtime(String userId) async {
    // Unsubscribe if existing to avoid duplicates
    if (_unsubscribeFunc != null) {
      await _unsubscribeFunc!();
    }

    try {
      print('🔌 [NotificationProvider] Subscribing to realtime for user: $userId');
      _unsubscribeFunc = await _service.subscribe(userId, (e) async {
        try {
          print('🔔 [NotificationProvider] RAW EVENT: ${e.action} - ${e.record}');
          if (e.action == 'create') {
            final newNotification = NotificationModel.fromRecord(e.record!);
            
            // Add to list always (History)
            _notifications.insert(0, newNotification);
            notifyListeners();

            // Check Settings for Local Push
            if (!_notifyAll) return;

            bool shouldShow = false;
            switch(newNotification.type) {
              case NotificationType.follow:
                shouldShow = _notifyFollows;
                break;
              case NotificationType.invite:
              case NotificationType.cancel:
              case NotificationType.approvalRequest:
                shouldShow = _notifyInvites;
                break;
              case NotificationType.visit:
                shouldShow = _notifyVisits;
                break;
              case NotificationType.reminder:
                shouldShow = _notifyReminders;
                break;
              case NotificationType.system:
                final isSalute = newNotification.title.contains('التحية') || 
                                 newNotification.message.contains('تحية') || 
                                 newNotification.message.contains('👋');
                if (isSalute) {
                  shouldShow = _notifySalutes;
                } else {
                  shouldShow = _notifySystem;
                }
                break;
              default:
                shouldShow = true;
            }

            if (shouldShow) {
              print('🔔 [NotificationProvider] Attempting to show local notification (ID: ${newNotification.id})...');
              
              // Load selected locale from SharedPreferences to translate local notification
              final prefs = await SharedPreferences.getInstance();
              final selectedLocale = prefs.getString('selected_locale') ?? 'ar';
              final localized = NotificationLocalizer.localize(
                newNotification.title,
                newNotification.message,
                selectedLocale,
              );

              _showLocalNotification(
                id: newNotification.id.hashCode,
                title: localized['title'] ?? newNotification.title,
                message: localized['message'] ?? newNotification.message,
                payload: jsonEncode(newNotification.toJson()),
              );

              // Show in-app banner overlay
              InAppNotificationBanner.show(
                newNotification,
                localizedTitle: localized['title'],
                localizedMessage: localized['message'],
              );
            }
          }
        } catch (err, stack) {
          print('‼️ [NotificationProvider] Error processing realtime event: $err');
          print(stack.toString());
        }
      });
    } catch (e) {
      print('‼️ [NotificationProvider] Error subscribing to notifications: $e');
    }
  }

  /// Mark single as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _service.markAsRead(notificationId);
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        _notifications[index] = _notifications[index].copyWith(isRead: true);
        notifyListeners();
      }
    } catch (e) {
      print('Error marking as read: $e');
    }
  }

  /// Mark ALL as read
  Future<void> markAllAsRead(String userId) async {
    try {
      await _service.markAllAsRead(userId);
      // Optimistic Update
      for (var i = 0; i < _notifications.length; i++) {
        if (!_notifications[i].isRead) {
          _notifications[i] = _notifications[i].copyWith(isRead: true);
        }
      }
      notifyListeners();
    } catch (e) {
      print('Error marking all as read: $e');
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
       await _service.deleteNotification(notificationId);
       _notifications.removeWhere((n) => n.id == notificationId);
       notifyListeners();
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  /// Show immediate local notification
  Future<void> _showLocalNotification({
    required int id,
    required String title,
    required String message,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'sijilli_channel_max_v3', // NEW ID to force refresh
      'Sijilli Critical Notifications',
      channelDescription: 'High priority notifications for invites and updates',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      category: AndroidNotificationCategory.message, // Treat as message
      ticker: 'New Notification from Sijilli',
      visibility: NotificationVisibility.public,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    
    try {
      await _localNotificationsPlugin.show(
        id: id,
        title: title,
        body: message,
        notificationDetails: platformChannelSpecifics,
        payload: payload,
      );
      print('✅ [NotificationProvider] Local notification shown successfully: $id');
    } catch (e) {
      print('‼️ [NotificationProvider] Failed to show local notification: $e');
    }
  }

  /// Schedule a local notification (e.g. for Appointments)
  Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    // Check master switch
    if (!_notifyAll) return;

    // If time is in past, don't schedule
    if (scheduledTime.isBefore(DateTime.now())) return;

    await _localNotificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(scheduledTime, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'sijilli_reminders',
          'Appointment Reminders',
          channelDescription: 'Reminders for upcoming appointments',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  /// Sync reminders for a list of appointments and bookmarked appointments
  Future<void> syncReminders(
    List<Appointment> appointments,
    List<Appointment> bookmarkedAppointments,
  ) async {
    if (!_notifyAll) {
       await _localNotificationsPlugin.cancelAll(); // Better to cancel all if master is off.
       return;
    }

    // 1. Process regular active appointments
    for (final appt in appointments) {
       // Skip cancelled or past (and cancel any scheduled notifications for them)
       if (appt.isCancelled || appt.isPast) {
         await cancelid(appt.id.hashCode);
         await cancelid('${appt.id}_1day'.hashCode);
         await cancelid('${appt.id}_offset'.hashCode);
         continue;
       }
       
       // A. Active Reminder (At start time)
       if (_notifyActive) {
          await scheduleReminder(
            id: appt.id.hashCode,
            title: 'تذكير موعد',
            body: 'حان موعد: ${appt.title}',
            scheduledTime: appt.startAt,
          );
       } else {
         await cancelid(appt.id.hashCode);
       }

       // B. One Day Prior Reminder
       if (_notifyOneDayBefore) {
          final oneDayPrior = appt.startAt.subtract(const Duration(days: 1));
          await scheduleReminder(
            id: '${appt.id}_1day'.hashCode,
            title: 'تذكير موعد غداً',
            body: 'غداً موعدك: ${appt.title}',
            scheduledTime: oneDayPrior,
          );
       } else {
         await cancelid('${appt.id}_1day'.hashCode);
       }

       // C. Custom Offset Reminder
       if (_notifyBeforeOffset) {
          final offsetTime = appt.startAt.subtract(Duration(minutes: _notifyBeforeOffsetMinutes));
          await scheduleReminder(
            id: '${appt.id}_offset'.hashCode,
            title: 'تذكير بقرب الموعد',
            body: 'يبدأ موعدك: ${appt.title} خلال $_notifyBeforeOffsetMinutes دقيقة',
            scheduledTime: offsetTime,
          );
       } else {
         await cancelid('${appt.id}_offset'.hashCode);
       }
    }

    // 2. Process bookmarked/saved appointments
    final activeIds = appointments.map((a) => a.id).toSet();
    for (final appt in bookmarkedAppointments) {
       // Cancel bookmark reminder if it is already in active appointments (to prevent duplicates)
       if (activeIds.contains(appt.id)) {
         await cancelid('saved_${appt.id}'.hashCode);
         await cancelid('saved_${appt.id}_1day'.hashCode);
         await cancelid('saved_${appt.id}_offset'.hashCode);
         continue;
       }

       // Skip cancelled or past (and cancel any scheduled notifications for them)
       if (appt.isCancelled || appt.isPast) {
         await cancelid('saved_${appt.id}'.hashCode);
         await cancelid('saved_${appt.id}_1day'.hashCode);
         await cancelid('saved_${appt.id}_offset'.hashCode);
         continue;
       }

       // If bookmarked notifications are enabled
       if (_notifyBookmarks) {
         // A. Active Reminder (At start time)
         if (_notifyActive) {
            await scheduleReminder(
              id: 'saved_${appt.id}'.hashCode,
              title: 'تذكير موعد محفوظ',
              body: 'حان موعد: ${appt.title}',
              scheduledTime: appt.startAt,
            );
         } else {
           await cancelid('saved_${appt.id}'.hashCode);
         }

         // B. One Day Prior Reminder
         if (_notifyOneDayBefore) {
            final oneDayPrior = appt.startAt.subtract(const Duration(days: 1));
            await scheduleReminder(
              id: 'saved_${appt.id}_1day'.hashCode,
              title: 'تذكير موعد محفوظ غداً',
              body: 'غداً موعدك: ${appt.title}',
              scheduledTime: oneDayPrior,
            );
         } else {
           await cancelid('saved_${appt.id}_1day'.hashCode);
         }

         // C. Custom Offset Reminder
         if (_notifyBeforeOffset) {
            final offsetTime = appt.startAt.subtract(Duration(minutes: _notifyBeforeOffsetMinutes));
            await scheduleReminder(
              id: 'saved_${appt.id}_offset'.hashCode,
              title: 'تذكير بقرب الموعد المحفوظ',
              body: 'يبدأ موعدك: ${appt.title} خلال $_notifyBeforeOffsetMinutes دقيقة',
              scheduledTime: offsetTime,
            );
         } else {
           await cancelid('saved_${appt.id}_offset'.hashCode);
         }
       } else {
         // Cancel all bookmarked reminders
         await cancelid('saved_${appt.id}'.hashCode);
         await cancelid('saved_${appt.id}_1day'.hashCode);
         await cancelid('saved_${appt.id}_offset'.hashCode);
       }
    }
  }
  
  /// Cancel specific notification
  Future<void> cancelid(int id) async {
    await _localNotificationsPlugin.cancel(id: id);
  }

  /// Cleanup on logout
  Future<void> clear() async {
    if (_unsubscribeFunc != null) {
      await _unsubscribeFunc!();
      _unsubscribeFunc = null;
    }
    if (_unsubscribeFriendshipFunc != null) {
      await _unsubscribeFriendshipFunc!();
      _unsubscribeFriendshipFunc = null;
    }
    _notifications = [];
    _pendingFollowsCount = 0;
    notifyListeners();
  }

  Future<void> _subscribeToFriendshipRealtime(String userId) async {
    if (_unsubscribeFriendshipFunc != null) {
      await _unsubscribeFriendshipFunc!();
    }
    try {
      final pb = PocketBaseClient.instance.pb;
      _unsubscribeFriendshipFunc = await pb.collection('friendship').subscribe('*', (e) {
         fetchPendingFollowsCount(userId);
      });
    } catch (e) {
      print('Error subscribing to friendship realtime: $e');
    }
  }

  void _showMissedNotifications() async {
    if (_hasCheckedMissed) return;
    _hasCheckedMissed = true;

    final unread = _notifications.where((n) => !n.isRead).toList();
    if (unread.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final selectedLocale = prefs.getString('selected_locale') ?? 'ar';

    // Take the 3 most recent unread, reverse so they show in sequential order (oldest to newest)
    final missed = unread.take(3).toList().reversed;
    for (final notif in missed) {
      final localized = NotificationLocalizer.localize(
        notif.title,
        notif.message,
        selectedLocale,
      );
      InAppNotificationBanner.show(
        notif,
        localizedTitle: localized['title'],
        localizedMessage: localized['message'],
      );
    }
  }

  @override
  void dispose() {
    if (_unsubscribeFunc != null) {
      _unsubscribeFunc!();
    }
    if (_unsubscribeFriendshipFunc != null) {
      _unsubscribeFriendshipFunc!();
    }
    super.dispose();
  }
}

class NotificationLocalizer {
  static Map<String, String> localize(String originalTitle, String originalMessage, String locale) {
    final titleLower = originalTitle.toLowerCase();
    final msgLower = originalMessage.toLowerCase();
    
    final words = originalMessage.trim().split(RegExp(r'\s+'));
    final namePart = words.isNotEmpty ? words.first : '';

    if (locale == 'ar') {
      String title = originalTitle;
      String message = originalMessage;

      if (titleLower.contains('appointment cancelled') || titleLower.contains('cancel')) {
        title = 'إلغاء موعد';
        message = msgLower.contains('organizer') ? 'تم إلغاء الموعد من قِبل المنظم' : 'تم إلغاء الموعد';
      } else if (titleLower.contains('new appointment invitation') || titleLower.contains('invite')) {
        title = 'دعوة موعد جديدة';
        message = 'وصلتك دعوة جديدة لحضور موعد';
      } else if (titleLower.contains('ping') || originalTitle.startsWith('PING')) {
        title = 'نكزة عاجلة ⚡';
        message = originalMessage;
      } else if (titleLower.contains('reminder') || titleLower.contains('appointment reminder')) {
        title = 'تذكير بالموعد';
        message = 'تذكير بموعدك القادم';
      } else if (titleLower.contains('confirmed') || titleLower.contains('appointment confirmed')) {
        title = 'تأكيد الموعد';
        message = 'تم تأكيد الموعد بنجاح';
      } else if (titleLower.contains('updated') || titleLower.contains('appointment updated')) {
        title = 'تحديث الموعد';
        message = 'تم تحديث تفاصيل الموعد';
      } else if (titleLower.contains('new accreditation') || titleLower.contains('new follow')) {
        title = 'اعتماد جديد';
        message = '$namePart قام باعتمادك';
      } else if (titleLower.contains('accreditation request') || titleLower.contains('follow request')) {
        title = 'طلب اعتماد';
        message = '$namePart يطلب اعتمادك';
      } else if (titleLower.contains('profile visit')) {
        title = 'زيارة جديدة للملف الشخصي';
        message = '$namePart قام بزيارة ملفك الشخصي';
      } else if (titleLower.contains('article visit')) {
        title = 'زيارة جديدة لمقالك';
        message = 'قام قارئ بتصفح مقالك';
      }

      return {
        'title': title,
        'message': message,
      };
    }

    String title = originalTitle;
    String message = originalMessage;

    // Follows & Accreditations
    if (originalTitle == 'اعتماد جديد' || titleLower.contains('new follow') || titleLower.contains('new accreditation')) {
      title = 'New Accreditation';
      message = '$namePart accredited you';
    } else if (originalTitle == 'طلب اعتماد' || titleLower.contains('follow request') || titleLower.contains('accredit request')) {
      title = 'Accreditation Request';
      message = '$namePart wants to accredit you';
    } else if (originalTitle == 'تراجع عن الاعتماد' || originalTitle == 'إلغاء الاعتماد' || titleLower.contains('unfollow') || titleLower.contains('unaccredit')) {
      title = 'Accreditation Removed';
      message = '$namePart removed their accreditation of you';
    } else if (originalTitle == 'اعتماد متبادل' || titleLower.contains('mutual')) {
      title = 'Mutual Accreditation';
      final mutualRegex = RegExp(r'(.+?)\s+قام\s+باعتمادك');
      final match = mutualRegex.firstMatch(originalMessage);
      if (match != null) {
        message = '${match.group(1)!.trim()} mutually accredited you';
      } else {
        message = '$namePart mutually accredited you';
      }
    }
    // Visits (including توافد الجمهور)
    else if (originalTitle == 'زيارة جديدة للملف الشخصي' || 
             originalTitle == 'زيارة ملف شخصي' || 
             originalTitle == 'زيارة جديدة' || 
             originalTitle == 'توافد الجمهور' || 
             titleLower.contains('profile visit') || 
             titleLower.contains('audience visit')) {
      
      final readRegex = RegExp(r'قام\s+(.+?)\s+بقراءة\s+مقالك');
      final browseRegex = RegExp(r'قام\s+(.+?)\s+بتصفح\s+ملفك');

      final readMatch = readRegex.firstMatch(originalMessage);
      final browseMatch = browseRegex.firstMatch(originalMessage);

      if (readMatch != null) {
        title = 'New Article Visit';
        message = '${readMatch.group(1)!.trim()} read your article';
      } else if (browseMatch != null) {
        title = 'New Profile Visit';
        message = '${browseMatch.group(1)!.trim()} visited your profile';
      } else {
        title = 'New Profile Visit';
        if (namePart == 'شخص' || namePart == 'قام' || namePart == 'أحد' || namePart == 'Someone' || namePart == 'A') {
          message = 'A member visited your profile';
        } else {
          message = '$namePart visited your profile';
        }
      }
    } else if (originalTitle == 'زيارة جديدة لمقالك' || titleLower.contains('article visit')) {
      title = 'New Article Visit';
      message = 'A reader visited and read your article';
    }
    // Likes & Comments
    else if (originalTitle == 'إعجابات' || titleLower.contains('like') || msgLower.contains('إعجاب') || msgLower.contains('أعجب')) {
      title = 'Likes';
      message = '$namePart liked your article';
    } else if (originalTitle == 'تعليقات' || titleLower.contains('comment') || msgLower.contains('علق') || msgLower.contains('تعليق')) {
      title = 'Comments';
      message = '$namePart commented on your article';
    }
    // Invites
    else if (originalTitle == 'دعوة جديدة' || originalTitle == 'دعوة موعد' || titleLower.contains('invite') || titleLower.contains('invitation')) {
      title = 'New Appointment Invitation';
      if (namePart.isNotEmpty && namePart != 'لقد' && namePart != 'تم') {
        message = '$namePart invited you to an appointment';
      } else {
        message = 'You have received a new appointment invitation';
      }
    } else if (originalTitle == 'إلغاء موعد' || originalTitle == 'تم إلغاء الموعد' || titleLower.contains('cancel')) {
      title = 'Appointment Cancelled';
      if (namePart.isNotEmpty && namePart != 'لقد' && namePart != 'تم') {
        message = '$namePart cancelled the appointment';
      } else {
        message = 'An appointment was cancelled';
      }
    } else if (originalTitle == 'تأكيد موعد' || originalTitle == 'تم تأكيد الموعد' || titleLower.contains('confirm')) {
      title = 'Appointment Confirmed';
      message = 'The appointment has been confirmed';
    } else if (originalTitle == 'تذكير موعد' || titleLower.contains('reminder') || msgLower.contains('تذكير')) {
      title = 'Appointment Reminder';
      message = 'Upcoming appointment reminder';
    } else if (originalTitle == 'تحديث موعد' || originalTitle == 'تعديل موعد' || titleLower.contains('update')) {
      title = 'Appointment Updated';
      message = 'Appointment details have been updated';
    } else if (originalTitle == 'قبول دعوة' || titleLower.contains('accepted invitation')) {
      title = 'Invitation Accepted';
      message = '$namePart accepted your invitation';
    } else if (originalTitle == 'رفض دعوة' || titleLower.contains('declined invitation')) {
      title = 'Invitation Declined';
      message = '$namePart declined your invitation';
    } else if (originalTitle == 'إشعار نظام' || originalTitle == 'إشعار عام' || titleLower.contains('system notification')) {
      title = 'System Notification';
      message = originalMessage;
    }

    return {
      'title': title,
      'message': message,
    };
  }
}
