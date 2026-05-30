import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import '../../models/user.dart';
import '../../models/appointment.dart';
import '../../models/article.dart';
// Explicit import for extension
import 'schemas/user_schema.dart';
import 'schemas/appointment_schema.dart';
import 'schemas/article_schema.dart';
import '../services/secure_storage_service.dart';
import 'dart:convert';

class LocalDbService {
  static LocalDbService? _instance;
  static LocalDbService get instance => _instance ??= LocalDbService._();
  
  static const String boxName = 'users';
  static const String followedBoxName = 'followed_users';
  static const String appointmentsBoxName = 'appointments';
  static const String recentSearchesBoxName = 'recent_searches';
  static const String articlesBoxName = 'articles';
  
  // Future واحد يضمن التهيئة التسلسلية — حل مشكلة IDBDatabase على الويب
  late final Future<void> _ready;

  Box<LocalUser>? _box;
  Box<LocalUser>? _followedBox;
  Box<LocalUser>? _recentSearchesBox;
  Box<LocalAppointment>? _appointmentsBox;
  Box<LocalArticle>? _articlesBox;
  
  LocalDbService._() {
    _ready = _initAll();
  }

  Future<void> _initAll() async {
    try {
      if (!kIsWeb) {
        try {
          final directory = await getApplicationSupportDirectory();
          Hive.init(directory.path);
        } catch (e) {
          debugPrint('❌ Hive.init failed: $e');
        }
      }

      if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(LocalUserAdapter());
      if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(LocalAppointmentAdapter());
      if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(LocalInvitationAdapter());
      if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(LocalCategoryAdapter());
      if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(LocalArticleAdapter());

      // جلب أو إنشاء مفتاح التشفير
      final encryptionKey = await _getEncryptionKey();
      final cipher = encryptionKey != null ? HiveAesCipher(encryptionKey) : null;

      // دالة مساعدة لفتح الصندوق بأمان مع معالجة التلف والتشفير
      Future<Box<T>> openBoxSafe<T>(String name, {HiveCipher? cipher}) async {
        try {
          return await Hive.openBox<T>(name, encryptionCipher: cipher);
        } catch (e) {
          debugPrint('⚠️ Box "$name" encryption mismatch or corrupted ($e). Attempting to reset...');
          try {
            await Hive.deleteBoxFromDisk(name);
            return await Hive.openBox<T>(name, encryptionCipher: cipher);
          } catch (e2) {
            debugPrint('‼️ Critical failure opening box "$name": $e2');
            rethrow;
          }
        }
      }

      // تهيئة تسلسلية لمنع المشاكل
      _box = await openBoxSafe<LocalUser>(boxName, cipher: cipher);
      _followedBox = await openBoxSafe<LocalUser>(followedBoxName, cipher: cipher);
      _recentSearchesBox = await openBoxSafe<LocalUser>(recentSearchesBoxName, cipher: cipher);
      _appointmentsBox = await openBoxSafe<LocalAppointment>(appointmentsBoxName, cipher: cipher);
      _articlesBox = await openBoxSafe<LocalArticle>(articlesBoxName, cipher: cipher);
      
    } catch (e) {
      debugPrint('‼️ Critical error during LocalDbService initialization: $e');
    }
  }

  /// جلب أو إنشاء مفتاح تشفير عشوائي وتخزينه بشكل آمن
  Future<List<int>?> _getEncryptionKey() async {
    if (kIsWeb) return null; // التشفير في الويب يتطلب معالجة مختلفة (SecureStorage ليس آمناً حقاً)
    
    try {
      final savedKey = await SecureStorageService.getHiveKey();
      if (savedKey != null) {
        return base64Url.decode(savedKey);
      } else {
        final key = Hive.generateSecureKey();
        await SecureStorageService.saveHiveKey(base64Url.encode(key));
        return key;
      }
    } catch (e) {
      debugPrint('❌ Error generating encryption key: $e');
      return null;
    }
  }

  Future<Box<LocalUser>?> get box async {
    await _ready;
    return _box;
  }

  Future<Box<LocalUser>?> get followedBox async {
    await _ready;
    return _followedBox;
  }

  Future<Box<LocalUser>?> get recentSearchesBox async {
    await _ready;
    return _recentSearchesBox;
  }

  Future<Box<LocalAppointment>?> get appointmentsBox async {
    await _ready;
    return _appointmentsBox;
  }
  
