// 📍 lib/core/utils/web_utils_web.dart
// 🌐 نسخة الويب الفعلية - تستدعي لغة JavaScript بأمان

// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

void removeWebLoader() {
  try {
    js.context.callMethod('removeLoadingOverlay');
  } catch (e) {
    // تجاهل الخطأ في حال لم تكن الدالة معرفة
  }
}
