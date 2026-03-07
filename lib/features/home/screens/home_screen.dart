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

import '../../../l10n/app_localizations.dart';
import '../../../core/extensions/context_l10n.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Fetch appointments when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppointmentProvider>().fetchAppointments();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final double headerHeight = (user?.hasBio ?? false) ? 440 : 370;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: NestedScrollView(
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
                      : Colors.black.withOpacity(0.05),
                ),
              ),
            ),
          ];
        },
        body: Container(
          color: Theme.of(context).scaffoldBackgroundColor, // Body matches theme active tab
          child: TabBarView(
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
            MaterialPageRoute(builder: (context) => const ArchiveTrashScreen()),
          );
        } else if (value == 'contact') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ContactScreen()),
          );
        } else if (value == 'logout') {
          context.read<AuthProvider>().logout();
        }
      },
      itemBuilder: (BuildContext context) => [
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