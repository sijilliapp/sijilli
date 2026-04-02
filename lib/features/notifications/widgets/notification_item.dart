import 'package:flutter/material.dart';
import 'package:sijilli/core/constants/app_colors.dart';
import '../../../../models/notification.dart';
import 'package:sijilli/core/utils/app_date_formatter.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';

class NotificationItem extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;

  const NotificationItem({
    super.key,
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: notification.isRead 
            ? (isDark ? const Color(0xFF1E1E1E) : Colors.white)
            : (isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF0F7FF)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: _buildIcon(context),
        title: Text(
          _getLocalizedTitle(notification.title, context),
          style: TextStyle(
            fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              _getLocalizedMessage(notification.title, notification.message, context),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              AppDateFormatter.timeAgo(notification.created, context.l10n.localeName, context.l10n),
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
              ),
            ),
          ],
        ),
        trailing: !notification.isRead
            ? Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildIcon(BuildContext context) {
    IconData icon;
    Color color;

    switch (notification.type) {
      case NotificationType.reminder:
        icon = Icons.alarm;
        color = Colors.orange;
        break;
      case NotificationType.cancel:
        icon = Icons.event_busy;
        color = Colors.red;
        break;
      case NotificationType.system:
        icon = Icons.info_outline;
        color = AppColors.primary;
        break;
      case NotificationType.follow:
        icon = Icons.person_add_alt_1;
        color = Colors.blue;
        break;
      case NotificationType.approvalRequest:
        icon = Icons.rule;
        color = Colors.purple;
        break;
      default:
        icon = Icons.notifications;
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  // Intercept titles from backend
  String _getLocalizedTitle(String originalTitle, BuildContext context) {
    if (originalTitle == 'اعتماد جديد' || originalTitle.toLowerCase().contains('new follow')) {
       return context.l10n.newFollowerTitle; 
    }
    if (originalTitle == 'طلب اعتماد' || originalTitle.toLowerCase().contains('follow request')) {
       return context.l10n.followRequestTitle;
    }
    return originalTitle;
  }

  // Intercept messages based on title pattern
  String _getLocalizedMessage(String originalTitle, String originalMessage, BuildContext context) {
    if (originalTitle == 'اعتماد جديد' || originalTitle == 'طلب اعتماد') {
       final namePart = originalMessage.split(' ').first; // Extract "Ammar" from "Ammar بدأ باغتمادك"
       if (originalTitle == 'اعتماد جديد') {
          return context.l10n.startedFollowingYou(namePart);
       } else {
          return context.l10n.wantsToFollowYou(namePart);
       }
    }
    return originalMessage;
  }
}
