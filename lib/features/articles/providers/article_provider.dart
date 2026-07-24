import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../models/article.dart';
import '../../../models/comment.dart';
import '../../../models/notification.dart';
import '../../../models/appointment.dart';
import '../../../core/local/local_db_service.dart';
import '../services/pb_article_service.dart';
import '../services/pb_comment_service.dart';
import '../../notifications/services/notification_service.dart';
import '../../../core/services/pocketbase_client.dart';
import '../../../core/utils/error_helper.dart';

class ArticleProvider extends ChangeNotifier {
  final PbArticleService _articleService = PbArticleService();
  
  List<Article> _articles = [];
  List<Article> _archivedArticles = [];
  List<Article> _trashedArticles = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _articlesErrorMessage;
  String? _commentsErrorMessage;
  
  String? get articlesErrorMessage => _articlesErrorMessage;
  String? get commentsErrorMessage => _commentsErrorMessage;
  
  List<String> _activeFilterTagIds = [];
  List<String> get activeFilterTagIds => _activeFilterTagIds;

  // مقالات المساعدة (من المشرف، مرئية لجميع المستخدمين)
  List<Article> _helpArticles = [];
  List<Article> get helpArticles => _helpArticles;
  bool _isLoadingHelpArticles = false;
  bool get isLoadingHelpArticles => _isLoadingHelpArticles;

  void setActiveFilterTagIds(List<String> tagIds) {
    _activeFilterTagIds = tagIds;
    notifyListeners();
  }

  // هل المستخدم الآن في فلتر "المساعدة"؟ (يُستخدم من main_screen لتمرير isHelpArticle عند إنشاء مقال جديد)
  bool _isHelpFilterActive = false;
  bool get isHelpFilterActive => _isHelpFilterActive;

  void setHelpFilterActive(bool value) {
    _isHelpFilterActive = value;
    notifyListeners();
  }
  
  final PbCommentService _commentService = PbCommentService();
  final Map<String, List<Comment>> _articleComments = {};
  bool _isCommentsLoading = false;

  Map<String, List<Comment>> get articleComments => _articleComments;
  List<Comment> getCommentsForArticle(String articleId) => _articleComments[articleId] ?? [];
  bool get isCommentsLoading => _isCommentsLoading;
  
  // Pagination
  int _currentPage = 1;
  bool _hasMore = true;
  static const int _perPage = 20;

  String? _currentUserId;

  ArticleProvider();

  void update(String? userId) {
    if (_currentUserId != userId) {
      _currentUserId = userId;
      
      // Wipe state when user changes or logs out to prevent data mix-up
      _articles = [];
      _archivedArticles = [];
      _trashedArticles = [];
      _articleComments.clear();
      _activeFilterTagIds = [];
      _helpArticles = [];
      _errorMessage = null;
      _articlesErrorMessage = null;
      _commentsErrorMessage = null;
      _currentPage = 1;
      _hasMore = true;
      
      if (userId != null) {
        _loadLocalArticles();
      } else {
        notifyListeners();
      }
    }
  }

  Future<void> _loadLocalArticles() async {
    final cachedArticles = await LocalDbService.instance.getArticles();
    if (cachedArticles.isNotEmpty) {
      _articles = cachedArticles;
      _sortArticles();
      notifyListeners();
      
      // Batch fetch comments in background for cached articles
      fetchCommentsForArticles(cachedArticles.map((a) => a.id).toList());
    }
  }

