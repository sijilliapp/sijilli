class AppointmentModel {
  final String id;
  final String title;
  final String? region;
  final String? building;
  final String?
  privacy; // للتوافق فقط - الخصوصية الفعلية في user_appointment_status
  final String status;
  final DateTime appointmentDate;
  final String?
  dateType; // نوع التاريخ المختار أثناء الإنشاء: 'gregorian' أو 'hijri'
  // التاريخ الهجري الأساسي (إذا كان الأساسي هجري)
  final int? hijriDay;
  final int? hijriMonth;
  final int? hijriYear;
  final String hostId;
  final int? duration; // مدة الموعد بالدقائق
  final String? streamLink;
  final String? noteShared;
  final DateTime created;
  final DateTime updated;

  AppointmentModel({
    required this.id,
    required this.title,
    this.region,
    this.building,
    this.privacy,
    required this.status,
    required this.appointmentDate,
    this.dateType,
    this.hijriDay,
    this.hijriMonth,
    this.hijriYear,
    required this.hostId,
    this.duration,
    this.streamLink,
    this.noteShared,
    required this.created,
    required this.updated,
  });

  factory AppointmentModel.fromJson(Map<String, dynamic> json) {
    return AppointmentModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      region: json['region'],
      building: json['building'],
      privacy: json['privacy'], // للتوافق فقط
      status: json['status'] ?? 'active',
      // ملاحظة: appointmentDate يأتي من قاعدة البيانات بتوقيت UTC
      // يجب تحويله إلى التوقيت المحلي عند العرض باستخدام TimezoneService.toLocal()
      appointmentDate:
          _parseDateTime(json['appointment_date']) ?? DateTime.now(),
      dateType: json['date_type'], // نوع التاريخ المختار أثناء الإنشاء
      hijriDay: json['hijri_day'] as int?,
      hijriMonth: json['hijri_month'] as int?,
      hijriYear: json['hijri_year'] as int?,
      hostId: json['host'] ?? '',
      duration: json['duration'] as int?,
      streamLink: json['stream_link'],
      noteShared: json['note_shared'],
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
      'title': title,
      'region': region,
      'building': building,
      'privacy': privacy,
      'status': status,
      'appointment_date': appointmentDate.toIso8601String(),
      'date_type': dateType,
      'hijri_day': hijriDay,
      'hijri_month': hijriMonth,
      'hijri_year': hijriYear,
      'host': hostId,
      'duration': duration,
      'stream_link': streamLink,
      'note_shared': noteShared,
      'created': created.toIso8601String(),
      'updated': updated.toIso8601String(),
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'region': region,
      'building': building,
      'privacy': privacy,
      'status': status,
      'appointment_date': appointmentDate.toIso8601String(),
      'date_type': dateType,
      'hijri_day': hijriDay,
      'hijri_month': hijriMonth,
      'hijri_year': hijriYear,
      'host_id': hostId,
      'stream_link': streamLink,
      'note_shared': noteShared,
      'created': created.toIso8601String(),
      'updated': updated.toIso8601String(),
    };
  }

  factory AppointmentModel.fromMap(Map<String, dynamic> map) {
    return AppointmentModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      region: map['region'],
      building: map['building'],
      privacy: map['privacy'] ?? 'public',
      status: map['status'] ?? 'active',
      appointmentDate:
          _parseDateTime(map['appointment_date']) ?? DateTime.now(),
      dateType: map['date_type'],
      hijriDay: map['hijri_day'] as int?,
      hijriMonth: map['hijri_month'] as int?,
      hijriYear: map['hijri_year'] as int?,
      hostId: map['host_id'] ?? '',
      duration: map['duration'] as int?,
      streamLink: map['stream_link'],
      noteShared: map['note_shared'],
      created: _parseDateTime(map['created']) ?? DateTime.now(),
      updated: _parseDateTime(map['updated']) ?? DateTime.now(),
    );
  }
}
