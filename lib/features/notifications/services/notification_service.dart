import 'dart:async';
import 'package:pocketbase/pocketbase.dart';
import '../../../../core/services/pocketbase_client.dart';
import '../../../../models/notification.dart';

class NotificationService {
  final PocketBase _pb = PocketBaseClient.instance.pb;

  Future<List<NotificationModel>> getNotifications({
    int page = 1,
    int perPage = 20,
    String? filter,
  }) async {
    final records = await _pb.collection('notifications').getList(
      page: page,
      perPage: perPage,
      filter: filter,
      sort: '-created',
      expand: 'user',
    );
    return records.items.map((r) => NotificationModel.fromRecord(r)).toList();
  }

  Future<NotificationModel> createNotification({
    required String targetUserId,
    required String title,
    required String message,
    required NotificationType type,
    String? relatedId,
  }) async {
    final body = {
      'user': targetUserId,
      'title': title,
      'message': message,
      'type': type.toValue(),
      'related_id': relatedId,
      'is_read': false,
    };

    print('🔔 [NotificationService] Creating notification for user: $targetUserId');
    print('🔔 [NotificationService] Title: $title, Message: $message, Type: $type');

    try {
      final record = await _pb.collection('notifications').create(body: body);
      print('✅ [NotificationService] Notification created successfully: ${record.id}');
      return NotificationModel.fromRecord(record);
    } catch (e) {
      print('‼️ [NotificationService] Failed to create notification: $e');
      if (e is ClientException) {
        print('‼️ [NotificationService] Response: ${e.response}');
      }
      rethrow;
    }
  }

  Future<void> markAsRead(String notificationId) async {
    await _pb.collection('notifications').update(
      notificationId,
      body: {'is_read': true},
    );
  }

  Future<void> markAllAsRead(String userId) async {
    try {
      // 1. Fetch all unread notifications
      // We limit to 50 to avoid massive updates, or just loop through pages
      final records = await _pb.collection('notifications').getFullList(
        filter: 'user = "$userId" && is_read = false',
      );

      // 2. Batch Update (Process in parallel)
      // PocketBase doesn't have a single "Update All" API yet, so we must iterate.
      // We use Future.wait to speed this up.
      final futures = records.map((r) {
        return _pb.collection('notifications').update(r.id, body: {'is_read': true});
      });

      await Future.wait(futures);
    } catch (e) {
      if (e.toString().contains('isAbort: true')) return;
      print('⚠️ Failed to mark all as read: $e');
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    await _pb.collection('notifications').delete(notificationId);
  }

  Stream<RecordSubscriptionEvent> subscribeToNotifications(String userId) {
    // Return the unsubscribe function or stream controller?
    // PB SDK returns a Stream explicitly for `subscribe` if using the right method, 
    // but `collection.subscribe` usually takes a callback.
    // We'll wrap it in a StreamController if needed, or just let the Provider handle the callback.
    // Actually, let's expose a method to register the callback for simplicity in the Provider.
    
    // However, to keep it clean, let's just return nothing here and let the provider call .subscribe directly
    // or wrap the subscription management here.
    // Let's go with a simple subscribe method that takes a callback.
    return const Stream.empty(); // Placeholder, actual logic in Provider likely easier to manage lifecycle.
  }
  
  // Alternative: Expose subscribe method
  Future<UnsubscribeFunc> subscribe(String userId, void Function(RecordSubscriptionEvent) onEvent) {
    return _pb.collection('notifications').subscribe(
      '*', 
      onEvent,
      filter: 'user = "$userId"',
    );
  }
}
