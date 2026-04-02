import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../auth/providers/auth_provider.dart';
import '../../appointments/providers/appointment_provider.dart';
import '../tabs/appointments_tab.dart';
import '../widgets/profile_header.dart';
import '../../../core/widgets/folder_tab_bar.dart';
import '../../settings/screens/contact_screen.dart';
import '../../appointments/screens/archive_trash_screen.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/extensions/context_l10n.dart';

import '../../search/providers/search_provider.dart';
import '../../../core/services/calendar_sync_service.dart';
import '../../../main.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin, RouteAware {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  final CalendarSyncService _calendarSyncService = CalendarSyncService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
         // Stop any current vertical scroll animation when switching tabs horizontally
         if (_scrollController.hasClients) {
           _scrollController.position.jumpTo(_scrollController.offset);
         }
         _snapToTabs(force: true);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppointmentProvider>().fetchAppointments();
      context.read<SearchProvider>().init();
      
      // Initial snap to tabs after short delay for layout
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _snapToTabs(force: true);
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void didPopNext() {
    // When returning to this screen from another screen (Navigator pop)
    // We only want to snap if the profile is currently showing/partially showing
    scrollToMagneticTop(force: false);
  }

  void _snapToTabs({bool force = false}) {
    if (!mounted || !_scrollController.hasClients) return;

    // Safety check: Don't snap if user is already scrolling or already animating
    if (!force && _scrollController.position.isScrollingNotifier.value) return;

    // Check if auto-scroll should be skipped
    final settings = context.read<SettingsProvider>();
    final appointments = context.read<AppointmentProvider>().appointments;
    
    if (!settings.isMagneticScrollEnabled || appointments.isEmpty) {
      return;
    }

    final hasBio = context.read<AuthProvider>().user?.hasBio ?? false;
    final double snapOffset = hasBio ? 310 : 280;

    // If offset is very close to snapOffset, skip to avoid jitter
    if ((_scrollController.offset - snapOffset).abs() < 1.0) return;

    if (force || (_scrollController.offset > 0 && _scrollController.offset < snapOffset)) {
      _scrollController.animateTo(
        snapOffset,
        duration: const Duration(milliseconds: 600),
        curve: Curves.fastOutSlowIn,
      ).catchError((_) {}); // Prevent crashes if unmounted mid-animation
    }
  }

  void scrollToMagneticTop({bool force = false}) {
    if (!mounted || !_scrollController.hasClients) return;

    // If already animating, stop current and start new (mostly for double tap)
    if (force && _scrollController.position.isScrollingNotifier.value) {
      _scrollController.position.jumpTo(_scrollController.offset);
    }

    final user = context.read<AuthProvider>().user;
    final double snapOffset = (user?.hasBio ?? false) ? 310 : 280;
    final currentOffset = _scrollController.offset;

    if (force) {
      _scrollController.animateTo(
        snapOffset,
        duration: const Duration(milliseconds: 600),
        curve: Curves.fastOutSlowIn,
      ).catchError((_) {});
    } else {
      if (currentOffset < snapOffset && !_scrollController.position.isScrollingNotifier.value) {
        _scrollController.animateTo(
          snapOffset,
          duration: const Duration(milliseconds: 600),
          curve: Curves.fastOutSlowIn,
        ).catchError((_) {});
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleBatchSync() async {
    final searchProvider = context.read<SearchProvider>();
    final appointments = searchProvider.exploreAppointments;

    if (appointments.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.batchSyncNoNew)),
        );
      }
      return;
    }

    // Show loading? Optional, but let's just run it.
    final result = await _calendarSyncService.syncAppointments(appointments);

    if (!mounted) return;

    if (result >= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 4),
          backgroundColor: Colors.green.shade600,
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Text(
                result > 0 
                  ? context.l10n.batchSyncSuccess(result)
                  : context.l10n.batchSyncNoNew,
              ),
            ],
          ),
        ),
      );
    } else if (result == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.errorOccurred)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AuthProvider>().user;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollEndNotification) {
            final settings = context.read<SettingsProvider>();
            final appointments = context.read<AppointmentProvider>().appointments;

            // Skip snap if disabled or no appointments
            if (!settings.isMagneticScrollEnabled || appointments.isEmpty) {
              return false;
            }

            final user = context.read<AuthProvider>().user;
            final double snapOffset = (user?.hasBio ?? false) ? 310 : 280;
            final offset = _scrollController.offset;

            // Magnetic snap if between 0 and snapOffset
            if (offset > 0 && offset < snapOffset) {
              if (offset > snapOffset / 2) {
                _snapToTabs();
              } else {
                _scrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOut,
                );
              }
            }
          }
          return false;
        },
        child: NestedScrollView(
          controller: _scrollController,
          headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            // 1. Collapsing Profile Header
            // 1. Pinned App Bar
            SliverAppBar(
              pinned: true,
              floating: false,
              backgroundColor: Theme.of(context).brightness == Brightness.dark 
                  ? Theme.of(context).scaffoldBackgroundColor 
                  : AppColors.lightSurface,
              surfaceTintColor: Theme.of(context).brightness == Brightness.dark 
                  ? Theme.of(context).scaffoldBackgroundColor 
                  : AppColors.lightSurface,
              scrolledUnderElevation: 5.0,
              shadowColor: Colors.black12,
              leading: _buildMenuButton(),
            ),

            // 2. Dynamic Profile Header
            SliverToBoxAdapter(
              child: Container(
                color: Theme.of(context).brightness == Brightness.dark 
                    ? Theme.of(context).scaffoldBackgroundColor 
                    : AppColors.lightSurface,
                child: const ProfileHeader(),
              ),
            ),

            // 2. Removed SliverToBoxAdapter (Integrated into FlexibleSpace)

            // 3. Persistent TabBar (Folder Style)
            SliverPersistentHeader(
              pinned: true,
              delegate: _FolderHeaderDelegate(
                FolderTabBar(
                  tabController: _tabController,
                  tabTitles: [context.l10n.appointments, context.l10n.articles],
                  backgroundColor: Theme.of(context).brightness == Brightness.dark 
                      ? AppColors.darkBackground 
                      : const Color(0xFFF3F4F6),
                  activeTabShadowColor: Theme.of(context).brightness == Brightness.dark 
                      ? Colors.transparent 
                      : Colors.black.withValues(alpha: 0.05),
                ),
              ),
            ),
          ];
        },
        body: Container(
          color: Theme.of(context).scaffoldBackgroundColor, // Body matches theme active tab
          child: TabBarView(
            physics: const NeverScrollableScrollPhysics(),
            controller: _tabController,
            children: [
              // Tab 1: Appointments
              const AppointmentsTab(),

              // Tab 2: Articles (Placeholder)
              _buildArticlesPlaceholder(),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildMenuButton() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.menu, color: AppColors.primary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimens.radiusM)),
      onSelected: (value) {
        if (value == 'archive') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ArchiveTrashScreen(initialIndex: 0)),
          );
        } else if (value == 'contact') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ContactScreen()),
          );
        } else if (value == 'sync') {
          _handleBatchSync();
        } else if (value == 'logout') {
          context.read<AuthProvider>().logout();
        }
      },
      itemBuilder: (BuildContext context) => [
        PopupMenuItem(
          value: 'sync',
          child: Row(
            children: [
              const Icon(Icons.calendar_month_outlined, size: 20, color: Colors.blue),
              const SizedBox(width: 8),
              Text(context.l10n.batchSyncTitle),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'archive',
          child: Row(
            children: [
              const Icon(Icons.archive_outlined, size: 20, color: Colors.grey),
              const SizedBox(width: 8),
              Text(context.l10n.archive),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'contact',
          child: Row(
            children: [
              const Icon(Icons.mail_outline, size: 20, color: Colors.grey),
              const SizedBox(width: 8),
              Text(context.l10n.contactTeam),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'logout',
          child: Row(
            children: [
              const Icon(Icons.logout, size: 20, color: Colors.red),
              const SizedBox(width: 8),
              Text(context.l10n.logout, style: const TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildArticlesPlaceholder() {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.article_outlined, size: 60, color: Colors.grey.shade300),
              const SizedBox(height: AppDimens.space),
              Text(
                context.l10n.noArticlesYet,
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// 📌 Delegate for Folder TabBar
class _FolderHeaderDelegate extends SliverPersistentHeaderDelegate {
  final FolderTabBar _tabBar;

  _FolderHeaderDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return _tabBar;
  }

  @override
  bool shouldRebuild(_FolderHeaderDelegate oldDelegate) {
    return true;
  }
}