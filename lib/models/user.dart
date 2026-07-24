import 'dart:convert';
import '../core/utils/json_utils.dart';

class UserModel {
  // ====================== الحقول الأساسية ======================
  final String id;
  final String username;
  final String email;
  final String name;
  final String? avatar;
  
  // ====================== الحقول الاختيارية ======================
  final String? bio;
  final String? socialLink;
  final String? phone;
  final double? hijriAdjustment;
  final String? region; // المنطقة
  
  // ====================== الإعدادات ======================
  final String role; // 'user', 'approved', 'admin'
  final bool isPublic;
  final bool hideFromSearch;
  final bool verified;
  final bool isSuggested; // 📢 هل يتم اقتراح هذا الحساب؟
  // 🔒 Official Badge Decoupling:
  // "verified" is for Email/Phone verification (System).
  // "isOfficial" is for the Blue Badge (Visual). 
  // Currently disabled until further notice.
  bool get isOfficial => false; 

  final bool emailVisibility;
  final bool phoneVerified; // 📱 هل تم التحقق من الهاتف؟
  final bool isSuperAdmin; // 🛡️ مشرف عام (صلاحيات كاملة)
  final bool disableCopying; // 🔒 منع نسخ المقالات
  final UserRoleMetadata? roleMetadata;

  // 🧠 ذاكرة مؤقتة للمطابقة الديناميكية لبيانات الفئات الآتية من قاعدة البيانات
  static final Map<String, UserRoleMetadata> rolesCache = {};

  UserRoleMetadata get activeRoleMetadata {
    if (roleMetadata != null) return roleMetadata!;
    if (rolesCache.containsKey(role)) {
      return rolesCache[role]!;
    }
    return getDefaultRoleMetadata(role);
  }
  
  // ====================== التواريخ ======================
  final DateTime? date; // تاريخ الميلاد
  final DateTime created;
  final DateTime updated;
  final DateTime joiningDate;
  final DateTime? lastActive;
  
  final String? token; // 🔑 Authentication Token
  
  // ====================== المنشئ ======================
  const UserModel({
    required this.id,
    required this.username,
    required this.email,
    required this.name,
    this.avatar,
    this.token, // Add token
    this.bio,
    this.socialLink,
    this.phone,
    this.hijriAdjustment,
    this.region,
    this.role = 'user',
    this.isPublic = false,
    this.hideFromSearch = false,
    this.verified = false,
    this.isSuggested = false,
    this.emailVisibility = false,
    this.phoneVerified = false, // Default is false
    this.isSuperAdmin = false, // Default is false
    this.disableCopying = false, // Default is false
    this.roleMetadata,
    this.date,
    required this.created,
    required this.updated,
    required this.joiningDate,
    this.lastActive,
  });
  
