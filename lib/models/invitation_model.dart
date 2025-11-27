class InvitationModel {
  final String id;
  final String appointmentId;
  final String guestId;
  final String status; // invited, accepted, rejected, deleted_after_accept
  final String? privacy; // public, private
  final DateTime? respondedAt;
  final DateTime created;
  final DateTime updated;

  InvitationModel({
    required this.id,
    required this.appointmentId,
    required this.guestId,
    required this.status,
    this.privacy,
    this.respondedAt,
    required this.created,
    required this.updated,
  });

  factory InvitationModel.fromJson(Map<String, dynamic> json) {
    return InvitationModel(
      id: json['id'] ?? '',
      appointmentId: json['appointment'] ?? '',
      guestId: json['guest'] ?? '',
      status: json['status'] ?? 'invited',
      privacy: json['privacy'],
      respondedAt: json['respondedAt'] != null
          ? _parseDateTime(json['respondedAt'])
          : null,
      created: _parseDateTime(json['created']) ?? DateTime.now(),
      updated: _parseDateTime(json['updated']) ?? DateTime.now(),
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

        // محاولة تحليل التاريخ والتأكد من أنه UTC
        // ✅ نستخدم .toUtc() دائماً لضمان أن النتيجة UTC
        return DateTime.parse(cleanValue).toUtc();
      }
      return null;
    } catch (e) {
      // تسجيل الخطأ فقط للقيم غير المتوقعة
      if (dateValue != null && dateValue.toString().trim().isNotEmpty) {
        print('⚠️ تاريخ دعوة غير صحيح تم تجاهله: $dateValue');
      }
      return null;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'appointment': appointmentId,
      'guest': guestId,
      'status': status,
      'privacy': privacy,
      'respondedAt': respondedAt?.toIso8601String(),
      'created': created.toIso8601String(),
      'updated': updated.toIso8601String(),
    };
  }

  // تحويل حالة الدعوة إلى حالة الطوق
  String get ringStatus {
    switch (status) {
      case 'accepted':
        return 'active';
      case 'deleted_after_accept':
        return 'deleted';
      case 'rejected':
        return 'cancelled';
      case 'invited':
      default:
        return 'pending';
    }
  }

  // نسخة محدثة من الدعوة
  InvitationModel copyWith({
    String? id,
    String? appointmentId,
    String? guestId,
    String? status,
    String? privacy,
    DateTime? respondedAt,
    DateTime? created,
    DateTime? updated,
  }) {
    return InvitationModel(
      id: id ?? this.id,
      appointmentId: appointmentId ?? this.appointmentId,
      guestId: guestId ?? this.guestId,
      status: status ?? this.status,
      privacy: privacy ?? this.privacy,
      respondedAt: respondedAt ?? this.respondedAt,
      created: created ?? this.created,
      updated: updated ?? this.updated,
    );
  }
}
