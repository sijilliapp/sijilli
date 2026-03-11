import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sijilli/core/constants/app_colors.dart';
import 'package:sijilli/core/constants/app_dimens.dart';
import 'package:sijilli/core/widgets/folder_tab_bar.dart';
import 'package:sijilli/features/search/providers/search_provider.dart';
import 'package:sijilli/features/profile/widgets/user_cards/user_card.dart';
import 'package:sijilli/features/appointments/widgets/cards/base_appointment_card.dart';
import 'package:sijilli/features/appointments/widgets/cards/policies/public_policy.dart';
import 'package:sijilli/features/profile/providers/moderation_provider.dart';
import 'package:sijilli/models/appointment.dart';
import 'package:sijilli/l10n/app_localizations.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final provider = context.read<SearchProvider>();
        provider.setTab(_tabController.index == 0 ? SearchTab.news : SearchTab.follows);
      }
    });
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      context.read<SearchProvider>().updateQuery(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<SearchProvider>();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(context.l10n.explore), 
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.primary.withOpacity(isDark ? 0.3 : 0.8),
                AppColors.primary.withOpacity(isDark ? 0.1 : 0.6),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(context, isDark, provider),
          
          if (!provider.isSearching) 
            FolderTabBar(
              tabController: _tabController,
              tabTitles: [context.l10n.news, context.l10n.follows],
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            ),

          Expanded(
            child: provider.isLoading 
              ? const Center(child: CircularProgressIndicator())
              : provider.isSearching 
                ? _buildSearchResults(provider)
                : _buildTabContent(provider),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, bool isDark, SearchProvider provider) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceM),
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.white,
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        textDirection: context.l10n.localeName == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        decoration: InputDecoration(
          hintText: context.l10n.searchHint,
          prefixIcon: const Icon(Icons.search, color: AppColors.primary),
          suffixIcon: provider.query.isNotEmpty 
            ? IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () {
                  _searchController.clear();
                  provider.updateQuery('');
                },
              )
            : null,
          filled: true,
          fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusL),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
    );
  }

  Widget _buildSearchResults(SearchProvider provider) {
    if (provider.userSearchResults.isEmpty) {
      return Center(child: Text(context.l10n.noResults));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppDimens.spaceS),
      itemCount: provider.userSearchResults.length,
      itemBuilder: (context, index) {
        final user = provider.userSearchResults[index];
        return UserCard(user: user, mode: UserCardMode.standard);
      },
    );
  }

  Widget _buildTabContent(SearchProvider provider) {
    final items = provider.selectedTab == SearchTab.news 
        ? provider.exploreAppointments 
        : provider.followedAppointments;

    if (items.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: provider.refresh,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final appointment = items[index];
          return BaseAppointmentCard(
            policy: PublicPolicy(appointment, context),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_note_outlined,
            size: 64,
            color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.noAppointmentsCurrently,
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }
}

