import 'package:flutter/foundation.dart';
import '../../models/appointment.dart';

/// Service responsible for generating smart suggestions for the "Word Buffet" (Zero Keyboard).
/// It uses N-gram analysis and curated datasets to predict the next likely words.
class AutocompleteService {
  // Singleton pattern
  static final AutocompleteService _instance = AutocompleteService._internal();
  factory AutocompleteService() => _instance;
  AutocompleteService._internal();

  // Optimized static data for religious occasions (Chain of Thought map)
  // Optimized static data for religious occasions (Chain of Thought map)
  // Format: "Previous Word" -> ["Next Word 1", "Next Word 2", ...]
  final Map<String, List<String>> _ngramData = {
    '': [], // Default empty context
  };

  // Dynamic Data (Learned)
  final Map<String, Map<String, int>> _learnedData = {};

  /// Clears all learned data from the singleton instance.
  void clearLearnedData() {
    _learnedData.clear();
    _pivotIndex.clear();
    _learnedDates.clear();
  }

  /// Returns a list of suggested next words based on the current input text.
  List<String> getSuggestions(String currentText) {
    // 1. Clean the text and split into words
    final trimmedText = currentText.trim();
    if (currentText.isEmpty || trimmedText.isEmpty) {
      return _ngramData['']!;
    }
    
    // 2. Identify Context (previous word) and Prefix (current being typed)
    String contextWord = '';
    String prefix = '';
    
    // Check if we are starting a NEW word (ends with space)
    if (currentText.endsWith(' ')) {
       // Context is the last word. Prefix is empty.
       final words = trimmedText.split(RegExp(r'\s+'));
       if (words.isNotEmpty) contextWord = words.last;
       prefix = '';
    } else {
       // We are in the middle of a word (or started one)
       // Context is the SECOND to last word (if exists). Prefix is the LAST word.
       final words = trimmedText.split(RegExp(r'\s+'));
       if (words.isNotEmpty) {
         prefix = words.last;
         if (words.length > 1) {
           contextWord = words[words.length - 2];
         }
       }
    }

    // 3. Collect Candidates
    final Set<String> candidates = {};
    
    // A. Contextual Matches (Bigram Prediction)
    // "What typically follows [contextWord]?"
    final Set<String> bigramMatches = {};
    
    // From Learned Data
    if (_learnedData.containsKey(contextWord)) {
      final map = _learnedData[contextWord]!;
      // Sort by frequency
      final sorted = map.keys.toList()..sort((a, b) => map[b]!.compareTo(map[a]!));
      bigramMatches.addAll(sorted);
    }
    // From Static Data
    if (_ngramData.containsKey(contextWord)) {
      bigramMatches.addAll(_ngramData[contextWord]!);
    }
    
    // Filter Bigram Matches by Prefix
    if (prefix.isNotEmpty) {
      candidates.addAll(bigramMatches.where((w) => w.startsWith(prefix)));
    } else {
      candidates.addAll(bigramMatches);
    }
    
    // B. Global Vocabulary Fallback (Prefix Autocomplete)
    // If we have a prefix, we also want to suggest words matching it even if they don't fit the bigram strictness
    // (User might be typing a new phrase we haven't learned yet)
    if (prefix.isNotEmpty) {
       // Collect all known words (Static + Learned)
       // Optimization: In a real app, cache this Set.
       final allWords = <String>{};
       
       // Add Static Values
       for (var list in _ngramData.values) {
         allWords.addAll(list);
       }
       // Add Static Keys
       allWords.addAll(_ngramData.keys.where((k) => k.isNotEmpty));
       
       // Add Learned Values
       for (var map in _learnedData.values) {
         allWords.addAll(map.keys);
       }
       // Add Learned Keys
       allWords.addAll(_learnedData.keys.where((k) => k.isNotEmpty));
       
       // Filter by Prefix
       final globalMatches = allWords.where((w) => w.startsWith(prefix) && w != prefix).take(10); // Limit fallback
       
       candidates.addAll(globalMatches);
    }

    return candidates.toList();
  }

