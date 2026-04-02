import 'package:flutter/material.dart';
import '../features/home/screens/public_profile_screen.dart';

class AppRouter {
  static const String root = '/';
  static const String main = '/main';
  
  // قائمة المسارات المحجوزة التي لا يجب اعتبارها أسماء مستخدمين
  static const List<String> reservedRoutes = [
    root,
    main,
    '/login',
    '/register',
    '/settings',
    '/search',
    '/notifications',
  ];

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final name = settings.name;
    if (name == null || name.isEmpty) return null;

    // 1. معالجة المسارات المحجوزة (إذا لم تكن في جدول routes الرئيسي)
    if (reservedRoutes.contains(name)) {
      return null; // سيستخدم MaterialApp جدول الـ routes العادي
    }

    // 2. معالجة المسار القديم /profile/username (للتوافق)
    if (name.startsWith('/profile/')) {
      final usernameOrId = name.replaceFirst('/profile/', '');
      return MaterialPageRoute(
        settings: settings,
        builder: (context) => PublicProfileScreen(usernameOrId: usernameOrId),
      );
    }

    // 3. Catch-all: أي مسار آخر يعتبر اسم مستخدم (مثل /hussain)
    // نتأكد أنه يبدأ بـ / ولا يحتوي على مسارات فرعية معقدة حالياً
    if (name.startsWith('/') && name.length > 1) {
      final usernameOrId = name.substring(1);
      
      // إذا كان يحتوي على / إضافية، قد يكون مسار فرعي غير مدعوم حالياً
      if (usernameOrId.contains('/')) return null;

      return MaterialPageRoute(
        settings: settings,
        builder: (context) => PublicProfileScreen(usernameOrId: usernameOrId),
      );
    }

    return null;
  }
}