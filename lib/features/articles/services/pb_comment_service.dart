import 'package:pocketbase/pocketbase.dart';
import '../../../core/services/pocketbase_client.dart';
import '../../../../models/comment.dart';

class PbCommentService {
  final PocketBase _pb = PocketBaseClient.instance.pb;

  static const String collectionComments = 'comments';

  /// جلب تعليقات مقال محدد مرتبة زمنيّاً من الأقدم إلى الأحدث
  Future<List<Comment>> getComments(String articleId) async {
    try {
      final resultList = await _pb.collection(collectionComments).getList(
        page: 1,
        perPage: 200, // جلب كافة التعليقات كحد أقصى
        filter: 'article = "$articleId"',
        sort: 'created', // الأقدم أولاً ليظهر مثل خيط محادثة منسق
        expand: 'user',
      );

      return resultList.items.map((record) => Comment.fromJson(record.toJson())).toList();
    } catch (e) {
      print('PbCommentService getComments error: $e');
      rethrow;
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
