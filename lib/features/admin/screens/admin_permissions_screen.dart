// 📍 lib/features/admin/screens/admin_permissions_screen.dart
// 🛡️ شاشة إدارة صلاحيات الفئات والأدوار للمشرفين

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/providers/global_config_provider.dart';
import '../providers/admin_provider.dart';

class AdminPermissionsScreen extends StatefulWidget {
  const AdminPermissionsScreen({super.key});

  @override
  State<AdminPermissionsScreen> createState() => _AdminPermissionsScreenState();
}

class _AdminPermissionsScreenState extends State<AdminPermissionsScreen> {
  // عادي
  final _createApptUserCtrl = TextEditingController();
  final _createArticleUserCtrl = TextEditingController();
  bool _commentsUser = true;
  final _guestsUserCtrl = TextEditingController();
  final _socialLinksUserCtrl = TextEditingController();

  // كاتب
  final _createApptWriterCtrl = TextEditingController();
  final _createArticleWriterCtrl = TextEditingController();
  bool _commentsWriter = true;
  final _guestsWriterCtrl = TextEditingController();
  final _socialLinksWriterCtrl = TextEditingController();

  // مؤسسة
  final _createApptOrgCtrl = TextEditingController();
  final _createArticleOrgCtrl = TextEditingController();
  bool _commentsOrg = true;
  final _guestsOrgCtrl = TextEditingController();
  final _socialLinksOrgCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final config = context.read<GlobalConfigProvider>();
    
    // عادي
    _createApptUserCtrl.text = config.limitCreateApptDailyUser.toString();
    _createArticleUserCtrl.text = config.limitCreateArticleDailyUser.toString();
    _commentsUser = config.permCommentsUser;
    _guestsUserCtrl.text = config.limitGuestsUser.toString();
    _socialLinksUserCtrl.text = config.limitSocialLinksUser.toString();

    // كاتب
    _createApptWriterCtrl.text = config.limitCreateApptDailyWriter.toString();
    _createArticleWriterCtrl.text = config.limitCreateArticleDailyWriter.toString();
    _commentsWriter = config.permCommentsWriter;
    _guestsWriterCtrl.text = config.limitGuestsWriter.toString();
    _socialLinksWriterCtrl.text = config.limitSocialLinksWriter.toString();

