import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:sijilli/core/services/pocketbase_client.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../models/article.dart';
import '../providers/article_provider.dart';
import '../../auth/providers/auth_provider.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/widgets/sheets/app_action_sheet.dart';
import '../../profile/providers/moderation_provider.dart';

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
              AppActionSheet.show(
                context,
                actions: [
                  AppActionItem(
                    label: context.l10n.copy,
                    icon: Icons.copy,
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: article.plainText));
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
                        if (confirm == true && context.mounted) {
                          context.read<ArticleProvider>().deleteArticle(article.id);
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
                                  if (article.isDraft)
                                    WidgetSpan(
                                      alignment: PlaceholderAlignment.middle,
                                      child: Container(
                                        margin: const EdgeInsets.only(left: 6.0),
                                        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: AppColors.warning, width: 1),
                                          borderRadius: BorderRadius.circular(4.0),
                                        ),
                                        child: const Text(
                                          'مسودة',
                                          style: TextStyle(
                                            color: AppColors.warning,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  TextSpan(
                                    text: article.title.isNotEmpty ? article.title : 'بدون عنوان',
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (isAuthor) ...[
                            const SizedBox(width: 8),
                            if (article.isPublished)
                              Text('منشور', style: TextStyle(fontSize: 12, color: AppColors.getTextSecondary(context), fontWeight: FontWeight.bold)),
                            Directionality(
                              textDirection: TextDirection.rtl,
                              child: Transform.scale(
                                scale: 0.8,
                                alignment: Alignment.centerLeft,
                                child: SizedBox(
                                  height: 32, // Reduce height footprint of the switch
                                  child: Switch(
                                    value: article.isPublished,
                                    activeColor: AppColors.primary,
                                    onChanged: (value) {
                                      context.read<ArticleProvider>().togglePublishStatus(article.id, value);
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Footer: Metadata
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                timeago.format(article.createdAt, locale: context.l10n.localeName),
                                style: TextStyle(
                                  fontSize: AppDimens.textSizeS,
                                  color: AppColors.getTextSecondary(context),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text('•', style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: AppDimens.textSizeS)),
                              const SizedBox(width: 8),
                              Text(
                                context.l10n.readTimeMins(article.estimatedReadingTimeMinutes),
                                style: TextStyle(
                                  fontSize: AppDimens.textSizeS,
                                  color: AppColors.getTextSecondary(context),
                                ),
                              ),
                            ],
                          ),
                          // Likes Counter
                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Share Button
                                InkWell(
                                  onTap: () async {
                                    final username = article.author?.username ?? 'user';
                                    final url = 'https://sijilli.com/$username/${article.id}';
                                    
                                    final authorName = article.author?.name ?? article.author?.username ?? 'مستخدم';
                                    final plainText = article.plainText.trim();
                                    String snippet = '';
                                    if (plainText.isNotEmpty) {
                                      final cleanSingleLine = plainText.replaceAll(RegExp(r'\s+'), ' ');
                                      if (cleanSingleLine.length > 120) {
                                        snippet = '${cleanSingleLine.substring(0, 120)}...';
                                      } else {
                                        snippet = cleanSingleLine;
                                      }
                                    }
                                    
                                    final shareText = 'كتب $authorName: $snippet\n\n$url';
                                    
                                    if (kIsWeb) {
                                      Clipboard.setData(ClipboardData(text: shareText));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(context.l10n.copiedToClipboard(shareText))),
                                      );
                                    } else {
                                      String? localImagePath;
                                      final hasArticleImage = article.image != null && article.image!.isNotEmpty;
                                      if (hasArticleImage) {
                                        try {
                                          final imageUrl = _getImageUrl(article);
                                          final response = await http.get(Uri.parse(imageUrl)).timeout(const Duration(seconds: 3));
                                          if (response.statusCode == 200) {
                                            final tempDir = await getTemporaryDirectory();
                                            final file = File('${tempDir.path}/article_${article.id}.png');
                                            await file.writeAsBytes(response.bodyBytes);
                                            localImagePath = file.path;
                                          }
                                        } catch (e) {
                                          debugPrint('Error downloading article image: $e');
                                        }
                                      }
                                      if (localImagePath == null && article.author != null && article.author!.hasAvatar) {
                                        try {
                                          final avatarUrl = article.author!.getAvatarUrl(
                                            PocketBaseClient.instance.pb.baseURL,
                                            thumb: '100x100',
                                          );
                                          if (avatarUrl != null) {
                                            final response = await http.get(Uri.parse(avatarUrl)).timeout(const Duration(seconds: 3));
                                            if (response.statusCode == 200) {
                                              final tempDir = await getTemporaryDirectory();
                                              final file = File('${tempDir.path}/avatar_${article.author!.id}_thumb.png');
                                              await file.writeAsBytes(response.bodyBytes);
                                              localImagePath = file.path;
                                            }
                                          }
                                        } catch (e) {
                                          debugPrint('Error downloading avatar: $e');
                                        }
                                      }
                                      
                                      if (localImagePath != null) {
                                        // ignore: deprecated_member_use
                                        await Share.shareXFiles(
                                          [XFile(localImagePath)],
                                          text: shareText,
                                          subject: article.title,
                                        );
                                      } else {
                                        // ignore: deprecated_member_use
                                        await Share.share(shareText, subject: article.title);
                                      }
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(4.0),
                                    child: Icon(
                                      Icons.ios_share,
                                      size: 16,
                                      color: AppColors.getTextSecondary(context),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const SizedBox(width: 5), // Nudge away from the edge to align with Switch
                                Icon(
                                  article.likes.contains(currentUserId) ? Icons.favorite : Icons.favorite_border,
                                  size: 16,
                                  color: article.likes.contains(currentUserId) ? AppColors.error : AppColors.getTextSecondary(context),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  article.likes.length.toString(),
                                  style: TextStyle(
                                    fontSize: AppDimens.textSizeS,
                                    color: AppColors.getTextSecondary(context),
                                  ),
                                ),
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

  String _getImageUrl(Article article) {
    // PocketBase URL format: http://127.0.0.1:8090/api/files/COLLECTION_ID_OR_NAME/RECORD_ID/FILENAME
    return 'https://sijilli.pockethost.io/api/files/articles/${article.id}/${article.image}';
  }
}
