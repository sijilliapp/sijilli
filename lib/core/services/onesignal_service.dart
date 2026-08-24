// 📍 lib/core/services/onesignal_service.dart
// 🔔 OneSignal Push Notification Integration for iOS (APNs) and Android

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OneSignalService {
  static final OneSignalService instance = OneSignalService._internal();
  OneSignalService._internal();

  /// معرف تطبيق OneSignal الخاص بك (يمكنك استبداله بالـ App ID الخاص بحسابك في OneSignal)
  static const String defaultAppId = 'c6b787e8-372e-413a-b64a-31704ff17821';
  static String _currentAppId = defaultAppId;

  bool _isInitialized = false;

  /// تهيئة OneSignal عند بداية تشغيل التطبيق
  Future<void> initialize({String? appId}) async {
    if (_isInitialized) return;
    
    final targetId = appId ?? _currentAppId;
    if (targetId.isEmpty || targetId == 'YOUR_ONESIGNAL_APP_ID') {
      debugPrint('⚠️ [OneSignalService] Please configure your OneSignal App ID in OneSignalService.defaultAppId');
    }

    _currentAppId = targetId;

    try {
      if (kDebugMode) {
        OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
      }

      // 1. تهيئة حزمة OneSignal
      OneSignal.initialize(_currentAppId);

      // 2. طلب صلاحية الإشعارات من المستخدم (خاصة لنظام iOS / APNs)
      await OneSignal.Notifications.requestPermission(true);

      // 3. مستمع الإشعارات في الواجهة الأمامية وعند النقر
      OneSignal.Notifications.addClickListener((event) {
        debugPrint('🔔 [OneSignalService] Notification clicked: ${event.notification.title}');
      });

      OneSignal.Notifications.addForegroundWillDisplayListener((event) async {
        debugPrint('🔔 [OneSignalService] Foreground notification received: ${event.notification.title}');
        
        try {
          final title = event.notification.title ?? '';
          final body = event.notification.body ?? '';
          
          final prefs = await SharedPreferences.getInstance();
          final notifyAll = prefs.getBool('notify_all') ?? true;
          final notifySalutes = prefs.getBool('notify_salutes') ?? true;
          final notifyFollows = prefs.getBool('notify_follows') ?? true;
          final notifyInvites = prefs.getBool('notify_invites') ?? true;
          final notifyVisits = prefs.getBool('notify_visits') ?? true;

          bool shouldShow = true;

          if (!notifyAll) {
            shouldShow = false;
          } else {
            final isSalute = title.contains('التحية') || body.contains('تحية') || body.contains('👋');
            final isFollow = title.contains('اعتماد') || title.contains('متابعة');
            final isInvite = title.contains('دعوة');
            final isVisit = title.contains('زيارة') || title.contains('تصفح') || title.contains('قرأ');

            if (isSalute) {
              shouldShow = notifySalutes;
            } else if (isFollow) {
              shouldShow = notifyFollows;
            } else if (isInvite) {
              shouldShow = notifyInvites;
            } else if (isVisit) {
              shouldShow = notifyVisits;
            }
          }

          if (!shouldShow) {
            debugPrint('🔇 [OneSignalService] Muting foreground notification: $title');
            event.preventDefault(); // كتم الصوت ومنع العرض
            return;
          }
        } catch (e) {
          debugPrint('⚠️ [OneSignalService] Error filtering foreground push: $e');
        }

        event.notification.display();
      });

      _isInitialized = true;
      debugPrint('✅ [OneSignalService] Initialized successfully with App ID: $_currentAppId');
    } catch (e) {
      debugPrint('❌ [OneSignalService] Failed to initialize OneSignal: $e');
    }
  }

  /// ربط معرف المستخدم الحالي في السيرفر (PocketBase User ID) بـ OneSignal
  Future<void> loginUser(String userId) async {
    try {
      await OneSignal.login(userId);
      debugPrint('👤 [OneSignalService] Logged in user: $userId to OneSignal');
    } catch (e) {
      debugPrint('⚠️ [OneSignalService] Failed to login user: $e');
    }
  }

  /// إزالة تسطير المستخدم عند تسجيل الخروج
  Future<void> logoutUser() async {
    try {
      await OneSignal.logout();
      debugPrint('🔌 [OneSignalService] Logged out user from OneSignal');
    } catch (e) {
      debugPrint('⚠️ [OneSignalService] Failed to logout user: $e');
    }
  }

  /// إرسال إشعار خارجي حي (Push Notification) لمستخدم محدد عبر OneSignal REST API
  Future<bool> sendPushNotification({
    required String targetUserId,
    required String title,
    required String message,
    Map<String, dynamic>? data,
    String? restApiKey,
  }) async {
    if (_currentAppId.isEmpty || _currentAppId == 'YOUR_ONESIGNAL_APP_ID') {
      debugPrint('⚠️ [OneSignalService] Skipping Push notification: OneSignal App ID not set.');
      return false;
    }

    final apiKey = restApiKey ?? '';
    if (apiKey.isEmpty) {
      debugPrint('ℹ️ [OneSignalService] Push notification request pre-configured for App ID: $_currentAppId');
    }

    try {
      final url = Uri.parse('https://onesignal.com/api/v1/notifications');
      final headers = {
        'Content-Type': 'application/json; charset=utf-8',
        if (apiKey.isNotEmpty) 'Authorization': 'Basic $apiKey',
      };

      final body = {
        'app_id': _currentAppId,
        'include_aliases': {
          'external_id': [targetUserId]
        },
        'target_channel': 'push',
        'headings': {'en': title, 'ar': title},
        'contents': {'en': message, 'ar': message},
        'content_available': true,
        'mutable_content': true,
        'priority': 10,
        if (data != null) 'data': data,
      };

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        debugPrint('🚀 [OneSignalService] Push notification sent successfully to user $targetUserId');
        return true;
      } else {
        debugPrint('⚠️ [OneSignalService] Push notification failed (${response.statusCode}): ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ [OneSignalService] Error sending push notification: $e');
      return false;
    }
  }
}
