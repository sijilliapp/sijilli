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
    // Normalize Alif Wasla to normal Alif first to prevent it from being stripped
    String cleaned = text.replaceAll('ٱ', 'ا');
    // Remove diacritics and non-Arabic letter characters
    cleaned = cleaned.replaceAll(RegExp(r'[^\u0621-\u064a\s]'), '');
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

  static List<String>? _allCleanWords;
  static List<String>? _allUthmaniWords;
  static List<int>? _wordSurahNumbers;
  static List<int>? _wordVerseNumbers;
  static List<String>? _wordSurahNames;

  static void _initFlattenedQuran() {
    if (_allCleanWords != null) return;
    _allCleanWords = [];
    _allUthmaniWords = [];
    _wordSurahNumbers = [];
    _wordVerseNumbers = [];
    _wordSurahNames = [];

    for (final verse in _quranData!) {
      final String cleanVerseText = verse['c'];
      final String uthmaniVerseText = verse['u'];
      
      final String cleanVerseCleaned = cleanVerseText.replaceAll('\u200b', '').replaceAll('\ufeff', '').trim();
      final String uthmaniVerseCleaned = uthmaniVerseText.replaceAll('\u200b', '').replaceAll('\ufeff', '').trim();

      final List<String> cleanWords = cleanVerseCleaned.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
      final List<String> uthmaniWords = uthmaniVerseCleaned.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

      if (cleanWords.length == uthmaniWords.length) {
        final int surahNum = verse['s'];
        final int verseNum = verse['a'];
        final String surahName = verse['n'];

        for (int i = 0; i < cleanWords.length; i++) {
          _allCleanWords!.add(cleanWords[i]);
          _allUthmaniWords!.add(uthmaniWords[i]);
          _wordSurahNumbers!.add(surahNum);
          _wordVerseNumbers!.add(verseNum);
          _wordSurahNames!.add(surahName);
        }
      }
    }
  }

  static int _levenshtein(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    List<int> v0 = List<int>.generate(t.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(t.length + 1, 0);

    for (int i = 0; i < s.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < t.length; j++) {
        int cost = (s.codeUnitAt(i) == t.codeUnitAt(j)) ? 0 : 1;
        v1[j + 1] = _min3(v1[j] + 1, v0[j + 1] + 1, v0[j] + cost);
      }
      for (int j = 0; j < v0.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v0[t.length];
  }

  static int _min3(int a, int b, int c) {
    int m = a < b ? a : b;
    return m < c ? m : c;
  }

  static Future<QuranMatch?> searchAndFormatVerse(String query) async {
    await _loadQuran();
    if (_quranData == null || _quranData!.isEmpty) return null;
    
    _initFlattenedQuran();
    if (_allCleanWords == null || _allCleanWords!.isEmpty) return null;

    final String cleanQuery = cleanText(query);
    if (cleanQuery.isEmpty) return null;

    final List<String> queryWords = cleanQuery.split(' ');
    final int qLen = queryWords.length;

    // Phase 1: Fast Candidate Match Filtering
    final List<String> candidateWords = queryWords.where((w) => w.length >= 3).toList();
    final Set<String> candidateSet = candidateWords.isNotEmpty 
        ? candidateWords.toSet() 
        : queryWords.toSet();

    final Set<int> potentialIndices = {};
    for (int i = 0; i < _allCleanWords!.length; i++) {
      final String word = _allCleanWords![i];
      bool isCandidate = false;
      for (final cand in candidateSet) {
        if (word.contains(cand)) {
          isCandidate = true;
          break;
        }
      }
      if (isCandidate) {
        int startMin = i - qLen + 1;
        if (startMin < 0) startMin = 0;
        int startMax = i;
        if (startMax > _allCleanWords!.length - qLen) {
          startMax = _allCleanWords!.length - qLen;
        }
        for (int s = startMin; s <= startMax; s++) {
          potentialIndices.add(s);
        }
      }
    }

    int bestStartIdx = -1;
    double bestScore = double.infinity;

    void evaluateIndices(Iterable<int> indices) {
      for (final i in indices) {
        if (i + qLen > _allCleanWords!.length) continue;
        int totalDistance = 0;
        for (int j = 0; j < qLen; j++) {
          totalDistance += _levenshtein(queryWords[j], _allCleanWords![i + j]);
        }
        final double score = totalDistance / qLen;
        if (score < bestScore) {
          bestScore = score;
          bestStartIdx = i;
        }
      }
    }

    evaluateIndices(potentialIndices);

    // Phase 2: If no good match under the threshold, fallback to scanning all windows in the Quran
    if (bestScore > 1.8) {
      final List<int> allIndices = List.generate(
        _allCleanWords!.length - qLen + 1, 
        (i) => i,
      );
      evaluateIndices(allIndices);
    }

    // Return the match if it is within our lenient threshold
    if (bestScore <= 1.8 && bestStartIdx != -1) {
      final List<String> matchedUthmani = [];
      for (int k = 0; k < qLen; k++) {
        String word = _allUthmaniWords![bestStartIdx + k];
        // If the current word's verse number is different from the next word's verse number,
        // and we haven't reached the last word, append an Arabic comma to separate the verses.
        if (k < qLen - 1 &&
            _wordVerseNumbers![bestStartIdx + k] != _wordVerseNumbers![bestStartIdx + k + 1]) {
          word = '$word،';
        }
        matchedUthmani.add(word);
      }
      final String matchedUthmaniText = matchedUthmani.join(' ');
      
      final int startSurah = _wordSurahNumbers![bestStartIdx];
      final int startVerse = _wordVerseNumbers![bestStartIdx];
      final String rawSurahName = _wordSurahNames![bestStartIdx];
      
      // Clean surah name of diacritics to prevent text rendering/font distortion
      final String cleanSurahName = rawSurahName
          .replaceAll('ٱ', 'ا')
          .replaceAll(RegExp(r'[\u064b-\u0652\u0670]'), '');

      return QuranMatch(
        uthmaniText: matchedUthmaniText,
        surahName: cleanSurahName,
        surahNumber: startSurah,
        verseNumber: startVerse,
      );
    }

    return null;
  }
}
