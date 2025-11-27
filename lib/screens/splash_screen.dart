import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/auth_service.dart';
import '../widgets/app_logo.dart';
import '../utils/route_handler.dart';
import 'login_screen.dart';
import 'main_screen.dart';
import 'user_profile_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(seconds: 2));

    final isAuthenticated = await _authService.initAuth();

    if (!mounted) return;

    // 🔗 معالجة Deep Links (للويب فقط)
    if (kIsWeb) {
      final currentUrl = Uri.base.toString();
      final path = RouteHandler.extractPath(currentUrl);

      print('🌐 URL الحالي: $currentUrl');
      print('📍 المسار: $path');

      // إذا كان المسار ليس الصفحة الرئيسية
      if (path != '/' && path.isNotEmpty) {
        final targetScreen = RouteHandler.handleRoute(path);

        if (targetScreen != null) {
          // إذا كان المستخدم مسجل دخول، افتح الصفحة المطلوبة
          if (isAuthenticated) {
            Navigator.of(
              context,
            ).pushReplacement(MaterialPageRoute(builder: (_) => targetScreen));
            return;
          } else {
            // إذا لم يكن مسجل دخول، اذهب لصفحة تسجيل الدخول
            // TODO: حفظ الرابط المطلوب وفتحه بعد تسجيل الدخول
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
            return;
          }
        }
      }
    }

    // السلوك الافتراضي
    if (isAuthenticated) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const MainScreen()));
    } else {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppLogo(
                width: 150,
                height: 150,
                variant: LogoVariant.normal,
                useHighQuality: true,
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
