// 📍 lib/core/widgets/auth_wrapper.dart
// 🔄 توجيه ذكي حسب حالة المصادقة

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/main/screens/main_screen.dart';
import '../utils/web_utils.dart';
import 'loaders/loading_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: _buildCurrentScreen(authProvider),
        );
      },
    );
  }

  Widget _buildCurrentScreen(AuthProvider authProvider) {
    if (authProvider.status == AuthStatus.initial || 
        authProvider.status == AuthStatus.loading) {
      return const LoadingScreen(key: ValueKey('loading'));
    }
    
    // إزالة شاشة التحميل للويب فور اكتمال التوجيه والجاهزية، مع استثناء الروابط العامة العميقة
    // ليتسنى لتلك الصفحات جلب بياناتها قبل إخفاء شاشة الشعار
    bool shouldRemoveWebLoader = true;
    if (kIsWeb) {
      final path = Uri.base.path;
      final cleanPath = path.split('?').first.replaceAll(RegExp(r'^/|/$'), '');
      if (cleanPath.isNotEmpty) {
        // قائمة المسارات المحجوزة
        final reserved = {'', 'main', 'login', 'register', 'settings', 'search', 'notifications'};
        final firstSegment = cleanPath.split('/').first;
        if (!reserved.contains(firstSegment)) {
          shouldRemoveWebLoader = false;
        }
      }
    }

    if (shouldRemoveWebLoader) {
      removeWebLoader();
    }
    
    if (authProvider.isAuthenticated) {
      return const MainScreen(key: ValueKey('main'));
    }

    // unauthenticated أو error — كلاهما يعرض شاشة الدخول
    return const LoginScreen(key: ValueKey('login'));
  }
}