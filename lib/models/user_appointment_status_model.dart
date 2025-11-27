class UserAppointmentStatusModel {
  final String id;
  final String userId;
  final String appointmentId;
  final String status; // active, deleted, archived
  final String? privacy; // public, private - خصوصية نسخة المستخدم
  final DateTime? deletedAt;
  final String? myNote; // ملاحظة خاصة للمستخدم
  // ✅ نسخة من بيانات الموعد الأساسية
  final String? title;
  final String? region;
  final String? building;
  final DateTime? appointmentDate;
  final DateTime created;
  final DateTime updated;

  UserAppointmentStatusModel({
    required this.id,
    required this.userId,
    required this.appointmentId,
    required this.status,
    this.privacy,
    this.deletedAt,
    this.myNote,
    this.title,
    this.region,
    this.building,
    this.appointmentDate,
    required this.created,
    required this.updated,
  });

  factory UserAppointmentStatusModel.fromJson(Map<String, dynamic> json) {
    try {
      return UserAppointmentStatusModel(
        id: json['id'] ?? '',
        userId: json['user'] ?? '',
        appointmentId: json['appointment'] ?? '',
        status: json['status'] ?? 'active',
        privacy: json['privacy'], // null means inherit from appointment
        deletedAt: _parseDateTime(json['deleted_at']),
        myNote: json['my_note'],
        title: json['title'],
        region: json['region'],
        building: json['building'],
        appointmentDate: _parseDateTime(json['appointment_date']),
        created: _parseDateTime(json['created']) ?? DateTime.now(),
        updated: _parseDateTime(json['updated']) ?? DateTime.now(),
      );
    } catch (e) {
      print('⚠️ خطأ في تحليل UserAppointmentStatusModel من JSON: $e');
      print('⚠️ البيانات: $json');
      rethrow;
    }
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

        // محاولة تحليل التاريخ والتأكد من أنه UTC
        final parsed = DateTime.parse(cleanValue);
        // إذا لم يكن UTC، نحوله إلى UTC
        return parsed.isUtc ? parsed : parsed.toUtc();
      }
      return null;
    } catch (e) {
      // تسجيل الخطأ فقط للقيم غير المتوقعة
      if (dateValue != null && dateValue.toString().trim().isNotEmpty) {
        print('⚠️ تاريخ غير صحيح تم تجاهله: $dateValue');
      }
      return null;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user': userId,
      'appointment': appointmentId,
      'status': status,
      'privacy': privacy,
      'deleted_at': deletedAt?.toIso8601String(),
      'my_note': myNote,
      'title': title,
      'region': region,
      'building': building,
      'appointment_date': appointmentDate?.toIso8601String(),
      'created': created.toIso8601String(),
      'updated': updated.toIso8601String(),
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'appointment_id': appointmentId,
      'status': status,
      'privacy': privacy,
      'deleted_at': deletedAt?.toIso8601String(),
      'my_note': myNote,
      'created': created.toIso8601String(),
      'updated': updated.toIso8601String(),
    };
  }

  factory UserAppointmentStatusModel.fromMap(Map<String, dynamic> map) {
    try {
      return UserAppointmentStatusModel(
        id: map['id'] ?? '',
        userId: map['user_id'] ?? '',
        appointmentId: map['appointment_id'] ?? '',
        status: map['status'] ?? 'active',
        privacy: map['privacy'],
        deletedAt: _parseDateTime(map['deleted_at']),
        myNote: map['my_note'],
        title: map['title'],
        region: map['region'],
        building: map['building'],
        appointmentDate: _parseDateTime(map['appointment_date']),
        created: _parseDateTime(map['created']) ?? DateTime.now(),
        updated: _parseDateTime(map['updated']) ?? DateTime.now(),
      );
    } catch (e) {
      print('⚠️ خطأ في تحليل UserAppointmentStatusModel من Map: $e');
      print('⚠️ البيانات: $map');
      rethrow;
    }
  }

  // دالة مساعدة لفحص إذا كان المستخدم حذف الموعد
  bool get isDeleted => status == 'deleted';

  // دالة مساعدة لفحص إذا كان المستخدم أرشف الموعد
  bool get isArchived => status == 'archived';

  // دالة مساعدة لفحص إذا كان المستخدم نشط في الموعد
  bool get isActive => status == 'active';

  // نسخة محدثة من الكائن
  UserAppointmentStatusModel copyWith({
    String? id,
    String? userId,
    String? appointmentId,
    String? status,
    String? privacy,
    DateTime? deletedAt,
    String? myNote,
    DateTime? created,
    DateTime? updated,
  }) {
    return UserAppointmentStatusModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      appointmentId: appointmentId ?? this.appointmentId,
      status: status ?? this.status,
      privacy: privacy ?? this.privacy,
      deletedAt: deletedAt ?? this.deletedAt,
      myNote: myNote ?? this.myNote,
      created: created ?? this.created,
      updated: updated ?? this.updated,
    );
  }

  @override
  String toString() {
    return 'UserAppointmentStatusModel(id: $id, userId: $userId, appointmentId: $appointmentId, status: $status, deletedAt: $deletedAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is UserAppointmentStatusModel &&
        other.id == id &&
        other.userId == userId &&
        other.appointmentId == appointmentId &&
        other.status == status &&
        other.privacy == privacy &&
        other.deletedAt == deletedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        userId.hashCode ^
        appointmentId.hashCode ^
        status.hashCode ^
        privacy.hashCode ^
        deletedAt.hashCode;
  }
}
