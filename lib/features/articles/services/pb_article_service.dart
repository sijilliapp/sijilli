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
    String? postStatus,
  }) async {
    try {
      String filter = '';
      if (authorId != null) {
        filter = 'author = "$authorId"';
      }
      
      if (postStatus != null) {
        if (filter.isNotEmpty) filter += ' && ';
        filter += 'post_status = "$postStatus"';
      } else if (onlyPublished) {
        if (filter.isNotEmpty) filter += ' && ';
        filter += '(post_status = "published" || (post_status = "" && is_published = true))';
      } else {
        if (filter.isNotEmpty) filter += ' && ';
        filter += '(post_status = "published" || post_status = "draft" || post_status = "written" || post_status = "")';
      }

      final resultList = await _pb.collection(collectionArticles).getList(
        page: page,
        perPage: perPage,
        filter: filter,
        sort: '-updated', // الأكثر تحديثاً أولاً
        expand: 'author,tags',
      );

      return resultList.items.map((record) => Article.fromJson(record.toJson())).toList();
    } catch (e) {
      print('PbArticleService getArticles error: $e');
      rethrow;
    }
  }

  /// جلب مقال واحد بواسطة المعرف (للعامة) مع محاولات إعادة المحاولة عند إسبات السيرفر
  Future<Article> getArticleById(String id) async {
    int retries = 0;
    const maxRetries = 5;
    const retryDelay = Duration(milliseconds: 1500);

    while (true) {
      try {
        final record = await _pb.collection(collectionArticles).getOne(
          id,
          expand: 'author,tags',
        );
        return Article.fromJson(record.toJson());
      } catch (e) {
        retries++;
        
        bool isTemporary = false;
        if (e is ClientException) {
          // Retry on connection timeout (408), network issues (0), request aborts, or server wake-up/503 errors
          if (e.statusCode == 0 || e.statusCode == 408 || e.statusCode >= 500 || e.isAbort) {
            isTemporary = true;
          }
        } else {
          isTemporary = true;
        }

        if (isTemporary && retries < maxRetries) {
          print('🔄 [PbArticleService] Temporary error fetching article $id (attempt $retries/$maxRetries): $e. Retrying in ${retryDelay.inMilliseconds}ms...');
          await Future.delayed(retryDelay);
          continue;
        }
        
        print('❌ [PbArticleService] Definitive error or max retries reached for article $id: $e');
        rethrow;
      }
    }
  }

  Future<Article> createArticle({
    required String text,
    required bool isPublished,
    bool isDraft = false,
    String? postStatus,
    List<String>? tagIds,
    http.MultipartFile? imageFile,
    List<http.MultipartFile>? audioFiles,
  }) async {
    try {
      final authorId = _pb.authStore.record?.id;
      if (authorId == null) throw Exception("User not authenticated");

      String resolvedStatus = 'written';
      if (postStatus != null) {
        resolvedStatus = postStatus;
      } else if (isPublished) {
        resolvedStatus = 'published';
      } else if (isDraft) {
        resolvedStatus = 'draft';
      }

      final body = <String, dynamic>{
        'author': authorId,
        'text': text,
        'post_status': resolvedStatus,
        'is_published': isPublished,
        'is_draft': isDraft,
        'likes': [],
        if (tagIds != null) 'tags': tagIds,
      };

      final List<http.MultipartFile> files = [];
      if (imageFile != null) {
        files.add(imageFile);
      }
      if (audioFiles != null) {
        files.addAll(audioFiles);
      }

      final record = await _pb.collection(collectionArticles).create(
        body: body,
        files: files,
        expand: 'author,tags',
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
    String? postStatus,
    List<String>? tagIds,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    http.MultipartFile? imageFile,
    bool removeImage = false,
    List<http.MultipartFile>? audioFiles,
    List<String>? existingAudios,
    bool removeAudio = false,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (text != null) body['text'] = text;
      
      if (postStatus != null) {
        body['post_status'] = postStatus;
        body['is_published'] = postStatus == 'published';
        body['is_draft'] = postStatus == 'draft';
      } else {
        if (isPublished != null) {
          body['is_published'] = isPublished;
          body['post_status'] = isPublished ? 'published' : 'written';
          if (!isPublished) {
            body['is_draft'] = false;
          }
        }
        if (isDraft != null) {
          body['is_draft'] = isDraft;
          body['post_status'] = isDraft ? 'draft' : 'written';
          if (isDraft) {
            body['is_published'] = false;
          }
        }
      }

      if (deletedAt != null) {
        body['deleted_at'] = deletedAt.toUtc().toIso8601String();
      } else if (clearDeletedAt) {
        body['deleted_at'] = '';
      }

      if (removeImage) body['image'] = ''; // PocketBase deletes the file if passed an empty string
      if (existingAudios != null) {
        if (existingAudios.isEmpty) {
          body['audio'] = '';
        } else {
          body['audio'] = existingAudios;
        }
      } else if (removeAudio) {
        body['audio'] = '';
      }
      if (tagIds != null) body['tags'] = tagIds;
 
      final List<http.MultipartFile> files = [];
      if (imageFile != null) {
        files.add(imageFile);
      }
      if (audioFiles != null) {
        files.addAll(audioFiles);
      }

      final record = await _pb.collection(collectionArticles).update(
        id,
        body: body,
        files: files,
        expand: 'author,tags',
      );

      return Article.fromJson(record.toJson());
    } catch (e) {
      print('PbArticleService updateArticle error: $e');
      rethrow;
    }
  }

  /// حذف المقال (حذف سوفت)
  Future<void> deleteArticle(String id) async {
    try {
      await _pb.collection(collectionArticles).update(id, body: {
        'post_status': 'trash',
        'deleted_at': DateTime.now().toUtc().toIso8601String(),
        'is_published': false,
        'is_draft': false,
      });
    } catch (e) {
      print('PbArticleService deleteArticle error: $e');
      rethrow;
    }
  }

  /// استعادة المقال من المحذوفات
  Future<Article> restoreArticle(String id) async {
    try {
      final record = await _pb.collection(collectionArticles).update(id, body: {
        'post_status': 'published',
        'deleted_at': '',
        'is_published': true,
        'is_draft': false,
      }, expand: 'author');
      return Article.fromJson(record.toJson());
    } catch (e) {
      print('PbArticleService restoreArticle error: $e');
      rethrow;
    }
  }

  /// الحذف النهائي الفعلي للمقال
  Future<void> hardDeleteArticle(String id) async {
    try {
      await _pb.collection(collectionArticles).delete(id);
    } catch (e) {
      print('PbArticleService hardDeleteArticle error: $e');
      rethrow;
    }
  }

  /// زيادة عدد القراءات والمشاهدات للمقال
  Future<void> incrementViewsCount(String articleId, int newCount) async {
    try {
      await _pb.collection(collectionArticles).update(articleId, body: {
        'likes_count': newCount,
      });
    } catch (e) {
      print('PbArticleService incrementViewsCount error: $e');
      rethrow;
    }
  }
}
