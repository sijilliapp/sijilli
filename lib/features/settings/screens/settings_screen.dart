// 📍 lib/features/settings/screens/settings_screen.dart
// ⚙️ شاشة الإعدادات

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/providers/theme_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../appointments/screens/archive_trash_screen.dart';
import 'profile_screen.dart';
import 'blocked_users_screen.dart';
import '../../auth/screens/privacy_policy_screen.dart';
import 'notification_settings_screen.dart';
import '../../../core/providers/locale_provider.dart';
import 'package:sijilli/l10n/app_localizations.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/extensions/context_l10n.dart';

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
        padding: const EdgeInsets.all(16),
        children: [
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
          const SizedBox(height: 12),

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
          const SizedBox(height: 12),

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
          const SizedBox(height: 12),

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
          const SizedBox(height: 12),
          
          // المحذوفات والأرشيف
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1)),
            ),
            color: Theme.of(context).cardColor,
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
              ),
              title: Text(
                context.l10n.trash,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Tajawal',
                  color: AppColors.error,
                ),
              ),
              subtitle: Text(
                context.l10n.manageArchiveTrash,
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
              trailing: Icon(
                Icons.arrow_forward_ios, 
                size: 16, 
                color: Theme.of(context).dividerColor,
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ArchiveTrashScreen(initialIndex: 1)),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          
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
          const SizedBox(height: 12),
          
          // الخصوصية
          _buildSettingsCard(
            context,
            icon: Icons.privacy_tip_outlined,
            title: context.l10n.privacyAndSecurity,
            subtitle: context.l10n.privacyAndSecurity,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Working on it...'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          const SizedBox(height: 12),

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
          const SizedBox(height: 12),
          
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
          const SizedBox(height: 12),

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
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1)),
      ),
      color: Theme.of(context).cardColor, 
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.primary),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios, 
          size: 16, 
          color: Theme.of(context).dividerColor,
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.logout, color: AppColors.warning),
        title: Text(
          context.l10n.logout,
          style: const TextStyle(
            color: AppColors.warning,
            fontWeight: FontWeight.w500,
          ),
        ),
        onTap: () {
          _showLogoutDialog(context);
        },
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