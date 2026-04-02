import 'user.dart';
import 'package:flutter/material.dart';
import 'package:hijri/hijri_calendar.dart';

export 'extensions/appointment_logic.dart';

/// حالة الضيف بالنسبة للموعد
enum InvitationStatus {
  /// لم يرد بعد (رمادي)
  pending,
  /// وافق على الدعوة (أزرق)
  accepted,
  /// رفض الدعوة (تختفي الكبسولة)
  declined,
  /// وافق ثم حذف الموعد (أحمر)
  deletedAfterAccept;

  /// الحصول على القيمة من النص (لـ PocketBase)
  static InvitationStatus fromString(String status) {
    switch (status) {
      case 'accepted': return InvitationStatus.accepted;
      case 'declined': return InvitationStatus.declined;
      case 'deleted_after_accept': return InvitationStatus.deletedAfterAccept;
      default: return InvitationStatus.pending;
    }
  }

  /// تحويل القيمة لنص (لـ PocketBase)
  @override
  String toString() => name == 'deletedAfterAccept' ? 'deleted_after_accept' : name;
}

/// التصنيفات الشخصية للمواعيد (مثلاً: عمل، أنف، حنجرة)
class AppointmentCategory {
  final String id;
  final String name;
  final String? icon;
  final String? color;
  final String? userId; // صاحب التصنيف (null للعام)

  AppointmentCategory({
    required this.id,
    required this.name,
    this.icon,
    this.color,
    this.userId,
  });

  factory AppointmentCategory.fromJson(Map<String, dynamic> json) {
    return AppointmentCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String?,
      color: json['color'] as String?,
      userId: json['user'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'icon': icon,
    'color': color,
    'user': userId,
  };

  /// الحصول على اللون كـ Color
  Color? getColor() {
    if (color == null || color!.isEmpty) return null;
    try {
      String hexColor = color!.replaceAll('#', '');
      if (hexColor.length == 6) hexColor = 'FF$hexColor';
      return Color(int.parse('0x$hexColor'));
    } catch (_) {
      return null;
    }
  }
}

/// حالة نشر الموعد (أين يتواجد)
enum PostStatus {
  /// منشور (في السجل والوارد)
  published,
  /// مؤرشف (في الأرشيف)
  archived,
  /// في المحذوفات
  trash;

  static PostStatus fromString(String status) {
    switch (status) {
      case 'archived': return PostStatus.archived;
      case 'trash': return PostStatus.trash;
      default: return PostStatus.published;
    }
  }

  @override
  String toString() => name;
}

/// سجل الدعوة أو النسخة الشخصية من الموعد
class Invitation {
  final String id;
  final String appointmentId;
  final String userId;
  final InvitationStatus status;
  final PostStatus postStatus; // الحالة المركزية الجديدة
  final String privacy; // خصوصية النسخة (public, private, followers)
  final String? personalNote;
  final UserModel? user; // البيانات الموسعة للمستخدم (الضيف)
  final AppointmentCategory? categories; // التصنيف الشخصي للموعد (تم تغيير المسمى للجمع ليتوافق مع PB)
  final bool isComplete; // جديد من PB
  final String? dateType; // جديد من PB
  
  // Getters للتوافق مع الكود القديم والـ DNA
  bool get isDeleted => postStatus == PostStatus.trash;
  bool get isArchived => postStatus == PostStatus.archived;

  // ====================== التوقيت الزمني (Timeline) ======================
  final DateTime? acceptedAt;
  final DateTime? declinedAt;
  final DateTime? deletedAt;

  Invitation({
    required this.id,
    required this.appointmentId,
    required this.userId,
    this.status = InvitationStatus.pending,
    this.postStatus = PostStatus.published,
    this.privacy = 'private',
    this.personalNote,
    this.user,
    this.categories,
    this.isComplete = false,
    this.dateType,
    this.acceptedAt,
    this.declinedAt,
    this.deletedAt,
  });

