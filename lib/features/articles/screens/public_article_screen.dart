import 'package:flutter/material.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';
import '../../../models/article.dart';
import '../../../models/user.dart';
import '../services/pb_article_service.dart';
import '../../settings/services/pb_user_service.dart';
import '../widgets/article_content_renderer.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/pocketbase_client.dart';
import '../../home/screens/public_profile_screen.dart';
import 'package:timeago/timeago.dart' as timeago;

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
  final _userService = PbUserService();
  
  Article? _article;
  UserModel? _authorProfile;
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
      
      // محاولة جلب ملف الكاتب العام للحصول على الصورة بدقة في حال لم يتوسع (expand)
      UserModel? profile = article.author;
      if (profile == null || profile.avatar == null) {
        try {
          profile = await _userService.getPublicProfile(widget.username);
        } catch (_) {}
      }
      
      setState(() {
        _article = article;
        _authorProfile = profile;
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
        title: _isLoading || _article == null
            ? Text(context.l10n.article, style: const TextStyle(fontWeight: FontWeight.bold))
            : const SizedBox.shrink(),
        centerTitle: false,
        actions: _isLoading || _article == null
            ? null
            : [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    textDirection: TextDirection.ltr,
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundImage: _authorProfile?.getAvatarUrl(PocketBaseClient.instance.pb.baseURL) != null
                            ? NetworkImage(_authorProfile!.getAvatarUrl(PocketBaseClient.instance.pb.baseURL)!)
                            : null,
                        child: _authorProfile?.getAvatarUrl(PocketBaseClient.instance.pb.baseURL) == null
                            ? const Icon(Icons.person, size: 18)
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _authorProfile?.name ?? widget.username,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '@${widget.username}',
                            style: TextStyle(
                              color: AppColors.getHintColor(context),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
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
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            decoration: BoxDecoration(
              color: AppColors.getCardBackground(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.getBorder(context).withValues(alpha: 0.5),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 48,
                  color: AppColors.alert,
                ),
                const SizedBox(height: 16),
                const Text(
                  'لم يعد هذا المقال متاحاً..',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PublicProfileScreen(usernameOrId: widget.username),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  child: const Text(
                    'قم بالاطلاع على مقالات الكاتب المنشورة',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final hasImage = _article!.image != null && _article!.image!.isNotEmpty;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // عنوان المقال
            Text(
              _article!.title.isNotEmpty ? _article!.title : 'بدون عنوان',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                height: 1.4,
                color: AppColors.getTextPrimary(context),
              ),
            ),
            const SizedBox(height: 10),
            
            // الكاتب والتاريخ
            Row(
              children: [
                Text(
                  _authorProfile?.name ?? widget.username,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '•',
                  style: TextStyle(color: AppColors.getTextSecondary(context)),
                ),
                const SizedBox(width: 8),
                Text(
                  timeago.format(_article!.createdAt, locale: context.l10n.localeName),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
  
            // غلاف المقال
            if (hasImage) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Image.network(
                    'https://sijilli.pockethost.io/api/files/articles/${_article!.id}/${_article!.image}',
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 200,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
  
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
      ),
    );
  }
}
