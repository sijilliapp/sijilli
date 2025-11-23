class PostModel {
  final String id;
  final String content;
  final String authorId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? likesCount;
  final int? commentsCount;
  final List<String>? images;
  final bool isPublic;

  PostModel({
    required this.id,
    required this.content,
    required this.authorId,
    required this.createdAt,
    required this.updatedAt,
    this.likesCount,
    this.commentsCount,
    this.images,
    this.isPublic = true,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    return PostModel(
      id: json['id'] ?? '',
      content: json['content'] ?? '',
      authorId: json['author'] ?? '',
      createdAt: DateTime.tryParse(json['created'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated'] ?? '') ?? DateTime.now(),
      likesCount: json['likes_count'] ?? 0,
      commentsCount: json['comments_count'] ?? 0,
      images: json['images'] != null ? List<String>.from(json['images']) : null,
      isPublic: json['is_public'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'author': authorId,
      'created': createdAt.toIso8601String(),
      'updated': updatedAt.toIso8601String(),
      'likes_count': likesCount,
      'comments_count': commentsCount,
      'images': images,
      'is_public': isPublic,
    };
  }
}
