import '../../core/utils/json_utils.dart';
import 'user.dart';

class Comment {
  final String id;
  final String articleId;
  final String userId;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Expanded relation
  final UserModel? user;

  Comment({
    required this.id,
    required this.articleId,
    required this.userId,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.user,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    final expand = json['expand'] as Map<String, dynamic>?;
    
    var userData = expand?['user'];
    if (userData is List && userData.isNotEmpty) {
      userData = userData.first;
    }
    final Map<String, dynamic>? userJson = userData is Map<String, dynamic> ? userData : null;

    return Comment(
      id: JsonUtils.parseString(json['id']) ?? '',
      articleId: JsonUtils.parseString(json['article']) ?? '',
      userId: JsonUtils.parseString(json['user']) ?? '',
      content: JsonUtils.parseString(json['content']) ?? '',
      createdAt: JsonUtils.parseDateTime(json['created']) ?? DateTime.now(),
      updatedAt: JsonUtils.parseDateTime(json['updated']) ?? DateTime.now(),
      user: userJson != null ? UserModel.fromJson(userJson) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'article': articleId,
      'user': userId,
      'content': content,
      'created': createdAt.toUtc().toIso8601String(),
      'updated': updatedAt.toUtc().toIso8601String(),
    };
  }
}