  // ====================== دوال المصنع ======================
  /// إنشاء مستخدم من JSON (من PocketBase) - نسخة مبسطة
  factory UserModel.fromJson(Map<String, dynamic> json, {String? token}) {
    return UserModel(
      id: JsonUtils.parseString(json['id']) ?? '',
      username: JsonUtils.parseString(json['username']) ?? '',
      email: JsonUtils.parseString(json['email']) ?? '',
      name: JsonUtils.parseString(json['name']) ?? '',
      avatar: JsonUtils.parseString(json['avatar']),
      token: token ?? JsonUtils.parseString(json['token']), // Load token if available
      bio: JsonUtils.parseString(json['bio']),
      socialLink: JsonUtils.parseString(json['social_link']),
      phone: JsonUtils.parseString(json['phone']),
      hijriAdjustment: JsonUtils.parseDouble(json['hijri_adjustment']),
      region: JsonUtils.parseString(json['region']),
      role: JsonUtils.parseString(json['role']) ?? 'user',
      isPublic: JsonUtils.parseBool(json['isPublic']),
      hideFromSearch: JsonUtils.parseBool(json['hideFromSearch']),
      verified: JsonUtils.parseBool(json['verified']),
      isSuggested: JsonUtils.parseBool(json['is_suggested']) ?? JsonUtils.parseBool(json['isSuggested']),
      emailVisibility: JsonUtils.parseBool(json['emailVisibility']),
      phoneVerified: JsonUtils.parseBool(json['phone_verified']) ?? JsonUtils.parseBool(json['phoneVerified']),
      isSuperAdmin: JsonUtils.parseBool(json['is_super_admin']) ?? JsonUtils.parseBool(json['isSuperAdmin']),
      disableCopying: JsonUtils.parseBool(json['disable_copying']) ?? JsonUtils.parseBool(json['disableCopying']),
      roleMetadata: json['role_metadata'] != null 
          ? UserRoleMetadata.fromJson(json['role_metadata'] is String 
              ? jsonDecode(json['role_metadata']) 
              : json['role_metadata'])
          : null,
      date: JsonUtils.parseDateTime(json['date']),
      created: JsonUtils.parseDateTime(json['created']) ?? DateTime.now(),
      updated: JsonUtils.parseDateTime(json['updated']) ?? DateTime.now(),
      joiningDate: JsonUtils.parseDateTime(json['joining_date']) ?? 
                   JsonUtils.parseDateTime(json['Joining_date']) ?? 
                   JsonUtils.parseDateTime(json['created']) ?? 
                   DateTime.now(),
      lastActive: JsonUtils.parseDateTime(json['lastActive']),
    );
  }
  
  /// إنشاء مستخدم جديد (لتسجيل مستخدم جديد)
  factory UserModel.newUser({
    required String username,
    required String name,
    required String email,
    String? phone,
    bool isPublic = false,
  }) {
    final now = DateTime.now();
    return UserModel(
      id: '', // سيتم توليده من PocketBase
      username: username,
      name: name,
      email: email,
      phone: phone,
      role: 'user',
      isPublic: isPublic,
      hideFromSearch: false,
      verified: false,
      isSuggested: false,
      emailVisibility: false,
      isSuperAdmin: false,
      created: now,
      updated: now,
      joiningDate: now,
      lastActive: now,
    );
  }
  
  /// مستخدم مجهول (للحالات التي لا يوجد مستخدم مسجل)
  factory UserModel.anonymous() {
    final now = DateTime.now();
    return UserModel(
      id: 'anonymous',
      username: 'مجهول',
      name: 'مستخدم مجهول',
      email: '',
      isSuggested: false,
      isSuperAdmin: false,
      created: now,
      updated: now,
      joiningDate: now,
      lastActive: now,
    );
  }
  
