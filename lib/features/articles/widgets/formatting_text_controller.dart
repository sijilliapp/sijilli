import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

// ============================================================
// تعريف أنواع التنسيق
// ============================================================

/// تنسيق على مستوى الفقرة (paragraph-level)
enum ParagraphFormat {
  none,
  center,
  justify,
  left,
  right,
  poem,
}

class FormattingTextEditingController extends TextEditingController {
  bool _internalUpdate = false;
  String? _highlightQuery;

  // ============================================================
  // Undo/Redo History Stacks
  // ============================================================
  final List<TextEditingValue> _undoStack = [];
  final List<TextEditingValue> _redoStack = [];
  bool _isUndoingOrRedoing = false;
  bool _isTypingSession = false;
  Timer? _debounceTimer;

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  // ============================================================
  // FormattingTextEditingController
  // ============================================================

  /// `TextEditingController` مخصص يعمل بنظام التحرير المباشر مع التنسيق البصري للوسوم.
  /// يتم تخزين النص مع وسومه في الـ `text` مباشرة لتفادي أي مشاكل إزاحة أو مزامنة.
  List<(int start, int end)> _getTagRangesOfText(String content) {
    final pattern = RegExp(
      r'\[/?(?:POEM|BOLD|CENTER|JUSTIFY|LEFT|RIGHT|B|HIGHLIGHT)\]',
      caseSensitive: false,
    );
    final List<(int start, int end)> ranges = [];
    for (final match in pattern.allMatches(content)) {
      ranges.add((match.start, match.end));
    }
    return ranges;
  }

  @override
  set value(TextEditingValue newValue) {
    final String oldText = value.text;
    final String newText = newValue.text;

    // Record undo/redo history if the text changed and we are not currently undoing/redoing
    if (newText != oldText && !_isUndoingOrRedoing) {
      _redoStack.clear();
      
      if (_internalUpdate) {
        // Programmatic changes (like formatting buttons) are committed immediately
        _undoStack.add(value);
        if (_undoStack.length > 100) {
          _undoStack.removeAt(0);
        }
        _isTypingSession = false;
        _debounceTimer?.cancel();
      } else {
        // Typing changes
        final bool isWordBoundary = newText.length > oldText.length && 
            (newText.endsWith(' ') || newText.endsWith('\n') || newText.endsWith('\t'));
        final bool isSignificantChange = (newText.length - oldText.length).abs() > 1;
        
        if (!_isTypingSession || isWordBoundary || isSignificantChange) {
          _undoStack.add(value);
          if (_undoStack.length > 100) {
            _undoStack.removeAt(0);
          }
          _isTypingSession = true;
        }
        
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(milliseconds: 800), () {
          _isTypingSession = false;
        });
      }
    }

    if (_internalUpdate) {
      super.value = newValue;
      return;
    }

    final String cleanedText = _cleanCitations(newText);
    
    if (cleanedText != newText) {
      int newBase = newValue.selection.baseOffset;
      int newExtent = newValue.selection.extentOffset;
      
      int mappedBase = newBase;
      int mappedExtent = newExtent;
      
      int cleanIdx = 0;
      int rawIdx = 0;
      
      while (rawIdx < newText.length && cleanIdx < cleanedText.length) {
        if (rawIdx == newBase) {
          mappedBase = cleanIdx;
        }
        if (rawIdx == newExtent) {
          mappedExtent = cleanIdx;
        }
        
        if (newText[rawIdx] == cleanedText[cleanIdx]) {
          cleanIdx++;
          rawIdx++;
        } else {
          rawIdx++;
        }
      }
      
      if (rawIdx == newBase) mappedBase = cleanIdx;
      if (rawIdx == newExtent) mappedExtent = cleanIdx;
      
      newValue = newValue.copyWith(
        text: cleanedText,
        selection: TextSelection(
          baseOffset: mappedBase,
          extentOffset: mappedExtent,
        ),
      );
    }

    final oldSel = value.selection;
    final newSel = newValue.selection;

