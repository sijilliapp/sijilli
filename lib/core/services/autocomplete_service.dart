import '../../models/appointment.dart';
import '../utils/arabic_search.dart';

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
  // Optimized static data - KEPT EMPTY to strictly rely on Personal History as per core requirement.
  final Map<String, List<String>> _ngramData = {
    '': [], 
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
      final starters = <String>{};
      if (_ngramData.containsKey('')) starters.addAll(_ngramData['']!);
      if (_learnedData.containsKey('')) {
        final map = _learnedData['']!;
        final sorted = map.keys.toList()..sort((a, b) => map[b]!.compareTo(map[a]!));
        starters.addAll(sorted);
      }
      return starters.toList();
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

    // Normalize for better matching
    final normPrefix = _normalize(prefix);
    final normContext = _normalize(contextWord);

    // 3. Collect Candidates
    final Set<String> candidates = {};
    
    // A. Contextual Matches (Bigram Prediction)
    final Set<String> bigramMatches = {};
    
    _learnedData.forEach((key, nextMap) {
       if (_normalize(key) == normContext) {
          // Sort by frequency
          final sorted = nextMap.keys.toList()..sort((a, b) => nextMap[b]!.compareTo(nextMap[a]!));
          bigramMatches.addAll(sorted);
       }
    });

    // Filter Bigram Matches by Prefix
    if (normPrefix.isNotEmpty) {
      candidates.addAll(bigramMatches.where((w) => ArabicSearch.smartMatch(w, prefix)));
    } else {
      candidates.addAll(bigramMatches);
    }
    
    // B. Global Vocabulary Fallback
    if (normPrefix.isNotEmpty) {
       final allWords = <String>{};
       
       for (var map in _learnedData.values) {
         allWords.addAll(map.keys);
       }
       for (var key in _learnedData.keys) {
         if (key.isNotEmpty) allWords.add(key);
       }
       
       final globalMatches = allWords.where((w) {
         return ArabicSearch.smartMatch(w, prefix) && _normalize(w) != normPrefix;
       }).take(15); 
       
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
    final normLastWord = _normalize(lastWord);
    
    if (normLastWord.length < 2) return [];

    final List<PivotMatch> results = [];
    
    _pivotIndex.forEach((pivotWord, fullTitles) {
      if (_normalize(pivotWord).startsWith(normLastWord)) {
        for (final title in fullTitles) {
          if (!results.any((r) => r.fullTitle == title)) {
            // Suggest the full title as a pivot option
            results.add(PivotMatch(differentiator: title, fullTitle: title));
          }
        }
      }
    });
    
    return results.take(15).toList();
  }

  // --- Semantic Deduction ---

  final Map<String, EventDate> _knownEvents = {};

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

  // Normalization helper (Centralized)
  String _normalize(String input) {
    return ArabicSearch.normalize(input);
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
