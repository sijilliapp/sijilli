import 'dart:async';
import 'package:flutter/material.dart';

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
  poemCenter,
  poemLeft,
}

enum SpanType { bold, highlight }

class StyleSpan {
  final int start;
  final int end;
  final SpanType type;

  StyleSpan({required this.start, required this.end, required this.type});

  StyleSpan copyWith({int? start, int? end, SpanType? type}) {
    return StyleSpan(
      start: start ?? this.start,
      end: end ?? this.end,
      type: type ?? this.type,
    );
  }

  @override
  String toString() => 'StyleSpan($start, $end, $type)';
}

class ParsedInlineText {
  final String cleanText;
  final List<StyleSpan> spans;
  ParsedInlineText(this.cleanText, this.spans);
}

class ParsedArticleContent {
  final String cleanText;
  final List<StyleSpan> inlineSpans;
  final List<ParagraphFormat> lineFormats;

  ParsedArticleContent({
    required this.cleanText,
    required this.inlineSpans,
    required this.lineFormats,
  });
}

class ControllerHistoryState {
  final TextEditingValue value;
  final List<StyleSpan> spans;
  final List<ParagraphFormat> lineFormats;

  ControllerHistoryState({
    required this.value,
    required List<StyleSpan> spans,
    required List<ParagraphFormat> lineFormats,
  })  : spans = List<StyleSpan>.from(spans),
        lineFormats = List<ParagraphFormat>.from(lineFormats);
}

class FormattingTextEditingController extends TextEditingController {
  bool _internalUpdate = false;
  String? _highlightQuery;

  // ============================================================
  // التنسيقات الوصفية المدمجة (Style Metadata)
  // ============================================================
  List<StyleSpan> _spans = [];
  List<ParagraphFormat> _lineFormats = [];

  List<StyleSpan> get spans => _spans;
  List<ParagraphFormat> get lineFormats => _lineFormats;

  // ============================================================
  // Undo/Redo History Stacks
  // ============================================================
  final List<ControllerHistoryState> _undoStack = [];
  final List<ControllerHistoryState> _redoStack = [];
  bool _isUndoingOrRedoing = false;
  bool _isTypingSession = false;
  Timer? _debounceTimer;

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  FormattingTextEditingController({String rawText = ''}) {
    setRawText(rawText);
    clearHistory();
  }

