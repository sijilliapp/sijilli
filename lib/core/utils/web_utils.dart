// 📍 lib/core/utils/web_utils.dart
// 🌐 واجهة موحدة لاستدعاءات الويب المشروطة (Conditional Imports)

import 'web_utils_stub.dart'
    if (dart.library.js) 'web_utils_web.dart' as platform;

/// إزالة شاشة التحميل الخارجية (HTML Loader Overlay) عند جاهزية الصفحة بالكامل
void removeWebLoader() {
  platform.removeWebLoader();
}
