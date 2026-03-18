import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sijilli/features/appointments/providers/appointment_provider.dart';
import 'package:sijilli/features/appointments/widgets/appointment_card.dart';
import 'package:sijilli/core/constants/app_colors.dart';
import 'package:sijilli/models/appointment.dart';
import 'package:sijilli/l10n/app_localizations.dart';
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
      final provider = context.read<AppointmentProvider>();
      provider.fetchArchivedAppointments();
      provider.fetchTrashedAppointments();
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? Theme.of(context).scaffoldBackgroundColor : Colors.grey[200], // Dynamic
      child: Consumer<AppointmentProvider>(
        builder: (context, provider, child) {
          final appointments = provider.archivedAppointments;
          
          if (appointments.isEmpty && provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (appointments.isEmpty) {
             return Center(child: Text(context.l10n.noArchivedAppointments));
          }

          // Filter logic
          final filtered = _searchQuery.isEmpty 
              ? appointments 
              : appointments.where((a) {
                  final text = '${a.title} ${a.description ?? ''} ${a.host?.name ?? ''} ${a.region ?? ''} ${a.building ?? ''} ${a.currentUserInvitation?.personalNote ?? ''}'.toLowerCase();
                  return text.contains(_searchQuery.toLowerCase());
                }).toList();

          return Column(
            children: [
               // Search Header (Elegant)
               Padding(
                 padding: const EdgeInsets.all(12),
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
                 child: filtered.isEmpty 
                    ? Center(child: Text(context.l10n.noResultsFound))
                    : ListView.separated(
                   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                   itemCount: filtered.length,
                   separatorBuilder: (_, __) => const SizedBox(height: 8),
                   itemBuilder: (context, index) {
                     final appt = filtered[index];
                     return AppointmentCard(
                       appointment: appt,
                     );
                   },
                 ),
               ),
            ],
          );
        },
      ),
    );
  }
}

class TrashTab extends StatelessWidget {
  const TrashTab({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? AppColors.error.withOpacity(0.1) : Colors.red[50], // Dynamic Red Tint
      child: Consumer<AppointmentProvider>(
        builder: (context, provider, child) {
          final appointments = provider.trashedAppointments;
          
          if (appointments.isEmpty && provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (appointments.isEmpty) {
             return Center(child: Text(context.l10n.trashEmpty));
          }

          return ListView.separated(
             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
             itemCount: appointments.length,
             separatorBuilder: (_, __) => const SizedBox(height: 8),
             itemBuilder: (context, index) {
               final appt = appointments[index];
               return AppointmentCard(
                 appointment: appt,
                 // Trash items.
               );
             },
           );
        },
      ),
    );
  }
}
