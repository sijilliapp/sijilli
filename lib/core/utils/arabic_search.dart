// 📍 lib/core/utils/arabic_search.dart
// 🔍 معالج البحث العربي - توحيد الحروف ومعالجة المختصرات

class ArabicSearch {
  /// تطبيع النص (Normalization) لتحسين نتائج البحث (يدعم العربي والإنجليزي والرموز)
  static String normalize(String text) {
    if (text.isEmpty) return text;

    // تحويل لحروف صغيرة واستبدال الرموز بمسافات
    String normalized = text.toLowerCase().replaceAll(RegExp(r'[_\-\.,/\\|]'), ' ').trim();

    // 1. إزالة التشكيل (Diacritics)
    normalized = normalized.replaceAll(RegExp(r'[\u064B-\u0652]'), '');

    // 2. توحيد الألف (أ، آ، إ -> ا)
    normalized = normalized.replaceAll(RegExp(r'[أآإ]'), 'ا');

    // 3. توحيد الواو (ؤ -> و)
    normalized = normalized.replaceAll('ؤ', 'و');

    // 4. توحيد الياء والهمزة على نبرة والألف المقصورة (ئ، ى -> ي)
    normalized = normalized.replaceAll(RegExp(r'[ئى]'), 'y'); // وسيط مؤقت
    normalized = normalized.replaceAll('ي', 'y');
    normalized = normalized.replaceAll('y', 'ي');

    // 5. توحيد التاء المربوطة والهاء (ة -> ه)
    normalized = normalized.replaceAll('ة', 'ه');

    return normalized;
  }

  /// إزالة الألقاب الشائعة من بداية النص للمقارنة
  static String removeTitles(String text) {
    String processed = text;
    final titles = [
      'الشيخ', 'السيد', 'الدكتور', 'د.', 'الأستاذ', 'أ.', 
      'المهندس', 'م.', 'شيخ', 'سيد'
    ];
    
    for (var title in titles) {
      if (processed.startsWith(title + ' ')) {
        processed = processed.substring(title.length + 1);
        break;
      }
    }
    return processed.trim();
  }

  /// دالة متكاملة للمقارنة الذكية بين نصين (اسم مستخدم وبحث)
  /// تتبع سياسة: الابتداء بالكلمة، وإسقاط "الـ" التعريفية، وعدم الالتقاط من الوسط.
  static bool smartMatch(String source, String query) {
    if (query.isEmpty) return true;

    // 1. تطبيع النصوص (توحيد الألفات والتاءات والياءات)
    String s = normalize(source);
    String q = normalize(query);

    // 2. إسقاط الألقاب (الشيخ، السيد...)
    s = removeTitles(s);
    q = removeTitles(q);

    // 3. معالجة "الـ" التعريفية:
    // إذا بدأ البحث بـ "الـ"، نحذفها للمقارنة
    if (q.startsWith('ال')) q = q.substring(2);
    
    // تقسيم النص المصدر إلى كلمات للمقارنة مع كل بداية كلمة
    List<String> words = s.split(RegExp(r'\s+'));

    for (var word in words) {
      String cleanWord = word;
      
      // إذا كانت الكلمة تبدأ بـ "الـ"، نجرب المقارنة بعد حذفها
      if (cleanWord.startsWith('ال')) {
        String withoutAl = cleanWord.substring(2);
        if (withoutAl.startsWith(q)) return true;
      }

      // المقارنة العادية مع بداية الكلمة
      if (cleanWord.startsWith(q)) return true;
    }

    return false;
  }
}