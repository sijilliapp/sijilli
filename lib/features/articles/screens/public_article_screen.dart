import 'package:flutter/material.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';
import '../../../models/article.dart';
import '../../../models/user.dart';
import '../services/pb_article_service.dart';
import '../../settings/services/pb_user_service.dart';
import '../widgets/article_content_renderer.dart';
import '../widgets/comment_section.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/services/pocketbase_client.dart';
import '../../home/screens/public_profile_screen.dart';
import 'package:provider/provider.dart';
import '../providers/article_provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/utils/app_date_formatter.dart';
import '../../../core/utils/web_utils.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/widgets/loaders/loading_screen.dart';
import 'package:sijilli/features/articles/widgets/tag_chip.dart';
import '../widgets/collapsible_content.dart';
import 'package:sijilli/core/utils/image_saver_util.dart';

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
  bool _isImageExpanded = false;

  void _showCommentsSheet() {
    if (_article == null) return;
    
    // أخذ القارئ المجهول لصفحة الدخول
    final currentUserId = PocketBaseClient.instance.pb.authStore.record?.id;
    if (currentUserId == null) {
      Navigator.of(context).pushReplacementNamed('/main');
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentSection(article: _article!),
    );
  }

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
      
      // جلب البروفايل والتعليقات بالتوازي لضمان التحضير المسبق وسرعة الاستجابة
      final profileFuture = (article.author == null || article.author?.avatar == null)
          ? _userService.getPublicProfile(widget.username)
          : Future.value(article.author);

      final commentsFuture = Provider.of<ArticleProvider>(context, listen: false).fetchComments(article.id);

      final results = await Future.wait([
        profileFuture.catchError((_) => null),
        commentsFuture.catchError((_) => null),
      ]);

      UserModel? profile = results[0] as UserModel?;
      if (profile == null) {
        profile = article.author;
      }
      
      setState(() {
        _article = article;
        _authorProfile = profile;
        _isLoading = false;
      });

      // تتبع قراءة المقال للجمهور العابر (الزوار المجهولين)
      if (mounted) {
        final currentUserId = PocketBaseClient.instance.pb.authStore.record?.id;
        if (currentUserId == null || currentUserId != article.authorId) {
          try {
            Provider.of<ArticleProvider>(context, listen: false).trackArticleVisit(
              articleId: article.id,
              authorId: article.authorId,
              articleTitle: article.title,
            );
          } catch (e) {
            print('⚠️ Failed to call trackArticleVisit from PublicArticleScreen: $e');
          }
        }
      }
      removeWebLoader();
    } catch (e) {
      setState(() {
        _error = context.l10n.errorFetchingArticle;
        _isLoading = false;
      });
      removeWebLoader();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final fontFamily = settingsProvider.articleFontFamily;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: _isLoading
          ? Scaffold(
              key: const ValueKey('loading'),
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: const BackButton(color: AppColors.primary),
              ),
              body: const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          : Scaffold(
              key: const ValueKey('content'),
              appBar: AppBar(
                title: _article == null
                    ? Text(context.l10n.article, style: const TextStyle(fontWeight: FontWeight.bold))
                    : const SizedBox.shrink(),
                centerTitle: false,
                actions: _article == null
                    ? null
                    : [
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
              body: _buildBody(fontFamily),
            ),
    );
  }

  Widget _buildBody(String? fontFamily) {
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
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth > 800;

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // اللمحة الزمنية
        Row(
          children: [
            Text(
              AppDateFormatter.formatArticleDateTime(_article!.createdAt, context.l10n.localeName),
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
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        'https://sijilli.pockethost.io/api/files/articles/${_article!.id}/${_article!.image}',
                        fit: _isImageExpanded ? BoxFit.contain : BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
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
                            final imageUrl = 'https://sijilli.pockethost.io/api/files/articles/${_article!.id}/${_article!.image}';
                            final success = await ImageSaverUtil.saveImageFromUrl(imageUrl, '${_article!.id}_image.jpg');
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
  
        // محتوى المقال
        CollapsibleContent(
          buttonText: context.l10n.fullArticle,
          child: ArticleContentRenderer(text: _article!.text, fontFamily: fontFamily),
        ),
        
        if (_article!.tags.isNotEmpty) ...[
          const SizedBox(height: 24),
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: _article!.tags.map((tag) => TagChip(tag: tag)).toList(),
          ),
        ],
        
        const SizedBox(height: 20),
        
        // شريط التفاعل (الإعجاب والتعليقات)
        const Divider(),
        Consumer<ArticleProvider>(
          builder: (context, provider, child) {
            final currentUserId = PocketBaseClient.instance.pb.authStore.record?.id;
            
            // البحث عن نسخة المقال المحدثة في المزود
            final innerArticle = provider.articles.firstWhere(
              (a) => a.id == _article!.id, 
              orElse: () => _article!,
            );
            
            final isLiked = innerArticle.likes.contains(currentUserId);
            final commentsCount = provider.getCommentsForArticle(innerArticle.id).length;
            
            return Row(
              children: [
                IconButton(
                  icon: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? AppColors.error : AppColors.getTextSecondary(context),
                  ),
                  onPressed: currentUserId != null ? () {
                    final record = PocketBaseClient.instance.pb.authStore.record;
                    final name = record?.data['name'] ?? record?.data['username'] ?? '';
                    provider.toggleLike(innerArticle.id, currentUserId, likerName: name);
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
                InkWell(
                  onTap: _showCommentsSheet,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
                    child: Text(
                      'عدد التعليقات: $commentsCount',
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
        const SizedBox(height: 30),
        
        // زر العودة أو الدخول
        Center(
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pushReplacementNamed('/main'),
            child: const Text('تصفح تطبيق سجلي'),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );

    if (isDesktop) {
      content = Container(
        margin: const EdgeInsets.symmetric(vertical: 32.0),
        padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 32.0),
        decoration: BoxDecoration(
          color: AppColors.getCardBackground(context),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(
            color: AppColors.getBorder(context).withOpacity(0.5),
            width: 1,
          ),
        ),
        child: content,
      );
    }

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? (screenWidth - 720) / 2 : 16.0,
          vertical: 16.0,
        ),
        child: content,
      ),
    );
  }
}
