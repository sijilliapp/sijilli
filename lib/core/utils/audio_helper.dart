import 'dart:io';

class AudioHelper {
  /// Decodes and cleans a PocketBase-sanitized audio filename back to its original Arabic/English form
  static String decodeArabicFileName(String filename) {
    try {
      // 1. Separate filename and extension
      final dotIndex = filename.lastIndexOf('.');
      String mainPart = dotIndex == -1 ? filename : filename.substring(0, dotIndex);
      final ext = dotIndex == -1 ? '' : filename.substring(dotIndex);
      
      // 2. Strip PocketBase 10-char random suffix (e.g. _a1b2c3d4e5)
      final suffixRegex = RegExp(r'_([a-zA-Z0-9]{10})$');
      if (suffixRegex.hasMatch(mainPart)) {
        mainPart = mainPart.replaceFirst(suffixRegex, '');
      }
      
      // 3. Remove underscores to get raw hex
      final hexOnly = mainPart.replaceAll('_', '').toLowerCase();
      
      // 4. Validate if it's a valid hex string of even length
      if (hexOnly.isNotEmpty && 
          hexOnly.length % 2 == 0 && 
          RegExp(r'^[0-9a-f]+$').hasMatch(hexOnly)) {
        
        // 5. Check if it looks like UTF-8 Arabic bytes (which start with d8/d9/da/db or 20 for space)
        bool isArabicHex = false;
        for (int i = 0; i < hexOnly.length; i += 2) {
          final byte = hexOnly.substring(i, i + 2);
          if (byte == 'd8' || byte == 'd9' || byte == 'da' || byte == 'db' || byte == '20') {
            isArabicHex = true;
            break;
          }
        }
        
        if (isArabicHex) {
          final buffer = StringBuffer();
          for (int i = 0; i < hexOnly.length; i += 2) {
            buffer.write('%');
            buffer.write(hexOnly.substring(i, i + 2));
          }
          final percentEncoded = buffer.toString();
          try {
            final decoded = Uri.decodeFull(percentEncoded);
            if (decoded.trim().isNotEmpty) {
              return '$decoded$ext';
            }
          } catch (_) {}
        }
      }

      // Fallback: standard pocketbase cleaning and URI decoding
      String cleanName = filename;
      final pbSuffixPattern = RegExp(r'_([a-zA-Z0-9]{10})\.([a-zA-Z0-9]+)$');
      if (pbSuffixPattern.hasMatch(cleanName)) {
        cleanName = cleanName.replaceFirst(RegExp(r'_([a-zA-Z0-9]{10})\.'), '.');
      }
      return Uri.decodeFull(cleanName);
    } catch (_) {
      return filename;
    }
  }

  /// Returns the decoded filename without its extension
  static String getCleanAudioTitle(String filename) {
    try {
      final decodedName = decodeArabicFileName(filename);
      final finalDotIndex = decodedName.lastIndexOf('.');
      return finalDotIndex == -1 ? decodedName : decodedName.substring(0, finalDotIndex);
    } catch (_) {
      return filename;
    }
  }

  /// Extracts filename from path or URL and cleans it
  static String getCleanFileNameFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final rawName = uri.pathSegments.last;
      return decodeArabicFileName(rawName);
    } catch (_) {
      return 'ملف صوتي 🎵';
    }
  }
}
