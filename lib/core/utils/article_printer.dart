import 'package:flutter/material.dart' as fm;
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:sijilli/core/providers/settings_provider.dart';
import 'package:sijilli/models/article.dart';

class ArticlePrinter {
  ArticlePrinter._();

  /// Generates a clean A4 PDF of the article text only and opens the native system print dialog.
  static Future<void> printArticle(fm.BuildContext context, Article article, {bool useTwoColumns = false}) async {
    // Detect if the article text contains Arabic characters (defaulting to RTL)
    final bool isArabic = RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]').hasMatch(article.text);

    // 1. Get user's active font from settings
    String selectedFont = 'Default';
    try {
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      selectedFont = settingsProvider.articleFontFamily;
    } catch (e) {
      fm.debugPrint('⚠️ Failed to read articleFontFamily from settings: $e');
    }

    // 2. Load the corresponding PDF font dynamically
    pw.Font arabicFont;
    if (selectedFont == 'Manal High') {
      try {
        final ByteData fontData = await rootBundle.load('assets/fonts/Manal_High.ttf');
        arabicFont = pw.Font.ttf(fontData);
      } catch (e) {
        fm.debugPrint('⚠️ Failed to load Manal_High: $e');
        arabicFont = await _loadFallbackFont();
      }
    } else if (selectedFont == 'Manal Bold') {
      try {
        final ByteData fontData = await rootBundle.load('assets/fonts/Manal_Bold.ttf');
        arabicFont = pw.Font.ttf(fontData);
      } catch (e) {
        fm.debugPrint('⚠️ Failed to load Manal_Bold: $e');
        arabicFont = await _loadFallbackFont();
      }
    } else if (selectedFont == 'Tajawal') {
      try {
        arabicFont = await PdfGoogleFonts.tajawalRegular();
      } catch (e) {
        fm.debugPrint('⚠️ Failed to load Tajawal from Google Fonts: $e');
        arabicFont = await _loadFallbackFont();
      }
    } else if (selectedFont == 'Amiri') {
      try {
        arabicFont = await PdfGoogleFonts.amiriRegular();
      } catch (e) {
        fm.debugPrint('⚠️ Failed to load Amiri from Google Fonts: $e');
        arabicFont = await _loadFallbackFont();
      }
    } else if (selectedFont == 'Al Amiri') {
      try {
        arabicFont = await PdfGoogleFonts.amiriQuranRegular();
      } catch (e) {
        fm.debugPrint('⚠️ Failed to load Amiri Quran from Google Fonts: $e');
        arabicFont = await _loadFallbackFont();
      }
    } else {
      arabicFont = await _loadFallbackFont();
    }

    final List<pw.Font> fontFallbackList = [pw.Font.helvetica()];

