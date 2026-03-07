import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'dart:io' show Platform;
import '../../models/user.dart';
import '../../models/appointment.dart';
import '../../models/extensions/appointment_logic.dart'; // Explicit import for extension
import 'schemas/user_schema.dart';
import 'schemas/appointment_schema.dart';
import 'dart:convert';

class LocalDbService {
  static LocalDbService? _instance;
  static LocalDbService get instance => _instance ??= LocalDbService._();
  
  static const String boxName = 'users';
  static const String followedBoxName = 'followed_users';
  static const String appointmentsBoxName = 'appointments'; // New Box
  
  late Future<Box<LocalUser>> box;
  late Future<Box<LocalUser>> followedBox;
  late Future<Box<LocalAppointment>> appointmentsBox; // New Box
  
  LocalDbService._() {
    box = _initDb(boxName);
    followedBox = _initDb(followedBoxName);
    appointmentsBox = _initAppointmentDb(appointmentsBoxName);
  }
  
  Future<Box<LocalUser>> _initDb(String name) async {
    await _ensureHiveInitialized();
    if (!Hive.isAdapterRegistered(0)) {
       Hive.registerAdapter(LocalUserAdapter());
    }
    return await Hive.openBox<LocalUser>(name);
  }

  Future<void> _ensureHiveInitialized() async {
    if (kIsWeb) return;
    
    // Check if initialized by seeing if we have a path
    try {
      // Hive.init doesn't have a direct "isInitialized" getter that's public easily
      // but we can just use path_provider to get the best path and call init again
      // Hive ignores subsequent init calls if path is same, or we can guard it.
      final directory = await getApplicationSupportDirectory();
      Hive.init(directory.path);
    } catch (e) {
      debugPrint('Hive init error: $e');
    }
  }

  // Initialize Appointment Box
  Future<Box<LocalAppointment>> _initAppointmentDb(String name) async {
    await _ensureHiveInitialized();
    if (!Hive.isAdapterRegistered(1)) {
       Hive.registerAdapter(LocalAppointmentAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
       Hive.registerAdapter(LocalInvitationAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
       Hive.registerAdapter(LocalCategoryAdapter());
    }
    
    return await Hive.openBox<LocalAppointment>(name);
  }
  
  // ====================== User Operations ======================
  // ... (Existing User Operations) ...
  Future<void> saveUser(UserModel user) async {
    final userBox = await box;
    await userBox.put('current_user', _toLocal(user)); 
  }
  
  Future<UserModel?> getUser() async {
    final userBox = await box;
    final localUser = userBox.get('current_user');
    return localUser != null ? _toModel(localUser) : null;
  }
  
  // ====================== Appointment Operations ======================
  
  /// Save appointments list to local DB
  Future<void> saveAppointments(List<Appointment> appointments) async {
    final appBox = await appointmentsBox;
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
    return appBox.values.map((la) => _toModelAppointment(la)).toList();
  }

  /// Clear all appointments
  Future<void> clearAppointments() async {
    final appBox = await appointmentsBox;
    await appBox.clear();
  }

  // ====================== Followed Users Operations ======================

  /// Save followed users list
  Future<void> saveFollowedUsers(List<UserModel> users) async {
    final fBox = await followedBox;
    await fBox.clear();
    for (var user in users) {
      await fBox.put(user.id, _toLocal(user));
    }
  }

  /// Get followed users from local DB
  Future<List<UserModel>> getFollowedUsers() async {
    final fBox = await followedBox;
    return fBox.values.map((lu) => _toModel(lu)).toList();
  }
  
  /// Clear specific user or all data on logout
  Future<void> clearUser() async {
    final userBox = await box;
    final fBox = await followedBox;
    final appBox = await appointmentsBox;
    
    await userBox.clear();
    await fBox.clear();
    await appBox.clear();
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
}
