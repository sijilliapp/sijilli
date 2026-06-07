import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sijilli/features/appointments/providers/appointment_provider.dart';
import 'package:sijilli/features/appointments/widgets/appointment_card.dart';
import 'package:sijilli/features/articles/providers/article_provider.dart';
import 'package:sijilli/features/articles/widgets/article_card.dart';
import 'package:sijilli/core/constants/app_colors.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';

class ArchiveTrashScreen extends StatefulWidget {
  final int initialIndex;
  const ArchiveTrashScreen({super.key, this.initialIndex = 0});

  @override
  State<ArchiveTrashScreen> createState() => _ArchiveTrashScreenState();
}

class _ArchiveTrashScreenState extends State<ArchiveTrashScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2, 
      vsync: this,
      initialIndex: widget.initialIndex,
    );
    
    // Fetch data on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final apptProvider = context.read<AppointmentProvider>();
      apptProvider.fetchArchivedAppointments();
      apptProvider.fetchTrashedAppointments();
      
      final articleProvider = context.read<ArticleProvider>();
      articleProvider.fetchArchivedArticles();
      articleProvider.fetchTrashedArticles();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.trash),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: context.l10n.archive),
            Tab(text: context.l10n.trash),
          ],
        ),
      ),
      body: TabBarView(
        physics: const NeverScrollableScrollPhysics(),
        controller: _tabController,
        children: const [
          ArchiveTab(),
          TrashTab(),
        ],
      ),
    );
  }
}

class ArchiveTab extends StatefulWidget {
  const ArchiveTab({super.key});

  @override
  State<ArchiveTab> createState() => _ArchiveTabState();
}

class _ArchiveTabState extends State<ArchiveTab> {
  String _searchQuery = '';
  int _selectedSegment = 0; // 0 = Appointments, 1 = Articles

  Widget _buildSegmentedControl() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.grey[300],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSegmentButton(
              label: 'المواعيد',
              isSelected: _selectedSegment == 0,
              onTap: () => setState(() => _selectedSegment = 0),
            ),
          ),
          Expanded(
            child: _buildSegmentButton(
              label: 'المقالات',
              isSelected: _selectedSegment == 1,
              onTap: () => setState(() => _selectedSegment = 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? (isDark ? Colors.grey[800] : Colors.white) 
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isSelected
                ? (isDark ? Colors.white : AppColors.primary)
                : (isDark ? Colors.grey[400] : Colors.grey[700]),
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? Theme.of(context).scaffoldBackgroundColor : Colors.grey[200],
      child: Column(
        children: [
          _buildSegmentedControl(),
          // Search Header (Elegant)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: SearchBar(
              hintText: context.l10n.searchArchive,
              leading: const Icon(Icons.search),
              constraints: const BoxConstraints(minHeight: 45, maxHeight: 45),
              backgroundColor: WidgetStateProperty.all(
                isDark ? Theme.of(context).cardColor : Colors.white
              ),
              elevation: WidgetStateProperty.all(0),
              shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
            ),
          ),
          Expanded(
            child: _selectedSegment == 0 
                ? _buildAppointmentsList() 
                : _buildArticlesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentsList() {
    return Consumer<AppointmentProvider>(
      builder: (context, provider, child) {
        final appointments = provider.archivedAppointments;
        
        if (appointments.isEmpty && provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (appointments.isEmpty) {
           return Center(child: Text(context.l10n.noArchivedAppointments));
        }

        final filtered = _searchQuery.isEmpty 
            ? appointments 
            : appointments.where((a) {
                final text = '${a.title} ${a.description ?? ''} ${a.host?.name ?? ''} ${a.region ?? ''} ${a.building ?? ''} ${a.currentUserInvitation?.personalNote ?? ''}'.toLowerCase();
                return text.contains(_searchQuery.toLowerCase());
              }).toList();

        return filtered.isEmpty 
            ? Center(child: Text(context.l10n.noResultsFound))
            : ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final appt = filtered[index];
                  return AppointmentCard(
                    appointment: appt,
                  );
                },
              );
      },
    );
  }

  Widget _buildArticlesList() {
    return Consumer<ArticleProvider>(
      builder: (context, provider, child) {
        final articles = provider.archivedArticles;
        
        if (articles.isEmpty && provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (articles.isEmpty) {
           return const Center(child: Text('لا توجد مقالات مؤرشفة'));
        }

        final filtered = _searchQuery.isEmpty 
            ? articles 
            : articles.where((art) {
                final text = '${art.title} ${art.plainText}'.toLowerCase();
                return text.contains(_searchQuery.toLowerCase());
              }).toList();

        return filtered.isEmpty 
            ? Center(child: Text(context.l10n.noResultsFound))
            : ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final article = filtered[index];
                  return ArticleCard(
                    article: article,
                    onTap: () {}, // Handled by inner longPress/onTap as needed
                  );
                },
              );
      },
    );
  }
}

class TrashTab extends StatefulWidget {
  const TrashTab({super.key});

  @override
  State<TrashTab> createState() => _TrashTabState();
}

class _TrashTabState extends State<TrashTab> {
  int _selectedSegment = 0; // 0 = Appointments, 1 = Articles

  Widget _buildSegmentedControl() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.grey[300],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSegmentButton(
              label: 'المواعيد',
              isSelected: _selectedSegment == 0,
              onTap: () => setState(() => _selectedSegment = 0),
            ),
          ),
          Expanded(
            child: _buildSegmentButton(
              label: 'المقالات',
              isSelected: _selectedSegment == 1,
              onTap: () => setState(() => _selectedSegment = 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? (isDark ? Colors.grey[800] : Colors.white) 
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isSelected
                ? (isDark ? Colors.white : AppColors.primary)
                : (isDark ? Colors.grey[400] : Colors.grey[700]),
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? AppColors.error.withValues(alpha: 0.1) : Colors.red[50], // Dynamic Red Tint
      child: Column(
        children: [
          _buildSegmentedControl(),
          Expanded(
            child: _selectedSegment == 0 
                ? _buildAppointmentsList() 
                : _buildArticlesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentsList() {
    return Consumer<AppointmentProvider>(
      builder: (context, provider, child) {
        final appointments = provider.trashedAppointments;
        
        if (appointments.isEmpty && provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (appointments.isEmpty) {
           return Center(child: Text(context.l10n.trashEmpty));
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: appointments.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final appt = appointments[index];
            return AppointmentCard(
              appointment: appt,
            );
          },
        );
      },
    );
  }

  Widget _buildArticlesList() {
    return Consumer<ArticleProvider>(
      builder: (context, provider, child) {
        final articles = provider.trashedArticles;
        
        if (articles.isEmpty && provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (articles.isEmpty) {
           return const Center(child: Text('سلة محذوفات المقالات فارغة'));
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: articles.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final article = articles[index];
            return ArticleCard(
              article: article,
              onTap: () {}, // Handled by inner longPress/onTap
            );
          },
        );
      },
    );
  }
}