  factory Invitation.fromJson(Map<String, dynamic> json) {
    final expand = json['expand'] as Map<String, dynamic>?;
    final userJson = expand?['user'] as Map<String, dynamic>?;
    final categoryJson = expand?['categories'] as Map<String, dynamic>?;

    // دعم التحويل التدريجي: إذا وجدنا post_status نستخدمه، وإلا نعتمد على الحقول القديمة
    PostStatus status;
    if (json['post_status'] != null) {
      status = PostStatus.fromString(json['post_status'] as String);
    } else {
      // Fallback للبيانات القديمة
      final oldDeleted = json['is_deleted'] as bool? ?? false;
      final oldArchived = json['is_archived'] as bool? ?? false;
      if (oldDeleted) status = PostStatus.trash;
      else if (oldArchived) status = PostStatus.archived;
      else status = PostStatus.published;
    }

    return Invitation(
      id: json['id'] as String,
      appointmentId: json['appointment'] as String,
      userId: json['user'] as String,
      status: InvitationStatus.fromString(json['status'] as String? ?? 'pending'),
      postStatus: status,
      isComplete: json['isComplete'] as bool? ?? false,
      dateType: json['date_type'] as String?,
      privacy: json['privacy'] as String? ?? 'private',
      personalNote: json['personal_note'] as String?,
      user: userJson != null ? UserModel.fromJson(userJson) : null,
      categories: categoryJson != null ? AppointmentCategory.fromJson(categoryJson) : null,
      acceptedAt: _parseDateTime(json['accepted_at']),
      declinedAt: _parseDateTime(json['declined_at']),
      deletedAt: _parseDateTime(json['deleted_at']),
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null || value.toString().isEmpty) return null;
    try {
      return DateTime.parse(value as String);
    } catch (_) {
      return null;
    }
  }

  Invitation copyWith({
     InvitationStatus? status,
     PostStatus? postStatus,
     String? privacy,
     String? personalNote,
     AppointmentCategory? categories,
     bool? isComplete,
     String? dateType,
     DateTime? acceptedAt,
     DateTime? declinedAt,
     DateTime? deletedAt,
  }) {
    return Invitation(
      id: id,
      appointmentId: appointmentId,
      userId: userId,
      status: status ?? this.status,
      postStatus: postStatus ?? this.postStatus,
      privacy: privacy ?? this.privacy,
      personalNote: personalNote ?? this.personalNote,
      user: user,
      categories: categories ?? this.categories,
      isComplete: isComplete ?? this.isComplete,
      dateType: dateType ?? this.dateType,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      declinedAt: declinedAt ?? this.declinedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'appointment': appointmentId,
    'user': userId,
    'status': status.toString(),
    'post_status': postStatus.toString(),
    'isComplete': isComplete,
    'date_type': dateType,
    'privacy': privacy,
    'personal_note': personalNote,
    'accepted_at': acceptedAt?.toIso8601String(),
    'declined_at': declinedAt?.toIso8601String(),
    'deleted_at': deletedAt?.toIso8601String(),
  };
}

class Appointment {
  // ====================== الحقول الأساسية ======================
  final String id;
  final String title;
  final String hostId; // ID المستخدم المنشئ
  
  // ====================== الزمان والمكان ======================
  /// نقطة الزمن الحقيقية للموعد بالتوقيت العالمي
  /// This is the source of truth for time calculations
  final DateTime startAt; 

  /// مدة الموعد بالدقائق (افتراضياً 45 دقيقة)
  final int duration; 

  final DateTime date; // مبقى للتوافق (للعرض فقط)
  final String time; // مبقى للتوافق (للعرض فقط)
  
  final String? region; // المنطقة
  final String? building; // المبنى
  
  // ====================== الإعدادات ======================
  final String privacy; // 'public' أو 'private'
  final String? description; // وصف إضافي
  
  // ====================== الإحصائيات ======================
  final int participantsCount; // عدد المشاركين المقبولين
  final int invitedCount; // عدد المدعوين
  
