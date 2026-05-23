// 📍 lib/features/auth/services/user_activity_service.dart

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/pocketbase_client.dart';

class UserActivityService with WidgetsBindingObserver {
  static final UserActivityService instance = UserActivityService._();
  
  UserActivityService._();

  static const String _lastUpdateKey = 'last_active_update_timestamp';
  static const int _throttleMinutes = 10;
  bool _isInitialized = false;

  void initialize() {
    if (_isInitialized) return;
    WidgetsBinding.instance.addObserver(this);
    _isInitialized = true;
    
    // تسجيل الحضور فور فتح التطبيق لأول مرة (إذا كان مسجلاً)
    updateActivity();
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _isInitialized = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      updateActivity();
    }
  }

  /// تحديث `lastActive` في السيرفر بذكاء لتجنب استنزاف الموارد
  Future<void> updateActivity() async {
    final client = PocketBaseClient.instance;
    final user = client.currentUser;
    
    if (user == null || user.isAnonymous) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final lastUpdateStr = prefs.getString(_lastUpdateKey);
      
      if (lastUpdateStr != null) {
        final lastUpdate = DateTime.parse(lastUpdateStr);
        final difference = DateTime.now().difference(lastUpdate);
        
        // إذا لم تمر المدة الكافية (10 دقائق)، لا ترسل طلباً للسيرفر
        if (difference.inMinutes < _throttleMinutes) {
          return;
        }
      }

      // إرسال التحديث للسيرفر
      final now = DateTime.now().toUtc(); // Use UTC for standardization
      await client.pb.collection('users').update(user.id, body: {
        'lastActive': now.toIso8601String(),
      });

      // حفظ وقت التحديث محلياً
      await prefs.setString(_lastUpdateKey, now.toIso8601String());
      print('✅ [UserActivityService] lastActive updated successfully.');
      
    } catch (e) {
      print('⚠️ [UserActivityService] Failed to update activity: $e');
    }
  }
}
