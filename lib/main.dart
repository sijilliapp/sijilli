import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/splash_screen.dart';
import 'services/timezone_service.dart';
import 'services/sunset_service.dart';

void main() async {
  // تهيئة شريط الحالة قبل تشغيل التطبيق
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة الخدمات الأساسية
  await TimezoneService.initialize();
  await SunsetService.initialize();

  // إعداد شريط الحالة ليكون مرئياً
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'سجلي',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2196F3),
          primary: const Color(0xFF2196F3),
        ),
        useMaterial3: true,
        fontFamily: 'Arial',
        // إعدادات شريط الحالة للتطبيق
        appBarTheme: const AppBarTheme(
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
