import 'package:flutter/material.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';
import '../../../models/article.dart';
import '../services/pb_article_service.dart';
import '../widgets/article_content_renderer.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/pocketbase_client.dart';

class PublicArticleScreen extends StatefulWidget {
  final String username;
  final String articleId;

  const PublicArticleScreen({
    super.key,
    required this.username,
    required this.articleId,
  });

  @override
  State<PublicArticleScreen> createState() => _PublicArticleScreenState();
}

class _PublicArticleScreenState extends State<PublicArticleScreen> {
  final _articleService = PbArticleService();
  Article? _article;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchArticle();
  }

  Future<void> _fetchArticle() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final article = await _articleService.getArticleById(widget.articleId);
      
      // التأكد أن المقال منشور فعلاً
      if (!article.isPublished) {
        throw Exception(context.l10n.errorArticleNotPublished);
      }
      
      setState(() {
        _article = article;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = context.l10n.errorFetchingArticle;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _article?.title ?? context.l10n.article,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null || _article == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              _error ?? 'المقال غير متوفر',
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pushReplacementNamed('/main'),
              child: const Text('العودة للرئيسية'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // معلومات الكاتب والوقت
          Row(
            children: [
              CircleAvatar(
                backgroundImage: _article!.author?.getAvatarUrl(PocketBaseClient.instance.pb.baseUrl) != null
                    ? NetworkImage(_article!.author!.getAvatarUrl(PocketBaseClient.instance.pb.baseUrl)!)
                    : null,
                child: _article!.author?.getAvatarUrl(PocketBaseClient.instance.pb.baseUrl) == null
                    ? const Icon(Icons.person)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _article!.author?.name ?? widget.username,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '@${widget.username}',
                      style: TextStyle(
                        color: AppColors.getHintColor(context),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // محتوى المقال
          ArticleContentRenderer(text: _article!.text),
          const SizedBox(height: 40),
          // زر العودة أو الدخول
          Center(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pushReplacementNamed('/main'),
              child: const Text('تصفح تطبيق سجلي'),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
