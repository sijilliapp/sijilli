import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../models/article.dart';
import '../../../models/appointment.dart';
import '../../../models/tag.dart';
import '../providers/article_provider.dart';
import '../../auth/providers/auth_provider.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/widgets/sheets/app_action_sheet.dart';
import '../../profile/providers/moderation_provider.dart';
import 'tag_selector_sheet.dart';
import '../../appointments/widgets/atomic/interaction_capsule.dart';


class ArticleCard extends StatelessWidget {
  final Article article;
  final VoidCallback onTap;

  const ArticleCard({
    super.key,
    required this.article,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final currentUser = authProvider.user;
    final currentUserId = currentUser?.id;
    final isAuthor = currentUserId == article.authorId;
    final isCopyDisabled = isAuthor
        ? (currentUser?.disableCopying == true)
        : (article.author?.disableCopying == true);
    final commentsCount = context.watch<ArticleProvider>().getCommentsForArticle(article.id).length;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isTrash = article.postStatus == PostStatus.trash;
    final isArchived = article.postStatus == PostStatus.archived;
    final isDraft = article.postStatus == PostStatus.draft;

    Color cardBgColor;

    if (isDark) {
      cardBgColor = AppColors.darkCardBackground;
    } else {
      if (isTrash) {
        cardBgColor = AppColors.warningLight.withValues(alpha: 0.12);
      } else if (isArchived) {
        cardBgColor = Colors.blue.shade50;
      } else if (isDraft) {
        cardBgColor = const Color(0xFFF3F4F6);
      } else {
        cardBgColor = AppColors.appointmentCardBackground; // Crisp light blue
      }
    }
    final borderColor = isDark ? Colors.grey.shade700 : Colors.grey.shade400;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 4.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.35) : Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: borderColor,
              width: 1.0,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            onLongPress: () {
              final articleProvider = context.read<ArticleProvider>();
              AppActionSheet.show(
                context,
                actions: [
                  if (article.postStatus == PostStatus.trash) ...[
                    AppActionItem(
                      label: 'استعادة المقال',
                      icon: Icons.restore_from_trash_outlined,
                      onTap: () async {
                        await articleProvider.restoreArticle(article.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم استعادة المقال بنجاح 🔄')),
                          );
                        }
                      },
                    ),
                    AppActionItem(
                      label: 'حذف نهائي',
                      icon: Icons.delete_forever_outlined,
                      isDestructive: true,
                      onTap: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            title: const Text('حذف المقال نهائياً'),
                            content: Text('هل أنت متأكد من حذف مقال "${article.title}" بشكل نهائي؟ لا يمكن التراجع عن هذا الإجراء.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(context.l10n.cancel)),
                              TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('حذف نهائي', style: TextStyle(color: Colors.red))),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await articleProvider.hardDeleteArticle(article.id);
                        }
                      },
                    ),
                  ] else if (article.postStatus == PostStatus.archived) ...[
                    AppActionItem(
                      label: 'إلغاء الأرشفة',
                      icon: Icons.unarchive_outlined,
                      onTap: () async {
                        await articleProvider.toggleArchiveArticle(article.id, false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم إلغاء أرشفة المقال بنجاح 📂')),
                          );
                        }
                      },
                    ),
                    AppActionItem(
                      label: context.l10n.delete,
                      icon: Icons.delete_outline,
                      isDestructive: true,
                      onTap: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            title: Text(context.l10n.confirmDeleteArticle),
                            content: Text(context.l10n.confirmDeleteArticleMsg(article.title)),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(context.l10n.cancel)),
                              TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(context.l10n.delete, style: const TextStyle(color: Colors.red))),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await articleProvider.deleteArticle(article.id);
                        }
                      },
                    ),
                  ] else ...[
                    if (isAuthor) ...[
                      if (article.isPublished)
                        AppActionItem(
                          label: 'إلغاء المشاركة',
                          icon: Icons.unpublished_outlined,
                          isDestructive: true,
                          onTap: () async {
                            articleProvider.togglePublishStatus(article.id, false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('تم إلغاء نشر المقال وإيقاف المشاركة 🛑'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                        )
                      else
                        AppActionItem(
                          label: 'مشاركة ونشر المقال',
                          icon: Icons.share,
                          onTap: () async {
                            final username = article.author?.username ?? 'user';
                            final url = 'https://sijilli.com/$username/${article.id}';
                            
                            if (!article.isPublished) {
                              articleProvider.togglePublishStatus(article.id, true);
                            }

                            if (kIsWeb) {
                              await Clipboard.setData(ClipboardData(text: url));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('تم نسخ رابط المقال إلى الحافظة ونشره تلقائياً 🚀'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            } else {
                              await Share.share(url, subject: article.title);
                            }
                          },
                        ),
                      AppActionItem(
                        label: 'أرشفة المقال',
                        icon: Icons.archive_outlined,
                        onTap: () async {
                          await articleProvider.toggleArchiveArticle(article.id, true);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم أرشفة المقال بنجاح 📦')),
                            );
                          }
                        },
                      ),
                    ] else if (article.isPublished)
                      AppActionItem(
                        label: 'مشاركة المقال',
                        icon: Icons.share,
                        onTap: () async {
                          final username = article.author?.username ?? 'user';
                          final url = 'https://sijilli.com/$username/${article.id}';

                          if (kIsWeb) {
                            await Clipboard.setData(ClipboardData(text: url));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('تم نسخ رابط المشاركة إلى الحافظة 🔗'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } else {
                            await Share.share(url, subject: article.title);
                          }
                        },
                      ),
                    AppActionItem(
                      label: isCopyDisabled ? 'النسخ مقفل' : context.l10n.copy,
                      icon: isCopyDisabled ? Icons.lock_outline : Icons.copy,
                      onTap: () async {
                        if (isCopyDisabled) {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              content: const Text(
                                'قام الكاتب بتعطيل نسخ المقال.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('موافق'),
                                ),
                              ],
                            ),
                          );
                        } else {
                          await Clipboard.setData(ClipboardData(text: article.pureText));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(context.l10n.articleCopied(article.title))),
                            );
                          }
                        }
                      },
                    ),
                    if (isAuthor || context.read<AuthProvider>().user?.isAdmin == true)
                      AppActionItem(
                        label: context.l10n.delete,
                        icon: Icons.delete_outline,
                        isDestructive: true,
                        onTap: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              title: Text(context.l10n.confirmDeleteArticle),
                              content: Text(context.l10n.confirmDeleteArticleMsg(article.title)),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(context.l10n.cancel)),
                                TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(context.l10n.delete, style: const TextStyle(color: Colors.red))),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await articleProvider.deleteArticle(article.id);
                          }
                        },
                      )
                    else
                      AppActionItem(
                        label: context.l10n.report,
                        icon: Icons.report_problem_outlined,
                        isDestructive: true,
                        onTap: () async {
                          final reason = await showDialog<String>(
                            context: context,
                            builder: (context) {
                              final controller = TextEditingController();
                              return AlertDialog(
                                title: Text(context.l10n.report),
                                content: TextField(
                                  controller: controller,
                                  decoration: InputDecoration(hintText: context.l10n.reportReason),
                                  maxLines: 3,
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.cancel)),
                                  TextButton(onPressed: () => Navigator.pop(context, controller.text), child: Text(context.l10n.send)),
                                ],
                              );
                            },
                          );
                          if (reason != null && reason.isNotEmpty && context.mounted) {
                            await context.read<ModerationProvider>().reportContent(
                              subjectType: 'article',
                              subjectId: article.id,
                              reason: reason,
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.reportSent)));
                            }
                          }
                        },
                      ),
                  ]
                ],
              );
            },
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                // 1. Transparent Background Image
                if (article.image != null && article.image!.isNotEmpty)
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.1,
                      child: Image.network(
                        _getImageUrl(article),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox(),
                      ),
                    ),
                  ),
                // 2. Content
                Padding(
                  padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 4.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Row: Title and status capsule combined in the same row
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 0.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                article.title.isNotEmpty ? article.title : 'بدون عنوان',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85),
                                  height: 1.2,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isAuthor && article.postStatus != PostStatus.written) ...[
                              const SizedBox(width: 12),
                              _buildStatusCapsule(context, article.postStatus),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      
                      // Footer: Metadata & Interaction (Plain text and icons, no capsules)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(0.0, 0, 0.0, 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: _buildMetadataRow(context, isAuthor: isAuthor),
                            ),
                            const SizedBox(width: 8),
                            _buildViewsAndComments(context, commentsCount),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetadataRow(BuildContext context, {required bool isAuthor}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final textColor = isDark ? Colors.grey.shade300 : Colors.grey.shade700;

    final locale = context.l10n.localeName;
    final mins = article.estimatedReadingTimeMinutes;
    final readTimeLabel = mins >= 60 
        ? (locale == 'ar' ? '${(mins / 60).round()} ساعة' : '${(mins / 60).round()} hr')
        : (locale == 'ar' ? '$mins دقيقة' : '$mins min');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(Icons.access_time_filled, size: 14, color: iconColor),
        const SizedBox(width: 4),
        Text(
          timeago.format(article.createdAt, locale: locale),
          style: TextStyle(color: textColor, fontSize: 13),
        ),
        const SizedBox(width: 10),
        Icon(Icons.hourglass_empty_rounded, size: 14, color: iconColor),
        const SizedBox(width: 4),
        Text(
          readTimeLabel,
          style: TextStyle(color: textColor, fontSize: 13),
        ),
        if (article.tags.isNotEmpty || isAuthor) ...[
          const SizedBox(width: 10),
          Text(
            '•',
            style: TextStyle(color: iconColor.withValues(alpha: 0.5), fontSize: 13),
          ),
          const SizedBox(width: 10),
        ],
        if (article.tags.isNotEmpty) ...[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: article.tags.map((tag) {
              return Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 2.0),
                decoration: BoxDecoration(
                  color: tag.color,
                  shape: BoxShape.circle,
                ),
              );
            }).toList(),
          ),
          if (isAuthor) const SizedBox(width: 8),
        ],
        if (isAuthor) _buildAddTagButton(context, article, isAuthor),
      ],
    );
  }

  Widget _buildViewsAndComments(BuildContext context, int commentsCount) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final textColor = isDark ? Colors.grey.shade300 : Colors.grey.shade700;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.visibility_outlined,
            size: 14,
            color: iconColor,
          ),
          const SizedBox(width: 4),
          Text(
            article.viewsCount.toString(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          if (commentsCount > 0) ...[
            const SizedBox(width: 12),
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 14,
              color: iconColor,
            ),
            const SizedBox(width: 4),
            Text(
              commentsCount.toString(),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAddTagButton(BuildContext context, Article article, bool isAuthor) {
    final primaryColor = AppColors.primary;
    return GestureDetector(
      onTap: () {
        TagSelectorSheet.show(
          context,
          initialSelectedTagIds: article.tagIds,
          onSelectionChanged: (selectedTagIds, selectedTags) async {
            await context.read<ArticleProvider>().updateArticle(
              id: article.id,
              tagIds: selectedTagIds,
            );
          },
        );
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.add_rounded,
              size: 13,
              color: primaryColor,
            ),
            const SizedBox(width: 2),
            Text(
              context.l10n.articleCategoryLabel,
              style: TextStyle(
                fontSize: 13,
                color: primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCapsule(BuildContext context, PostStatus status) {
    if (status == PostStatus.written) {
      return const SizedBox.shrink();
    }
    Color color;
    String label;
    switch (status) {
      case PostStatus.published:
        color = AppColors.success;
        label = context.l10n.published;
        break;
      case PostStatus.draft:
        color = Colors.grey;
        label = context.l10n.draft;
        break;
      case PostStatus.archived:
        color = Colors.blue;
        label = context.l10n.archived;
        break;
      case PostStatus.trash:
        color = AppColors.error;
        label = context.l10n.deleted;
        break;
      default:
        color = AppColors.success;
        label = context.l10n.published;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? color.withValues(alpha: 0.15) : color.withValues(alpha: 0.08);

    return InteractionCapsule(
      borderColor: color,
      borderOpacity: 1.0,
      backgroundColor: bgColor,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _getImageUrl(Article article) {
    // PocketBase URL format: http://127.0.0.1:8090/api/files/COLLECTION_ID_OR_NAME/RECORD_ID/FILENAME
    return 'https://sijilli.pockethost.io/api/files/articles/${article.id}/${article.image}';
  }
}