    // 1. الحظر والمغنطة (Cursor Snap) لمنع المؤشر من الوقوف داخل الوسوم
    if (newSel.isValid && newSel != oldSel) {
      final textContent = newValue.text;
      final ranges = _getTagRangesOfText(textContent);
      
      int newBase = newSel.baseOffset;
      int newExtent = newSel.extentOffset;
      
      int snapOffset(int offset) {
        for (final range in ranges) {
          if (offset > range.$1 && offset < range.$2) {
            final distToStart = (offset - range.$1).abs();
            final distToEnd = (offset - range.$2).abs();
            return distToStart < distToEnd ? range.$1 : range.$2;
          }
        }
        return offset;
      }

      final snappedBase = snapOffset(newBase);
      final snappedExtent = snapOffset(newExtent);
      
      if (snappedBase != newBase || snappedExtent != newExtent) {
        newValue = newValue.copyWith(
          selection: TextSelection(
            baseOffset: snappedBase,
            extentOffset: snappedExtent,
          ),
        );
      }
    }

    // 2. الحذف الذري (Atomic Deletion) لحذف الوسم بالكامل عند الضغط على Backspace
    if (newValue.text.length < value.text.length && oldSel.isCollapsed && oldSel.start > 0) {
      final oldText = value.text;
      final deletedIndex = oldSel.start - 1;
      
      final ranges = _getTagRangesOfText(oldText);
      for (final range in ranges) {
        if (deletedIndex >= range.$1 && deletedIndex < range.$2) {
          final fullNewText = oldText.replaceRange(range.$1, range.$2, '');
          newValue = TextEditingValue(
            text: fullNewText,
            selection: TextSelection.collapsed(offset: range.$1),
          );
          break;
        }
      }
    }