  Future<Box<LocalArticle>?> get articlesBox async {
    await _ready;
    return _articlesBox;
  }
  
  // ====================== User Operations ======================
  // ... (Existing User Operations) ...
  Future<void> saveUser(UserModel user) async {
    final userBox = await box;
    await userBox?.put('current_user', _toLocal(user)); 
  }
  
  Future<UserModel?> getUser() async {
    try {
      final userBox = await box;
      if (userBox == null) return null;
      final localUser = userBox.get('current_user');
      return localUser != null ? _toModel(localUser) : null;
    } catch (e) {
      debugPrint('❌ Error getting user from local DB: $e');
      return null;
    }
  }
  
  // ====================== Appointment Operations ======================
  
  /// Save appointments list to local DB
  Future<void> saveAppointments(List<Appointment> appointments) async {
    final appBox = await appointmentsBox;
    if (appBox == null) return;
    await appBox.clear(); // Overwrite cache strategy
    
    // Convert and save
    final Map<String, LocalAppointment> entries = {};
    for (var app in appointments) {
      entries[app.id] = _toLocalAppointment(app);
    }
    await appBox.putAll(entries);
  }

  /// Get appointments from local DB
  Future<List<Appointment>> getAppointments() async {
    final appBox = await appointmentsBox;
    if (appBox == null) return [];
    return appBox.values.map((la) => _toModelAppointment(la)).toList();
  }

  /// Clear all appointments
  Future<void> clearAppointments() async {
    final appBox = await appointmentsBox;
    await appBox?.clear();
  }

  // ====================== Article Operations ======================
  
  Future<void> saveArticles(List<Article> articles) async {
    final aBox = await articlesBox;
    if (aBox == null) return;
    await aBox.clear(); // Overwrite cache strategy
    
    final Map<String, LocalArticle> entries = {};
    for (var a in articles) {
      entries[a.id] = _toLocalArticle(a);
    }
    await aBox.putAll(entries);
  }

  Future<List<Article>> getArticles() async {
    final aBox = await articlesBox;
    if (aBox == null) return [];
    return aBox.values.map((la) => _toModelArticle(la)).toList();
  }

  Future<void> clearArticles() async {
    final aBox = await articlesBox;
    await aBox?.clear();
  }

  // ====================== Followed Users Operations ======================

  /// Save followed users list
  Future<void> saveFollowedUsers(List<UserModel> users) async {
    final fBox = await followedBox;
    if (fBox == null) return;
    await fBox.clear();
    for (var user in users) {
      await fBox.put(user.id, _toLocal(user));
    }
  }

  /// Get followed users from local DB
  Future<List<UserModel>> getFollowedUsers() async {
    final fBox = await followedBox;
    if (fBox == null) return [];
    return fBox.values.map((lu) => _toModel(lu)).toList();
  }

  // ====================== Recent Searches Operations ======================

  /// Add a user to recent searches (keeps only last 10)
  Future<void> saveRecentSearch(UserModel user) async {
    final rBox = await recentSearchesBox;
    if (rBox == null) return;
    
    // Remove if already exists to move it to the front (end of the list in Hive)
    await rBox.delete(user.id);
    
    await rBox.put(user.id, _toLocal(user));

    // Cleanup if more than 10
    if (rBox.length > 10) {
      final keyToRemove = rBox.keys.first;
      await rBox.delete(keyToRemove);
    }
  }

  /// Get recent searches
  Future<List<UserModel>> getRecentSearches() async {
    final rBox = await recentSearchesBox;
    if (rBox == null) return [];
    // Reverse to show most recent first
    return rBox.values.map((lu) => _toModel(lu)).toList().reversed.toList();
  }

  /// Clear specific user or all data on logout
  Future<void> clearUser() async {
    final userBox = await box;
    final fBox = await followedBox;
    final rBox = await recentSearchesBox;
    final appBox = await appointmentsBox;
    final aBox = await articlesBox;
    
    await userBox?.clear();
    await fBox?.clear();
    await rBox?.clear();
    await appBox?.clear();
    await aBox?.clear();
  }

  // ====================== Helpers (User) ======================

