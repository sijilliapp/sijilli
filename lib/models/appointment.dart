import 'user.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:hijri/hijri_calendar.dart';
import '../core/utils/json_utils.dart';
import 'article.dart';

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
  trash,
  /// محفوظ (في قائمة المحفوظات الخاصة)
  bookmarked;

  static PostStatus fromString(String status) {
    switch (status) {
      case 'archived': return PostStatus.archived;
      case 'trash': return PostStatus.trash;
      case 'bookmarked': return PostStatus.bookmarked;
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
  final String? invitedPhone; // جديد لنظام الاستضافة عبر الهاتف
  final String? invitedName; // جديد لنظام الاستضافة عبر الهاتف
  
  // Getters للتوافق مع الكود القديم والـ DNA
  bool get isDeleted => postStatus == PostStatus.trash;
  bool get isArchived => postStatus == PostStatus.archived;

  // ====================== التوقيت الزمني (Timeline) ======================
  final DateTime? acceptedAt;
  final DateTime? declinedAt;
  final DateTime? deletedAt;
  final String? linkedArticleId;
  final Article? linkedArticle;

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
    this.invitedPhone,
    this.invitedName,
    this.acceptedAt,
    this.declinedAt,
    this.deletedAt,
    this.linkedArticleId,
    this.linkedArticle,
  });

  factory Invitation.fromJson(Map<String, dynamic> json) {
    final expand = json['expand'] as Map<String, dynamic>?;
    
    var userData = expand?['user'];
    if (userData is List && userData.isNotEmpty) userData = userData.first;
    final Map<String, dynamic>? userJson = userData is Map<String, dynamic> ? userData : null;

    var apptData = expand?['appointment'];
    if (apptData is List && apptData.isNotEmpty) apptData = apptData.first;
    final Map<String, dynamic>? apptJson = apptData is Map<String, dynamic> ? apptData : null;

    var categoryData = expand?['categories'];
    if (categoryData is List && categoryData.isNotEmpty) categoryData = categoryData.first;
    final Map<String, dynamic>? categoryJson = categoryData is Map<String, dynamic> ? categoryData : null;



    // دعم التحويل التدريجي: إذا وجدنا post_status نستخدمه، وإلا نعتمد على الحقول القديمة
    PostStatus status;
    final postStatusStr = JsonUtils.parseString(json['post_status']);
    if (postStatusStr != null) {
      status = PostStatus.fromString(postStatusStr);
    } else {
      // Fallback للبيانات القديمة
      final oldDeleted = JsonUtils.parseBool(json['is_deleted']);
      final oldArchived = JsonUtils.parseBool(json['is_archived']);
      if (oldDeleted) status = PostStatus.trash;
      else if (oldArchived) status = PostStatus.archived;
      else status = PostStatus.published;
    }

    return Invitation(
      id: JsonUtils.parseString(json['id']) ?? '',
      appointmentId: JsonUtils.parseString(json['appointment']) ?? '',
      userId: JsonUtils.parseString(json['user']) ?? '',
      status: InvitationStatus.fromString(JsonUtils.parseString(json['status']) ?? 'pending'),
      postStatus: status,
      isComplete: JsonUtils.parseBool(json['isComplete']),
      dateType: JsonUtils.parseString(json['date_type']),
      privacy: JsonUtils.parseString(json['privacy']) ?? 'private',
      personalNote: JsonUtils.parseString(json['personal_note']),
      user: userJson != null ? UserModel.fromJson(userJson) : null,
      categories: categoryJson != null ? AppointmentCategory.fromJson(categoryJson) : null,
      invitedPhone: JsonUtils.parseString(json['invited_phone']),
      invitedName: JsonUtils.parseString(json['invited_name']),
      acceptedAt: JsonUtils.parseDateTime(json['accepted_at']),
      declinedAt: JsonUtils.parseDateTime(json['declined_at']),
      deletedAt: JsonUtils.parseDateTime(json['deleted_at']),
      linkedArticleId: JsonUtils.parseString(json['linked_article']),
      linkedArticle: json['expand'] != null && json['expand']['linked_article'] != null
          ? Article.fromJson(json['expand']['linked_article'])
          : null,
    );
  }

  Invitation copyWith({
     InvitationStatus? status,
     PostStatus? postStatus,
     String? privacy,
     String? personalNote,
     AppointmentCategory? categories,
     bool? isComplete,
     String? dateType,
     String? invitedPhone,
     String? invitedName,
     DateTime? acceptedAt,
     DateTime? declinedAt,
     DateTime? deletedAt,
     String? linkedArticleId,
     Article? linkedArticle,
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
      invitedPhone: invitedPhone ?? this.invitedPhone,
      invitedName: invitedName ?? this.invitedName,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      declinedAt: declinedAt ?? this.declinedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      linkedArticleId: linkedArticleId ?? this.linkedArticleId,
      linkedArticle: linkedArticle ?? this.linkedArticle,
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
    'invited_phone': invitedPhone,
    'invited_name': invitedName,
    'accepted_at': acceptedAt?.toIso8601String(),
    'declined_at': declinedAt?.toIso8601String(),
    'deleted_at': deletedAt?.toIso8601String(),
    'linked_article': linkedArticleId,
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
  final int savesCount; // عدد الذين حفظوا الموعد
  
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
    this.savesCount = 0,
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
      var apptDataNested = invExpand?['appointment'];
      if (apptDataNested is List && apptDataNested.isNotEmpty) apptDataNested = apptDataNested.first;
      
      var hostDataNested = (apptDataNested as Map<String, dynamic>?)?['expand']?['host'];
      if (hostDataNested is List && hostDataNested.isNotEmpty) hostDataNested = hostDataNested.first;
      hostJson = hostDataNested is Map<String, dynamic> ? hostDataNested : null;
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

    // --- TIME TRUTH LOGIC ---
    // Rule: start_at (UTC) is the ONLY source of truth.
    // 1. Try to get start_at from JSON
    DateTime parsedStartAt;
    final startAtStr = JsonUtils.parseString(json['start_at']);
    if (startAtStr != null && startAtStr.isNotEmpty) {
      parsedStartAt = DateTime.parse(startAtStr);
      // Ensure it's treated as UTC if it ends with Z or comes from PB
      if (!parsedStartAt.isUtc && startAtStr.endsWith('Z')) {
        parsedStartAt = parsedStartAt.toUtc();
      }
    } else {
      // Fallback for legacy records
      parsedStartAt = JsonUtils.parseDateTime(json['date']) ?? DateTime.now();
      final tStr = JsonUtils.parseString(json['time']);
      if (tStr != null && tStr.contains(':')) {
        try {
          final t = tStr.split(':');
          // For legacy, we assume the stored time was local to the creator.
          // This is the best we can do for migration.
          parsedStartAt = DateTime(parsedStartAt.year, parsedStartAt.month, parsedStartAt.day, int.parse(t[0]), int.parse(t[1]));
        } catch (_) {}
      }
    }

    // --- HIJRI DYNAMIC SHIFT LOGIC ---
    final dateType = JsonUtils.parseString(json['date_type']) ?? 'gregorian';
    final hijriDateStr = JsonUtils.parseString(json['hijri_date']);
    
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
          
          parsedStartAt = DateTime(
            effectiveGregorian.year,
            effectiveGregorian.month,
            effectiveGregorian.day,
            localOriginal.hour,
            localOriginal.minute,
          ).toUtc();
        } catch (_) {}
      }
    }

    final localDateTime = parsedStartAt.toLocal();

    return Appointment(
      id: JsonUtils.parseString(json['id']) ?? '',
      title: JsonUtils.parseString(json['title']) ?? '',
      hostId: JsonUtils.parseString(json['host']) ?? '', 
      startAt: parsedStartAt, 
      duration: JsonUtils.parseInt(json['duration']) ?? 45,
      // Derive display fields from local time
      date: DateTime(localDateTime.year, localDateTime.month, localDateTime.day), 
      time: '${localDateTime.hour.toString().padLeft(2, '0')}:${localDateTime.minute.toString().padLeft(2, '0')}', 
      region: JsonUtils.parseString(json['region']),
      building: JsonUtils.parseString(json['building']),
      privacy: JsonUtils.parseString(json['privacy']) ?? 'private',
      description: JsonUtils.parseString(json['description']),
      participantsCount: JsonUtils.parseInt(json['participants_count']) ?? 0,
      invitedCount: JsonUtils.parseInt(json['invited_count']) ?? 0,
      isCancelled: JsonUtils.parseBool(json['is_cancelled']),
      isConfirmed: JsonUtils.parseBool(json['is_confirmed']),
      isDeleted: JsonUtils.parseBool(json['is_deleted']),
      dateType: dateType,
      streamLink: JsonUtils.parseString(json['stream_link']),
      appointmentGroupId: JsonUtils.parseString(json['appointmentGroupId'] ?? json['recurrence_id']),
      isFirstComeFirstServed: JsonUtils.parseBool(json['is_first_come']),
      recurrenceType: JsonUtils.parseString(json['recurrence_type']),
      recurrenceCount: JsonUtils.parseInt(json['recurrence_count']),
      recurrenceIndex: JsonUtils.parseInt(json['recurrence_index']),
      hijriDate: hijriDateStr,
      hijriMonth: JsonUtils.parseInt(json['hijri_month']),
      sunset: JsonUtils.parseString(json['sunset']),
      savesCount: JsonUtils.parseInt(json['saves_count']) ?? 0,
      host: hostJson != null ? UserModel.fromJson(hostJson) : null,
      currentUserInvitation: currentUserInvitation,
      viewerInvitation: viewerInvitation,
      participants: participants,
      createdAt: JsonUtils.parseDateTime(json['created']) ?? DateTime.now(),
      updatedAt: JsonUtils.parseDateTime(json['updated']) ?? DateTime.now(),
      contextAdjustment: contextAdjustment,
    );
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
    int savesCount = 0,
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
      savesCount: savesCount,
      createdAt: now,
      updatedAt: now,
    );
  }
  
  // ====================== التحويل لـ JSON ======================
  /// تحويل الموعد لـ JSON (لإرساله لـ PocketBase)
  Map<String, dynamic> toJson() {
    final utc = startAt.toUtc();
    return {
      'id': id,
      'title': title,
      'host': hostId,
      'start_at': utc.toIso8601String(),
      'duration': duration,
      // REMOVED: 'date' and 'time' strings. Let DB generate them from start_at.
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
      'saves_count': savesCount,
      'created': createdAt.toUtc().toIso8601String(),
      'updated': updatedAt.toUtc().toIso8601String(),
    };
  }
  
  /// تحويل لـ JSON للعرض (بدون الحقول الداخلية)
  Map<String, dynamic> toJsonForDisplay() {
    final local = startAt.toLocal();
    return {
      'id': id,
      'title': title,
      'date': local.toIso8601String().split('T')[0],
      'time': '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}',
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
    int? savesCount,
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
      savesCount: savesCount ?? this.savesCount,
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
