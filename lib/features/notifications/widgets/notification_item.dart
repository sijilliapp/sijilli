import 'package:flutter/material.dart';
import 'package:sijilli/core/constants/app_colors.dart';
import '../../../../models/notification.dart';
import 'package:sijilli/core/utils/app_date_formatter.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';
import 'package:sijilli/features/settings/services/pb_user_service.dart';
import 'package:sijilli/features/home/screens/public_profile_screen.dart';
import 'package:sijilli/models/user.dart';

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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SenderAvatar(
                userId: notification.relatedId,
                notificationType: notification.type,
                notificationTitle: notification.title,
                notificationMessage: notification.message,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _getLocalizedTitle(notification.title, context),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: notification.isRead ? FontWeight.w600 : FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getLocalizedMessage(notification.title, notification.message, context),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                AppDateFormatter.timeAgo(notification.created, context.l10n.localeName, context.l10n),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      ),
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

class SenderAvatar extends StatefulWidget {
  final String userId;
  final NotificationType notificationType;
  final String notificationTitle;
  final String notificationMessage;

  const SenderAvatar({
    super.key,
    required this.userId,
    required this.notificationType,
    required this.notificationTitle,
    required this.notificationMessage,
  });

  @override
  State<SenderAvatar> createState() => _SenderAvatarState();
}

class _SenderAvatarState extends State<SenderAvatar> {
  UserModel? _user;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void didUpdateWidget(SenderAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.userId != oldWidget.userId) {
      _loadUser();
    }
  }

  Future<void> _loadUser() async {
    if (widget.userId.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final user = await PbUserService().getPublicProfile(widget.userId);
      if (mounted) {
        setState(() {
          _user = user;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Widget _buildDefaultAvatar() {
    IconData icon;
    Color color;

    switch (widget.notificationType) {
      case NotificationType.reminder:
        icon = Icons.alarm;
        color = Colors.orange;
        break;
      case NotificationType.cancel:
        icon = Icons.event_busy;
        color = Colors.red;
        break;
      case NotificationType.system:
        final isLike = widget.notificationTitle == 'إعجابات' || widget.notificationMessage.contains('إعجاب');
        final isComment = widget.notificationTitle == 'تعليقات' || widget.notificationMessage.contains('تعليق') || widget.notificationMessage.contains('علق');
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
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return _buildDefaultAvatar();
    }

    final user = _user;
    final avatarUrl = user?.getAvatarUrl('https://sijilli.pockethost.io');
    if (user == null || user.avatar == null || user.avatar!.isEmpty || avatarUrl == null || avatarUrl.isEmpty) {
      return GestureDetector(
        onTap: () {
          if (widget.userId.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => PublicProfileScreen(usernameOrId: widget.userId)),
            );
          }
        },
        child: _buildDefaultAvatar(),
      );
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => PublicProfileScreen(usernameOrId: widget.userId)),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Image.network(
          avatarUrl,
          width: 38,
          height: 38,
          fit: BoxFit.cover,
          errorBuilder: (context, _, __) => _buildDefaultAvatar(),
        ),
      ),
    );
  }
}
