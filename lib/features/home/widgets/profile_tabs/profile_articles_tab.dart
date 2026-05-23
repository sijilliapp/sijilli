import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_dimens.dart';
import '../private_profile_wall.dart';
import '../../../articles/providers/article_provider.dart';
import '../../../articles/widgets/article_list.dart';
import '../../../articles/screens/add_article_screen.dart';
import '../../../../core/constants/app_colors.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';

class ProfileArticlesTab extends StatefulWidget {
  final String userId;
  final bool isCurrentUser;

  const ProfileArticlesTab({
    super.key,
    required this.userId,
    required this.isCurrentUser,
  });

  @override
  State<ProfileArticlesTab> createState() => _ProfileArticlesTabState();
}

class _ProfileArticlesTabState extends State<ProfileArticlesTab> {
  bool _isSearchVisible = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ArticleProvider>().fetchUserArticles(
            widget.userId,
            refresh: true,
            isCurrentUser: widget.isCurrentUser,
          );
    });
  }

  String _normalizeArabic(String text) {
    String normalized = text.replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), ''); // إزالة التشكيل
    normalized = normalized.replaceAll('\u0640', ''); // إزالة التطويل (الكشيدة)
    
    // إزالة رموز التنسيق والأسطر الجديدة واستبدالها بمسافات لكي لا تقطع تسلسل الكلمات
    normalized = normalized.replaceAll(RegExp(r'\[/?(POEM|CENTER|JUSTIFY|B)\]', caseSensitive: false), ' ');
    normalized = normalized.replaceAll(RegExp(r'[=~*\n\r]'), ' ');
    
    normalized = normalized.replaceAll(RegExp(r'[أإآ]'), 'ا'); // توحيد الألف
    normalized = normalized.replaceAll('ة', 'ه'); // توحيد التاء المربوطة
    normalized = normalized.replaceAll('ى', 'ي'); // توحيد الألف المقصورة
    
    // توحيد المسافات
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized.toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ArticleProvider>(
      builder: (context, provider, child) {
        final userArticles = provider.getUserArticles(widget.userId);
        
        final query = _normalizeArabic(_searchQuery);
        final filteredArticles = _searchQuery.isEmpty 
            ? userArticles 
            : userArticles.where((a) => 
                _normalizeArabic(a.title).contains(query) || 
                _normalizeArabic(a.text).contains(query)).toList();
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${context.l10n.articles} (${userArticles.length})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(_isSearchVisible ? Icons.search_off : Icons.search, color: AppColors.primary),
                        onPressed: () {
                          setState(() {
                            _isSearchVisible = !_isSearchVisible;
                            if (!_isSearchVisible) {
                              _searchController.clear();
                              _searchQuery = '';
                            }
                          });
                        },
                      ),
                      if (widget.isCurrentUser)
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: AppColors.primary, size: 28),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AddArticleScreen(),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (_isSearchVisible)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0).copyWith(bottom: 12.0),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: '${context.l10n.search}...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),
            Expanded(
              child: ArticleList(
                articles: filteredArticles,
                isInitialLoading: provider.isInitialLoading,
                isFetchingMore: provider.isFetchingMore,
                hasMore: provider.hasMore,
                onLoadMore: () {
                  provider.fetchUserArticles(
                    widget.userId,
                    isCurrentUser: widget.isCurrentUser,
                  );
                },
                onRefresh: () => provider.fetchUserArticles(
                  widget.userId,
                  refresh: true,
                  isCurrentUser: widget.isCurrentUser,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
