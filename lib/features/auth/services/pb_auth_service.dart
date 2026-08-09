// 📍 lib/features/auth/services/pb_auth_service.dart
// 🔐 خدمة المصادقة عبر PocketBase

import 'package:pocketbase/pocketbase.dart';
import '../../../core/services/pocketbase_client.dart';
import '../../../core/constants/app_config.dart';
import '../../../models/user.dart';

class PbAuthService {
  final PocketBase _pb = PocketBaseClient.instance.pb;
  static const String collectionUsers = 'users';

  Future<UserModel> loginWithEmail({
    required String email,
    required String password,
  }) async {
    final authData = await _pb.collection(collectionUsers).authWithPassword(email.toLowerCase().trim(), password);
    return UserModel.fromJson(authData.record.toJson(), token: authData.token);
  }

  Future<UserModel> loginWithUsername({
    required String username,
    required String password,
  }) async {
    final authData = await _pb.collection(collectionUsers).authWithPassword(username.toLowerCase().trim(), password);
    return UserModel.fromJson(authData.record.toJson(), token: authData.token);
  }

  Future<UserModel> register({
    required String name,
    required String username,
    required String email,
    required String password,
    required String passwordConfirm,
    String? phone,
  }) async {
    final body = {
      'username': username.toLowerCase().trim(),
      'email': email.toLowerCase().trim(),
      'emailVisibility': false, // Privacy: Do not expose email by default
      'password': password,
      'passwordConfirm': passwordConfirm,
      'name': name,
      'phone': phone,
      'isPublic': AppConfig.defaultUserIsPublic,
      'hijri_adjustment': -1,
      'phone_verified': false,
      'role': 'user',
    };

    final record = await _pb.collection(collectionUsers).create(body: body);
    
    // بعد التسجيل، نقوم بتسجيل الدخول تلقائياً للحصول على التوكن وصلاحية الجلسة
    final authData = await _pb.collection(collectionUsers).authWithPassword(email.toLowerCase().trim(), password);
    
    final newUser = UserModel.fromJson(authData.record.toJson(), token: authData.token);

    return newUser;
  }

  void logout() {
    _pb.authStore.clear();
  }

  Future<void> requestPasswordReset(String email) async {
    await _pb.collection(collectionUsers).requestPasswordReset(email.toLowerCase().trim());
  }

  Future<void> changePassword({
    required String userId,
    required String oldPassword,
    required String password,
    required String passwordConfirm,
  }) async {
    final body = {
      'oldPassword': oldPassword,
      'password': password,
      'passwordConfirm': passwordConfirm,
    };
    await _pb.collection(collectionUsers).update(userId, body: body);
  }

  Future<void> deleteAccount(String userId, {Function(String)? onStepComplete}) async {
    print('🔌 PbAuthService: Starting robust user cleanup for $userId');
    try {
      // 1. Friendships
      print('   - Cleaning up friendships...');
      try {
        final friendships = await _pb.collection('friendship').getFullList(
          filter: 'user_a = "$userId" || user_b = "$userId"',
        );
        for (final f in friendships) {
          try { await _pb.collection('friendship').delete(f.id); } catch (_) {}
        }
      } catch (e) { print('     ⚠️ Friendship cleanup error: $e'); }
      onStepComplete?.call('friendship');
      
      // 2. Invitations
      print('   - Cleaning up invitations...');
      try {
        final invitations = await _pb.collection('invitations').getFullList(
          filter: 'user = "$userId"',
        );
        for (final inv in invitations) {
          try { await _pb.collection('invitations').delete(inv.id); } catch (_) {}
        }
      } catch (e) { print('     ⚠️ Invitation cleanup error: $e'); }
      onStepComplete?.call('invitations');
      
      // 3. Notifications
      print('   - Cleaning up notifications...');
      try {
        final notifications = await _pb.collection('notifications').getFullList(
          filter: 'user = "$userId"',
        );
        for (final n in notifications) {
          try { await _pb.collection('notifications').delete(n.id); } catch (_) {}
        }
      } catch (e) { print('     ⚠️ Notification cleanup error: $e'); }
      onStepComplete?.call('notifications');
      
      // 4. Appointments
      print('   - Cleaning up appointments and their invitations...');
      try {
        final appointments = await _pb.collection('appointments').getFullList(
          filter: 'host = "$userId"',
        );
        for (final appt in appointments) {
          try {
            final apptInvites = await _pb.collection('invitations').getFullList(
              filter: 'appointment = "${appt.id}"',
            );
            for (final inv in apptInvites) {
              try { await _pb.collection('invitations').delete(inv.id); } catch (_) {}
            }
            await _pb.collection('appointments').delete(appt.id);
          } catch (_) {}
        }
      } catch (e) { print('     ⚠️ Appointment cleanup error: $e'); }
      onStepComplete?.call('appointments');
      
      // 5. Reports
      print('   - Cleaning up reports...');
      try {
        final reports = await _pb.collection('reports').getFullList(
          filter: 'reporter = "$userId" || (subject_type = "user" && subject_id = "$userId")',
        );
        for (final r in reports) {
          try { await _pb.collection('reports').delete(r.id); } catch (_) {}
        }
      } catch (e) { print('     ⚠️ Reports cleanup error: $e'); }
      onStepComplete?.call('reports');
      
      // 6. Final Step
      print('🔌 PbAuthService: Final Step: Deleting user record $userId...');
      await _pb.collection(collectionUsers).delete(userId);
      onStepComplete?.call('user');
      print('🔌 PbAuthService: Account and all related data deleted successfully');
      
    } catch (e) {
      print('🔌 PbAuthService: FINAL delete request FAILED: $e');
      if (e is ClientException) {
        print('   - Response: ${e.response}');
      }
      rethrow;
    }
  }
}