    // مؤسسة
    _createApptOrgCtrl.text = config.limitCreateApptDailyOrg.toString();
    _createArticleOrgCtrl.text = config.limitCreateArticleDailyOrg.toString();
    _commentsOrg = config.permCommentsOrg;
    _guestsOrgCtrl.text = config.limitGuestsOrg.toString();
    _socialLinksOrgCtrl.text = config.limitSocialLinksOrg.toString();
  }

  @override
  void dispose() {
    _createApptUserCtrl.dispose();
    _createArticleUserCtrl.dispose();
    _guestsUserCtrl.dispose();
    _socialLinksUserCtrl.dispose();

    _createApptWriterCtrl.dispose();
    _createArticleWriterCtrl.dispose();
    _guestsWriterCtrl.dispose();
    _socialLinksWriterCtrl.dispose();

    _createApptOrgCtrl.dispose();
    _createArticleOrgCtrl.dispose();
    _guestsOrgCtrl.dispose();
    _socialLinksOrgCtrl.dispose();
    super.dispose();
  }

  Future<void> _savePermissions(String role) async {
    final admin = context.read<AdminProvider>();
    final config = context.read<GlobalConfigProvider>();

    bool success = true;

    if (role == 'user') {
      final apptVal = double.tryParse(_createApptUserCtrl.text) ?? 5.0;
      final articleVal = double.tryParse(_createArticleUserCtrl.text) ?? 0.0;
      final guestsVal = double.tryParse(_guestsUserCtrl.text) ?? 1.0;
      final socialVal = double.tryParse(_socialLinksUserCtrl.text) ?? 1.0;
      
      success &= await admin.updateConfigNumber('limit_create_appt_daily_user', apptVal, config);
      success &= await admin.updateConfigNumber('limit_create_article_daily_user', articleVal, config);
      success &= await admin.updateConfigBool('perm_comments_user', _commentsUser, config);
      success &= await admin.updateConfigNumber('limit_guests_user', guestsVal, config);
      success &= await admin.updateConfigNumber('limit_social_links_user', socialVal, config);
    } else if (role == 'writer') {
      final apptVal = double.tryParse(_createApptWriterCtrl.text) ?? 10.0;
      final articleVal = double.tryParse(_createArticleWriterCtrl.text) ?? 5.0;
      final guestsVal = double.tryParse(_guestsWriterCtrl.text) ?? 5.0;
      final socialVal = double.tryParse(_socialLinksWriterCtrl.text) ?? 3.0;
      
      success &= await admin.updateConfigNumber('limit_create_appt_daily_writer', apptVal, config);
      success &= await admin.updateConfigNumber('limit_create_article_daily_writer', articleVal, config);
      success &= await admin.updateConfigBool('perm_comments_writer', _commentsWriter, config);
      success &= await admin.updateConfigNumber('limit_guests_writer', guestsVal, config);
      success &= await admin.updateConfigNumber('limit_social_links_writer', socialVal, config);
    } else if (role == 'organization') {
      final apptVal = double.tryParse(_createApptOrgCtrl.text) ?? 30.0;
      final articleVal = double.tryParse(_createArticleOrgCtrl.text) ?? 15.0;
      final guestsVal = double.tryParse(_guestsOrgCtrl.text) ?? 15.0;
      final socialVal = double.tryParse(_socialLinksOrgCtrl.text) ?? 5.0;
      
      success &= await admin.updateConfigNumber('limit_create_appt_daily_org', apptVal, config);
      success &= await admin.updateConfigNumber('limit_create_article_daily_org', articleVal, config);
      success &= await admin.updateConfigBool('perm_comments_org', _commentsOrg, config);
      success &= await admin.updateConfigNumber('limit_guests_org', guestsVal, config);
      success &= await admin.updateConfigNumber('limit_social_links_org', socialVal, config);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'تم حفظ التغييرات بنجاح' : 'حدث خطأ أثناء الحفظ!'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text(
            'إدارة الصلاحيات والأدوار',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          elevation: 0,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          foregroundColor: isDark ? Colors.white : Colors.black,
          bottom: TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            indicatorColor: AppColors.primary,
            indicatorSize: TabBarIndicatorSize.tab,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            tabs: const [
              Tab(text: 'عادي'),
              Tab(text: 'كاتب'),
              Tab(text: 'مؤسسة'),
            ],
          ),
        ),
        body: SafeArea(
          child: Consumer<AdminProvider>(
            builder: (context, admin, _) {
              return TabBarView(
                children: [
                  _buildRoleTab('user', isDark, admin.isLoading),
                  _buildRoleTab('writer', isDark, admin.isLoading),
                  _buildRoleTab('organization', isDark, admin.isLoading),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildRoleTab(String role, bool isDark, bool isLoading) {
    TextEditingController createApptCtrl;
    TextEditingController createArticleCtrl;
    bool comments;
    TextEditingController guestsCtrl;
    TextEditingController socialLinksCtrl;
    String roleLabel;

    if (role == 'user') {
      createApptCtrl = _createApptUserCtrl;
      createArticleCtrl = _createArticleUserCtrl;
      comments = _commentsUser;
      guestsCtrl = _guestsUserCtrl;
      socialLinksCtrl = _socialLinksUserCtrl;
      roleLabel = 'مستخدم عادي';
    } else if (role == 'writer') {
      createApptCtrl = _createApptWriterCtrl;
      createArticleCtrl = _createArticleWriterCtrl;
      comments = _commentsWriter;
      guestsCtrl = _guestsWriterCtrl;
      socialLinksCtrl = _socialLinksWriterCtrl;
      roleLabel = 'كاتب معتمد';
    } else {
      createApptCtrl = _createApptOrgCtrl;
      createArticleCtrl = _createArticleOrgCtrl;
      comments = _commentsOrg;
      guestsCtrl = _guestsOrgCtrl;
      socialLinksCtrl = _socialLinksOrgCtrl;
      roleLabel = 'مؤسسة / جهة معتمدة';
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 📋 العنوان التعريفي للفئة
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0, right: 4.0),
                child: Text(
                  'صلاحيات فئة: $roleLabel',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),

              // 📅 الحد اليومي للمواعيد
              _buildInputCard(
                icon: Icons.calendar_today_rounded,
                title: 'الحد اليومي للمواعيد',
                subtitle: 'أقصى عدد للمواعيد التي يمكن إنشاؤها يومياً (0 للمنع)',
                controller: createApptCtrl,
                isDark: isDark,
              ),

              const SizedBox(height: 12),

              // 📝 الحد اليومي للمقالات
              _buildInputCard(
                icon: Icons.article_rounded,
                title: 'الحد اليومي للمقالات',
                subtitle: 'أقصى عدد للمقالات التي يمكن نشرها يومياً (0 للمنع)',
                controller: createArticleCtrl,
                isDark: isDark,
              ),

              const SizedBox(height: 12),

              // 💬 التعليقات
              _buildSwitchCard(
                icon: Icons.comment_rounded,
                title: 'التعليقات',
                subtitle: 'السماح للمستخدمين من هذه الفئة بالتعليق على مقالات الآخرين',
                value: comments,
                isDark: isDark,
                onChanged: (val) {
                  setState(() {
                    if (role == 'user') _commentsUser = val;
                    else if (role == 'writer') _commentsWriter = val;
                    else _commentsOrg = val;
                  });
                },
              ),

              const SizedBox(height: 12),

              // 👥 عدد الضيوف
              _buildInputCard(
                icon: Icons.group_add_rounded,
                title: 'عدد الضيوف الأقصى',
                subtitle: 'الحد الأقصى للأشخاص المستضافين في الموعد الواحد',
                controller: guestsCtrl,
                isDark: isDark,
              ),

              const SizedBox(height: 12),

              // 🔗 عدد الروابط الاجتماعية الأقصى
              _buildInputCard(
                icon: Icons.link_rounded,
                title: 'الحد الأقصى لروابط التواصل',
                subtitle: 'أقصى عدد من الروابط الاجتماعية المسموح بإضافتها في الملف الشخصي',
                controller: socialLinksCtrl,
                isDark: isDark,
              ),
            ],
          ),
        ),

        // زر الحفظ في الأسفل
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: isLoading ? null : () => _savePermissions(role),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'حفظ التغييرات',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required bool isDark,
    required ValueChanged<bool> onChanged,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
      ),
      color: isDark ? AppColors.darkSurface : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              activeColor: AppColors.primary,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required TextEditingController controller,
    required bool isDark,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
      ),
      color: isDark ? AppColors.darkSurface : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 70,
              height: 40,
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.zero,
                  filled: true,
                  fillColor: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
