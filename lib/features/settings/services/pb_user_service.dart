// 📍 lib/features/settings/services/pb_user_service.dart
// 👤 خدمة المستخدمين عبر PocketBase

import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/pocketbase_client.dart';
import '../../../core/constants/app_config.dart';
import '../../../models/user.dart';
import '../../../models/notification.dart';
import '../../notifications/services/notification_service.dart';
import '../../search/utils/search_filter_builder.dart';

class PbUserService {
  final PocketBase _pb = PocketBaseClient.instance.pb;
  final NotificationService _notificationService = NotificationService();
  static const String collectionUsers = 'users';

  // 🧠 In-memory cache for public profiles to prevent redundant network hits
  static final Map<String, UserModel> _profileCache = {};
  static final Map<String, DateTime> _cacheTime = {};
  static const Duration _cacheDuration = Duration(minutes: 5);

  Future<(UserModel, RecordModel)> updateCurrentUser(Map<String, dynamic> data, {XFile? avatarFile}) async {
    try {
      if (!_pb.authStore.isValid) {
        throw Exception('يجب تسجيل الدخول أولاً');
      }
      
      final userId = _pb.authStore.model?.id;
      if (userId == null) {
        throw Exception('فشل الحصول على معرف المستخدم، يرجى تسجيل الدخول مجدداً');
      }
      final List<http.MultipartFile> files = [];

      if (avatarFile != null) {
        // على الويب: dart:io غير مدعوم — نستخدم readAsBytes دائماً
        // على الموبايل: نستخدم File فقط إذا كان المسار حقيقياً
        final bool useBytes = kIsWeb;

        // 📏 فحص حجم الملف (2MB)
        final int length = useBytes
            ? (await avatarFile.readAsBytes()).length
            : await File(avatarFile.path).length();

        if (length > 2 * 1024 * 1024) {
          throw Exception('حجم الصورة كبير جداً (يجب أن يكون أقل من 2 ميجابايت)');
        }

        if (useBytes) {
          final bytes = await avatarFile.readAsBytes();
          files.add(http.MultipartFile.fromBytes(
            'avatar',
            bytes,
            filename: avatarFile.name,
          ));
        } else {
          files.add(await http.MultipartFile.fromPath(
            'avatar',
            avatarFile.path,
          ));
        }
      }
      
      debugPrint('📝 [UserUpdate] Attempting to update user $userId with data: $data');
      
      RecordModel record;
      try {
        record = await _pb.collection(collectionUsers).update(
          userId, 
          body: data,
          files: files,
        );
      } catch (e) {
        if (e.toString().contains('hideFromSearch')) {
           debugPrint('⚠️ [UserUpdate] hideFromSearch field not found in DB. Retrying without it...');
           final safeData = Map<String, dynamic>.from(data)..remove('hideFromSearch');
           record = await _pb.collection(collectionUsers).update(
             userId, 
             body: safeData,
             files: files,
           );
        } else {
          rethrow;
        }
      }
      
      debugPrint('✅ [UserUpdate] Update successful');
      return (UserModel.fromJson(record.toJson()), record);
    } catch (e) {
      debugPrint('❌ [UserUpdate] Error: $e');
      rethrow;
    }
  }

  Future<List<UserModel>> searchUsers(String query, {int page = 1, int perPage = 10}) async {
    try {
      final filter = SearchFilterBuilder.buildUserSearchFilter(
        query: query,
        showAdmins: AppConfig.showAdminsInSearch,
      );
      
      debugPrint('🔍 [Search] Page: $page, PerPage: $perPage');
      debugPrint('🔍 [Search] URL-encoded Filter: ${Uri.encodeComponent(filter)}');
      debugPrint('🔍 [Search] Raw Filter: $filter');
      
      final resultList = await _pb.collection(collectionUsers).getList(
        filter: filter,
        page: page,
        perPage: perPage,
      );
      
      debugPrint('✅ [Search] Found ${resultList.items.length} users');
      return resultList.items.map((record) => UserModel.fromJson(record.toJson())).toList();
    } catch (e) {
      debugPrint('❌ [Search] Error: $e');
      rethrow;
    }
  }

