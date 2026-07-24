import '../appointment.dart';

extension AppointmentLogic on Appointment {
  /// الحصول على سجل المشاهد (سواء كان هو السجل الأساسي أو سجل طرفي)
  Invitation? get viewerRecord => viewerInvitation ?? currentUserInvitation;
  
  /// الحصول على DateTime الكامل (بالتوقيت المحلي)
  /// Always returns accurate Local Time derived from startAt
  DateTime get fullDateTime {
    return startAt.toLocal();
  }
  
  /// الحصول على الخصوصية الفعلية.
  /// الخصوصية الفعلية للموعد — مصدرها نسخة المستخدم الشخصية (invitations.privacy) فقط.
  /// جدول appointments لا يحتوي على حقل privacy بعد الآن.
  String get effectivePrivacy {
    final invPrivacy = currentUserInvitation?.privacy;
    if (invPrivacy != null && invPrivacy.isNotEmpty) {
      return invPrivacy;
    }
    return 'private'; // افتراضي آمن إذا لم تتوفر نسخة شخصية
  }

  /// التحقق إذا كان الموعد عاماً
  bool get isPublic => effectivePrivacy == 'public';
  
  /// التحقق إذا كان الموعد خاصاً
  bool get isPrivate => effectivePrivacy == 'private';

  /// التحقق إذا كان الموعد مخصصاً للأصدقاء (المتابعة المتبادلة)
  bool get isFollowers => effectivePrivacy == 'followers';
  
  /// التحقق إذا كان الموعد نشطاً (لم ينته بعد ولم يحذفه المستخدم حالياً)
  bool get isActive => !isPast && !isCancelled && !isUserDeleted && !isArchived;

  /// هل الموعد مؤرشف
  bool get isArchived => currentUserInvitation?.postStatus == PostStatus.archived;
  
  /// هل الموعد محذوف من قبل المالك (Global)
  // تم نقل isDeleted كحقل أساسي في كلاس Appointment

  /// التحقق إذا كان المستخدم الحالي قد حذف نسخته (Personal Soft Delete)
  bool get isUserDeleted => currentUserInvitation?.postStatus == PostStatus.trash;
  
  /// التحقق إذا كان الموعد قد انتهى (Local time comparison against Now)
  bool get isPast {
    final now = DateTime.now().toUtc();
    final endAt = startAt.add(Duration(minutes: duration));
    return now.isAfter(endAt) || now.isAtSameMomentAs(endAt);
  }
  
  /// التحقق إذا كان الموعد في المستقبل (لم يبدأ بعد)
  bool get isFuture {
    if (isPast || isCancelled || isNow) return false;
    final now = DateTime.now().toUtc();
    return startAt.isAfter(now);
  }

  /// التحقق إذا كان الموعد قريباً (في الـ 24 ساعة القادمة ولم يبدأ بعد)
  bool get isUpcoming {
    final now = DateTime.now();
    final difference = startAt.difference(now.toUtc()); 
    return difference.inHours <= 24 && difference.inSeconds > 0;
  }
  
  /// التحقق إذا كان الموعد جارياً الآن (من وقت البدء حتى انتهاء المدة)
  bool get isNow {
    final now = DateTime.now();
    final nowUtc = now.toUtc();
    final endAt = startAt.add(Duration(minutes: duration));
    
    // It is "now" if:
    // 1. Current time is after or at startAt
    // 2. Current time is before endAt
    return (nowUtc.isAfter(startAt) || nowUtc.isAtSameMomentAs(startAt)) && 
           nowUtc.isBefore(endAt);
  }

  /// التحقق إذا كان الموعد طوال اليوم
  /// التحقق إذا كان الموعد طوال اليوم (أو متعدد الأيام)
  bool get isAllDay => duration == 0 || duration >= 1440;
  
  /// التحقق إذا كان الموعد في نفس اليوم
  bool get isToday {
    final now = DateTime.now();
    final local = fullDateTime;
    return local.year == now.year &&
           local.month == now.month &&
           local.day == now.day;
  }
  
  /// التحقق إذا كان الموعد في الغد
  bool get isTomorrow {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final local = fullDateTime;
    return local.year == tomorrow.year &&
           local.month == tomorrow.month &&
           local.day == tomorrow.day;
  }
  
  /// التحقق إذا كان الموعد في الأسبوع الحالي
  bool get isThisWeek {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    
    final local = fullDateTime;
    return local.isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
           local.isBefore(endOfWeek.add(const Duration(days: 1)));
  }
  
