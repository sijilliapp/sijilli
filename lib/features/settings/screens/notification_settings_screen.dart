// 📍 lib/features/settings/screens/notification_settings_screen.dart
// 🔔 شاشة إعدادات الإشعارات

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../notifications/providers/notification_provider.dart';
import 'package:sijilli/l10n/app_localizations.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(context.l10n.notificationSettings),
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Master Switch
              _buildSwitchTile(
                title: context.l10n.enableNotifications,
                subtitle: context.l10n.enableNotificationsDesc,
                value: provider.notifyAll,
                onChanged: (val) => provider.setNotifyAll(val),
                isHeader: true,
              ),
              const Divider(height: 32),

              // Categories
              _buildSectionHeader(context.l10n.customizeNotifications),
              
              _buildSwitchTile(
                title: context.l10n.newFollowersDesc, // Same key context used as title
                subtitle: context.l10n.notifyFollowsDesc,
                value: provider.notifyFollows,
                enabled: provider.notifyAll,
                onChanged: (val) => provider.setNotifyFollows(val),
              ),

              _buildSwitchTile(
                title: context.l10n.invitesAndUpdatesDesc, // Same concept
                subtitle: context.l10n.notifyInvitesDesc,
                value: provider.notifyInvites,
                enabled: provider.notifyAll,
                onChanged: (val) => provider.setNotifyInvites(val),
              ),

              _buildSwitchTile(
                title: context.l10n.appointmentAlertsDesc,
                subtitle: context.l10n.notifyActiveDesc,
                value: provider.notifyActive,
                enabled: provider.notifyAll,
                onChanged: (val) => provider.setNotifyActive(val),
              ),

              if (provider.notifyActive && provider.notifyAll)
                Padding(
                  padding: const EdgeInsets.only(right: 24.0), // Tree indentation
                  child: _buildSwitchTile(
                    title: context.l10n.reminderOneDayBefore,
                    subtitle: context.l10n.notifyOneDayBeforeDesc,
                    value: provider.notifyOneDayBefore,
                    enabled: true,
                    onChanged: (val) => provider.setNotifyOneDayBefore(val),
                    isSubItem: true,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
    bool isHeader = false,
    bool isSubItem = false,
  }) {
    return Card(
      elevation: isHeader ? 2 : 0,
      color: isHeader ? Colors.white : (isSubItem ? Colors.grey.shade50 : Colors.white),
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSubItem 
            ? BorderSide(color: Colors.grey.shade200) 
            : BorderSide.none,
      ),
      child: SwitchListTile(
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isHeader ? FontWeight.bold : FontWeight.w500,
            color: enabled ? Colors.black87 : Colors.grey,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: enabled ? Colors.grey.shade600 : Colors.grey.shade400,
                ),
              )
            : null,
        value: value,
        onChanged: enabled ? onChanged : null,
        activeColor: AppColors.primary,
        contentPadding: EdgeInsets.only(
          right: isSubItem ? 16 : 16, 
          left: 16
        ),
        secondary: isSubItem 
            ? Icon(Icons.subdirectory_arrow_right, color: Colors.grey.shade400, size: 20)
            : null,
      ),
    );
  }
}