  /// جلب البيانات العامة لمستخدم عبر اسم المستخدم أو المعرف مع دعم التخزين المؤقت وإعادة المحاولة
  Future<UserModel?> getPublicProfile(String usernameOrId) async {
    // 1. Check Cache first
    if (_profileCache.containsKey(usernameOrId)) {
      final cachedAt = _cacheTime[usernameOrId]!;
      if (DateTime.now().difference(cachedAt) < _cacheDuration) {
        return _profileCache[usernameOrId];
      }
    }

    int retries = 0;
    const maxRetries = 5;
    const retryDelay = Duration(milliseconds: 1500);

    while (true) {
      try {
        final isIdFormat = RegExp(r'^[a-z0-9]{15}$').hasMatch(usernameOrId);
        
        UserModel? user;
        if (isIdFormat) {
          try {
             final record = await _pb.collection(collectionUsers).getOne(usernameOrId);
             user = UserModel.fromJson(record.toJson());
          } catch (e) {
             if (e is ClientException && e.statusCode != 404) rethrow;
          }
        }

        if (user == null) {
          final result = await _pb.collection(collectionUsers).getFirstListItem(
            'username = "$usernameOrId"',
          );
          user = UserModel.fromJson(result.toJson());
        }

        // Update Cache
        _profileCache[usernameOrId] = user;
        _profileCache[user.id] = user;
        _profileCache[user.username] = user;
        
        final now = DateTime.now();
        _cacheTime[usernameOrId] = now;
        _cacheTime[user.id] = now;
        _cacheTime[user.username] = now;
      
        return user;

      } catch (e) {
        retries++;
        
        bool isTemporary = false;
        if (e is ClientException) {
          // Do not retry on 404 Not Found
          if (e.statusCode == 404) {
            debugPrint('⚠️ [PbUserService] User not found ($usernameOrId): $e');
            return null;
          }
          if (e.statusCode == 0 || e.statusCode == 408 || e.statusCode >= 500 || e.isAbort) {
            isTemporary = true;
          }
        } else {
          isTemporary = true;
        }

        if (isTemporary && retries < maxRetries) {
          print('🔄 [PbUserService] Temporary error fetching profile $usernameOrId (attempt $retries/$maxRetries): $e. Retrying in ${retryDelay.inMilliseconds}ms...');
          await Future.delayed(retryDelay);
          continue;
        }

        print('❌ [PbUserService] Definitive error or max retries reached for profile $usernameOrId: $e');
        return null;
      }
    }
  }

  /// التحقق من متابعة مستخدم معين (مقبول فقط)
  Future<bool> isFollowing(String targetUserId) async {
    final status = await getAccreditationStatus(targetUserId);
    return status['status'] == 'accepted';
  }

  /// التحقق من وجود علاقة صداقة متبادلة (كلاهما يتابع الآخر بحالة مقبول)
  Future<bool> isFriend(String targetUserId) async {
    final status = await getAccreditationStatus(targetUserId);
    return status['isFriend'] == true;
  }

  /// التحقق مما إذا كان مستخدم معين يتابعني (بحالة انتظار أو مقبول)
  Future<bool> isUserFollowingMe(String targetUserId) async {
    final status = await getAccreditationStatus(targetUserId);
    return status['isBeingFollowed'] == true;
  }

  /// حذف متابع (إجبار شخص على إلغاء متابعتي)
  Future<void> removeFollower(String targetUserId) async {
    if (!_pb.authStore.isValid) return;
    final userId = _pb.authStore.record!.id;
    final pair = _getPair(userId, targetUserId);
    final isUserA = pair['a'] == userId;

    try {
      final record = await _pb.collection('friendship').getFirstListItem(
        'user_a = "${pair['a']}" && user_b = "${pair['b']}"',
      );
      
      await _pb.collection('friendship').update(record.id, body: {
        'a_status': 'none',
        'b_status': 'none',
        'last_action_by': userId,
      });
    } catch (e) {
      // Record not found
    }
  }

