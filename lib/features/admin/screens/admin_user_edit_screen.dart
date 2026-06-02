// 📍 lib/features/admin/screens/admin_user_edit_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/app_date_formatter.dart';
import '../../../core/widgets/pulse_avatar.dart';
import '../providers/admin_provider.dart';
import '../../../models/user.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/extensions/context_l10n.dart';

class AdminUserEditScreen extends StatefulWidget {
  final UserModel user;

  const AdminUserEditScreen({super.key, required this.user});

  @override
  State<AdminUserEditScreen> createState() => _AdminUserEditScreenState();
}

class _AdminUserEditScreenState extends State<AdminUserEditScreen> {
  late String _selectedRole;
  late bool _isVerified;
  late bool _phoneVerified;
  late bool _isPublic;
  late bool _hideFromSearch;
  late bool _isSuggested;
  late bool _isSuperAdmin;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    
    // التحقق من الرتبة وتعيين قيمة افتراضية آمنة في حال كانت فارغة أو غير معروفة لمنع انهيار القائمة المنسدلة
    const validRoles = ['user', 'approved', 'admin'];
    if (validRoles.contains(widget.user.role)) {
      _selectedRole = widget.user.role;
    } else {
      _selectedRole = 'user';
    }
    
    // تفعيل وتهيئة الخيارات التفاعلية المباشرة من السيرفر
    _isVerified = widget.user.verified;
    _phoneVerified = widget.user.phoneVerified;
    _isPublic = widget.user.isPublic;
    _hideFromSearch = widget.user.hideFromSearch;
    _isSuggested = widget.user.isSuggested;
    _isSuperAdmin = widget.user.isSuperAdmin;
  }

  void _confirmAndSimulate(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          context.l10n.simulateLogin,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          context.l10n.simulateConfirm(widget.user.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(context.l10n.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade900,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(dialogCtx);
              
              // تفعيل المحاكاة
              context.read<AuthProvider>().simulateUser(widget.user);
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.l10n.loginSimulated(widget.user.name)),
                  backgroundColor: Colors.amber.shade900,
                ),
              );
              
              // العودة للواجهة الرئيسية الأولى
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: Text(context.l10n.login),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          context.l10n.editUserAccount,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 💳 كارت هوية المشترك العلوي
                  _buildUserHeaderCard(isDark),
                  
                  const SizedBox(height: 16),
                  
                  // ⚙️ قسم الصلاحيات والأدوار (الأساسي حالياً)
                  _buildSectionTitle(context, context.l10n.permissionsAndControl),
                  const SizedBox(height: 8),
                  _buildRoleCard(isDark),
                  
                  const SizedBox(height: 16),
                  
                  // 🚀 قسم الميزات والخيارات التفاعلية
                  _buildSectionTitle(context, context.l10n.accountOptions),
                  const SizedBox(height: 8),
                  _buildExtensibleOptionsCard(isDark),
                ],
              ),
            ),
            
            // 💾 زر الحفظ السفلي
            _buildSaveButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildUserHeaderCard(bool isDark) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          width: 1,
        ),
      ),
      color: isDark ? AppColors.darkSurface : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            PulseAvatar(
              image: widget.user.getAvatarUrl('https://sijilli.pockethost.io') != null
                  ? NetworkImage(widget.user.getAvatarUrl('https://sijilli.pockethost.io')!)
                  : null,
              size: 56,
              status: AvatarStatus.none,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.user.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '@${widget.user.username}',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 14,
                        color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          context.l10n.joinedSince(AppDateFormatter.formatMediumDate(widget.user.joiningDate, Localizations.localeOf(context).languageCode)),
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade900,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.login_rounded, size: 14),
              label: Text(
                context.l10n.simulateLogin,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onPressed: () => _confirmAndSimulate(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildRoleCard(bool isDark) {
    final roleOptions = [
      {'key': 'user', 'label': context.l10n.roleUserOption},
      {'key': 'approved', 'label': context.l10n.roleApprovedOption},
      {'key': 'admin', 'label': context.l10n.roleAdminOption},
    ];

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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.userRoleLabel,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedRole,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  ),
                ),
                filled: true,
                fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
              ),
              items: roleOptions.map((opt) {
                return DropdownMenuItem<String>(
                  value: opt['key'],
                  child: Text(
                    opt['label']!,
                    style: const TextStyle(fontSize: 14),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedRole = val;
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /// ⚙️ كارت خيارات الحساب التفاعلية المباشرة:
  /// قمنا بتفعيلها بالكامل لتسمح لك بتغييرها وحفظها في قاعدة البيانات فوراً!
  Widget _buildExtensibleOptionsCard(bool isDark) {
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            // 📧 توثيق البريد الإلكتروني
            _buildInteractiveSwitchRow(
              icon: Icons.verified_user_outlined,
              title: context.l10n.verifiedEmailLabel,
              subtitle: context.l10n.verifiedEmailDesc,
              value: _isVerified,
              onChanged: (val) {
                setState(() {
                  _isVerified = val;
                });
              },
            ),
            
            const Divider(height: 1),
            
            // 📱 توثيق رقم الهاتف
            _buildInteractiveSwitchRow(
              icon: Icons.phone_android_outlined,
              title: context.l10n.verifiedPhoneLabel,
              subtitle: context.l10n.verifiedPhoneDesc,
              value: _phoneVerified,
              onChanged: (val) {
                setState(() {
                  _phoneVerified = val;
                });
              },
            ),
            
            const Divider(height: 1),
            
            // 🌐 ملف شخصي عام
            _buildInteractiveSwitchRow(
              icon: Icons.public_outlined,
              title: context.l10n.publicProfileLabel,
              subtitle: context.l10n.publicProfileDesc,
              value: _isPublic,
              onChanged: (val) {
                setState(() {
                  _isPublic = val;
                });
              },
            ),
            
            const Divider(height: 1),
            
            // 👁️ إخفاء الحساب من البحث
            _buildInteractiveSwitchRow(
              icon: Icons.visibility_off_outlined,
              title: context.l10n.hideFromSearchLabel,
              subtitle: context.l10n.hideFromSearchDesc,
              value: _hideFromSearch,
              onChanged: (val) {
                setState(() {
                  _hideFromSearch = val;
                });
              },
            ),
            
            const Divider(height: 1),
            
            // 📢 اقتراح الحساب للمستخدمين
            _buildInteractiveSwitchRow(
              icon: Icons.star_outline_rounded,
              title: context.l10n.suggestedAccountLabel,
              subtitle: context.l10n.suggestedAccountDesc,
              value: _isSuggested,
              onChanged: (val) {
                setState(() {
                  _isSuggested = val;
                });
              },
            ),

            // 🛡️ ترقية لمشرف عام (Super Admin) - لا تظهر إلا للمشرف العام
            if (context.read<AuthProvider>().user?.isSuperAdmin == true) ...[
              const Divider(height: 1),
              _buildInteractiveSwitchRow(
                icon: Icons.shield_outlined,
                title: context.l10n.superAdminLabel,
                subtitle: context.l10n.superAdminDesc,
                value: _isSuperAdmin,
                onChanged: (val) {
                  setState(() {
                    _isSuperAdmin = val;
                  });
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInteractiveSwitchRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        onPressed: _isSaving ? null : () => _saveChanges(context),
        child: _isSaving
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Text(
                context.l10n.saveChangesBtn,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Future<void> _saveChanges(BuildContext context) async {
    setState(() {
      _isSaving = true;
    });

    // تجميع كافة الحقول المعدلة لإرسالها دفعة واحدة
    final Map<String, dynamic> updatedFields = {
      'role': _selectedRole,
      'verified': _isVerified,
      'phoneVerified': _phoneVerified,
      'isPublic': _isPublic,
      'hideFromSearch': _hideFromSearch,
      'isSuggested': _isSuggested,
      'isSuperAdmin': _isSuperAdmin,
    };

    final success = await context.read<AdminProvider>().updateUserFields(
      widget.user.id,
      updatedFields,
    );

    if (mounted) {
      setState(() {
        _isSaving = false;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.saveChangesSuccess),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.saveChangesFailed),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
