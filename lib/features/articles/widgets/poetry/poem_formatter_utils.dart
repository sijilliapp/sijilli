import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';
import '../../../../core/constants/app_colors.dart';

class PoemFormatterUtils {
  static const String poemTagStart = '[POEM]';
  static const String poemTagEnd = '[/POEM]';
  static const String centerTagStart = '[CENTER]';
  static const String centerTagEnd = '[/CENTER]';
  static const String justifyTagStart = '[JUSTIFY]';
  static const String justifyTagEnd = '[/JUSTIFY]';

  /// Formats raw text by wrapping it in [POEM] tags.
  static String formatAsPoem(String rawText) {
    if (rawText.trim().isEmpty) return '';
    final cleanText = rawText.trim();
    
    // If already wrapped in poem tags, toggle it off (unwrap)
    if (cleanText.startsWith(poemTagStart) && cleanText.endsWith(poemTagEnd)) {
      return cleanText.substring(poemTagStart.length, cleanText.length - poemTagEnd.length).trim();
    }
    
    return '$poemTagStart\n$cleanText\n$poemTagEnd';
  }

  /// Toggles center alignment tags on each line of the raw text.
  static String toggleCenterAlignment(String rawText) {
    if (rawText.isEmpty) return '';
    final lines = rawText.split('\n');
    final formattedLines = lines.map((line) {
      final cleanLine = line.trim();
      
      // التحقق إذا كان السطر يحتوي بالفعل على علامات توسيط
      if (cleanLine.startsWith(centerTagStart) && cleanLine.endsWith(centerTagEnd)) {
        // إزالة علامات التوسيط
        return cleanLine.substring(centerTagStart.length, cleanLine.length - centerTagEnd.length);
      } else {
        // إزالة أي علامات تنسيق موجودة أولاً
        String stripped = cleanLine;
        
        // إزالة علامات ضبط النص إذا كانت موجودة
        if (stripped.startsWith(justifyTagStart) && stripped.endsWith(justifyTagEnd)) {
          stripped = stripped.substring(justifyTagStart.length, stripped.length - justifyTagEnd.length);
        }
        
        // إضافة علامات التوسيط
        return '$centerTagStart$stripped$centerTagEnd';
      }
    }).toList();
    return formattedLines.join('\n');
  }

  /// Toggles justify alignment tags on each line of the raw text.
  static String toggleJustifyAlignment(String rawText) {
    if (rawText.isEmpty) return '';
    final lines = rawText.split('\n');
    final formattedLines = lines.map((line) {
      final cleanLine = line.trim();
      if (cleanLine.startsWith(justifyTagStart) && cleanLine.endsWith(justifyTagEnd)) {
        // Toggle justify off
        return cleanLine.substring(justifyTagStart.length, cleanLine.length - justifyTagEnd.length);
      } else {
        // Remove center tags if present, and add justify tags
        String stripped = cleanLine;
        if (stripped.startsWith(centerTagStart) && stripped.endsWith(centerTagEnd)) {
          stripped = stripped.substring(centerTagStart.length, stripped.length - centerTagEnd.length);
        }
        return '$justifyTagStart$stripped$justifyTagEnd';
      }
    }).toList();
    return formattedLines.join('\n');
  }

  static String _stripLeftoverTags(String text) {
    return text
        .replaceAll(RegExp(r'\[/?(?:BOLD|HIGHLIGHT|B|POEM|CENTER|JUSTIFY|LEFT|RIGHT|AUDIO(?:_[^\]]+|:\s*[^\]]+)?)/?\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[/', caseSensitive: false), '');
  }

