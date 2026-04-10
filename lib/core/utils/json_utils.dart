// 📍 lib/core/utils/json_utils.dart
// 🛠️ أدوات معالجة بيانات JSON بأمان لمنع الانهيارات في الويب (JSArray errors)

class JsonUtils {
  /// تحليل النصوص بأمان (تحويل القوائم إلى نص بأخذ العنصر الأول)
  static String? parseString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is List) {
       return value.isNotEmpty ? value.first.toString() : null;
    }
    return value.toString();
  }

  /// تحليل الأرقام الصحيحة بأمان
  static int? parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    if (value is List && value.isNotEmpty) return parseInt(value.first);
    return null;
  }

  /// تحليل الأرقام العشرية بأمان
  static double? parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    if (value is List && value.isNotEmpty) return parseDouble(value.first);
    return null;
  }

  /// تحليل القيم المنطقية بأمان
  static bool parseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is String) {
      final s = value.toLowerCase();
      return s == 'true' || s == '1' || s == 'yes';
    }
    if (value is int) return value == 1;
    if (value is List && value.isNotEmpty) return parseBool(value.first);
    return false;
  }

  /// تحليل التواريخ بأمان
  static DateTime? parseDateTime(dynamic value) {
    if (value == null || value.toString().isEmpty) return null;
    try {
      if (value is String) return DateTime.parse(value);
      if (value is List && value.isNotEmpty) return parseDateTime(value.first);
      return DateTime.parse(value.toString());
    } catch (_) {
      return null;
    }
  }
}
