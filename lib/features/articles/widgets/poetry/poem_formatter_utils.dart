class PoemFormatterUtils {
  static const String poemTagStart = '[POEM]';
  static const String poemTagEnd = '[/POEM]';
  static const String centerTagStart = '[CENTER]';
  static const String centerTagEnd = '[/CENTER]';
  static const String justifyTagStart = '[JUSTIFY]';
  static const String justifyTagEnd = '[/JUSTIFY]';

  /// Formats raw text by wrapping it in [POEM] tags.
  static String formatAsPoem(String rawText) {
    if (rawText.trim().isEmpty) return '';
    final cleanText = rawText.trim();
    
    // If already wrapped in poem tags, toggle it off (unwrap)
    if (cleanText.startsWith(poemTagStart) && cleanText.endsWith(poemTagEnd)) {
      return cleanText.substring(poemTagStart.length, cleanText.length - poemTagEnd.length).trim();
    }
    
    return '$poemTagStart\n$cleanText\n$poemTagEnd';
  }

  /// Toggles center alignment tags on each line of the raw text.
  static String toggleCenterAlignment(String rawText) {
    if (rawText.isEmpty) return '';
    final lines = rawText.split('\n');
    final formattedLines = lines.map((line) {
      final cleanLine = line.trim();
      
      // التحقق إذا كان السطر يحتوي بالفعل على علامات توسيط
      if (cleanLine.startsWith(centerTagStart) && cleanLine.endsWith(centerTagEnd)) {
        // إزالة علامات التوسيط
        return cleanLine.substring(centerTagStart.length, cleanLine.length - centerTagEnd.length);
      } else {
        // إزالة أي علامات تنسيق موجودة أولاً
        String stripped = cleanLine;
        
        // إزالة علامات ضبط النص إذا كانت موجودة
        if (stripped.startsWith(justifyTagStart) && stripped.endsWith(justifyTagEnd)) {
          stripped = stripped.substring(justifyTagStart.length, stripped.length - justifyTagEnd.length);
        }
        
        // إضافة علامات التوسيط
        return '$centerTagStart$stripped$centerTagEnd';
      }
    }).toList();
    return formattedLines.join('\n');
  }

  /// Toggles justify alignment tags on each line of the raw text.
  static String toggleJustifyAlignment(String rawText) {
    if (rawText.isEmpty) return '';
    final lines = rawText.split('\n');
    final formattedLines = lines.map((line) {
      final cleanLine = line.trim();
      if (cleanLine.startsWith(justifyTagStart) && cleanLine.endsWith(justifyTagEnd)) {
        // Toggle justify off
        return cleanLine.substring(justifyTagStart.length, cleanLine.length - justifyTagEnd.length);
      } else {
        // Remove center tags if present, and add justify tags
        String stripped = cleanLine;
        if (stripped.startsWith(centerTagStart) && stripped.endsWith(centerTagEnd)) {
          stripped = stripped.substring(centerTagStart.length, stripped.length - centerTagEnd.length);
        }
        return '$justifyTagStart$stripped$justifyTagEnd';
      }
    }).toList();
    return formattedLines.join('\n');
  }
}