  @override
  set value(TextEditingValue newValue) {
    final String oldText = value.text;
    final String newText = newValue.text;
    final TextSelection oldSel = value.selection;

    final int oldLen = oldText.length;
    final int newLen = newText.length;
    final int delta = newLen - oldLen;

    int editStart = oldSel.start;
    int editEnd = oldSel.end;

    if (editStart < 0) {
      editStart = 0;
      while (editStart < oldText.length && editStart < newText.length && oldText[editStart] == newText[editStart]) {
        editStart++;
      }
      editEnd = oldLen;
    }

    // Select the inserted text on paste/autofill
    if (!_internalUpdate && delta > 1) {
      newValue = newValue.copyWith(
        selection: TextSelection(
          baseOffset: editStart,
          extentOffset: editStart + delta,
        ),
      );
    }

    // Smart Paste Poetry Detection on paste is disabled to prevent automatic formatting.
    // Poetry formatting is now done explicitly via the formatting button.

    // Record undo/redo history if the text changed and we are not currently undoing/redoing
    if (newText != oldText && !_isUndoingOrRedoing) {
      _redoStack.clear();
      
      final historyState = ControllerHistoryState(
        value: value,
        spans: _spans,
        lineFormats: _lineFormats,
      );

      if (_internalUpdate) {
        // Programmatic changes are committed immediately
        _undoStack.add(historyState);
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
          _undoStack.add(historyState);
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

    // Clean citations in brackets [...]
    final String cleanedText = _cleanCitations(newText);
    TextEditingValue finalValue = newValue;
    
    if (cleanedText != newText) {
      int newBase = newValue.selection.baseOffset;
      int newExtent = newValue.selection.extentOffset;
      
      int mappedBase = newBase;
      int mappedExtent = newExtent;
      
      int cleanIdx = 0;
      int rawIdx = 0;
      
      while (rawIdx < newText.length && cleanIdx < cleanedText.length) {
        if (rawIdx == newBase) mappedBase = cleanIdx;
        if (rawIdx == newExtent) mappedExtent = cleanIdx;
        
        if (newText[rawIdx] == cleanedText[cleanIdx]) {
          cleanIdx++;
          rawIdx++;
        } else {
          rawIdx++;
        }
      }
      
      if (rawIdx == newBase) mappedBase = cleanIdx;
      if (rawIdx == newExtent) mappedExtent = cleanIdx;
      
      finalValue = newValue.copyWith(
        text: cleanedText,
        selection: TextSelection(
          baseOffset: mappedBase,
          extentOffset: mappedExtent,
        ),
      );
    }

    // Sync metadata spans and paragraph formats if text changed
    if (finalValue.text != oldText) {
      _updateSpansOnChange(oldText, finalValue.text, oldSel, finalValue.selection);
      _updateLineFormatsOnChange(oldText, finalValue.text, oldSel, finalValue.selection);
    }

    super.value = finalValue;
  }

  // ============================================================
  // مزامنة التنسيقات عند تعديل النص
  // ============================================================
  
  void _updateSpansOnChange(String oldText, String newText, TextSelection oldSel, TextSelection newSel) {
    if (oldText == newText) return;

    final int oldLen = oldText.length;
    final int newLen = newText.length;
    final int delta = newLen - oldLen;

    int editStart = oldSel.start;
    int editEnd = oldSel.end;

    if (editStart < 0) {
      editStart = 0;
      while (editStart < oldText.length && editStart < newText.length && oldText[editStart] == newText[editStart]) {
        editStart++;
      }
      editEnd = oldLen;
    }

    final List<StyleSpan> updatedSpans = [];

    for (final span in _spans) {
      int start = span.start;
      int end = span.end;

      if (editEnd <= start) {
        start += delta;
        end += delta;
      } else if (editStart >= end) {
        // Keep as is
      } else {
        if (editStart >= start && editEnd <= end) {
          end += delta;
        } else {
          if (editStart < start) {
            start = editStart + delta;
          }
          if (editEnd > end) {
            end = editStart;
          }
          if (start < 0) start = 0;
          if (end < start) end = start;
        }
      }

      if (end > start) {
        updatedSpans.add(StyleSpan(start: start, end: end, type: span.type));
      }
    }

    _spans = updatedSpans;
  }

  void _updateLineFormatsOnChange(String oldText, String newText, TextSelection oldSel, TextSelection newSel) {
    final oldLines = oldText.split('\n');
    final newLines = newText.split('\n');
    
    if (oldLines.length == newLines.length) {
      return;
    }

    final List<ParagraphFormat> updatedFormats = [];
    
    int editedLineIndex = 0;
    int charCount = 0;
    for (int i = 0; i < oldLines.length; i++) {
      if (oldSel.start >= charCount && oldSel.start <= charCount + oldLines[i].length) {
        editedLineIndex = i;
        break;
      }
      charCount += oldLines[i].length + 1;
    }

    final lineDiff = newLines.length - oldLines.length;
    
    if (lineDiff > 0) {
      final bool isAtLineStart = oldSel.start == charCount;

      for (int i = 0; i < editedLineIndex; i++) {
        if (i < _lineFormats.length) {
          updatedFormats.add(_lineFormats[i]);
        } else {
          updatedFormats.add(ParagraphFormat.none);
        }
      }

      if (isAtLineStart) {
        // Pressing Enter at the start of the line:
        // The new empty line(s) get ParagraphFormat.none
        for (int i = 0; i < lineDiff; i++) {
          updatedFormats.add(ParagraphFormat.none);
        }
        // The original line gets pushed down and retains its format
        if (editedLineIndex < _lineFormats.length) {
          updatedFormats.add(_lineFormats[editedLineIndex]);
        } else {
          updatedFormats.add(ParagraphFormat.none);
        }
      } else {
        // Pressing Enter in the middle or end of the line:
        // The original line retains its format
        if (editedLineIndex < _lineFormats.length) {
          updatedFormats.add(_lineFormats[editedLineIndex]);
        } else {
          updatedFormats.add(ParagraphFormat.none);
        }
        // The new empty line(s) get ParagraphFormat.none
        for (int i = 0; i < lineDiff; i++) {
          updatedFormats.add(ParagraphFormat.none);
        }
      }

      for (int i = editedLineIndex + 1; i < _lineFormats.length; i++) {
        updatedFormats.add(_lineFormats[i]);
      }
    } else {
      for (int i = 0; i < editedLineIndex + lineDiff + 1; i++) {
        if (i < _lineFormats.length) {
          updatedFormats.add(_lineFormats[i]);
        }
      }
      for (int i = editedLineIndex + 1; i < _lineFormats.length; i++) {
        updatedFormats.add(_lineFormats[i]);
      }
    }

    while (updatedFormats.length < newLines.length) {
      updatedFormats.add(ParagraphFormat.none);
    }
    while (updatedFormats.length > newLines.length) {
      updatedFormats.removeLast();
    }

    _lineFormats = updatedFormats;
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

  // ============================================================
  // التراجع والإعادة (Undo/Redo)
  // ============================================================

  void _saveHistoryState() {
    _redoStack.clear();
    final currentState = ControllerHistoryState(
      value: value,
      spans: _spans,
      lineFormats: _lineFormats,
    );
    if (_undoStack.isNotEmpty) {
      final last = _undoStack.last;
      if (last.value.text == currentState.value.text &&
          _areSpansEqual(last.spans, currentState.spans) &&
          _areFormatsEqual(last.lineFormats, currentState.lineFormats)) {
        return; // Skip duplicate
      }
    }
    _undoStack.add(currentState);
    if (_undoStack.length > 100) {
      _undoStack.removeAt(0);
    }
  }

  bool _areSpansEqual(List<StyleSpan> a, List<StyleSpan> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].start != b[i].start || a[i].end != b[i].end || a[i].type != b[i].type) {
        return false;
      }
    }
    return true;
  }

