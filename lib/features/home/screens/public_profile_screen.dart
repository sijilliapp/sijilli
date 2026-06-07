import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sijilli/features/auth/providers/auth_provider.dart';
import 'package:sijilli/core/constants/app_colors.dart';
import 'package:sijilli/core/constants/app_dimens.dart';
import 'package:sijilli/models/appointment.dart';
import 'package:sijilli/features/home/widgets/profile_header.dart';
import 'package:sijilli/core/widgets/pulse_avatar.dart';
import 'package:sijilli/core/widgets/folder_tab_bar.dart';
import 'package:sijilli/features/home/widgets/profile_tabs/profile_appointments_tab.dart';
import 'package:sijilli/features/home/widgets/profile_tabs/profile_articles_tab.dart';
import 'package:sijilli/features/home/widgets/private_profile_wall.dart';
import 'package:sijilli/features/home/providers/public_profile_provider.dart';
import 'package:sijilli/features/profile/providers/moderation_provider.dart';
import 'package:sijilli/core/widgets/auth_wrapper.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';
import 'package:sijilli/core/utils/web_utils.dart';
import 'package:sijilli/core/widgets/loaders/loading_screen.dart';

class PublicProfileScreen extends StatefulWidget {
  final String usernameOrId;
  final int initialTabIndex;

