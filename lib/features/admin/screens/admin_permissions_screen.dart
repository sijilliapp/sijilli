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
  bool _createApptUser = true;
  bool _createArticleUser = false;
  bool _commentsUser = true;
  final _guestsUserCtrl = TextEditingController();

  // كاتب
  bool _createApptWriter = true;
  bool _createArticleWriter = true;
  bool _commentsWriter = true;
  final _guestsWriterCtrl = TextEditingController();

  // مؤسسة
  bool _createApptOrg = true;
  bool _createArticleOrg = true;
  bool _commentsOrg = true;
  final _guestsOrgCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final config = context.read<GlobalConfigProvider>();
    
    // عادي
    _createApptUser = config.permCreateApptUser;
    _createArticleUser = config.permCreateArticleUser;
    _commentsUser = config.permCommentsUser;
    _guestsUserCtrl.text = config.limitGuestsUser.toString();

    // كاتب
    _createApptWriter = config.permCreateApptWriter;
    _createArticleWriter = config.permCreateArticleWriter;
    _commentsWriter = config.permCommentsWriter;
    _guestsWriterCtrl.text = config.limitGuestsWriter.toString();

    // مؤسسة
    _createApptOrg = config.permCreateApptOrg;
    _createArticleOrg = config.permCreateArticleOrg;
    _commentsOrg = config.permCommentsOrg;
    _guestsOrgCtrl.text = config.limitGuestsOrg.toString();
  }

  @override
  void dispose() {
    _guestsUserCtrl.dispose();
    _guestsWriterCtrl.dispose();
    _guestsOrgCtrl.dispose();
    super.dispose();
  }

  Future<void> _savePermissions(String role) async {
    final admin = context.read<AdminProvider>();
    final config = context.read<GlobalConfigProvider>();

    bool success = true;

    if (role == 'user') {
      final guestsVal = double.tryParse(_guestsUserCtrl.text) ?? 1.0;
      success &= await admin.updateConfigBool('perm_create_appt_user', _createApptUser, config);
      success &= await admin.updateConfigBool('perm_create_article_user', _createArticleUser, config);
      success &= await admin.updateConfigBool('perm_comments_user', _commentsUser, config);
      success &= await admin.updateConfigNumber('limit_guests_user', guestsVal, config);
    } else if (role == 'writer') {
      final guestsVal = double.tryParse(_guestsWriterCtrl.text) ?? 5.0;
      success &= await admin.updateConfigBool('perm_create_appt_writer', _createApptWriter, config);
      success &= await admin.updateConfigBool('perm_create_article_writer', _createArticleWriter, config);
      success &= await admin.updateConfigBool('perm_comments_writer', _commentsWriter, config);
      success &= await admin.updateConfigNumber('limit_guests_writer', guestsVal, config);
    } else if (role == 'organization') {
      final guestsVal = double.tryParse(_guestsOrgCtrl.text) ?? 15.0;
      success &= await admin.updateConfigBool('perm_create_appt_org', _createApptOrg, config);
      success &= await admin.updateConfigBool('perm_create_article_org', _createArticleOrg, config);
      success &= await admin.updateConfigBool('perm_comments_org', _commentsOrg, config);
      success &= await admin.updateConfigNumber('limit_guests_org', guestsVal, config);
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
    bool createAppt;
    bool createArticle;
    bool comments;
    TextEditingController guestsCtrl;
    String roleLabel;

    if (role == 'user') {
      createAppt = _createApptUser;
      createArticle = _createArticleUser;
      comments = _commentsUser;
      guestsCtrl = _guestsUserCtrl;
      roleLabel = 'مستخدم عادي';
    } else if (role == 'writer') {
      createAppt = _createApptWriter;
      createArticle = _createArticleWriter;
      comments = _commentsWriter;
      guestsCtrl = _guestsWriterCtrl;
      roleLabel = 'كاتب معتمد';
    } else {
      createAppt = _createApptOrg;
      createArticle = _createArticleOrg;
      comments = _commentsOrg;
      guestsCtrl = _guestsOrgCtrl;
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

              // 📅 تدوين موعد
              _buildSwitchCard(
                icon: Icons.calendar_today_rounded,
                title: 'تدوين موعد',
                subtitle: 'السماح لهذه الفئة بإنشاء مواعيد جديدة للعامة والمتابعين',
                value: createAppt,
                isDark: isDark,
                onChanged: (val) {
                  setState(() {
                    if (role == 'user') _createApptUser = val;
                    else if (role == 'writer') _createApptWriter = val;
                    else _createApptOrg = val;
                  });
                },
              ),

              const SizedBox(height: 12),

              // 📝 تدوين مقال
              _buildSwitchCard(
                icon: Icons.article_rounded,
                title: 'تدوين مقال',
                subtitle: 'السماح لهذه الفئة بكتابة ونشر مقالات جديدة للجمهور',
                value: createArticle,
                isDark: isDark,
                onChanged: (val) {
                  setState(() {
                    if (role == 'user') _createArticleUser = val;
                    else if (role == 'writer') _createArticleWriter = val;
                    else _createArticleOrg = val;
                  });
                },
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