  // ====================== التحويل لـ JSON ======================
  /// تحويل المستخدم لـ JSON (لإرساله لـ PocketBase)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'name': name,
      'avatar': avatar,
      'token': token, // Save token
      'bio': bio,
      'social_link': socialLink,
      'phone': phone,
      'hijri_adjustment': hijriAdjustment,
      'region': region,
      'role': role,
      'isPublic': isPublic,
      'hideFromSearch': hideFromSearch,
      'verified': verified,
      'is_suggested': isSuggested,
      'emailVisibility': emailVisibility,
      'phone_verified': phoneVerified,
      'is_super_admin': isSuperAdmin,
      'disable_copying': disableCopying,
      if (roleMetadata != null) 'role_metadata': roleMetadata!.toJson(),
      'date': date?.toIso8601String(),
      'created': created.toIso8601String(),
      'updated': updated.toIso8601String(),
      'Joining_date': joiningDate.toIso8601String(),
      if (lastActive != null) 'lastActive': lastActive?.toIso8601String(),
    };
  }

  /// تحويل المستخدم لنص JSON (للتخزين المحلي)
  String toJsonString() => jsonEncode(toJson());

  // ... toRegistrationJson ...

  // ====================== الدوال المساعدة ======================
  /// نسخ المستخدم مع تحديث بعض الحقول
  UserModel copyWith({
    String? id,
    String? username,
    String? email,
    String? name,
    String? avatar,
    String? token, // Add token
    String? bio,
    String? socialLink,
    String? phone,
    double? hijriAdjustment,
    String? region,
    String? role,
    bool? isPublic,
    bool? hideFromSearch,
    bool? verified,
    bool? isSuggested,
    bool? emailVisibility,
    bool? phoneVerified,
    bool? isSuperAdmin,
    bool? disableCopying,
    UserRoleMetadata? roleMetadata,
    DateTime? date,
    DateTime? created,
    DateTime? updated,
    DateTime? joiningDate,
    DateTime? lastActive,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      token: token ?? this.token, // Copy token
      bio: bio ?? this.bio,
      socialLink: socialLink ?? this.socialLink,
      phone: phone ?? this.phone,
      hijriAdjustment: hijriAdjustment ?? this.hijriAdjustment,
      region: region ?? this.region,
      role: role ?? this.role,
      isPublic: isPublic ?? this.isPublic,
      hideFromSearch: hideFromSearch ?? this.hideFromSearch,
      verified: verified ?? this.verified,
      isSuggested: isSuggested ?? this.isSuggested,
      emailVisibility: emailVisibility ?? this.emailVisibility,
      phoneVerified: phoneVerified ?? this.phoneVerified,
      isSuperAdmin: isSuperAdmin ?? this.isSuperAdmin,
      disableCopying: disableCopying ?? this.disableCopying,
      roleMetadata: roleMetadata ?? this.roleMetadata,
      date: date ?? this.date,
      created: created ?? this.created,
      updated: updated ?? this.updated,
      joiningDate: joiningDate ?? this.joiningDate,
      lastActive: lastActive ?? this.lastActive,
    );
  }
  
  /// التحقق إذا كان المستخدم مجهولاً
  bool get isAnonymous => id == 'anonymous';
  
  /// التحقق إذا كان المستخدم مشرفاً
  bool get isAdmin => role == 'admin';
  
  /// التحقق إذا كان المستخدم معتمداً (له رتبة مميزة تمنحه صلاحية إنشاء مواعيد وحجز ونشر)
  bool get isApproved => role == 'approved' || role == 'writer' || role == 'organization' || role == 'admin';
  
  /// الحصول على رابط الصورة الشخصية
  String? getAvatarUrl(String baseUrl, {String? thumb}) {
    if (avatar == null || avatar!.isEmpty) return null;
    final url = '$baseUrl/api/files/_pb_users_auth_/$id/$avatar';
    if (thumb != null) return '$url?thumb=$thumb';
    return url;
  }
  
  /// الحصول على رابط الملف الشخصي
  String get profileUrl => 'sijilli.com/$username';
  
  /// التحقق إذا كان لديه صورة شخصية
  bool get hasAvatar => avatar != null && avatar!.isNotEmpty;
  
  /// التحقق إذا كان لديه نبذة شخصية
  bool get hasBio => bio != null && bio!.isNotEmpty;
  
  /// التحقق إذا كان لديه رابط اجتماعي
  bool get hasSocialLink => socialLink != null && socialLink!.isNotEmpty;
  
  /// الحصول على اسم الدور بالعربية
  String get roleDisplayName {
    if (isSuperAdmin) return 'مشرف عام';
    return activeRoleMetadata.displayNameAr;
  }
  
  // ====================== المقارنة ======================
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel && other.id == id;
  }
  
  @override
  int get hashCode => id.hashCode;
  
  @override
  String toString() {
    return 'UserModel(id: $id, username: $username, name: $name, role: $role)';
  }
}

class UserRoleMetadata {
  final String key;
  final String displayNameAr;
  final String displayNameEn;
  final String? badgeTextAr;
  final String? badgeColor;
  final String? badgeIcon;
  final Map<String, dynamic> permissions;

  const UserRoleMetadata({
    required this.key,
    required this.displayNameAr,
    required this.displayNameEn,
    this.badgeTextAr,
    this.badgeColor,
    this.badgeIcon,
    required this.permissions,
  });

