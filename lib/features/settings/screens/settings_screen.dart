// 📍 lib/features/settings/screens/settings_screen.dart
// ⚙️ شاشة الإعدادات

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/theme_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../appointments/screens/archive_trash_screen.dart';
import 'profile_screen.dart';
import 'blocked_users_screen.dart';
import '../../auth/screens/privacy_policy_screen.dart';
import 'notification_settings_screen.dart';
import 'privacy_settings_screen.dart';
import '../../admin/screens/super_admin_screen.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../auth/screens/change_password_screen.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';

import 'package:sijilli/features/appointments/screens/saved_appointments_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.settings),
        centerTitle: true,
        backgroundColor: isDark ? null : AppColors.primary,
        foregroundColor: isDark ? null : Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          // لوحة تحكم المشرف العام (تظهر فقط للمشرف)
          Consumer<AuthProvider>(
            builder: (context, auth, _) {
              if (auth.user?.role != 'admin') return const SizedBox.shrink();
              final isAmberDark = Theme.of(context).brightness == Brightness.dark;
              return Column(
                children: [
                  Card(
                    margin: EdgeInsets.zero,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: Colors.amber.shade800.withValues(alpha: 0.2),
                        width: 1.5,
                      ),
                    ),
                    color: isAmberDark 
                        ? Colors.amber.shade900.withValues(alpha: 0.1) 
                        : Colors.amber.shade50.withValues(alpha: 0.3),
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const SuperAdminScreen()),
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade800.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.amber.shade800.withValues(alpha: 0.05),
                                  width: 1,
                                ),
                              ),
                              child: Icon(Icons.admin_panel_settings_rounded, color: Colors.amber.shade800, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    context.l10n.adminPanelTitle,
                                    style: TextStyle(
                                      color: isAmberDark ? Colors.amber.shade300 : Colors.amber.shade900,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 17,
                                      letterSpacing: -0.5,
                                      height: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    context.l10n.adminPanelDesc,
                                    style: TextStyle(
                                      color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                                      fontSize: 12,
                                      height: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(
                              Icons.arrow_forward_ios, 
                              size: 14, 
                              color: Colors.amber.shade800,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              );
            },
          ),
          // تعديل البروفايل
          _buildSettingsCard(
            context,
            icon: Icons.person_outlined,
            title: context.l10n.editProfile,
            subtitle: context.l10n.editProfileSubtitle,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
          const SizedBox(height: 8),

          // الخصوصية والأمان
          _buildSettingsCard(
            context,
            icon: Icons.privacy_tip_outlined,
            title: context.l10n.privacyAndSecurity,
            subtitle: context.l10n.privacyAndSecurity,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PrivacySettingsScreen()),
              );
            },
          ),
          const SizedBox(height: 8),

          // تخصيص المظهر (الوضع الليلي)
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) {
              String modeLabel;
              switch (themeProvider.currentTheme) {
                case 'dark': modeLabel = context.l10n.themeModeDark; break;
                case 'light': modeLabel = context.l10n.themeModeLight; break;
                default: modeLabel = context.l10n.themeModeSystem;
              }
              return _buildSettingsCard(
                context,
                icon: Icons.brightness_6_outlined,
                title: context.l10n.appAppearance,
                subtitle: modeLabel,
                onTap: () => _showThemeSelectionDialog(context),
              );
            },
          ),
          const SizedBox(height: 8),

          // تخصيص المظهر (الخطوط)
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) {
              return _buildSettingsCard(
                context,
                icon: Icons.font_download_outlined,
                title: context.l10n.fontStyle,
                subtitle: themeProvider.fontFamily == 'Default' ? context.l10n.defaultFontStyle : themeProvider.fontFamily,
                onTap: () {
                  _showFontSelectionDialog(context);
                },
              );
            },
          ),
          const SizedBox(height: 8),
          
          // الرئيسية المغناطيسية
          Consumer<SettingsProvider>(
            builder: (context, settings, _) {
              return _buildSwitchCard(
                context,
                icon: Icons.auto_mode_outlined,
                title: context.l10n.magneticHome,
                subtitle: context.l10n.magneticHomeDesc,
                value: settings.isMagneticScrollEnabled,
                onChanged: (val) => settings.setMagneticScrollEnabled(val),
              );
            },
          ),
          const SizedBox(height: 8),

          // لغة التطبيق
          Consumer<LocaleProvider>(
            builder: (context, localeProvider, _) {
              return _buildSettingsCard(
                context,
                icon: Icons.language_outlined,
                title: context.l10n.appLanguage,
                subtitle: localeProvider.isArabic ? 'العربية' : 'English',
                onTap: () => _showLanguageSelectionDialog(context),
              );
            },
          ),
          const SizedBox(height: 8),
          
          const SizedBox(height: 8),
          
          // المحذوفات والأرشيف
          Card(
            margin: EdgeInsets.zero,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: AppColors.error.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            color: isDark ? AppColors.error.withValues(alpha: 0.05) : Colors.red.shade50.withValues(alpha: 0.3),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ArchiveTrashScreen(initialIndex: 1)),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.error.withValues(alpha: 0.15),
                            AppColors.error.withValues(alpha: 0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.1),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.delete_sweep_rounded, 
                        color: AppColors.error,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            context.l10n.trash,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: AppColors.error,
                              letterSpacing: -0.5,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            context.l10n.manageArchiveTrash,
                            style: TextStyle(
                              color: AppColors.error.withValues(alpha: 0.7),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.arrow_forward_ios, 
                      size: 16, 
                      color: Theme.of(context).dividerColor,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          
          // الإشعارات
          _buildSettingsCard(
            context,
            icon: Icons.notifications_outlined,
            title: context.l10n.notificationSettings,
            subtitle: context.l10n.notificationSettings,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NotificationSettingsScreen()),
              );
            },
          ),
          const SizedBox(height: 8),

          // قائمة الحظر
          _buildSettingsCard(
            context,
            icon: Icons.block_flipped,
            title: context.l10n.blockedUsers,
            subtitle: context.l10n.blockedUsers,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BlockedUsersScreen()),
              );
            },
          ),
          const SizedBox(height: 8),
          
          // حول التطبيق
          _buildSettingsCard(
            context,
            icon: Icons.info_outlined,
            title: context.l10n.aboutApp,
            subtitle: context.l10n.aboutApp,
            onTap: () {
              _showAboutDialog(context);
            },
          ),
          const SizedBox(height: 8),

          // الشروط والأحكام
          _buildSettingsCard(
            context,
            icon: Icons.description_outlined,
            title: context.l10n.termsAndConditions,
            subtitle: context.l10n.termsAndConditions,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PrivacyPolicyScreen()),
              );
            },
          ),
          const SizedBox(height: 24),
          
          // تسجيل الخروج
          _buildLogoutButton(context),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
      ),
      color: Theme.of(context).cardColor, 
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    width: 1,
                  ),
                ),
                child: Icon(icon, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                        letterSpacing: -0.5,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                        fontSize: 12,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
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

  Widget _buildSwitchCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
      ),
      color: Theme.of(context).cardColor, 
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    width: 1,
                  ),
                ),
                child: Icon(icon, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                        letterSpacing: -0.5,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                        fontSize: 12,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Switch(
                value: value,
                onChanged: onChanged,
                activeColor: AppColors.primary,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
      ),
      color: Theme.of(context).cardColor, 
      child: InkWell(
        onTap: () {
          _showLogoutDialog(context);
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.05),
                    width: 1,
                  ),
                ),
                child: const Icon(Icons.logout_rounded, color: AppColors.warning, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.l10n.logout,
                      style: const TextStyle(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                        letterSpacing: -0.5,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
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

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: context.l10n.appName,
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(
        Icons.calendar_today,
        size: 48,
        color: AppColors.primary,
      ),
      children: [
        const Text('Sijilli - Professional Appointment Management'),
      ],
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.logout),
        content: Text(context.l10n.confirmLogout),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Provider.of<AuthProvider>(context, listen: false).logout();
            },
            child: Text(
              context.l10n.logout,
              style: const TextStyle(color: AppColors.warning),
            ),
          ),
        ],
      ),
    );
  }

  void _showLanguageSelectionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(context.l10n.selectLanguage),
          content: Consumer<LocaleProvider>(
            builder: (context, provider, _) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<Locale>(
                    title: const Text('العربية'),
                    value: const Locale('ar'),
                    groupValue: provider.locale,
                    activeColor: AppColors.primary,
                    onChanged: (val) {
                      provider.setLocale(val!);
                      Navigator.pop(context);
                    },
                  ),
                  RadioListTile<Locale>(
                    title: const Text('English'),
                    value: const Locale('en'),
                    groupValue: provider.locale,
                    activeColor: AppColors.primary,
                    onChanged: (val) {
                      provider.setLocale(val!);
                      Navigator.pop(context);
                    },
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.cancel),
            ),
          ],
        );
      },
    );
  }

  void _showFontSelectionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
        return AlertDialog(
          title: Text(context.l10n.fontStyle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: themeProvider.availableFonts.map((font) {
                return RadioListTile<String>(
                  title: Text(
                    font == 'Default' ? context.l10n.defaultFontStyle : font,
                    style: TextStyle(fontFamily: font == 'Default' ? null : font),
                  ),
                  value: font,
                  groupValue: themeProvider.fontFamily,
                  activeColor: AppColors.primary,
                  onChanged: (value) {
                     if (value != null) {
                       themeProvider.setFontFamily(value);
                       Navigator.pop(context);
                     }
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.cancel),
            ),
          ],
        );
      },
    );
  }

  void _showThemeSelectionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(context.l10n.appAppearance),
          content: Consumer<ThemeProvider>(
            builder: (context, provider, _) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   RadioListTile<String>(
                     title: const Text('Auto'),
                     secondary: const Icon(Icons.wb_twilight, color: Colors.orange),
                     value: 'auto',
                     groupValue: provider.currentTheme,
                     activeColor: AppColors.primary,
                     onChanged: (val) {
                       provider.setThemeMode(val!);
                       Navigator.pop(context);
                     },
                   ),
                   RadioListTile<String>(
                     title: const Text('Light'),
                     secondary: const Icon(Icons.wb_sunny_outlined, color: Colors.amber),
                     value: 'light',
                     groupValue: provider.currentTheme,
                     activeColor: AppColors.primary,
                     onChanged: (val) {
                       provider.setThemeMode(val!);
                       Navigator.pop(context);
                     },
                   ),
                   RadioListTile<String>(
                     title: const Text('Dark'),
                     secondary: const Icon(Icons.dark_mode_outlined, color: Colors.blueGrey),
                     value: 'dark',
                     groupValue: provider.currentTheme,
                     activeColor: AppColors.primary,
                     onChanged: (val) {
                       provider.setThemeMode(val!);
                       Navigator.pop(context);
                     },
                   ),
                ],
              );
            },
          ),
          actions: [
             TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.cancel)),
          ],
        );
      },
    );
  }
}