  // ====================== الحالات ======================
  final bool isCancelled; // ملغى
  final bool isConfirmed; // مؤكد (وافق الجميع)
  final bool isDeleted; // محذوف من قبل المضيف (global)
  final String dateType; // 'gregorian' أو 'hijri'
  final String? streamLink; // رابط البث (جديد من PB)
  final String? appointmentGroupId; // معرف مجموعة المواعيد (لالتكرار أو غيره)
  final bool isFirstComeFirstServed; // خاصية الأسبقية
  
  // ====================== التكرار (Recurrence) ======================
  final String? recurrenceType; // 'none', 'daily', 'weekly', 'annual'
  final int? recurrenceCount; // عدد المرات الإجمالي
  final int? recurrenceIndex; // ترتيبه في السلسلة (مثلاً: 2 من 4)
  
  // ====================== التاريخ الهجري ======================
  final String? hijriDate; // 1447-09-25
  final int? hijriMonth; // 9
  final String? sunset; // وقت الغروب (جديد)
  
  // ====================== البيانات الموسعة (Expand) ======================
  final UserModel? host; // بيانات المضيف الموسعة
  final Invitation? currentUserInvitation; // نسخة/دعوة السجل الحالي (صاحب الصفحة/السياق)
  final Invitation? viewerInvitation; // دعوة المستخدم المشاهد (لأزرار التفاعل)
  final List<Invitation>? participants; // جميع المشاركين والدعوات
  
  // ====================== التواريخ ======================
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // ====================== السياق (Context) ======================
  /// مقياس التصحيح الذي تم بناءً عليه حساب الوقت الفيزيائي لهذا الموعد 
  /// (يعتمد على صاحب الصفحة التي يتم استعراض الموعد فيها)
  final int contextAdjustment;

  // ====================== بيانات المضيف المساعدة ======================
  String? get hostName => host?.name;
  String? get hostAvatar => host?.avatar != null ? 'https://sijilli.pockethost.io/api/files/users/${host!.id}/${host!.avatar}' : null;

  // ====================== المنشئ ======================
  Appointment({
    required this.id,
    required this.title,
    required this.hostId,
    required this.startAt,
    this.duration = 45, // Default to 45 mins
    required this.date,
    required this.time,
    this.region,
    this.building,
    this.privacy = 'private',
    this.description,
    this.participantsCount = 0,
    this.invitedCount = 0,
    this.isCancelled = false,
    this.isConfirmed = false,
    this.isDeleted = false,
    this.dateType = 'gregorian',
    this.streamLink, // جديد
    this.appointmentGroupId,
    this.isFirstComeFirstServed = false,
    this.recurrenceType,
    this.recurrenceCount,
    this.recurrenceIndex,
    this.hijriDate,
    this.hijriMonth, // جديد
    this.sunset,
    this.host,
    this.currentUserInvitation,
    this.viewerInvitation,
    this.participants,
    required this.createdAt,
    required this.updatedAt,
    this.contextAdjustment = 0,
  });
  
