// 📍 lib/features/admin/screens/admin_reports_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../providers/admin_provider.dart';
import 'admin_user_edit_screen.dart';
import '../../../models/user.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:timeago/timeago.dart' as timeago;

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  final Map<String, Map<String, dynamic>?> _subjectDetailsCache = {};
  final Map<String, bool> _loadingSubjects = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AdminProvider>().fetchReports();
      }
    });
  }

  Future<void> _loadSubjectDetails(String reportId, String subjectType, String subjectId) async {
    if (_subjectDetailsCache.containsKey(reportId) || (_loadingSubjects[reportId] ?? false)) {
      return;
    }

    setState(() {
      _loadingSubjects[reportId] = true;
    });

    final details = await context.read<AdminProvider>().fetchSubjectDetails(subjectType, subjectId);

    if (mounted) {
      setState(() {
        _subjectDetailsCache[reportId] = details;
        _loadingSubjects[reportId] = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'البلاغات والتقارير',
          style: TextStyle(fontWeight: FontWeight.bold),
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
                    const Text(
                      'لا توجد بلاغات معلقة',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'كل شيء يبدو آمناً ونظيفاً!',
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
                  return _buildReportCard(context, report, isDark, admin);
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildReportCard(BuildContext context, RecordModel report, bool isDark, AdminProvider admin) {
    final reportId = report.id;
    final reporter = report.expand['reporter']?.first;
    final reporterName = reporter?.getStringValue('name') ?? reporter?.getStringValue('username') ?? 'مجهول';
    final subjectType = report.getStringValue('subject_type');
    final subjectId = report.getStringValue('subject_id');
    final reason = report.getStringValue('reason');
    final status = report.getStringValue('status');
    final created = report.getStringValue('created');
    final createdDate = DateTime.tryParse(created) ?? DateTime.now();

    String typeLabel = '';
    IconData typeIcon = Icons.info_outline;
    Color typeColor = Colors.grey;

    switch (subjectType) {
      case 'user':
        typeLabel = 'حساب مستخدم';
        typeIcon = Icons.person_outline;
        typeColor = Colors.orange;
        break;
      case 'appointment':
        typeLabel = 'موعد جديد';
        typeIcon = Icons.calendar_today_outlined;
        typeColor = AppColors.primary;
        break;
      case 'article':
        typeLabel = 'مقال منشورة';
        typeIcon = Icons.article_outlined;
        typeColor = Colors.blue;
        break;
    }

    final hasDetails = _subjectDetailsCache.containsKey(reportId);
    final details = _subjectDetailsCache[reportId];
    final isLoadingDetails = _loadingSubjects[reportId] ?? false;

    // Trigger details load if expanded or just load automatically on build
    if (!hasDetails && !isLoadingDetails) {
      _loadSubjectDetails(reportId, subjectType, subjectId);
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
                  timeago.format(createdDate, locale: 'ar'),
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
                Text(
                  'المُبلّغ: ',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                  ),
                ),
                Text(
                  reporterName,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Reason
            Text(
              'السبب: $reason',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.grey.shade300 : Colors.black87,
              ),
            ),
            const Divider(height: 24),

            // Subject Details Section
            if (isLoadingDetails)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 10),
                    Text('جاري تحميل تفاصيل المحتوى المُبلّغ عنه...', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              )
            else if (details == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  '⚠️ هذا المحتوى لم يعد متاحاً أو تم حذفه مسبقاً.',
                  style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w600),
                ),
              )
            else
              _buildSubjectPreview(context, subjectType, details, isDark),

            const SizedBox(height: 16),

            // Action Buttons
            if (status == 'pending')
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.block_outlined, size: 16, color: Colors.red),
                      label: const Text('حذف المحتوى', style: TextStyle(color: Colors.red, fontSize: 12)),
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
                      label: const Text('تجاهل وحفظ', style: TextStyle(color: Colors.white, fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => admin.updateReportStatus(reportId, 'ignored'),
                    ),
                  ),
                ],
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: status == 'resolved' ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status == 'resolved' ? '✅ تم حسم هذا البلاغ وحذف المحتوى' : 'ℹ️ تم تجاهل هذا البلاغ وأرشفته',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: status == 'resolved' ? Colors.green : Colors.grey,
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
      final title = details['title'] ?? 'موعد بدون عنوان';
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
            const Row(
              children: [
                Icon(Icons.event_note, size: 16, color: AppColors.primary),
                SizedBox(width: 6),
                Text('تفاصيل الموعد المُبلّغ عنه:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
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
      String title = 'مقال بدون عنوان';
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
            const Row(
              children: [
                Icon(Icons.menu_book, size: 16, color: AppColors.primary),
                SizedBox(width: 6),
                Text('تفاصيل المقال المُبلّغ عنه:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
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
      builder: (context) => AlertDialog(
        title: const Text('تأكيد حذف المحتوى', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('هل أنت متأكد من رغبتك في حذف هذا المحتوى نهائياً من قاعدة البيانات؟ لا يمكن التراجع عن هذا الإجراء.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              final success = await admin.deleteReportedContent(subjectType, subjectId);
              if (success) {
                await admin.updateReportStatus(reportId, 'resolved');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم حذف المحتوى بنجاح وحسم البلاغ 🚀')),
                  );
                }
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('⚠️ فشل في حذف المحتوى. قد يكون تم حذفه مسبقاً.')),
                  );
                }
              }
            },
            child: const Text('نعم، حذف نهائياً', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
