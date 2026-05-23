import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../models/notification.dart';
import '../../../../models/appointment.dart';
import '../services/notification_service.dart';
import '../../appointments/services/pb_appointment_service.dart';
import '../../../core/services/pocketbase_client.dart';

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

  // Settings State
  bool _notifyAll = true;
  bool _notifyFollows = true;
  bool _notifyInvites = true;
  bool _notifyActive = true;
  bool _notifyOneDayBefore = true;

  bool get notifyAll => _notifyAll;
  bool get notifyFollows => _notifyFollows;
  bool get notifyInvites => _notifyInvites;
  bool get notifyActive => _notifyActive;
  bool get notifyOneDayBefore => _notifyOneDayBefore;
  
  // Counts
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  NotificationProvider();

  Future<void> _initLocalNotifications() async {
    tz.initializeTimeZones();

    // Use launcher_icon to match manifest
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');

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
    await _loadSettings();
    await _initLocalNotifications();
    await fetchNotifications(userId);
    await fetchPendingFollowsCount(userId);
    await _subscribeToRealtime(userId);
    await _subscribeToFriendshipRealtime(userId);
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _notifyAll = prefs.getBool(_keyNotifyAll) ?? true;
    _notifyFollows = prefs.getBool(_keyNotifyFollows) ?? true;
    _notifyInvites = prefs.getBool(_keyNotifyInvites) ?? true;
    _notifyActive = prefs.getBool(_keyNotifyActive) ?? true;
    _notifyOneDayBefore = prefs.getBool(_keyNotifyOneDayBefore) ?? false; // Default false for extra reminder? Or true? User asked for option.
    notifyListeners();
  }

  Future<void> setNotifyAll(bool value) async {
    _notifyAll = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotifyAll, value);
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
      _unsubscribeFunc = await _service.subscribe(userId, (e) {
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
              case NotificationType.reminder:
              case NotificationType.system:
                shouldShow = true; // Default match active/other?
                break;
              default:
                shouldShow = true;
            }

            if (shouldShow) {
              print('🔔 [NotificationProvider] Attempting to show local notification (ID: ${newNotification.id})...');
              _showLocalNotification(
                id: newNotification.id.hashCode,
                title: newNotification.title,
                message: newNotification.message,
                payload: newNotification.relatedId,
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

  /// Sync reminders for a list of appointments
  Future<void> syncReminders(List<Appointment> appointments) async {
    if (!_notifyAll) {
       await _localNotificationsPlugin.cancelAll(); // Or just don't schedule new? 
       // Better to cancel all if master is off.
       return;
    }

    for (final appt in appointments) {
       // Skip cancelled or past
       if (appt.isCancelled || appt.isPast) {
         continue;
       }
       
       // 1. Active Reminder (At start time)
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

       // 2. One Day Prior Reminder
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
