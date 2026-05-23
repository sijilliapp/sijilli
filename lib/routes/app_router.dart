import 'package:flutter/material.dart';
import '../features/home/screens/public_profile_screen.dart';
import '../features/articles/screens/public_article_screen.dart';

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

    // 3. Catch-all: أي مسار آخر يعتبر إما اسم مستخدم أو مسار لمقال
    // تنظيف المسار من الاستعلامات والشرطات الزائدة
    final cleanPath = name.split('?').first.replaceAll(RegExp(r'^/|/$'), '');
    
    if (cleanPath.isNotEmpty && !reservedRoutes.contains('/$cleanPath')) {
      // إذا كان يحتوي على مسار فرعي (مثل hussain/articleId)
      if (cleanPath.contains('/')) {
        final parts = cleanPath.split('/');
        if (parts.length >= 2) {
          final username = parts[0];
          final articleId = parts[1];
          return MaterialPageRoute(
            settings: settings,
            builder: (context) => PublicArticleScreen(
              username: username,
              articleId: articleId,
            ),
          );
        }
      }

      // مسار اسم مستخدم فقط (مثل hussain)
      return MaterialPageRoute(
        settings: settings,
        builder: (context) => PublicProfileScreen(usernameOrId: cleanPath),
      );
    }

    return null;
  }
}