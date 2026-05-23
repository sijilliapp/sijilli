import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sijilli/features/auth/providers/auth_provider.dart';
import 'package:sijilli/features/appointments/providers/appointment_provider.dart';
import 'package:sijilli/features/notifications/providers/notification_provider.dart';
import 'package:sijilli/core/constants/app_colors.dart';
import 'package:sijilli/features/home/screens/home_screen.dart';
import 'package:sijilli/features/search/screens/search_screen.dart';
import 'package:sijilli/features/add/screens/add_event_screen.dart';
import 'package:sijilli/features/articles/screens/add_article_screen.dart';
import 'package:sijilli/features/notifications/screens/notifications_screen.dart';
import 'package:sijilli/features/settings/screens/settings_screen.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';
import 'package:sijilli/models/notification.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  final GlobalKey<HomeScreenState> _homeKey = GlobalKey<HomeScreenState>();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = context.read<AuthProvider>().user?.id;
      if (userId != null) {
        context.read<NotificationProvider>().init(userId);
        
        // Sync reminders initially
        final apptProvider = context.read<AppointmentProvider>();
        context.read<NotificationProvider>().syncReminders(apptProvider.appointments);
        
        // Listen for future updates
        apptProvider.addListener(() {
          if (mounted) {
             context.read<NotificationProvider>().syncReminders(apptProvider.appointments);
          }
        });
      }
    });
  }

  void setIndex(int index) {
    if (mounted) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  int _currentIndex = 0;

  late final List<Widget> _screens = [
    HomeScreen(key: _homeKey),
    const SearchScreen(),
    const AddEventScreen(), // هذا العنصر لا يستخدم فعلياً لأن زر الإضافة يفتح شاشات مختلفة
    const NotificationsScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer3<AuthProvider, NotificationProvider, AppointmentProvider>(
      builder: (context, authProvider, notifProvider, apptProvider, _) {
        final user = authProvider.user;
        
        // Privacy Lock logic: Show if account is not public OR hidden from search
        final isPrivate = user != null && (user.isPublic == false || user.hideFromSearch == true);
        
        // Smart Notification Badge: Only show if there are actionable invitations pending user response
        final showNotificationBadge = apptProvider.pendingInvitationsCount > 0;

        return Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          bottomNavigationBar: _buildBottomNavigationBar(
            showNotificationBadge: showNotificationBadge,
            showLock: isPrivate,
          ),
        );
      },
    );
  }

  Widget _buildBottomNavigationBar({required bool showNotificationBadge, required bool showLock}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBackground : Colors.white,
        border: isDark ? const Border(top: BorderSide(color: AppColors.darkBorder)) : null,
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == 2) {
            final homeState = _homeKey.currentState;
            final isInArticlesTab = homeState?.isInArticlesTab ?? false;
            
            if (_currentIndex == 0 && isInArticlesTab) {
              // إذا كان المستخدم في تبويب المقالات، نفتح شاشة إضافة مقال
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddArticleScreen()),
              );
              return;
            }
          }

          if (index == _currentIndex) {
            if (index == 0) {
              _homeKey.currentState?.scrollToMagneticTop(force: true);
            }
          } else {
            setState(() {
              _currentIndex = index;
            });
            
            if (index == 0) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _homeKey.currentState?.scrollToMagneticTop(force: false);
              });
            }
          }
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w400,
          fontSize: 12,
        ),
        items: [
          _buildBottomNavItem(
            icon: Icons.home_outlined,
            activeIcon: Icons.home,
            label: context.l10n.home,
          ),
          _buildBottomNavItem(
            icon: Icons.search_outlined,
            activeIcon: Icons.search,
            label: context.l10n.search,
          ),
          _buildBottomNavItem(
            icon: Icons.add_circle_outline,
            activeIcon: Icons.add_circle,
            label: context.l10n.add,
          ),
          _buildBottomNavItem(
            icon: Icons.notifications_outlined,
            activeIcon: Icons.notifications,
            label: context.l10n.notifications,
            showBadge: showNotificationBadge,
          ),
          _buildBottomNavItem(
            icon: Icons.settings_outlined,
            activeIcon: Icons.settings,
            label: context.l10n.settings,
            showLock: showLock,
          ),
        ],
      ),
    );
  }

  /// بناء عنصر الإضافة الديناميكي في BottomNavigationBar
  BottomNavigationBarItem _buildDynamicAddNavItem() {
    // استخدام GlobalKey للوصول إلى HomeScreenState
    final homeState = _homeKey.currentState;
    final isInArticlesTab = homeState?.isInArticlesTab ?? false;
    
    return BottomNavigationBarItem(
      icon: Icon(isInArticlesTab ? Icons.article_outlined : Icons.add_circle_outline),
      activeIcon: Icon(isInArticlesTab ? Icons.article : Icons.add_circle),
      label: context.l10n.add,
    );
  }

  /// معالجة الضغط على زر الإضافة في BottomNavigationBar
  void _handleAddButtonPress() {
    // استخدام GlobalKey للوصول إلى HomeScreenState
    final homeState = _homeKey.currentState;
    final isInArticlesTab = homeState?.isInArticlesTab ?? false;
    
    if (isInArticlesTab) {
      // إذا كان في تبويب المقالات، افتح شاشة إضافة مقال
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const AddArticleScreen(),
        ),
      );
    } else {
      // إذا كان في تبويب المواعيد، افتح شاشة إضافة موعد
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const AddEventScreen(),
        ),
      );
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  BottomNavigationBarItem _buildBottomNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    bool showBadge = false,
    bool showLock = false,
  }) {
    return BottomNavigationBarItem(
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon),
          if (showBadge)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
          if (showLock)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.amber.shade700,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: const Icon(
                  Icons.lock,
                  size: 8,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
      activeIcon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(activeIcon),
          if (showBadge)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
          if (showLock)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.amber.shade700,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: const Icon(
                  Icons.lock,
                  size: 8,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
      label: label,
    );
  }
}