  factory UserRoleMetadata.fromJson(Map<String, dynamic> json) {
    return UserRoleMetadata(
      key: json['key'] ?? 'user',
      displayNameAr: json['display_name_ar'] ?? '',
      displayNameEn: json['display_name_en'] ?? '',
      badgeTextAr: json['badge_text_ar'],
      badgeColor: json['badge_color'],
      badgeIcon: json['badge_icon'],
      permissions: json['permissions'] is Map 
          ? Map<String, dynamic>.from(json['permissions']) 
          : {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'display_name_ar': displayNameAr,
      'display_name_en': displayNameEn,
      'badge_text_ar': badgeTextAr,
      'badge_color': badgeColor,
      'badge_icon': badgeIcon,
      'permissions': permissions,
    };
  }

  bool hasPermission(String permissionKey, {bool defaultValue = false}) {
    return permissions[permissionKey] as bool? ?? defaultValue;
  }

  int getLimit(String permissionKey, {int defaultValue = 0}) {
    return permissions[permissionKey] as int? ?? defaultValue;
  }
}

UserRoleMetadata getDefaultRoleMetadata(String roleKey) {
  switch (roleKey) {
    case 'admin':
      return const UserRoleMetadata(
        key: 'admin',
        displayNameAr: 'مشرف عام',
        displayNameEn: 'General Moderator',
        badgeTextAr: 'مشرف',
        badgeColor: '#9C27B0', // Purple
        badgeIcon: 'shield',
        permissions: {
          'can_use_ai_transcribe': true,
          'can_use_ai_summarize': true,
          'max_audio_files': 99,
          'can_publish_public': true,
          'can_verify_articles': true,
          'daily_ai_limit': 999, // Uncapped
        },
      );
    case 'writer':
      return const UserRoleMetadata(
        key: 'writer',
        displayNameAr: 'كاتب',
        displayNameEn: 'Writer',
        badgeTextAr: 'كاتب معتمد',
        badgeColor: '#1E88E5', // Blue
        badgeIcon: 'verified',
        permissions: {
          'can_use_ai_transcribe': true,
          'can_use_ai_summarize': true,
          'max_audio_files': 10,
          'can_publish_public': true,
          'can_verify_articles': false,
          'daily_ai_limit': 10, // Define dynamic limit for writer (e.g. 10 uses per day)
        },
      );
    case 'organization':
      return const UserRoleMetadata(
        key: 'organization',
        displayNameAr: 'مؤسسة / جهة',
        displayNameEn: 'Organization',
        badgeTextAr: 'مؤسسة معتمدة',
        badgeColor: '#FFB300', // Gold/Amber
        badgeIcon: 'business',
        permissions: {
          'can_use_ai_transcribe': true,
          'can_use_ai_summarize': true,
          'max_audio_files': 25,
          'can_publish_public': true,
          'can_verify_articles': true,
          'daily_ai_limit': 25, // 25 uses per day
        },
      );
    case 'approved': // Legacy approved role maps to writer permissions
      return const UserRoleMetadata(
        key: 'approved',
        displayNameAr: 'مستخدم معتمد',
        displayNameEn: 'Approved User',
        badgeTextAr: 'معتمد',
        badgeColor: '#00897B', // Teal
        badgeIcon: 'verified',
        permissions: {
          'can_use_ai_transcribe': true,
          'can_use_ai_summarize': true,
          'max_audio_files': 5,
          'can_publish_public': true,
          'can_verify_articles': false,
          'daily_ai_limit': 5,
        },
      );
    case 'user':
    default:
      return const UserRoleMetadata(
        key: 'user',
        displayNameAr: 'مستخدم عادي',
        displayNameEn: 'Standard User',
        badgeTextAr: null,
        badgeColor: null,
        badgeIcon: null,
        permissions: {
          'can_use_ai_transcribe': true,
          'can_use_ai_summarize': true,
          'max_audio_files': 1,
          'can_publish_public': false,
          'can_verify_articles': false,
          'daily_ai_limit': 1, // Only 1 use per day
        },
      );
  }
}