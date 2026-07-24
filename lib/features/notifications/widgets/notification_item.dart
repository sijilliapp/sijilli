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
        trailing: null, // Red dot is strictly for actionable invitations that require a response
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
        final isLike = notification.title == 'إعجابات' || notification.message.contains('إعجاب');
        final isComment = notification.title == 'تعليقات' || notification.message.contains('تعليق') || notification.message.contains('علق');
        if (isLike) {
          icon = Icons.favorite;
          color = Colors.red;
        } else if (isComment) {
          icon = Icons.comment;
          color = Colors.blue;
        } else {
          icon = Icons.info_outline;
          color = AppColors.primary;
        }
        break;
      case NotificationType.follow:
        icon = Icons.person_add_alt_1;
        color = Colors.blue;
        break;
      case NotificationType.approvalRequest:
        icon = Icons.rule;
        color = Colors.purple;
        break;
      case NotificationType.visit:
        icon = Icons.visibility_outlined;
        color = Colors.teal;
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
    final titleLower = originalTitle.toLowerCase();
    if (originalTitle == 'اعتماد جديد' || titleLower.contains('new follow') || titleLower.contains('new accreditation')) {
       return context.l10n.newFollowerTitle; 
    }
    if (originalTitle == 'طلب اعتماد' || titleLower.contains('follow request') || titleLower.contains('accredit request')) {
       return context.l10n.followRequestTitle;
    }
    if (originalTitle == 'تراجع عن الاعتماد' || originalTitle == 'إلغاء الاعتماد' || titleLower.contains('unfollow') || titleLower.contains('unaccredit')) {
       return context.l10n.unfollowedTitle;
    }
    if (originalTitle == 'زيارة جديدة للملف الشخصي' || originalTitle == 'زيارة ملف شخصي' || originalTitle == 'زيارة جديدة' || titleLower.contains('profile visit')) {
       return context.l10n.newProfileVisitTitle;
    }
    if (originalTitle == 'زيارة جديدة لمقالك' || titleLower.contains('article visit')) {
       return context.l10n.newArticleVisitTitle;
    }
    if (originalTitle == 'توافد الجمهور' || originalTitle.contains('توافد') || originalTitle.contains('جمهور')) {
       // Check message to determine if it is a profile or article visit
       return context.l10n.newProfileVisitTitle;
    }
    if (originalTitle == 'اعتماد متبادل' || titleLower.contains('mutual')) {
       return context.l10n.mutualAccreditationTitle;
    }
    if (originalTitle == 'إعجابات' || titleLower.contains('like')) {
       return context.l10n.likesTitle;
    }
    if (originalTitle == 'تعليقات' || titleLower.contains('comment')) {
       return context.l10n.commentsTitle;
    }
    return originalTitle;
  }

  // Intercept messages based on title pattern
  String _getLocalizedMessage(String originalTitle, String originalMessage, BuildContext context) {
    final words = originalMessage.trim().split(RegExp(r'\s+'));
    if (words.isEmpty || words.first.isEmpty) return originalMessage;
    final namePart = words.first;

    final titleLower = originalTitle.toLowerCase();
    final msgLower = originalMessage.toLowerCase();

    // Accredit / Follow requests
    if (originalTitle == 'اعتماد جديد' || titleLower.contains('new follow') || titleLower.contains('new accreditation')) {
       return context.l10n.startedFollowingYou(namePart);
    }
    if (originalTitle == 'طلب اعتماد' || titleLower.contains('follow request') || titleLower.contains('accredit request')) {
       return context.l10n.wantsToFollowYou(namePart);
    }
    if (originalTitle == 'تراجع عن الاعتماد' || originalTitle == 'إلغاء الاعتماد' || titleLower.contains('unfollow') || titleLower.contains('unaccredit')) {
       return context.l10n.unfollowedMessage(namePart);
    }

    // Mutual Accreditations
    if (originalTitle == 'اعتماد متبادل' || titleLower.contains('mutual')) {
       final mutualRegex = RegExp(r'(.+?)\s+قام\s+باعتمادك');
       final match = mutualRegex.firstMatch(originalMessage);
       if (match != null) {
          return context.l10n.mutualAccreditedYou(match.group(1)!.trim());
       }
       return context.l10n.mutualAccreditedYou(namePart);
    }

    // Profile & Article Visits (including توافد الجمهور)
    if (originalTitle == 'زيارة جديدة للملف الشخصي' || 
        originalTitle == 'زيارة ملف شخصي' || 
        originalTitle == 'زيارة جديدة' || 
        originalTitle == 'توافد الجمهور' || 
        titleLower.contains('profile visit') || 
        titleLower.contains('audience visit')) {
       
       final readRegex = RegExp(r'قام\s+(.+?)\s+بقراءة\s+مقالك');
       final browseRegex = RegExp(r'قام\s+(.+?)\s+بتصفح\s+ملفك');

       final readMatch = readRegex.firstMatch(originalMessage);
       if (readMatch != null) {
          return context.l10n.readerReadYourArticle(readMatch.group(1)!.trim());
       }

       final browseMatch = browseRegex.firstMatch(originalMessage);
       if (browseMatch != null) {
          return context.l10n.visitedYourProfile(browseMatch.group(1)!.trim());
       }

       if (namePart == 'شخص' || namePart == 'قام' || namePart == 'أحد' || namePart == 'Someone' || namePart == 'A') {
          return context.l10n.newProfileVisitMessage;
       }
       return context.l10n.visitedYourProfile(namePart);
    }
    if (originalTitle == 'زيارة جديدة لمقالك' || titleLower.contains('article visit')) {
       return context.l10n.newArticleVisitMessage;
    }

    // Likes & Comments
    if (originalTitle == 'إعجابات' || titleLower.contains('like') || msgLower.contains('إعجاب') || msgLower.contains('أعجب')) {
       return context.l10n.likedYourArticle(namePart);
    }
    if (originalTitle == 'تعليقات' || titleLower.contains('comment') || msgLower.contains('علق') || msgLower.contains('تعليق')) {
       return context.l10n.commentedOnYourArticle(namePart);
    }

    return originalMessage;
  }
}
