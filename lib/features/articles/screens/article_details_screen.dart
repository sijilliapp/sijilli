import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../models/article.dart';
import '../providers/article_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../widgets/article_content_renderer.dart';
import 'add_article_screen.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/utils/app_date_formatter.dart';
import '../../../core/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/providers/theme_provider.dart';
import '../widgets/comment_section.dart';
import '../widgets/collapsible_content.dart';
import 'package:sijilli/features/articles/widgets/tag_chip.dart';
import 'package:sijilli/features/articles/widgets/tag_selector_sheet.dart';
import 'package:sijilli/core/utils/image_saver_util.dart';

class ArticleDetailsScreen extends StatefulWidget {
  final Article article;
  final bool openComments;

  const ArticleDetailsScreen({
    super.key,
    required this.article,
    this.openComments = false,
  });

  @override
  State<ArticleDetailsScreen> createState() => _ArticleDetailsScreenState();
}

class _ArticleDetailsScreenState extends State<ArticleDetailsScreen> {
  bool _isImageExpanded = false;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ArticleProvider>(context, listen: false).fetchComments(widget.article.id);
      if (widget.openComments) {
        _showCommentsSheet();
      }
    });

    // تتبع قراءة المقال إذا كان القارئ غير الكاتب
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUserId = authProvider.user?.id;
      if (currentUserId != widget.article.authorId) {
        Provider.of<ArticleProvider>(context, listen: false).trackArticleVisit(
          articleId: widget.article.id,
          authorId: widget.article.authorId,
          articleTitle: widget.article.title,
        );
      }
    });
  }

  void _showCommentsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentSection(article: widget.article),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ArticleProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final fontFamily = settingsProvider.articleFontFamily;

    final updatedArticle = provider.articles.firstWhere(
      (a) => a.id == widget.article.id,
      orElse: () => widget.article,
    );
    
    final hasImage = updatedArticle.image != null && updatedArticle.image!.isNotEmpty;
    final currentUserId = context.read<AuthProvider>().user?.id;
    final isAuthor = currentUserId == updatedArticle.authorId;

    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.getBackground(context),
        body: SafeArea(
          bottom: false,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              // AppBar (Standard pinned toolbar)
              SliverAppBar(
                pinned: true,
                backgroundColor: AppColors.getBackground(context),
                foregroundColor: AppColors.getTextPrimary(context),
                actions: [
                  IconButton(
                    tooltip: context.l10n.readingFontTooltip,
                    icon: Icon(
                      Icons.font_download,
                      color: fontFamily != 'Default' ? AppColors.primary : null,
                    ),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                        ),
                        builder: (context) {
                          return SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(height: 16),
                                Container(
                                  width: 40,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  context.l10n.readingFontTooltip,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Divider(),
                                Flexible(
                                  child: ListView(
                                    shrinkWrap: true,
                                    children: themeProvider.availableFonts.map((font) {
                                      final isSelected = fontFamily == font;
                                      return ListTile(
                                        title: Text(
                                          font == 'Default' ? context.l10n.defaultFontStyle : font,
                                          style: TextStyle(
                                            fontFamily: font == 'Default' ? null : font,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                            color: isSelected ? AppColors.primary : null,
                                          ),
                                        ),
                                        trailing: isSelected 
                                            ? const Icon(Icons.check_circle, color: AppColors.primary)
                                            : null,
                                        onTap: () async {
                                          await settingsProvider.setArticleFontFamily(font);
                                          if (context.mounted) {
                                            Navigator.pop(context);
                                          }
                                        },
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                  if (isAuthor || updatedArticle.isPublished)
                    IconButton(
                      tooltip: 'نسخ رابط المشاركة',
                      icon: const Icon(Icons.link),
                      onPressed: () async {
                      final username = updatedArticle.author?.username ?? 'user';
                      final url = 'https://sijilli.com/$username/${updatedArticle.id}';
                      
                      // Auto-publish if author and not already published
                      if (isAuthor && !updatedArticle.isPublished) {
                        await context.read<ArticleProvider>().togglePublishStatus(updatedArticle.id, true);
                      }
  
                      await Clipboard.setData(ClipboardData(text: url));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(isAuthor && !updatedArticle.isPublished 
                                ? 'تم نسخ رابط المقال إلى الحافظة ونشره تلقائياً 🚀'
                                : 'تم نسخ رابط المشاركة إلى الحافظة 🔗'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                  ),
                  if (isAuthor)
                    IconButton(
                      tooltip: 'تعديل المقال',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddArticleScreen(article: updatedArticle),
                          ),
                        );
                      },
                    ),
                ],
              ),
  
              // Article Content
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (hasImage) ...[
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _isImageExpanded = !_isImageExpanded;
                            });
                          },
                          child: AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            child: Stack(
                              alignment: Alignment.bottomCenter,
                              children: [
                                Container(
                                  width: double.infinity,
                                  height: _isImageExpanded ? null : 120.0,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Image.network(
                                      'https://sijilli.pockethost.io/api/files/articles/${updatedArticle.id}/${updatedArticle.image}',
                                      fit: _isImageExpanded ? BoxFit.contain : BoxFit.cover,
                                    ),
                                  ),
                                ),
                                if (_isImageExpanded)
                                  Positioned(
                                    bottom: 12,
                                    right: 12,
                                    child: Material(
                                      color: Colors.black.withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(20),
                                      child: InkWell(
                                        onTap: () async {
                                          final imageUrl = 'https://sijilli.pockethost.io/api/files/articles/${updatedArticle.id}/${updatedArticle.image}';
                                          final success = await ImageSaverUtil.saveImageFromUrl(imageUrl, '${updatedArticle.id}_image.jpg');
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(success 
                                                    ? 'تم حفظ الصورة في ألبوم الصور بنجاح 🖼️' 
                                                    : 'فشل حفظ الصورة ❌'),
                                              ),
                                            );
                                          }
                                        },
                                        borderRadius: BorderRadius.circular(20),
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          child: const Icon(
                                            Icons.arrow_downward,
                                            size: 24,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      // Text Content
                      CollapsibleContent(
                        buttonText: context.l10n.fullArticle,
                        child: isAuthor
                            ? GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => AddArticleScreen(article: updatedArticle),
                                    ),
                                  );
                                },
                                child: ArticleContentRenderer(
                                  text: updatedArticle.text,
                                  fontFamily: fontFamily,
                                ),
                              )
                            : ArticleContentRenderer(
                                text: updatedArticle.text,
                                fontFamily: fontFamily,
                              ),
                      ),
                      
                      if (updatedArticle.tags.isNotEmpty || isAuthor) ...[
                        const SizedBox(height: 24),
                        Wrap(
                          spacing: 8.0,
                          runSpacing: 8.0,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            ...updatedArticle.tags.map((tag) => TagChip(tag: tag)),
                            if (isAuthor)
                              GestureDetector(
                                onTap: () {
                                  TagSelectorSheet.show(
                                    context,
                                    initialSelectedTagIds: updatedArticle.tagIds,
                                    onSelectionChanged: (selectedTagIds, selectedTags) async {
                                      await context.read<ArticleProvider>().updateArticle(
                                        id: updatedArticle.id,
                                        tagIds: selectedTagIds,
                                      );
                                    },
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: AppColors.primary.withValues(alpha: 0.3),
                                      width: 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.add,
                                        size: 13,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        updatedArticle.tags.isEmpty 
                                            ? context.l10n.addCategory 
                                            : context.l10n.editCategory,
                                        style: const TextStyle(
                                          color: AppColors.primary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          height: 1.1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                      
                      // Metadata Block at the bottom
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.getCardBackground(context).withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Word Count
                            Row(
                              children: [
                                Icon(Icons.text_snippet_outlined, size: 18, color: AppColors.getTextSecondary(context)),
                                const SizedBox(width: 8),
                                Text(
                                  context.l10n.wordsCount(updatedArticle.wordCount),
                                  style: TextStyle(fontSize: 14, color: AppColors.getTextSecondary(context)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Publish Date
                            Row(
                              children: [
                                Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.getTextSecondary(context)),
                                const SizedBox(width: 8),
                                Text(
                                  'تاريخ النشر: ${AppDateFormatter.formatArticleDateTime(updatedArticle.createdAt, Localizations.localeOf(context).languageCode)}',
                                  style: TextStyle(fontSize: 14, color: AppColors.getTextSecondary(context)),
                                ),
                              ],
                            ),
                            // Last Edit Date (if different)
                            if (updatedArticle.updatedAt.isAfter(updatedArticle.createdAt.add(const Duration(minutes: 5)))) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(Icons.edit_calendar_outlined, size: 18, color: AppColors.getTextSecondary(context)),
                                  const SizedBox(width: 8),
                                  Text(
                                    context.l10n.lastEdited(AppDateFormatter.formatArticleDateTime(updatedArticle.updatedAt, Localizations.localeOf(context).languageCode)),
                                    style: TextStyle(fontSize: 14, color: AppColors.getTextSecondary(context)),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Interaction Bar
                      const Divider(),
                      Consumer<ArticleProvider>(
                        builder: (context, provider, child) {
                          // Find the updated article from the provider if possible
                          final innerArticle = provider.articles.firstWhere(
                            (a) => a.id == widget.article.id, 
                            orElse: () => updatedArticle,
                          );
                          
                          final isLiked = innerArticle.likes.contains(currentUserId);
                          
                          return Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  isLiked ? Icons.favorite : Icons.favorite_border,
                                  color: isLiked ? AppColors.error : AppColors.getTextSecondary(context),
                                ),
                                onPressed: currentUserId != null ? () {
                                  final likerName = context.read<AuthProvider>().user?.name ?? '';
                                  provider.toggleLike(innerArticle.id, currentUserId, likerName: likerName);
                                } : null,
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  '${innerArticle.likes.length}',
                                  style: TextStyle(
                                    fontSize: AppDimens.textSizeM,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.getTextSecondary(context),
                                  ),
                                ),
                              ),
                              const Spacer(),
                              InkWell(
                                onTap: _showCommentsSheet,
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    left: 4.0,
                                    right: 4.0,
                                    top: 10.0,
                                    bottom: 6.0,
                                  ),
                                  child: Text(
                                    'عدد التعليقات: ${provider.getCommentsForArticle(innerArticle.id).length}',
                                    style: TextStyle(
                                      fontSize: AppDimens.textSizeM,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.getTextSecondary(context),
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.comment_outlined, color: AppColors.getTextSecondary(context)),
                                onPressed: _showCommentsSheet,
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