  // 🧠 Queue for preventing 429 Too Many Requests on accreditation check
  static final Queue<MapEntry<String, Completer<Map<String, dynamic>>>> _accreditationQueue = Queue();
  static bool _isProcessingAccreditation = false;

  /// مساعد لترتيب أزواج المستخدمين لضمان سجل واحد في جدول friendship
  Map<String, String> _getPair(String id1, String id2) {
    if (id1.compareTo(id2) < 0) {
      return {'a': id1, 'b': id2};
    } else {
      return {'a': id2, 'b': id1};
    }
  }

  /// جلب حالة الاعتماد الموحدة من جدول friendship
  Future<Map<String, dynamic>> getAccreditationStatus(String targetUserId) async {
    if (!_pb.authStore.isValid) {
      return {'status': 'none', 'isFriend': false, 'isBeingFollowed': false, 'isBlocked': false, 'isBlockingMe': false};
    }

    try {
      final userId = _pb.authStore.record!.id;
      if (userId == targetUserId) return {'status': 'none', 'isFriend': true, 'isBeingFollowed': false, 'isBlocked': false, 'isBlockingMe': false};

      final pair = _getPair(userId, targetUserId);
      
      RecordModel? record;
      try {
        record = await _pb.collection('friendship').getFirstListItem(
          'user_a = "${pair['a']}" && user_b = "${pair['b']}"',
        );
      } catch (e) {
        // Record not found is fine
      }

      if (record == null) {
        return {'status': 'none', 'isFriend': false, 'isBeingFollowed': false, 'isBlocked': false, 'isBlockingMe': false};
      }

      final isUserA = record.getStringValue('user_a') == userId;
      final myStatus = record.getStringValue(isUserA ? 'a_status' : 'b_status');
      final theirStatus = record.getStringValue(isUserA ? 'b_status' : 'a_status');

      return {
        'status': myStatus,
        'isFriend': myStatus == 'accepted' && theirStatus == 'accepted',
        'isBeingFollowed': theirStatus == 'accepted' || theirStatus == 'pending',
        'isBlocked': myStatus == 'blocked',
        'isBlockingMe': theirStatus == 'blocked',
      };
    } catch (e) {
      if (kDebugMode) print('❌ Error fetching friendship status: $e');
      return {'status': 'none', 'isFriend': false, 'isBeingFollowed': false, 'isBlocked': false, 'isBlockingMe': false};
    }
  }

