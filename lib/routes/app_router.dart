import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/widgets/auth_wrapper.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/appointments/providers/appointment_provider.dart';
import '../features/home/screens/public_profile_screen.dart';
import '../features/articles/screens/public_article_screen.dart';
import '../features/articles/screens/article_details_screen.dart';
import '../features/articles/services/pb_article_service.dart';
import '../features/appointments/services/pb_appointment_service.dart';
import '../features/appointments/widgets/sheets/appointment_details_sheet.dart';
import '../features/notifications/providers/notification_provider.dart';
import '../models/notification.dart';

class AppRouter {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  
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

    // 0. معالجة روابط الدعوات (/join أو /invite)
    if (name.startsWith('/join') || name.startsWith('/invite')) {
      final uri = Uri.parse(name);
      final token = uri.queryParameters['token'];
      if (token != null && token.isNotEmpty) {
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => InviteLinkHandler(token: token),
        );
      }
    }

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
          final secondPart = parts[1];
          
          if (secondPart.toLowerCase() == 'articles' || secondPart.toLowerCase() == 'art') {
            return MaterialPageRoute(
              settings: settings,
              builder: (context) => PublicProfileScreen(
                usernameOrId: username,
                initialTabIndex: 1,
              ),
            );
          }
          
          final articleId = secondPart;
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

  /// معالجة نقر الإشعار وتوجيه المستخدم للمكان الصحيح
  static void handleNotificationTap(NotificationModel notification) async {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    
    // 1. تعليم الإشعار كمقروء
    try {
      Provider.of<NotificationProvider>(context, listen: false).markAsRead(notification.id);
    } catch (_) {}

    final relatedId = notification.relatedId;
    if (relatedId.isEmpty) return;

    // 2. توجيه المستخدم حسب نوع الإشعار
    if (notification.type == NotificationType.follow || notification.type == NotificationType.approvalRequest) {
      // التوجيه لملف الشخص الذي تابعني
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PublicProfileScreen(usernameOrId: relatedId),
        ),
      );
    } else if (notification.type == NotificationType.invite || 
               notification.type == NotificationType.cancel || 
               notification.type == NotificationType.reminder) {
      // جلب الموعد وفتح تفاصيله
      try {
        final apptService = PbAppointmentService();
        final appointment = await apptService.getAppointmentById(relatedId);
        if (context.mounted) {
          showModalBottomSheet(
            context: context,
            useRootNavigator: true,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => AppointmentDetailsSheet(appointment: appointment),
          );
        }
      } catch (e) {
        print('⚠️ Failed to open appointment details: $e');
      }
    } else if (notification.type == NotificationType.visit || notification.type == NotificationType.system) {
      // إذا كان معرف المقال بطول 15 حرفاً
      if (relatedId.length == 15) {
        try {
          final articleService = PbArticleService();
          final article = await articleService.getArticleById(relatedId);
          if (context.mounted) {
            final isComment = notification.title.contains('تعليق') || notification.message.contains('علق');
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ArticleDetailsScreen(
                  article: article,
                  openComments: isComment,
                ),
              ),
            );
          }
        } catch (e) {
          print('⚠️ Failed to open article details: $e');
        }
      } else {
        // إذا كان زيارة ملف شخصي (معرف طويل)، نفتح صفحة الملف الشخصي الخاصة بالمستخدم نفسه
        // لأن زيارة ملفه تمت من زائر مجهول، فنكتفي بتوجيهه لقائمة الإشعارات أو لملفه الشخصي.
        // بما أن المستخدم متواجد بالفعل، فليس هناك صفحة زائر لعرضها.
      }
    }
  }
}

class InviteLinkHandler extends StatefulWidget {
  final String token;
  const InviteLinkHandler({super.key, required this.token});

  @override
  State<InviteLinkHandler> createState() => _InviteLinkHandlerState();
}

class _InviteLinkHandlerState extends State<InviteLinkHandler> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleToken());
  }

  Future<void> _handleToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_invite_token', widget.token);

    if (mounted) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.isAuthenticated) {
        final apptProvider = Provider.of<AppointmentProvider>(context, listen: false);
        final success = await apptProvider.claimAppointmentByToken(widget.token);
        if (success && mounted) {
          auth.setJustClaimedInvitation(true);
          Navigator.pushReplacementNamed(context, '/main');
          return;
        }
      }
      setState(() {
        _initialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    return const AuthWrapper();
  }
}