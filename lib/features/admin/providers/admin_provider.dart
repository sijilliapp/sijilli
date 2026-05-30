import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import '../../../core/services/pocketbase_client.dart';
import '../../../core/providers/global_config_provider.dart';
import '../../../models/contact_message.dart';
import '../../../models/user.dart';

class AdminProvider extends ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<ContactMessageModel> _messages = [];
  List<ContactMessageModel> get messages => _messages;

  bool _isFetchingMessages = false;
  bool get isFetchingMessages => _isFetchingMessages;

  // إدارة البلاغات والتقارير
  List<RecordModel> _reports = [];
  List<RecordModel> get reports => _reports;

  bool _isFetchingReports = false;
  bool get isFetchingReports => _isFetchingReports;

  int get pendingReportsCount => _reports.where((r) => r.getStringValue('status') == 'pending').length;

  // إدارة المستخدمين
  List<UserModel> _userSearchResults = [];
  List<UserModel> get userSearchResults => _userSearchResults;

  bool _isSearchingUsers = false;
  bool get isSearchingUsers => _isSearchingUsers;

  List<UserModel> _recentRegisteredUsers = [];
  List<UserModel> get recentRegisteredUsers => _recentRegisteredUsers;

  bool _isFetchingRecentRegistered = false;
  bool get isFetchingRecentRegistered => _isFetchingRecentRegistered;

  List<UserModel> _adminUsers = [];
  List<UserModel> get adminUsers => _adminUsers;

  bool _isFetchingAdmins = false;
  bool get isFetchingAdmins => _isFetchingAdmins;

  /// الحصول على عدد الرسائل الجديدة
  int get newMessagesCount => _messages.where((m) => m.status == 'new').length;

  /// جلب المستخدمين المسجلين مؤخراً
  Future<void> fetchRecentlyRegistered() async {
    _isFetchingRecentRegistered = true;
    notifyListeners();
    try {
      final pb = PocketBaseClient.instance.pb;
      final records = await pb.collection('users').getList(
        sort: '-created',
        perPage: 20,
      );
      _recentRegisteredUsers = records.items.map((r) => UserModel.fromJson(r.toJson())).toList();
    } catch (e) {
      print('❌ Error fetching recent users: $e');
    } finally {
      _isFetchingRecentRegistered = false;
      notifyListeners();
    }
  }

  /// جلب المشرفين والمسؤولين
  Future<void> fetchAdmins() async {
    _isFetchingAdmins = true;
    notifyListeners();
    try {
      final pb = PocketBaseClient.instance.pb;
      final records = await pb.collection('users').getList(
        filter: 'role = "admin" || role = "approved"',
        sort: '-created',
        perPage: 30,
      );
      _adminUsers = records.items.map((r) => UserModel.fromJson(r.toJson())).toList();
    } catch (e) {
      print('❌ Error fetching admins: $e');
    } finally {
      _isFetchingAdmins = false;
      notifyListeners();
    }
  }

  /// تفعيل أو إيقاف التسجيل في التطبيق
  Future<bool> toggleRegistration(bool isEnabled, GlobalConfigProvider configProvider) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final pb = PocketBaseClient.instance.pb;
      
      // 1. البحث عن السجل الخاص بمفتاح التسجيل
      final result = await pb.collection('app_config').getFirstListItem('key="registrations_enabled"');
      
      // 2. تحديث القيمة في قاعدة البيانات
      await pb.collection('app_config').update(result.id, body: {
        'value_bool': isEnabled,
      });

      // 3. مزامنة التغييرات مع المزود العام لكي تنعكس التحديثات على كافة أجزاء التطبيق فوراً
      await configProvider.fetchConfig();
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      print('❌ Error toggling registration: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// تحديث قيمة إعداد رقمي (مثل الحد الأقصى لحروف المقال)
  Future<bool> updateConfigNumber(String key, double value, GlobalConfigProvider configProvider) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final pb = PocketBaseClient.instance.pb;
      
      try {
        final result = await pb.collection('app_config').getFirstListItem('key="$key"');
        await pb.collection('app_config').update(result.id, body: {
          'value_number': value,
        });
      } catch (e) {
        // If not found, create it
        await pb.collection('app_config').create(body: {
          'key': key,
          'value_number': value,
        });
      }

      await configProvider.fetchConfig();
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      print('❌ Error updating config $key: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// تحديث قيمة إعداد نصي (مثل قاموس الأخطاء الشائعة)
  Future<bool> updateConfigString(String key, String value, GlobalConfigProvider configProvider) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final pb = PocketBaseClient.instance.pb;
      
      try {
        final result = await pb.collection('app_config').getFirstListItem('key="$key"');
        await pb.collection('app_config').update(result.id, body: {
          'value_string': value,
        });
      } catch (e) {
        // If not found, create it
        await pb.collection('app_config').create(body: {
          'key': key,
          'value_string': value,
        });
      }

      await configProvider.fetchConfig();
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      print('❌ Error updating config $key: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// جلب كافة رسائل التواصل الواردة
  Future<void> fetchContactMessages() async {
    _isFetchingMessages = true;
    notifyListeners();

    try {
      final pb = PocketBaseClient.instance.pb;
      final records = await pb.collection('contact_messages').getFullList(
        sort: '-created',
        expand: 'user',
      );

      _messages = records.map((r) {
        final data = r.toJson();
        
        // استخراج بيانات المستخدم المرفقة بشكل آمن
        final userExpand = r.expand['user'];
        if (userExpand != null && userExpand.isNotEmpty) {
          final userRecord = userExpand.first;
          data['expand'] = {
            'user': userRecord.toJson()
          };
        }
        
        return ContactMessageModel.fromJson(data);
      }).toList();
    } catch (e) {
      print('❌ Error fetching contact messages: $e');
    } finally {
      _isFetchingMessages = false;
      notifyListeners();
    }
  }

  /// تحديث حالة الرسالة (مثلاً: تم الرد، مقروءة، إلخ)
  Future<bool> updateMessageStatus(String messageId, String newStatus) async {
    try {
      final pb = PocketBaseClient.instance.pb;
      await pb.collection('contact_messages').update(messageId, body: {
        'status': newStatus,
      });

      // تحديث الحالة محلياً فوراً لجعل الواجهة متفاعلة وسريعة للغاية
      final index = _messages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        final oldMsg = _messages[index];
        _messages[index] = ContactMessageModel(
          id: oldMsg.id,
          userId: oldMsg.userId,
          user: oldMsg.user,
          title: oldMsg.title,
          message: oldMsg.message,
          type: oldMsg.type,
          status: newStatus,
          created: oldMsg.created,
          updated: DateTime.now(),
        );
        notifyListeners();
      }
      return true;
    } catch (e) {
      print('❌ Error updating message status: $e');
      return false;
    }
  }

  /// البحث عن مستخدمين بالأبجدية أو الاسم أو اليوزرنيم
  Future<void> searchUsers(String query) async {
    if (query.trim().isEmpty) {
      _userSearchResults = [];
      notifyListeners();
      return;
    }

    _isSearchingUsers = true;
    notifyListeners();

    try {
      final pb = PocketBaseClient.instance.pb;
      final cleanQuery = query.trim();
      
      // جلب قائمة المستخدمين المطابقين
      final records = await pb.collection('users').getList(
        filter: 'name ~ "$cleanQuery" || username ~ "$cleanQuery"',
        sort: 'username',
        perPage: 30,
      );

      _userSearchResults = records.items.map((r) => UserModel.fromJson(r.toJson())).toList();
    } catch (e) {
      print('❌ Error searching users: $e');
      _userSearchResults = [];
    } finally {
      _isSearchingUsers = false;
      notifyListeners();
    }
  }

  /// تنظيف نتائج البحث عن مستخدمين
  void clearUserSearch() {
    _userSearchResults = [];
    notifyListeners();
  }

  /// تحديث بيانات حقول المشترك بالكامل (أدوار، توثيق، إخفاء، إلخ)
  Future<bool> updateUserFields(String userId, Map<String, dynamic> fields) async {
    _isLoading = true;
    notifyListeners();

    try {
      final pb = PocketBaseClient.instance.pb;
      
      // مطابقة حقل phone_verified مع الاسم في قاعدة البيانات
      final Map<String, dynamic> body = Map.from(fields);
      if (body.containsKey('phoneVerified')) {
        body['phone_verified'] = body.remove('phoneVerified');
      }
      if (body.containsKey('isSuggested')) {
        body['is_suggested'] = body.remove('isSuggested');
      }

      await pb.collection('users').update(userId, body: body);

      // تحديث محلي لنتائج البحث فوراً
      final index = _userSearchResults.indexWhere((u) => u.id == userId);
      if (index != -1) {
        final oldUser = _userSearchResults[index];
        _userSearchResults[index] = UserModel(
          id: oldUser.id,
          username: oldUser.username,
          email: oldUser.email,
          name: oldUser.name,
          avatar: oldUser.avatar,
          token: oldUser.token,
          bio: oldUser.bio,
          socialLink: oldUser.socialLink,
          phone: oldUser.phone,
          hijriAdjustment: oldUser.hijriAdjustment,
          region: oldUser.region,
          role: fields['role'] ?? oldUser.role,
          isPublic: fields['isPublic'] ?? oldUser.isPublic,
          hideFromSearch: fields['hideFromSearch'] ?? oldUser.hideFromSearch,
          verified: fields['verified'] ?? oldUser.verified,
          isSuggested: fields['isSuggested'] ?? fields['is_suggested'] ?? oldUser.isSuggested,
          emailVisibility: oldUser.emailVisibility,
          phoneVerified: fields['phoneVerified'] ?? fields['phone_verified'] ?? oldUser.phoneVerified,
          date: oldUser.date,
          created: oldUser.created,
          updated: DateTime.now(),
          joiningDate: oldUser.joiningDate,
          lastActive: oldUser.lastActive,
        );
      }
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      print('❌ Error updating user fields: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// جلب البلاغات والتقارير
  Future<void> fetchReports() async {
    _isFetchingReports = true;
    notifyListeners();
    try {
      final pb = PocketBaseClient.instance.pb;
      final records = await pb.collection('reports').getList(
        sort: '-created',
        expand: 'reporter',
        perPage: 50,
      );
      _reports = records.items;
    } catch (e) {
      print('❌ Error fetching reports: $e');
    } finally {
      _isFetchingReports = false;
      notifyListeners();
    }
  }

  /// تحديث حالة البلاغ (pending, resolved, ignored)
  Future<bool> updateReportStatus(String reportId, String status) async {
    try {
      final pb = PocketBaseClient.instance.pb;
      await pb.collection('reports').update(reportId, body: {
        'status': status,
      });
      await fetchReports();
      return true;
    } catch (e) {
      print('❌ Error updating report status: $e');
      return false;
    }
  }

  /// حذف المحتوى المُبلّغ عنه (موعد، مقال، مستخدم)
  Future<bool> deleteReportedContent(String subjectType, String subjectId) async {
    try {
      final pb = PocketBaseClient.instance.pb;
      String collectionName;
      if (subjectType == 'appointment') {
        collectionName = 'appointments';
      } else if (subjectType == 'article') {
        collectionName = 'articles';
      } else if (subjectType == 'user') {
        collectionName = 'users';
      } else {
        return false;
      }
      await pb.collection(collectionName).delete(subjectId);
      return true;
    } catch (e) {
      print('❌ Error deleting reported content: $e');
      return false;
    }
  }

  /// جلب تفاصيل المحتوى المُبلّغ عنه بشكل منفصل لعرضه
  Future<Map<String, dynamic>?> fetchSubjectDetails(String subjectType, String subjectId) async {
    try {
      final pb = PocketBaseClient.instance.pb;
      String collectionName;
      if (subjectType == 'appointment') {
        collectionName = 'appointments';
      } else if (subjectType == 'article') {
        collectionName = 'articles';
      } else if (subjectType == 'user') {
        collectionName = 'users';
      } else {
        return null;
      }
      final record = await pb.collection(collectionName).getOne(subjectId);
      return record.toJson();
    } catch (e) {
      print('❌ Error fetching subject details ($subjectType, $subjectId): $e');
      return null;
    }
  }
}