  /// Recursively parses formatting tags and returns a list of styled spans.
  static List<InlineSpan> parseInlineText(String text, TextStyle currentStyle, BuildContext context) {
    if (text.isEmpty) return [];

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final highlightBg = isDark ? const Color(0xFF78350F).withValues(alpha: 0.5) : const Color(0xFFFEF08A);
    final highlightText = isDark ? const Color(0xFFFFFBEB) : const Color(0xFF1E293B);

    final boldRegex = RegExp(r'\[BOLD\](.*?)\[(?:/BOLD|BOLD/)\]', caseSensitive: false, dotAll: true);
    final bRegex = RegExp(r'\[B\](.*?)\[(?:/B|B/)\]', caseSensitive: false, dotAll: true);
    final highlightRegex = RegExp(r'\[HIGHLIGHT\](.*?)\[(?:/HIGHLIGHT|HIGHLIGHT/)\]', caseSensitive: false, dotAll: true);
    final starRegex = RegExp(r'\*(.*?)\*', caseSensitive: false, dotAll: true);
    final mdLinkRegex = RegExp(r'\[([^\]]+?)\]\((https?:\/\/[^\s\)]+?)\)', caseSensitive: false);
    final plainUrlRegex = RegExp(r'(https?:\/\/[^\s\)]+)', caseSensitive: false);

    Match? earliestMatch;
    int earliestType = 0; // 1: BOLD, 2: B, 3: HIGHLIGHT, 4: *, 5: MD_LINK, 6: PLAIN_URL

    final boldMatch = boldRegex.firstMatch(text);
    if (boldMatch != null) {
      earliestMatch = boldMatch;
      earliestType = 1;
    }

    final bMatch = bRegex.firstMatch(text);
    if (bMatch != null && (earliestMatch == null || bMatch.start < earliestMatch.start)) {
      earliestMatch = bMatch;
      earliestType = 2;
    }

    final highlightMatch = highlightRegex.firstMatch(text);
    if (highlightMatch != null && (earliestMatch == null || highlightMatch.start < earliestMatch.start)) {
      earliestMatch = highlightMatch;
      earliestType = 3;
    }

    final starMatch = starRegex.firstMatch(text);
    if (starMatch != null && (earliestMatch == null || starMatch.start < earliestMatch.start)) {
      earliestMatch = starMatch;
      earliestType = 4;
    }

    final mdLinkMatch = mdLinkRegex.firstMatch(text);
    if (mdLinkMatch != null && (earliestMatch == null || mdLinkMatch.start < earliestMatch.start)) {
      earliestMatch = mdLinkMatch;
      earliestType = 5;
    }

    final plainUrlMatch = plainUrlRegex.firstMatch(text);
    if (plainUrlMatch != null && (earliestMatch == null || plainUrlMatch.start < earliestMatch.start)) {
      earliestMatch = plainUrlMatch;
      earliestType = 6;
    }

    if (earliestMatch == null) {
      return [TextSpan(text: _stripLeftoverTags(text), style: currentStyle)];
    }

    final List<InlineSpan> spans = [];

    if (earliestMatch.start > 0) {
      spans.addAll(parseInlineText(text.substring(0, earliestMatch.start), currentStyle, context));
    }

    if (earliestType == 1 || earliestType == 2 || earliestType == 4) {
      final innerText = earliestMatch.group(1) ?? '';
      final innerStyle = currentStyle.copyWith(fontWeight: FontWeight.w900); // Super bold for maximum contrast against w600 base
      spans.addAll(parseInlineText(innerText, innerStyle, context));
    } else if (earliestType == 3) {
      final innerText = earliestMatch.group(1) ?? '';
      final innerStyle = currentStyle.copyWith(
        backgroundColor: highlightBg,
        color: highlightText,
      );
      spans.addAll(parseInlineText(innerText, innerStyle, context));
    } else if (earliestType == 5) {
      final linkText = earliestMatch.group(1) ?? '';
      final linkUrl = earliestMatch.group(2) ?? '';
      final linkStyle = currentStyle.copyWith(
        color: AppColors.primary,
        decoration: TextDecoration.underline,
      );
      spans.add(
        TextSpan(
          children: parseInlineText(linkText, linkStyle, context),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              _showLeaveAppDialog(context, linkUrl);
            },
        ),
      );
    } else if (earliestType == 6) {
      final linkUrl = earliestMatch.group(0) ?? '';
      final linkStyle = currentStyle.copyWith(
        color: AppColors.primary,
        decoration: TextDecoration.underline,
      );
      spans.add(
        TextSpan(
          text: linkUrl,
          style: linkStyle,
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              _showLeaveAppDialog(context, linkUrl);
            },
        ),
      );
    }

    if (earliestMatch.end < text.length) {
      spans.addAll(parseInlineText(text.substring(earliestMatch.end), currentStyle, context));
    }

    return spans;
  }

  static void _showLeaveAppDialog(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(context.l10n.leaveAppDialogTitle),
          content: Text(context.l10n.leaveAppDialogMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.l10n.no),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                try {
                  final uri = Uri.parse(url);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                } catch (e) {
                  debugPrint('Could not launch URL: $e');
                }
              },
              child: Text(
                context.l10n.yes,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Flattens and splits inline spans into individual styled word spans.
  static List<InlineSpan> splitSpansIntoWords(List<InlineSpan> spans) {
    final List<TextSpan> leafSpans = [];
    
    void collectLeaves(InlineSpan span, TextStyle? activeStyle) {
      if (span is TextSpan) {
        final combinedStyle = activeStyle == null ? span.style : activeStyle.merge(span.style);
        if (span.text != null && span.text!.isNotEmpty) {
          leafSpans.add(TextSpan(text: span.text, style: combinedStyle));
        }
        if (span.children != null) {
          for (final child in span.children!) {
            collectLeaves(child, combinedStyle);
          }
        }
      }
    }

    for (final span in spans) {
      collectLeaves(span, null);
    }

    final List<InlineSpan> wordSpans = [];
    for (final leaf in leafSpans) {
      final text = leaf.text ?? '';
      final style = leaf.style;
      final parts = text.split(RegExp(r'\s+'));
      for (final part in parts) {
        if (part.isNotEmpty) {
          wordSpans.add(TextSpan(text: part, style: style));
        }
      }
    }
    return wordSpans;
  }
}
