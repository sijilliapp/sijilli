// 📍 lib/models/user.dart
// 👤 نموذج بيانات المستخدم في تطبيق "سجلي" - متوافق مع PocketBase
import 'dart:convert';

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
  final bool verified;
  // 🔒 Official Badge Decoupling:
  // "verified" is for Email/Phone verification (System).
  // "isOfficial" is for the Blue Badge (Visual). 
  // Currently disabled until further notice.
  bool get isOfficial => false; 

  final bool emailVisibility;
  
  // ====================== التواريخ ======================
  final DateTime? date; // تاريخ الميلاد
  final DateTime created;
  final DateTime updated;
  final DateTime joiningDate;
  
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
    this.verified = false,
    this.emailVisibility = false,
    this.date,
    required this.created,
    required this.updated,
    required this.joiningDate,
  });
  
  // ====================== دوال المصنع ======================
  /// إنشاء مستخدم من JSON (من PocketBase) - نسخة مبسطة
  factory UserModel.fromJson(Map<String, dynamic> json, {String? token}) {
    return UserModel(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      avatar: json['avatar'],
      token: token ?? json['token'], // Load token if available
      bio: json['bio'],
      socialLink: json['social_link'],
      phone: json['phone']?.toString(),
      hijriAdjustment: json['hijri_adjustment']?.toDouble(),
      region: json['region'] as String?,
      role: json['role'] ?? 'user',
      isPublic: _parseBool(json['isPublic']),
      verified: json['verified'] ?? false,
      emailVisibility: json['emailVisibility'] ?? false,
      date: _parseDate(json['date']),
      created: _parseDate(json['created']) ?? DateTime.now(),
      updated: _parseDate(json['updated']) ?? DateTime.now(),
      joiningDate: _parseDate(json['joining_date']) ?? 
                   _parseDate(json['Joining_date']) ?? 
                   _parseDate(json['created']) ?? 
                   DateTime.now(),
    );
  }
  
  /// دالة مساعدة لتحليل التاريخ
  static DateTime? _parseDate(dynamic dateValue) {
    if (dateValue == null || dateValue == '') return null;
    try {
      return DateTime.parse(dateValue.toString());
    } catch (e) {
      return null;
    }
  }
  
  /// دالة مساعدة لتحليل القيم المنطقية
  static bool _parseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is String) {
      return value.toLowerCase() == 'true' || value == '1';
    }
    if (value is int) return value == 1;
    return false;
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
      verified: false,
      emailVisibility: false,
      created: now,
      updated: now,
      joiningDate: now,
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
      created: now,
      updated: now,
      joiningDate: now,
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
      'verified': verified,
      'emailVisibility': emailVisibility,
      'date': date?.toIso8601String(),
      'created': created.toIso8601String(),
      'updated': updated.toIso8601String(),
      'Joining_date': joiningDate.toIso8601String(),
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
    bool? verified,
    bool? emailVisibility,
    DateTime? date,
    DateTime? created,
    DateTime? updated,
    DateTime? joiningDate,
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
      verified: verified ?? this.verified,
      emailVisibility: emailVisibility ?? this.emailVisibility,
      date: date ?? this.date,
      created: created ?? this.created,
      updated: updated ?? this.updated,
      joiningDate: joiningDate ?? this.joiningDate,
    );
  }
  
  /// التحقق إذا كان المستخدم مجهولاً
  bool get isAnonymous => id == 'anonymous';
  
  /// التحقق إذا كان المستخدم مشرفاً
  bool get isAdmin => role == 'admin';
  
  /// التحقق إذا كان المستخدم معتمداً
  bool get isApproved => role == 'approved';
  
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
    switch (role) {
      case 'admin':
        return 'مشرف';
      case 'approved':
        return 'معتمد';
      case 'user':
      default:
        return 'مستخدم';
    }
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