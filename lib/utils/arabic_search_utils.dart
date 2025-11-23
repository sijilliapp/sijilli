/// Utility class for Arabic text normalization and search
class ArabicSearchUtils {
  /// Normalize Arabic text for search by replacing similar characters
  static String normalizeArabicText(String text) {
    if (text.isEmpty) return text;
    
    String normalized = text.toLowerCase();
    
    // تطبيع الألف
    normalized = normalized
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ء', 'ا');
    
    // تطبيع الياء
    normalized = normalized
        .replaceAll('ى', 'ي')
        .replaceAll('ئ', 'ي')
        .replaceAll('ؤ', 'و');
    
    // تطبيع الهاء والتاء المربوطة
    normalized = normalized
        .replaceAll('ة', 'ه');
    
    // إزالة التشكيل
    normalized = normalized
        .replaceAll(RegExp(r'[\u064B-\u0652]'), ''); // تشكيل
    
    // تطبيع الألقاب
    normalized = normalized
        .replaceAll('الشيخ', 'شيخ')
        .replaceAll('السيد', 'سيد')
        .replaceAll('الدكتور', 'دكتور')
        .replaceAll('الأستاذ', 'استاذ')
        .replaceAll('المهندس', 'مهندس');
    
    return normalized.trim();
  }
  
  /// Check if search query matches text using Arabic normalization
  static bool matchesArabicSearch(String text, String query) {
    if (query.isEmpty) return true;
    if (text.isEmpty) return false;
    
    final normalizedText = normalizeArabicText(text);
    final normalizedQuery = normalizeArabicText(query);
    
    return normalizedText.contains(normalizedQuery);
  }
  
  /// Search in multiple fields (name, username, bio) with Arabic normalization
  static bool searchInUserFields(String name, String username, String? bio, String query) {
    if (query.isEmpty) return true;
    
    // البحث في الاسم
    if (matchesArabicSearch(name, query)) return true;
    
    // البحث في اسم المستخدم
    if (matchesArabicSearch(username, query)) return true;
    
    // البحث في السيرة الذاتية
    if (bio != null && matchesArabicSearch(bio, query)) return true;
    
    return false;
  }
  
  /// Highlight search terms in text (for UI display)
  static String highlightSearchTerms(String text, String query) {
    if (query.isEmpty) return text;
    
    final normalizedQuery = normalizeArabicText(query);
    final normalizedText = normalizeArabicText(text);
    
    if (normalizedText.contains(normalizedQuery)) {
      // Find the actual position in original text
      // This is a simplified version - in a real app you might want more sophisticated highlighting
      return text;
    }
    
    return text;
  }
}
