// 📍 lib/core/constants/app_config.dart
// ⚙️ الإعدادات العامة للتطبيق - سهلة التعديل للمالك

class AppConfig {
  // ====================== إعدادات الحسابات ======================
  
  /// هل التسجيل مفتوح للمستخدمين الجدد؟
  static const bool isRegistrationEnabled = true;

  /// الخصوصية الافتراضية للمستخدم الجديد (true = عام، false = خاص)
  static const bool defaultUserIsPublic = true;

  /// هل يظهر المستخدمون الذين ليس لديهم دور (role) في نتائج البحث؟ 
  static const bool showUsersWithNoRoleInSearch = true;

  /// هل يظهر المشرفون (Admin) في نتائج البحث العامة؟
  static const bool showAdminsInSearch = true;

  // ====================== إعدادات الواجهة (Aesthetics) ======================

  /// سرعة نبض حلقة الصورة الشخصية (بالملي ثانية) - الرقم الأصغر يعني سرعة أكبر
  static const int avatarPulseDurationMs = 3000;

  /// قوة توهج الصورة الشخصية (0.0 إلى 1.0)
  static const double avatarGlowOpacity = 0.4;
  
  // ====================== إعدادات أخرى ======================
  
  /// النسخة الحالية للتطبيق
  static const String appVersion = '1.0.0';
}