    super.value = newValue;
  }

  String _cleanCitations(String rawText) {
    return rawText.replaceAllMapped(RegExp(r'\[([^\]]+?)\]'), (match) {
      final content = match.group(1)!;
      final cleanedContent = content
          .replaceAll('ٱ', 'ا')
          .replaceAll(RegExp(r'[\u064b-\u0652\u0670]'), '');
      return '[$cleanedContent]';
    });
  }

  FormattingTextEditingController({String rawText = ''}) {
    text = _cleanCitations(rawText);
    clearHistory();
  }

  void undo() {
    if (!canUndo) return;
    
    final currentVal = value;
    _redoStack.add(currentVal);
    if (_redoStack.length > 100) {
      _redoStack.removeAt(0);
    }
    
    final previousVal = _undoStack.removeLast();
    
    _isUndoingOrRedoing = true;
    _isTypingSession = false;
    _debounceTimer?.cancel();
    value = previousVal;
    _isUndoingOrRedoing = false;
    
    notifyListeners();
  }

  void redo() {
    if (!canRedo) return;
    
    final currentVal = value;
    _undoStack.add(currentVal);
    if (_undoStack.length > 100) {
      _undoStack.removeAt(0);
    }
    
    final nextVal = _redoStack.removeLast();
    
    _isUndoingOrRedoing = true;
    _isTypingSession = false;
    _debounceTimer?.cancel();
    value = nextVal;
    _isUndoingOrRedoing = false;
    
    notifyListeners();
  }

  void clearHistory() {
    _undoStack.clear();
    _redoStack.clear();
    _isTypingSession = false;
    _debounceTimer?.cancel();
  }

  void updateValueProgrammatically(TextEditingValue newValue) {
    _internalUpdate = true;
    value = newValue;
    _internalUpdate = false;
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  String? get highlightQuery => _highlightQuery;
  set highlightQuery(String? val) {
    if (_highlightQuery != val) {
      _highlightQuery = val;
      notifyListeners();
    }
  }

  // ----------------------------------------------------------
  // Getters
  // ----------------------------------------------------------

  /// النص الخام الكامل (للحفظ في قاعدة البيانات)
  String get rawText => text;

  /// النص النظيف الحالي (ما يراه المستخدم بدون وسوم)
  String get cleanText {
    return text
        .replaceAll(RegExp(r'\[/?(POEM|BOLD|CENTER|JUSTIFY|LEFT|RIGHT|B|HIGHLIGHT)\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'[=~]'), '')
        .replaceAll(RegExp(r'\*'), '')
        .replaceAll(RegExp(r'\+\+'), '')
        .replaceAll(RegExp(r'--'), '');
  }

  // ----------------------------------------------------------
  // دالات التحديث الخارجي
  // ----------------------------------------------------------

  /// تعيين النص الخام
  void setRawText(String raw) {
    _internalUpdate = true;
    text = _cleanCitations(raw);
    _internalUpdate = false;
  }

  // ----------------------------------------------------------
  // الحصول على معلومات الفقرة الحالية
  // ----------------------------------------------------------

  /// يجد حدود السطر الحالي الذي يقع فيه المؤشر
  (int start, int end) _currentLineRange() {
    final sel = selection;
    if (!sel.isValid) return (0, 0);
    final content = text;

    int start = sel.baseOffset;
    while (start > 0 && content[start - 1] != '\n') {
      start--;
    }
    int end = sel.baseOffset;
    while (end < content.length && content[end] != '\n') {
      end++;
    }
    return (start, end);
  }

  /// يتحقق إذا كان فهرس المحارف يقع داخل كتلة [POEM]
  bool _isLineInsidePoemBlock(int charIndex) {
    final content = text;
    final poemPattern = RegExp(r'\[POEM\]([\s\S]*?)\[/POEM\]', caseSensitive: false);
    for (final match in poemPattern.allMatches(content)) {
      if (charIndex >= match.start && charIndex < match.end) {
        return true;
      }
    }
    return false;
  }

  /// يُعيد تنسيق الفقرة الحالية
  ParagraphFormat get currentParagraphFormat {
    final range = _currentLineRange();
    if (range.$1 >= range.$2) return ParagraphFormat.none;
    final line = text.substring(range.$1, range.$2).trim();

    if (_isLineInsidePoemBlock(range.$1)) {
      return ParagraphFormat.poem;
    }

    if ((line.startsWith('[CENTER]') && line.endsWith('[/CENTER]')) ||
        (line.startsWith('=') && line.endsWith('=') && line.length > 1)) {
      return ParagraphFormat.center;
    }
    if ((line.startsWith('[JUSTIFY]') && line.endsWith('[/JUSTIFY]')) ||
        (line.startsWith('~') && line.endsWith('~') && line.length > 1)) {
      return ParagraphFormat.justify;
    }
    if ((line.startsWith('[LEFT]') && line.endsWith('[/LEFT]')) ||
        (line.startsWith('--') && line.endsWith('--') && line.length > 3)) {
      return ParagraphFormat.left;
    }
    if ((line.startsWith('[RIGHT]') && line.endsWith('[/RIGHT]')) ||
        (line.startsWith('++') && line.endsWith('++') && line.length > 3)) {
      return ParagraphFormat.right;
    }
    return ParagraphFormat.none;
  }

  // ----------------------------------------------------------
  // تطبيق التنسيقات والوسوم على النص
  // ----------------------------------------------------------

  /// يُبدِّل تنسيق الفقرات المحددة
  void toggleParagraphFormat(ParagraphFormat format) {
    final sel = selection;
    if (!sel.isValid) return;

    final content = text;

    // 1. تحديد بداية ونهاية السطور المحددة بالكامل
    int start = sel.start;
    while (start > 0 && content[start - 1] != '\n') {
      start--;
    }
    int end = sel.end;
    while (end < content.length && content[end] != '\n') {
      end++;
    }

    final selectedText = content.substring(start, end);
    final lines = selectedText.split('\n');

    // للقصيدة الشعرية: يتم تغليف السطور المحددة بالكامل داخل كتلة واحدة
    if (format == ParagraphFormat.poem) {
      final trimmed = selectedText.trim();
      final bool isPoem = trimmed.startsWith('[POEM]') && trimmed.endsWith('[/POEM]');

      String newText;
      if (isPoem) {
        // إزالة وسوم القصيدة
        String inner = trimmed.substring('[POEM]'.length, trimmed.length - '[/POEM]'.length).trim();
        newText = inner;
      } else {
        // مسح أي وسوم فقرات أخرى أولاً
        final cleanedLines = lines.map((l) => _stripParagraphTags(l)).toList();
        newText = '[POEM]\n${cleanedLines.join('\n')}\n[/POEM]';
      }

      final fullNewText = content.replaceRange(start, end, newText);
      _internalUpdate = true;
      value = value.copyWith(
        text: fullNewText,
        selection: TextSelection(baseOffset: start, extentOffset: start + newText.length),
      );
      _internalUpdate = false;
      notifyListeners();
      return;
    }

    // للتنسيقات العادية (المحاذاة):
    final bool allHaveFormat = lines.every((l) => _getLineFormat(l) == format);
    final ParagraphFormat newFormat = allHaveFormat ? ParagraphFormat.none : format;

    final formattedLines = lines.map((l) {
      final cleaned = _stripParagraphTags(l);
      return _applyFormatToLine(cleaned, newFormat);
    }).toList();

    final newText = formattedLines.join('\n');
    final fullNewText = content.replaceRange(start, end, newText);

    _internalUpdate = true;
    value = value.copyWith(
      text: fullNewText,
      selection: TextSelection(baseOffset: start, extentOffset: start + newText.length),
    );
    _internalUpdate = false;
    notifyListeners();
  }

  /// يُطبِّق/يُزيل التعريض (Bold) على الكلمة أو الجزء المحدد (كـ Switch)
  void toggleBoldAtCursor() {
    final currentSel = selection;
    if (!currentSel.isValid) return;

    final content = text;
    int bStart = currentSel.start;
    int bEnd = currentSel.end;

    if (currentSel.isCollapsed) {
      // إيجاد حدود الكلمة
      while (bStart > 0 && !_isWordBoundary(content[bStart - 1])) {
        bStart--;
      }
      while (bEnd < content.length && !_isWordBoundary(content[bEnd])) {
        bEnd++;
      }
    }

    if (bStart >= bEnd) return;

    final selectedText = content.substring(bStart, bEnd);
    if (selectedText.trim().isEmpty) return;

    String newText;
    final upperSelected = selectedText.toUpperCase();
    final bool hasBoldTag = upperSelected.contains('[BOLD]') || 
                           upperSelected.contains('[/BOLD]') || 
                           upperSelected.contains('[B]') || 
                           upperSelected.contains('[/B]') ||
                           selectedText.contains('*');

    if (hasBoldTag) {
      // إزالة التنسيق
      newText = selectedText
          .replaceAll(RegExp(r'\[BOLD\]', caseSensitive: false), '')
          .replaceAll(RegExp(r'\[/BOLD\]', caseSensitive: false), '')
          .replaceAll(RegExp(r'\[B\]', caseSensitive: false), '')
          .replaceAll(RegExp(r'\[/B\]', caseSensitive: false), '')
          .replaceAll('*', '');
    } else {
      // إضافة التنسيق
      newText = '[BOLD]$selectedText[/BOLD]';
    }

    final fullNewText = content.replaceRange(bStart, bEnd, newText);
    _internalUpdate = true;
    value = value.copyWith(
      text: fullNewText,
      selection: TextSelection(baseOffset: bStart, extentOffset: bStart + newText.length),
    );
    _internalUpdate = false;
    notifyListeners();
  }

  /// يُطبِّق/يُزيل التمييز (Highlight) على الكلمة أو الجزء المحدد (كـ Switch)
  void toggleHighlightAtCursor() {
    final currentSel = selection;
    if (!currentSel.isValid) return;

    final content = text;
    int bStart = currentSel.start;
    int bEnd = currentSel.end;

    if (currentSel.isCollapsed) {
      // إيجاد حدود الكلمة
      while (bStart > 0 && !_isWordBoundary(content[bStart - 1])) {
        bStart--;
      }
      while (bEnd < content.length && !_isWordBoundary(content[bEnd])) {
        bEnd++;
      }
    }

    if (bStart >= bEnd) return;

    final selectedText = content.substring(bStart, bEnd);
    if (selectedText.trim().isEmpty) return;

    String newText;
    final upperSelected = selectedText.toUpperCase();
    final bool hasHighlightTag = upperSelected.contains('[HIGHLIGHT]') || 
                                 upperSelected.contains('[/HIGHLIGHT]');

    if (hasHighlightTag) {
      // إزالة التنسيق
      newText = selectedText
          .replaceAll(RegExp(r'\[HIGHLIGHT\]', caseSensitive: false), '')
          .replaceAll(RegExp(r'\[/HIGHLIGHT\]', caseSensitive: false), '');
    } else {
      // إضافة التنسيق
      newText = '[HIGHLIGHT]$selectedText[/HIGHLIGHT]';
    }

    final fullNewText = content.replaceRange(bStart, bEnd, newText);
    _internalUpdate = true;
    value = value.copyWith(
      text: fullNewText,
      selection: TextSelection(baseOffset: bStart, extentOffset: bStart + newText.length),
    );
    _internalUpdate = false;
    notifyListeners();
  }

  // ----------------------------------------------------------
  // دالات مساعدة
  // ----------------------------------------------------------

  bool _isWordBoundary(String c) {
    return c == ' ' || c == '\n' || c == '\t' || c == '\u2003' || c == '\u200B';
  }

  String _stripParagraphTags(String line) {
    final trimmed = line.trim();
    if ((trimmed.startsWith('[CENTER]') && trimmed.endsWith('[/CENTER]')) ||
        (trimmed.startsWith('=') && trimmed.endsWith('=') && trimmed.length > 1)) {
      return trimmed.startsWith('=') ? trimmed.substring(1, trimmed.length - 1).trim() : trimmed.substring(8, trimmed.length - 9).trim();
    }
    if ((trimmed.startsWith('[JUSTIFY]') && trimmed.endsWith('[/JUSTIFY]')) ||
        (trimmed.startsWith('~') && trimmed.endsWith('~') && trimmed.length > 1)) {
      return trimmed.startsWith('~') ? trimmed.substring(1, trimmed.length - 1).trim() : trimmed.substring(9, trimmed.length - 10).trim();
    }
    if ((trimmed.startsWith('[LEFT]') && trimmed.endsWith('[/LEFT]')) ||
        (trimmed.startsWith('--') && trimmed.endsWith('--') && trimmed.length > 3)) {
      return trimmed.startsWith('-') ? trimmed.substring(2, trimmed.length - 2).trim() : trimmed.substring(6, trimmed.length - 7).trim();
    }
    if ((trimmed.startsWith('[RIGHT]') && trimmed.endsWith('[/RIGHT]')) ||
        (trimmed.startsWith('++') && trimmed.endsWith('++') && trimmed.length > 3)) {
      return trimmed.startsWith('+') ? trimmed.substring(2, trimmed.length - 2).trim() : trimmed.substring(7, trimmed.length - 8).trim();
    }
    return line;
  }

  ParagraphFormat _getLineFormat(String line) {
    final trimmed = line.trim();
    if ((trimmed.startsWith('[CENTER]') && trimmed.endsWith('[/CENTER]')) ||
        (trimmed.startsWith('=') && trimmed.endsWith('=') && trimmed.length > 1)) {
      return ParagraphFormat.center;
    }
    if ((trimmed.startsWith('[JUSTIFY]') && trimmed.endsWith('[/JUSTIFY]')) ||
        (trimmed.startsWith('~') && trimmed.endsWith('~') && trimmed.length > 1)) {
      return ParagraphFormat.justify;
    }
    if ((trimmed.startsWith('[LEFT]') && trimmed.endsWith('[/LEFT]')) ||
        (trimmed.startsWith('--') && trimmed.endsWith('--') && trimmed.length > 3)) {
      return ParagraphFormat.left;
    }
    if ((trimmed.startsWith('[RIGHT]') && trimmed.endsWith('[/RIGHT]')) ||
        (trimmed.startsWith('++') && trimmed.endsWith('++') && trimmed.length > 3)) {
      return ParagraphFormat.right;
    }
    return ParagraphFormat.none;
  }

  String _applyFormatToLine(String cleanLine, ParagraphFormat format) {
    final trimmed = cleanLine.trim();
    if (trimmed.isEmpty) return cleanLine;
    switch (format) {
      case ParagraphFormat.none:
        return trimmed;
      case ParagraphFormat.center:
        return '[CENTER]$trimmed[/CENTER]';
      case ParagraphFormat.justify:
        return '[JUSTIFY]$trimmed[/JUSTIFY]';
      case ParagraphFormat.left:
        return '[LEFT]$trimmed[/LEFT]';
      case ParagraphFormat.right:
        return '[RIGHT]$trimmed[/RIGHT]';
      case ParagraphFormat.poem:
        return '[POEM]\n$trimmed\n[/POEM]';
    }
  }

  // ----------------------------------------------------------
  // buildTextSpan: التزيين البصري الأنيق للوسوم داخل المحرر مع تظليل البحث
  // ----------------------------------------------------------

  List<InlineSpan> _buildHighlightedSpans(String segmentText, TextStyle baseStyle, BuildContext context) {
    if (_highlightQuery == null || _highlightQuery!.trim().isEmpty) {
      return [TextSpan(text: segmentText, style: baseStyle)];
    }

    final query = _highlightQuery!.trim();
    // إزالة التشكيل لبناء نمط البحث غير الحساس للتشكيل
    final baseWord = query.replaceAll(RegExp(r'[\u064B-\u0652]'), '');
    if (baseWord.isEmpty) {
      return [TextSpan(text: segmentText, style: baseStyle)];
    }

    final regexPattern = baseWord.split('').map((char) => RegExp.escape(char)).join(r'[\u064B-\u0652]*');
    final regex = RegExp(regexPattern, caseSensitive: false);

    final List<InlineSpan> spans = [];
    int lastIndex = 0;

    for (final match in regex.allMatches(segmentText)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: segmentText.substring(lastIndex, match.start),
          style: baseStyle,
        ));
      }
      spans.add(TextSpan(
        text: match.group(0),
        style: baseStyle.copyWith(
          backgroundColor: Colors.yellow.withValues(alpha: 0.5),
          color: Colors.black, // لضمان وضوح النص المظلل في أي ثيم
        ),
      ));
      lastIndex = match.end;
    }

    if (lastIndex < segmentText.length) {
      spans.add(TextSpan(
        text: segmentText.substring(lastIndex),
        style: baseStyle,
      ));
    }

    return spans;
  }

  TextStyle _getTagChipStyle(String tag, BuildContext context, TextStyle defaultStyle) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cleanTag = tag.toUpperCase().replaceAll('[', '').replaceAll(']', '').replaceAll('/', '');
    
    Color bg;
    Color fg;
    
    switch (cleanTag) {
      case 'POEM':
        bg = isDark ? const Color(0xFF4C1D95) : const Color(0xFFF3E8FF); // Purple
        fg = isDark ? const Color(0xFFDDD6FE) : const Color(0xFF7C3AED);
        break;
      case 'BOLD':
      case 'B':
        bg = isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE); // Blue
        fg = isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8);
        break;
      case 'HIGHLIGHT':
        bg = isDark ? const Color(0xFF78350F) : const Color(0xFFFEF08A); // Amber/Yellow
        fg = isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309);
        break;
      case 'CENTER':
      case 'JUSTIFY':
      case 'LEFT':
      case 'RIGHT':
        bg = isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5); // Emerald/Green
        fg = isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857);
        break;
      default:
        bg = isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6); // Grey
        fg = isDark ? const Color(0xFFD1D5DB) : const Color(0xFF4B5563);
        break;
    }
    
    return defaultStyle.copyWith(
      backgroundColor: bg,
      color: fg,
      fontSize: 13,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
    );
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final fullText = text;
    if (fullText.isEmpty) {
      return TextSpan(text: fullText, style: style);
    }

    final defaultStyle = style ?? const TextStyle();
    
    // وسوم رمادية خفيفة (للقديمة غير المطورة)
    final tagStyle = defaultStyle.copyWith(
      color: AppColors.getTextPrimary(context).withValues(alpha: 0.35),
      fontSize: 14,
      fontWeight: FontWeight.normal,
    );

    final List<InlineSpan> children = [];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // التعبيرات المنتظمة لالتقاط الكتل والوسوم
    final pattern = RegExp(
      r'(\[POEM\][\s\S]*?\[/POEM\])'
      r'|(\[BOLD\][\s\S]*?\[/BOLD\])'
      r'|(\[B\][\s\S]*?\[/B\])'
      r'|(\[HIGHLIGHT\][\s\S]*?\[/HIGHLIGHT\])'
      r'|(\[CENTER\][\s\S]*?\[/CENTER\])'
      r'|(\[JUSTIFY\][\s\S]*?\[/JUSTIFY\])'
      r'|(\[LEFT\][\s\S]*?\[/LEFT\])'
      r'|(\[RIGHT\][\s\S]*?\[/RIGHT\])'
      r'|(\*.*?\*)'
      r'|(=.*?=)'
      r'|(~.*?~)'
      r'|(--.*?--)'
      r'|(\+\+.*?\+\+)',
      caseSensitive: false,
    );

    int lastIndex = 0;

    for (final match in pattern.allMatches(fullText)) {
      // إضافة النص العادي قبل الوسم
      if (match.start > lastIndex) {
        children.addAll(_buildHighlightedSpans(
          fullText.substring(lastIndex, match.start),
          defaultStyle,
          context,
        ));
      }

      final matchedText = match.group(0)!;
      final matchedUpper = matchedText.toUpperCase();

      if (matchedUpper.startsWith('[POEM]')) {
        final tagLength = '[POEM]'.length;
        final innerText = matchedText.substring(tagLength, matchedText.length - (tagLength + 1));
        children.add(TextSpan(text: '[POEM]', style: _getTagChipStyle('[POEM]', context, defaultStyle)));
        children.addAll(_buildHighlightedSpans(
          innerText,
          defaultStyle.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.primary.withValues(alpha: 0.85),
            fontStyle: FontStyle.italic,
          ),
          context,
        ));
        children.add(TextSpan(text: '[/POEM]', style: _getTagChipStyle('[/POEM]', context, defaultStyle)));
      } else if (matchedUpper.startsWith('[BOLD]')) {
        final tagLength = '[BOLD]'.length;
        final innerText = matchedText.substring(tagLength, matchedText.length - (tagLength + 1));
        children.add(TextSpan(text: '[BOLD]', style: _getTagChipStyle('[BOLD]', context, defaultStyle)));
        children.addAll(_buildHighlightedSpans(
          innerText,
          defaultStyle.copyWith(fontWeight: FontWeight.w900),
          context,
        ));
        children.add(TextSpan(text: '[/BOLD]', style: _getTagChipStyle('[/BOLD]', context, defaultStyle)));
      } else if (matchedUpper.startsWith('[HIGHLIGHT]')) {
        final tagLength = '[HIGHLIGHT]'.length;
        final innerText = matchedText.substring(tagLength, matchedText.length - (tagLength + 1));
        children.add(TextSpan(text: '[HIGHLIGHT]', style: _getTagChipStyle('[HIGHLIGHT]', context, defaultStyle)));
        children.addAll(_buildHighlightedSpans(
          innerText,
          defaultStyle.copyWith(
            backgroundColor: isDark ? const Color(0xFF78350F).withValues(alpha: 0.5) : const Color(0xFFFEF08A),
            color: isDark ? const Color(0xFFFFFBEB) : const Color(0xFF1E293B),
          ),
          context,
        ));
        children.add(TextSpan(text: '[/HIGHLIGHT]', style: _getTagChipStyle('[/HIGHLIGHT]', context, defaultStyle)));
      } else if (matchedUpper.startsWith('[B]')) {
        final tagLength = '[B]'.length;
        final innerText = matchedText.substring(tagLength, matchedText.length - (tagLength + 1));
        children.add(TextSpan(text: '[B]', style: _getTagChipStyle('[B]', context, defaultStyle)));
        children.addAll(_buildHighlightedSpans(
          innerText,
          defaultStyle.copyWith(fontWeight: FontWeight.w900),
          context,
        ));
        children.add(TextSpan(text: '[/B]', style: _getTagChipStyle('[/B]', context, defaultStyle)));
      } else if (matchedUpper.startsWith('[CENTER]')) {
        final tagLength = '[CENTER]'.length;
        final innerText = matchedText.substring(tagLength, matchedText.length - (tagLength + 1));
        children.add(TextSpan(text: '[CENTER]', style: _getTagChipStyle('[CENTER]', context, defaultStyle)));
        children.addAll(_buildHighlightedSpans(
          innerText,
          defaultStyle.copyWith(
            color: AppColors.primary,
            decoration: TextDecoration.underline,
          ),
          context,
        ));
        children.add(TextSpan(text: '[/CENTER]', style: _getTagChipStyle('[/CENTER]', context, defaultStyle)));
      } else if (matchedUpper.startsWith('[JUSTIFY]')) {
        final tagLength = '[JUSTIFY]'.length;
        final innerText = matchedText.substring(tagLength, matchedText.length - (tagLength + 1));
        children.add(TextSpan(text: '[JUSTIFY]', style: _getTagChipStyle('[JUSTIFY]', context, defaultStyle)));
        children.addAll(_buildHighlightedSpans(
          innerText,
          defaultStyle.copyWith(decoration: TextDecoration.underline),
          context,
        ));
        children.add(TextSpan(text: '[/JUSTIFY]', style: _getTagChipStyle('[/JUSTIFY]', context, defaultStyle)));
      } else if (matchedUpper.startsWith('[LEFT]')) {
        final tagLength = '[LEFT]'.length;
        final innerText = matchedText.substring(tagLength, matchedText.length - (tagLength + 1));
        children.add(TextSpan(text: '[LEFT]', style: _getTagChipStyle('[LEFT]', context, defaultStyle)));
        children.addAll(_buildHighlightedSpans(
          innerText,
          defaultStyle.copyWith(fontStyle: FontStyle.italic),
          context,
        ));
        children.add(TextSpan(text: '[/LEFT]', style: _getTagChipStyle('[/LEFT]', context, defaultStyle)));
      } else if (matchedUpper.startsWith('[RIGHT]')) {
        final tagLength = '[RIGHT]'.length;
        final innerText = matchedText.substring(tagLength, matchedText.length - (tagLength + 1));
        children.add(TextSpan(text: '[RIGHT]', style: _getTagChipStyle('[RIGHT]', context, defaultStyle)));
        children.addAll(_buildHighlightedSpans(
          innerText,
          defaultStyle.copyWith(fontWeight: FontWeight.w500),
          context,
        ));
        children.add(TextSpan(text: '[/RIGHT]', style: _getTagChipStyle('[/RIGHT]', context, defaultStyle)));
      } else if (matchedText.startsWith('*')) {
        final innerText = matchedText.substring(1, matchedText.length - 1);
        children.add(TextSpan(text: '*', style: tagStyle));
        children.addAll(_buildHighlightedSpans(
          innerText,
          defaultStyle.copyWith(fontWeight: FontWeight.w900),
          context,
        ));
        children.add(TextSpan(text: '*', style: tagStyle));
      } else if (matchedText.startsWith('=')) {
        final innerText = matchedText.substring(1, matchedText.length - 1);
        children.add(TextSpan(text: '=', style: tagStyle));
        children.addAll(_buildHighlightedSpans(
          innerText,
          defaultStyle.copyWith(
            color: AppColors.primary,
            decoration: TextDecoration.underline,
          ),
          context,
        ));
        children.add(TextSpan(text: '=', style: tagStyle));
      } else if (matchedText.startsWith('~')) {
        final innerText = matchedText.substring(1, matchedText.length - 1);
        children.add(TextSpan(text: '~', style: tagStyle));
        children.addAll(_buildHighlightedSpans(
          innerText,
          defaultStyle.copyWith(decoration: TextDecoration.underline),
          context,
        ));
        children.add(TextSpan(text: '~', style: tagStyle));
      } else if (matchedText.startsWith('--')) {
        final innerText = matchedText.substring(2, matchedText.length - 2);
        children.add(TextSpan(text: '--', style: tagStyle));
        children.addAll(_buildHighlightedSpans(
          innerText,
          defaultStyle.copyWith(fontStyle: FontStyle.italic),
          context,
        ));
        children.add(TextSpan(text: '--', style: tagStyle));
      } else if (matchedText.startsWith('++')) {
        final innerText = matchedText.substring(2, matchedText.length - 2);
        children.add(TextSpan(text: '++', style: tagStyle));
        children.addAll(_buildHighlightedSpans(
          innerText,
          defaultStyle.copyWith(fontWeight: FontWeight.w500),
          context,
        ));
        children.add(TextSpan(text: '++', style: tagStyle));
      }

      lastIndex = match.end;
    }

    if (lastIndex < fullText.length) {
      children.addAll(_buildHighlightedSpans(
        fullText.substring(lastIndex),
        defaultStyle,
        context,
      ));
    }

    return TextSpan(children: children, style: defaultStyle);
  }
}
