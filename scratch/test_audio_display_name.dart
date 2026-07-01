import 'dart:convert';

class AudioHelper {
  static String decodeArabicFileName(String filename) {
    try {
      final dotIndex = filename.lastIndexOf('.');
      String mainPart = dotIndex == -1 ? filename : filename.substring(0, dotIndex);
      final ext = dotIndex == -1 ? '' : filename.substring(dotIndex);
      
      final suffixRegex = RegExp(r'_([a-zA-Z0-9]{8,15})$');
      if (suffixRegex.hasMatch(mainPart)) {
        mainPart = mainPart.replaceFirst(suffixRegex, '');
      }

      String temp = mainPart;
      
      final singleHexRegex = RegExp(r'_([0-9a-f])_([0-9a-f])', caseSensitive: false);
      while (singleHexRegex.hasMatch(temp)) {
        temp = temp.replaceAllMapped(singleHexRegex, (m) => '_${m.group(1)}${m.group(2)}');
      }

      if (RegExp(r'^[0-9a-f]{2}_', caseSensitive: false).hasMatch(temp)) {
        temp = '_$temp';
      }

      final hasArabicBytes = RegExp(r'(?:^|_)(d8|d9|da|db|e2)', caseSensitive: false).hasMatch(temp);
      if (hasArabicBytes) {
        final hexPairRegex = RegExp(r'_([0-9a-f]{2})', caseSensitive: false);
        final percentEncoded = temp.replaceAllMapped(hexPairRegex, (m) => '%${m.group(1)}');
        
        try {
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
          
          String cleanDecoded = decoded.replaceAll('\uFFFD', '').trim();
          cleanDecoded = cleanDecoded.replaceAll('\u200e', '').replaceAll('\u2068', '').replaceAll('\u2069', '');

          if (cleanDecoded.isNotEmpty) {
            return '$cleanDecoded$ext';
          }
        } catch (_) {}
      }

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

  static String getCleanFileNameFromUrl(String url) {
    try {
      String name = url;
      if (url.toLowerCase().startsWith('http://') ||
          url.toLowerCase().startsWith('https://')) {
        final uri = Uri.parse(url);
        name = uri.pathSegments.last;
      } else {
        name = url.split('/').last;
      }
      return decodeArabicFileName(name);
    } catch (_) {
      return 'ملف صوتي 🎵';
    }
  }

  static String getAudioDisplayName(String audioFileOrUrl, String articleText, List<String> audioFiles) {
    try {
      String filename = audioFileOrUrl;
      if (audioFileOrUrl.toLowerCase().startsWith('http://') ||
          audioFileOrUrl.toLowerCase().startsWith('https://')) {
        try {
          final uri = Uri.parse(audioFileOrUrl);
          filename = uri.pathSegments.last;
        } catch (_) {}
      } else {
        filename = audioFileOrUrl.split('/').last;
      }

      final index = audioFiles.indexOf(filename);
      if (index != -1) {
        final tagRegex = RegExp(r'\[(AUDIO_ADVANCED|AUDIO)(?:_|:\s*)(.+?)\]', caseSensitive: false);
        final matches = tagRegex.allMatches(articleText).toList();
        
        if (index < matches.length) {
          final label = matches[index].group(2)!.trim();
          if (label.isNotEmpty && 
              !label.toLowerCase().startsWith('http://') && 
              !label.toLowerCase().startsWith('https://')) {
            return label;
          }
        }
      }
    } catch (_) {}

    return getCleanFileNameFromUrl(audioFileOrUrl);
  }
}

void main() {
  final articleText = '''
[LEFT][AUDIO_ADVANCED: زينب - صالح الدرازي - محرم 1448][/LEFT]
ما يحني الهامة
للشمْر و أزلامه
[AUDIO:  ملف ثانوي للتوضيح ]
  ''';
  
  final audioFiles = [
    'e2_80_8_e_e2_81_a8_d8_b2_d9_8_a_d9_86_d8_a8_d8_a8_20_d8_a7_d9_84_d8_af_d8_b1_d8_a7_d8_b2_d9_8a_20_d9_85_d8_ad_d8_b1_d9_85_201448_a1b2c3d4e5.mp3',
    'd9_85_d8_a7_20_d9_8_a_d8_ad_d9_86_d9_8_a_20_d8_a7_d9_84_d9_87_d8_a7_d9_85_d8_a9_agpbzupzf8.m4a'
  ];

  print('File 1 Display Name: ${AudioHelper.getAudioDisplayName(audioFiles[0], articleText, audioFiles)}');
  print('File 2 Display Name: ${AudioHelper.getAudioDisplayName(audioFiles[1], articleText, audioFiles)}');
  print('Non-existent File Display Name: ${AudioHelper.getAudioDisplayName("nonexistent.mp3", articleText, audioFiles)}');
}
