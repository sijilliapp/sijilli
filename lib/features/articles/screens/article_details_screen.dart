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
class ArticleDetailsScreen extends StatefulWidget {
  final Article article;

  const ArticleDetailsScreen({
    super.key,
    required this.article,
  });

  @override
  State<ArticleDetailsScreen> createState() => _ArticleDetailsScreenState();
}

class _ArticleDetailsScreenState extends State<ArticleDetailsScreen> {
  bool _isImageExpanded = false;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ArticleProvider>(context);
    final updatedArticle = provider.articles.firstWhere(
      (a) => a.id == widget.article.id,
      orElse: () => widget.article,
    );
    
    final hasImage = updatedArticle.image != null && updatedArticle.image!.isNotEmpty;
    final currentUserId = context.read<AuthProvider>().user?.id;
    final isAuthor = currentUserId == updatedArticle.authorId;

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
        slivers: [
          // AppBar & Image Header
          SliverAppBar(
            expandedHeight: hasImage 
                ? (_isImageExpanded ? 300.0 : 100.0) 
                : kToolbarHeight,
            pinned: true,
            backgroundColor: AppColors.getBackground(context),
            foregroundColor: AppColors.getTextPrimary(context),
            actions: [
              IconButton(
                tooltip: 'نسخ النص',
                icon: const Icon(Icons.copy),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: updatedArticle.plainText));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.l10n.articleCopied(updatedArticle.title))),
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
            flexibleSpace: FlexibleSpaceBar(
              background: hasImage
                  ? GestureDetector(
                      onTap: () {
                        setState(() {
                          _isImageExpanded = !_isImageExpanded;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        width: double.infinity,
                        height: _isImageExpanded ? 300.0 : 100.0,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              'https://sijilli.pockethost.io/api/files/articles/${updatedArticle.id}/${updatedArticle.image}',
                              fit: BoxFit.cover,
                            ),
                            // Gradient overlay to ensure back button is visible
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.6),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.0, 0.3],
                                ),
                              ),
                            ),
                            if (!_isImageExpanded)
                              Positioned(
                                bottom: 8,
                                right: 16,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 16),
                                      const SizedBox(width: 4),
                                      Text(context.l10n.expandImage, style: const TextStyle(color: Colors.white, fontSize: 10)),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    )
                  : null,
            ),
          ),

          // Article Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [

                  // Text Content
                  ArticleContentRenderer(text: updatedArticle.text),
                  
                  // Metadata Block at the bottom
                  const SizedBox(height: 48),
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
                              'تاريخ النشر: ${timeago.format(updatedArticle.createdAt, locale: Localizations.localeOf(context).languageCode)}',
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
                                context.l10n.lastEdited(timeago.format(updatedArticle.updatedAt, locale: Localizations.localeOf(context).languageCode)),
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
                              provider.toggleLike(innerArticle.id, currentUserId);
                            } : null,
                          ),
                          Text(
                            '${innerArticle.likes.length}',
                            style: TextStyle(
                              fontSize: AppDimens.textSizeM,
                              fontWeight: FontWeight.bold,
                              color: AppColors.getTextSecondary(context),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: Icon(Icons.comment_outlined, color: AppColors.getTextSecondary(context)),
                            onPressed: () {
                              // TODO: Open Comments Bottom Sheet
                            },
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
    );
  }
}
