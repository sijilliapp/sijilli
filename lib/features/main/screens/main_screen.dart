import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sijilli/features/auth/providers/auth_provider.dart';
import 'package:sijilli/features/appointments/providers/appointment_provider.dart';
import 'package:sijilli/features/notifications/providers/notification_provider.dart';
import 'package:sijilli/core/constants/app_colors.dart';
import 'package:sijilli/features/home/screens/home_screen.dart';
import 'package:sijilli/features/search/screens/search_screen.dart';
import 'package:sijilli/features/add/screens/add_event_screen.dart';
import 'package:sijilli/features/notifications/screens/notifications_screen.dart';
import 'package:sijilli/features/settings/screens/settings_screen.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';

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

  int _currentIndex = 0;

  late final List<Widget> _screens = [
    HomeScreen(key: _homeKey),
    const SearchScreen(),
    const AddEventScreen(),
    const NotificationsScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Consumer2<AppointmentProvider, NotificationProvider>(
      builder: (context, appointmentProvider, notificationProvider, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        // Combined badge check: pending invitations OR unread notifications
        final hasPending = appointmentProvider.pendingInvitationsCount > 0 || 
                           notificationProvider.unreadCount > 0;
        
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
              if (index == _currentIndex) {
                // Already on this tab: Handle special re-selection logic
                if (index == 0) {
                  // If on Home tab, scroll to Magnetic Top
                  _homeKey.currentState?.scrollToMagneticTop(force: true);
                }
              } else {
                // Switching tabs: State is preserved by IndexedStack
                setState(() {
                  _currentIndex = index;
                });
                
                // If switching back TO Home, check for magnetic snap
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
                showBadge: hasPending, // نقطة حمراء فقط عند وجود دعوات معلقة
              ),
              _buildBottomNavItem(
                icon: Icons.settings_outlined,
                activeIcon: Icons.settings,
                label: context.l10n.settings,
              ),
            ],
          ),
        );
      },
    );
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
  }) {
    return BottomNavigationBarItem(
      icon: Stack(
        children: [
          Icon(icon),
          if (showBadge)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
      activeIcon: Stack(
        children: [
          Icon(activeIcon),
          if (showBadge)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
      label: label,
    );
  }
}
