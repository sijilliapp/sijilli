import 'package:pocketbase/pocketbase.dart';
import '../../../core/services/pocketbase_client.dart';
import '../../../models/tag.dart';

class PbTagService {
  final PocketBase _pb = PocketBaseClient.instance.pb;
  
  static const String collectionTags = 'tags';

  /// Get all tags for the current logged-in user
  Future<List<Tag>> getUserTags() async {
    try {
      final userId = _pb.authStore.record?.id;
      if (userId == null) return [];

      final resultList = await _pb.collection(collectionTags).getList(
        page: 1,
        perPage: 200, // Reasonable maximum for tags
        filter: 'user = "$userId"',
        sort: 'name',
      );

      return resultList.items.map((record) => Tag.fromJson(record.toJson())).toList();
    } catch (e) {
      print('PbTagService getUserTags error: $e');
      rethrow;
    }
  }

  /// Create a new tag in PocketBase
  Future<Tag> createTag({
    required String name,
    required String colorHex,
  }) async {
    try {
      final userId = _pb.authStore.record?.id;
      if (userId == null) throw Exception("User not authenticated");

      final body = <String, dynamic>{
        'name': name,
        'color': colorHex,
        'user': userId,
      };

      final record = await _pb.collection(collectionTags).create(
        body: body,
      );

      return Tag.fromJson(record.toJson());
    } catch (e) {
      print('PbTagService createTag error: $e');
      rethrow;
    }
  }

  /// Update an existing tag in PocketBase
  Future<Tag> updateTag({
    required String tagId,
    required String name,
    required String colorHex,
  }) async {
    try {
      final body = <String, dynamic>{
        'name': name,
        'color': colorHex,
      };

      final record = await _pb.collection(collectionTags).update(
        tagId,
        body: body,
      );

      return Tag.fromJson(record.toJson());
    } catch (e) {
      print('PbTagService updateTag error: $e');
      rethrow;
    }
  }

  /// Delete a tag from PocketBase
  Future<void> deleteTag(String tagId) async {
    try {
      await _pb.collection(collectionTags).delete(tagId);
    } catch (e) {
      print('PbTagService deleteTag error: $e');
      rethrow;
    }
  }
}
