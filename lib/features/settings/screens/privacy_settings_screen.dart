import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/change_password_screen.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  bool _hideProfile = false; // Inverted from isPublic
  bool _hideFromSearch = false;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _hideProfile = !(user?.isPublic ?? true); // Default is public (true), so hide is false
    _hideFromSearch = user?.hideFromSearch ?? false;
  }

  Future<void> _updatePrivacySetting(String field, bool value) async {
    setState(() => _isUpdating = true);
    
    final success = await context.read<AuthProvider>().updateUser({
      field == 'hideProfile' ? 'isPublic' : field: field == 'hideProfile' ? !value : value,
    });

    if (mounted) {
      setState(() => _isUpdating = false);
      if (!success) {
        // Rollback on failure
        setState(() {
          if (field == 'hideProfile') _hideProfile = !_hideProfile;
          if (field == 'hideFromSearch') _hideFromSearch = !_hideFromSearch;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.errorOccurred), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.privacyAndSecurity),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppDimens.padding),
        children: [
          // حجب حسابي عن الغرباء
          _buildSwitchTile(
            title: 'حجب حسابي عن الغرباء',
            subtitle: 'يمنع أي شخص غير مضاف في سجلك من استعراض حسابك الشخصي أو الوصول لمواعيدك.',
            icon: Icons.shield_outlined,
            value: _hideProfile,
            onChanged: (val) {
              setState(() => _hideProfile = val);
              _updatePrivacySetting('hideProfile', val);
            },
          ),
          const SizedBox(height: 12),

          // حجب حسابي من البحث
          _buildSwitchTile(
            title: 'حجب حسابي من البحث',
            subtitle: 'إخفاء حسابك الشخصي من نتائج البحث العامة، بحيث لا يمكن العثور عليك إلا عبر الرابط المباشر.',
            icon: Icons.person_off_outlined,
            value: _hideFromSearch,
            onChanged: (val) {
              setState(() => _hideFromSearch = val);
              _updatePrivacySetting('hideFromSearch', val);
            },
          ),
          
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),

          // تغيير كلمة المرور
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            tileColor: Theme.of(context).cardColor,
            leading: const Icon(Icons.lock_outline, color: AppColors.primary),
            title: Text(context.l10n.changePassword, style: const TextStyle(fontWeight: FontWeight.bold)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ChangePasswordScreen()),
              );
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
