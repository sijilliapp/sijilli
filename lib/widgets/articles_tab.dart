import 'package:flutter/material.dart';
import '../models/article_model.dart';
import '../services/auth_service.dart';
import '../screens/add_article_screen.dart';
import '../screens/article_details_screen.dart';

/// تبويب المقالات - مستقل تماماً عن المواعيد
class ArticlesTab extends StatefulWidget {
  const ArticlesTab({super.key});

  @override
  State<ArticlesTab> createState() => _ArticlesTabState();
}

class _ArticlesTabState extends State<ArticlesTab> {
  final AuthService _authService = AuthService();
  List<ArticleModel> _articles = [];
  Map<String, String> _authorNames = {}; // معرف المقال -> اسم الكاتب
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadArticles();
  }

  Future<void> _loadArticles() async {
    setState(() => _isLoading = true);
    
    try {
      final currentUserId = _authService.currentUser?.id;
      if (currentUserId == null) return;

      final records = await _authService.pb
          .collection('articles')
          .getList(
            page: 1,
            perPage: 50,
            sort: '-created',
            filter: 'is_public = true || author = "$currentUserId"',
          );

      final articles = records.items
          .map((record) => ArticleModel.fromJson(record.toJson()))
          .toList();

      // جلب أسماء الكتّاب
      final authorIds = articles.map((a) => a.authorId).toSet().toList();
      if (authorIds.isNotEmpty) {
        final authorFilter = authorIds.map((id) => 'id = "$id"').join(' || ');
        final authorRecords = await _authService.pb
            .collection('users')
            .getFullList(filter: '($authorFilter)');
        
        for (final record in authorRecords) {
          final userId = record.data['id'] as String;
          final userName = record.data['name'] as String;
          // ربط اسم الكاتب بكل مقالاته
          for (final article in articles) {
            if (article.authorId == userId) {
              _authorNames[article.id] = userName;
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _articles = articles;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ خطأ في تحميل المقالات: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_articles.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.article_outlined, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'لا توجد مقالات',
                style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              Text(
                'اضغط على + لإضافة مقال جديد',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildListDelegate([
        // هيدر المقالات
        _buildHeader(),
        // قائمة المقالات
        ..._articles.map((article) => _buildArticleCard(article)),
      ]),
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // زر الإضافة على اليسار (LTR)
          IconButton(
            icon: const Icon(Icons.add, color: Color(0xFF2196F3), size: 28),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddArticleScreen(),
                ),
              ).then((_) => _loadArticles());
            },
          ),
          // عنوان "المقالات" على اليمين
          const Text(
            'المقالات',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArticleCard(ArticleModel article) {
    final authorName = _authorNames[article.id] ?? 'غير معروف';
    final formattedDate = _formatDate(article.created);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ArticleDetailsScreen(article: article),
            ),
          ).then((deleted) {
            if (deleted == true) {
              _loadArticles();
            }
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // المحتوى والمعلومات
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // المحتوى - سطر واحد فقط
                    Text(
                      article.content,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 6),
                    // معلومات الكاتب والتاريخ
                    Text(
                      'كتبه: $authorName بتاريخ $formattedDate',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.right,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // أيقونة النقاط الثلاث
              Icon(
                Icons.more_horiz,
                size: 20,
                color: Colors.grey.shade600,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'يناير', 'فبراير', 'مارس', 'إبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    return '${date.day}/${months[date.month - 1]}/${date.year}';
  }
}