  bool _areFormatsEqual(List<ParagraphFormat> a, List<ParagraphFormat> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void undo() {
    if (!canUndo) return;
    
    final currentVal = value;
    _redoStack.add(ControllerHistoryState(
      value: currentVal,
      spans: _spans,
      lineFormats: _lineFormats,
    ));
    if (_redoStack.length > 100) {
      _redoStack.removeAt(0);
    }
    
    final previousState = _undoStack.removeLast();
    
    _isUndoingOrRedoing = true;
    _isTypingSession = false;
    _debounceTimer?.cancel();
    
    _spans = previousState.spans;
    _lineFormats = previousState.lineFormats;
    value = previousState.value;
    
    _isUndoingOrRedoing = false;
    
    notifyListeners();
  }

  void redo() {
    if (!canRedo) return;
    
    final currentVal = value;
    _undoStack.add(ControllerHistoryState(
      value: currentVal,
      spans: _spans,
      lineFormats: _lineFormats,
    ));
    if (_undoStack.length > 100) {
      _undoStack.removeAt(0);
    }
    
    final nextState = _redoStack.removeLast();
    
    _isUndoingOrRedoing = true;
    _isTypingSession = false;
    _debounceTimer?.cancel();
    
    _spans = nextState.spans;
    _lineFormats = nextState.lineFormats;
    value = nextState.value;
    
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

  // ============================================================
  // الترجمة ثنائية الاتجاه (Serialization & Parsing)
  // ============================================================

  /// النص النظيف الحالي (ما يراه المستخدم بدون وسوم)
  String get cleanText => text;

  /// النص الخام الكامل بالوسوم (للحفظ في قاعدة البيانات)
  String get rawText {
    final clean = text;
    if (clean.isEmpty) return '';

    final lines = clean.split('\n');
    final List<String> formattedLines = [];
    bool inPoemBlock = false;
    int currentOffset = 0;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineStart = currentOffset;
      final lineEnd = currentOffset + line.length;

      // Extract inline spans for this line
      final List<StyleSpan> lineSpans = _spans
          .where((s) => s.start < lineEnd && s.end > lineStart)
          .toList();

      // Formulate insertions relative to this line
      final List<(int index, String tag)> insertions = [];
      for (final span in lineSpans) {
        final relStart = (span.start - lineStart).clamp(0, line.length);
        final relEnd = (span.end - lineStart).clamp(0, line.length);
        
        final tagStart = span.type == SpanType.bold ? '[BOLD]' : '[HIGHLIGHT]';
        final tagEnd = span.type == SpanType.bold ? '[/BOLD]' : '[/HIGHLIGHT]';

        insertions.add((relStart, tagStart));
        insertions.add((relEnd, tagEnd));
      }

      // Sort insertions: index ascending, closing tags first
      insertions.sort((a, b) {
        if (a.$1 != b.$1) {
          return a.$1.compareTo(b.$1);
        }
        final aIsClosing = a.$2.startsWith('[/');
        final bIsClosing = b.$2.startsWith('[/');
        if (aIsClosing && !bIsClosing) return -1;
        if (!aIsClosing && bIsClosing) return 1;
        return 0;
      });

      // Apply insertions in reverse order to keep indices stable
      String lineTextWithInline = line;
      for (int j = insertions.length - 1; j >= 0; j--) {
        final ins = insertions[j];
        lineTextWithInline = lineTextWithInline.replaceRange(ins.$1, ins.$1, ins.$2);
      }

      final ParagraphFormat format = i < _lineFormats.length ? _lineFormats[i] : ParagraphFormat.none;

      // Handle Poem Block Grouping
      final isPoemFormat = format == ParagraphFormat.poem || 
                          format == ParagraphFormat.poemCenter || 
                          format == ParagraphFormat.poemLeft;

      if (isPoemFormat) {
        if (!inPoemBlock) {
          formattedLines.add('[POEM]');
          inPoemBlock = true;
        }
        
        String poemLine = lineTextWithInline;
        if (format == ParagraphFormat.poemCenter) {
          poemLine = '[CENTER]$poemLine[/CENTER]';
        } else if (format == ParagraphFormat.poemLeft) {
          poemLine = '[LEFT]$poemLine[/LEFT]';
        }
        formattedLines.add(poemLine);
      } else {
        if (inPoemBlock) {
          formattedLines.add('[/POEM]');
          inPoemBlock = false;
        }

        String finalLine = lineTextWithInline;
        if (format == ParagraphFormat.center) {
          finalLine = '[CENTER]$finalLine[/CENTER]';
        } else if (format == ParagraphFormat.justify) {
          finalLine = '[JUSTIFY]$finalLine[/JUSTIFY]';
        } else if (format == ParagraphFormat.left) {
          finalLine = '[LEFT]$finalLine[/LEFT]';
        } else if (format == ParagraphFormat.right) {
          finalLine = '[RIGHT]$finalLine[/RIGHT]';
        }
        formattedLines.add(finalLine);
      }

      currentOffset += line.length + 1; // +1 for \n
    }

    if (inPoemBlock) {
      formattedLines.add('[/POEM]');
    }

    return formattedLines.join('\n');
  }

  /// تعيين وتفكيك النص الخام القادم من قاعدة البيانات
  void setRawText(String raw) {
    _saveHistoryState();
    _internalUpdate = true;
    final parsed = parseRawText(raw);
    _spans = parsed.inlineSpans;
    _lineFormats = parsed.lineFormats;
    text = parsed.cleanText;
    _internalUpdate = false;
    notifyListeners();
  }

  /// إدراج قالب القصيدة عند سطر معين وإعادة التحليل والتوجيه
  void insertPoemTemplateAtLine(int lineIndex, String poemRaw) {
    final clean = text;
    final lines = clean.split('\n');
    final List<String> formattedLines = [];
    bool inPoemBlock = false;
    int currentOffset = 0;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineStart = currentOffset;
      final lineEnd = currentOffset + line.length;

      if (i == lineIndex) {
        if (inPoemBlock) {
          formattedLines.add('[/POEM]');
          inPoemBlock = false;
        }
        formattedLines.add(poemRaw);
        currentOffset += line.length + 1;
        continue;
      }

      // Extract inline spans for this line
      final List<StyleSpan> lineSpans = _spans
          .where((s) => s.start < lineEnd && s.end > lineStart)
          .toList();

      // Formulate insertions relative to this line
      final List<(int index, String tag)> insertions = [];
      for (final span in lineSpans) {
        final relStart = (span.start - lineStart).clamp(0, line.length);
        final relEnd = (span.end - lineStart).clamp(0, line.length);
        
        final tagStart = span.type == SpanType.bold ? '[BOLD]' : '[HIGHLIGHT]';
        final tagEnd = span.type == SpanType.bold ? '[/BOLD]' : '[/HIGHLIGHT]';

        insertions.add((relStart, tagStart));
        insertions.add((relEnd, tagEnd));
      }

      // Sort insertions: index ascending, closing tags first
      insertions.sort((a, b) {
        if (a.$1 != b.$1) {
          return a.$1.compareTo(b.$1);
        }
        final aIsClosing = a.$2.startsWith('[/');
        final bIsClosing = b.$2.startsWith('[/');
        if (aIsClosing && !bIsClosing) return -1;
        if (!aIsClosing && bIsClosing) return 1;
        return 0;
      });

      // Apply insertions in reverse order to keep indices stable
      String lineTextWithInline = line;
      for (int j = insertions.length - 1; j >= 0; j--) {
        final ins = insertions[j];
        lineTextWithInline = lineTextWithInline.replaceRange(ins.$1, ins.$1, ins.$2);
      }

      final ParagraphFormat format = i < _lineFormats.length ? _lineFormats[i] : ParagraphFormat.none;

      // Handle Poem Block Grouping
      final isPoemFormat = format == ParagraphFormat.poem || 
                          format == ParagraphFormat.poemCenter || 
                          format == ParagraphFormat.poemLeft;

      if (isPoemFormat) {
        if (!inPoemBlock) {
          formattedLines.add('[POEM]');
          inPoemBlock = true;
        }
        
        String poemLine = lineTextWithInline;
        if (format == ParagraphFormat.poemCenter) {
          poemLine = '[CENTER]$poemLine[/CENTER]';
        } else if (format == ParagraphFormat.poemLeft) {
          poemLine = '[LEFT]$poemLine[/LEFT]';
        }
        formattedLines.add(poemLine);
      } else {
        if (inPoemBlock) {
          formattedLines.add('[/POEM]');
          inPoemBlock = false;
        }

        String finalLine = lineTextWithInline;
        if (format == ParagraphFormat.center) {
          finalLine = '[CENTER]$finalLine[/CENTER]';
        } else if (format == ParagraphFormat.justify) {
          finalLine = '[JUSTIFY]$finalLine[/JUSTIFY]';
        } else if (format == ParagraphFormat.left) {
          finalLine = '[LEFT]$finalLine[/LEFT]';
        } else if (format == ParagraphFormat.right) {
          finalLine = '[RIGHT]$finalLine[/RIGHT]';
        }
        formattedLines.add(finalLine);
      }

      currentOffset += line.length + 1; // +1 for \n
    }

    if (inPoemBlock) {
      formattedLines.add('[/POEM]');
    }

    final newRaw = formattedLines.join('\n');
    setRawText(newRaw);

    // Place selection cursor at the first inserted template line
    final newLines = text.split('\n');
    int newOffset = 0;
    for (int i = 0; i < lineIndex && i < newLines.length; i++) {
      newOffset += newLines[i].length + 1;
    }
    selection = TextSelection.collapsed(offset: newOffset);
  }

