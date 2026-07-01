import 'dart:convert';

class AudioHelper {
  static String decodeArabicFileName(String filename) {
    try {
      final dotIndex = filename.lastIndexOf('.');
      String mainPart = dotIndex == -1 ? filename : filename.substring(0, dotIndex);
      final ext = dotIndex == -1 ? '' : filename.substring(dotIndex);
      
      // Strip suffix (support 8 to 15 alphanumeric characters at the end)
      final suffixRegex = RegExp(r'_([a-zA-Z0-9]{8,15})$');
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
        // Replace all _XX patterns with %XX
        final hexPairRegex = RegExp(r'_([0-9a-f]{2})', caseSensitive: false);
        final percentEncoded = temp.replaceAllMapped(hexPairRegex, (m) => '%${m.group(1)}');
        
        try {
          // Custom percent decode with allowMalformed to prevent any crash
          final List<int> bytes = [];
          int i = 0;
          while (i < percentEncoded.length) {
            final char = percentEncoded.codeUnitAt(i);
            if (char == 37 /* % */ && i + 2 < percentEncoded.length) {
              final hex = percentEncoded.substring(i + 1, i + 3);
              final byte = int.tryParse(hex, radix: 16);
              if (byte != null) {
                bytes.add(byte);
                i += 3;
                continue;
              }
            }
            bytes.add(char);
            i++;
          }
          final decoded = utf8.decode(bytes, allowMalformed: true);
          
          // Strip any residual malformed symbols or trailing random tokens
          String cleanDecoded = decoded.replaceAll('', '').trim();
          
          // Also strip directional isolates if they clutter filenames
          cleanDecoded = cleanDecoded.replaceAll('\u200e', '').replaceAll('\u2068', '').replaceAll('\u2069', '');

          if (cleanDecoded.isNotEmpty) {
            return '$cleanDecoded$ext';
          }
        } catch (_) {}
      }

      // Fallback: standard pocketbase cleaning and URI decoding
      String cleanName = filename;
      final pbSuffixPattern = RegExp(r'_([a-zA-Z0-9]{8,15})\.([a-zA-Z0-9]+)$');
      if (pbSuffixPattern.hasMatch(cleanName)) {
        cleanName = cleanName.replaceFirst(RegExp(r'_([a-zA-Z0-9]{8,15})\.'), '.');
      }
      return Uri.decodeFull(cleanName);
    } catch (_) {
      return filename;
    }
  }
}

void main() {
  final testCases = [
    'e2_80_8_e_e2_81_a8_d8_b2_d9_8_a_d9_86_d8_a8_d8_a8_20_d8_a7_d9_84_d8_af_d8_b1_d8_a7_d8_b2_d9_8a_20_d9_85_d8_ad_d8_b1_d9_85_201448_a1b2c3d4e5.mp3',
    'd9_a3_d9_a0_20_d9_8_a_d9_88_d9_86_d9_8_a_d9_88_20_d9_88_20_d9_88_20_d9_a6_vmqew82705.D9A020',
  ];

  for (final input in testCases) {
    final decoded = AudioHelper.decodeArabicFileName(input);
    print('Input: $input');
    print('Decoded: $decoded\n');
  }
}
