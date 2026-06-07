import 'package:flutter/material.dart';
import '../../../models/article.dart';
import 'article_card.dart';
import '../screens/article_details_screen.dart';
import '../screens/add_article_screen.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';
import '../../../core/constants/app_colors.dart';

class ArticleList extends StatelessWidget {
  final List<Article> articles;
  final bool isInitialLoading;
  final bool isFetchingMore;
  final bool hasMore;
  final String? errorMessage;
  final VoidCallback onLoadMore;
  final Future<void> Function() onRefresh;

  const ArticleList({
    super.key,
    required this.articles,
    required this.isInitialLoading,
    required this.isFetchingMore,
    required this.hasMore,
    this.errorMessage,
    required this.onLoadMore,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (articles.isEmpty && isInitialLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (articles.isEmpty) {
      return _buildEmptyState(context);
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(4.0, 2.0, 4.0, 80.0),
        itemCount: articles.length + (hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == articles.length) {
            // Reached the end, trigger load more if not already loading and no error
            if (!isFetchingMore && !isInitialLoading && errorMessage == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                onLoadMore();
              });
            }
            // Show retry button if error occurred
            if (errorMessage != null) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: onLoadMore,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('إعادة المحاولة', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
            }
            // Only show bottom spinner if we are actively fetching more
            if (isFetchingMore) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }
            return const SizedBox.shrink();
          }

          final article = articles[index];
          return ArticleCard(
            article: article,
            onTap: () {
              if (article.isDraft) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddArticleScreen(article: article),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ArticleDetailsScreen(article: article),
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.article_outlined, size: 64, color: AppColors.getTextSecondary(context).withValues(alpha: 0.5)),
                const SizedBox(height: 16),
                Text(
                  context.l10n.noArticlesYet,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