  LocalUser _toLocal(UserModel user) {
    return LocalUser()
      ..userId = user.id
      ..username = user.username
      ..email = user.email
      ..name = user.name
      ..avatar = user.avatar
      ..bio = user.bio
      ..socialLink = user.socialLink
      ..phone = user.phone
      ..hijriAdjustment = user.hijriAdjustment
      ..role = user.role
      ..isPublic = user.isPublic
      ..verified = user.verified
      ..emailVisibility = user.emailVisibility
      ..date = user.date
      ..created = user.created
      ..updated = user.updated
      ..joiningDate = user.joiningDate
      ..phoneVerified = user.phoneVerified
      ..token = user.token;
  }

  UserModel _toModel(LocalUser lu) {
    return UserModel(
      id: lu.userId,
      username: lu.username,
      email: lu.email,
      name: lu.name,
      avatar: lu.avatar,
      token: lu.token,
      bio: lu.bio,
      socialLink: lu.socialLink,
      phone: lu.phone,
      hijriAdjustment: lu.hijriAdjustment,
      role: lu.role,
      isPublic: lu.isPublic,
      verified: lu.verified,
      emailVisibility: lu.emailVisibility,
      date: lu.date,
      created: lu.created,
      updated: lu.updated,
      joiningDate: lu.joiningDate,
      phoneVerified: lu.phoneVerified,
    );
  }

  // ====================== Helpers (Appointment) ======================

  LocalAppointment _toLocalAppointment(Appointment app) {
    return LocalAppointment()
      ..id = app.id
      ..title = app.title
      ..hostId = app.hostId
      ..startAt = app.startAt
      ..duration = app.duration
      ..date = app.date
      ..time = app.time
      ..region = app.region
      ..building = app.building
      ..coordinates = app.coordinates
      ..privacy = app.privacy
      ..description = app.description
      ..participantsCount = app.participantsCount
      ..invitedCount = app.invitedCount
      ..isCancelled = app.isCancelled
      ..hostJson = app.host != null ? app.host!.toJsonString() : null
      ..participants = app.participants?.map(_toLocalInvitation).toList()
      ..currentUserInvitation = app.currentUserInvitation != null ? _toLocalInvitation(app.currentUserInvitation!) : null
      ..createdAt = app.createdAt
      ..updatedAt = app.updatedAt
      ..isConfirmed = app.isConfirmed
      ..dateType = app.dateType
      ..streamLink = app.streamLink
      ..appointmentGroupId = app.appointmentGroupId
      ..hijriDate = app.hijriDate
      ..hijriMonth = app.hijriMonth;
  }

  Appointment _toModelAppointment(LocalAppointment la) {
    // Reconstruct currentUserInvitation first to have the status available for Logic Extension
    final currentUserInvitation = la.currentUserInvitation != null ? _toModelInvitation(la.currentUserInvitation!) : null;

    return Appointment(
      id: la.id,
      title: la.title,
      hostId: la.hostId,
      startAt: la.startAt,
      duration: la.duration,
      date: la.date,
      time: la.time,
      region: la.region,
      building: la.building,
      coordinates: la.coordinates,
      privacy: la.privacy,
      description: la.description,
      participantsCount: la.participantsCount,
      invitedCount: la.invitedCount,
      isCancelled: la.isCancelled,
      createdAt: la.createdAt,
      updatedAt: la.updatedAt,
      participants: la.participants?.map(_toModelInvitation).toList(),
      currentUserInvitation: currentUserInvitation,
      isConfirmed: la.isConfirmed,
      dateType: la.dateType,
      streamLink: la.streamLink,
      appointmentGroupId: la.appointmentGroupId,
      hijriDate: la.hijriDate,
      hijriMonth: la.hijriMonth,
      host: la.hostJson != null ? UserModel.fromJson(jsonDecode(la.hostJson!)) : null,
    );
  }

  LocalInvitation _toLocalInvitation(Invitation inv) {
    return LocalInvitation()
      ..id = inv.id
      ..appointmentId = inv.appointmentId
      ..userId = inv.userId
      ..status = inv.status.toString()
      // We map PostStatus back to booleans for legacy Hive schema if needed, or update Hive schema. 
      // Assuming Hive Schema 'LocalInvitation' has isArchived/isDeleted fields.
      ..isDeleted = inv.postStatus == PostStatus.trash
      ..isArchived = inv.postStatus == PostStatus.archived
      ..isComplete = inv.isComplete
      ..dateType = inv.dateType
      ..personalNote = inv.personalNote
      ..privacy = inv.privacy
      ..acceptedAt = inv.acceptedAt
      ..declinedAt = inv.declinedAt
      ..deletedAt = inv.deletedAt
      ..userJson = inv.user != null ? inv.user!.toJsonString() : null
      ..categoryJson = inv.categories != null ? jsonEncode(inv.categories!.toJson()) : null;
  }

