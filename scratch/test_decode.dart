import 'dart:io';

class AudioHelper {
  static String decodeArabicFileName(String filename) {
    try {
      final dotIndex = filename.lastIndexOf('.');
      String mainPart = dotIndex == -1 ? filename : filename.substring(0, dotIndex);
      final ext = dotIndex == -1 ? '' : filename.substring(dotIndex);
      
      final suffixRegex = RegExp(r'_([a-zA-Z0-9]{10})$');
      if (suffixRegex.hasMatch(mainPart)) {
        mainPart = mainPart.replaceFirst(suffixRegex, '');
      }

      String temp = mainPart;
      
      // 1. Clean up split single hex digits (e.g. _8_a -> _8a)
      final singleHexRegex = RegExp(r'_([0-9a-f])_([0-9a-f])', caseSensitive: false);
      while (singleHexRegex.hasMatch(temp)) {
        temp = temp.replaceAllMapped(singleHexRegex, (m) => '_${m.group(1)}${m.group(2)}');
      }

      // 2. Prepend underscore if it starts with 2 hex digits followed by underscore
      if (RegExp(r'^[0-9a-f]{2}_', caseSensitive: false).hasMatch(temp)) {
        temp = '_$temp';
      }

      // 3. Only decode if it contains Arabic UTF-8 signature bytes (d8/d9/da/db/e2) preceded by underscore
      final hasArabicBytes = RegExp(r'_(d8|d9|da|db|e2)', caseSensitive: false).hasMatch(temp);
      if (hasArabicBytes) {
        // Replace all _XX with %XX
        final hexPairRegex = RegExp(r'_([0-9a-f]{2})', caseSensitive: false);
        final percentEncoded = temp.replaceAllMapped(hexPairRegex, (m) => '%${m.group(1)}');
        try {
          final decoded = Uri.decodeFull(percentEncoded);
          if (decoded.trim().isNotEmpty) {
            return '$decoded$ext';
          }
        } catch (_) {}
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
}

void main() {
  final testCases = {
    '_d8_b2_d9_8a_d9_86_d8_a8_a1b2c3d4e5.mp3': 'زينب.mp3',
    '_d8_b2_d9_8a_d9_86_d8_a8_201448_a1b2c3d4e5.mp3': 'زينب 1448.mp3',
    'd9_a3_d9_a0_20_d9_8_a_d9_88_d9_86_d9_8_a_d9_88_a1b2c3d4e5.mp3': '٣٠ يونيو.mp3',
    'my_audio_file_123_a1b2c3d4e5.mp3': 'my_audio_file_123.mp3',
  };

  testCases.forEach((input, expected) {
    final decoded = AudioHelper.decodeArabicFileName(input);
    print('Input: $input');
    print('Decoded: $decoded');
    print('Expected: $expected');
    print('Result: ${decoded == expected ? "PASS" : "FAIL"}\n');
  });
}
