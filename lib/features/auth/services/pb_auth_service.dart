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
      'emailVisibility': true,
      'password': password,
      'passwordConfirm': passwordConfirm,
      'name': name,
      'phone': phone,
      'isPublic': AppConfig.defaultUserIsPublic,
      'hijri_adjustment': -1,
    };

    final record = await _pb.collection(collectionUsers).create(body: body);
    
    // بعد التسجيل، نقوم بتسجيل الدخول تلقائياً للحصول على التوكن
    // Note: We use the already normalized email here
    final authData = await _pb.collection(collectionUsers).authWithPassword(email.toLowerCase().trim(), password);
    return UserModel.fromJson(authData.record.toJson(), token: authData.token);
  }

  Future<bool> isUsernameAvailable(String username) async {
    try {
      final normalizedUsername = username.toLowerCase().trim();
      final result = await _pb.collection(collectionUsers).getList(
        filter: 'username = "$normalizedUsername"',
        page: 1,
        perPage: 1,
      );
      return result.items.isEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<bool> isEmailAvailable(String email) async {
    try {
      final normalizedEmail = email.toLowerCase().trim();
      final result = await _pb.collection(collectionUsers).getList(
        filter: 'email = "$normalizedEmail"',
        page: 1,
        perPage: 1,
      );
      return result.items.isEmpty;
    } catch (e) {
      return false;
    }
  }

  void logout() {
    _pb.authStore.clear();
  }

  Future<void> requestPasswordReset(String email) async {
    await _pb.collection(collectionUsers).requestPasswordReset(email.toLowerCase().trim());
  }

  Future<void> deleteAccount(String userId) async {
    print('🔌 PbAuthService: Deleting user $userId and all related data');
    try {
      // 1. Delete all INVITATIONS for appointments hosted by this user
      // Reason: You cannot delete an appointment if it has required relations (invitations) pointing to it.
      try {
        final hostedAppointments = await _pb.collection('appointments').getFullList(
          filter: 'host = "$userId"',
        );
        
        for (final appt in hostedAppointments) {
          final relatedInvitations = await _pb.collection('invitations').getFullList(
            filter: 'appointment = "${appt.id}"',
          );
          for (final invite in relatedInvitations) {
             await _pb.collection('invitations').delete(invite.id);
          }
        }
        print('🔌 PbAuthService: Related invitations for hosted appointments deleted');
      } catch (e) {
        print('⚠️ PbAuthService: Error deleting hosted appointment invitations: $e');
      }

      // 2. Delete all FOLLOWS (follower or following)
      // We split this into two queries to avoid complex OR logic permissions issues
      try {
        // 2a. Delete where user is FOLLOWER
        final followingList = await _pb.collection('follows').getFullList(
          filter: 'follower = "$userId"',
        );
        for (final f in followingList) {
          await _pb.collection('follows').delete(f.id);
        }
        
        // 2b. Delete where user is FOLLOWING (target)
        final followerList = await _pb.collection('follows').getFullList(
          filter: 'following = "$userId"',
        );
        for (final f in followerList) {
          await _pb.collection('follows').delete(f.id);
        }
        print('🔌 PbAuthService: Follows deleted');
      } catch (e) {
        print('⚠️ PbAuthService: Error deleting follows: $e');
      }

      // 3. Delete all REPORTS (made by user)
      try {
        final reports = await _pb.collection('reports').getFullList(
          filter: 'reporter = "$userId"',
        );
        for (final r in reports) {
          await _pb.collection('reports').delete(r.id);
        }
        print('🔌 PbAuthService: Reports deleted');
      } catch (e) {
        print('⚠️ PbAuthService: Error deleting reports: $e');
      }

      // 4. Delete all CONTACT MESSAGES
      try {
        final msgs = await _pb.collection('contact_messages').getFullList(
          filter: 'user = "$userId"',
        );
        for (final m in msgs) {
          await _pb.collection('contact_messages').delete(m.id);
        }
        print('🔌 PbAuthService: Contact messages deleted');
      } catch (e) {
        // Collection might not exist yet, ignore
        print('⚠️ PbAuthService: Error deleting contact messages (collection might be missing): $e');
      }

      // 5. Delete all NOTIFICATIONS
      try {
        final notifications = await _pb.collection('notifications').getFullList(
          filter: 'user = "$userId"',
        );
        for (final n in notifications) {
          await _pb.collection('notifications').delete(n.id);
        }
        print('🔌 PbAuthService: Notifications deleted');
      } catch (e) {
        print('⚠️ PbAuthService: Error deleting notifications: $e');
      }

      // 6. Delete all INVITATIONS where user is GUEST
      try {
        final guestInvitations = await _pb.collection('invitations').getFullList(
          filter: 'user = "$userId"',
        );
        for (final invite in guestInvitations) {
          await _pb.collection('invitations').delete(invite.id);
        }
        print('🔌 PbAuthService: Guest invitations deleted');
      } catch (e) {
        print('⚠️ PbAuthService: Error deleting guest invitations: $e');
      }

      // 7. Delete HOSTED APPOINTMENTS (Now safe as children invitations are gone)
      try {
        final appointments = await _pb.collection('appointments').getFullList(
          filter: 'host = "$userId"',
        );
        for (final appt in appointments) {
          await _pb.collection('appointments').delete(appt.id);
        }
        print('🔌 PbAuthService: Hosted appointments deleted');
      } catch (e) {
        print('⚠️ PbAuthService: Error deleting appointments: $e');
      }
      
      // 8. Delete the USER record
      print('🔌 PbAuthService: Deleting user record $userId');
      await _pb.collection(collectionUsers).delete(userId);
      print('🔌 PbAuthService: Delete request completed successfully');
      
    } catch (e) {
      print('🔌 PbAuthService: Delete request FAILED: $e');
      rethrow;
    }
  }
}
