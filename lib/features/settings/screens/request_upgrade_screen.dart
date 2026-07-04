// 📍 lib/features/settings/screens/request_upgrade_screen.dart
// 👑 شاشة تقديم ومتابعة طلب ترقية العضوية

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pocketbase/pocketbase.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../auth/providers/auth_provider.dart';

class RequestUpgradeScreen extends StatefulWidget {
  const RequestUpgradeScreen({super.key});

  @override
  State<RequestUpgradeScreen> createState() => _RequestUpgradeScreenState();
}

class _RequestUpgradeScreenState extends State<RequestUpgradeScreen> {
  final _notesController = TextEditingController();
  String _selectedRole = 'writer';
  bool _isSubmitting = false;
  List<RecordModel> _myRequests = [];
  bool _isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoadingHistory = true;
    });
    final requests = await context.read<AuthProvider>().getMyUpgradeRequests();
    if (mounted) {
      setState(() {
        _myRequests = requests;
        _isLoadingHistory = false;
      });
    }
  }

  Future<void> _submitRequest() async {
    final notes = _notesController.text.trim();
    if (notes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء كتابة مبررات طلب الترقية أو نبذة عنك')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final success = await context.read<AuthProvider>().requestRoleUpgrade(_selectedRole, notes);

    if (mounted) {
      setState(() {
        _isSubmitting = false;
      });

      if (success) {
        _notesController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال طلب الترقية للمشرفين بنجاح وهو قيد المراجعة'),
            backgroundColor: Colors.green,
          ),
        );
        _loadHistory();
      } else {
        final error = context.read<AuthProvider>().errorMessage ?? 'حدث خطأ أثناء إرسال الطلب';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل الإرسال: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = context.watch<AuthProvider>().user;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('الرجاء تسجيل الدخول أولاً')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('طلب ترقية العضوية'),
        centerTitle: true,
        backgroundColor: isDark ? null : AppColors.primary,
        foregroundColor: isDark ? null : Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Current Role Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: theme.dividerColor.withOpacity(0.15)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.stars_rounded, color: Colors.blueAccent, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'صنف عضويتك الحالية',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user.roleDisplayName,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Select Target Role Title
            const Text(
              'اختر الصنف المطلوب الترقية إليه:',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 8),

            // Role selection options
            Row(
              textDirection: TextDirection.rtl,
              children: [
                Expanded(
                  child: _buildRoleSelectOption(
                    title: 'كاتب',
                    subtitle: 'للكتاب والباحثين',
                    roleKey: 'writer',
                    icon: Icons.edit_note_rounded,
                    selectedColor: Colors.blueAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildRoleSelectOption(
                    title: 'مؤسسة / جهة',
                    subtitle: 'للمراكز والهيئات',
                    roleKey: 'organization',
                    icon: Icons.business_rounded,
                    selectedColor: Colors.amber.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Application Notes Title
            const Text(
              'مبررات الطلب أو معلومات تعريفية عنك:',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 8),

            // Reason Text Field
            TextField(
              controller: _notesController,
              maxLines: 4,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(
                hintText: 'اكتب مبررات الترقية أو مؤهلاتك هنا (مثال: رابط لموقعك، أعمالك السابقة، أو طبيعة المواد التي تنشرها...)',
                hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.dividerColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5),
                ),
                filled: true,
                fillColor: theme.cardColor.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 16),

            // Submit Button
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('إرسال طلب الترقية للمراجعة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 30),

            // Previous Requests Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              textDirection: TextDirection.rtl,
              children: [
                const Text(
                  'سجل طلبات الترقية السابقة',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  onPressed: _loadHistory,
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),

            _buildHistoryList(),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleSelectOption({
    required String title,
    required String subtitle,
    required String roleKey,
    required IconData icon,
    required Color selectedColor,
  }) {
    final isSelected = _selectedRole == roleKey;
    final theme = Theme.of(context);

    return InkWell(
      onTap: () {
        setState(() {
          _selectedRole = roleKey;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected 
              ? selectedColor.withOpacity(0.08) 
              : theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? selectedColor : theme.dividerColor.withOpacity(0.15),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? selectedColor : Colors.grey, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isSelected ? selectedColor : theme.textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList() {
    if (_isLoadingHistory) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_myRequests.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'لا توجد طلبات سابقة',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _myRequests.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final req = _myRequests[index];
        final roleKey = req.getStringValue('requested_role');
        final status = req.getStringValue('status');
        final created = req.getStringValue('created');
        final userNotes = req.getStringValue('user_notes');
        final adminNotes = req.getStringValue('admin_notes');

        Color statusColor;
        String statusText;
        IconData statusIcon;

        switch (status) {
          case 'approved':
            statusColor = Colors.green;
            statusText = 'مقبول';
            statusIcon = Icons.check_circle_rounded;
            break;
          case 'rejected':
            statusColor = Colors.red;
            statusText = 'مرفوض';
            statusIcon = Icons.cancel_rounded;
            break;
          case 'pending':
          default:
            statusColor = Colors.orange;
            statusText = 'قيد المراجعة';
            statusIcon = Icons.hourglass_empty_rounded;
            break;
        }

        String roleDisplay = roleKey == 'writer' ? 'كاتب معتمد' : 'مؤسسة / جهة';

        return Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  textDirection: TextDirection.rtl,
                  children: [
                    Text(
                      'ترقية إلى: $roleDisplay',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        textDirection: TextDirection.rtl,
                        children: [
                          Icon(statusIcon, color: statusColor, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            statusText,
                            style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'ملاحظاتك: $userNotes',
                  style: const TextStyle(fontSize: 13),
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                ),
                if (adminNotes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'تعليق الإدارة: $adminNotes',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
                      textAlign: TextAlign.right,
                      textDirection: TextDirection.rtl,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  'تاريخ الطلب: ${created.substring(0, 10)}',
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