  const PublicProfileScreen({
    super.key,
    required this.usernameOrId,
    this.initialTabIndex = 0,
  });

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2, 
      vsync: this, 
      initialIndex: widget.initialTabIndex,
    );
    _tabController.addListener(() {
      if (mounted) {
        setState(() {
          if (_tabController.index != 0 && _isSearching) {
            _isSearching = false;
            _searchController.clear();
            Provider.of<PublicProfileProvider>(context, listen: false).filterAppointments('');
          }
        });
      }
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      Provider.of<PublicProfileProvider>(context, listen: false).fetchData(
        widget.usernameOrId, 
        currentUserId: authProvider.user?.id
      );
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await Provider.of<PublicProfileProvider>(context, listen: false).fetchData(
      widget.usernameOrId, 
      currentUserId: authProvider.user?.id
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, PublicProfileProvider>(
      builder: (context, authProvider, profileProvider, _) {
        final user = profileProvider.user;
        final appointments = profileProvider.appointments;
        final isLoading = profileProvider.isLoading;
        final error = profileProvider.error;
        final isFollowing = profileProvider.isFollowing;
        
        if (!isLoading) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            removeWebLoader();
          });
        }
        
        final isMe = user != null && user.id == authProvider.user?.id;
        final canView = (user?.isPublic ?? false) || isFollowing || isMe;
    
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: isLoading
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: const BackButton(color: AppColors.primary),
            )
          : null,
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : error != null
              ? Scaffold(
                  appBar: AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    leading: const BackButton(color: AppColors.primary),
                  ),
                  body: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimens.spaceL),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_off_outlined, 
                            size: 80, 
                            color: isDark ? Colors.grey.shade700 : Colors.grey.shade200
                          ),
                          const SizedBox(height: AppDimens.spaceL),
                          Text(
                            error == 'BLOCK_RESTRICTED' 
                                ? 'هذا الحساب غير متاح حالياً' 
                                : error,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.grey.shade600, 
                              fontSize: 18,
                              fontWeight: FontWeight.w600
                            ),
                          ),
                          const SizedBox(height: AppDimens.space),
                          Text(
                            error == 'BLOCK_RESTRICTED'
                                ? 'لقد تم تقييد الوصول لهذا الملف الشخصي أو أن الحساب لم يعد متاحاً.'
                                : context.l10n.verifyUsernameOrNetwork,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade500, 
                              fontSize: 14
                            ),
                          ),
                          const SizedBox(height: AppDimens.spaceXL),
                          if (error != 'BLOCK_RESTRICTED')
                            ElevatedButton.icon(
                              onPressed: _handleRefresh,
                              icon: const Icon(Icons.refresh),
                              label: Text(context.l10n. retry),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimens.radiusRound)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final double screenWidth = constraints.maxWidth;
                    final bool isDesktop = screenWidth > 800;

                    Widget mainContent = NestedScrollView(
                      headerSliverBuilder: (context, innerBoxIsScrolled) {
                        return [
                          SliverAppBar(
                            pinned: true,
                            floating: false,
                            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                            surfaceTintColor: Theme.of(context).scaffoldBackgroundColor,
                            scrolledUnderElevation: 5.0,
                            shadowColor: Colors.black12,
                            leading: const BackButton(color: AppColors.primary),
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
                                    profileProvider.filterAppointments(value);
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
                                      profileProvider.filterAppointments('');
                                    });
                                  },
                                )
                              else ...[
                                if (_tabController.index == 0 && canView)
                                  IconButton(
                                    icon: const Icon(Icons.search, color: AppColors.primary),
                                    onPressed: () {
                                      setState(() {
                                        _isSearching = true;
                                      });
                                    },
                                  ),
                                if (user != null && user.id != Provider.of<AuthProvider>(context, listen: false).user?.id)
                                  Consumer<ModerationProvider>(
                                    builder: (context, moderation, _) {
                                      final isBlocked = moderation.isUserBlocked(user.id);
                                      final currentUser = Provider.of<AuthProvider>(context, listen: false).user;
                                      if (currentUser == null) {
                                        return IconButton(
                                          icon: const Icon(Icons.more_vert, color: AppColors.primary),
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(builder: (context) => const AuthWrapper()),
                                            );
                                          },
                                        );
                                      }
                                      return PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert, color: AppColors.primary),
                                        onSelected: (val) async {
                                          if (val == 'block') {
                                            if (isBlocked) {
                                              await moderation.unblockUser(user.id);
                                            } else {
                                              final confirm = await showDialog<bool>(
                                                context: context,
                                                builder: (context) => AlertDialog(
                                                  title: Text(context.l10n.blockUser),
                                                  content: Text(context.l10n.blockConfirmDesc),
                                                  actions: [
                                                    TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.l10n.cancel)),
                                                    TextButton(onPressed: () => Navigator.pop(context, true), child: Text(context.l10n.blockUser, style: const TextStyle(color: Colors.red))),
                                                  ],
                                                ),
                                              );
                                              if (confirm == true) {
                                                await moderation.blockUser(user);
                                                if (mounted) Navigator.pop(context);
                                              }
                                            }
                                          } else if (val == 'report') {
                                            final reason = await showDialog<String>(
                                              context: context,
                                              builder: (context) {
                                                final controller = TextEditingController();
                                                return AlertDialog(
                                                  title: Text(context.l10n.reportAccount),
                                                  content: TextField(
                                                    controller: controller,
                                                    decoration: InputDecoration(hintText: context.l10n.reportReason),
                                                    maxLines: 3,
                                                  ),
                                                  actions: [
                                                    TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.cancel)),
                                                    TextButton(onPressed: () => Navigator.pop(context, controller.text), child: Text(context.l10n.send)),
                                                  ],
                                                );
                                              },
                                            );
                                            if (reason != null && reason.isNotEmpty) {
                                              await moderation.reportContent(
                                                subjectType: 'user',
                                                subjectId: user.id,
                                                reason: reason,
                                              );
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.reportThanks)));
                                              }
                                            }
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          PopupMenuItem(
                                            value: 'block',
                                            child: Row(
                                              children: [
                                                Icon(isBlocked ? Icons.person_add : Icons.block, color: isBlocked ? Colors.green : Colors.red, size: 20),
                                                const SizedBox(width: 8),
                                                Text(isBlocked ? context.l10n.unblock : context.l10n.blockUser, style: TextStyle(color: isBlocked ? Colors.green : Colors.red)),
                                              ],
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: 'report',
                                            child: Row(
                                              children: [
                                                const Icon(Icons.report_problem_outlined, size: 20),
                                                const SizedBox(width: 8),
                                                Text(context.l10n.reportAccount),
                                              ],
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                              ],
                            ],
                          ),
                          if (!_isSearching)
                            SliverToBoxAdapter(
                              child: ProfileHeader(
                                user: user,
                                isPublicView: true,
                                streamLink: appointments.firstWhere(
                                  (a) => a.isNow && a.streamLink != null && a.streamLink!.isNotEmpty,
                                  orElse: () => Appointment(id: '', title: '', hostId: '', startAt: DateTime.now(), date: DateTime.now(), time: '', createdAt: DateTime.now(), updatedAt: DateTime.now()),
                                ).streamLink,
                                customStatus: appointments.any((a) => a.isNow && !a.isCancelled && !a.isUserDeleted) 
                                    ? AvatarStatus.active 
                                    : (appointments.any((a) => a.currentUserInvitation?.postStatus == PostStatus.published && a.isUpcoming && !a.isCancelled && !a.isUserDeleted) 
                                        ? AvatarStatus.upcoming 
                                        : AvatarStatus.none),
                              ),
                            ),
                          
                          SliverPersistentHeader(
                            pinned: true,
                            delegate: SliverFolderHeaderDelegate(
                              child: FolderTabBar(
                                tabController: _tabController,
                                tabTitles: [context.l10n.appointments, context.l10n.articles],
                                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                              ),
                            ),
                          ),
                        ];
                      },
                      body: Container(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        child: TabBarView(
                          physics: const NeverScrollableScrollPhysics(),
                          controller: _tabController,
                          children: [
                            canView 
                              ? ProfileAppointmentsTab(
                                  appointments: appointments,
                                  user: user,
                                  onRefresh: _handleRefresh,
                                )
                              : const ProfileEmptyState(),
                            canView ? ProfileArticlesTab(
                                    userId: user?.id ?? '',
                                    isCurrentUser: isMe,
                                  ) : const ProfileEmptyState(),
                          ],
                        ),
                      ),
                    );

                    if (isDesktop) {
                      return Container(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 800),
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 24.0),
                              decoration: BoxDecoration(
                                color: AppColors.getCardBackground(context),
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 24,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                                border: Border.all(
                                  color: AppColors.getBorder(context).withOpacity(0.5),
                                  width: 1,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: mainContent,
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    return mainContent;
                  },
                ),
      );
    },
  );
}
}