  /// جلب حالات الاعتماد لمجموعة من المستخدمين دفعة واحدة
  Future<List<RecordModel>> fetchFriendships(List<String> targetUserIds) async {
    if (!_pb.authStore.isValid || targetUserIds.isEmpty) return [];
    final userId = _pb.authStore.record!.id;
    
    // بناء فلتر يبحث عن أي علاقة بين المستخدم الحالي وأي من المستخدمين في القائمة
    final idFilter = targetUserIds.map((id) => '(user_a = "$id" || user_b = "$id")').join(' || ');
    final filter = '("$userId" = user_a || "$userId" = user_b) && ($idFilter)';
    
    try {
      return await _pb.collection('friendship').getFullList(filter: filter);
    } catch (e) {
      debugPrint('⚠️ Error fetching batch friendships: $e');
      return [];
    }
  }
  /// اعتماد مستخدم (قبول طلبه أو اعتماد مقترح فوري)
  /// - إذا كان الطرف الآخر بعث طلباً (theirStatus == 'pending') → اعتماد متبادل فوري
  /// - إذا كان is_suggested (يُستدعى صراحة من الواجهة) → اعتماد متبادل فوري
  /// - في كل الأحوال: حالة الطرف الطالب فقط تُضبط على accepted
  Future<void> accreditUser(String targetUserId, {bool isSuggested = false}) async {
    try {
      if (!_pb.authStore.isValid || _pb.authStore.record == null) {
        throw Exception('الجلسة منتهية، يرجى إعادة تسجيل الدخول');
      }
      
      final userId = _pb.authStore.record!.id;
      if (userId == targetUserId) return;

      final pair = _getPair(userId, targetUserId);
      final isUserA = pair['a'] == userId;

      RecordModel? record;
      try {
        final records = await _pb.collection('friendship').getFullList(
          filter: 'user_a = "${pair['a']}" && user_b = "${pair['b']}"',
        );
        if (records.isNotEmpty) record = records.first;
      } catch (e) {
        debugPrint('⚠️ Error checking existing friendship: $e');
      }

      // حالة الطرف الآخر الحالية
      final theirCurrentStatus = record != null
          ? record.getStringValue(isUserA ? 'b_status' : 'a_status')
          : 'none';

      // الاعتماد متبادل فوري فقط في حالتين:
      // 1. الطرف الآخر بعث طلباً مسبقاً (pending)
      // 2. الحساب مقترح (is_suggested) → قبول فوري بلا انتظار
      final theirNewStatus = (theirCurrentStatus == 'pending' || isSuggested)
          ? 'accepted'
          : theirCurrentStatus; // نترك حالته كما هي

      final body = <String, dynamic>{
        'user_a': pair['a'],
        'user_b': pair['b'],
        isUserA ? 'a_status' : 'b_status': 'accepted',
        isUserA ? 'b_status' : 'a_status': theirNewStatus,
        'last_action_by': userId,
      };

      if (record == null) {
        debugPrint('🆕 [Accredit] Creating new friendship record...');
        await _pb.collection('friendship').create(body: body);
      } else {
        debugPrint('📝 [Accredit] Updating existing record (${record.id})...');
        await _pb.collection('friendship').update(record.id, body: body);
      }
      debugPrint('✅ [Accredit] Done');

      // 🔔 إشعار
      final myName = _pb.authStore.record?.data['name'] ?? 'مستخدم';
      final isMutual = theirNewStatus == 'accepted';
      try {
        await _notificationService.createNotification(
          targetUserId: targetUserId,
          title: isMutual ? 'اعتماد متبادل' : 'طلب اعتماد',
          message: isMutual
              ? '$myName قام باعتمادك المتبادل'
              : '$myName يريد اعتمادك',
          type: isMutual ? NotificationType.follow : NotificationType.approvalRequest,
          relatedId: userId,
        );
      } catch (e) {
        debugPrint('⚠️ Failed to send notification: $e');
      }
    } catch (e) {
      debugPrint('🚨 Error in accreditUser: $e');
      rethrow;
    }
  }

  /// التحقق من حالة المتابعة (للتوافق مع الكود القديم)
  Future<String> getFollowStatus(String targetUserId) async {
    final status = await getAccreditationStatus(targetUserId);
    return status['status'] as String;
  }

