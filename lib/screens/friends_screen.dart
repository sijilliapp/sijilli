import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/connectivity_service.dart';
import '../config/constants.dart';
import '../utils/arabic_search_utils.dart';
import 'user_profile_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AuthService _authService = AuthService();
  final ConnectivityService _connectivityService = ConnectivityService();

  // قوائم البيانات
  List<UserModel> _followers = [];
  List<UserModel> _following = [];
  List<UserModel> _filteredFollowers = [];
  List<UserModel> _filteredFollowing = [];
  List<UserModel> _pendingRequests = []; // طلبات الصداقة الواردة (pending_received)
  List<UserModel> _sentRequests = []; // طلبات الصداقة المرسلة (pending_sent)
  
  // خريطة حالات المتابعة (userId -> followRecord)
  Map<String, Map<String, dynamic>> _followersStatus = {}; // من يتابعونني
  Map<String, Map<String, dynamic>> _followingStatus = {}; // من أتابعهم
  Map<String, Map<String, dynamic>> _pendingRequestsStatus = {}; // حالات الطلبات الواردة
  Map<String, Map<String, dynamic>> _sentRequestsStatus = {}; // حالات الطلبات المرسلة

  // حالات التحميل
  bool _isLoadingFollowers = false;
  bool _isLoadingFollowing = false;
  bool _isOnline = true;

  // البحث
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPendingRequests(); // جلب الطلبات الواردة
    _loadSentRequests(); // جلب الطلبات المرسلة
    _loadFollowers();
    _loadFollowing();
    _listenToConnectivity();
  }

  void _listenToConnectivity() {
    _connectivityService.onConnectivityChanged.listen((isConnected) {
      if (mounted) {
        setState(() => _isOnline = isConnected);
        if (isConnected) {
          // Refresh data when coming back online
          _loadPendingRequests();
          _loadSentRequests();
          _loadFollowers();
          _loadFollowing();
        }
      }
    });
  }

  // تحميل طلبات الصداقة الواردة (pending_received)
  Future<void> _loadPendingRequests() async {
    try {
      final currentUserId = _authService.currentUser?.id;
      if (currentUserId == null) return;

      // جلب الطلبات الواردة
      final pendingRecords = await _authService.pb
          .collection(AppConstants.friendshipCollection)
          .getFullList(
        filter: 'following = "$currentUserId" && status = "pending"',
      );

      print('📨 طلبات الصداقة الواردة: ${pendingRecords.length}');

      if (pendingRecords.isNotEmpty) {
        // جلب بيانات المرسلين
        final senderIds = pendingRecords.map((r) => r.data['follower'] as String).toList();
        final sendersFilter = senderIds.map((id) => 'id = "$id"').join(' || ');

        final usersRecords = await _authService.pb
            .collection(AppConstants.usersCollection)
            .getFullList(
          filter: '($sendersFilter)',
          sort: 'name',
        );

        final pendingUsers = usersRecords
            .map((record) => UserModel.fromJson(record.toJson()))
            .toList();

        // حفظ حالات الطلبات
        final pendingStatus = <String, Map<String, dynamic>>{};
        for (final record in pendingRecords) {
          final senderId = record.data['follower'] as String;
          pendingStatus[senderId] = {
            'id': record.id,
            'status': 'pending_received',
            'created': record.data['created'],
          };
        }

        if (mounted) {
          setState(() {
            _pendingRequests = pendingUsers;
            _pendingRequestsStatus = pendingStatus;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _pendingRequests = [];
            _pendingRequestsStatus = {};
          });
        }
      }
    } catch (e) {
      print('❌ خطأ في جلب الطلبات الواردة: $e');
    }
  }

  // تحميل طلبات الصداقة المرسلة (pending_sent)
  Future<void> _loadSentRequests() async {
    try {
      final currentUserId = _authService.currentUser?.id;
      if (currentUserId == null) return;

      // جلب الطلبات المرسلة
      final sentRecords = await _authService.pb
          .collection(AppConstants.friendshipCollection)
          .getFullList(
        filter: 'follower = "$currentUserId" && status = "pending"',
      );

      print('📤 طلبات الصداقة المرسلة: ${sentRecords.length}');

      if (sentRecords.isNotEmpty) {
        // جلب بيانات المستقبلين
        final receiverIds = sentRecords.map((r) => r.data['following'] as String).toList();
        final receiversFilter = receiverIds.map((id) => 'id = "$id"').join(' || ');

        final usersRecords = await _authService.pb
            .collection(AppConstants.usersCollection)
            .getFullList(
          filter: '($receiversFilter)',
          sort: 'name',
        );

        final sentUsers = usersRecords
            .map((record) => UserModel.fromJson(record.toJson()))
            .toList();

        // حفظ حالات الطلبات
        final sentStatus = <String, Map<String, dynamic>>{};
        for (final record in sentRecords) {
          final receiverId = record.data['following'] as String;
          sentStatus[receiverId] = {
            'id': record.id,
            'status': 'pending_sent',
            'created': record.data['created'],
          };
        }

        if (mounted) {
          setState(() {
            _sentRequests = sentUsers;
            _sentRequestsStatus = sentStatus;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _sentRequests = [];
            _sentRequestsStatus = {};
          });
        }
      }
    } catch (e) {
      print('❌ خطأ في جلب الطلبات المرسلة: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // تحميل المتابعين (من يتابعونني) - Offline First
  Future<void> _loadFollowers() async {
    if (!mounted) return;

    try {
      // 1. Load from Cache FIRST (instant) ⚡
      await _loadFollowersFromCache();

      // 2. Check internet connection
      final isOnline = await _connectivityService.hasConnection();
      if (!mounted) return;
      setState(() => _isOnline = isOnline);

      // 3. If online, update from PocketHost in background
      if (isOnline && _authService.isAuthenticated) {
        try {
          final currentUserId = _authService.currentUser?.id;
          if (currentUserId == null) return;

          // جلب الأصدقاء (علاقة متبادلة مقبولة)
          // البحث في كلا الاتجاهين
          final followRecords = await _authService.pb
              .collection(AppConstants.friendshipCollection)
              .getFullList(
                filter: '(follower = "$currentUserId" || following = "$currentUserId") && status = "approved"',
              );

          print('📊 عدد سجلات الأصدقاء: ${followRecords.length}');

          // جلب بيانات المستخدمين (الأصدقاء العاديين فقط - role = user)
          if (followRecords.isNotEmpty) {
            // استخراج IDs الأصدقاء (الطرف الآخر من العلاقة)
            final friendIds = followRecords.map((record) {
              final followerId = record.data['follower'] as String;
              final followingId = record.data['following'] as String;
              return followerId == currentUserId ? followingId : followerId;
            }).toSet().toList();
            
            final friendsFilter = friendIds.map((id) => 'id = "$id"').join(' || ');

            print('🔍 فلتر الأصدقاء العاديين: ($friendsFilter) && (role = "user" || role = "")');
            
            // جلب جميع الأصدقاء أولاً
            final allUsersRecords = await _authService.pb
                .collection(AppConstants.usersCollection)
                .getFullList(
                  filter: '($friendsFilter)',
                  sort: 'name',
                );
            
            print('📊 إجمالي الأصدقاء المسترجعين: ${allUsersRecords.length}');
            
            // فلترة العاديين (ليسوا approved أو admin) في الكود
            final usersRecords = allUsersRecords.where((record) {
              final role = record.data['role'] as String?;
              final name = record.data['name'] as String?;
              final isRegular = role != 'approved' && role != 'admin';
              print('   👤 $name: role="$role" -> ${isRegular ? "عادي ✅" : "معتمد/أدمن ❌"}');
              return isRegular;
            }).toList();

            print('📊 عدد الأصدقاء العاديين المسترجعين: ${usersRecords.length}');

            final followers = usersRecords
                .map((record) => UserModel.fromJson(record.toJson()))
                .toList();

            // حفظ حالات المتابعة (استخدام ID الصديق كمفتاح)
            final followersStatus = <String, Map<String, dynamic>>{};
            for (final record in followRecords) {
              final followerId = record.data['follower'] as String;
              final followingId = record.data['following'] as String;
              final friendId = followerId == currentUserId ? followingId : followerId;
              followersStatus[friendId] = {
                'id': record.id,
                'status': record.data['status'] ?? 'pending',
                'created': record.data['created'],
              };
            }

            print('📊 حالات المتابعين: ${followersStatus.length}');

            // Save to Cache for next time ⚡
            await _saveFollowersToCache(followers);

            // Update UI with fresh data
            if (!mounted) return;
            setState(() {
              _followers = followers;
              _filteredFollowers = followers;
              _followersStatus = followersStatus;
              _isLoadingFollowers = false;
            });
          } else {
            // Save empty list to cache
            await _saveFollowersToCache([]);

            if (!mounted) return;
            setState(() {
              _followers = [];
              _filteredFollowers = [];
              _followersStatus = {};
              _isLoadingFollowers = false;
            });
          }
        } catch (e) {
          print('خطأ في تحميل المتابعين من الخادم: $e');
          // Keep showing cached data (already loaded)
          if (mounted) {
            setState(() => _isLoadingFollowers = false);
          }
        }
      } else {
        // Offline - just show cached data (already loaded in step 1)
        if (mounted) {
          setState(() => _isLoadingFollowers = false);
        }
      }
    } catch (e) {
      print('خطأ عام في تحميل المتابعين: $e');
      if (mounted) {
        setState(() {
          _followers = [];
          _filteredFollowers = [];
          _isLoadingFollowers = false;
        });
      }
    }
  }

  // دوال Cache للمتابعين
  Future<void> _loadFollowersFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = _authService.currentUser?.id;
      if (userId == null) return;

      final cachedData = prefs.getString('followers_$userId');
      if (cachedData != null) {
        final List<dynamic> jsonList = jsonDecode(cachedData);
        final followers = jsonList.map((json) => UserModel.fromJson(json)).toList();
        if (mounted) {
          setState(() {
            _followers = followers;
            _filteredFollowers = followers;
            _isLoadingFollowers = false;
          });
        }
      }
    } catch (e) {
      // Ignore cache errors
      print('خطأ في تحميل المتابعين من الذاكرة: $e');
    }
  }

  Future<void> _saveFollowersToCache(List<UserModel> followers) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = _authService.currentUser?.id;
      if (userId == null) return;

      final jsonList = followers.map((follower) => follower.toJson()).toList();
      await prefs.setString('followers_$userId', jsonEncode(jsonList));
    } catch (e) {
      // Ignore cache errors
      print('خطأ في حفظ المتابعين في الذاكرة: $e');
    }
  }

  // تحميل المتبوعين (من أتابعهم) - Offline First
  Future<void> _loadFollowing() async {
    if (!mounted) return;

    try {
      // 1. Load from Cache FIRST (instant) ⚡
      await _loadFollowingFromCache();

      // 2. Check internet connection
      final isOnline = await _connectivityService.hasConnection();
      if (!mounted) return;
      setState(() => _isOnline = isOnline);

      // 3. If online, update from PocketHost in background
      if (isOnline && _authService.isAuthenticated) {
        try {
          final currentUserId = _authService.currentUser?.id;
          if (currentUserId == null) return;

          // جلب الأصدقاء المعتمدين (علاقة متبادلة مقبولة)
          // البحث في كلا الاتجاهين
          final followRecords = await _authService.pb
              .collection(AppConstants.friendshipCollection)
              .getFullList(
                filter: '(follower = "$currentUserId" || following = "$currentUserId") && status = "approved"',
              );

          print('📊 عدد سجلات الأصدقاء المعتمدين: ${followRecords.length}');

          // جلب بيانات المستخدمين (الأصدقاء المعتمدين فقط - role = approved)
          if (followRecords.isNotEmpty) {
            // استخراج IDs الأصدقاء (الطرف الآخر من العلاقة)
            final friendIds = followRecords.map((record) {
              final followerId = record.data['follower'] as String;
              final followingId = record.data['following'] as String;
              return followerId == currentUserId ? followingId : followerId;
            }).toSet().toList();
            
            final friendsFilter = friendIds.map((id) => 'id = "$id"').join(' || ');

            print('🔍 فلتر الأصدقاء المعتمدين: ($friendsFilter) && role = "approved"');
            
            // جلب جميع الأصدقاء أولاً
            final allUsersRecords = await _authService.pb
                .collection(AppConstants.usersCollection)
                .getFullList(
                  filter: '($friendsFilter)',
                  sort: 'name',
                );
            
            print('📊 إجمالي الأصدقاء المسترجعين: ${allUsersRecords.length}');
            
            // فلترة المعتمدين في الكود
            final usersRecords = allUsersRecords.where((record) {
              final role = record.data['role'] as String?;
              final name = record.data['name'] as String?;
              final isApproved = role == 'approved';
              print('   👤 $name: role="$role" -> ${isApproved ? "معتمد ✅" : "عادي ❌"}');
              return isApproved;
            }).toList();

            print('📊 عدد الأصدقاء المعتمدين المسترجعين: ${usersRecords.length}');

            final following = usersRecords
                .map((record) => UserModel.fromJson(record.toJson()))
                .toList();

            // حفظ حالات المتابعة (استخدام ID الصديق كمفتاح)
            final followingStatus = <String, Map<String, dynamic>>{};
            for (final record in followRecords) {
              final followerId = record.data['follower'] as String;
              final followingId = record.data['following'] as String;
              final friendId = followerId == currentUserId ? followingId : followerId;
              followingStatus[friendId] = {
                'id': record.id,
                'status': record.data['status'] ?? 'pending',
                'created': record.data['created'],
              };
            }

            print('📊 حالات المتبوعين: ${followingStatus.length}');

            // Save to Cache for next time ⚡
            await _saveFollowingToCache(following);

            // Update UI with fresh data
            if (!mounted) return;
            setState(() {
              _following = following;
              _filteredFollowing = following;
              _followingStatus = followingStatus;
              _isLoadingFollowing = false;
            });
          } else {
            // Save empty list to cache
            await _saveFollowingToCache([]);

            if (!mounted) return;
            setState(() {
              _following = [];
              _filteredFollowing = [];
              _followingStatus = {};
              _isLoadingFollowing = false;
            });
          }
        } catch (e) {
          print('خطأ في تحميل المتبوعين من الخادم: $e');
          // Keep showing cached data (already loaded)
          if (mounted) {
            setState(() => _isLoadingFollowing = false);
          }
        }
      } else {
        // Offline - just show cached data (already loaded in step 1)
        if (mounted) {
          setState(() => _isLoadingFollowing = false);
        }
      }
    } catch (e) {
      print('خطأ عام في تحميل المتبوعين: $e');
      if (mounted) {
        setState(() {
          _following = [];
          _filteredFollowing = [];
          _isLoadingFollowing = false;
        });
      }
    }
  }

  // دوال Cache للمتبوعين
  Future<void> _loadFollowingFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = _authService.currentUser?.id;
      if (userId == null) return;

      final cachedData = prefs.getString('following_$userId');
      if (cachedData != null) {
        final List<dynamic> jsonList = jsonDecode(cachedData);
        final following = jsonList.map((json) => UserModel.fromJson(json)).toList();
        if (mounted) {
          setState(() {
            _following = following;
            _filteredFollowing = following;
            _isLoadingFollowing = false;
          });
        }
      }
    } catch (e) {
      // Ignore cache errors
      print('خطأ في تحميل المتبوعين من الذاكرة: $e');
    }
  }

  Future<void> _saveFollowingToCache(List<UserModel> following) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = _authService.currentUser?.id;
      if (userId == null) return;

      final jsonList = following.map((user) => user.toJson()).toList();
      await prefs.setString('following_$userId', jsonEncode(jsonList));
    } catch (e) {
      // Ignore cache errors
      print('خطأ في حفظ المتبوعين في الذاكرة: $e');
    }
  }

  // فلترة النتائج بناءً على البحث
  void _filterResults(String query) {
    setState(() {
      _searchQuery = query;
      
      if (query.isEmpty) {
        _filteredFollowers = _followers;
        _filteredFollowing = _following;
      } else {
        _filteredFollowers = _followers.where((user) {
          return ArabicSearchUtils.searchInUserFields(
            user.name,
            user.username,
            user.bio ?? '',
            query,
          );
        }).toList();
        
        _filteredFollowing = _following.where((user) {
          return ArabicSearchUtils.searchInUserFields(
            user.name,
            user.username,
            user.bio ?? '',
            query,
          );
        }).toList();
      }
    });
  }

  // الحصول على رابط الصورة الشخصية
  String? _getUserAvatarUrl(UserModel user) {
    if (user.avatar?.isEmpty ?? true) return null;

    // تنظيف اسم الملف من الأقواس والاقتباسات
    final cleanAvatar = user.avatar!.replaceAll('[', '').replaceAll(']', '').replaceAll('"', '');
    return '${AppConstants.pocketbaseUrl}/api/files/${AppConstants.usersCollection}/${user.id}/$cleanAvatar';
  }

  // تحديد لون الطوق حسب نشاط المستخدم
  Color _getUserRingColor(UserModel user) {
    // حالياً: رمادي دائماً في قائمة الأصدقاء
    Color ringColor = Colors.grey.shade400;

    // متاح للتطوير المستقبلي:
    // if (user.verified) ringColor = const Color(0xFF2196F3); // أزرق للمتحققين
    // if (user.isOnline) ringColor = Colors.green; // أخضر للمتصلين
    // if (user.hasActiveAppointment) ringColor = Colors.orange; // برتقالي للنشطين
    // if (user.isPremium) ringColor = Colors.purple; // بنفسجي للمميزين

    return ringColor;
  }

  // الموافقة على طلب صداقة
  Future<void> _approveFollowRequest(String userId, String followRecordId) async {
    try {
      await _authService.pb
          .collection(AppConstants.friendshipCollection)
          .update(followRecordId, body: {'status': 'approved'});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تمت الموافقة على طلب المتابعة'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        _loadFollowers(); // إعادة تحميل القائمة
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في الموافقة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // رفض طلب صداقة
  Future<void> _rejectFollowRequest(String userId, String followRecordId) async {
    try {
      await _authService.pb
          .collection(AppConstants.friendshipCollection)
          .delete(followRecordId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم رفض طلب المتابعة'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
        _loadFollowers(); // إعادة تحميل القائمة
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في الرفض: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // حظر مستخدم
  Future<void> _blockUser(String userId, String followRecordId) async {
    try {
      await _authService.pb
          .collection(AppConstants.friendshipCollection)
          .update(followRecordId, body: {'status': 'block'});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حظر المستخدم'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
        _loadFollowers(); // إعادة تحميل القائمة
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في الحظر: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // إلغاء طلب صداقة مرسل
  Future<void> _cancelSentRequest(String userId, String followRecordId) async {
    // تأكيد إلغاء الطلب
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إلغاء طلب الصداقة'),
        content: const Text('هل تريد إلغاء طلب الصداقة المرسل؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('لا'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('نعم، إلغاء', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    try {
      await _authService.pb
          .collection(AppConstants.friendshipCollection)
          .delete(followRecordId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إلغاء طلب الصداقة'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
        // إعادة تحميل جميع القوائم
        _loadPendingRequests();
        _loadSentRequests();
        _loadFollowers();
        _loadFollowing();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في إلغاء الطلب: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // إنهاء الصداقة
  Future<void> _unfollowUser(String userId, String followRecordId) async {
    // تأكيد إنهاء الصداقة
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إنهاء الصداقة'),
        content: const Text('هل تريد إنهاء هذه الصداقة؟\nلن تتمكنا من رؤية مواعيد بعضكما البعض.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('إنهاء الصداقة', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    try {
      await _authService.pb
          .collection(AppConstants.friendshipCollection)
          .delete(followRecordId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إنهاء الصداقة'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
        // إعادة تحميل جميع القوائم
        _loadPendingRequests();
        _loadSentRequests();
        _loadFollowers();
        _loadFollowing();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في إنهاء الصداقة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('الأصدقاء'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: Colors.blue,
          tabs: [
            Tab(
              text: 'عاديين (${_followers.length})',
            ),
            Tab(
              text: 'معتمدين (${_following.length})',
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // حقل البحث
          Container(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                hintText: 'ابحث في الأصدقاء...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.blue),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: _filterResults,
            ),
          ),
          
          // التبويبات
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildFollowersList(),
                _buildFollowingList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // قائمة المتابعين
  Widget _buildFollowersList() {
    if (_isLoadingFollowers) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // قسم طلبات الصداقة الواردة
        if (_pendingRequests.isNotEmpty) _buildPendingRequestsSection(),
        
        // قسم طلبات الصداقة المرسلة
        if (_sentRequests.isNotEmpty) _buildSentRequestsSection(),
        
        // قائمة الأصدقاء
        Expanded(
          child: _filteredFollowers.isEmpty
              ? _buildEmptyFollowersState()
              : _buildFollowersListView(),
        ),
      ],
    );
  }

  // قسم طلبات الصداقة الواردة
  Widget _buildPendingRequestsSection() {
    return Container(
      color: Colors.blue.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Icon(Icons.person_add, size: 20, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  'طلبات واردة (${_pendingRequests.length})',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _pendingRequests.length,
            itemBuilder: (context, index) {
              final user = _pendingRequests[index];
              final status = _pendingRequestsStatus[user.id];
              return _buildUserCard(user, status?['status'] ?? 'pending_received', status?['id'] ?? '', true);
            },
          ),
          Divider(height: 1, thickness: 2, color: Colors.grey.shade200),
        ],
      ),
    );
  }

  // قسم طلبات الصداقة المرسلة
  Widget _buildSentRequestsSection() {
    return Container(
      color: Colors.orange.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Icon(Icons.schedule_send, size: 20, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Text(
                  'طلبات مرسلة (${_sentRequests.length})',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _sentRequests.length,
            itemBuilder: (context, index) {
              final user = _sentRequests[index];
              final status = _sentRequestsStatus[user.id];
              return _buildUserCard(user, status?['status'] ?? 'pending_sent', status?['id'] ?? '', true);
            },
          ),
          Divider(height: 1, thickness: 2, color: Colors.grey.shade200),
        ],
      ),
    );
  }

  // حالة فارغة للمتابعين
  Widget _buildEmptyFollowersState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty ? 'لا يوجد أصدقاء عاديين' : 'لا توجد نتائج',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // قائمة المتابعين
  Widget _buildFollowersListView() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredFollowers.length,
      itemBuilder: (context, index) {
        final user = _filteredFollowers[index];
        final status = _followersStatus[user.id];
        return _buildUserCard(user, status?['status'] ?? 'approved', status?['id'] ?? '', true);
      },
    );
  }

  // قائمة المتبوعين
  Widget _buildFollowingList() {
    if (_isLoadingFollowing) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_filteredFollowing.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.verified_user_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty ? 'لا يوجد أصدقاء معتمدين' : 'لا توجد نتائج',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredFollowing.length,
      itemBuilder: (context, index) {
        final user = _filteredFollowing[index];
        final status = _followingStatus[user.id];
        return _buildUserCard(user, status?['status'] ?? 'approved', status?['id'] ?? '', false);
      },
    );
  }

  // بطاقة المستخدم
  Widget _buildUserCard(UserModel user, [String? statusOverride, String? recordIdOverride, bool? isFollowersTabOverride]) {
    // تحديد التبويب الحالي
    final isFollowersTab = isFollowersTabOverride ?? _tabController.index == 0;
    
    // الحصول على حالة المتابعة
    final statusData = isFollowersTab 
        ? _followersStatus[user.id] 
        : _followingStatus[user.id];
    final status = statusOverride ?? statusData?['status'] as String? ?? 'approved';
    final followRecordId = recordIdOverride ?? statusData?['id'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserProfileScreen(
                userId: user.id,
                username: user.username,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // الصورة الشخصية
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _getUserRingColor(user),
                    width: 2,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundImage: _getUserAvatarUrl(user) != null
                        ? NetworkImage(_getUserAvatarUrl(user)!)
                        : null,
                    backgroundColor: Colors.grey.shade200,
                    child: _getUserAvatarUrl(user) == null
                        ? const Icon(Icons.person, size: 22)
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // معلومات المستخدم
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '@${user.username}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    if (user.bio?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 4),
                      Text(
                        user.bio!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              
              // أزرار الإجراءات
              _buildActionButtons(user, status, followRecordId, isFollowersTab),
            ],
          ),
        ),
      ),
    );
  }

  // زر الإجراء الموحد حسب الحالة (نظام الصداقة)
  Widget _buildActionButtons(UserModel user, String status, String followRecordId, bool isFollowersTab) {
    // في نظام الصداقة، التبويبان يعرضان نفس العلاقة (أصدقاء)
    // الفرق فقط في تصنيف المستخدمين (عاديين/معتمدين)
    
    if (status == 'pending_sent') {
      // أنا أرسلت الطلب - زر انتظار (يمكن إلغاؤه)
      return SizedBox(
        width: 110,
        child: OutlinedButton(
          onPressed: () => _cancelSentRequest(user.id, followRecordId),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.orange,
            side: BorderSide(color: Colors.orange.shade300),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.schedule, size: 16),
              SizedBox(width: 4),
              Text('انتظار', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
      );
    } else if (status == 'pending_received' || status == 'pending') {
      // هو أرسل لي الطلب - زر قبول الصداقة
      return SizedBox(
        width: 110,
        child: ElevatedButton(
          onPressed: () => _approveFollowRequest(user.id, followRecordId),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check, size: 16),
              SizedBox(width: 4),
              Text('قبول', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
      );
    } else if (status == 'approved') {
      // صداقة مقبولة - زر صديق (رمادي فاتح فلات)
      return SizedBox(
        width: 110,
        child: TextButton(
          onPressed: () => _unfollowUser(user.id, followRecordId),
          style: TextButton.styleFrom(
            backgroundColor: Colors.grey.shade200,
            foregroundColor: Colors.grey.shade700,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, size: 16),
              SizedBox(width: 4),
              Text('صديق', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
      );
    } else if (status == 'block') {
      // محظور - زر فك الحظر
      return SizedBox(
        width: 110,
        child: OutlinedButton(
          onPressed: () => _approveFollowRequest(user.id, followRecordId),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.grey,
            side: BorderSide(color: Colors.grey.shade400),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.block, size: 16),
              SizedBox(width: 4),
              Text('محظور', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
      );
    }
    
    return const SizedBox.shrink();
  }
}
