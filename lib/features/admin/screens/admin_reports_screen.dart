// 📍 lib/features/admin/screens/admin_reports_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../providers/admin_provider.dart';
import 'admin_user_edit_screen.dart';
import '../../../models/user.dart';
import '../../auth/providers/auth_provider.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/extensions/context_l10n.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AdminProvider>().fetchReports();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          context.l10n.reportsScreenTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Consumer<AdminProvider>(
          builder: (context, admin, child) {
            if (admin.isFetchingReports) {
              return const Center(child: CircularProgressIndicator());
            }

            if (admin.reports.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_outline,
                        size: 72,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.l10n.noReportsFound,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.allSafeAndClean,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () => admin.fetchReports(),
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: admin.reports.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final report = admin.reports[index];
                  return ReportCardWidget(
                    report: report,
                    isDark: isDark,
                    admin: admin,
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class ReportCardWidget extends StatefulWidget {
  final RecordModel report;
  final bool isDark;
  final AdminProvider admin;

  const ReportCardWidget({
    super.key,
    required this.report,
    required this.isDark,
    required this.admin,
  });

  @override
  State<ReportCardWidget> createState() => _ReportCardWidgetState();
}

class _ReportCardWidgetState extends State<ReportCardWidget> {
  Map<String, dynamic>? _details;
  bool _isLoading = true;
  bool _hasAttempted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasAttempted) {
      _hasAttempted = true;
      _loadDetails();
    }
  }

  Future<void> _loadDetails() async {
    final subjectType = widget.report.getStringValue('subject_type');
    final subjectId = widget.report.getStringValue('subject_id');
    final details = await widget.admin.fetchSubjectDetails(subjectType, subjectId);
    if (mounted) {
      setState(() {
        _details = details;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final isDark = widget.isDark;
    final admin = widget.admin;

    final reportId = report.id;
    final reporterList = report.get<List<RecordModel>>('expand.reporter');
    final reporter = (reporterList != null && reporterList.isNotEmpty) ? reporterList.first : null;
    final reporterName = reporter?.getStringValue('name') ?? reporter?.getStringValue('username') ?? context.l10n.anonymous;
    final subjectType = report.getStringValue('subject_type');
    final subjectId = report.getStringValue('subject_id');
    final reason = report.getStringValue('reason');
    final status = report.getStringValue('status');
    final isResolved = status.startsWith('resolved');
    final isIgnored = status.startsWith('ignored');
    final isPending = !isResolved && !isIgnored;

    String moderatorTag = '';
    if (status.contains(': ')) {
      moderatorTag = status.split(': ')[1];
    }
    final created = report.getStringValue('created');
    final createdDate = DateTime.tryParse(created) ?? DateTime.now();

    String typeLabel = '';
    IconData typeIcon = Icons.info_outline;
    Color typeColor = Colors.grey;

    switch (subjectType) {
      case 'user':
        typeLabel = context.l10n.reportTypeUser;
        typeIcon = Icons.person_outline;
        typeColor = Colors.orange;
        break;
      case 'appointment':
        typeLabel = context.l10n.reportTypeAppointment;
        typeIcon = Icons.calendar_today_outlined;
        typeColor = AppColors.primary;
        break;
      case 'article':
        typeLabel = context.l10n.reportTypeArticle;
        typeIcon = Icons.article_outlined;
        typeColor = Colors.blue;
        break;
    }

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          width: 1,
        ),
      ),
      color: isDark ? AppColors.darkSurface : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Type Badge & Date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: typeColor.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(typeIcon, color: typeColor, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        typeLabel,
                        style: TextStyle(color: typeColor, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Text(
                  timeago.format(createdDate, locale: Localizations.localeOf(context).languageCode),
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Reporter
            Row(
              children: [
                const Icon(Icons.campaign_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    context.l10n.reporterLabel(reporterName),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Reason
            Text(
              context.l10n.reportReasonLabel(reason),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.grey.shade300 : Colors.black87,
              ),
            ),
            const Divider(height: 24),

            // Subject Details Section
            if (_isLoading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 10),
                    Text(context.l10n.loadingReportedDetails, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              )
            else if (_details == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  context.l10n.reportedContentUnavailable,
                  style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w600),
                ),
              )
            else
              _buildSubjectPreview(context, subjectType, _details!, isDark),

            const SizedBox(height: 16),

            // Action Buttons
            if (isPending)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.block_outlined, size: 16, color: Colors.red),
                      label: Text(context.l10n.reportActionDelete, style: const TextStyle(color: Colors.red, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _confirmDeleteContent(context, admin, reportId, subjectType, subjectId),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.done_all, size: 16, color: Colors.white),
                      label: Text(context.l10n.reportActionIgnore, style: const TextStyle(color: Colors.white, fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        final currentUser = Provider.of<AuthProvider>(context, listen: false).user;
                        final moderatorTag = currentUser != null ? '@${currentUser.username}' : '@${context.l10n.anonymous}';
                        admin.updateReportStatus(reportId, 'ignored: $moderatorTag');
                      },
                    ),
                  ),
                ],
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isResolved ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isResolved 
                      ? context.l10n.reportStatusResolved(moderatorTag.isNotEmpty ? context.l10n.byModerator(moderatorTag) : '') 
                      : context.l10n.reportStatusIgnored(moderatorTag.isNotEmpty ? context.l10n.byModerator(moderatorTag) : ''),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isResolved ? Colors.green : Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectPreview(BuildContext context, String subjectType, Map<String, dynamic> details, bool isDark) {
    if (subjectType == 'user') {
      final name = details['name'] ?? '';
      final username = details['username'] ?? '';
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.account_circle, size: 36, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  Text('@$username', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.manage_accounts_outlined, color: AppColors.primary),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AdminUserEditScreen(user: UserModel.fromJson(details)),
                  ),
                );
              },
            ),
          ],
        ),
      );
    } else if (subjectType == 'appointment') {
      final title = details['title'] ?? context.l10n.appointmentNoTitle;
      final desc = details['description'] ?? '';
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.event_note, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(context.l10n.reportSubjectAppointmentDetails, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
              ],
            ),
            const SizedBox(height: 6),
            Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                desc,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      );
    } else if (subjectType == 'article') {
      final text = details['text'] ?? '';
      // Extract title first few words
      String title = context.l10n.articleNoTitle;
      if (text.trim().isNotEmpty) {
        final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
        if (lines.isNotEmpty) {
          final words = lines.first.split(RegExp(r'\s+'));
          title = words.length <= 5 ? lines.first : '${words.take(5).join(' ')}...';
        }
      }
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.menu_book, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(context.l10n.reportSubjectArticleDetails, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
              ],
            ),
            const SizedBox(height: 6),
            Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              text,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  void _confirmDeleteContent(BuildContext context, AdminProvider admin, String reportId, String subjectType, String subjectId) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(context.l10n.reportActionDeleteConfirm, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(context.l10n.reportActionDeleteDesc),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(context.l10n.cancel, style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final success = await admin.deleteReportedContent(subjectType, subjectId);
              if (success) {
                final currentUser = Provider.of<AuthProvider>(context, listen: false).user;
                final moderatorTag = currentUser != null ? '@${currentUser.username}' : '@${context.l10n.anonymous}';
                await admin.updateReportStatus(reportId, 'resolved: $moderatorTag');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.l10n.reportDeleteSuccess)),
                  );
                }
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.l10n.reportDeleteFailed)),
                  );
                }
              }
            },
            child: Text(context.l10n.reportActionDelete, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
