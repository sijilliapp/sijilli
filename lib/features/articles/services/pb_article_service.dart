import 'package:pocketbase/pocketbase.dart';
import 'package:http/http.dart' as http;
import '../../../core/services/pocketbase_client.dart';
import '../../../models/article.dart';

class PbArticleService {
  final PocketBase _pb = PocketBaseClient.instance.pb;
  
  static const String collectionArticles = 'articles';

  /// جلب المقالات مع التصفية والفرز
  Future<List<Article>> getArticles({
    int page = 1, 
    int perPage = 50, 
    String? authorId,
    bool onlyPublished = true,
  }) async {
    try {
      String filter = '';
      if (authorId != null) {
        filter = 'author = "$authorId"';
      }
      
      if (onlyPublished) {
        if (filter.isNotEmpty) filter += ' && ';
        filter += 'is_published = true';
      }

      final resultList = await _pb.collection(collectionArticles).getList(
        page: page,
        perPage: perPage,
        filter: filter,
        sort: '-updated', // الأكثر تحديثاً أولاً
        expand: 'author',
      );

      return resultList.items.map((record) => Article.fromJson(record.toJson())).toList();
    } catch (e) {
      print('PbArticleService getArticles error: $e');
      rethrow;
    }
  }

  /// جلب مقال واحد بواسطة المعرف (للعامة)
  Future<Article> getArticleById(String id) async {
    try {
      final record = await _pb.collection(collectionArticles).getOne(
        id,
        expand: 'author',
      );
      return Article.fromJson(record.toJson());
    } catch (e) {
      print('PbArticleService getArticleById error: $e');
      rethrow;
    }
  }

  Future<Article> createArticle({
    required String text,
    required bool isPublished,
    bool isDraft = false,
    http.MultipartFile? imageFile,
  }) async {
    try {
      final authorId = _pb.authStore.record?.id;
      if (authorId == null) throw Exception("User not authenticated");

      final body = <String, dynamic>{
        'author': authorId,
        'text': text,
        'is_published': isPublished,
        'is_draft': isDraft,
        'likes': [],
      };

      final List<http.MultipartFile> files = [];
      if (imageFile != null) {
        files.add(imageFile);
      }

      final record = await _pb.collection(collectionArticles).create(
        body: body,
        files: files,
        expand: 'author',
      );

      return Article.fromJson(record.toJson());
    } catch (e) {
      print('PbArticleService createArticle error: $e');
      rethrow;
    }
  }

  /// تحديث المقال
  Future<Article> updateArticle({
    required String id,
    String? text,
    bool? isPublished,
    bool? isDraft,
    http.MultipartFile? imageFile,
    bool removeImage = false,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (text != null) body['text'] = text;
      if (isPublished != null) body['is_published'] = isPublished;
      if (isDraft != null) body['is_draft'] = isDraft;
      if (removeImage) body['image'] = ''; // PocketBase deletes the file if passed an empty string

      final List<http.MultipartFile> files = [];
      if (imageFile != null) {
        files.add(imageFile);
      }

      final record = await _pb.collection(collectionArticles).update(
        id,
        body: body,
        files: files,
        expand: 'author',
      );

      return Article.fromJson(record.toJson());
    } catch (e) {
      print('PbArticleService updateArticle error: $e');
      rethrow;
    }
  }

  /// حذف المقال
  Future<void> deleteArticle(String id) async {
    try {
      await _pb.collection(collectionArticles).delete(id);
    } catch (e) {
      print('PbArticleService deleteArticle error: $e');
      rethrow;
    }
  }

  /// إضافة أو إزالة الإعجاب
  Future<void> toggleLike(String articleId, String userId) async {
    try {
      // 1. Fetch current article likes
      final record = await _pb.collection(collectionArticles).getOne(articleId);
      List<dynamic> currentLikes = record.getListValue<String>('likes');
      
      // 2. Toggle
      if (currentLikes.contains(userId)) {
        currentLikes.remove(userId);
      } else {
        currentLikes.add(userId);
      }

      // 3. Update
      await _pb.collection(collectionArticles).update(articleId, body: {
        'likes': currentLikes,
      });
    } catch (e) {
      print('PbArticleService toggleLike error: $e');
      rethrow;
    }
  }
}
