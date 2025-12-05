class ArticleModel {
  final String id;
  final String content;
  final String authorId;
  final int likesCount;
  final int commentsCount;
  final String? images;
  final bool isPublic;
  final DateTime created;
  final DateTime updated;

  ArticleModel({
    required this.id,
    required this.content,
    required this.authorId,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.images,
    this.isPublic = true,
    required this.created,
    required this.updated,
  });

  factory ArticleModel.fromJson(Map<String, dynamic> json) {
    return ArticleModel(
      id: json['id'] ?? '',
      content: json['content'] ?? '',
      authorId: json['author'] ?? '',
      likesCount: json['likes_count'] ?? 0,
      commentsCount: json['comments_count'] ?? 0,
      images: json['images'],
      isPublic: json['is_public'] ?? true,
      created: DateTime.parse(json['created']),
      updated: DateTime.parse(json['updated']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'author': authorId,
      'likes_count': likesCount,
      'comments_count': commentsCount,
      'images': images,
      'is_public': isPublic,
      'created': created.toIso8601String(),
      'updated': updated.toIso8601String(),
    };
  }
}
