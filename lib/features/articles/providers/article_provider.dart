import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../models/article.dart';
import '../../../models/comment.dart';
import '../../../models/notification.dart';
import '../../../core/local/local_db_service.dart';
import '../services/pb_article_service.dart';
import '../services/pb_comment_service.dart';
import '../../notifications/services/notification_service.dart';
import '../../../core/services/pocketbase_client.dart';

class ArticleProvider extends ChangeNotifier {
  final PbArticleService _articleService = PbArticleService();
  
  List<Article> _articles = [];
  bool _isLoading = false;
  String? _errorMessage;
  
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

  ArticleProvider() {
    _loadLocalArticles();
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

  List<Article> get articles => _articles;
  List<Article> getUserArticles(String authorId) => _articles.where((a) => a.authorId == authorId).toList();
  bool get isLoading => _isLoading;
  bool get isInitialLoading => _isLoading && _currentPage == 1 && _articles.isEmpty;
  bool get isFetchingMore => _isLoading && _currentPage > 1;
  String? get errorMessage => _errorMessage;
  bool get hasMore => _hasMore;

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
    } catch (e) {
      _errorMessage = 'Failed to load articles: $e';
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
    } catch (e) {
      _errorMessage = 'Failed to load user articles: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Add a new article
  Future<Article?> addArticle({
    required String text,
    bool isPublished = true,
    bool isDraft = false,
    File? imageFile,
    bool silent = false,
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
        isPublished: isPublished,
        isDraft: isDraft,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        likes: [],
        // For offline display without image
      );
      
      _articles.insert(0, tempArticle);
      _sortArticles();
      await LocalDbService.instance.saveArticles(_articles);
      notifyListeners();
  
      try {
        http.MultipartFile? multipartFile;
        if (imageFile != null) {
          multipartFile = await http.MultipartFile.fromPath('image', imageFile.path);
        }
  
        final newArticle = await _articleService.createArticle(
          text: text,
          isPublished: isPublished,
          isDraft: isDraft,
          imageFile: multipartFile,
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
      _errorMessage = 'Saved locally (sync failed): $e';
      print('Sync Error: $e');
      return tempArticle;
    } finally {
      if (!silent) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Update an existing article
  Future<Article?> updateArticle({
    required String id,
    String? text,
    bool? isPublished,
    bool? isDraft,
    File? imageFile,
    bool removeImage = false,
    bool silent = false,
  }) async {
    if (!silent) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      http.MultipartFile? multipartFile;
      if (imageFile != null) {
        multipartFile = await http.MultipartFile.fromPath('image', imageFile.path);
      }

      final updatedArticle = await _articleService.updateArticle(
        id: id,
        text: text,
        isPublished: isPublished,
        isDraft: isDraft,
        imageFile: multipartFile,
        removeImage: removeImage,
      );

      final index = _articles.indexWhere((a) => a.id == id);
      if (index != -1) {
        _articles[index] = updatedArticle;
      }
      await LocalDbService.instance.saveArticles(_articles);
      return updatedArticle;
    } catch (e) {
      _errorMessage = 'Failed to update article: $e';
      return null;
    } finally {
      if (!silent) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Toggle Like
  Future<void> toggleLike(String articleId, String userId, {String? likerName}) async {
    final index = _articles.indexWhere((a) => a.id == articleId);
    if (index == -1) return;

    final article = _articles[index];
    final currentLikes = List<String>.from(article.likes);
    final isAddingLike = !currentLikes.contains(userId);
    
    // Optimistic UI update
    if (currentLikes.contains(userId)) {
      currentLikes.remove(userId);
    } else {
      currentLikes.add(userId);
    }
    _articles[index] = article.copyWith(likes: currentLikes);
    notifyListeners();

    try {
      await _articleService.toggleLike(articleId, userId);
      
      // If we added a like, trigger a notification to the author
      if (isAddingLike && userId != article.authorId && likerName != null && likerName.isNotEmpty) {
        try {
          final notificationService = NotificationService();
          await notificationService.createNotification(
            targetUserId: article.authorId,
            title: 'إعجابات',
            message: 'لقد سجل $likerName إعجاباً بمقالك.',
            type: NotificationType.system, // use system type to display in screen feed
            relatedId: articleId,
          );
        } catch (e) {
          print('⚠️ Failed to send like notification: $e');
        }
      }
    } catch (e) {
      // Revert if API fails
      _articles[index] = article;
      _errorMessage = 'Failed to toggle like: $e';
      notifyListeners();
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

  /// Delete Article
  Future<bool> deleteArticle(String articleId) async {
    final index = _articles.indexWhere((a) => a.id == articleId);
    if (index == -1) return false;

    // Optimistic UI update
    final deletedArticle = _articles.removeAt(index);
    await LocalDbService.instance.saveArticles(_articles);
    notifyListeners();

    try {
      if (!articleId.startsWith('temp_')) {
        await _articleService.deleteArticle(articleId);
      }
      return true;
    } catch (e) {
      // Revert if API fails
      _articles.insert(index, deletedArticle);
      await LocalDbService.instance.saveArticles(_articles);
      _errorMessage = 'Failed to delete article: $e';
      notifyListeners();
      return false;
    }
  }

  /// Fetch comments for a list of articles in a single batch query
  Future<void> fetchCommentsForArticles(List<String> articleIds) async {
    if (articleIds.isEmpty) return;
    try {
      // Build a PocketBase filter query: article = "id1" || article = "id2" || ...
      final filterString = articleIds.map((id) => 'article = "$id"').join(' || ');
      final resultList = await PocketBaseClient.instance.pb.collection('comments').getList(
        page: 1,
        perPage: 500, // Safe batch limit
        filter: filterString,
        expand: 'user',
      );
      
      final comments = resultList.items.map((record) => Comment.fromJson(record.toJson())).toList();
      
      // Initialize lists
      for (final id in articleIds) {
        _articleComments[id] = [];
      }
      
      // Group by articleId
      for (final comment in comments) {
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
    notifyListeners();

    try {
      final comments = await _commentService.getComments(articleId);
      _articleComments[articleId] = comments;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to load comments: $e';
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
      _errorMessage = 'Failed to add comment: $e';
      notifyListeners();
      return null;
    }
  }

  /// Delete a comment
  Future<bool> deleteComment(String articleId, String commentId) async {
    _errorMessage = null;
    try {
      await _commentService.deleteComment(commentId);
      if (_articleComments.containsKey(articleId)) {
        _articleComments[articleId]!.removeWhere((c) => c.id == commentId);
      }
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete comment: $e';
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
      
      String deviceName = 'متصفح ويب';

      if (!kIsWeb) {
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