  /// Adds a new learned sequence to the local memory
  void learnSequence(String sentence) {
    if (sentence.trim().isEmpty) return;
    
    // Normalize spaces
    final text = sentence.trim().replaceAll(RegExp(r'\s+'), ' ');
    final words = text.split(' ');
    
    if (words.isEmpty) return;

    // 1. Learn Start Word
    _incrementLearned('', words[0]);

    // 2. Learn Bigrams
    for (int i = 0; i < words.length - 1; i++) {
       final current = words[i];
       final next = words[i + 1];
       _incrementLearned(current, next);
    }
  }

  void _incrementLearned(String key, String nextWord) {
    if (!_learnedData.containsKey(key)) {
      _learnedData[key] = {};
    }
    _learnedData[key]![nextWord] = (_learnedData[key]![nextWord] ?? 0) + 1;
  }

  // --- Pivot Indexing ---
  
  final Map<String, List<String>> _pivotIndex = {}; 
  final Set<String> _stopWords = {
    'ليلة', 'يوم', 'مجلس', 'ذكرى', 'مولد', 'وفاة', 'شهادة', 'ميلاد', 'استشهاد', 
    'الإمام', 'السيدة', 'النبي', 'أم', 'أبي', 
    '(ع)', '(ص)', '(عج)', 'بن', 'من', 'في', 'على',
    'الليلة', 'مساء', 'صباح', 'ظهيرة'
  };

  void learn(List<String> sentences) {
    for (final sentence in sentences) {
      learnSequence(sentence);
      _indexPivotWords(sentence);
    }
  }
  
  void _indexPivotWords(String title) {
    final words = title.trim().split(RegExp(r'\s+')).where((w) => w.length > 2).toList();
    for (final word in words) {
      if (!_stopWords.contains(word)) {
        if (!_pivotIndex.containsKey(word)) {
          _pivotIndex[word] = [];
        }
        if (!_pivotIndex[word]!.contains(title)) {
           _pivotIndex[word]!.add(title);
        }
      }
    }
  }

  List<PivotMatch> getPivotSuggestions(String currentText) {
    final trimmed = currentText.trim();
    if (trimmed.isEmpty) return [];
    
    final words = trimmed.split(RegExp(r'\s+'));
    final lastWord = words.last;
    
    if (_pivotIndex.containsKey(lastWord)) {
      final fullTitles = _pivotIndex[lastWord]!;
      // Suggest differentiation if we have matches
      List<PivotMatch> results = [];
      for (final title in fullTitles) {
        final titleWords = title.split(' ');
        if (titleWords.isNotEmpty) {
           final diff = titleWords.first;
           if (diff != lastWord) {
             // Avoid duplicate differentiators? (e.g. "Mawlid X" and "Mawlid Y")
             // Here we map Differentiator -> Full Title.
             // If multiple titles have same differentiator (ambiguous?), we might need smarter logic.
             // For V1, we just list them.
             if (!results.any((r) => r.differentiator == diff)) {
                results.add(PivotMatch(differentiator: diff, fullTitle: title));
             }
           }
        }
      }
      return results;
    }
    return [];
  }

  // --- Semantic Deduction ---

  final Map<String, EventDate> _knownEvents = {
    'ليلة النصف من شعبان': EventDate(month: 8, day: 15),
    'مولد الإمام الحسين': EventDate(month: 3, day: 3),
    'مولد الإمام علي': EventDate(month: 7, day: 13),
    'عيد الغدير': EventDate(month: 12, day: 18),
    'يوم عرفة': EventDate(month: 12, day: 9),
    'عاشوراء': EventDate(month: 1, day: 10),
    'الأربعين': EventDate(month: 2, day: 20),
    'المولد النبوي': EventDate(month: 3, day: 17),
    'دعاء كميل': EventDate(weekday: 5), 
    'دعاء الندبة': EventDate(weekday: 6),
    // New Additions
    'مولد الحجة': EventDate(month: 8, day: 15),
    'مولد الإمام المهدي': EventDate(month: 8, day: 15),
    'مولد صاحب الزمان': EventDate(month: 8, day: 15),
    'مولد السيدة الزهراء': EventDate(month: 6, day: 20),
    'شهادة السيدة الزهراء': EventDate(month: 6, day: 3), // Fatimiyya 3?
  };

