class UserModel {
  final String id;
  final String email;
  final String username;
  final String name;
  final bool verified;
  final String? avatar;
  final String? bio;
  final String? socialLink;
  final String? phone;
  final String? role;
  final String? joiningDate;
  final int? hijriAdjustment;
  final DateTime? createdDate;
  final bool? isPublic;

  UserModel({
    required this.id,
    required this.email,
    required this.username,
    required this.name,
    required this.verified,
    this.avatar,
    this.bio,
    this.socialLink,
    this.phone,
    this.role,
    this.joiningDate,
    this.hijriAdjustment,
    this.createdDate,
    this.isPublic,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      verified: json['verified'] ?? false,
      avatar: json['avatar']?.toString(),
      bio: json['bio']?.toString(),
      socialLink: json['social_link']?.toString(),
      phone: json['phone']?.toString(),
      role: json['role']?.toString(),
      joiningDate: json['joining_date']?.toString(),
      hijriAdjustment: json['hijri_adjustment'] as int?,
      createdDate: json['created'] != null
          ? _parseDateTime(json['created'])
          : null,
      isPublic: json['isPublic'] as bool?,
    );
  }

  static DateTime? _parseDateTime(dynamic dateValue) {
    if (dateValue == null) return null;

    try {
      if (dateValue is String) {
        // تنظيف النص من المسافات الزائدة
        final cleanValue = dateValue.trim();

        // تجاهل القيم الفارغة أو غير الصحيحة
        if (cleanValue.isEmpty ||
            cleanValue == 'null' ||
            cleanValue == '0000-00-00' ||
            cleanValue == '0000-00-00 00:00:00') {
          return null;
        }

        // محاولة تحليل التاريخ
        return DateTime.parse(cleanValue);
      }
      return null;
    } catch (e) {
      // تسجيل الخطأ فقط للقيم غير المتوقعة
      if (dateValue != null && dateValue.toString().trim().isNotEmpty) {
        print('⚠️ تاريخ مستخدم غير صحيح تم تجاهله: $dateValue');
      }
      return null;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'name': name,
      'verified': verified,
      'avatar': avatar,
      'bio': bio,
      'social_link': socialLink,
      'phone': phone,
      'role': role,
      'joining_date': joiningDate,
      'hijri_adjustment': hijriAdjustment,
      'created': createdDate?.toIso8601String(),
      'isPublic': isPublic,
    };
  }
}
