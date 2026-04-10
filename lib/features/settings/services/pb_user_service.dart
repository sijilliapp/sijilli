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

class PbUserService {
  final PocketBase _pb = PocketBaseClient.instance.pb;
  final NotificationService _notificationService = NotificationService();
  static const String collectionUsers = 'users';

  // 🧠 In-memory cache for public profiles to prevent redundant network hits
  static final Map<String, UserModel> _profileCache = {};
  static final Map<String, DateTime> _cacheTime = {};
  static const Duration _cacheDuration = Duration(minutes: 5);

  Future<UserModel> updateCurrentUser(Map<String, dynamic> data, {XFile? avatarFile}) async {
    try {
      if (!_pb.authStore.isValid) {
        throw Exception('يجب تسجيل الدخول أولاً');
      }
      
      final userId = _pb.authStore.record!.id;
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
      
      final record = await _pb.collection(collectionUsers).update(
        userId, 
        body: data,
        files: files,
      );
      
      return UserModel.fromJson(record.toJson());
    } catch (e) {
      rethrow;
    }
  }

  Future<List<UserModel>> searchUsers(String query) async {
    try {
      String filter = '(name ~ "$query" || username ~ "$query")';
      
      if (!AppConfig.showAdminsInSearch) {
        filter += ' && role != "admin"';
      }
      
      // ملاحظة: إذا كانت الأدوار تدار بشكل مختلف في PocketBase، يمكن تعديل هذا الفلتر
      
      final resultList = await _pb.collection(collectionUsers).getList(
        filter: filter,
        page: 1,
        perPage: 20,
      );
      return resultList.items.map((record) => UserModel.fromJson(record.toJson())).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// جلب البيانات العامة لمستخدم عبر اسم المستخدم أو المعرف
  Future<UserModel?> getPublicProfile(String usernameOrId) async {
    // 1. Check Cache first
    if (_profileCache.containsKey(usernameOrId)) {
      final cachedAt = _cacheTime[usernameOrId]!;
      if (DateTime.now().difference(cachedAt) < _cacheDuration) {
        return _profileCache[usernameOrId];
      }
    }

    int retries = 0;
    while (retries < 3) {
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
        // 🔄 Retry Logic
        bool shouldRetry = false;
        
        if (e is ClientException) {
          // Retry on: Network Error (0), Server Error (5xx), or Request Aborted
          if (e.isAbort || e.statusCode == 0 || e.statusCode >= 500) {
            shouldRetry = true;
          }
        } else {
          // Retry on unknown Dart exceptions (e.g. SocketException wrapped)
          shouldRetry = true;
        }

        if (shouldRetry) {
          retries++;
          if (retries >= 3) break; // Give up after max retries
          
          print('🔄 [PbUserService] Error fetching user "$usernameOrId": $e. Retrying ($retries/3)...');
          await Future.delayed(Duration(milliseconds: 500 * retries)); // Exponential backoff
          continue;
        }

        print('⚠️ Failed to fetch public profile for "$usernameOrId": $e');
        return null; // Return null only if definitive failure (e.g. 404)
      }
    }
    return null;
  }

  /// جلب المتابَعين (الأشخاص الذين يتابعهم المستخدم)
  Future<List<UserModel>> getFollowedUsers({String? userId}) async {
    try {
      final targetId = userId ?? _pb.authStore.record?.id;
      if (targetId == null) return [];
      
      // Use getFullList to fetch ALL records, not just first page (default 30)
      final resultList = await _pb.collection('follows').getFullList(
        filter: 'follower = "$targetId" && status = "accepted"',
        expand: 'following',
      );

      return resultList.map((record) {
        try {
          final followingList = record.expand['following'];
          final followedUserJson = (followingList != null && followingList.isNotEmpty) 
              ? followingList.first.toJson() 
              : null;
          
          if (followedUserJson == null) return null;
          return UserModel.fromJson(followedUserJson);
        } catch (e) {
          print('⚠️ Error parsing followed user record ${record.id}: $e');
          return null; // Skip bad record
        }
      }).whereType<UserModel>().toList();
    } catch (e) {
      print('⚠️ Failed to fetch followed users: $e');
      return [];
    }
  }

  /// التحقق من حالة المتابعة (قبول، انتظار، أو لا يوجد)
  Future<String> getFollowStatus(String targetUserId) async {
    try {
      if (!_pb.authStore.isValid) return 'none';
      final userId = _pb.authStore.record!.id;
      
      final result = await _pb.collection('follows').getList(
        filter: 'follower = "$userId" && following = "$targetUserId"',
        page: 1,
        perPage: 1,
      );
      
      if (result.items.isEmpty) return 'none';
      return result.items.first.getStringValue('status'); // 'pending' or 'accepted'
    } catch (e) {
      return 'none';
    }
  }

  /// التحقق من متابعة مستخدم معين (مقبول فقط)
  Future<bool> isFollowing(String targetUserId) async {
    final status = await getFollowStatus(targetUserId);
    return status == 'accepted';
  }

  /// التحقق من وجود علاقة صداقة متبادلة (كلاهما يتابع الآخر بحالة مقبول)
  Future<bool> isFriend(String targetUserId) async {
    try {
      if (!_pb.authStore.isValid) return false;
      final userId = _pb.authStore.record!.id;
      
      // فحص المتابعة من طرفي
      final myFollowStatus = await getFollowStatus(targetUserId);
      if (myFollowStatus != 'accepted') return false;

      // فحص المتابعة من الطرف الآخر
      final result = await _pb.collection('follows').getList(
        filter: 'follower = "$targetUserId" && following = "$userId" && status = "accepted"',
        page: 1,
        perPage: 1,
      );
      
      return result.items.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// التحقق مما إذا كان مستخدم معين يتابعني (بحالة انتظار أو مقبول)
  Future<bool> isUserFollowingMe(String targetUserId) async {
    try {
      if (!_pb.authStore.isValid) return false;
      final userId = _pb.authStore.record!.id;
      
      final result = await _pb.collection('follows').getList(
        filter: 'follower = "$targetUserId" && following = "$userId"', // Removed status = "pending" to check for any follow
        page: 1,
        perPage: 1,
      );
      
      return result.items.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // 🧠 Queue for preventing 429 Too Many Requests on accreditation check
  static final Queue<MapEntry<String, Completer<Map<String, dynamic>>>> _accreditationQueue = Queue();
  static bool _isProcessingAccreditation = false;

  /// جلب حالة الاعتماد الموحدة في طلب واحد لتحسين الأداء
  Future<Map<String, dynamic>> getAccreditationStatus(String targetUserId) {
    if (!_pb.authStore.isValid) {
      return Future.value({'status': 'none', 'isFriend': false, 'isBeingFollowed': false});
    }

    final completer = Completer<Map<String, dynamic>>();
    _accreditationQueue.add(MapEntry(targetUserId, completer));
    _processAccreditationQueue();
    
    return completer.future;
  }

  Future<void> _processAccreditationQueue() async {
    if (_isProcessingAccreditation) return;
    _isProcessingAccreditation = true;

    while (_accreditationQueue.isNotEmpty) {
      final entry = _accreditationQueue.removeFirst();
      final targetUserId = entry.key;
      final completer = entry.value;

      try {
        if (!_pb.authStore.isValid) {
           completer.complete({'status': 'none', 'isFriend': false, 'isBeingFollowed': false});
           continue;
        }
        
        final userId = _pb.authStore.record!.id;

        // جلب السجلات المتعلقة بالطرفين (أنا أتابعه أو هو يتابعني)
        final records = await _pb.collection('follows').getList(
          filter: '(follower = "$userId" && following = "$targetUserId") || (follower = "$targetUserId" && following = "$userId")',
          page: 1,
          perPage: 2,
        );

        String status = 'none';
        bool isBeingFollowed = false;
        bool isFollowingMeBack = false;

        for (var item in records.items) {
          final follower = item.getStringValue('follower');
          final itemStatus = item.getStringValue('status');

          if (follower == userId) {
            status = itemStatus;
          } else {
            isBeingFollowed = true;
            if (itemStatus == 'accepted') {
              isFollowingMeBack = true;
            }
          }
        }

        if (!completer.isCompleted) {
            completer.complete({
              'status': status,
              'isFriend': status == 'accepted' && isFollowingMeBack,
              'isBeingFollowed': isBeingFollowed,
            });
        }
      } catch (e) {
        print('⚠️ Error getting accreditation status for $targetUserId: $e');
        if (!completer.isCompleted) {
            completer.complete({'status': 'none', 'isFriend': false, 'isBeingFollowed': false});
        }
      }

      // Small delay to prevent API rate limits on PocketHost
      await Future.delayed(const Duration(milliseconds: 150));
    }

    _isProcessingAccreditation = false;
  }

  /// اعتماد مستخدم (قبول طلبه ومتابعته بالمقابل)
  Future<void> accreditUser(String targetUserId) async {
    try {
      if (!_pb.authStore.isValid) return;
      final userId = _pb.authStore.record!.id;

      // 1. البحث عن طلب وارد معلق
      final result = await _pb.collection('follows').getList(
        filter: 'follower = "$targetUserId" && following = "$userId" && status = "pending"',
        page: 1,
        perPage: 1,
      );

      if (result.items.isNotEmpty) {
        // إذا وجدنا طلباً معلقاً، نقبله (وهذا سيقوم بالمتابعة العكسية كـ accepted)
        await respondToFollowRequest(result.items.first.id, true);
      } else {
        // إذا لم نجد طلباً معلقاً (مقبول أصلاً)، نقوم بمتابعته مباشرة لتحقيق التبادلية كـ accepted
        final status = await getFollowStatus(targetUserId);
        if (status == 'none') {
            await _pb.collection('follows').create(body: {
              'follower': userId,
              'following': targetUserId,
              'status': 'accepted', // Always accepted during accreditation
            });
            // 🔔 Trigger Notification
            final followerName = _pb.authStore.record?.data['name'] ?? 'مستخدم';
            try {
              await _notificationService.createNotification(
                targetUserId: targetUserId,
                title: 'اعتماد جديد',
                message: '$followerName بدأ باعتمادك المتبادل',
                type: NotificationType.follow,
                relatedId: userId,
              );
            } catch (e) {
              print('⚠️ Failed to send notification: $e');
            }
        }
      }
    } catch (e) {
      print('🚨 Error in accreditUser: $e');
      rethrow;
    }
  }

  Future<void> followUser(String targetUserId) async {
    if (!_pb.authStore.isValid) {
      throw Exception('يجب تسجيل الدخول أولاً للمتابعة');
    }
    
    final userId = _pb.authStore.record!.id;
    if (userId == targetUserId) return; 
    
    try {
      final status = await getFollowStatus(targetUserId);
      if (status != 'none') return;

      final targetUser = await getPublicProfile(targetUserId);
      if (targetUser == null) throw Exception('المستخدم غير موجود');

      final initialStatus = targetUser.isPublic ? 'accepted' : 'pending';

      await _pb.collection('follows').create(body: {
        'follower': userId,
        'following': targetUserId,
        'status': initialStatus,
      });

      // 🔔 Trigger Notification
    final followerName = _pb.authStore.record?.data['name'] ?? 'مستخدم';
    try {
      await _notificationService.createNotification(
        targetUserId: targetUserId,
        title: initialStatus == 'accepted' ? 'اعتماد جديد' : 'طلب اعتماد',
        message: '$followerName ${initialStatus == 'accepted' ? 'بدأ باعتمادك' : 'يريد اعتمادك'}',
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

  /// إلغاء متابعة مستخدم
  Future<void> unfollowUser(String targetUserId) async {
    final userId = _pb.authStore.record!.id;
    
    try {
      final result = await _pb.collection('follows').getList(
        filter: 'follower = "$userId" && following = "$targetUserId"',
        page: 1,
        perPage: 1,
      );
      
      if (result.items.isNotEmpty) {
        await _pb.collection('follows').delete(result.items.first.id);
      }
    } catch (e) {
      rethrow;
    }
  }

  /// حذف متابع (إجبار شخص على إلغاء متابعتي)
  Future<void> removeFollower(String targetUserId) async {
    final userId = _pb.authStore.record!.id;
    
    try {
      final result = await _pb.collection('follows').getList(
        filter: 'follower = "$targetUserId" && following = "$userId"',
        page: 1,
        perPage: 1,
      );
      
      if (result.items.isNotEmpty) {
        await _pb.collection('follows').delete(result.items.first.id);
      }
    } catch (e) {
      rethrow;
    }
  }

  /// جلب المتابِعين (الأشخاص الذين يتابعون المستخدم الحالي أو مستخدم آخر)
  Future<List<UserModel>> getFollowers({String? userId}) async {
    try {
      final targetId = userId ?? _pb.authStore.record?.id;
      if (targetId == null) return [];
      
      // Use getFullList instead of getList to correct pagination issues
      final resultList = await _pb.collection('follows').getFullList(
        filter: 'following = "$targetId" && status = "accepted"',
        expand: 'follower',
      );

      return resultList.map((record) {
        try {
           final followerList = record.expand['follower'];
           final followerJson = (followerList != null && followerList.isNotEmpty) 
              ? followerList.first.toJson() 
              : null;
           
           if (followerJson == null) return null;
           return UserModel.fromJson(followerJson);
        } catch (e) {
           print('⚠️ Error parsing follower record ${record.id}: $e');
           return null;
        }
      }).whereType<UserModel>().toList();
    } catch (e) {
      print('⚠️ Failed to fetch followers: $e');
      return [];
    }
  }

  /// جلب طلبات المتابعة الواردة (للمستخدم الحالي فقط)
  Future<List<RecordModel>> getIncomingFollowRequests() async {
    try {
      if (!_pb.authStore.isValid) return [];
      final userId = _pb.authStore.record!.id;
      
      // Use getFullList
      final resultList = await _pb.collection('follows').getFullList(
        filter: 'following = "$userId" && status = "pending"',
        expand: 'follower',
      );
      
      return resultList;
    } catch (e) {
      return [];
    }
  }

  /// جلب طلبات المتابعة الصادرة (التي أرسلها المستخدم الحالي وينتظر قبولها)
  Future<List<RecordModel>> getOutgoingFollowRequests() async {
    try {
      if (!_pb.authStore.isValid) return [];
      final userId = _pb.authStore.record!.id;
      
      final resultList = await _pb.collection('follows').getFullList(
        filter: 'follower = "$userId" && status = "pending"',
        expand: 'following',
      );
      
      return resultList;
    } catch (e) {
      return [];
    }
  }

  /// جلب عدد المتابعين والمتابَعين
  Future<Map<String, int>> getFollowCounts(String userId) async {
    try {
      final results = await Future.wait([
        _pb.collection('follows').getList(
          filter: 'following = "$userId" && status = "accepted"',
          page: 1,
          perPage: 1,
        ),
        _pb.collection('follows').getList(
          filter: 'follower = "$userId" && status = "accepted"',
          page: 1,
          perPage: 1,
        ),
        _pb.collection('invitations').getList(
          filter: 'user = "$userId" && post_status = "published" && status = "accepted"',
          page: 1,
          perPage: 1,
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

  /// قبول أو رفض طلب متابعة
  Future<void> respondToFollowRequest(String requestId, bool accept) async {
    try {
      if (accept) {
        // 1. قبول الطلب الوارد
        final record = await _pb.collection('follows').update(requestId, body: {'status': 'accepted'});
        
        // 2. المتابعة المتبادلة تلقائياً (Reciprocal Follow)
        try {
          final requesterId = record.getStringValue('follower');
          final currentUserId = record.getStringValue('following');
          
          if (requesterId.isNotEmpty && currentUserId.isNotEmpty) {
             final status = await getFollowStatus(requesterId);
             if (status == 'none') {
                 await _pb.collection('follows').create(body: {
                   'follower': currentUserId,
                   'following': requesterId,
                   'status': 'accepted', // Always accepted for mutual accreditation
                 });
                 
                 // 🔔 Trigger Notification
                 final followerName = _pb.authStore.record?.data['name'] ?? 'مستخدم';
                 try {
                   await _notificationService.createNotification(
                     targetUserId: requesterId,
                     title: 'اعتماد متبادل',
                     message: '$followerName قَبِل طلبك وبادلك الاعتماد',
                     type: NotificationType.follow,
                     relatedId: currentUserId,
                   );
                 } catch (e) {
                   print('⚠️ Failed to send notification: $e');
                 }
             } else if (status == 'pending') {
                 // إذا كان يوجد طلب صادر منا معلق، نقبله فوراً (تحصيل حاصل)
                 final myPendingList = await _pb.collection('follows').getList(
                   filter: 'follower = "$currentUserId" && following = "$requesterId"',
                   page: 1,
                   perPage: 1,
                 );
                 if (myPendingList.items.isNotEmpty) {
                   await _pb.collection('follows').update(myPendingList.items.first.id, body: {'status': 'accepted'});
                 }
             }
          }
        } catch (e) {
          print('⚠️ Reciprocal follow partially failed but main request accepted: $e');
        }
      } else {
        await _pb.collection('follows').delete(requestId);
      }
    } catch (e) {
      print('🚨 Error in respondToFollowRequest: $e');
      rethrow;
    }
  }
}
