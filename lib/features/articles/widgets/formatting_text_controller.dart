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

// ============================================================
// FormattingTextEditingController
// ============================================================

/// `TextEditingController` مخصص يعمل بنظام التحرير المباشر مع التنسيق البصري للوسوم.
/// يتم تخزين النص مع وسومه في الـ `text` مباشرة لتفادي أي مشاكل إزاحة أو مزامنة.
class FormattingTextEditingController extends TextEditingController {
  bool _internalUpdate = false;
  String? _highlightQuery;

  FormattingTextEditingController({String rawText = ''}) {
    text = rawText;
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
        .replaceAll(RegExp(r'\[/?(POEM|CENTER|JUSTIFY|LEFT|RIGHT|B)\]', caseSensitive: false), '')
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
    text = raw;
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

  /// يُطبِّق/يُزيل التعريض (Bold) على الكلمة أو الجزء المحدد
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
    if (selectedText.startsWith('*') && selectedText.endsWith('*') && selectedText.length > 1) {
      // إزالة النجمة
      newText = selectedText.substring(1, selectedText.length - 1);
    } else {
      // إضافة النجمة
      newText = '*$selectedText*';
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
    switch (format) {
      case ParagraphFormat.none:
        return cleanLine;
      case ParagraphFormat.center:
        return '=$cleanLine=';
      case ParagraphFormat.justify:
        return '~$cleanLine~';
      case ParagraphFormat.left:
        return '--$cleanLine--';
      case ParagraphFormat.right:
        return '++$cleanLine++';
      case ParagraphFormat.poem:
        return '[POEM]\n$cleanLine\n[/POEM]';
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
    
    // وسوم رمادية خفيفة
    final tagStyle = defaultStyle.copyWith(
      color: AppColors.getTextPrimary(context).withValues(alpha: 0.35),
      fontSize: 14,
      fontWeight: FontWeight.normal,
    );

    final List<InlineSpan> children = [];

    // التعبيرات المنتظمة لالتقاط الكتل والوسوم
    final pattern = RegExp(
      r'(\[POEM\][\s\S]*?\[/POEM\])'
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

      if (matchedText.startsWith('[POEM]') || matchedText.startsWith('[poem]')) {
        final innerText = matchedText.substring(6, matchedText.length - 7);
        children.add(TextSpan(text: '[POEM]', style: tagStyle));
        children.addAll(_buildHighlightedSpans(
          innerText,
          defaultStyle.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.primary.withValues(alpha: 0.85),
            fontStyle: FontStyle.italic,
          ),
          context,
        ));
        children.add(TextSpan(text: '[/POEM]', style: tagStyle));
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
