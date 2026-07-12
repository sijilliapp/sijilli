import 'package:pocketbase/pocketbase.dart';

class Broadcast {
  final String id;
  final String title;
  final String content;
  final String type; // 'event' or 'article'
  final DateTime? expiresAt;
  final List<String> targetRoles;
  final DateTime createdAt;
  final DateTime updatedAt;

  Broadcast({
    required this.id,
    required this.title,
    required this.content,
    required this.type,
    this.expiresAt,
    required this.targetRoles,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Broadcast.fromJson(Map<String, dynamic> json) {
    final dynamic rolesRaw = json['target_roles'];
    List<String> roles = [];
    if (rolesRaw is List) {
      roles = rolesRaw.map((e) => e.toString()).toList();
    } else if (rolesRaw is String && rolesRaw.isNotEmpty) {
      roles = [rolesRaw];
    }

    return Broadcast(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      type: json['type'] ?? 'event',
      expiresAt: json['expires_at'] != null && json['expires_at'].toString().isNotEmpty
          ? DateTime.parse(json['expires_at'].toString()).toLocal()
          : null,
      targetRoles: roles,
      createdAt: json['created'] != null
          ? DateTime.parse(json['created'].toString()).toLocal()
          : DateTime.now(),
      updatedAt: json['updated'] != null
          ? DateTime.parse(json['updated'].toString()).toLocal()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'type': type,
      'expires_at': expiresAt?.toUtc().toIso8601String(),
      'target_roles': targetRoles,
    };
  }
}
