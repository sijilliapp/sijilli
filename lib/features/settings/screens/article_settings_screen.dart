import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../auth/providers/auth_provider.dart';

class ArticleSettingsScreen extends StatefulWidget {
  const ArticleSettingsScreen({super.key});

  @override
  State<ArticleSettingsScreen> createState() => _ArticleSettingsScreenState();
}

class _ArticleSettingsScreenState extends State<ArticleSettingsScreen> {
  bool _disableCopying = false;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _disableCopying = user?.disableCopying ?? false;
  }

  Future<void> _updateArticleSetting(bool value) async {
    setState(() => _isUpdating = true);
    
    final success = await context.read<AuthProvider>().updateUser({
      'disable_copying': value,
    });

    if (mounted) {
      setState(() => _isUpdating = false);
      if (!success) {
        // Rollback on failure
        setState(() {
          _disableCopying = !_disableCopying;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل تحديث الإعدادات، يرجى المحاولة مرة أخرى.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إعدادات المقالات'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppDimens.padding),
        children: [
          _buildSwitchTile(
            title: 'تعطيل نسخ المقال',
            subtitle: 'يمنع القراء من نسخ نصوص مقالاتك لحماية المحتوى من السرقة.',
            icon: Icons.copy_all_outlined,
            value: _disableCopying,
            onChanged: (val) {
              setState(() => _disableCopying = val);
              _updateArticleSetting(val);
            },
          ),
          if (_isUpdating)
            const Padding(
              padding: EdgeInsets.only(top: 20),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
      ),
      child: SwitchListTile(
        secondary: Icon(icon, color: AppColors.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        value: value,
        onChanged: _isUpdating ? null : onChanged,
        activeColor: AppColors.primary,
      ),
    );
  }
}
