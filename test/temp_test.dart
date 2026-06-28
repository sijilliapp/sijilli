import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';

void main() {
  test('test approved user update likes_count only', () async {
    final pb = PocketBase('https://sijilli.pockethost.io');
    try {
      // 1. Create a temp user with role = approved
      final email = 'temp_approved_${DateTime.now().millisecondsSinceEpoch}@example.com';
      final password = 'password123';
      
      final userRecord = await pb.collection('users').create(body: {
        'email': email,
        'password': password,
        'passwordConfirm': password,
        'username': 'apprv_${DateTime.now().millisecondsSinceEpoch}',
        'name': 'Temp Approved',
        'role': 'approved',
      });
      print('Created temp approved: ${userRecord.id}');

      // 2. Authenticate
      final authData = await pb.collection('users').authWithPassword(email, password);
      print('Authenticated as: ${authData.record.id}');

      // 3. Fetch article
      final resultList = await pb.collection('articles').getList(page: 1, perPage: 1);
      if (resultList.items.isEmpty) {
        print('No articles found');
        return;
      }
      final record = resultList.items.first;
      final currentLikesCount = record.data['likes_count'] ?? 0;
      print('Current likes_count: $currentLikesCount');

      // 4. Try updating likes_count only
      final updatedRecord = await pb.collection('articles').update(record.id, body: {
        'likes_count': currentLikesCount + 1,
      });
      print('SUCCESS! Updated likes_count: ${updatedRecord.data['likes_count']}');

      // Clean up
      await pb.collection('users').delete(authData.record.id);
    } catch (e) {
      print('Error during update: $e');
    }
  });
}