  /// طلب متابعة أو اتصال
  Future<void> followUser(String targetUserId) async {
    if (!_pb.authStore.isValid) {
      throw Exception('يجب تسجيل الدخول أولاً');
    }
    
    final userId = _pb.authStore.record!.id;
    if (userId == targetUserId) return; 
    
    try {
      final targetUser = await getPublicProfile(targetUserId);
      if (targetUser == null) throw Exception('المستخدم غير موجود');

      // الاعتماد دائماً ينتظر — لا قبول فوري إلا للحسابات المقترحة (is_suggested)
      // is_suggested تُعالَج عبر accreditUser() مباشرة من الواجهة
      const initialStatus = 'pending';
      final pair = _getPair(userId, targetUserId);
      final isUserA = pair['a'] == userId;

      RecordModel? record;
      try {
        record = await _pb.collection('friendship').getFirstListItem(
          'user_a = "${pair['a']}" && user_b = "${pair['b']}"',
        );
      } catch (_) {}

      if (record == null) {
        await _pb.collection('friendship').create(body: {
          'user_a': pair['a'],
          'user_b': pair['b'],
          isUserA ? 'a_status' : 'b_status': initialStatus,
          'last_action_by': userId,
        });
      } else {
        // إذا كان الشخص محظوراً، لا يمكن المتابعة
        final theirStatus = record.getStringValue(isUserA ? 'b_status' : 'a_status');
        if (theirStatus == 'blocked') throw Exception('لا يمكنك متابعة هذا المستخدم');

        await _pb.collection('friendship').update(record.id, body: {
          isUserA ? 'a_status' : 'b_status': initialStatus,
          'last_action_by': userId,
        });
      }

      // 🔔 Trigger Notification
      final myName = _pb.authStore.record?.data['name'] ?? 'مستخدم';
      try {
        await _notificationService.createNotification(
          targetUserId: targetUserId,
          title: initialStatus == 'accepted' ? 'اعتماد جديد' : 'طلب اعتماد',
          message: '$myName ${initialStatus == 'accepted' ? 'بدأ باعتمادك' : 'يريد اعتمادك'}',
          type: initialStatus == 'accepted' ? NotificationType.follow : NotificationType.approvalRequest,
          relatedId: userId,
        );
      } catch (e) {
        print('⚠️ Failed to send notification: $e');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// إلغاء الاتصال أو المتابعة (كسر الاعتماد المتبادل)
  Future<void> unfollowUser(String targetUserId) async {
    if (!_pb.authStore.isValid) return;
    final userId = _pb.authStore.record!.id;
    final pair = _getPair(userId, targetUserId);

    try {
      final record = await _pb.collection('friendship').getFirstListItem(
        'user_a = "${pair['a']}" && user_b = "${pair['b']}"',
      );
      
      debugPrint('🔄 [Friendship] Breaking mutual bond for record: ${record.id}');
      
      // كسر الاعتماد من الطرفين تماماً لضمان عدم العودة إلا بموافقة جديدة
      await _pb.collection('friendship').update(record.id, body: {
        'a_status': 'none',
        'b_status': 'none',
        'last_action_by': userId,
      });
      debugPrint('✅ [Friendship] Bond broken successfully');

      // 🔔 Trigger Notification to target user that I withdrew/cancelled my accreditation/relationship
      final myName = _pb.authStore.record?.data['name'] ?? 'مستخدم';
      try {
        await _notificationService.createNotification(
          targetUserId: targetUserId,
          title: 'تراجع عن الاعتماد',
          message: '$myName تراجع عن اعتمادك أو طلب اعتمادك',
          type: NotificationType.cancel,
          relatedId: userId,
        );
      } catch (err) {
        debugPrint('⚠️ Failed to send cancel/withdraw notification: $err');
      }
    } catch (e) {
      debugPrint('⚠️ [Friendship] Failed to break bond: $e');
    }
  }

  /// حظر مستخدم
  Future<void> blockUser(String targetUserId) async {
    if (!_pb.authStore.isValid) return;
    final userId = _pb.authStore.record!.id;
    final pair = _getPair(userId, targetUserId);
    final isUserA = pair['a'] == userId;

    try {
      RecordModel? record;
      try {
        record = await _pb.collection('friendship').getFirstListItem(
          'user_a = "${pair['a']}" && user_b = "${pair['b']}"',
        );
      } catch (_) {}

      if (record == null) {
        await _pb.collection('friendship').create(body: {
          'user_a': pair['a'],
          'user_b': pair['b'],
          isUserA ? 'a_status' : 'b_status': 'blocked',
          isUserA ? 'b_status' : 'a_status': 'none', // مسح أي علاقة سابقة
          'last_action_by': userId,
        });
      } else {
        await _pb.collection('friendship').update(record.id, body: {
          isUserA ? 'a_status' : 'b_status': 'blocked',
          isUserA ? 'b_status' : 'a_status': 'none', // مسح أي علاقة سابقة
          'last_action_by': userId,
        });
      }
    } catch (e) {
      rethrow;
    }
  }

  /// جلب المتابَعين (الأشخاص الذين أتابعهم بحالة مقبول)
  Future<List<UserModel>> getFollowedUsers({String? userId}) async {
    try {
      final targetId = userId ?? _pb.authStore.record?.id;
      if (targetId == null) return [];
      
      final records = await _pb.collection('friendship').getFullList(
        filter: '(user_a = "$targetId" && a_status = "accepted") || (user_b = "$targetId" && b_status = "accepted")',
        expand: 'user_a,user_b',
      );

      return records.map((record) {
        final isUserA = record.getStringValue('user_a') == targetId;
        final targetUserJson = record.expand[isUserA ? 'user_b' : 'user_a']?.first.toJson();
        return targetUserJson != null ? UserModel.fromJson(targetUserJson) : null;
      }).whereType<UserModel>().toList();
    } catch (e) {
      return [];
    }
  }

  /// جلب المتابِعين (الأشخاص الذين يتابعونني بحالة مقبول)
  Future<List<UserModel>> getFollowers({String? userId}) async {
    try {
      final targetId = userId ?? _pb.authStore.record?.id;
      if (targetId == null) return [];
      
      final records = await _pb.collection('friendship').getFullList(
        filter: '(user_a = "$targetId" && b_status = "accepted") || (user_b = "$targetId" && a_status = "accepted")',
        expand: 'user_a,user_b',
      );

      return records.map((record) {
        final isUserA = record.getStringValue('user_a') == targetId;
        final targetUserJson = record.expand[isUserA ? 'user_b' : 'user_a']?.first.toJson();
        return targetUserJson != null ? UserModel.fromJson(targetUserJson) : null;
      }).whereType<UserModel>().toList();
    } catch (e) {
      return [];
    }
  }

  /// جلب عدد المتابعين والمتابَعين
  Future<Map<String, int>> getFollowCounts(String userId) async {
    try {
      final results = await Future.wait([
        _pb.collection('friendship').getList(
          filter: '(user_a = "$userId" && b_status = "accepted") || (user_b = "$userId" && a_status = "accepted")',
          page: 1, perPage: 1,
        ),
        _pb.collection('friendship').getList(
          filter: '(user_a = "$userId" && a_status = "accepted") || (user_b = "$userId" && b_status = "accepted")',
          page: 1, perPage: 1,
        ),
        _pb.collection('invitations').getList(
          filter: 'user = "$userId" && post_status = "published" && status = "accepted"',
          page: 1, perPage: 1,
        ),
      ]);

      return {
        'followers': results[0].totalItems,
        'following': results[1].totalItems,
        'appointments': results[2].totalItems,
      };
    } catch (e) {
      return {'followers': 0, 'following': 0, 'appointments': 0};
    }
  }

  /// الرد على طلب المتابعة
  Future<void> respondToFollowRequest(String friendshipId, bool accept) async {
    if (!_pb.authStore.isValid) return;
    final userId = _pb.authStore.record!.id;

    try {
      final record = await _pb.collection('friendship').getOne(friendshipId);
      final isUserA = record.getStringValue('user_a') == userId;

      if (accept) {
        await _pb.collection('friendship').update(friendshipId, body: {
          isUserA ? 'a_status' : 'b_status': 'accepted',
          'last_action_by': userId,
        });
        
        // 🔔 Trigger Notification
        final requesterId = record.getStringValue(isUserA ? 'user_b' : 'user_a');
        final myName = _pb.authStore.record?.data['name'] ?? 'مستخدم';
        try {
          await _notificationService.createNotification(
            targetUserId: requesterId,
            title: 'تم قبول الطلب',
            message: '$myName قَبِل طلب اعتمادك',
            type: NotificationType.follow,
            relatedId: userId,
          );
        } catch (_) {}
      } else {
        await _pb.collection('friendship').update(friendshipId, body: {
          isUserA ? 'a_status' : 'b_status': 'none',
          'last_action_by': userId,
        });
      }
    } catch (e) {
      rethrow;
    }
  }

}