  // ====================== دوال المصنع ======================
  /// إنشاء موعد من JSON (من PocketBase)
  factory Appointment.fromJson(Map<String, dynamic> json, {int contextAdjustment = 0}) {
    // جلب البيانات الموسعة إن وجدت
    final expand = json['expand'] as Map<String, dynamic>?;
    
    // PocketBase nested expansion can sometimes be flattened or nested. 
    // We check both the direct 'host' in expand, and potentially in a nested expand if 'appointment' was expanded from an invitation
    var hostData = expand?['host'];
    if (hostData is List && hostData.isNotEmpty) hostData = hostData.first;
    Map<String, dynamic>? hostJson = hostData is Map<String, dynamic> ? hostData : null;
    
    // Safety fallback: if we were passed an invitation expansion that contains the host 
    // (unlikely if getAppointments is used correctly but good for robustness)
    if (hostJson == null && json['currentUserInvitation'] != null) {
      final invExpand = (json['currentUserInvitation'] as Map<String, dynamic>)['expand'] as Map<String, dynamic>?;
      hostJson = invExpand?['appointment']?['expand']?['host'] as Map<String, dynamic>?;
    }
    
    // جلب المشاركين (دعم أكثر من مفتاح للتوسع)
    final invitationItems = (expand?['invitations_via_appointment'] ?? expand?['invitations']) as List<dynamic>?;
    final List<Invitation>? participants = invitationItems?.map((e) => Invitation.fromJson(e as Map<String, dynamic>)).toList();

    // تحديد دعوة المستخدم الحالي (إذا تم تمريرها في JSON أو موجودة في القائمة)
    // ملاحظة: قد نحتاج لتمرير userId من الخارج أو البحث في القائمة
    final currentUserInvitationJson = json['currentUserInvitation'] as Map<String, dynamic>?;
    Invitation? currentUserInvitation = currentUserInvitationJson != null 
        ? Invitation.fromJson(currentUserInvitationJson) 
        : null;

    final viewerInvitationJson = json['viewerInvitation'] as Map<String, dynamic>?;
    Invitation? viewerInvitation = viewerInvitationJson != null 
        ? Invitation.fromJson(viewerInvitationJson) 
        : null;

    // Handle Time Logic: Prefers 'start_at' (UTC), falls back to legacy 'date' + 'time'
    DateTime parsedStartAt;
    try {
      if (json['start_at'] != null && json['start_at'].toString().isNotEmpty) {
        parsedStartAt = DateTime.parse(json['start_at'] as String);
      } else if (json['date'] != null && json['date'].toString().isNotEmpty) {
        // Legacy Fallback
        final d = DateTime.parse(json['date'] as String);
        if (json['time'] != null && json['time'].toString().isNotEmpty) {
          final t = (json['time'] as String).split(':');
          parsedStartAt = DateTime(d.year, d.month, d.day, int.parse(t[0]), int.parse(t[1]));
        } else {
          parsedStartAt = d;
        }
      } else {
        // Safe default if everything else fails
        parsedStartAt = DateTime.now();
      }
    } catch (e) {
      print('⚠️ Error parsing appointment date: $e');
      parsedStartAt = DateTime.now();
    }

    // --- HIJRI DYNAMIC SHIFT LOGIC ---
    // The physical Gregorian time must dynamically shift according to the current "Page Owner" 
    // adjustment, passed explicitly as `contextAdjustment`.
    final dateType = json['date_type'] as String? ?? 'gregorian';
    final hijriDateStr = json['hijri_date'] as String?;
    
    if (dateType == 'hijri' && hijriDateStr != null && hijriDateStr.isNotEmpty) {
      final parts = hijriDateStr.split('-');
      if (parts.length == 3) {
        try {
          final hYear = int.parse(parts[0]);
          final hMonth = int.parse(parts[1]);
          final hDay = int.parse(parts[2].trim().split(' ').first);
          
          final hijriCal = HijriCalendar();
          final baseGregorian = hijriCal.hijriToGregorian(hYear, hMonth, hDay);
          
          final effectiveGregorian = baseGregorian.subtract(Duration(days: contextAdjustment));
          
          final localOriginal = parsedStartAt.toLocal();
          
          // Overwrite the physical timestamp
          parsedStartAt = DateTime(
            effectiveGregorian.year,
            effectiveGregorian.month,
            effectiveGregorian.day,
            localOriginal.hour,
            localOriginal.minute,
          ).toUtc();
        } catch (e) {
          print('⚠️ Error shifting Hijri physical time: $e');
        }
      }
    }

    // Prepare display helpers from the truth source (Local Time for display)
    // parsedStartAt from DB (UTC) -> toLocal() for display fields
    final localDateTime = parsedStartAt.toLocal();

    return Appointment(
      id: json['id'] as String,
      title: json['title'] as String,
      hostId: json['host'] as String, 
      startAt: parsedStartAt, 
      duration: json['duration'] as int? ?? 45, // Get from JSON or default to 45
      date: DateTime(localDateTime.year, localDateTime.month, localDateTime.day), 
      time: '${localDateTime.hour.toString().padLeft(2, '0')}:${localDateTime.minute.toString().padLeft(2, '0')}', 
      region: json['region'] as String?,
      building: json['building'] as String?,
      privacy: json['privacy'] as String? ?? 'private',
      description: json['description'] as String?,
      participantsCount: json['participants_count'] as int? ?? 0,
      invitedCount: json['invited_count'] as int? ?? 0,
      isCancelled: json['is_cancelled'] as bool? ?? false,
      isConfirmed: json['is_confirmed'] as bool? ?? false,
      isDeleted: json['is_deleted'] as bool? ?? false,
      dateType: json['date_type'] as String? ?? 'gregorian',
      streamLink: json['stream_link'] as String?,
      appointmentGroupId: json['appointmentGroupId'] as String? ?? json['recurrence_id'] as String?,
      isFirstComeFirstServed: json['is_first_come'] as bool? ?? false,
      recurrenceType: json['recurrence_type'] as String?,
      recurrenceCount: json['recurrence_count'] as int?,
      recurrenceIndex: json['recurrence_index'] as int?,
      hijriDate: json['hijri_date'] as String?,
      hijriMonth: json['hijri_month'] as int?,
      sunset: json['sunset'] as String?,
      host: hostJson != null ? UserModel.fromJson(hostJson) : null,
      currentUserInvitation: currentUserInvitation,
      viewerInvitation: viewerInvitation,
      participants: participants,
      createdAt: _parseDateTime(json['created']) ?? DateTime.now(),
      updatedAt: _parseDateTime(json['updated']) ?? DateTime.now(),
      contextAdjustment: contextAdjustment,
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null || value.toString().isEmpty) return null;
    try {
      return DateTime.parse(value as String);
    } catch (_) {
      return null;
    }
  }
  
