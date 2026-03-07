import 'package:pocketbase/pocketbase.dart';
import '../../../core/services/pocketbase_client.dart';

class ContactService {
  final PocketBase _pb = PocketBaseClient.instance.pb;
  static const String collectionName = 'contact_messages';

  Future<void> sendMessage({
    required String title,
    required String message,
    required String type,
  }) async {
    if (!_pb.authStore.isValid) {
      throw Exception('يجب تسجيل الدخول لإرسال رسالة');
    }

    try {
      final userId = _pb.authStore.model!.id;
      
      await _pb.collection(collectionName).create(body: {
        'user': userId,
        'title': title,
        'message': message,
        'type': type,
        'status': 'new',
      });
    } catch (e) {
      throw Exception('فشل إرسال الرسالة: $e');
    }
  }
}
