import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html;
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

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? _initialUsername;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _checkUrlForUsername();
    }
  }

  void _checkUrlForUsername() {
    try {
      final url = html.window.location.href;
      final uri = Uri.parse(url);
      print('🌐 URL الحالي: $url');
      print('📍 المسار: ${uri.path}');
      
      // التحقق من وجود username في المسار (مثل /hussain)
      if (uri.pathSegments.isNotEmpty) {
        final username = uri.pathSegments.first;
        if (username.isNotEmpty && username != 'index.html') {
          setState(() {
            _initialUsername = username;
          });
          print('👤 تم العثور على username في الرابط: $username');
        }
      }
    } catch (e) {
      print('❌ خطأ في قراءة URL: $e');
    }
  }

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
        appBarTheme: const AppBarTheme(
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
        ),
      ),
      home: SplashScreen(initialUsername: _initialUsername),
    );
  }
}
