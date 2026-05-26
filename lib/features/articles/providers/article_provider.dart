import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../models/article.dart';
import '../../../core/local/local_db_service.dart';
import '../services/pb_article_service.dart';

class ArticleProvider extends ChangeNotifier {
  final PbArticleService _articleService = PbArticleService();
  
  List<Article> _articles = [];
  bool _isLoading = false;
  String? _errorMessage;
  
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
    }
  }

  void _sortArticles() {
    _articles.sort((a, b) => b.createdAt.compareTo(a.createdAt));
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
  Future<void> toggleLike(String articleId, String userId) async {
    final index = _articles.indexWhere((a) => a.id == articleId);
    if (index == -1) return;

    final article = _articles[index];
    final currentLikes = List<String>.from(article.likes);
    
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
}
