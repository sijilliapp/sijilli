import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timeago/timeago.dart' as timeago;
import 'core/services/pocketbase_client.dart';
import 'core/constants/app_colors.dart';
import 'core/constants/app_dimens.dart';
import 'core/widgets/auth_wrapper.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/appointments/providers/appointment_provider.dart';
import 'features/appointments/providers/category_provider.dart';
import 'features/profile/providers/user_status_provider.dart';
import 'features/profile/providers/moderation_provider.dart';
import 'features/home/screens/public_profile_screen.dart';
import 'features/notifications/providers/notification_provider.dart';
import 'features/search/providers/search_provider.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';
import 'package:sijilli/l10n/app_localizations.dart';
import 'features/home/providers/public_profile_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/providers/locale_provider.dart';
import 'l10n/app_localizations.dart';

void main() async { // Changed to async
  // معالجة الأخطاء الشاملة
  WidgetsFlutterBinding.ensureInitialized();
  
  tz.initializeTimeZones();
  
  // Initialize timeago locale
  timeago.setLocaleMessages('ar', timeago.ArMessages());
  
  // ضبط سمات النظام (شريط الحالة)
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark, // أيقونات داكنة (للمود الفاتح)
    statusBarBrightness: Brightness.light, // لـ iOS
  ));

  // Initialize Hive
  await Hive.initFlutter();
  
  // Initialize PocketBase
  PocketBaseClient.instance.initialize();
  
  // معالجة أخطاء Flutter
  FlutterError.onError = (FlutterErrorDetails details) {
    // Prevent infinite loops on Web if the error object is a JS Proxy that crashes dumpErrorToConsole
    try {
      FlutterError.presentError(details);
    } catch (e) {
      debugPrint('⚠️ Flutter Error (Safe Log): ${details.exception}');
      debugPrint('Stacktrace: ${details.stack}');
    }
  };
  
  // Initialize ThemeProvider (Pre-load settings to avoid flash)
  final themeProvider = ThemeProvider();
  await themeProvider.loadSettings();
  
  // Initialize LocaleProvider
  final localeProvider = LocaleProvider();
  
  // تشغيل التطبيق
  runApp(SijilliApp(
    themeProvider: themeProvider,
    localeProvider: localeProvider,
  ));
}

class SijilliApp extends StatelessWidget {
  final ThemeProvider themeProvider;
  final LocaleProvider localeProvider;
  
  const SijilliApp({
    super.key, 
    required this.themeProvider,
    required this.localeProvider,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // إدارة حالة المصادقة
        ChangeNotifierProvider(
          create: (context) => AuthProvider()..initialize(),
        ),
        // إدارة نظام الحظر والتبليغ
        ChangeNotifierProvider(
          create: (context) => ModerationProvider(),
        ),
        // إدارة حالة المواعيد - تعتمد على حالة المصادقة ونظام الحظر
        ChangeNotifierProxyProvider2<AuthProvider, ModerationProvider, AppointmentProvider>(
          create: (context) => AppointmentProvider(),
          update: (context, auth, moderation, appointment) {
            appointment?.update(auth.user?.id, (auth.user?.hijriAdjustment ?? 0).toInt(), moderation);
            return appointment ?? AppointmentProvider();
          },
        ),
        // إدارة التصنيفات
        ChangeNotifierProvider(
          create: (context) => CategoryProvider()..fetchCategories(),
        ),
        // إدارة حالات المستخدمين (Avatar Status)
        ChangeNotifierProvider(
          create: (context) => UserStatusProvider(),
        ),
        // إدارة الإشعارات
        ChangeNotifierProxyProvider<AuthProvider, NotificationProvider>(
          create: (context) => NotificationProvider(),
          update: (context, auth, notification) {
            notification?.updateAuth(auth.user?.id);
            return notification ?? NotificationProvider();
          },
        ),
        // إدارة حالة البحث
        ChangeNotifierProvider(
          create: (context) => SearchProvider()..init(),
        ),
        // إدارة بيانات الملفات الشخصية العامة
        ChangeNotifierProvider(
          create: (context) => PublicProfileProvider(),
        ),
        // إدارة الثيم والخطوط (تم تحميلها مسبقاً)
        ChangeNotifierProvider.value(
          value: themeProvider,
        ),
        // إدارة اللغة
        ChangeNotifierProvider.value(
          value: localeProvider,
        ),
      ],
      child: Consumer2<ThemeProvider, LocaleProvider>(
        builder: (context, themeProvider, localeProvider, child) {
          return MaterialApp(
            onGenerateTitle: (context) => context.l10n.appName,
            title: 'Sijilli',
            debugShowCheckedModeBanner: false,
            
            // 1. Theme Mode binding
            themeMode: themeProvider.materialThemeMode,

            // 2. Light Theme
            theme: ThemeData(
              brightness: Brightness.light,
              colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary, brightness: Brightness.light),
              useMaterial3: true,
              scaffoldBackgroundColor: AppColors.lightBackground,
              textTheme: themeProvider.getCustomTextTheme(ThemeData.light().textTheme),
              
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.padding,
                  vertical: AppDimens.padding,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radius),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radius),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radius),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radius),
                  borderSide: const BorderSide(color: AppColors.error),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radius),
                  borderSide: const BorderSide(color: AppColors.error, width: 2),
                ),
                labelStyle: TextStyle(color: Colors.grey.shade700),
                floatingLabelStyle: const TextStyle(color: AppColors.primary),
              ),
              visualDensity: VisualDensity.adaptivePlatformDensity,
            ),

            // 3. Dark Theme
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              colorScheme: ColorScheme.fromSeed(
                 seedColor: AppColors.primary, 
                 brightness: Brightness.dark,
                 surface: AppColors.darkCardBackground,
              ),
              useMaterial3: true,
              scaffoldBackgroundColor: AppColors.darkBackground,
              cardColor: AppColors.darkCardBackground,
              
              textTheme: themeProvider.getCustomTextTheme(ThemeData.dark().textTheme),
              
              appBarTheme: const AppBarTheme(
                backgroundColor: AppColors.darkBackground,
                foregroundColor: Colors.white,
                elevation: 0,
                systemOverlayStyle: SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: Brightness.light,
                  statusBarBrightness: Brightness.dark,
                ),
              ),
              
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: AppColors.darkSurface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.padding,
                  vertical: AppDimens.padding,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radius),
                  borderSide: const BorderSide(color: AppColors.darkBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radius),
                  borderSide: const BorderSide(color: AppColors.darkBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radius),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radius),
                  borderSide: const BorderSide(color: AppColors.error),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radius),
                  borderSide: const BorderSide(color: AppColors.error, width: 2),
                ),
                labelStyle: const TextStyle(color: AppColors.darkTextSecondary),
                hintStyle: const TextStyle(color: AppColors.darkTextHint),
                floatingLabelStyle: const TextStyle(color: AppColors.primary),
              ),
              visualDensity: VisualDensity.adaptivePlatformDensity,
            ),

            // 2. Localization Configuration
            locale: localeProvider.locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const AuthWrapper(),
            onGenerateRoute: (settings) {
              if (settings.name != null && settings.name!.startsWith('/profile/')) {
                final usernameOrId = settings.name!.replaceFirst('/profile/', '');
                return MaterialPageRoute(
                  builder: (context) => PublicProfileScreen(usernameOrId: usernameOrId),
                );
              }
              return null;
            },
            routes: {
              '/main': (context) => const AuthWrapper(),
            },
          );
        },
      ),
    );
  }
}