  Invitation _toModelInvitation(LocalInvitation li) {
    return Invitation(
      id: li.id,
      appointmentId: li.appointmentId,
      userId: li.userId,
      status: InvitationStatus.fromString(li.status),
      // Derive PostStatus from legacy flags in Local DB
      postStatus: li.isDeleted 
          ? PostStatus.trash 
          : (li.isArchived ? PostStatus.archived : PostStatus.published),
      isComplete: li.isComplete,
      dateType: li.dateType,
      privacy: li.privacy,
      personalNote: li.personalNote,
      acceptedAt: li.acceptedAt,
      declinedAt: li.declinedAt,
      deletedAt: li.deletedAt,
      user: li.userJson != null ? UserModel.fromJson(jsonDecode(li.userJson!)) : null,
      categories: li.categoryJson != null ? AppointmentCategory.fromJson(jsonDecode(li.categoryJson!)) : null,
    );
  }

  // ====================== Helpers (Article) ======================

  LocalArticle _toLocalArticle(Article a) {
    return LocalArticle()
      ..id = a.id
      ..authorId = a.authorId
      ..text = a.text
      ..isPublished = a.isPublished
      ..createdAt = a.createdAt
      ..updatedAt = a.updatedAt
      ..image = a.image
      ..likes = a.likes
      ..authorJson = a.author != null ? a.author!.toJsonString() : null
      ..poetryMetadataJson = a.poetryMetadata != null ? jsonEncode(a.poetryMetadata) : null
      ..highlightsMetadataJson = a.highlightsMetadata != null ? jsonEncode(a.highlightsMetadata) : null;
  }

  Article _toModelArticle(LocalArticle la) {
    return Article(
      id: la.id,
      authorId: la.authorId,
      text: la.text,
      isPublished: la.isPublished,
      createdAt: la.createdAt,
      updatedAt: la.updatedAt,
      image: la.image,
      likes: la.likes,
      author: la.authorJson != null ? UserModel.fromJson(jsonDecode(la.authorJson!)) : null,
      poetryMetadata: la.poetryMetadataJson != null ? jsonDecode(la.poetryMetadataJson!) : null,
      highlightsMetadata: la.highlightsMetadataJson != null ? jsonDecode(la.highlightsMetadataJson!) : null,
    );
  }

  // ====================== Dismissed Suggestions Operations ======================
  
  Future<void> saveDismissedSuggestionId(String userId) async {
    try {
      final prefBox = await Hive.openBox<dynamic>('app_preferences');
      final currentList = prefBox.get('dismissed_suggestions');
      final List<String> dismissed = currentList != null ? List<String>.from(currentList) : [];
      if (!dismissed.contains(userId)) {
        dismissed.add(userId);
        await prefBox.put('dismissed_suggestions', dismissed);
      }
    } catch (e) {
      debugPrint('❌ Error saving dismissed suggestion ID: $e');
    }
  }

  Future<List<String>> getDismissedSuggestionIds() async {
    try {
      final prefBox = await Hive.openBox<dynamic>('app_preferences');
      final currentList = prefBox.get('dismissed_suggestions');
      return currentList != null ? List<String>.from(currentList) : [];
    } catch (e) {
      debugPrint('❌ Error getting dismissed suggestion IDs: $e');
      return [];
    }
  }

  // ====================== Article Draft Operations ======================

  Future<void> saveArticleDraft(String text) async {
    try {
      final prefBox = await Hive.openBox<dynamic>('app_preferences');
      await prefBox.put('article_draft', text);
    } catch (e) {
      debugPrint('❌ Error saving article draft: $e');
    }
  }

  Future<String?> getArticleDraft() async {
    try {
      final prefBox = await Hive.openBox<dynamic>('app_preferences');
      return prefBox.get('article_draft') as String?;
    } catch (e) {
      debugPrint('❌ Error getting article draft: $e');
      return null;
    }
  }

  Future<void> clearArticleDraft() async {
    try {
      final prefBox = await Hive.openBox<dynamic>('app_preferences');
      await prefBox.delete('article_draft');
    } catch (e) {
      debugPrint('❌ Error clearing article draft: $e');
    }
  }
}
