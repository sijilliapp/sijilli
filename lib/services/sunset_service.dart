import 'package:flutter/services.dart';

/// 🌅 خدمة أوقات الغروب - Sunset Service 🌅
/// 
/// تدير أوقات الشروق والغروب لجميع أيام السنة
/// وتوفر وقت الغروب كوقت افتراضي للمواعيد
class SunsetService {
  static final SunsetService _instance = SunsetService._internal();
  factory SunsetService() => _instance;
  SunsetService._internal();

  static bool _isInitialized = false;
  static Map<String, Map<String, String>> _sunsetData = {};

  /// تهيئة خدمة أوقات الغروب
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // تحميل ملف أوقات الشروق والغروب
      final String data = await rootBundle.loadString('assets/data/sunrise_sunset_times.csv');
      
      // تحليل البيانات
      _parseSunsetData(data);
      
      _isInitialized = true;
      print('✅ تم تهيئة خدمة أوقات الغروب بنجاح');
      print('📊 تم تحميل ${_sunsetData.length} يوم من بيانات الغروب');
    } catch (e) {
      print('❌ خطأ في تهيئة خدمة أوقات الغروب: $e');
      _isInitialized = true; // تجنب المحاولة مرة أخرى
    }
  }

  /// تحليل بيانات ملف CSV
  static void _parseSunsetData(String csvData) {
    final lines = csvData.split('\n');
    
    // تخطي السطر الأول (العناوين)
    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      try {
        final parts = line.split(',');
        if (parts.length >= 4) {
          final dayMonth = parts[0].trim();        // "22-10"
          final sunrise = parts[1].trim();         // "5:40 AM"
          final noon = parts[2].trim();            // "11:22 AM"
          final sunset = parts[3].trim();          // "5:04 PM"

          _sunsetData[dayMonth] = {
            'sunrise': sunrise,
            'noon': noon,
            'sunset': sunset,
          };
        }
      } catch (e) {
        // تجاهل الأسطر التالفة
        continue;
      }
    }
  }

  /// الحصول على وقت الغروب لتاريخ معين
  /// 
  /// Parameters:
  /// - [date]: التاريخ الميلادي
  /// 
  /// Returns: وقت الغروب بصيغة "5:04 PM" أو null إذا لم يوجد
  static String? getSunsetTime(DateTime date) {
    if (!_isInitialized) {
      print('⚠️ خدمة أوقات الغروب غير مهيأة');
      return null;
    }

    // تنسيق التاريخ كـ "DD-MM"
    final dayMonth = '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}';
    
    final data = _sunsetData[dayMonth];
    return data?['sunset'];
  }

  /// الحصول على وقت الشروق لتاريخ معين
  static String? getSunriseTime(DateTime date) {
    if (!_isInitialized) {
      print('⚠️ خدمة أوقات الغروب غير مهيأة');
      return null;
    }

    final dayMonth = '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}';
    
    final data = _sunsetData[dayMonth];
    return data?['sunrise'];
  }

  /// الحصول على وقت الظهر لتاريخ معين
  static String? getNoonTime(DateTime date) {
    if (!_isInitialized) {
      print('⚠️ خدمة أوقات الغروب غير مهيأة');
      return null;
    }

    final dayMonth = '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}';
    
    final data = _sunsetData[dayMonth];
    return data?['noon'];
  }

  /// تحويل وقت الغروب إلى ساعة ودقيقة
  /// 
  /// Parameters:
  /// - [sunsetTime]: وقت الغروب بصيغة "5:04 PM"
  /// 
  /// Returns: Map يحتوي على hour و minute و period
  static Map<String, dynamic>? parseSunsetTime(String? sunsetTime) {
    if (sunsetTime == null || sunsetTime.isEmpty) return null;

    try {
      // تحليل الوقت مثل "5:04 PM"
      final parts = sunsetTime.split(' ');
      if (parts.length != 2) return null;

      final timePart = parts[0]; // "5:04"
      final periodPart = parts[1]; // "PM"

      final timeParts = timePart.split(':');
      if (timeParts.length != 2) return null;

      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      // تحويل إلى العربية
      final period = periodPart.toUpperCase() == 'AM' ? 'صباحاً' : 'مساءً';

      return {
        'hour': hour,
        'minute': minute,
        'period': period,
      };
    } catch (e) {
      print('❌ خطأ في تحليل وقت الغروب: $sunsetTime');
      return null;
    }
  }

  /// الحصول على وقت الغروب المحلل لتاريخ معين
  /// 
  /// دالة مساعدة تجمع بين getSunsetTime و parseSunsetTime
  static Map<String, dynamic>? getParsedSunsetTime(DateTime date) {
    final sunsetTime = getSunsetTime(date);
    return parseSunsetTime(sunsetTime);
  }

  /// فحص ما إذا كانت الخدمة مهيأة
  static bool get isInitialized => _isInitialized;

  /// الحصول على عدد الأيام المحملة
  static int get loadedDaysCount => _sunsetData.length;

  /// الحصول على جميع البيانات (للتطوير والاختبار)
  static Map<String, Map<String, String>> get allData => Map.from(_sunsetData);
}
