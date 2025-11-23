import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

/// 🌍 خدمة المناطق الزمنية - Timezone Service 🌍
/// 
/// تدير عرض وحفظ الأوقات بحسب المنطقة الزمنية المحلية للمستخدم
/// مثل WhatsApp وباقي التطبيقات العالمية
class TimezoneService {
  static final TimezoneService _instance = TimezoneService._internal();
  factory TimezoneService() => _instance;
  TimezoneService._internal();

  static bool _isInitialized = false;
  static late tz.Location _localLocation;
  static late tz.Location _utcLocation;

  /// تهيئة خدمة المناطق الزمنية
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // تحميل بيانات المناطق الزمنية
      tz.initializeTimeZones();

      // استخدام المنطقة الزمنية المحلية للجهاز تلقائياً
      _localLocation = tz.local;
      _utcLocation = tz.UTC;

      // في بيئة الويب، إذا كانت المنطقة UTC، استخدم البحرين كافتراضي
      if (_localLocation.name == 'UTC') {
        try {
          _localLocation = tz.getLocation('Asia/Bahrain');
          print('🌐 بيئة الويب: تم استخدام منطقة البحرين (UTC+3)');
        } catch (e) {
          print('⚠️ فشل تحميل منطقة البحرين، سيتم استخدام UTC');
        }
      }

      // حساب الفرق الزمني مع UTC
      final now = DateTime.now();
      final localNow = tz.TZDateTime.from(now, _localLocation);
      final utcOffset = localNow.timeZoneOffset;
      final offsetHours = utcOffset.inHours;
      final offsetSign = offsetHours >= 0 ? '+' : '';

      _isInitialized = true;
      print('✅ تم تهيئة خدمة المناطق الزمنية بنجاح');
      print('📍 المنطقة الزمنية: ${_localLocation.name} (UTC$offsetSign$offsetHours)');
    } catch (e) {
      print('❌ خطأ في تهيئة خدمة المناطق الزمنية: $e');
      // في حالة الخطأ، استخدم منطقة البحرين كقيمة افتراضية
      try {
        _localLocation = tz.getLocation('Asia/Bahrain');
        print('🔄 تم استخدام منطقة البحرين كقيمة افتراضية');
      } catch (e2) {
        // إذا فشل تحميل منطقة البحرين، استخدم UTC
        _localLocation = tz.UTC;
        print('🔄 تم استخدام UTC كقيمة افتراضية');
      }
      _utcLocation = tz.UTC;
      _isInitialized = true;
    }
  }

  /// الحصول على المنطقة الزمنية المحلية
  static tz.Location get localLocation {
    if (!_isInitialized) {
      throw Exception('TimezoneService غير مهيأ. استدعي initialize() أولاً');
    }
    return _localLocation;
  }

  /// الحصول على منطقة UTC
  static tz.Location get utcLocation {
    if (!_isInitialized) {
      throw Exception('TimezoneService غير مهيأ. استدعي initialize() أولاً');
    }
    return _utcLocation;
  }

  /// تحويل التاريخ والوقت المحلي إلى UTC للحفظ في قاعدة البيانات
  ///
  /// مثال:
  /// - الوقت المحلي: 2024-10-20 19:30 (البحرين +03:00)
  /// - الوقت في UTC: 2024-10-20 16:30 UTC
  static DateTime toUtc(DateTime localDateTime) {
    if (!_isInitialized) {
      return localDateTime.toUtc();
    }

    try {
      // تحويل DateTime العادي إلى TZDateTime في المنطقة المحلية للجهاز
      final localTz = tz.TZDateTime.from(localDateTime, _localLocation);

      // تحويل إلى UTC
      final utcTz = localTz.toUtc();

      // إرجاع DateTime عادي
      return DateTime.utc(
        utcTz.year,
        utcTz.month,
        utcTz.day,
        utcTz.hour,
        utcTz.minute,
        utcTz.second,
        utcTz.millisecond,
      );
    } catch (e) {
      print('❌ خطأ في تحويل الوقت إلى UTC: $e');
      return localDateTime.toUtc();
    }
  }

  /// تحويل التاريخ والوقت من UTC إلى المنطقة الزمنية المحلية للعرض
  ///
  /// مثال:
  /// - الوقت في UTC: 2024-10-20 16:30 UTC
  /// - الوقت المحلي: 2024-10-20 19:30 (حسب المنطقة الزمنية للجهاز)
  static DateTime toLocal(DateTime utcDateTime) {
    if (!_isInitialized) {
      return utcDateTime.toLocal();
    }

    try {
      // تحويل DateTime العادي إلى TZDateTime في UTC
      final utcTz = tz.TZDateTime.utc(
        utcDateTime.year,
        utcDateTime.month,
        utcDateTime.day,
        utcDateTime.hour,
        utcDateTime.minute,
        utcDateTime.second,
        utcDateTime.millisecond,
      );

      // تحويل إلى المنطقة المحلية للجهاز
      final localTz = tz.TZDateTime.from(utcTz, _localLocation);

      // إرجاع DateTime عادي
      return DateTime(
        localTz.year,
        localTz.month,
        localTz.day,
        localTz.hour,
        localTz.minute,
        localTz.second,
        localTz.millisecond,
      );
    } catch (e) {
      print('❌ خطأ في تحويل الوقت إلى المحلي: $e');
      return utcDateTime.toLocal();
    }
  }

  /// الحصول على الوقت الحالي في المنطقة الزمنية المحلية
  static DateTime now() {
    if (!_isInitialized) {
      return DateTime.now();
    }

    try {
      final nowTz = tz.TZDateTime.now(_localLocation);
      return DateTime(
        nowTz.year,
        nowTz.month,
        nowTz.day,
        nowTz.hour,
        nowTz.minute,
        nowTz.second,
        nowTz.millisecond,
      );
    } catch (e) {
      print('❌ خطأ في الحصول على الوقت الحالي: $e');
      return DateTime.now();
    }
  }

  /// تنسيق الوقت للعرض (12 ساعة مع صباحاً/مساءً)
  static String formatTime12Hour(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute;
    
    if (hour == 0) {
      return '12:${minute.toString().padLeft(2, '0')} صباحاً';
    } else if (hour < 12) {
      return '$hour:${minute.toString().padLeft(2, '0')} صباحاً';
    } else if (hour == 12) {
      return '12:${minute.toString().padLeft(2, '0')} مساءً';
    } else {
      return '${hour - 12}:${minute.toString().padLeft(2, '0')} مساءً';
    }
  }

  /// تنسيق الوقت للعرض (24 ساعة)
  static String formatTime24Hour(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// تنسيق التاريخ والوقت للعرض
  static String formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} - ${formatTime12Hour(dateTime)}';
  }

  /// الحصول على معلومات المنطقة الزمنية
  static String getTimezoneInfo() {
    if (!_isInitialized) {
      return 'غير مهيأ';
    }
    
    final now = tz.TZDateTime.now(_localLocation);
    final offset = now.timeZoneOffset;
    final hours = offset.inHours;
    final minutes = offset.inMinutes.remainder(60);
    
    final sign = hours >= 0 ? '+' : '';
    return '${_localLocation.name} (UTC$sign$hours:${minutes.abs().toString().padLeft(2, '0')})';
  }

  /// فحص ما إذا كان التطبيق مهيأ
  static bool get isInitialized => _isInitialized;
}
