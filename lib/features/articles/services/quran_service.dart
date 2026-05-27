import 'dart:convert';
import 'package:flutter/services.dart';

class QuranMatch {
  final String uthmaniText;
  final String surahName;
  final int surahNumber;
  final int verseNumber;

  QuranMatch({
    required this.uthmaniText,
    required this.surahName,
    required this.surahNumber,
    required this.verseNumber,
  });
}

class QuranService {
  static List<dynamic>? _quranData;

  static Future<void> _loadQuran() async {
    if (_quranData != null) return;
    try {
      final String jsonString = await rootBundle.loadString('assets/quran/quran.json');
      _quranData = json.decode(jsonString);
    } catch (e) {
      _quranData = [];
    }
  }

  static String cleanText(String text) {
    // Remove diacritics and non-Arabic letter characters
    String cleaned = text.replaceAll(RegExp(r'[^\u0621-\u064a\s]'), '');
    // Normalize Alif
    cleaned = cleaned.replaceAll(RegExp(r'[أإآ]'), 'ا');
    // Normalize Ya / Alif Maqsura
    cleaned = cleaned.replaceAll('ى', 'ي');
    // Normalize Ta Marbuta
    cleaned = cleaned.replaceAll('ة', 'ه');
    // Normalize spaces
    cleaned = cleaned.trim().replaceAll(RegExp(r'\s+'), ' ');
    return cleaned;
  }

  static String toEasternNumerals(String numberStr) {
    const Map<String, String> numerals = {
      '0': '٠',
      '1': '١',
      '2': '٢',
      '3': '٣',
      '4': '٤',
      '5': '٥',
      '6': '٦',
      '7': '٧',
      '8': '٨',
      '9': '٩',
    };
    return numberStr.split('').map((char) => numerals[char] ?? char).join();
  }

  static Future<QuranMatch?> searchAndFormatVerse(String query) async {
    await _loadQuran();
    if (_quranData == null || _quranData!.isEmpty) return null;

    final String cleanQuery = cleanText(query);
    if (cleanQuery.isEmpty) return null;

    final List<String> queryWords = cleanQuery.split(' ');

    for (final verse in _quranData!) {
      final String cleanVerseText = verse['c'];
      
      // Check if the whole cleaned query is a substring of the cleaned verse text
      if (cleanVerseText.contains(cleanQuery)) {
        final String uthmaniVerseText = verse['u'];
        final List<String> verseCleanWords = cleanVerseText.split(' ');
        final List<String> verseUthmaniWords = uthmaniVerseText.split(' ');

        // Guarantee matching length to prevent index errors
        if (verseCleanWords.length == verseUthmaniWords.length) {
          // Find the start index of the query in the verse words
          int startIdx = -1;
          for (int i = 0; i <= verseCleanWords.length - queryWords.length; i++) {
            bool isMatch = true;
            for (int j = 0; j < queryWords.length; j++) {
              // Check if clean word matches or contains the query word
              if (verseCleanWords[i + j] != queryWords[j] &&
                  !verseCleanWords[i + j].contains(queryWords[j])) {
                isMatch = false;
                break;
              }
            }
            if (isMatch) {
              startIdx = i;
              break;
            }
          }

          if (startIdx != -1) {
            // Extract Uthmani words matching the query words span
            final matchedUthmaniWords = verseUthmaniWords.sublist(
              startIdx, 
              startIdx + queryWords.length,
            );
            final matchedUthmaniText = matchedUthmaniWords.join(' ');

            return QuranMatch(
              uthmaniText: matchedUthmaniText,
              surahName: verse['n'],
              surahNumber: verse['s'],
              verseNumber: verse['a'],
            );
          }
        }
      }
    }
    return null;
  }
}
