// 📍 lib/features/admin/screens/admin_upgrade_requests_screen.dart
// 🛡️ شاشة مراجعة وإدارة طلبات الترقية للمشرفين

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pocketbase/pocketbase.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/providers/auth_provider.dart';

class AdminUpgradeRequestsScreen extends StatefulWidget {
  const AdminUpgradeRequestsScreen({super.key});

  @override
  State<AdminUpgradeRequestsScreen> createState() => _AdminUpgradeRequestsScreenState();
}

class _AdminUpgradeRequestsScreenState extends State<AdminUpgradeRequestsScreen> {
  List<RecordModel> _pendingRequests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    setState(() {
      _isLoading = true;
    });
    final requests = await context.read<AuthProvider>().getPendingUpgradeRequests();
    if (mounted) {
      setState(() {
        _pendingRequests = requests;
        _isLoading = false;
      });
    }
  }

  Future<void> _processRequest(RecordModel request, bool approve) async {
    final theme = Theme.of(context);
    final notesController = TextEditingController();
    final actionText = approve ? 'قبول' : 'رفض';
    final actionColor = approve ? Colors.green : Colors.red;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '$actionText طلب الترقية',
          textAlign: TextAlign.right,
          style: TextStyle(color: actionColor, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'هل أنت متأكد من رغبتك في $actionText هذا الطلب؟',
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              maxLines: 3,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(
                hintText: approve 
                    ? 'تعليق الإدارة أو الترحيب بالعضو (اختياري)...' 
                    : 'سبب الرفض وتوجيه العضو (مطلوب)...',
                hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              if (!approve && notesController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('الرجاء كتابة سبب رفض الطلب')),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: actionColor, foregroundColor: Colors.white),
            child: Text(actionText),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() {
        _isLoading = true;
      });

      final notes = notesController.text.trim();
      bool success;

      if (approve) {
        final targetUserId = request.getStringValue('user');
        final requestedRole = request.getStringValue('requested_role');
        success = await context.read<AuthProvider>().approveUpgrade(
          request.id,
          targetUserId,
          requestedRole,
          notes,
        );
      } else {
        success = await context.read<AuthProvider>().rejectUpgrade(request.id, notes);
      }

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم $actionText الطلب بنجاح وتحديث الرول'),
              backgroundColor: Colors.green,
            ),
          );
          _fetchRequests();
        } else {
          final error = context.read<AuthProvider>().errorMessage ?? 'حدث خطأ أثناء معالجة الطلب';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('فشل تنفيذ العملية: $error'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('طلبات ترقية العضوية'),
        centerTitle: true,
        backgroundColor: isDark ? null : AppColors.primary,
        foregroundColor: isDark ? null : Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchRequests,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pendingRequests.isEmpty
              ? _buildEmptyState()
              : _buildRequestsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 64),
            ),
            const SizedBox(height: 16),
            const Text(
              'لا توجد طلبات ترقية معلقة حالياً',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'جميع طلبات الأعضاء تمت مراجعتها بالكامل.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestsList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _pendingRequests.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final req = _pendingRequests[index];
        final userExpandList = req.expand['user'] as List<RecordModel>?;
        final userExpand = (userExpandList != null && userExpandList.isNotEmpty) ? userExpandList.first : null;
        final userName = userExpand?.getStringValue('name') ?? 'عضو غير معروف';
        final userUsername = userExpand?.getStringValue('username') ?? '';
        final roleKey = req.getStringValue('requested_role');
        final userNotes = req.getStringValue('user_notes');
        final created = req.getStringValue('created');

        String roleDisplay = roleKey == 'writer' ? 'كاتب معتمد' : 'مؤسسة / جهة';
        Color roleBadgeColor = roleKey == 'writer' ? Colors.blueAccent : Colors.amber.shade700;

        return Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    CircleAvatar(
                      backgroundColor: roleBadgeColor.withOpacity(0.1),
                      child: Text(
                        userName.isNotEmpty ? userName.substring(0, 1) : 'U',
                        style: TextStyle(color: roleBadgeColor, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          Text('@$userUsername', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: roleBadgeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'ترقية لـ: $roleDisplay',
                        style: TextStyle(color: roleBadgeColor, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 6),
                const Text(
                  'رسالة ومبررات التقديم:',
                  style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 4),
                Text(
                  userNotes,
                  style: const TextStyle(fontSize: 14, height: 1.4),
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _processRequest(req, false),
                        icon: const Icon(Icons.cancel_rounded, color: Colors.red, size: 18),
                        label: const Text('رفض الطلب', style: TextStyle(color: Colors.red)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _processRequest(req, true),
                        icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                        label: const Text('قبول وترقية', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'تاريخ الطلب: ${created.substring(0, 10)} | الساعة: ${created.substring(11, 16)}',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                  textAlign: TextAlign.left,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
