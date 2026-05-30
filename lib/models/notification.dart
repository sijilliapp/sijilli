import 'package:pocketbase/pocketbase.dart';

enum NotificationType {
  reminder,
  follow,
  cancel,
  invite,
  system,
  approvalRequest,
  visit,
  unknown;

  static NotificationType fromString(String value) {
    switch (value) {
      case 'reminder':
        return NotificationType.reminder;
      case 'follow':
        return NotificationType.follow;
      case 'cancel':
        return NotificationType.cancel;
      case 'invite':
        return NotificationType.invite;
      case 'system':
        return NotificationType.system;
      case 'approval_request':
        return NotificationType.approvalRequest;
      case 'visit':
        return NotificationType.visit;
      default:
        return NotificationType.unknown;
    }
  }

  String toValue() {
    switch (this) {
      case NotificationType.reminder:
        return 'reminder';
      case NotificationType.follow:
        return 'follow';
      case NotificationType.cancel:
        return 'cancel';
      case NotificationType.invite:
        return 'invite';
      case NotificationType.system:
        return 'system';
      case NotificationType.approvalRequest:
        return 'approval_request';
      case NotificationType.visit:
        return 'visit';
      case NotificationType.unknown:
        return 'unknown';
    }
  }
}

class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String message;
  final NotificationType type;
  final String relatedId;
  final bool isRead;
  final DateTime created;
  final DateTime updated;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    required this.relatedId,
    required this.isRead,
    required this.created,
    required this.updated,
  });

  factory NotificationModel.fromRecord(RecordModel record) {
    return NotificationModel(
      id: record.id,
      userId: record.getStringValue('user'),
      title: record.getStringValue('title'),
      message: record.getStringValue('message'),
      // Note: mapping 'type' from DB to 'type' in model
      type: NotificationType.fromString(record.getStringValue('type')), 
      relatedId: record.getStringValue('related_id'),
      isRead: record.getBoolValue('is_read'),
      created: DateTime.parse(record.created),
      updated: DateTime.parse(record.updated),
    );
  }

  NotificationModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? message,
    NotificationType? type,
    String? relatedId,
    bool? isRead,
    DateTime? created,
    DateTime? updated,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      relatedId: relatedId ?? this.relatedId,
      isRead: isRead ?? this.isRead,
      created: created ?? this.created,
      updated: updated ?? this.updated,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user': userId,
      'title': title,
      'message': message,
      'type': type.toValue(),
      'related_id': relatedId,
      'is_read': isRead,
    };
  }
}