  // Learned Dates: Title -> {EventDate -> Frequency}
  final Map<String, Map<EventDate, int>> _learnedDates = {};

  /// Learn frequent dates from history
  void learnDates(List<Appointment> history) {
    _learnedDates.clear();
    
    for (var appt in history) {
      if (appt.title.isEmpty) continue;
      
      final normalizedTitle = _normalize(appt.title);
      final isHijri = appt.dateType == 'hijri';
      
      EventDate date;
      if (isHijri && appt.hijriMonth != null) {
         // Hijri Date
         // We need Day. Parsing hijriDate string or assuming calculation?
         // Appointment model has hijriDate string "YYYY-MM-DD".
         // Let's parse it safely.
         int? day;
         if (appt.hijriDate != null) {
           final parts = appt.hijriDate!.split('-');
           if (parts.length == 3) {
             day = int.tryParse(parts[2]);
           }
         }
         if (day != null) {
           date = EventDate(month: appt.hijriMonth, day: day, isHijri: true);
         } else {
           continue; 
         }
      } else {
         // Gregorian
         date = EventDate(month: appt.date.month, day: appt.date.day, isHijri: false);
      }
      
      if (!_learnedDates.containsKey(normalizedTitle)) {
        _learnedDates[normalizedTitle] = {};
      }
      
      _learnedDates[normalizedTitle]![date] = (_learnedDates[normalizedTitle]![date] ?? 0) + 1;
    }
  }

  EventDate? checkForDateMatch(String title) {
    if (title.isEmpty) return null;
    
    final normalizedTitle = _normalize(title);
    
    // 1. Check Learned Dates (Priority: It's specific to User)
    if (_learnedDates.containsKey(normalizedTitle)) {
      final matches = _learnedDates[normalizedTitle]!;
      if (matches.isNotEmpty) {
        // Return the most frequent
        var sortedKeys = matches.keys.toList()
          ..sort((a, b) => matches[b]!.compareTo(matches[a]!));
        return sortedKeys.first;
      }
    }
    
    // 2. Check Static Known Events
    for (final entry in _knownEvents.entries) {
      final normalizedKey = _normalize(entry.key);
      if (normalizedTitle.contains(normalizedKey)) {
        return entry.value;
      }
    }
    return null;
  }

  // Normalization helper (Moved to class level for reuse)
  String _normalize(String input) {
    return input.trim()
        .replaceAll(RegExp(r'[أإآ]'), 'ا') // Unify Alefs
        .replaceAll('ة', 'ه') // Teh Marbuta
        .replaceAll('ى', 'ي') // Alef Maqsura
        .replaceAll(RegExp(r'[\u064B-\u065F]'), ''); // Remove Tashkeel
  }
}

class PivotMatch {
  final String differentiator;
  final String fullTitle;
  PivotMatch({required this.differentiator, required this.fullTitle});
}

class EventDate {
  final int? month;
  final int? day;
  final int? weekday; // 1 = Monday, ..., 5 = Friday, ... 7 = Sunday
  final bool isHijri;

  const EventDate({
    this.month,
    this.day,
    this.weekday,
    this.isHijri = true,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventDate &&
          runtimeType == other.runtimeType &&
          month == other.month &&
          day == other.day &&
          weekday == other.weekday &&
          isHijri == other.isHijri;

  @override
  int get hashCode =>
      month.hashCode ^ day.hashCode ^ weekday.hashCode ^ isHijri.hashCode;
}