  /// إنشاء موعد جديد (لإنشاء موعد)
  factory Appointment.newAppointment({
    required String title,
    required String hostId,
    required DateTime date,
    required String time,
    int duration = 45,
    String? region,
    String? building,
    String privacy = 'private',
    String? description,
    String dateType = 'gregorian',
    String? hijriDate,
    int? hijriMonth,
    String? recurrenceType,
    int? recurrenceCount,
    int? recurrenceIndex,
    String? appointmentGroupId,
    bool isFirstComeFirstServed = false,
    String? streamLink,
    String? sunset,
  }) {
    final now = DateTime.now();
    
    // Combine inputs to create the Local Date Time
    final timeParts = time.split(':');
    final localFullDateTime = DateTime(
      date.year, 
      date.month, 
      date.day, 
      int.parse(timeParts[0]), 
      int.parse(timeParts[1])
    );
    
    // Convert to UTC for storage
    final startAtUtc = localFullDateTime.toUtc();

    return Appointment(
      id: '', // سيتم توليده من PocketBase
      title: title,
      hostId: hostId,
      startAt: startAtUtc,
      duration: duration,
      date: date,
      time: time,
      region: region,
      building: building,
      privacy: privacy,
      description: description,
      dateType: dateType,
      appointmentGroupId: appointmentGroupId,
      isFirstComeFirstServed: isFirstComeFirstServed,
      streamLink: streamLink,
      recurrenceType: recurrenceType,
      recurrenceCount: recurrenceCount,
      recurrenceIndex: recurrenceIndex,
      hijriDate: hijriDate,
      hijriMonth: hijriMonth,
      sunset: sunset,
      createdAt: now,
      updatedAt: now,
    );
  }
  
