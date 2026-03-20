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
    };

    final record = await _pb.collection(collectionUsers).create(body: body);
    
    // بعد التسجيل، نقوم بتسجيل الدخول تلقائياً للحصول على التوكن
    // Note: We use the already normalized email here
    final authData = await _pb.collection(collectionUsers).authWithPassword(email.toLowerCase().trim(), password);
    return UserModel.fromJson(authData.record.toJson(), token: authData.token);
  }

  void logout() {
    _pb.authStore.clear();
  }

  Future<void> requestPasswordReset(String email) async {
    await _pb.collection(collectionUsers).requestPasswordReset(email.toLowerCase().trim());
  }

  Future<void> deleteAccount(String userId) async {
    print('🔌 PbAuthService: Requesting user deletion for $userId');
    try {
      // Security Improvement: 
      // All cascading deletes (invitations, follows, reports, etc.) MUST be handled by the backend
      // (e.g. via PocketBase SQLite relations `ON DELETE CASCADE` or OnRecordBeforeDeleteRequest hooks).
      // Doing it from the client is insecure and prone to partial failures.
      
      await _pb.collection(collectionUsers).delete(userId);
      print('🔌 PbAuthService: Delete request completed successfully');
      
    } catch (e) {
      print('🔌 PbAuthService: Delete request FAILED: $e');
      rethrow;
    }
  }
}