  // ============================================================
  // المحلل المخصص للمدونات (Parser)
  // ============================================================

  static ParsedArticleContent parseRawText(String raw) {
    if (raw.isEmpty) {
      return ParsedArticleContent(cleanText: '', inlineSpans: [], lineFormats: []);
    }

    final lines = raw.split('\n');
    final List<String> cleanLines = [];
    final List<ParagraphFormat> lineFormats = [];
    final List<StyleSpan> inlineSpans = [];

    bool insidePoem = false;
    int currentCleanOffset = 0;
    final poemSeparator = RegExp(r'\s*(?:\*\*\*|\*\s+\*\s+\*|\t|\s{3,})\s*');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();
      final trimmedUpper = trimmed.toUpperCase();

      if (trimmedUpper == '[POEM]') {
        insidePoem = true;
        continue;
      }
      if (trimmedUpper == '[/POEM]') {
        insidePoem = false;
        continue;
      }

      ParagraphFormat format = insidePoem ? ParagraphFormat.poem : ParagraphFormat.none;
      String lineText = line;
      final trimmedLine = lineText.trim();
      final trimmedLineUpper = trimmedLine.toUpperCase();

      final isCentered = (trimmedLineUpper.startsWith('[CENTER]') && trimmedLineUpper.endsWith('[/CENTER]')) ||
                         (trimmedLine.startsWith('=') && trimmedLine.endsWith('=') && trimmedLine.length > 1);
      final isLeft = (trimmedLineUpper.startsWith('[LEFT]') && trimmedLineUpper.endsWith('[/LEFT]')) ||
                     (trimmedLine.startsWith('--') && trimmedLine.endsWith('--') && trimmedLine.length > 3);
      final isRight = (trimmedLineUpper.startsWith('[RIGHT]') && trimmedLineUpper.endsWith('[/RIGHT]')) ||
                      (trimmedLine.startsWith('++') && trimmedLine.endsWith('++') && trimmedLine.length > 3);
      final isJustify = (trimmedLineUpper.startsWith('[JUSTIFY]') && trimmedLineUpper.endsWith('[/JUSTIFY]')) ||
                        (trimmedLine.startsWith('~') && trimmedLine.endsWith('~') && trimmedLine.length > 1);

      if (isCentered) {
        format = insidePoem ? ParagraphFormat.poemCenter : ParagraphFormat.center;
        if (trimmedLine.startsWith('=')) {
          lineText = lineText.replaceFirst('=', '');
          int lastIdx = lineText.lastIndexOf('=');
          if (lastIdx != -1) {
            lineText = lineText.substring(0, lastIdx) + lineText.substring(lastIdx + 1);
          }
        } else {
          lineText = lineText.replaceFirst(RegExp(r'\[CENTER\]', caseSensitive: false), '');
          lineText = lineText.replaceFirst(RegExp(r'\[/CENTER\]', caseSensitive: false), '');
        }
      } else if (isJustify) {
        format = ParagraphFormat.justify;
        if (trimmedLine.startsWith('~')) {
          lineText = lineText.replaceFirst('~', '');
          int lastIdx = lineText.lastIndexOf('~');
          if (lastIdx != -1) {
            lineText = lineText.substring(0, lastIdx) + lineText.substring(lastIdx + 1);
          }
        } else {
          lineText = lineText.replaceFirst(RegExp(r'\[JUSTIFY\]', caseSensitive: false), '');
          lineText = lineText.replaceFirst(RegExp(r'\[/JUSTIFY\]', caseSensitive: false), '');
        }
      } else if (isLeft) {
        format = insidePoem ? ParagraphFormat.poemLeft : ParagraphFormat.left;
        if (trimmedLine.startsWith('--')) {
          lineText = lineText.replaceFirst('--', '');
          int lastIdx = lineText.lastIndexOf('--');
          if (lastIdx != -1) {
            lineText = lineText.substring(0, lastIdx) + lineText.substring(lastIdx + 2);
          }
        } else {
          lineText = lineText.replaceFirst(RegExp(r'\[LEFT\]', caseSensitive: false), '');
          lineText = lineText.replaceFirst(RegExp(r'\[/LEFT\]', caseSensitive: false), '');
        }
      } else if (isRight) {
        format = ParagraphFormat.right;
        if (trimmedLine.startsWith('++')) {
          lineText = lineText.replaceFirst('++', '');
          int lastIdx = lineText.lastIndexOf('++');
          if (lastIdx != -1) {
            lineText = lineText.substring(0, lastIdx) + lineText.substring(lastIdx + 2);
          }
        } else {
          lineText = lineText.replaceFirst(RegExp(r'\[RIGHT\]', caseSensitive: false), '');
          lineText = lineText.replaceFirst(RegExp(r'\[/RIGHT\]', caseSensitive: false), '');
        }
      }

      // Smart poetry split on load if line inside poem contains ***
      if (insidePoem && !isCentered && !isLeft && lineText.contains(poemSeparator)) {
        final parts = lineText.split(poemSeparator);
        for (final part in parts) {
          if (part.trim().isEmpty) continue;
          final parsedInline = _parseInlineStyles(part, currentCleanOffset);
          cleanLines.add(parsedInline.cleanText);
          inlineSpans.addAll(parsedInline.spans);
          lineFormats.add(ParagraphFormat.poem);
          currentCleanOffset += parsedInline.cleanText.length + 1;
        }
        continue;
      }

      final parsedInline = _parseInlineStyles(lineText, currentCleanOffset);
      cleanLines.add(parsedInline.cleanText);
      inlineSpans.addAll(parsedInline.spans);
      lineFormats.add(format);

      currentCleanOffset += parsedInline.cleanText.length + 1;
    }