  /// النص الخاص بالوقت المتبقي (بالعربية حسب القواعد المطلوبة)
  String get remainingTimeText {

    if (isPast) return 'فائت';

    if (isNow) return 'الآن';

    final now = DateTime.now().toUtc();
    final diff = startAt.difference(now);

    if (diff.isNegative) return 'الآن';

    // سنة أو أكثر
    final years = (diff.inDays / 365).floor();
    if (years >= 1) return 'بعد سنة';

    // شهر أو أكثر
    final months = (diff.inDays / 30).floor();
    if (months >= 1) {
      if (months == 1) return 'بعد شهر';
      if (months == 2) return 'بعد شهرين';
      return 'بعد $months أشهر';
    }

    // يوم أو أكثر
    final days = diff.inDays;
    if (days >= 1) {
      if (days == 1) return 'بعد يوم';
      if (days == 2) return 'بعد يومين';
      return 'بعد $days أيام';
    }

    // ساعة أو أكثر
    final hours = diff.inHours;
    if (hours >= 1) {
      if (hours == 1) return 'خلال ساعة';
      if (hours == 2) return 'خلال ساعتين';
      return 'خلال $hours ساعة';
    }

    // دقيقة أو أكثر
    final minutes = diff.inMinutes;
    if (minutes >= 1) {
      if (minutes == 1) return 'خلال دقيقة';
      if (minutes == 2) return 'خلال دقيقتين';
      return 'خلال $minutes دقيقة';
    }

    return 'خلال لحظات';
  }

  /// هل الموعد عاجل (أقل من يوم واحد)
  bool get isUrgent {
    if (isPast || isCancelled || isNow) return false;
    final now = DateTime.now().toUtc();
    return startAt.difference(now).inHours < 24;
  }

  /// وزن الترتيب (للفرز)
  /// 0: جاري الآن (أعلى أولوية)
  /// 1: قادم
  /// 2: مستقبلي
  /// 3: منتهي/ملغى/مؤرشف
  int get sortWeight {
    if (isCancelled || isDeleted || isArchived) return 3;
    if (isNow) return 0;
    if (isUpcoming) return 1;
    if (isPast) return 3;
    return 2;
  }
  
  /// نص حالة الموعد (للعرض)
  String get statusText {
    if (isCancelled) return 'فائت';
    if (isDeleted) return 'محذوف';
    if (isArchived) return 'مؤرشف';
    if (isNow) return 'جاري الآن';
    if (isPast) return 'فائت';

    if (isUpcoming) return 'قريباً';
    return 'مستقبلي';
  }
  
  /// الحصول على اسم المبنى النظيف بدون إحداثيات الخريطة
  String get cleanBuilding {
    if (building == null) return '';
    if (coordinates != null && coordinates!.isNotEmpty) return building!;
    final parts = building!.split('|');
    return parts.first.trim();
  }

  /// الحصول على إحداثيات الخريطة المضمنة في حقل المبنى
  String? get locationCoordinates {
    if (coordinates != null && coordinates!.isNotEmpty) return coordinates;
    if (building == null) return null;
    final parts = building!.split('|');
    if (parts.length > 1) {
      final coords = parts.last.trim();
      if (coords.contains(',')) {
        return coords;
      }
    }
    return null;
  }

  /// الحصول على المكان كامل
  String? get fullLocation {
    final hasRegion = region != null && region!.trim().isNotEmpty;
    final cleanB = cleanBuilding;
    final hasBuilding = cleanB.isNotEmpty;

    if (!hasRegion && !hasBuilding) return null;
    if (hasRegion && hasBuilding) return '$region - $cleanB';
    if (hasRegion) return region;
    if (hasBuilding) return cleanB;
    return null;
  }
  
  /// الموقع المختصر الذكي (يعطي الأولوية للمبنى/المكان المحدد)
  String? get smartLocation {
    final hasRegion = region != null && region!.trim().isNotEmpty;
    final cleanB = cleanBuilding;
    final hasBuilding = cleanB.isNotEmpty;

    if (!hasRegion && !hasBuilding) return null;
    // Flip order: Building - Region
    if (hasRegion && hasBuilding) return '$cleanB - $region';
    if (hasRegion) return region;
    if (hasBuilding) return cleanB;
    return null;
  }
  
  /// التحقق إذا كان الموعد لديه مكان (يتجاهل النصوص الفارغة)
  bool get hasLocation => fullLocation != null;
  
  /// التحقق إذا كان الموعد لديه وصف
  bool get hasDescription => description != null && description!.isNotEmpty;
}