  // ====================== التحويل لـ JSON ======================
  /// تحويل الموعد لـ JSON (لإرساله لـ PocketBase)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'host': hostId,
      'start_at': startAt.toUtc().toIso8601String(),
      'duration': duration,
      'date': date.toIso8601String().split('T')[0],
      'time': time,
      'region': region,
      'building': building,
      'privacy': privacy,
      'description': description,
      'participants_count': participantsCount,
      'invited_count': invitedCount,
      'is_archived': currentUserInvitation?.postStatus == PostStatus.archived,
      'is_cancelled': isCancelled,
      'is_confirmed': isConfirmed,
      'is_deleted': isDeleted,
      'date_type': dateType,
      'stream_link': streamLink,
      'appointmentGroupId': appointmentGroupId,
      'is_first_come': isFirstComeFirstServed,
      'recurrence_type': recurrenceType,
      'recurrence_count': recurrenceCount,
      'recurrence_index': recurrenceIndex,
      'hijri_date': hijriDate,
      'hijri_month': hijriMonth,
      'sunset': sunset,
      'created': createdAt.toIso8601String(),
      'updated': updatedAt.toIso8601String(),
    };
  }
  
  /// تحويل لـ JSON للعرض (بدون الحقول الداخلية)
  Map<String, dynamic> toJsonForDisplay() {
    return {
      'id': id,
      'title': title,
      'date': date.toIso8601String().split('T')[0],
      'time': time,
      'region': region,
      'building': building,
      'privacy': privacy,
      'description': description,
      'participants_count': participantsCount,
    };
  }
  
  // ====================== الدوال المساعدة ======================
  /// نسخ الموعد مع تحديث بعض الحقول
  Appointment copyWith({
    String? id,
    String? title,
    String? hostId,
    DateTime? startAt,
    int? duration,
    DateTime? date,
    String? time,
    String? region,
    String? building,
    String? privacy,
    String? description,
    int? participantsCount,
    int? invitedCount,
    bool? isCancelled,
    bool? isConfirmed,
    String? dateType,
    String? streamLink,
    String? appointmentGroupId,
    String? recurrenceType,
    int? recurrenceCount,
    int? recurrenceIndex,
    String? hijriDate,
    int? hijriMonth,
    String? sunset,
    UserModel? host,
    Invitation? currentUserInvitation,
    Invitation? viewerInvitation,
    List<Invitation>? participants,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Appointment(
      id: id ?? this.id,
      title: title ?? this.title,
      hostId: hostId ?? this.hostId,
      startAt: startAt ?? this.startAt,
      duration: duration ?? this.duration,
      date: date ?? this.date,
      time: time ?? this.time,
      region: region ?? this.region,
      building: building ?? this.building,
      privacy: privacy ?? this.privacy,
      description: description ?? this.description,
      participantsCount: participantsCount ?? this.participantsCount,
      invitedCount: invitedCount ?? this.invitedCount,
      isCancelled: isCancelled ?? this.isCancelled,
      isConfirmed: isConfirmed ?? this.isConfirmed,
      dateType: dateType ?? this.dateType,
      streamLink: streamLink ?? this.streamLink,
      appointmentGroupId: appointmentGroupId ?? this.appointmentGroupId,
      isFirstComeFirstServed: isFirstComeFirstServed ?? isFirstComeFirstServed,
      recurrenceType: recurrenceType ?? this.recurrenceType,
      recurrenceCount: recurrenceCount ?? this.recurrenceCount,
      recurrenceIndex: recurrenceIndex ?? this.recurrenceIndex,
      hijriDate: hijriDate ?? this.hijriDate,
      hijriMonth: hijriMonth ?? this.hijriMonth,
      sunset: sunset ?? this.sunset,
      host: host ?? this.host,
      currentUserInvitation: currentUserInvitation ?? this.currentUserInvitation,
      viewerInvitation: viewerInvitation ?? this.viewerInvitation,
      participants: participants ?? this.participants,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
  
  // ====================== المقارنة ======================
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Appointment && other.id == id;
  }
  
  @override
  int get hashCode => id.hashCode;
  
  @override
  String toString() {
    return 'Appointment(id: $id, title: $title, startAt: $startAt)';
  }
}