  void _sortArticles() {
    _articles.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  List<Article> get articles => _articles.where((a) {
        final isMe = a.authorId == _currentUserId;
        if (isMe) {
          return a.postStatus == PostStatus.published || 
                 a.postStatus == PostStatus.draft || 
                 a.postStatus == PostStatus.written;
        } else {
          return a.postStatus == PostStatus.published;
        }
      }).toList();
  List<Article> get archivedArticles => _archivedArticles;
  List<Article> get trashedArticles => _trashedArticles;
  List<Article> getUserArticles(String authorId) {
    final isMe = authorId == _currentUserId;
    return _articles.where((a) {
      if (a.authorId != authorId) return false;
      if (isMe) {
        return a.postStatus == PostStatus.published || 
               a.postStatus == PostStatus.draft || 
               a.postStatus == PostStatus.written;
      } else {
        return a.postStatus == PostStatus.published;
      }
    }).toList();
  }
  bool get isLoading => _isLoading;
  bool get isInitialLoading => _isLoading && _currentPage == 1 && _articles.isEmpty;
  bool get isFetchingMore => _isLoading && _currentPage > 1;
  String? get errorMessage => _errorMessage;
  bool get hasMore => _hasMore;

  Future<void> fetchArchivedArticles() async {
    if (_currentUserId == null) return;
    _isLoading = true;
    _errorMessage = null;
    _articlesErrorMessage = null;
    notifyListeners();

    try {
      final fetched = await _articleService.getArticles(
        authorId: _currentUserId,
        onlyPublished: false,
        postStatus: 'archived',
      );
      _archivedArticles = fetched;
      _errorMessage = null;
      _articlesErrorMessage = null;
    } catch (e) {
      _articlesErrorMessage = ErrorHelper.getFriendlyErrorMessage(e, defaultMessage: 'فشل تحميل المقالات المؤرشفة.');
      _errorMessage = _articlesErrorMessage;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchTrashedArticles() async {
    if (_currentUserId == null) return;
    _isLoading = true;
    _errorMessage = null;
    _articlesErrorMessage = null;
    notifyListeners();

    try {
      final fetched = await _articleService.getArticles(
        authorId: _currentUserId,
        onlyPublished: false,
        postStatus: 'trash',
      );
      _trashedArticles = fetched;
      _errorMessage = null;
      _articlesErrorMessage = null;
    } catch (e) {
      _articlesErrorMessage = ErrorHelper.getFriendlyErrorMessage(e, defaultMessage: 'فشل تحميل المقالات المحذوفة.');
      _errorMessage = _articlesErrorMessage;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch public articles
  Future<void> fetchPublicArticles({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
      
      // Load from local cache immediately for fast UI response
      final cachedArticles = await LocalDbService.instance.getArticles();
      if (cachedArticles.isNotEmpty) {
        _articles = cachedArticles;
        notifyListeners();
      } else {
        _articles.clear();
      }
      
      _errorMessage = null;
      _articlesErrorMessage = null;
    }

    if (!_hasMore || _isLoading) return;

    _isLoading = true;
    notifyListeners();

    try {
      final fetchedArticles = await _articleService.getArticles(
        page: _currentPage,
        perPage: _perPage,
        onlyPublished: true,
      );

      if (fetchedArticles.length < _perPage) {
        _hasMore = false;
      }

      if (refresh) {
        // Remove old public articles to prevent duplicates, but keep temp ones or unpublished user ones
        // Actually, just merge them!
      }
      
      // Merge with existing
      for (var fetched in fetchedArticles) {
        final idx = _articles.indexWhere((a) => a.id == fetched.id);
        if (idx != -1) {
          _articles[idx] = fetched;
        } else {
          _articles.add(fetched);
        }
      }
      
      _sortArticles();
      await LocalDbService.instance.saveArticles(_articles);
      
      if (fetchedArticles.isNotEmpty) {
        fetchCommentsForArticles(fetchedArticles.map((a) => a.id).toList());
      }
      
      _currentPage++;
      _errorMessage = null;
      _articlesErrorMessage = null;
    } catch (e) {
      _articlesErrorMessage = ErrorHelper.getFriendlyErrorMessage(e, defaultMessage: 'فشل تحميل المقالات.');
      _errorMessage = _articlesErrorMessage;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch user specific articles (including drafts if authorId is current user)
  Future<void> fetchUserArticles(String authorId, {bool refresh = false, bool isCurrentUser = false}) async {
    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
      _errorMessage = null;
      _articlesErrorMessage = null;
    }

    if (!_hasMore || _isLoading) return;

    _isLoading = true;
    notifyListeners();

    try {
      final fetchedArticles = await _articleService.getArticles(
        page: _currentPage,
        perPage: _perPage,
        authorId: authorId,
        onlyPublished: !isCurrentUser, // Show unpublished if it's the current user
      );

      if (fetchedArticles.length < _perPage) {
        _hasMore = false;
      }

      if (refresh) {
        // Remove old articles for this author from RAM to prevent duplicates
        _articles.removeWhere((a) => a.authorId == authorId);
      }
      
      // Merge with existing
      for (var fetched in fetchedArticles) {
        final idx = _articles.indexWhere((a) => a.id == fetched.id);
        if (idx != -1) {
          _articles[idx] = fetched;
        } else {
          _articles.add(fetched);
        }
      }
      
      _sortArticles();
      await LocalDbService.instance.saveArticles(_articles);
      
      if (fetchedArticles.isNotEmpty) {
        fetchCommentsForArticles(fetchedArticles.map((a) => a.id).toList());
      }
      
      _currentPage++;
      _errorMessage = null;
      _articlesErrorMessage = null;
    } catch (e) {
      _articlesErrorMessage = ErrorHelper.getFriendlyErrorMessage(e, defaultMessage: 'فشل تحميل المقالات.');
      _errorMessage = _articlesErrorMessage;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// جلب مقالات المساعدة من المشرف (is_help_article = true && author.role = admin)
  Future<void> fetchHelpArticles({bool refresh = false}) async {
    if (_isLoadingHelpArticles) return;
    _isLoadingHelpArticles = true;
    if (refresh) _helpArticles = [];
    notifyListeners();
    try {
      final pb = PocketBaseClient.instance.pb;
      final records = await pb.collection('articles').getFullList(
        filter: 'is_help_article = true && author.role = "admin"',
        expand: 'author,tags',
        sort: '-created',
      );
      _helpArticles = records.map((r) => Article.fromJson({
        ...r.toJson(),
        'expand': r.expand,
      })).toList();
    } catch (e) {
      debugPrint('⚠️ fetchHelpArticles error: \$e');
    } finally {
      _isLoadingHelpArticles = false;
      notifyListeners();
    }
  }

  Future<Article> addArticle({
    required String text,
    bool isPublished = true,
    bool isDraft = false,
    List<String>? tagIds,
    File? imageFile,
    List<File>? audioFiles,
    List<File>? inlineImageFiles,
    bool silent = false,
    Map<String, dynamic>? audioMetadata,
    bool isHelpArticle = false,
  }) async {
    if (!silent) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }
    
    // Optimistic offline creation
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
      final tempArticle = Article(
        id: tempId,
        authorId: await LocalDbService.instance.box.then((b) => b?.get('current_user')?.userId) ?? '',
        text: text,
        postStatus: isPublished ? PostStatus.published : (isDraft ? PostStatus.draft : PostStatus.written),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        likes: [],
        tagIds: tagIds ?? [],
        audioMetadata: audioMetadata,
        // For offline display without image
      );
      
      _articles.insert(0, tempArticle);
      _sortArticles();
      await LocalDbService.instance.saveArticles(_articles);
      notifyListeners();
  
      try {
        http.MultipartFile? multipartFile;
        if (imageFile != null) {
          final String ext = imageFile.path.split('.').last.toLowerCase();
          final String safeExt = (ext.length > 0 && ext.length <= 4) ? ext : 'jpg';
          final String safeFileName = 'image_${DateTime.now().millisecondsSinceEpoch}.$safeExt';
          multipartFile = await http.MultipartFile.fromPath(
            'image',
            imageFile.path,
            filename: safeFileName,
          );
        }
        List<http.MultipartFile>? multipartAudios;
        if (audioFiles != null && audioFiles.isNotEmpty) {
          multipartAudios = [];
          for (final audioFile in audioFiles) {
            final String originalName = audioFile.path.split('/').last;
            final String fileName = Uri.encodeFull(originalName);
            multipartAudios.add(await http.MultipartFile.fromPath(
              'audio',
              audioFile.path,
              filename: fileName,
            ));
          }
        }
        List<http.MultipartFile>? multipartInlineImages;
        if (inlineImageFiles != null && inlineImageFiles.isNotEmpty) {
          multipartInlineImages = [];
          for (final inlineImageFile in inlineImageFiles) {
            final String originalName = inlineImageFile.path.split('/').last;
            final String fileName = Uri.encodeFull(originalName);
            multipartInlineImages.add(await http.MultipartFile.fromPath(
              'images',
              inlineImageFile.path,
              filename: fileName,
            ));
          }
        }
  
        final newArticle = await _articleService.createArticle(
          text: text,
          isPublished: isPublished,
          isDraft: isDraft,
          tagIds: tagIds,
          imageFile: multipartFile,
          audioFiles: multipartAudios,
          inlineImageFiles: multipartInlineImages,
          audioMetadata: audioMetadata,
          isHelpArticle: isHelpArticle,
        );

      // Replace temp with real
      final index = _articles.indexWhere((a) => a.id == tempId);
      if (index != -1) {
        _articles[index] = newArticle;
      } else {
        _articles.insert(0, newArticle);
      }
      _sortArticles();
      await LocalDbService.instance.saveArticles(_articles);
      return newArticle;
    } catch (e) {
      _errorMessage = 'Saved locally: ${_getFriendlyErrorMessage(e)}';
      print('Sync Error: $e');
      return tempArticle;
    } finally {
      if (!silent) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<Article?> updateArticle({
    required String id,
    String? text,
    bool? isPublished,
    bool? isDraft,
    List<String>? tagIds,
    File? imageFile,
    bool removeImage = false,
    List<File>? audioFiles,
    List<String>? existingAudios,
    bool removeAudio = false,
    List<File>? inlineImageFiles,
    List<String>? existingInlineImages,
    bool removeInlineImages = false,
    bool silent = false,
    Map<String, dynamic>? audioMetadata,
  }) async {
    if (!silent) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    final isTemp = id.startsWith('temp_');

    try {
      http.MultipartFile? multipartFile;
      if (imageFile != null) {
        final String ext = imageFile.path.split('.').last.toLowerCase();
        final String safeExt = (ext.length > 0 && ext.length <= 4) ? ext : 'jpg';
        final String safeFileName = 'image_${DateTime.now().millisecondsSinceEpoch}.$safeExt';
        multipartFile = await http.MultipartFile.fromPath(
          'image',
          imageFile.path,
          filename: safeFileName,
        );
      }
      List<http.MultipartFile>? multipartAudios;
      if (audioFiles != null && audioFiles.isNotEmpty) {
        multipartAudios = [];
        for (final audioFile in audioFiles) {
          final String originalName = audioFile.path.split('/').last;
          final String fileName = Uri.encodeFull(originalName);
          multipartAudios.add(await http.MultipartFile.fromPath(
            'audio',
            audioFile.path,
            filename: fileName,
          ));
        }
      }
      List<http.MultipartFile>? multipartInlineImages;
      if (inlineImageFiles != null && inlineImageFiles.isNotEmpty) {
        multipartInlineImages = [];
        for (final inlineImageFile in inlineImageFiles) {
          final String originalName = inlineImageFile.path.split('/').last;
          final String fileName = Uri.encodeFull(originalName);
          multipartInlineImages.add(await http.MultipartFile.fromPath(
            'images',
            inlineImageFile.path,
            filename: fileName,
          ));
        }
      }
 
      Article updatedArticle;
      if (isTemp) {
        updatedArticle = await _articleService.createArticle(
          text: text ?? '',
          isPublished: isPublished ?? false,
          isDraft: isDraft ?? true,
          tagIds: tagIds,
          imageFile: multipartFile,
          audioFiles: multipartAudios,
          inlineImageFiles: multipartInlineImages,
        );
      } else {
        updatedArticle = await _articleService.updateArticle(
          id: id,
          text: text,
          isPublished: isPublished,
          isDraft: isDraft,
          tagIds: tagIds,
          imageFile: multipartFile,
          removeImage: removeImage,
          audioFiles: multipartAudios,
          existingAudios: existingAudios,
          removeAudio: removeAudio,
          inlineImageFiles: multipartInlineImages,
          existingInlineImages: existingInlineImages,
          removeInlineImages: removeInlineImages,
          audioMetadata: audioMetadata,
        );
      }

      final index = _articles.indexWhere((a) => a.id == id);
      if (index != -1) {
        _articles[index] = updatedArticle;
      } else {
        _articles.insert(0, updatedArticle);
      }
      _sortArticles();
      await LocalDbService.instance.saveArticles(_articles);
      return updatedArticle;
    } catch (e) {
      if (isTemp) {
        final index = _articles.indexWhere((a) => a.id == id);
        if (index != -1) {
          final existing = _articles[index];
          final localUpdated = existing.copyWith(
            text: text ?? existing.text,
            tagIds: tagIds ?? existing.tagIds,
          );
          _articles[index] = localUpdated;
          await LocalDbService.instance.saveArticles(_articles);
          return localUpdated;
        }
      }
      _errorMessage = 'Failed to update article: ${_getFriendlyErrorMessage(e)}';
      return null;
    } finally {
      if (!silent) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  String _getFriendlyErrorMessage(dynamic e) {
    final errorStr = e.toString();
    if (errorStr.contains('validation_file_size_limit')) {
      return 'حجم الملف الصوتي كبير جداً. الحد الأقصى المسموح به حالياً على الخادم هو 5 ميجابايت. يرجى زيارة لوحة التحكم PocketBase لزيادة الحد.';
    }
    if (errorStr.contains('validation_file_mime_type')) {
      return 'نوع الملف الصوتي غير مدعوم على الخادم.';
    }
    return '$e';
  }

  /// زيادة عدد القراءات والمشاهدات للمقال
  Future<void> incrementViews(String articleId, {Article? article}) async {
    final index = _articles.indexWhere((a) => a.id == articleId);
    if (index != -1) {
      final oldArticle = _articles[index];
      final newCount = oldArticle.viewsCount + 1;

      // تحديث محلي فوري (Optimistic UI)
      _articles[index] = oldArticle.copyWith(viewsCount: newCount);
      notifyListeners();

      // حفظ التحديث محلياً في قاعدة البيانات المحلية (Hive)
      try {
        await LocalDbService.instance.saveArticles(_articles);
      } catch (e) {
        print('⚠️ Failed to save view count to local DB: $e');
      }

      try {
        await _articleService.incrementViewsCount(articleId, newCount);
      } catch (e) {
        print('⚠️ Failed to sync view count to server: $e');
      }
    } else if (article != null) {
      final newCount = article.viewsCount + 1;
      try {
        await _articleService.incrementViewsCount(articleId, newCount);
      } catch (e) {
        print('⚠️ Failed to sync view count to server: $e');
      }
    }
  }

  /// Toggle Publish Status
  Future<void> togglePublishStatus(String articleId, bool isPublished) async {
    final index = _articles.indexWhere((a) => a.id == articleId);
    if (index == -1) return;

    final article = _articles[index];
    
    // Optimistic UI update
    _articles[index] = article.copyWith(isPublished: isPublished);
    notifyListeners();

    try {
      await _articleService.updateArticle(
        id: articleId,
        isPublished: isPublished,
      );
    } catch (e) {
      // Revert if API fails
      _articles[index] = article;
      _errorMessage = 'Failed to update publish status: $e';
      notifyListeners();
    }
  }

  /// Soft Delete Article
  Future<bool> deleteArticle(String articleId) async {
    final index = _articles.indexWhere((a) => a.id == articleId);
    if (index == -1) return false;

    final target = _articles[index];
    final updatedTarget = target.copyWith(
      postStatus: PostStatus.trash,
      deletedAt: DateTime.now().toUtc(),
    );

    // Optimistic UI update
    _articles.removeAt(index);
    _trashedArticles.insert(0, updatedTarget);
    await LocalDbService.instance.saveArticles(_articles);
    notifyListeners();

    try {
      if (!articleId.startsWith('temp_')) {
        await _articleService.deleteArticle(articleId);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('draft_cursor_base_$articleId');
      await prefs.remove('draft_cursor_extent_$articleId');
      return true;
    } catch (e) {
      // Revert if API fails
      _articles.insert(index, target);
      _trashedArticles.removeWhere((a) => a.id == articleId);
      await LocalDbService.instance.saveArticles(_articles);
      _errorMessage = 'Failed to delete article: $e';
      notifyListeners();
      return false;
    }
  }

  /// Restore Article from Trash
  Future<bool> restoreArticle(String articleId) async {
    final index = _trashedArticles.indexWhere((a) => a.id == articleId);
    if (index == -1) return false;

    final target = _trashedArticles[index];
    final restoredTarget = target.copyWith(
      postStatus: PostStatus.published,
      deletedAt: null,
    );

    // Optimistic UI update
    _trashedArticles.removeAt(index);
    _articles.insert(0, restoredTarget);
    _sortArticles();
    await LocalDbService.instance.saveArticles(_articles);
    notifyListeners();

    try {
      await _articleService.restoreArticle(articleId);
      return true;
    } catch (e) {
      // Revert if API fails
      _articles.removeWhere((a) => a.id == articleId);
      _trashedArticles.insert(index, target);
      await LocalDbService.instance.saveArticles(_articles);
      _errorMessage = 'Failed to restore article: $e';
      notifyListeners();
      return false;
    }
  }

  /// Permanently delete Article
  Future<bool> hardDeleteArticle(String articleId) async {
    final index = _trashedArticles.indexWhere((a) => a.id == articleId);
    if (index == -1) return false;

    final target = _trashedArticles[index];

    // Optimistic UI update
    _trashedArticles.removeAt(index);
    notifyListeners();

    try {
      await _articleService.hardDeleteArticle(articleId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('draft_cursor_base_$articleId');
      await prefs.remove('draft_cursor_extent_$articleId');
      return true;
    } catch (e) {
      // Revert if API fails
      _trashedArticles.insert(index, target);
      _errorMessage = 'Failed to permanently delete article: $e';
      notifyListeners();
      return false;
    }
  }

  /// Toggle Archive Article Status
  Future<bool> toggleArchiveArticle(String articleId, bool archive) async {
    if (archive) {
      final index = _articles.indexWhere((a) => a.id == articleId);
      if (index == -1) return false;

      final target = _articles[index];
      final updatedTarget = target.copyWith(postStatus: PostStatus.archived);

      // Optimistic UI update
      _articles.removeAt(index);
      _archivedArticles.insert(0, updatedTarget);
      await LocalDbService.instance.saveArticles(_articles);
      notifyListeners();

      try {
        await _articleService.updateArticle(
          id: articleId,
          postStatus: 'archived',
        );
        return true;
      } catch (e) {
        // Revert
        _articles.insert(index, target);
        _archivedArticles.removeWhere((a) => a.id == articleId);
        await LocalDbService.instance.saveArticles(_articles);
        _errorMessage = 'Failed to archive article: $e';
        notifyListeners();
        return false;
      }
    } else {
      final index = _archivedArticles.indexWhere((a) => a.id == articleId);
      if (index == -1) return false;

      final target = _archivedArticles[index];
      final restoredTarget = target.copyWith(postStatus: PostStatus.published);

      // Optimistic UI update
      _archivedArticles.removeAt(index);
      _articles.insert(0, restoredTarget);
      _sortArticles();
      await LocalDbService.instance.saveArticles(_articles);
      notifyListeners();

      try {
        await _articleService.updateArticle(
          id: articleId,
          postStatus: 'published',
        );
        return true;
      } catch (e) {
        // Revert
        _articles.removeWhere((a) => a.id == articleId);
        _archivedArticles.insert(index, target);
        await LocalDbService.instance.saveArticles(_articles);
        _errorMessage = 'Failed to restore archived article: $e';
        notifyListeners();
        return false;
      }
    }
  }

  /// Fetch comments for a list of articles in a single batch query
  Future<void> fetchCommentsForArticles(List<String> articleIds) async {
    if (articleIds.isEmpty) return;
    try {
      // Chunk articleIds into batches of 5 to avoid extremely long URL queries
      // which get aborted (isAbort: true, statusCode: 0) by browsers or PocketBase host.
      final List<List<String>> chunks = [];
      const int chunkSize = 5;
      for (int i = 0; i < articleIds.length; i += chunkSize) {
        final end = (i + chunkSize < articleIds.length) ? i + chunkSize : articleIds.length;
        chunks.add(articleIds.sublist(i, end));
      }

      final List<Comment> allComments = [];

      // Fetch all chunks in parallel
      await Future.wait(chunks.map((chunk) async {
        final filterString = chunk.map((id) => 'article = "$id"').join(' || ');
        try {
          final resultList = await PocketBaseClient.instance.pb.collection('comments').getList(
            page: 1,
            perPage: 250, // Safe batch limit per chunk
            filter: filterString,
            expand: 'user',
            skipTotal: true, // Speeds up the query
          );
          final comments = resultList.items.map((record) => Comment.fromJson(record.toJson())).toList();
          allComments.addAll(comments);
        } catch (e) {
          print('⚠️ Error fetching batch comments chunk: $e');
        }
      }));

      // Initialize lists
      for (final id in articleIds) {
        _articleComments[id] = [];
      }
      
      // Group by articleId
      for (final comment in allComments) {
        if (_articleComments.containsKey(comment.articleId)) {
          _articleComments[comment.articleId]!.add(comment);
        } else {
          _articleComments[comment.articleId] = [comment];
        }
      }
      notifyListeners();
    } catch (e) {
      print('⚠️ fetchCommentsForArticles error: $e');
    }
  }

  /// Fetch comments for a specific article
  Future<void> fetchComments(String articleId) async {
    _isCommentsLoading = true;
    _errorMessage = null;
    _commentsErrorMessage = null;
    notifyListeners();

    try {
      final comments = await _commentService.getComments(articleId);
      _articleComments[articleId] = comments;
      _errorMessage = null;
      _commentsErrorMessage = null;
    } catch (e) {
      _commentsErrorMessage = ErrorHelper.getFriendlyErrorMessage(e, defaultMessage: 'فشل تحميل التعليقات.');
      _errorMessage = _commentsErrorMessage;
    } finally {
      _isCommentsLoading = false;
      notifyListeners();
    }
  }

  /// Add a comment to an article and send a notification to the author
  Future<Comment?> addComment({
    required String articleId,
    required String content,
    required String authorId,
    required String articleTitle,
    required String commenterName,
  }) async {
    _errorMessage = null;
    _commentsErrorMessage = null;
    try {
      final newComment = await _commentService.createComment(
        articleId: articleId,
        content: content,
      );

      // Add to local cache list
      if (_articleComments.containsKey(articleId)) {
        _articleComments[articleId]!.add(newComment);
      } else {
        _articleComments[articleId] = [newComment];
      }
      notifyListeners();

      // Trigger a notification to the article author (if commenter is not the author)
      final currentUserId = newComment.userId;
      if (currentUserId != authorId) {
        try {
          final notificationService = NotificationService();
          await notificationService.createNotification(
            targetUserId: authorId,
            title: 'تعليقات',
            message: 'قام $commenterName بالتعليق على مقالك',
            type: NotificationType.system, // use system to bypass constraints
            relatedId: articleId,
          );
        } catch (e) {
          print('⚠️ Failed to send comment notification to author: $e');
        }
      }

      return newComment;
    } catch (e) {
      _commentsErrorMessage = ErrorHelper.getFriendlyErrorMessage(e, defaultMessage: 'فشل إضافة التعليق.');
      _errorMessage = _commentsErrorMessage;
      notifyListeners();
      return null;
    }
  }

  /// Delete a comment
  Future<bool> deleteComment(String articleId, String commentId) async {
    _errorMessage = null;
    _commentsErrorMessage = null;
    try {
      await _commentService.deleteComment(commentId);
      if (_articleComments.containsKey(articleId)) {
        _articleComments[articleId]!.removeWhere((c) => c.id == commentId);
      }
      notifyListeners();
      return true;
    } catch (e) {
      _commentsErrorMessage = ErrorHelper.getFriendlyErrorMessage(e, defaultMessage: 'فشل حذف التعليق.');
      _errorMessage = _commentsErrorMessage;
      notifyListeners();
      return false;
    }
  }

  /// Track anonymous views of articles
  Future<void> trackArticleVisit({
    required String articleId,
    required String authorId,
    required String articleTitle,
  }) async {
    try {
      final now = DateTime.now().toUtc();
      final dateStr = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final startOfDay = '$dateStr 00:00:00';
      
      String deviceName = 'جهاز غير معروف';
      final deviceInfoPlugin = DeviceInfoPlugin();

      if (kIsWeb) {
        final webInfo = await deviceInfoPlugin.webBrowserInfo;
        final userAgent = webInfo.userAgent?.toLowerCase() ?? '';
        final browser = webInfo.browserName.toString().replaceAll('BrowserName.', '');
        String browserName = browser;
        if (browser.isNotEmpty) {
          browserName = browser[0].toUpperCase() + browser.substring(1);
        }
        if (browserName == 'Safari') browserName = 'سفاري';
        if (browserName == 'Chrome') browserName = 'كروم';
        if (browserName == 'Firefox') browserName = 'فايرفوكس';

        if (userAgent.contains('iphone')) {
          deviceName = 'آيفون ($browserName)';
        } else if (userAgent.contains('ipad')) {
          deviceName = 'آيباد ($browserName)';
        } else if (userAgent.contains('android')) {
          deviceName = 'أندرويد ($browserName)';
        } else if (userAgent.contains('macintosh') || userAgent.contains('mac os')) {
          deviceName = 'ماك ($browserName)';
        } else if (userAgent.contains('windows')) {
          deviceName = 'ويندوز ($browserName)';
        } else {
          deviceName = 'متصفح $browserName';
        }
      } else {
        if (Platform.isAndroid) {
          deviceName = 'أندرويد';
        } else if (Platform.isIOS) {
          deviceName = 'آيفون';
        } else if (Platform.isMacOS) {
          deviceName = 'ماك';
        } else if (Platform.isWindows) {
          deviceName = 'ويندوز';
        }
      }

      final notificationService = NotificationService();
      
      // Look for a notification for this article, from this device, created today
      final existing = await notificationService.getNotifications(
        filter: 'user = "$authorId" && type = "visit" && related_id = "$articleId" && message ~ "$deviceName" && created >= "$startOfDay"',
        perPage: 1
      );
      
      if (existing.isEmpty) {
        await notificationService.createNotification(
          targetUserId: authorId,
          title: 'توافد الجمهور',
          message: 'قام $deviceName بقراءة مقالك.',
          type: NotificationType.visit,
          relatedId: articleId, // Store article ID to support direct redirect when tapped!
        );
      }
    } catch (e) {
      print('⚠️ Failed to track anonymous article visit: $e');
    }
  }
}
