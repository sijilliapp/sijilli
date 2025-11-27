import 'package:flutter/material.dart';
import '../screens/user_profile_screen.dart';
import '../screens/main_screen.dart';

/// معالج الروابط المباشرة (Deep Links)
/// 
/// يدعم الأنماط التالية:
/// - sijilli.com/username → فتح الملف الشخصي
/// - sijilli.com/ → الصفحة الرئيسية
class RouteHandler {
  /// معالجة الرابط وإرجاع الصفحة المناسبة
  static Widget? handleRoute(String path) {
    // إزالة / من البداية والنهاية
    final cleanPath = path.trim().replaceAll(RegExp(r'^/+|/+$'), '');
    
    print('🔗 معالجة الرابط: "$cleanPath"');
    
    // الصفحة الرئيسية
    if (cleanPath.isEmpty) {
      print('✅ توجيه إلى الصفحة الرئيسية');
      return const MainScreen();
    }
    
    // ملف شخصي: /username
    if (cleanPath.isNotEmpty && !cleanPath.contains('/')) {
      print('✅ توجيه إلى الملف الشخصي: $cleanPath');
      return UserProfileScreen.fromUsername(cleanPath);
    }
    
    // رابط غير معروف
    print('⚠️ رابط غير معروف: $cleanPath');
    return null;
  }
  
  /// استخراج المسار من URL كامل
  static String extractPath(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.path;
    } catch (e) {
      print('❌ خطأ في تحليل URL: $e');
      return '/';
    }
  }
}

