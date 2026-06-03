// 📍 lib/core/widgets/auth_wrapper.dart
// 🔄 توجيه ذكي حسب حالة المصادقة

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/main/screens/main_screen.dart';
import '../constants/app_colors.dart';
import '../utils/web_utils.dart';

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
    
    // إزالة شاشة التحميل للويب فور اكتمال التوجيه والجاهزية
    removeWebLoader();
    
    if (authProvider.isAuthenticated) {
      return const MainScreen(key: ValueKey('main'));
    }

    // unauthenticated أو error — كلاهما يعرض شاشة الدخول
    return const LoginScreen(key: ValueKey('login'));
  }
}

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // الشعار
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.calendar_today,
                size: 60,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 32),
            
            // اسم التطبيق
            const Text(
              'سجلي',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            
            // الوصف
            const Text(
              'تنظيم المواعيد وإدارة الدعوات',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 48),
            
            // مؤشر التحميل
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              strokeWidth: 3,
            ),
            const SizedBox(height: 16),
            
            // نص التحميل
            const Text(
              'جاري التحميل...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}