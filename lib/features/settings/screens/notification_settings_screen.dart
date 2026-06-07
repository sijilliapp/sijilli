// 📍 lib/features/settings/screens/notification_settings_screen.dart
// 🔔 شاشة إعدادات الإشعارات

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../notifications/providers/notification_provider.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
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
                context: context,
                title: context.l10n.enableNotifications,
                subtitle: context.l10n.enableNotificationsDesc,
                value: provider.notifyAll,
                onChanged: (val) => provider.setNotifyAll(val),
                isHeader: true,
              ),
              Divider(height: 32, color: AppColors.getBorder(context)),

              // Categories
              _buildSectionHeader(context, context.l10n.customizeNotifications),
              
              _buildSwitchTile(
                context: context,
                title: context.l10n.newFollowersDesc, // Same key context used as title
                subtitle: context.l10n.notifyFollowsDesc,
                value: provider.notifyFollows,
                enabled: provider.notifyAll,
                onChanged: (val) => provider.setNotifyFollows(val),
              ),

              _buildSwitchTile(
                context: context,
                title: context.l10n.invitesAndUpdatesDesc, // Same concept
                subtitle: context.l10n.notifyInvitesDesc,
                value: provider.notifyInvites,
                enabled: provider.notifyAll,
                onChanged: (val) => provider.setNotifyInvites(val),
              ),

              _buildSwitchTile(
                context: context,
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
                    context: context,
                    title: context.l10n.reminderOneDayBefore,
                    subtitle: context.l10n.notifyOneDayBeforeDesc,
                    value: provider.notifyOneDayBefore,
                    enabled: true,
                    onChanged: (val) => provider.setNotifyOneDayBefore(val),
                    isSubItem: true,
                  ),
                ),

              _buildSwitchTile(
                context: context,
                title: context.l10n.notifyBookmarks,
                subtitle: context.l10n.notifyBookmarksDesc,
                value: provider.notifyBookmarks,
                enabled: provider.notifyAll,
                onChanged: (val) => provider.setNotifyBookmarks(val),
              ),

              _buildSwitchTile(
                context: context,
                title: context.l10n.notifyBeforeOffset,
                subtitle: context.l10n.notifyBeforeOffsetDesc,
                value: provider.notifyBeforeOffset,
                enabled: provider.notifyAll,
                onChanged: (val) => provider.setNotifyBeforeOffset(val),
              ),

              if (provider.notifyBeforeOffset && provider.notifyAll)
                Padding(
                  padding: const EdgeInsets.only(right: 24.0), // Tree indentation
                  child: Card(
                    elevation: 0,
                    color: AppColors.getBackground(context),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: AppColors.getBorder(context)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButtonFormField<int>(
                          value: provider.notifyBeforeOffsetMinutes,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          icon: Icon(Icons.arrow_drop_down, color: AppColors.getTextSecondary(context)),
                          dropdownColor: AppColors.getCardBackground(context),
                          items: [
                            DropdownMenuItem(
                              value: 10,
                              child: Text(
                                context.l10n.minutes10,
                                style: TextStyle(color: AppColors.getTextPrimary(context)),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 15,
                              child: Text(
                                context.l10n.minutes15,
                                style: TextStyle(color: AppColors.getTextPrimary(context)),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 30,
                              child: Text(
                                context.l10n.minutes30,
                                style: TextStyle(color: AppColors.getTextPrimary(context)),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 60,
                              child: Text(
                                context.l10n.hour1,
                                style: TextStyle(color: AppColors.getTextPrimary(context)),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 120,
                              child: Text(
                                context.l10n.hours2,
                                style: TextStyle(color: AppColors.getTextPrimary(context)),
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              provider.setNotifyBeforeOffsetMinutes(val);
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ),

              _buildSwitchTile(
                context: context,
                title: context.l10n.readerInflux,
                subtitle: context.l10n.notifyReaderInfluxDesc,
                value: provider.notifyVisits,
                enabled: provider.notifyAll,
                onChanged: (val) => provider.setNotifyVisits(val),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.getTextSecondary(context),
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required BuildContext context,
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
      color: isHeader 
          ? AppColors.getCardBackground(context) 
          : (isSubItem ? AppColors.getBackground(context) : AppColors.getCardBackground(context)),
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSubItem 
            ? BorderSide(color: AppColors.getBorder(context)) 
            : BorderSide.none,
      ),
      child: SwitchListTile(
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isHeader ? FontWeight.bold : FontWeight.w500,
            color: enabled 
                ? AppColors.getTextPrimary(context) 
                : AppColors.getTextSecondary(context).withOpacity(0.5),
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: enabled 
                      ? AppColors.getTextSecondary(context) 
                      : AppColors.getTextSecondary(context).withOpacity(0.5),
                ),
              )
            : null,
        value: value,
        onChanged: enabled ? onChanged : null,
        activeThumbColor: AppColors.primary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        secondary: isSubItem 
            ? Icon(Icons.subdirectory_arrow_right, color: AppColors.getTextSecondary(context), size: 20)
            : null,
      ),
    );
  }
}
