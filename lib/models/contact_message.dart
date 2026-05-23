// 📍 lib/models/contact_message.dart

import 'user.dart';

class ContactMessageModel {
  final String id;
  final String? userId;
  final UserModel? user; // Expanded relation
  final String title;
  final String message;
  final String type; // inquiry, complaint, suggestion, other
  final String status; // new, read, replied, closed
  final DateTime created;
  final DateTime updated;

  ContactMessageModel({
    required this.id,
    this.userId,
    this.user,
    required this.title,
    required this.message,
    required this.type,
    required this.status,
    required this.created,
    required this.updated,
  });

  factory ContactMessageModel.fromJson(Map<String, dynamic> json) {
    UserModel? expandedUser;
    if (json['expand'] != null && json['expand']['user'] != null) {
      expandedUser = UserModel.fromJson(json['expand']['user']);
    }
    
    return ContactMessageModel(
      id: json['id'] ?? '',
      userId: json['user'] ?? '',
      user: expandedUser,
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      type: json['type'] ?? 'other',
      status: json['status'] ?? 'new',
      created: json['created'] != null ? DateTime.parse(json['created']) : DateTime.now(),
      updated: json['updated'] != null ? DateTime.parse(json['updated']) : DateTime.now(),
    );
  }
}
