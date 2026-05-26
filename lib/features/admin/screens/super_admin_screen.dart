// 📍 lib/features/admin/screens/super_admin_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/global_config_provider.dart';
import '../providers/admin_provider.dart';
import 'admin_messages_screen.dart';
import 'admin_users_screen.dart';
import 'admin_article_prefs_screen.dart';

class SuperAdminScreen extends StatefulWidget {
  const SuperAdminScreen({super.key});

  @override
  State<SuperAdminScreen> createState() => _SuperAdminScreenState();
}

class _SuperAdminScreenState extends State<SuperAdminScreen> {
  @override
  void initState() {
    super.initState();
    // جلب الرسائل في الخلفية فور فتح لوحة التحكم
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AdminProvider>().fetchContactMessages();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'لوحة تحكم المشرف العام',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          children: [
            // 📋 القسم الأول: إعدادات التطبيق العامة
            const Padding(
              padding: EdgeInsets.only(left: 8, right: 8, top: 4, bottom: 4),
              child: Text(
                'إعدادات التسجيل والدخول',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
            
            Consumer2<GlobalConfigProvider, AdminProvider>(
              builder: (context, config, admin, _) {
                return _buildSwitchCard(
                  context,
                  isDark: isDark,
                  icon: Icons.person_add_alt_1_outlined,
                  value: config.isRegistrationEnabled,
                  isLoading: admin.isLoading,
                  activeColor: AppColors.primary,
                  onChanged: (val) async {
                    final success = await admin.toggleRegistration(val, config);
                    if (success && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(val ? 'تم استئناف التسجيل بنجاح' : 'تم إيقاف التسجيل بنجاح'),
                          backgroundColor: val ? Colors.green : Colors.orange,
                        ),
                      );
                    } else if (!success && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('حدث خطأ أثناء حفظ الإعدادات'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                );
              },
            ),

            const SizedBox(height: 8),

            _buildClickableCard(
              context,
              isDark: isDark,
              icon: Icons.manage_accounts_outlined,
              title: 'إدارة حسابات المستخدمين',
              subtitle: 'البحث عن المشتركين وتعديل الصلاحيات والأدوار الفعالة',
              badgeCount: 0,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AdminUsersScreen()),
                );
              },
            ),

            const SizedBox(height: 8),

            // 📝 القسم الثاني: إدارة المقالات والمحتوى
            const Padding(
              padding: EdgeInsets.only(left: 8, right: 8, top: 8, bottom: 4),
              child: Text(
                'إدارة المقالات والمحتوى',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),

            _buildClickableCard(
              context,
              isDark: isDark,
              icon: Icons.article_outlined,
              title: 'تفضيلات المقالات الإدارية',
              subtitle: 'الحد الأقصى لحروف المقالات وإدارة قاموس الأخطاء الشائعة المخصص',
              badgeCount: 0,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AdminArticlePrefsScreen()),
                );
              },
            ),

            const SizedBox(height: 8),

            // 💬 القسم الثاني: الدعم الفني والمراسلات
            const Padding(
              padding: EdgeInsets.only(left: 8, right: 8, top: 8, bottom: 4),
              child: Text(
                'المراسلات والدعم الفني',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),

            Consumer<AdminProvider>(
              builder: (context, admin, _) {
                return _buildClickableCard(
                  context,
                  isDark: isDark,
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'مراسلات التواصل',
                  subtitle: 'استعراض وإدارة استفسارات واقتراحات وشكاوى المستخدمين',
                  badgeCount: admin.newMessagesCount,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AdminMessagesScreen()),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchCard(
    BuildContext context, {
    required bool isDark,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isLoading,
    Color activeColor = AppColors.primary,
  }) {
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
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: activeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: activeColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'السماح بتسجيل حسابات جديدة',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'تعطيل هذا الخيار سيمنع انضمام أي مشترك جديد للتطبيق.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).brightness == Brightness.dark 
                          ? Colors.grey.shade400 
                          : Colors.grey.shade600,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              Switch(
                value: value,
                onChanged: onChanged,
                activeColor: activeColor,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildClickableCard(
    BuildContext context, {
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    required int badgeCount,
    required VoidCallback onTap,
    Color activeColor = AppColors.primary,
  }) {
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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: activeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: activeColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        if (badgeCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$badgeCount جديد',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).brightness == Brightness.dark 
                            ? Colors.grey.shade400 
                            : Colors.grey.shade600,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: Theme.of(context).dividerColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
