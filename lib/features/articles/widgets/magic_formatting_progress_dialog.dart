import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import 'formatting_text_controller.dart';

class MagicFormatterParams {
  final String text;
  final List<ParagraphFormat> lineFormats;
  final Map<String, String> dynamicFixes;

  MagicFormatterParams({
    required this.text,
    required this.lineFormats,
    required this.dynamicFixes,
  });
}

class MagicFormatterResult {
  final String formattedText;
  final int changesCount;
  final int score;

  MagicFormatterResult({
    required this.formattedText,
    required this.changesCount,
    required this.score,
  });
}

// دالة التشغيل المستقلة للخلفية (Isolate Entrypoint)
MagicFormatterResult runMagicFormattingInIsolate(MagicFormatterParams params) {
  final text = params.text;
  if (text.isEmpty) {
    return MagicFormatterResult(formattedText: '', changesCount: 0, score: 100);
  }

  int changesCount = 0;

  String replaceWithCount(String source, Pattern pattern, String Function(Match) replace) {
    return source.replaceAllMapped(pattern, (match) {
      changesCount++;
      return replace(match);
    });
  }

  bool isParagraphEnglish(String paragraph) {
    final clean = paragraph.trim();
    if (clean.isEmpty) return false;

    final arabicRegExp = RegExp(r'[\u0600-\u06FF]');
    final latinRegExp = RegExp(r'[a-zA-Z]');
    
    final arabicCount = arabicRegExp.allMatches(clean).length;
    final latinCount = latinRegExp.allMatches(clean).length;
    
    return latinCount > arabicCount;
  }

  final paragraphs = text.split('\n');
  final formattedParagraphs = <String>[];

  for (int i = 0; i < paragraphs.length; i++) {
    var para = paragraphs[i];
    if (para.trim().isEmpty) {
      formattedParagraphs.add(para);
      continue;
    }

    final format = i < params.lineFormats.length ? params.lineFormats[i] : ParagraphFormat.none;
    final isFormattedLine = format != ParagraphFormat.none;

    if (isParagraphEnglish(para)) {
      // --- ENGLISH PARAGRAPH ---
      para = replaceWithCount(para, '،', (m) => ',');
      para = replaceWithCount(para, '؟', (m) => '?');
      para = replaceWithCount(para, RegExp(r'\(\s+'), (m) => '(');
      para = replaceWithCount(para, RegExp(r'\s+\)'), (m) => ')');
      para = replaceWithCount(para, RegExp(r'\s+([,.;:?!])'), (match) => match.group(1)!);
      para = replaceWithCount(para, RegExp(r'([,.;:?!])(?=[^\s,.;:?!"\d])'), (match) => '${match.group(1)} ');

      if (!isFormattedLine && para.isNotEmpty && !para.startsWith(RegExp(r'[\s\u2003=~\[]'))) {
        para = '\u2003$para';
        changesCount++;
      }

      final englishSpellingFixes = {
        'teh': 'the',
        'dont': "don't",
        'cant': "can't",
        'wont': "won't",
        'im': "I'm",
        'ive': "I've",
        'id': "I'd",
        'youre': "you're",
        'theyre': "they're",
        'weve': "we've",
        'shouldnt': "shouldn't",
        'wouldnt': "wouldn't",
        'couldnt': "couldn't",
        'didnt': "didn't",
        'doesnt': "doesn't",
        'isnt': "isn't",
        'arent': "aren't",
        'wasnt': "wasn't",
        'werent': "weren't",
        'hasnt': "hasn't",
        'havent': "haven't",
        'hadnt': "hadn't",
        'reiceve': 'receive',
        'reiceved': 'received',
        'reiceving': 'receiving',
        'seperate': 'separate',
        'seperated': 'separated',
        'seperating': 'separating',
        'seperation': 'separation',
        'occured': 'occurred',
        'occurence': 'occurrence',
        'alot': 'a lot',
        'wierd': 'weird',
        'goverment': 'government',
        'enviroment': 'environment',
      };

      englishSpellingFixes.forEach((wrong, correct) {
        final pattern = RegExp('\\b' + RegExp.escape(wrong) + '\\b', caseSensitive: false);
        para = replaceWithCount(para, pattern, (match) {
          final matchedText = match.group(0)!;
          if (matchedText.startsWith(RegExp(r'[A-Z]'))) {
            return correct[0].toUpperCase() + correct.substring(1);
          }
          return correct;
        });
      });
    } else {
      // --- ARABIC PARAGRAPH ---
      para = replaceWithCount(para, ',', (m) => '،');
      para = replaceWithCount(para, '?', (m) => '؟');
      para = replaceWithCount(para, RegExp(r'"([^"]*)"'), (match) => '«${match.group(1)}»');
      para = replaceWithCount(para, RegExp(r'\(\s+'), (m) => '(');
      para = replaceWithCount(para, RegExp(r'\s+\)'), (m) => ')');
      para = replaceWithCount(para, RegExp(r'«\s+'), (m) => '«');
      para = replaceWithCount(para, RegExp(r'\s+»'), (m) => '»');
      para = replaceWithCount(para, RegExp(r'\s+([،.؛:؟!])'), (match) => match.group(1)!);
      para = replaceWithCount(para, RegExp(r'([،.؛:؟!])(?=[^\s،.؛:؟!])'), (match) => '${match.group(1)} ');
      para = replaceWithCount(para, RegExp(r'(?<=\s|^)و([\u064B-\u0652]*)\s+'), (match) => 'و${match.group(1)}');

      if (!isFormattedLine && para.isNotEmpty && !para.startsWith(RegExp(r'[\s\u2003=~\[]'))) {
        para = '\u2003$para';
        changesCount++;
      }

      final spellingFixes = {
        'انشاء الله': 'إن شاء الله',
        'إنشاء الله': 'إن شاء الله',
        'اللهم صلي': 'اللهم صلِّ',
        'هاذا': 'هذا',
        'هاذه': 'هذه',
        'هاذان': 'هذان',
        'هاؤلاء': 'هؤلاء',
        'ذالك': 'ذلك',
        'كذالك': 'كذلك',
        'لاكن': 'لكن',
        'لاكنه': 'لكنه',
        'لاكنها': 'لكنها',
        'لاكنهم': 'لكنهم',
        'انتي': 'أنتِ',
        'أنتي': 'أنتِ',
        'إسم': 'اسم',
        'أسم': 'اسم',
        'إبن': 'ابن',
        'إمرأة': 'امرأة',
        'أمرأة': 'امرأة',
        'شئ': 'شيء',
        'مأئة': 'مئة',
        'مائة': 'مئة',
        'داوود': 'داود',
        'طاووس': 'طاوس',
        'أولائك': 'أولئك',
        'الى': 'إلى',
        'او': 'أو',
        'ايجاد': 'إيجاد',
        'انشاء': 'إنشاء',
        'ndcwa': 'ندعو',
        'ndcwa': 'ندعو',
        'ندعوا': 'ندعو',
        'نرجوا': 'نرجو',
        'مديروا': 'مديرو',
        'اللة': 'الله',
        'حتي': 'حتى',
        'مستشفي': 'مستشفى',
        'جزاكي': 'جزاكِ',
      };

      final mergedFixes = {...spellingFixes, ...params.dynamicFixes};

      mergedFixes.forEach((wrong, correct) {
        final baseWrong = wrong.replaceAll(RegExp(r'[\u064B-\u0652]'), '');
        final patternParts = baseWrong.split('').map((char) {
          if (char == ' ') return r'\s+';
          return RegExp.escape(char) + r'[\u064B-\u0652]*';
        }).join('');
        final pattern = RegExp('(?<![\\u0600-\\u06FF])' + patternParts + '(?![\\u0600-\\u06FF])');
        para = replaceWithCount(para, pattern, (match) => correct);
      });
    }

    para = replaceWithCount(para, RegExp(r'[ \t]{2,}'), (m) => ' ');
    formattedParagraphs.add(para);
  }

  String newText = formattedParagraphs.join('\n');
  newText = replaceWithCount(newText, RegExp(r'\n{3,}'), (m) => '\n\n');

  int wordCount = text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  int score = 100;
  if (wordCount > 0) {
    double errorRate = (changesCount / wordCount) * 100;
    score = (100 - errorRate).clamp(0, 100).toInt();
  }

  return MagicFormatterResult(
    formattedText: newText,
    changesCount: changesCount,
    score: score,
  );
}