    // 4. Trigger print with dynamic PDF generation based on page size selected in system dialog
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async {
        final pdf = pw.Document();
        
        // Define page format: respect selected size but enforce standard 0.75" (54 points) margins
        final pageFormat = format.copyWith(
          marginLeft: 54,
          marginRight: 54,
          marginTop: 54,
          marginBottom: 54,
        );

        pdf.addPage(
          pw.MultiPage(
            pageFormat: pageFormat,
            textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr, // RTL flow for Arabic, LTR for English
            footer: (pw.Context context) {
              final username = article.author?.username ?? '';
              return pw.Container(
                alignment: isArabic ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
                margin: const pw.EdgeInsets.only(top: 10),
                padding: const pw.EdgeInsets.only(top: 5),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    top: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                  ),
                ),
                child: pw.Text(
                  'http://sijilli.com/$username',
                  style: pw.TextStyle(
                    font: pw.Font.helvetica(),
                    fontSize: 9,
                    color: PdfColors.grey600,
                  ),
                ),
              );
            },
            build: (pw.Context context) {
              final title = article.title;
              final articleBodyWidgets = _parseArticleText(
                article.textWithoutTitle,
                arabicFont,
                fontFallbackList,
                useTwoColumns: useTwoColumns,
              );

              if (useTwoColumns && articleBodyWidgets.isNotEmpty) {
                final cols = _splitWidgets(articleBodyWidgets);
                final col1 = cols[0];
                final col2 = cols[1];

                return [
                  // Centered and Bold Title at the top (spans across both columns)
                  pw.Align(
                    alignment: pw.Alignment.center,
                    child: pw.Text(
                      title,
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        font: arabicFont,
                        fontFallback: fontFallbackList,
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey900,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 20),

                  // Two columns layout (partition order is right-to-left for Arabic, left-to-right for English)
                  pw.Partitions(
                    children: [
                      pw.Partition(
                        child: pw.Padding(
                          padding: pw.EdgeInsets.only(left: isArabic ? 10 : 0, right: isArabic ? 0 : 10),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                            children: col1,
                          ),
                        ),
                      ),
                      pw.Partition(
                        child: pw.Padding(
                          padding: pw.EdgeInsets.only(right: isArabic ? 10 : 0, left: isArabic ? 0 : 10),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                            children: col2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ];
              }

              return [
                // Centered and Bold Title at the top
                pw.Align(
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    title,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      font: arabicFont,
                      fontFallback: fontFallbackList,
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey900,
                    ),
                  ),
                ),
                pw.SizedBox(height: 20),

                // Formatted body of the article (excluding the title to prevent duplication)
                ...articleBodyWidgets,
              ];
            },
          ),
        );

        return pdf.save();
      },
      name: 'مقال - ${article.title}',
    );
  }

  /// Helper to split a list of widgets into two balanced columns by character weight.
  static List<List<pw.Widget>> _splitWidgets(List<pw.Widget> widgets) {
    final List<pw.Widget> col1 = [];
    final List<pw.Widget> col2 = [];
    
    int totalLen = 0;
    final List<int> lengths = [];
    
    for (final widget in widgets) {
      int len = 50; // default weight
      if (widget is pw.Text) {
        len = widget.text.text.length;
      } else if (widget is pw.RichText) {
        len = widget.text.toString().length;
      } else if (widget is pw.Paragraph) {
        len = widget.text.text.length;
      } else if (widget is pw.Header) {
        len = widget.text.text.length + 100; // give more weight to headers
      } else if (widget is pw.Container) {
        len = 150; 
      }
      lengths.add(len);
      totalLen += len;
    }
    
    int currentLen = 0;
    int splitIndex = widgets.length ~/ 2;
    
    for (int i = 0; i < widgets.length; i++) {
      currentLen += lengths[i];
      if (currentLen >= totalLen / 2) {
        splitIndex = i;
        break;
      }
    }
    
    if (splitIndex < 0) splitIndex = 0;
    if (splitIndex >= widgets.length) splitIndex = widgets.length - 1;
    
    for (int i = 0; i < widgets.length; i++) {
      if (i <= splitIndex) {
        col1.add(widgets[i]);
      } else {
        col2.add(widgets[i]);
      }
    }
    
    return [col1, col2];
  }

  /// Parses Sijilli markup tags (like [POEM]) and returns a list of PDF widgets.
  static List<pw.Widget> _parseArticleText(String text, pw.Font font, List<pw.Font> fontFallback, {bool useTwoColumns = false}) {
    final List<pw.Widget> widgets = [];
    
    // Clean citations in brackets [...] of diacritics to prevent font rendering/ligature distortion
    final cleanedText = text.replaceAllMapped(RegExp(r'\[([^\]]+?)\]'), (match) {
      final content = match.group(1)!;
      final cleanedContent = content
          .replaceAll('ٱ', 'ا')
          .replaceAll(RegExp(r'[\u064b-\u0652\u0670]'), '');
      return '[$cleanedContent]';
    });

    final poemPattern = RegExp(r'\[POEM\](.*?)\[/POEM\]', dotAll: true, caseSensitive: false);
    int lastMatchEnd = 0;

    for (final match in poemPattern.allMatches(cleanedText)) {
      final preText = cleanedText.substring(lastMatchEnd, match.start).trim();
      if (preText.isNotEmpty) {
        widgets.addAll(_parseParagraphs(preText, font, fontFallback, useTwoColumns: useTwoColumns));
      }

      final poemContent = match.group(1)?.trim() ?? '';
      if (poemContent.isNotEmpty) {
        widgets.add(_buildPdfPoem(poemContent, font, fontFallback, useTwoColumns: useTwoColumns));
      }

      lastMatchEnd = match.end;
    }

    final postText = cleanedText.substring(lastMatchEnd).trim();
    if (postText.isNotEmpty) {
      widgets.addAll(_parseParagraphs(postText, font, fontFallback, useTwoColumns: useTwoColumns));
    }

    if (widgets.isEmpty && cleanedText.isNotEmpty) {
      widgets.addAll(_parseParagraphs(cleanedText, font, fontFallback, useTwoColumns: useTwoColumns));
    }

    return widgets;
  }

  /// Parses regular paragraphs and paragraph alignments.
  static List<pw.Widget> _parseParagraphs(String blockText, pw.Font font, List<pw.Font> fontFallback, {bool useTwoColumns = false}) {
    final List<pw.Widget> widgets = [];
    final lines = blockText.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim().isEmpty) {
        widgets.add(pw.SizedBox(height: 8));
        continue;
      }

      // Detect directionality per line: Arabic right-aligned by default, English left-aligned
      final bool isLineArabic = RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]').hasMatch(line);
      pw.TextAlign textAlign = isLineArabic ? pw.TextAlign.right : pw.TextAlign.left;
      String cleanLine = line.trim();
      final cleanLineUpper = cleanLine.toUpperCase();

      if ((cleanLineUpper.startsWith('[CENTER]') && cleanLineUpper.endsWith('[/CENTER]')) ||
          (cleanLine.startsWith('=') && cleanLine.endsWith('=') && cleanLine.length > 1)) {
        textAlign = pw.TextAlign.center;
        if (cleanLine.startsWith('=')) {
          cleanLine = cleanLine.substring(1, cleanLine.length - 1).trim();
        } else {
          cleanLine = cleanLine.substring('[CENTER]'.length, cleanLine.length - '[/CENTER]'.length).trim();
        }
      } else if ((cleanLineUpper.startsWith('[JUSTIFY]') && cleanLineUpper.endsWith('[/JUSTIFY]')) ||
                 (cleanLine.startsWith('~') && cleanLine.endsWith('~') && cleanLine.length > 1)) {
        textAlign = pw.TextAlign.justify;
        if (cleanLine.startsWith('~')) {
          cleanLine = cleanLine.substring(1, cleanLine.length - 1).trim();
        } else {
          cleanLine = cleanLine.substring('[JUSTIFY]'.length, cleanLine.length - '[/JUSTIFY]'.length).trim();
        }
      } else if ((cleanLineUpper.startsWith('[LEFT]') && cleanLineUpper.endsWith('[/LEFT]')) ||
                 (cleanLine.startsWith('--') && cleanLine.endsWith('--') && cleanLine.length > 3)) {
        textAlign = pw.TextAlign.left;
        if (cleanLine.startsWith('-')) {
          cleanLine = cleanLine.substring(2, cleanLine.length - 2).trim();
        } else {
          cleanLine = cleanLine.substring('[LEFT]'.length, cleanLine.length - '[/LEFT]'.length).trim();
        }
      } else if ((cleanLineUpper.startsWith('[RIGHT]') && cleanLineUpper.endsWith('[/RIGHT]')) ||
                 (cleanLine.startsWith('++') && cleanLine.endsWith('++') && cleanLine.length > 3)) {
        textAlign = pw.TextAlign.right;
        if (cleanLine.startsWith('+')) {
          cleanLine = cleanLine.substring(2, cleanLine.length - 2).trim();
        } else {
          cleanLine = cleanLine.substring('[RIGHT]'.length, cleanLine.length - '[/RIGHT]'.length).trim();
        }
      }

      // Skip media links (images, YouTube embeds) for print rendering
      if (_isMediaLine(cleanLine)) {
        continue;
      }

      final textStyle = pw.TextStyle(
        font: font,
        fontFallback: fontFallback,
        fontSize: useTwoColumns ? 11.0 : 13.0, // slightly smaller font in columns
        height: useTwoColumns ? 1.5 : 1.6,
      );
      final inlineSpans = _parsePdfInlineText(cleanLine, textStyle, font);

      widgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 6.0),
          child: pw.RichText(
            text: pw.TextSpan(children: inlineSpans),
            textAlign: textAlign,
          ),
        ),
      );
    }

    return widgets;
  }

  /// Check if the line is purely media.
  static bool _isMediaLine(String line) {
    final trimmed = line.trim();
    if (trimmed.startsWith('![') && trimmed.endsWith(')')) return true;
    if (trimmed.startsWith('https://') &&
        (trimmed.contains('youtube.com') ||
            trimmed.contains('youtu.be') ||
            trimmed.contains('images.unsplash.com') ||
            trimmed.contains('unsplash.com/photo-'))) {
      return true;
    }
    return false;
  }

  /// Parses inline styling tags ([BOLD], [HIGHLIGHT], markdown links, and URLs) into pw.InlineSpans.
  static List<pw.InlineSpan> _parsePdfInlineText(String text, pw.TextStyle currentStyle, pw.Font font) {
    if (text.isEmpty) return [];

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

    // Clean leftover tags
    String stripTags(String t) {
      return t
          .replaceAll(
              RegExp(r'\[/?(?:BOLD|HIGHLIGHT|B|POEM|CENTER|JUSTIFY|LEFT|RIGHT)/?\]', caseSensitive: false), '')
          .replaceAll(RegExp(r'\[/', caseSensitive: false), '');
    }

    if (earliestMatch == null) {
      return [pw.TextSpan(text: stripTags(text), style: currentStyle)];
    }

    final List<pw.InlineSpan> spans = [];

    if (earliestMatch.start > 0) {
      spans.addAll(_parsePdfInlineText(text.substring(0, earliestMatch.start), currentStyle, font));
    }

    if (earliestType == 1 || earliestType == 2 || earliestType == 4) {
      final innerText = earliestMatch.group(1) ?? '';
      final innerStyle = currentStyle.copyWith(fontWeight: pw.FontWeight.bold);
      spans.addAll(_parsePdfInlineText(innerText, innerStyle, font));
    } else if (earliestType == 3) {
      final innerText = earliestMatch.group(1) ?? '';
      final innerStyle = currentStyle.copyWith(
        background: const pw.BoxDecoration(color: PdfColors.yellow100),
      );
      spans.addAll(_parsePdfInlineText(innerText, innerStyle, font));
    } else if (earliestType == 5) {
      final linkText = earliestMatch.group(1) ?? '';
      final linkUrl = earliestMatch.group(2) ?? '';
      final linkStyle = currentStyle.copyWith(
        color: PdfColors.blue700,
        decoration: pw.TextDecoration.underline,
      );
      spans.add(
        pw.TextSpan(
          text: '$linkText ($linkUrl)',
          style: linkStyle,
        ),
      );
    } else if (earliestType == 6) {
      final linkUrl = earliestMatch.group(0) ?? '';
      final linkStyle = currentStyle.copyWith(
        color: PdfColors.blue700,
        decoration: pw.TextDecoration.underline,
      );
      spans.add(
        pw.TextSpan(
          text: linkUrl,
          style: linkStyle,
        ),
      );
    }

    if (earliestMatch.end < text.length) {
      spans.addAll(_parsePdfInlineText(text.substring(earliestMatch.end), currentStyle, font));
    }

    return spans;
  }

  /// Parses and groups poetry lines inside [POEM] tags, rendering Sadr and Ajez side-by-side
  /// and centering the poem block elegantly on the A4 page.
  static pw.Widget _buildPdfPoem(String poemText, pw.Font font, List<pw.Font> fontFallback, {bool useTwoColumns = false}) {
    final lines = poemText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final List<pw.Widget> poemWidgets = [];

    String? pendingSadr;

    // Helper to justify a single hemistich (Sadr or Ajez) to a fixed column width,
    // scaling it down if the text exceeds the column width to prevent wrapping.
    pw.Widget buildJustifiedPoemLine(String text, pw.TextStyle style, double columnWidth) {
      final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
      if (words.length <= 1) {
        return pw.Text(
          text,
          textAlign: pw.TextAlign.center,
          style: style,
        );
      }

      // Estimate natural width: average Arabic char is ~0.55 of font size in width.
      const double charWidthFactor = 0.55;
      final double estimatedNaturalWidth = text.length * (style.fontSize ?? 10) * charWidthFactor;
      final double targetWidth = estimatedNaturalWidth > columnWidth ? estimatedNaturalWidth : columnWidth;

      return pw.SizedBox(
        width: columnWidth,
        child: pw.FittedBox(
          fit: pw.BoxFit.scaleDown,
          child: pw.SizedBox(
            width: targetWidth,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: words.map((word) => pw.Text(word, style: style)).toList(),
            ),
          ),
        ),
      );
    }

    pw.Widget buildPoemRow(String sadr, String ajez) {
      final style = pw.TextStyle(
        font: font,
        fontFallback: fontFallback,
        fontSize: useTwoColumns ? 8 : 10,
        height: 1.5,
      );
      final double colWidth = useTwoColumns ? 75.0 : 150.0;
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            buildJustifiedPoemLine(sadr, style, colWidth),
            pw.Text(
              '***',
              style: pw.TextStyle(
                font: font,
                fontFallback: fontFallback,
                fontSize: useTwoColumns ? 8 : 10,
                color: PdfColors.grey500,
              ),
            ),
            buildJustifiedPoemLine(ajez, style, colWidth),
          ],
        ),
      );
    }

    pw.Widget buildSinglePoemLine(String line, pw.TextAlign align, bool isCentered) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Align(
          alignment: align == pw.TextAlign.center
              ? pw.Alignment.center
              : (align == pw.TextAlign.left ? pw.Alignment.centerLeft : pw.Alignment.centerRight),
          child: pw.Text(
            line,
            textAlign: align,
            style: pw.TextStyle(
              font: font,
              fontFallback: fontFallback,
              fontSize: useTwoColumns ? 8 : 10,
              height: 1.5,
              fontWeight: isCentered ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ),
      );
    }

    for (final line in lines) {
      final isCentered = (line.toUpperCase().startsWith('[CENTER]') && line.toUpperCase().endsWith('[/CENTER]')) ||
                         (line.startsWith('=') && line.endsWith('=') && line.length > 1);

      String cleanWordCheck = line
          .replaceAll(RegExp(r'\[/?(BOLD|B|HIGHLIGHT|CENTER|JUSTIFY|LEFT|RIGHT)\]', caseSensitive: false), '')
          .replaceAll(RegExp(r'[=~\-\+\*]'), '')
          .trim();
      final isSingleWord = cleanWordCheck.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length <= 1;

      if (isCentered || isSingleWord) {
        if (pendingSadr != null) {
          poemWidgets.add(buildSinglePoemLine(pendingSadr, pw.TextAlign.right, false));
          pendingSadr = null;
        }

        String cleanText = line;
        pw.TextAlign align = pw.TextAlign.center;
        if (isCentered) {
          if (cleanText.startsWith('=')) {
            cleanText = cleanText.substring(1, cleanText.length - 1).trim();
          } else {
            cleanText = cleanText.substring(8, cleanText.length - 9).trim();
          }
        } else {
          if (line.toUpperCase().contains('[LEFT]') || line.startsWith('--')) {
            align = pw.TextAlign.left;
          } else if (line.toUpperCase().contains('[RIGHT]') || line.startsWith('++')) {
            align = pw.TextAlign.right;
          }
          cleanText = cleanWordCheck;
        }

        poemWidgets.add(buildSinglePoemLine(cleanText, align, isCentered));
      } else {
        if (pendingSadr == null) {
          pendingSadr = line;
        } else {
          poemWidgets.add(buildPoemRow(pendingSadr, line));
          pendingSadr = null;
        }
      }
    }

    if (pendingSadr != null) {
      poemWidgets.add(buildSinglePoemLine(pendingSadr, pw.TextAlign.right, false));
    }

    // Centered block with balanced width of 360pt (180pt in two-column mode) to keep Sadr and Ajez columns nicely centered
    // with margins/indentation relative to main paragraphs.
    return pw.Align(
      alignment: pw.Alignment.center,
      child: pw.Container(
        width: useTwoColumns ? 180 : 360,
        margin: const pw.EdgeInsets.symmetric(vertical: 14),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: poemWidgets,
        ),
      ),
    );
  }

  /// Helper to load the fallback font NotoSansArabic from assets or Google Fonts.
  static Future<pw.Font> _loadFallbackFont() async {
    try {
      final ByteData fontData = await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf');
      return pw.Font.ttf(fontData);
    } catch (e) {
      try {
        return await PdfGoogleFonts.notoSansArabicRegular();
      } catch (e2) {
        return pw.Font.helvetica();
      }
    }
  }
}
