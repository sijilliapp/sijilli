import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../models/article.dart';
import '../../../models/appointment.dart';
import '../providers/article_provider.dart';
import '../../auth/providers/auth_provider.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/widgets/sheets/app_action_sheet.dart';
import '../../profile/providers/moderation_provider.dart';
import 'tag_selector_sheet.dart';

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
    final currentUserId = context.read<AuthProvider>().user?.id;
    final isAuthor = currentUserId == article.authorId;
    final commentsCount = context.watch<ArticleProvider>().getCommentsForArticle(article.id).length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4.0),
      child: Material(
        elevation: AppDimens.appointmentCardElevation,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        color: AppColors.getCardBackground(context),
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey, width: AppDimens.appointmentCardBorderWidth),
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
                      label: context.l10n.copy,
                      icon: Icons.copy,
                      onTap: () async {
                        await Clipboard.setData(ClipboardData(text: article.pureText));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(context.l10n.articleCopied(article.title))),
                          );
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
                      opacity: 0.1, // Increased transparency (was 0.15)
                      child: Image.network(
                        _getImageUrl(article),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox(),
                      ),
                    ),
                  ),

                // 2. Content
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header: Title and Publish Switch
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: RichText(
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              text: TextSpan(
                                style: TextStyle(
                                  fontSize: AppDimens.textSizeL,
                                  fontWeight: FontWeight.bold,
                                  height: 1.2,
                                  color: AppColors.getTextPrimary(context),
                                  fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
                                ),
                                children: [
                                  TextSpan(
                                    text: article.title.isNotEmpty ? article.title : 'بدون عنوان',
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (isAuthor && article.postStatus != PostStatus.written) ...[
                            const SizedBox(width: 8),
                            _buildStatusCapsule(context, article.postStatus),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      
                      // Footer: Metadata
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: timeago.format(article.createdAt, locale: context.l10n.localeName),
                                  ),
                                  const TextSpan(text: '  •  '),
                                  TextSpan(
                                    text: context.l10n.readTimeMins(article.estimatedReadingTimeMinutes),
                                  ),
                                  if (article.tags.isNotEmpty) ...[
                                    const TextSpan(text: '  •  '),
                                    ...article.tags.map((t) => WidgetSpan(
                                      alignment: PlaceholderAlignment.middle,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 2.0),
                                        child: Tooltip(
                                          message: t.name,
                                          child: Container(
                                            width: 6.0,
                                            height: 6.0,
                                            decoration: BoxDecoration(
                                              color: t.color,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ),
                                      ),
                                    )),
                                  ] else if (isAuthor) ...[
                                    const TextSpan(text: '  •  '),
                                    WidgetSpan(
                                      alignment: PlaceholderAlignment.middle,
                                      child: GestureDetector(
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
                                            children: [
                                              const Icon(
                                                Icons.add,
                                                size: 11,
                                                color: AppColors.primary,
                                              ),
                                              const SizedBox(width: 1),
                                              Text(
                                                context.l10n.articleCategoryLabel,
                                                style: TextStyle(
                                                  fontSize: AppDimens.textSizeS,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: AppDimens.textSizeS,
                                color: AppColors.getTextSecondary(context),
                              ),
                            ),
                          ),
                          // Likes & Comments Counters
                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const SizedBox(width: 5), // Nudge away from the edge to align with Switch
                                Icon(
                                  article.likes.contains(currentUserId) ? Icons.favorite : Icons.favorite_border,
                                  size: 14,
                                  color: AppColors.getTextSecondary(context),
                                ),
                                const SizedBox(width: 4),
                                Padding(
                                  padding: const EdgeInsets.only(top: 2.0),
                                  child: Text(
                                    article.likes.length.toString(),
                                    style: TextStyle(
                                      fontSize: AppDimens.textSizeS,
                                      color: AppColors.getTextSecondary(context),
                                    ),
                                  ),
                                ),
                                if (commentsCount > 0) ...[
                                  const SizedBox(width: 12),
                                  Icon(
                                    Icons.comment_outlined,
                                    size: 14,
                                    color: AppColors.getTextSecondary(context),
                                  ),
                                  const SizedBox(width: 4),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2.0),
                                    child: Text(
                                      commentsCount.toString(),
                                      style: TextStyle(
                                        fontSize: AppDimens.textSizeS,
                                        color: AppColors.getTextSecondary(context),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color, width: 1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _getImageUrl(Article article) {
    // PocketBase URL format: http://127.0.0.1:8090/api/files/COLLECTION_ID_OR_NAME/RECORD_ID/FILENAME
    return 'https://sijilli.pockethost.io/api/files/articles/${article.id}/${article.image}';
  }
}
