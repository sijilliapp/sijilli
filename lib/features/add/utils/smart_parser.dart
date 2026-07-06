class ParsedEventData {
  final String title;
  final String? region;
  final String? building;
  final String? time; 
  final String? timePeriod; 

  ParsedEventData({
    required this.title,
    this.region,
    this.building,
    this.time,
    this.timePeriod,
  });
}

class ArabicSmartParser {
  static ParsedEventData parse(String text) {
    if (text.isEmpty) return ParsedEventData(title: '');

    String cleanText = text.trim();

    // 1. استخراج الوقت (مثال: س ٨:٠٠ ص، الساعة 8 مساء، الساعة 8:30 صباحا)
    String? time;
    String? period;
    
    // تحويل الأرقام العربية إلى إنجليزية لتسهيل المعالجة
    final normalizedText = _normalizeNumbers(cleanText);

    final timeRegex = RegExp(
      r'(?:س\s*|الساعة\s*)([0-9\u0660-\u0669]{1,2})(?::([0-9\u0660-\u0669]{2}))?\s*(ص|م|صباحاً|مساءً|صباحا|مساء)?',
      caseSensitive: false,
    );

    final match = timeRegex.firstMatch(normalizedText);
    if (match != null) {
      final hours = match.group(1);
      final minutes = match.group(2) ?? '00';
      final rawPeriod = match.group(3);

      if (hours != null) {
        time = '${hours.padLeft(2, '0')}:$minutes';
        if (rawPeriod != null) {
          if (rawPeriod.contains('ص')) {
            period = 'ص';
          } else if (rawPeriod.contains('م')) {
            period = 'م';
          }
        }
      }
      
      final rawMatch = timeRegex.firstMatch(cleanText);
      if (rawMatch != null) {
        cleanText = cleanText.replaceRange(rawMatch.start, rawMatch.end, '').trim();
      }
    }

    // 2. استخراج المبنى والمنطقة (مثال: في مسجد الصادق صدد)
    String? building;
    String? region;

    final locationKeywords = ['مسجد', 'مأتم', 'حسينية', 'قاعة', 'مجلس', 'ديوانية', 'ديوان', 'بيت', 'منزل', 'مدرسة', 'مجمع', 'مركز'];
    final keywordsPattern = locationKeywords.join('|');
    
    final locationRegex = RegExp(
      r'(?:في\s+|بـ|ب)(' + keywordsPattern + r')\s+([^,\s]+(?:\s+[^,\s]+){0,2})',
      caseSensitive: false,
    );

    final locMatch = locationRegex.firstMatch(cleanText);
    if (locMatch != null) {
      final type = locMatch.group(1); 
      final rest = locMatch.group(2); 
      
      if (type != null && rest != null) {
        final words = rest.split(RegExp(r'\s+'));
        if (words.length > 1) {
          region = words.last;
          building = '$type ${words.sublist(0, words.length - 1).join(' ')}';
        } else {
          building = '$type $rest';
        }
      }
      
      cleanText = cleanText.replaceRange(locMatch.start, locMatch.end, '').trim();
    }

    // تنظيف العنوان المتبقي
    cleanText = cleanText.replaceAll(RegExp(r'\s+في$'), '').trim();

    return ParsedEventData(
      title: cleanText,
      region: region,
      building: building,
      time: time,
      timePeriod: period,
    );
  }

  static String _normalizeNumbers(String input) {
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    
    String result = input;
    for (int i = 0; i < 10; i++) {
      result = result.replaceAll(arabic[i], english[i]).replaceAll(persian[i], english[i]);
    }
    return result;
  }
}