class MagicFormattingProgressDialog extends StatefulWidget {
  final String text;
  final List<ParagraphFormat> lineFormats;
  final Map<String, String> dynamicFixes;
  final Function(String formattedText, String resultMessage) onComplete;

  const MagicFormattingProgressDialog({
    super.key,
    required this.text,
    required this.lineFormats,
    required this.dynamicFixes,
    required this.onComplete,
  });

  @override
  State<MagicFormattingProgressDialog> createState() => _MagicFormattingProgressDialogState();
}

class _MagicFormattingProgressDialogState extends State<MagicFormattingProgressDialog> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progress;
  final List<String> _words = [
    'جاري التدقيق...',
    'تحليل الكلمات...',
    'ضبط القواعد...',
    'تصحيح الإملاء...',
    'تنسيق الفقرات...',
    'معالجة النصوص...'
  ];
  String _currentWord = 'جاري التدقيق...';
  
  String _formattedText = '';
  String _resultMessage = 'جاري التحليل...';
  bool _isFormattingDone = false;
  bool _isAnimationDone = false;
  bool _isDone = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500));
    _progress = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    
    _controller.addListener(() {
      if (mounted) {
        setState(() {
          int wordIndex = (_progress.value * _words.length).floor();
          if (wordIndex >= _words.length) wordIndex = _words.length - 1;
          _currentWord = _words[wordIndex];
        });
      }
    });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          setState(() {
            _isAnimationDone = true;
            _checkIfDone();
          });
        }
      }
    });

    _controller.forward();
    _startIsolateFormatting();
  }

  Future<void> _startIsolateFormatting() async {
    final params = MagicFormatterParams(
      text: widget.text,
      lineFormats: widget.lineFormats,
      dynamicFixes: widget.dynamicFixes,
    );

    try {
      // تشغيل عملية التدقيق بالخلفية لضمان عدم تجمد الواجهة (Background Isolate)
      final result = await compute(runMagicFormattingInIsolate, params);
      
      String msg;
      if (result.changesCount == 0) {
        msg = 'النص سليم تماماً.\nنسبة سلامة النص: 100%';
      } else {
        msg = 'تم الانتهاء من التنسيق التلقائي.\n\nعدد التعديلات التي تم تطبيقها: ${result.changesCount}\nنسبة سلامة النص الأصلية: ${result.score}%';
      }

      if (mounted) {
        setState(() {
          _formattedText = result.formattedText;
          _resultMessage = msg;
          _isFormattingDone = true;
          _checkIfDone();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _formattedText = widget.text;
          _resultMessage = 'حدث خطأ أثناء التنسيق: $e';
          _isFormattingDone = true;
          _checkIfDone();
        });
      }
    }
  }

  void _checkIfDone() {
    if (_isFormattingDone && _isAnimationDone) {
      setState(() {
        _isDone = true;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isDone) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('اكتمل التدقيق'),
          ],
        ),
        content: Text(_resultMessage, style: const TextStyle(fontSize: 16, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onComplete(_formattedText, _resultMessage);
            },
            child: const Text('تم', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      );
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('التدقيق الآلي', textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _progress.value,
              minHeight: 10,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '${(_progress.value * 100).toInt()}%',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              _currentWord,
              key: ValueKey<String>(_currentWord),
              style: const TextStyle(color: Colors.grey, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
