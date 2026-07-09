// 📍 lib/features/admin/screens/admin_system_notification_screen.dart
// 🛡️ شاشة إرسال وبث إشعارات النظام الجماعية للفئات المستهدفة

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../providers/admin_provider.dart';

class AdminSystemNotificationScreen extends StatefulWidget {
  const AdminSystemNotificationScreen({super.key});

  @override
  State<AdminSystemNotificationScreen> createState() => _AdminSystemNotificationScreenState();
}

class _AdminSystemNotificationScreenState extends State<AdminSystemNotificationScreen> {
  // Target roles state
  final Set<String> _selectedRoles = {'user', 'writer', 'admin', 'organization'};

  // Nerve Tapping Game form controllers
  late final TextEditingController _nerveTitleController;
  late final TextEditingController _nerveMessageController;

  @override
  void initState() {
    super.initState();
    _nerveTitleController = TextEditingController(text: 'تحدّي الأعصاب اليومي ⚡');
    _nerveMessageController = TextEditingController(
      text: 'اضغط 10 مرات متتالية بأسرع ما يمكن وسجل نتيجتك في قائمة التحدي اليومية!',
    );
  }

  @override
  void dispose() {
    _nerveTitleController.dispose();
    _nerveMessageController.dispose();
    super.dispose();
  }

  void _toggleRole(String role, bool selected) {
    setState(() {
      if (selected) {
        _selectedRoles.add(role);
      } else {
        if (_selectedRoles.length > 1) {
          _selectedRoles.remove(role);
        } else {
          // Prevent unchecking all roles
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('الرجاء اختيار جهة مستهدفة واحدة على الأقل')),
          );
        }
      }
    });
  }

  Future<void> _sendNotification({
    required String title,
    required String message,
    String? relatedId,
  }) async {
    if (title.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال العنوان ونص الرسالة')),
      );
      return;
    }

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (loadingContext) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    final success = await context.read<AdminProvider>().sendSystemNotificationToAll(
          title: title,
          message: message,
          relatedId: relatedId,
          targetRoles: _selectedRoles.toList(),
        );

    if (mounted) {
      Navigator.pop(context); // Close loading dialog
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success 
              ? 'تم إرسال الإشعار للفئات المحددة بنجاح' 
              : 'فشل إرسال الإشعار'),
          backgroundColor: success ? AppColors.success : Colors.red,
        ),
      );

      if (success) {
        Navigator.pop(context); // Go back on success
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('بث إشعار للنظام', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimens.space),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Target Recipients Header Card
              _buildTargetSelectorCard(isDark),
              
              const SizedBox(height: AppDimens.space),

              // 2. Sections Label
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Text(
                  'خيارات البث المتاحة والمستقبلية:',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ),

              const SizedBox(height: 8),

              // 3. Option 1: Daily Nerve Tapping Game Form
              _buildNerveGameCard(isDark),

              const SizedBox(height: AppDimens.spaceXS),

              // 4. Option 2: Group Event (Future/Disabled)
              _buildFutureFeatureCard(
                isDark: isDark,
                title: 'حدث جماعي (قريباً ⏳)',
                subtitle: 'إشعار لبث مناسبة أو حدث ديني أو اجتماعي قادم لجميع المشتركين.',
                icon: Icons.event_available_outlined,
              ),

              const SizedBox(height: AppDimens.spaceXS),

              // 5. Option 3: Group Article (Future/Disabled)
              _buildFutureFeatureCard(
                isDark: isDark,
                title: 'مقال جماعي (قريباً ⏳)',
                subtitle: 'إشعار يدعو المشتركين لقراءة بيان رسمي أو مقال مميز تم نشره حديثاً.',
                icon: Icons.menu_book_outlined,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTargetSelectorCard(bool isDark) {
    final rolesList = [
      {'key': 'user', 'label': 'مستخدم (user)'},
      {'key': 'writer', 'label': 'كاتب (writer)'},
      {'key': 'admin', 'label': 'مشرف (admin)'},
      {'key': 'organization', 'label': 'مؤسسة (org)'},
    ];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.people_alt_outlined, color: AppColors.primary, size: 20),
                SizedBox(width: 8),
                Text(
                  'اختيار الجهات المستهدفة بالرسالة الجماعية:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: rolesList.map((role) {
                final key = role['key']!;
                final label = role['label']!;
                final isSelected = _selectedRoles.contains(key);

                return FilterChip(
                  label: Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (val) => _toggleRole(key, val),
                  selectedColor: AppColors.primary,
                  checkmarkColor: Colors.white,
                  backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Text(
              'سيتم تصفية وبث الإشعار حصراً للمستخدمين الذين يحملون الأدوار المحددة أعلاه.',
              style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNerveGameCard(bool isDark) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          leading: const Icon(Icons.flash_on, color: Colors.amber),
          title: const Text(
            'لعبة النقر السريع',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          subtitle: const Text('إطلاق وتفعيل جولة تحدي النقر اليومي وتنبيه المستخدمين'),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nerveTitleController,
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(
                      labelText: 'عنوان الإشعار',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nerveMessageController,
                    maxLines: 3,
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(
                      labelText: 'نص الرسالة',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _sendNotification(
                      title: _nerveTitleController.text.trim(),
                      message: _nerveMessageController.text.trim(),
                      relatedId: 'game_nerve',
                    ),
                    icon: const Icon(Icons.send_rounded, size: 16),
                    label: const Text('إرسال وبدء التحدي ⚡'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFutureFeatureCard({
    required bool isDark,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Card(
      elevation: 0,
      color: isDark ? Colors.grey.shade900.withOpacity(0.5) : Colors.grey.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(icon, color: Colors.grey.shade500),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade500,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
