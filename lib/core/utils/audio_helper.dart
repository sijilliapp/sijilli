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
      
      // 3. Clean transition underscores between hex characters (e.g. d_8 -> d8, 8_a -> 8a)
      String cleaned = mainPart.toLowerCase();
      final transitionRegex = RegExp(r'([0-9a-f])_([0-9a-f])');
      while (transitionRegex.hasMatch(cleaned)) {
        cleaned = cleaned.replaceAllMapped(transitionRegex, (m) => '${m[1]}${m[2]}');
      }

      // 4. Convert all _XX (where XX is two hex chars) to %XX
      final byteRegex = RegExp(r'_([0-9a-f]{2})');
      String percentEncoded = cleaned.replaceAllMapped(byteRegex, (m) => '%${m[1]}');

      // 5. Decode URL percent-encoding to restore Arabic characters
      try {
        final decoded = Uri.decodeFull(percentEncoded);
        if (decoded.trim().isNotEmpty) {
          return '$decoded$ext';
        }
      } catch (_) {}

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
