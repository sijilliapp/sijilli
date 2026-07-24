import 'package:pocketbase/pocketbase.dart';
import '../../../core/services/pocketbase_client.dart';
import '../../../models/comment.dart';

class PbCommentService {
  final PocketBase _pb = PocketBaseClient.instance.pb;

  static const String collectionComments = 'comments';

  /// جلب تعليقات مقال محدد مرتبة زمنيّاً من الأقدم إلى الأحدث
  /// مع retry logic لمعالجة حالة إسبات الخادم (cold start)
  Future<List<Comment>> getComments(String articleId) async {
    int retries = 0;
    const maxRetries = 4;
    const retryDelay = Duration(milliseconds: 1500);

    while (true) {
      try {
        final resultList = await _pb.collection(collectionComments).getList(
          page: 1,
          perPage: 200,
          filter: 'article = "$articleId"',
          sort: 'created',
          expand: 'user',
        );
        return resultList.items
            .map((record) => Comment.fromJson(record.toJson()))
            .toList();
      } catch (e) {
        retries++;

        bool isTemporary = false;
        if (e is ClientException) {
          if (e.statusCode == 0 || e.statusCode == 408 || e.statusCode >= 500 || e.isAbort) {
            isTemporary = true;
          }
        } else {
          isTemporary = true;
        }

        if (isTemporary && retries < maxRetries) {
          print('🔄 [PbCommentService] Temporary error for article $articleId (attempt $retries/$maxRetries), retrying...');
          await Future.delayed(retryDelay);
          continue;
        }

        print('PbCommentService getComments error: $e');
        rethrow;
      }
    }
  }

  /// إضافة تعليق جديد
  Future<Comment> createComment({
    required String articleId,
    required String content,
  }) async {
    try {
      final userId = _pb.authStore.record?.id;
      if (userId == null) throw Exception("User not authenticated");

      final body = <String, dynamic>{
        'article': articleId,
        'user': userId,
        'content': content,
      };

      final record = await _pb.collection(collectionComments).create(
        body: body,
        expand: 'user',
      );

      return Comment.fromJson(record.toJson());
    } catch (e) {
      print('PbCommentService createComment error: $e');
      rethrow;
    }
  }

  /// حذف تعليق
  Future<void> deleteComment(String commentId) async {
    try {
      await _pb.collection(collectionComments).delete(commentId);
    } catch (e) {
      print('PbCommentService deleteComment error: $e');
      rethrow;
    }
  }
}
