import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_dimens.dart';
import '../private_profile_wall.dart';
import '../../../articles/providers/article_provider.dart';
import '../../../articles/widgets/article_list.dart';
import '../../../articles/screens/add_article_screen.dart';
import '../../../articles/widgets/tag_chip.dart';
import '../../../../models/tag.dart';
import 'package:sijilli/models/article.dart';
import 'package:sijilli/models/appointment.dart';
import '../../../../core/constants/app_colors.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';
import '../../../../core/services/pocketbase_client.dart';

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
  bool _showSystemFilters = false;
  String? _activeSystemStatus; // null, 'published', 'draft'
  List<Tag> _allPublishedTags = [];
  bool _isLoadingTags = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ArticleProvider>().fetchUserArticles(
            widget.userId,
            refresh: true,
            isCurrentUser: widget.isCurrentUser,
          );
      _fetchPublishedTags();
    });
  }

  Future<void> _fetchPublishedTags() async {
    if (!mounted) return;
    setState(() {
      _isLoadingTags = true;
    });

    try {
      final pb = PocketBaseClient.instance.pb;

      // 1. Fetch tags of all published articles for this user (only tags field)
      final String filter = widget.isCurrentUser
          ? 'author = "${widget.userId}" && (post_status = "published" || post_status = "draft" || post_status = "written" || post_status = "")'
          : 'author = "${widget.userId}" && (post_status = "published" || (post_status = "" && is_published = true))';
      
      final articlesRecords = await pb.collection('articles').getFullList(
        filter: filter,
        fields: 'tags',
      );

      final Set<String> publishedTagIds = {};
      for (var record in articlesRecords) {
        final List<dynamic> tagList = record.data['tags'] ?? [];
        for (var tagId in tagList) {
          publishedTagIds.add(tagId.toString());
        }
      }

      if (publishedTagIds.isEmpty) {
        if (mounted) {
          setState(() {
            _allPublishedTags = [];
            _isLoadingTags = false;
          });
        }
        return;
      }

      // 2. Fetch all tags belonging to the author
      final tagsRecords = await pb.collection('tags').getFullList(
        filter: 'user = "${widget.userId}"',
        sort: 'name',
      );

      final List<Tag> tags = tagsRecords
          .map((record) => Tag.fromJson(record.toJson()))
          .where((tag) => publishedTagIds.contains(tag.id))
          .toList();

      if (mounted) {
        setState(() {
          _allPublishedTags = tags;
          _isLoadingTags = false;
        });
      }
    } catch (e) {
      print('Error fetching published tags: $e');
      if (mounted) {
        setState(() {
          _isLoadingTags = false;
        });
      }
    }
  }

  String _normalizeArabic(String text) {
    String normalized = text.replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), ''); // إزالة التشكيل
    normalized = normalized.replaceAll('\u0640', ''); // إزالة التطويل (الكشيدة)
    
    // إزالة رموز التنسيق والأسطر الجديدة واستبدالها بمسافات لكي لا تقطع تسلسل الكلمات
    normalized = normalized.replaceAll(RegExp(r'\[/?(POEM|BOLD|CENTER|JUSTIFY|LEFT|RIGHT|B|HIGHLIGHT)\]', caseSensitive: false), ' ');
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

        // Extract unique tags present in these articles as a fallback during loading
        final List<Tag> availableTags;
        if (_isLoadingTags) {
          final articlesTags = userArticles.expand((a) => a.tags).toList();
          final uniqueTagsMap = <String, Tag>{};
          for (var tag in articlesTags) {
            uniqueTagsMap[tag.id] = tag;
          }
          availableTags = uniqueTagsMap.values.toList();
        } else {
          availableTags = _allPublishedTags;
        }

        final activeTagIds = provider.activeFilterTagIds;

        // 1. Filter by tags if selected (AND logic)
        var filteredByTag = userArticles;
        if (activeTagIds.isNotEmpty) {
          filteredByTag = userArticles.where((a) => 
            activeTagIds.every((id) => a.tagIds.contains(id))
          ).toList();
        }

        // 1.5. Filter by system status if active (only when on "All" category)
        if (activeTagIds.isEmpty && _activeSystemStatus != null && widget.isCurrentUser) {
          if (_activeSystemStatus == 'published') {
            filteredByTag = filteredByTag.where((a) => a.postStatus == PostStatus.published).toList();
          } else if (_activeSystemStatus == 'draft') {
            filteredByTag = filteredByTag.where((a) => a.postStatus == PostStatus.draft).toList();
          } else if (_activeSystemStatus == 'duplicate') {
            final articleWordSets = <String, Set<String>>{};
            for (final a in filteredByTag) {
              final normalized = _normalizeArabic(a.title + '\n' + a.pureText);
              final words = normalized.split(' ').where((w) => w.isNotEmpty).toSet();
              articleWordSets[a.id] = words;
            }

            final duplicateIds = <String>{};
            final n = filteredByTag.length;
            for (int i = 0; i < n; i++) {
              final id1 = filteredByTag[i].id;
              final words1 = articleWordSets[id1]!;
              if (words1.isEmpty) continue;

              for (int j = i + 1; j < n; j++) {
                final id2 = filteredByTag[j].id;
                final words2 = articleWordSets[id2]!;
                if (words2.isEmpty) continue;

                // Jaccard similarity: intersection / union
                final intersectionCount = words1.intersection(words2).length;
                final unionCount = words1.length + words2.length - intersectionCount;
                final similarity = unionCount > 0 ? intersectionCount / unionCount : 0.0;

                // 85% similarity captures loose duplicates (with slight word variations)
                if (similarity >= 0.85) {
                  duplicateIds.add(id1);
                  duplicateIds.add(id2);
                }
              }
            }
            filteredByTag = filteredByTag.where((a) => duplicateIds.contains(a.id)).toList();
          }
        }
        
        final query = _normalizeArabic(_searchQuery);
        final filteredArticles = _searchQuery.isEmpty 
            ? filteredByTag 
            : filteredByTag.where((a) => 
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
                    '${context.l10n.articles} (${filteredArticles.length})',
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
                                builder: (context) => AddArticleScreen(
                                  initialTagIds: activeTagIds,
                                ),
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
            if (availableTags.isNotEmpty) ...[
              Container(
                height: 28,
                margin: const EdgeInsets.only(bottom: 6.0),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: availableTags.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      final isAllSelected = activeTagIds.isEmpty;
                      return Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: GestureDetector(
                          onTap: () {
                            if (isAllSelected && widget.isCurrentUser) {
                              setState(() {
                                _showSystemFilters = !_showSystemFilters;
                                if (!_showSystemFilters) {
                                  _activeSystemStatus = null;
                                }
                              });
                            } else {
                              setState(() {
                                _showSystemFilters = false;
                                _activeSystemStatus = null;
                              });
                              provider.setActiveFilterTagIds([]);
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: isAllSelected 
                                  ? AppColors.primary 
                                  : (Theme.of(context).brightness == Brightness.dark 
                                      ? Colors.white12 
                                      : Colors.grey.shade100),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isAllSelected 
                                    ? AppColors.primary 
                                    : (Theme.of(context).brightness == Brightness.dark 
                                        ? Colors.white24 
                                        : Colors.grey.shade300),
                                width: 1.0,
                              ),
                            ),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    context.l10n.all,
                                    style: TextStyle(
                                      color: isAllSelected 
                                          ? Colors.white 
                                          : (Theme.of(context).brightness == Brightness.dark 
                                              ? Colors.white70 
                                              : Colors.black87),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      height: 1.1,
                                    ),
                                  ),
                                  if (isAllSelected && widget.isCurrentUser) ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      _showSystemFilters ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                      size: 12,
                                      color: Colors.white70,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    final tag = availableTags[index - 1];
                    final isSelected = activeTagIds.contains(tag.id);

                    return Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: TagChip(
                        tag: tag,
                        isSelected: isSelected,
                        onTap: () {
                          setState(() {
                            _showSystemFilters = false;
                            _activeSystemStatus = null;
                          });
                          if (activeTagIds.length == 1 && isSelected) {
                            provider.setActiveFilterTagIds([]);
                          } else {
                            provider.setActiveFilterTagIds([tag.id]);
                          }
                        },
                        onLongPress: () {
                          setState(() {
                            _showSystemFilters = false;
                            _activeSystemStatus = null;
                          });
                          final newIds = List<String>.from(activeTagIds);
                          if (isSelected) {
                            newIds.remove(tag.id);
                          } else {
                            newIds.add(tag.id);
                          }
                          provider.setActiveFilterTagIds(newIds);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
            if (activeTagIds.isEmpty && _showSystemFilters && widget.isCurrentUser) ...[
              Container(
                height: 28,
                margin: const EdgeInsets.only(bottom: 6.0),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  children: [
                    _buildSystemFilterChip(
                      label: context.l10n.published,
                      isActive: _activeSystemStatus == 'published',
                      activeColor: AppColors.success,
                      onTap: () {
                        setState(() {
                          if (_activeSystemStatus == 'published') {
                            _activeSystemStatus = null;
                          } else {
                            _activeSystemStatus = 'published';
                          }
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildSystemFilterChip(
                      label: context.l10n.draft,
                      isActive: _activeSystemStatus == 'draft',
                      activeColor: Colors.grey,
                      onTap: () {
                        setState(() {
                          if (_activeSystemStatus == 'draft') {
                            _activeSystemStatus = null;
                          } else {
                            _activeSystemStatus = 'draft';
                          }
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildSystemFilterChip(
                      label: context.l10n.duplicate,
                      isActive: _activeSystemStatus == 'duplicate',
                      activeColor: Colors.redAccent,
                      onTap: () {
                        setState(() {
                          if (_activeSystemStatus == 'duplicate') {
                            _activeSystemStatus = null;
                          } else {
                            _activeSystemStatus = 'duplicate';
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
            Expanded(
              child: ArticleList(
                articles: filteredArticles,
                isInitialLoading: provider.isInitialLoading,
                isFetchingMore: provider.isFetchingMore,
                hasMore: provider.hasMore,
                errorMessage: provider.errorMessage,
                onLoadMore: () {
                  provider.fetchUserArticles(
                    widget.userId,
                    isCurrentUser: widget.isCurrentUser,
                  );
                },
                onRefresh: () {
                  _fetchPublishedTags();
                  return provider.fetchUserArticles(
                    widget.userId,
                    refresh: true,
                    isCurrentUser: widget.isCurrentUser,
                  );
                },
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

  Widget _buildSystemFilterChip({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    Color activeColor = AppColors.primary,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
        decoration: BoxDecoration(
          color: isActive 
              ? activeColor.withValues(alpha: 0.15)
              : (isDark ? Colors.white10 : Colors.grey.shade50),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive 
                ? activeColor 
                : (isDark ? Colors.white24 : Colors.grey.shade300),
            width: 1.0,
          ),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isActive ? Icons.check : Icons.circle,
                size: 8,
                color: isActive ? activeColor : (isDark ? Colors.white30 : Colors.grey.shade400),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isActive 
                      ? (isDark ? Colors.white : activeColor)
                      : (isDark ? Colors.white70 : Colors.black87),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