    return ParsedArticleContent(
      cleanText: cleanLines.join('\n'),
      inlineSpans: inlineSpans,
      lineFormats: lineFormats,
    );
  }

  static ParsedInlineText _parseInlineStyles(String text, int globalOffset) {
    final pattern = RegExp(
      r'(\[BOLD\])'
      r'|(\[/BOLD\])'
      r'|(\[B\])'
      r'|(\[/B\])'
      r'|(\[HIGHLIGHT\])'
      r'|(\[/HIGHLIGHT\])'
      r'|(\*)',
      caseSensitive: false,
    );

    final List<StyleSpan> spans = [];
    final StringBuffer cleanBuf = StringBuffer();

    final List<int> openBoldOffsets = [];
    final List<int> openHighlightOffsets = [];

    int lastIndex = 0;

    for (final match in pattern.allMatches(text)) {
      if (match.start > lastIndex) {
        cleanBuf.write(text.substring(lastIndex, match.start));
      }

      final matched = match.group(0)!;
      final matchedUpper = matched.toUpperCase();
      final currentCleanLen = cleanBuf.length;

      if (matchedUpper == '[BOLD]' || matchedUpper == '[B]') {
        openBoldOffsets.add(currentCleanLen);
      } else if (matchedUpper == '[/BOLD]' || matchedUpper == '[/B]') {
        if (openBoldOffsets.isNotEmpty) {
          final start = openBoldOffsets.removeLast();
          spans.add(StyleSpan(
            start: globalOffset + start,
            end: globalOffset + currentCleanLen,
            type: SpanType.bold,
          ));
        }
      } else if (matchedUpper == '[HIGHLIGHT]') {
        openHighlightOffsets.add(currentCleanLen);
      } else if (matchedUpper == '[/HIGHLIGHT]') {
        if (openHighlightOffsets.isNotEmpty) {
          final start = openHighlightOffsets.removeLast();
          spans.add(StyleSpan(
            start: globalOffset + start,
            end: globalOffset + currentCleanLen,
            type: SpanType.highlight,
          ));
        }
      } else if (matched == '*') {
        if (openBoldOffsets.isNotEmpty) {
          final start = openBoldOffsets.removeLast();
          spans.add(StyleSpan(
            start: globalOffset + start,
            end: globalOffset + currentCleanLen,
            type: SpanType.bold,
          ));
        } else {
          openBoldOffsets.add(currentCleanLen);
        }
      }

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      cleanBuf.write(text.substring(lastIndex));
    }

    final finalCleanLen = cleanBuf.length;
    for (final start in openBoldOffsets) {
      spans.add(StyleSpan(
        start: globalOffset + start,
        end: globalOffset + finalCleanLen,
        type: SpanType.bold,
      ));
    }
    for (final start in openHighlightOffsets) {
      spans.add(StyleSpan(
        start: globalOffset + start,
        end: globalOffset + finalCleanLen,
        type: SpanType.highlight,
      ));
    }

    return ParsedInlineText(cleanBuf.toString(), spans);
  }

  // ============================================================
  // الحصول على معلومات الفقرة الحالية والتعديل
  // ============================================================

  ParagraphFormat get currentParagraphFormat {
    final sel = selection;
    if (!sel.isValid) return ParagraphFormat.none;
    
    final lines = text.split('\n');
    int currentOffset = 0;
    for (int i = 0; i < lines.length; i++) {
      final len = lines[i].length;
      if (sel.baseOffset >= currentOffset && sel.baseOffset <= currentOffset + len) {
        if (i < _lineFormats.length) {
          return _lineFormats[i];
        }
        break;
      }
      currentOffset += len + 1;
    }
    return ParagraphFormat.none;
  }

  void toggleParagraphFormat(ParagraphFormat format) {
    final sel = selection;
    if (!sel.isValid) return;

    _saveHistoryState();
    final content = text;
    final lines = content.split('\n');

    int startOffset = sel.start;
    int endOffset = sel.end;

    int currentOffset = 0;
    int startLineIdx = -1;
    int endLineIdx = -1;

    for (int i = 0; i < lines.length; i++) {
      final len = lines[i].length;
      if (startOffset >= currentOffset && startOffset <= currentOffset + len) {
        if (startLineIdx == -1) startLineIdx = i;
      }
      if (endOffset >= currentOffset && endOffset <= currentOffset + len) {
        endLineIdx = i;
      }
      currentOffset += len + 1;
    }

    if (startLineIdx == -1 || endLineIdx == -1) return;

    // We distinguish if we are toggling poetry format or standard alignment format.
    if (format == ParagraphFormat.poem) {
      // Toggle poetry format
      bool allArePoem = true;
      for (int i = startLineIdx; i <= endLineIdx; i++) {
        final currentF = i < _lineFormats.length ? _lineFormats[i] : ParagraphFormat.none;
        final isLinePoem = currentF == ParagraphFormat.poem ||
                           currentF == ParagraphFormat.poemCenter ||
                           currentF == ParagraphFormat.poemLeft;
        if (!isLinePoem) {
          allArePoem = false;
          break;
        }
      }

      final List<String> updatedLines = [];
      final List<ParagraphFormat> updatedFormats = [];
      int selectionEndShift = 0;

      currentOffset = 0;
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        final lineLen = line.length;
        final lineEnd = currentOffset + lineLen;
        final bool isSelected = i >= startLineIdx && i <= endLineIdx;
        ParagraphFormat lineFormat = i < _lineFormats.length ? _lineFormats[i] : ParagraphFormat.none;

        if (isSelected) {
          if (allArePoem) {
            // Toggling poetry off
            if (lineFormat == ParagraphFormat.poem) {
              lineFormat = ParagraphFormat.none;
            } else if (lineFormat == ParagraphFormat.poemCenter) {
              lineFormat = ParagraphFormat.center;
            } else if (lineFormat == ParagraphFormat.poemLeft) {
              lineFormat = ParagraphFormat.left;
            }
          } else {
            // Toggling poetry on
            if (lineFormat == ParagraphFormat.center) {
              lineFormat = ParagraphFormat.poemCenter;
            } else if (lineFormat == ParagraphFormat.left) {
              lineFormat = ParagraphFormat.poemLeft;
            } else if (lineFormat == ParagraphFormat.poem ||
                       lineFormat == ParagraphFormat.poemCenter ||
                       lineFormat == ParagraphFormat.poemLeft) {
              // already poem, keep it
            } else {
              lineFormat = ParagraphFormat.poem;
            }
          }
        }

        final isPoemLine = lineFormat == ParagraphFormat.poem ||
                           lineFormat == ParagraphFormat.poemCenter ||
                           lineFormat == ParagraphFormat.poemLeft;

        final poemSeparator = RegExp(r'\s*(?:\*\*\*|\*\s+\*\s+\*|\s+#\s+|//+|\\+|--|\s+-\s+|\t|\s{3,})\s*');
        if (isPoemLine && line.contains(poemSeparator)) {
          final parts = line.split(poemSeparator).where((p) => p.trim().isNotEmpty).toList();
          if (parts.isNotEmpty) {
            for (int j = 0; j < parts.length; j++) {
              updatedLines.add(parts[j]);
              updatedFormats.add(lineFormat);
            }
            final addedNewlinesCount = parts.length - 1;
            if (sel.end > lineEnd) {
              selectionEndShift += addedNewlinesCount;
            }
          } else {
            updatedLines.add(line);
            updatedFormats.add(lineFormat);
          }
        } else {
          updatedLines.add(line);
          updatedFormats.add(lineFormat);
        }

        currentOffset += lineLen + 1;
      }

      final newText = updatedLines.join('\n');
      _lineFormats = updatedFormats;

      _internalUpdate = true;
      value = value.copyWith(
        text: newText,
        selection: TextSelection(
          baseOffset: sel.baseOffset,
          extentOffset: sel.extentOffset + selectionEndShift,
        ),
      );
      _internalUpdate = false;
      notifyListeners();
    } else {
      // Toggle standard alignment format (center, left, right, justify)
      // If we are on a poem line, we want center/left to toggle sub-alignments of the poem.
      bool allHaveFormat = true;
      for (int i = startLineIdx; i <= endLineIdx; i++) {
        final currentF = i < _lineFormats.length ? _lineFormats[i] : ParagraphFormat.none;
        // Check if the current format matches the target format or its poem equivalent
        bool hasTargetAlignment = false;
        if (format == ParagraphFormat.center) {
          hasTargetAlignment = currentF == ParagraphFormat.center || currentF == ParagraphFormat.poemCenter;
        } else if (format == ParagraphFormat.left) {
          hasTargetAlignment = currentF == ParagraphFormat.left || currentF == ParagraphFormat.poemLeft;
        } else {
          hasTargetAlignment = currentF == format;
        }

        if (!hasTargetAlignment) {
          allHaveFormat = false;
          break;
        }
      }

      final ParagraphFormat newFormat = allHaveFormat ? ParagraphFormat.none : format;

      final List<String> updatedLines = [];
      final List<ParagraphFormat> updatedFormats = [];
      int selectionEndShift = 0;

      currentOffset = 0;
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        final lineLen = line.length;
        final lineEnd = currentOffset + lineLen;
        
        final bool isSelected = i >= startLineIdx && i <= endLineIdx;
        ParagraphFormat lineFormat = i < _lineFormats.length ? _lineFormats[i] : ParagraphFormat.none;

        if (isSelected) {
          final isCurrentPoem = lineFormat == ParagraphFormat.poem ||
                                lineFormat == ParagraphFormat.poemCenter ||
                                lineFormat == ParagraphFormat.poemLeft;

          if (isCurrentPoem) {
            if (newFormat == ParagraphFormat.none) {
              lineFormat = ParagraphFormat.poem;
            } else if (newFormat == ParagraphFormat.center) {
              lineFormat = ParagraphFormat.poemCenter;
            } else if (newFormat == ParagraphFormat.left) {
              lineFormat = ParagraphFormat.poemLeft;
            }
          } else {
            lineFormat = newFormat;
          }
        }

        final isPoemLine = lineFormat == ParagraphFormat.poem ||
                           lineFormat == ParagraphFormat.poemCenter ||
                           lineFormat == ParagraphFormat.poemLeft;

        final poemSeparator = RegExp(r'\s*(?:\*\*\*|\*\s+\*\s+\*|\t|\s{3,})\s*');
        if (isPoemLine && line.contains(poemSeparator)) {
          final parts = line.split(poemSeparator).where((p) => p.trim().isNotEmpty).toList();
          if (parts.isNotEmpty) {
            for (int j = 0; j < parts.length; j++) {
              updatedLines.add(parts[j]);
              updatedFormats.add(lineFormat);
            }
            final addedNewlinesCount = parts.length - 1;
            if (sel.end > lineEnd) {
              selectionEndShift += addedNewlinesCount;
            }
          } else {
            updatedLines.add(line);
            updatedFormats.add(lineFormat);
          }
        } else {
          updatedLines.add(line);
          updatedFormats.add(lineFormat);
        }

        currentOffset += lineLen + 1;
      }

      final newText = updatedLines.join('\n');
      _lineFormats = updatedFormats;

      _internalUpdate = true;
      value = value.copyWith(
        text: newText,
        selection: TextSelection(
          baseOffset: sel.baseOffset,
          extentOffset: sel.extentOffset + selectionEndShift,
        ),
      );
      _internalUpdate = false;
      notifyListeners();
    }
  }

  void toggleBoldAtCursor() {
    final currentSel = selection;
    if (!currentSel.isValid) return;

    final content = text;
    int bStart = currentSel.start;
    int bEnd = currentSel.end;

    if (currentSel.isCollapsed) {
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

    _toggleSpan(bStart, bEnd, SpanType.bold);
  }

  void toggleHighlightAtCursor() {
    final currentSel = selection;
    if (!currentSel.isValid) return;

    final content = text;
    int bStart = currentSel.start;
    int bEnd = currentSel.end;

    if (currentSel.isCollapsed) {
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

    _toggleSpan(bStart, bEnd, SpanType.highlight);
  }

  void _toggleSpan(int start, int end, SpanType type) {
    _saveHistoryState();
    final List<StyleSpan> overlapping = _spans.where((s) => s.type == type && s.start < end && s.end > start).toList();
    
    if (overlapping.isNotEmpty) {
      // Toggle OFF: remove style from [start, end]
      final List<StyleSpan> remainingSpans = [];
      for (final span in _spans) {
        if (span.type != type) {
          remainingSpans.add(span);
          continue;
        }
        
        if (span.end <= start || span.start >= end) {
          remainingSpans.add(span);
        } else {
          if (span.start < start) {
            remainingSpans.add(StyleSpan(start: span.start, end: start, type: type));
          }
          if (span.end > end) {
            remainingSpans.add(StyleSpan(start: end, end: span.end, type: type));
          }
        }
      }
      _spans = remainingSpans;
    } else {
      // Prevent overlapping bold and highlight
      final oppositeType = type == SpanType.bold ? SpanType.highlight : SpanType.bold;
      final bool hasOpposite = _spans.any((s) => s.type == oppositeType && s.start < end && s.end > start);
      if (hasOpposite) {
        return;
      }

      // Toggle ON: add style to [start, end] and merge with adjacent/overlapping spans
      final List<StyleSpan> remainingSpans = _spans.where((s) => s.type != type).toList();
      
      int newStart = start;
      int newEnd = end;
      
      for (final span in _spans.where((s) => s.type == type)) {
        if (span.start <= newEnd && span.end >= newStart) {
          if (span.start < newStart) newStart = span.start;
          if (span.end > newEnd) newEnd = span.end;
        } else {
          remainingSpans.add(span);
        }
      }
      
      remainingSpans.add(StyleSpan(start: newStart, end: newEnd, type: type));
      _spans = remainingSpans;
    }
    
    notifyListeners();
  }

  void addSpan(int start, int end, SpanType type) {
    _saveHistoryState();
    // Prevent overlapping bold and highlight
    final oppositeType = type == SpanType.bold ? SpanType.highlight : SpanType.bold;
    final bool hasOpposite = _spans.any((s) => s.type == oppositeType && s.start < end && s.end > start);
    if (hasOpposite) {
      return;
    }

    final List<StyleSpan> remainingSpans = _spans.where((s) => s.type != type).toList();
    
    int newStart = start;
    int newEnd = end;
    
    for (final span in _spans.where((s) => s.type == type)) {
      if (span.start <= newEnd && span.end >= newStart) {
        if (span.start < newStart) newStart = span.start;
        if (span.end > newEnd) newEnd = span.end;
      } else {
        remainingSpans.add(span);
      }
    }
    
    remainingSpans.add(StyleSpan(start: newStart, end: newEnd, type: type));
    _spans = remainingSpans;
    notifyListeners();
  }

  bool _isWordBoundary(String c) {
    return c == ' ' || c == '\n' || c == '\t' || c == '\u2003' || c == '\u200B' || c == '،' || c == '.' || c == '؛';
  }

  // ============================================================
  // buildTextSpan: التزيين البصري الأنيق للوسوم والفقرات داخل المحرر
  // ============================================================

  List<TextSpan> _applySearchHighlight(String segmentText, TextStyle baseStyle, BuildContext context) {
    if (_highlightQuery == null || _highlightQuery!.trim().isEmpty) {
      return [TextSpan(text: segmentText, style: baseStyle)];
    }

    final query = _highlightQuery!.trim();
    final baseWord = query.replaceAll(RegExp(r'[\u064B-\u0652]'), '');
    if (baseWord.isEmpty) {
      return [TextSpan(text: segmentText, style: baseStyle)];
    }

    final regexPattern = baseWord.split('').map((char) => RegExp.escape(char)).join(r'[\u064B-\u0652]*');
    final regex = RegExp(regexPattern, caseSensitive: false);

    final List<TextSpan> spans = [];
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
          backgroundColor: Colors.yellow.withValues(alpha: 0.6),
          color: Colors.black,
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

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final defaultStyle = style ?? const TextStyle();
    final cleanText = text;
    if (cleanText.isEmpty) {
      return TextSpan(text: cleanText, style: defaultStyle);
    }

    final List<TextSpan> lineSpans = [];
    final lines = cleanText.split('\n');
    int currentOffset = 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineStart = currentOffset;
      final lineEnd = currentOffset + line.length;

      // Extract inline spans that overlap with this line range
      final List<StyleSpan> lineInlineSpans = _spans
          .where((s) => s.start < lineEnd && s.end > lineStart)
          .toList();

      // Determine paragraph styling based on format
      final ParagraphFormat format = i < _lineFormats.length ? _lineFormats[i] : ParagraphFormat.none;
      TextStyle paragraphStyle = defaultStyle;

      switch (format) {
        case ParagraphFormat.center:
        case ParagraphFormat.poemCenter:
          paragraphStyle = paragraphStyle.copyWith(
            backgroundColor: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.25) : const Color(0xFFD1FAE5),
            color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857),
            fontWeight: FontWeight.bold,
          );
          break;
        case ParagraphFormat.justify:
          paragraphStyle = paragraphStyle.copyWith(
            backgroundColor: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.15) : const Color(0xFFDBEAFE),
            color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
          );
          break;
        case ParagraphFormat.left:
        case ParagraphFormat.poemLeft:
          paragraphStyle = paragraphStyle.copyWith(
            backgroundColor: isDark ? const Color(0xFF374151).withValues(alpha: 0.25) : const Color(0xFFF3F4F6),
            color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF4B5563),
          );
          break;
        case ParagraphFormat.right:
          paragraphStyle = paragraphStyle.copyWith(
            backgroundColor: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.2) : const Color(0xFFE2E8F0),
          );
          break;
        case ParagraphFormat.poem:
          paragraphStyle = paragraphStyle.copyWith(
            backgroundColor: isDark ? const Color(0xFF4C1D95).withValues(alpha: 0.15) : const Color(0xFFF3E8FF),
            color: isDark ? const Color(0xFFDDD6FE) : const Color(0xFF7C3AED),
            fontStyle: FontStyle.italic,
          );
          break;
        case ParagraphFormat.none:
          break;
      }

      // Build inline spans for this line
      final List<TextSpan> inlineSpansForLine = [];
      int lastLineIndex = 0;

      // Sort spans inside the line by start offset
      lineInlineSpans.sort((a, b) => a.start.compareTo(b.start));

      for (final span in lineInlineSpans) {
        final relStart = (span.start - lineStart).clamp(0, line.length);
        final relEnd = (span.end - lineStart).clamp(0, line.length);

        if (relStart > lastLineIndex) {
          inlineSpansForLine.addAll(_applySearchHighlight(
            line.substring(lastLineIndex, relStart),
            paragraphStyle,
            context,
          ));
        }

        TextStyle spanStyle = paragraphStyle;
        if (span.type == SpanType.bold) {
          spanStyle = spanStyle.copyWith(fontWeight: FontWeight.w900);
        } else if (span.type == SpanType.highlight) {
          spanStyle = spanStyle.copyWith(
            backgroundColor: isDark ? const Color(0xFF78350F).withValues(alpha: 0.6) : const Color(0xFFFEF08A),
            color: isDark ? const Color(0xFFFFFBEB) : const Color(0xFF1E293B),
          );
        }

        if (relEnd > relStart) {
          inlineSpansForLine.addAll(_applySearchHighlight(
            line.substring(relStart, relEnd),
            spanStyle,
            context,
          ));
        }

        lastLineIndex = relEnd;
      }

      if (lastLineIndex < line.length) {
        inlineSpansForLine.addAll(_applySearchHighlight(
          line.substring(lastLineIndex),
          paragraphStyle,
          context,
        ));
      }

      lineSpans.add(TextSpan(
        children: inlineSpansForLine,
      ));

      if (i < lines.length - 1) {
        lineSpans.add(TextSpan(text: '\n', style: defaultStyle));
      }

      currentOffset += line.length + 1;
    }

    return TextSpan(children: lineSpans, style: defaultStyle);
  }
}
