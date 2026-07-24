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
import '../../../core/utils/article_printer.dart';
import 'package:share_plus/share_plus.dart';

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
  late ScrollController _scrollController;
  // 0 = مطوية (بنر)، 1 = كاملة بزوايا، 2 = ملء شاشة dialog
  int _coverState = 0;

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

    // زيادة عداد القراءات للجميع بما فيهم صاحب المقال
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ArticleProvider>(context, listen: false).incrementViews(widget.article.id);
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
    final List<String> audioUrls = updatedArticle.audioFiles
        .map((file) => 'https://sijilli.pockethost.io/api/files/articles/${updatedArticle.id}/$file')
        .toList();
    final List<String> imageUrls = updatedArticle.imageFiles
        .map((file) => 'https://sijilli.pockethost.io/api/files/articles/${updatedArticle.id}/$file')
        .toList();
    final currentUserId = context.read<AuthProvider>().user?.id;
    final isAuthor = currentUserId == updatedArticle.authorId;

    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

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
                                    children: [
                                      ...themeProvider.availableFonts.map((font) {
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
                                      const Divider(),
                                      ListenableBuilder(
                                        listenable: settingsProvider,
                                        builder: (context, _) => SwitchListTile(
                                          title: const Text(
                                            'ضبط أسطر الفقرات تلقائياً',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          subtitle: const Text(
                                            'توزيع الكلمات بالتساوي لمحاذاة النص من الجانبين ومنع الفراغات الزائدة',
                                            style: TextStyle(fontSize: 12),
                                          ),
                                          value: settingsProvider.justifyArticles,
                                          activeColor: AppColors.primary,
                                          onChanged: (val) async {
                                            await settingsProvider.setJustifyArticles(val);
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                  if (isAuthor && !updatedArticle.isReadOnly)
                    IconButton(
                      tooltip: isArabic ? 'تعديل المقال' : 'Edit article',
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
                  if (isAuthor || updatedArticle.isPublished)
                    IconButton(
                      tooltip: isArabic ? 'مشاركة المقال' : 'Share article',
                      icon: const Icon(Icons.share_outlined),
                      onPressed: () async {
                        final username = updatedArticle.author?.username ?? 'user';
                        final url = 'https://sijilli.com/$username/${updatedArticle.id}';
                        
                        // Auto-publish if author and not already published
                        if (isAuthor && !updatedArticle.isPublished) {
                          await context.read<ArticleProvider>().togglePublishStatus(updatedArticle.id, true);
                        }
  
                        await Share.share(url, subject: updatedArticle.title);
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
                      // غلاف المقال
                      if (hasImage) ...[
                        AnimatedSize(
                          duration: const Duration(milliseconds: 380),
                          curve: Curves.easeInOut,
                          alignment: Alignment.topCenter,
                          child: GestureDetector(
                            onTap: () {
                              if (_coverState == 0) {
                                setState(() => _coverState = 1);
                              } else if (_coverState == 1) {
                                final imageUrl = 'https://sijilli.pockethost.io/api/files/articles/${updatedArticle.id}/${updatedArticle.image}';
                                FullScreenImageViewer.show(context, imageUrl);
                              }
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.network(
                                'https://sijilli.pockethost.io/api/files/articles/${updatedArticle.id}/${updatedArticle.image}',
                                width: double.infinity,
                                height: _coverState == 0 ? 120.0 : null,
                                fit: _coverState == 0 ? BoxFit.cover : BoxFit.fitWidth,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      // Text Content
                      CollapsibleContent(
                        buttonText: context.l10n.fullArticle,
                        onExpand: hasImage
                            ? () => setState(() => _coverState = 1)
                            : null,
                        child: (isAuthor && !updatedArticle.isReadOnly)
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
                                  audioUrls: audioUrls,
                                  imageFiles: imageUrls,
                                  articleId: updatedArticle.id,
                                  audioMetadata: updatedArticle.audioMetadata,
                                  onTextUpdated: (isAuthor && !updatedArticle.isReadOnly) ? (updatedText) async {
                                    await Provider.of<ArticleProvider>(context, listen: false).updateArticle(
                                      id: updatedArticle.id,
                                      text: updatedText,
                                    );
                                  } : null,
                                  onMetadataUpdated: (isAuthor && !updatedArticle.isReadOnly) ? (updatedMetadata) async {
                                    await Provider.of<ArticleProvider>(context, listen: false).updateArticle(
                                      id: updatedArticle.id,
                                      audioMetadata: updatedMetadata,
                                    );
                                  } : null,
                                ),
                              )
                            : ArticleContentRenderer(
                                text: updatedArticle.text,
                                fontFamily: fontFamily,
                                audioUrls: audioUrls,
                                imageFiles: imageUrls,
                                articleId: updatedArticle.id,
                                audioMetadata: updatedArticle.audioMetadata,
                                onTextUpdated: (isAuthor && !updatedArticle.isReadOnly) ? (updatedText) async {
                                  await Provider.of<ArticleProvider>(context, listen: false).updateArticle(
                                    id: updatedArticle.id,
                                    text: updatedText,
                                  );
                                } : null,
                                onMetadataUpdated: (isAuthor && !updatedArticle.isReadOnly) ? (updatedMetadata) async {
                                  await Provider.of<ArticleProvider>(context, listen: false).updateArticle(
                                    id: updatedArticle.id,
                                    audioMetadata: updatedMetadata,
                                  );
                                } : null,
                              ),
                      ),
                      
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (updatedArticle.tags.isNotEmpty || isAuthor)
                            Expanded(
                              child: Wrap(
                                spacing: 8.0,
                                runSpacing: 8.0,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  ...updatedArticle.tags.map((tag) => TagChip(tag: tag)),
                                  if (isAuthor && !updatedArticle.isReadOnly)
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
                            )
                          else
                            const Spacer(),
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: () {
                              _showPrintOptionsSheet(context, updatedArticle);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isDarkMode 
                                    ? Colors.white.withValues(alpha: 0.08) 
                                    : Colors.grey.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isDarkMode 
                                      ? Colors.white.withValues(alpha: 0.2) 
                                      : Colors.grey.withValues(alpha: 0.35),
                                  width: 1.0,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.print_outlined,
                                    size: 13,
                                    color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isArabic ? 'طباعة (A4)' : 'Print (A4)',
                                    style: TextStyle(
                                      color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
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
                                  context.l10n.publishedDate(AppDateFormatter.formatArticleDateTime(updatedArticle.createdAt, Localizations.localeOf(context).languageCode)),
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
                          
                          return Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Icon(
                                  Icons.visibility_outlined,
                                  color: AppColors.getTextSecondary(context),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  '${innerArticle.viewsCount}',
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

  void _showPrintOptionsSheet(BuildContext context, Article article) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        bool useTwoColumns = false;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      isArabic ? 'خيارات الطباعة' : 'Print Options',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.titleLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(context).dividerColor.withOpacity(0.1),
                        ),
                      ),
                      child: Column(
                        children: [
                          RadioListTile<bool>(
                            value: false,
                            groupValue: useTwoColumns,
                            activeColor: AppColors.primary,
                            title: Text(
                              isArabic ? 'عمود واحد (افتراضي)' : 'One Column (Default)',
                              style: const TextStyle(fontSize: 14),
                            ),
                            subtitle: Text(
                              isArabic 
                                  ? 'طباعة المقال في عمود واحد كامل الصفحة' 
                                  : 'Print the article in a single column full page',
                              style: const TextStyle(fontSize: 12),
                            ),
                            onChanged: (val) {
                              if (val != null) setSheetState(() => useTwoColumns = val);
                            },
                          ),
                          const Divider(height: 1),
                          RadioListTile<bool>(
                            value: true,
                            groupValue: useTwoColumns,
                            activeColor: AppColors.primary,
                            title: Text(
                              isArabic ? 'عمودان (تنسيق صحيفة)' : 'Two Columns (Newspaper Layout)',
                              style: const TextStyle(fontSize: 14),
                            ),
                            subtitle: Text(
                              isArabic 
                                  ? 'تقسيم المقال لعمودين متوازيين لتوفير الورق وتسهيل القراءة' 
                                  : 'Split the article into two parallel columns to save paper and ease reading',
                              style: const TextStyle(fontSize: 12),
                            ),
                            onChanged: (val) {
                              if (val != null) setSheetState(() => useTwoColumns = val);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        try {
                          await ArticlePrinter.printArticle(context, article, useTwoColumns: useTwoColumns);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isArabic 
                                      ? 'حدث خطأ أثناء محاولة الطباعة: $e' 
                                      : 'An error occurred while trying to print: $e',
                                ),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        isArabic ? 'بدء الطباعة' : 'Start Printing',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
