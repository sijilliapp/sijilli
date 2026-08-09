import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../auth/providers/auth_provider.dart';
import '../../appointments/providers/appointment_provider.dart';
import '../../articles/providers/article_provider.dart';
import '../../../models/extensions/appointment_logic.dart';
import '../tabs/appointments_tab.dart';
import '../widgets/profile_tabs/profile_articles_tab.dart';
import '../widgets/profile_header.dart';
import '../../../core/widgets/folder_tab_bar.dart';
import '../../settings/screens/contact_screen.dart';
import '../../appointments/screens/archive_trash_screen.dart';
import '../../appointments/screens/saved_appointments_screen.dart';
import 'package:flutter/services.dart';
import '../../game/widgets/nerve_game_sheet.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/global_config_provider.dart';
import '../../../core/extensions/context_l10n.dart';
import '../../../core/local/local_db_service.dart';

import '../../search/providers/search_provider.dart';
import '../../add/providers/add_event_provider.dart';
import '../../../core/services/calendar_sync_service.dart';
import '../../../core/utils/app_date_formatter.dart';
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
  bool _isSnapping = false;

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

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      context.read<AppointmentProvider>().fetchAppointments();
      context.read<SearchProvider>().init();
      
      // توجيه تلقائي ذكي للتبويب الأنسب عند فتح التطبيق بالاستعلام المباشر من قاعدة البيانات المحلية
      try {
        final appointments = await LocalDbService.instance.getAppointments();
        final userArticles = await LocalDbService.instance.getArticles();

        final hasActiveOrUpcoming = appointments.any((a) => 
          (a.isNow || a.isUpcoming) && !a.isCancelled && !a.isUserDeleted
        );
        
        final hasPublishedArticles = userArticles.any((a) => a.isPublished);

        if (mounted) {
          // إذا لم يكن لديه مواعيد نشطة أو قريبة، ولديه مقالات منشورة، نفتح المقالات كافتراضي
          if (!hasActiveOrUpcoming && hasPublishedArticles) {
            _tabController.index = 1;
          }
        }
      } catch (e) {
        print('⚠️ [HomeScreen] Failed to fetch cache for tab routing: $e');
      }
      
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
    // If we are returning because we just created an appointment, skip the magnetic snapping to avoid conflict
    final hasHighlight = context.read<AddEventProvider>().highlightedAppointmentId != null;
    if (hasHighlight) {
      return;
    }
    
    // When returning to this screen from another screen (Navigator pop)
    // We only want to snap if the profile is currently showing/partially showing
    scrollToMagneticTop(force: false);
  }

  void _snapToTabs({bool force = false}) {
    if (!mounted || !_scrollController.hasClients || _isSnapping) return;

    // Safety check: Don't snap if user is already scrolling or already animating
    if (!force && _scrollController.position.isScrollingNotifier.value) return;

    // Check if auto-scroll should be skipped
    final settings = context.read<SettingsProvider>();
    final appointments = context.read<AppointmentProvider>().appointments;
    
    if (!settings.isMagneticScrollEnabled || appointments.isEmpty || _isSearching || _isSnappingSuspended) {
      return;
    }

    final hasBio = context.read<AuthProvider>().user?.hasBio ?? false;
    final double snapOffset = hasBio ? 310 : 280;

    // If offset is very close to snapOffset, skip to avoid jitter
    if ((_scrollController.offset - snapOffset).abs() < 1.0) return;

    if (force || (_scrollController.offset > 1.0 && _scrollController.offset < snapOffset - 1.0)) {
      setState(() => _isSnapping = true);
      _scrollController.animateTo(
        snapOffset,
        duration: const Duration(milliseconds: 600),
        curve: Curves.fastOutSlowIn,
      ).then((_) {
        if (mounted) setState(() => _isSnapping = false);
      }).catchError((_) {
        if (mounted) setState(() => _isSnapping = false);
      });
    }
  }

  void scrollToMagneticTop({bool force = false}) {
    if (!mounted || !_scrollController.hasClients || _isSnapping) return;

    final settings = context.read<SettingsProvider>();
    final appointments = context.read<AppointmentProvider>().appointments;

    // Logic: If disabled (or no appts), "Magnetic Top" is actually the REAL top (0)
    final bool isEnabled = settings.isMagneticScrollEnabled && appointments.isNotEmpty && !_isSearching && !_isSnappingSuspended;

    // If already animating, stop current and start new (mostly for double tap)
    if (force && _scrollController.position.isScrollingNotifier.value) {
      _scrollController.position.jumpTo(_scrollController.offset);
    }

    final user = context.read<AuthProvider>().user;
    final double snapOffset = (user?.hasBio ?? false) ? 310 : 280;
    final targetOffset = isEnabled ? snapOffset : 0.0;
    final currentOffset = _scrollController.offset;

    if (force) {
      setState(() => _isSnapping = true);
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 600),
        curve: Curves.fastOutSlowIn,
      ).then((_) {
        if (mounted) setState(() => _isSnapping = false);
      }).catchError((_) {
        if (mounted) setState(() => _isSnapping = false);
      });
    } else {
      // Auto-snap only if enabled and within range
      if (isEnabled && currentOffset < snapOffset - 1.0 && !_scrollController.position.isScrollingNotifier.value) {
        setState(() => _isSnapping = true);
        _scrollController.animateTo(
          snapOffset,
          duration: const Duration(milliseconds: 600),
          curve: Curves.fastOutSlowIn,
        ).then((_) {
          if (mounted) setState(() => _isSnapping = false);
        }).catchError((_) {
          if (mounted) setState(() => _isSnapping = false);
        });
      }
    }
  }

  bool _isSearching = false;
  bool _isSnappingSuspended = false;
  
  void setSnappingSuspended(bool suspended) {
    if (mounted) {
      setState(() {
        _isSnappingSuspended = suspended;
      });
    }
  }

  Future<void> scrollToTabAndTarget(BuildContext cardContext) async {
    setSnappingSuspended(true);
    final user = context.read<AuthProvider>().user;
    final double snapOffset = (user?.hasBio ?? false) ? 310 : 280;
    
    try {
      if (_scrollController.hasClients) {
        await _scrollController.animateTo(
          snapOffset,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
        );
      }
      
      await Scrollable.ensureVisible(
        cardContext,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
      );
    } catch (e) {
      debugPrint('Scroll highlight error: $e');
    } finally {
      Future.delayed(const Duration(milliseconds: 500), () {
        setSnappingSuspended(false);
      });
    }
  }

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  /// خاصية للتحقق إذا كان المستخدم في تبويب المقالات
  bool get isInArticlesTab => _tabController.index == 1;

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _tabController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
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
    final auth = context.watch<AuthProvider>();
    final isSimulating = auth.isSimulating;
    final apptProvider = context.watch<AppointmentProvider>();
    final settings = context.watch<SettingsProvider>();
    final hasRegions = apptProvider.searchRegionKeywords.isNotEmpty;
    final hasMonths = apptProvider.searchMonthKeywords.isNotEmpty;

    double capsulesHeight = 0.0;
    if (hasRegions && hasMonths) {
      capsulesHeight = 90.0;
    } else if (hasRegions || hasMonths) {
      capsulesHeight = 45.0;
    }

    Widget bodyWidget = NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification) {
          final settings = context.read<SettingsProvider>();
          final appointments = context.read<AppointmentProvider>().appointments;

          // Skip snap if disabled, no appointments, currently snapping, searching, or snap suspended
          if (!settings.isMagneticScrollEnabled || appointments.isEmpty || _isSnapping || _isSearching || _isSnappingSuspended) {
            return false;
          }

          final user = auth.user;
          final double snapOffset = (user?.hasBio ?? false) ? 310 : 280;
          final offset = _scrollController.offset;

          // Magnetic snap if between 0 and snapOffset
          if (offset > 1.0 && offset < snapOffset - 1.0) {
            if (offset > snapOffset / 2) {
              _snapToTabs();
            } else {
              setState(() => _isSnapping = true);
              _scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut,
              ).then((_) {
                if (mounted) setState(() => _isSnapping = false);
              }).catchError((_) {
                if (mounted) setState(() => _isSnapping = false);
              });
            }
          }
        }
        return false;
      },
      child: NestedScrollView(
        controller: _scrollController,
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
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
              title: _isSearching 
                ? TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: context.l10n.search,
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                    ),
                    style: const TextStyle(fontSize: 16),
                    onChanged: (value) {
                      context.read<AppointmentProvider>().filterAppointments(value);
                    },
                  )
                : null,
              actions: [
                if (_isSearching)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () {
                      setState(() {
                        _isSearching = false;
                        _searchController.clear();
                        context.read<AppointmentProvider>().filterAppointments('');
                      });
                    },
                  ),
              ],
              bottom: _isSearching && capsulesHeight > 0
                  ? PreferredSize(
                      preferredSize: Size.fromHeight(capsulesHeight),
                      child: _buildSearchCapsules(),
                    )
                  : null,
            ),

            // 2. Dynamic Profile Header
            if (!_isSearching)
              SliverToBoxAdapter(
                child: Container(
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? Theme.of(context).scaffoldBackgroundColor 
                      : AppColors.lightSurface,
                  child: Column(
                    children: [
                      const ProfileHeader(),
                      if (context.watch<GlobalConfigProvider>().isNerveGameEnabled)
                        _buildNerveGameBanner(context),
                    ],
                  ),
                ),
              ),

            // 3. Persistent TabBar (Folder Style)
            SliverPersistentHeader(
              pinned: true,
              delegate: _FolderHeaderDelegate(
                Builder(
                  builder: (context) {
                    final appts = apptProvider.appointments.where((a) => a.isActiveUpcomingAccepted).toList();
                    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
                    final countStr = isArabic 
                        ? AppDateFormatter.toEasternArabicDigits(appts.length.toString()) 
                        : appts.length.toString();
                    final apptsTitle = appts.isEmpty 
                        ? context.l10n.appointments 
                        : '${context.l10n.appointments} $countStr';

                    return FolderTabBar(
                      tabController: _tabController,
                      tabTitles: [apptsTitle, context.l10n.articles],
                      backgroundColor: Theme.of(context).brightness == Brightness.dark 
                          ? AppColors.darkBackground 
                          : const Color(0xFFF3F4F6),
                      activeTabShadowColor: Theme.of(context).brightness == Brightness.dark 
                          ? Colors.transparent 
                          : Colors.black.withValues(alpha: 0.05),
                    );
                  }
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

              // Tab 2: Articles
              ProfileArticlesTab(
                userId: auth.user?.id ?? '',
                isCurrentUser: true,
              ),
            ],
          ),
        ),
      ),
    );

    if (isSimulating) {
      bodyWidget = Column(
        children: [
          Container(
            color: Colors.amber.shade900,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  const Icon(Icons.security_outlined, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'تصفح محاكى لحساب: ${auth.user?.name} (@${auth.user?.username})',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.amber.shade900,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      auth.stopSimulation();
                    },
                    child: const Text('خروج والعودة للمشرف', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: bodyWidget),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: bodyWidget,
    );
  }

  Widget _buildNerveGameBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.flash_on, color: Colors.amber, size: 36),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'تحدّي الأعصاب اليومي ⚡',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'اضغط 10 مرات متتالية بأسرع ما يمكن وسجل نتيجتك!',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              NerveGameSheet.show(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text(
              'ابدأ 🎮',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchCapsules() {
    return Consumer<AppointmentProvider>(
      builder: (context, provider, _) {
        final regions = provider.searchRegionKeywords;
        final months = provider.searchMonthKeywords;

        if (regions.isEmpty && months.isEmpty) return const SizedBox.shrink();

        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // السطر الأول: أسماء المناطق المتوفرة
            if (regions.isNotEmpty)
              Container(
                height: 45,
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: regions.length,
                  itemBuilder: (context, index) {
                    final keyword = regions[index];
                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: ActionChip(
                        label: Text(keyword, style: const TextStyle(fontSize: 12)),
                        backgroundColor: AppColors.primary.withValues(alpha: 0.05),
                        side: BorderSide(
                          color: isDark ? Colors.white.withValues(alpha: 0.3) : Colors.black,
                          width: 1.0,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        onPressed: () {
                          _searchController.text = keyword;
                          provider.filterAppointments(keyword);
                        },
                      ),
                    );
                  },
                ),
              ),
            // السطر الثاني: أسماء الأشهر
            if (months.isNotEmpty)
              Container(
                height: 45,
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: months.length,
                  itemBuilder: (context, index) {
                    final keyword = months[index];
                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: ActionChip(
                        label: Text(keyword, style: const TextStyle(fontSize: 12)),
                        backgroundColor: AppColors.primary.withValues(alpha: 0.05),
                        side: BorderSide(
                          color: isDark ? Colors.white.withValues(alpha: 0.3) : Colors.black,
                          width: 1.0,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        onPressed: () {
                          _searchController.text = keyword;
                          provider.filterAppointments(keyword);
                        },
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }



  Widget _buildMenuButton() {
    final settings = context.read<SettingsProvider>();
    final showLoc = settings.showLocationInfo;

    return PopupMenuButton<String>(
      icon: const Icon(Icons.menu, color: AppColors.primary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimens.radiusM)),
      onSelected: (value) {
        if (value == 'search') {
          setState(() {
            _isSearching = true;
          });
        } else if (value == 'archive') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ArchiveTrashScreen(initialIndex: 0)),
          );
        } else if (value == 'saved') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SavedAppointmentsScreen()),
          );
        } else if (value == 'location_toggle') {
          settings.setShowLocationInfo(!showLoc);
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
          value: 'search',
          child: Row(
            children: [
              const Icon(Icons.search, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(context.l10n.search),
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
          value: 'saved',
          child: Row(
            children: [
              const Icon(Icons.bookmarks_outlined, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(context.l10n.saved),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'location_toggle',
          child: Row(
            children: [
              Icon(
                showLoc ? Icons.location_off_outlined : Icons.location_on_outlined,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(showLoc ? context.l10n.hideLocation : context.l10n.showLocation),
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
        const PopupMenuDivider(),
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
  final Widget child;

  _FolderHeaderDelegate(this.child);

  @override
  double get minExtent => 52.0;
  @override
  double get maxExtent => 52.0;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(_FolderHeaderDelegate oldDelegate) {
    return true;
  }
}