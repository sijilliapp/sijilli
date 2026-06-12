import 'package:flutter/material.dart' as fm;
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:sijilli/core/providers/settings_provider.dart';
import 'package:sijilli/models/article.dart';
import 'package:sijilli/core/utils/bidi_utils.dart';

class ArticlePrinter {
  ArticlePrinter._();

  /// Generates a clean A4 PDF of the article text only and opens the native system print dialog.
  static Future<void> printArticle(fm.BuildContext context, Article article, {bool useTwoColumns = false}) async {
    // Detect if the article text is RTL (Arabic)
    final bool isArabic = BidiUtils.isRtl(article.text);

    // 1. Get user's active font from settings
    String selectedFont = 'Default';
    try {
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      selectedFont = settingsProvider.articleFontFamily;
    } catch (e) {
      fm.debugPrint('⚠️ Failed to read articleFontFamily from settings: $e');
    }

    // 2. Load the corresponding PDF font dynamically
    // Note: Custom local fonts like 'Manal High' and 'Manal Bold' do not contain standard
    // GSUB/GPOS shaping tables compatible with PDF viewers, which causes Arabic letters to
    // render disconnected in the printed PDFs. We fall back to the bundled,
    // print-compatible 'NotoSansArabic-Regular.ttf' font for these styles.
    pw.Font arabicFont;
    if (selectedFont == 'Manal High' || selectedFont == 'Manal Bold') {
      arabicFont = await _loadFallbackFont();
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
                    font: pw.Font.helveticaOblique(),
                    fontSize: 9,
                    color: PdfColors.grey600,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              );
            },
            build: (pw.Context context) {
              final double printableWidth = pageFormat.width - pageFormat.marginLeft - pageFormat.marginRight;
              final double columnWidth = useTwoColumns 
                  ? (((printableWidth / 2) - 32) > 0 ? ((printableWidth / 2) - 32) : 200.0)
                  : ((printableWidth - 40) > 0 ? (printableWidth - 40) : 360.0);

              final articleBodyWidgets = _parseArticleText(
                article.text,
                arabicFont,
                fontFallbackList,
                columnWidth: columnWidth,
                useTwoColumns: useTwoColumns,
              );

              if (useTwoColumns && articleBodyWidgets.isNotEmpty) {
                final double printableHeight = pageFormat.height - pageFormat.marginTop - pageFormat.marginBottom - 20; // 20pt buffer for margins/footer
                final double colWidth = (pageFormat.width - pageFormat.marginLeft - pageFormat.marginRight) / 2;
                return _flowColumns(articleBodyWidgets, printableHeight, colWidth, isArabic);
              }

              return articleBodyWidgets;
            },
          ),
        );

        return pdf.save();
      },
      name: 'مقال - ${article.title}',
    );
  }

  /// Natural multi-column layout flow simulation across pages.
  static List<pw.Widget> _flowColumns(List<pw.Widget> widgets, double pageHeight, double columnWidth, bool isArabic) {
    final List<pw.Widget> pages = [];
    
    List<pw.Widget> currentPageCol1 = [];
    List<pw.Widget> currentPageCol2 = [];
    
    double currentCol1Height = 0;
    double currentCol2Height = 0;
    
    for (final widget in widgets) {
      final double widgetHeight = _estimateWidgetHeight(widget, columnWidth);
      
      // Fallback if the widget is larger than the column height itself
      if (widgetHeight > pageHeight) {
        if (currentCol1Height == 0) {
          currentPageCol1.add(widget);
          currentCol1Height += widgetHeight;
        } else if (currentCol2Height == 0) {
          currentPageCol2.add(widget);
          currentCol2Height += widgetHeight;
        } else {
          pages.add(_buildPagePartitions(currentPageCol1, currentPageCol2, isArabic));
          currentPageCol1 = [widget];
          currentPageCol2 = [];
          currentCol1Height = widgetHeight;
          currentCol2Height = 0;
        }
      }
      // Fit in Column 1
      else if (currentCol1Height + widgetHeight <= pageHeight) {
        currentPageCol1.add(widget);
        currentCol1Height += widgetHeight;
      }
      // Fit in Column 2
      else if (currentCol2Height + widgetHeight <= pageHeight) {
        currentPageCol2.add(widget);
        currentCol2Height += widgetHeight;
      }
      // Spill over to next page
      else {
        pages.add(_buildPagePartitions(currentPageCol1, currentPageCol2, isArabic));
        currentPageCol1 = [widget];
        currentPageCol2 = [];
        currentCol1Height = widgetHeight;
        currentCol2Height = 0;
      }
    }
    
    if (currentPageCol1.isNotEmpty || currentPageCol2.isNotEmpty) {
      pages.add(_buildPagePartitions(currentPageCol1, currentPageCol2, isArabic));
    }
    
    return pages;
  }

  /// Builds a single page layout using pw.Partitions (RTL order for Arabic).
  static pw.Widget _buildPagePartitions(List<pw.Widget> col1, List<pw.Widget> col2, bool isArabic) {
    return pw.Partitions(
      children: [
        pw.Partition(
          child: pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 16),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: isArabic ? col2 : col1,
            ),
          ),
        ),
        pw.Partition(
          child: pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 16),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: isArabic ? col1 : col2,
            ),
          ),
        ),
      ],
    );
  }

  /// Estimates the visual height of a widget in points.
  static double _estimateWidgetHeight(pw.Widget widget, double columnWidth) {
    if (widget is pw.SizedBox) {
      return widget.height ?? 0.0;
    }
    if (widget is pw.Divider) {
      return widget.thickness ?? 0.5;
    }
    if (widget is pw.Column) {
      double total = 0.0;
      for (final child in widget.children) {
        total += _estimateWidgetHeight(child, columnWidth);
      }
      return total;
    }
    if (widget is pw.Padding) {
      final child = widget.child;
      if (child == null) return widget.padding.vertical;
      final verticalPadding = widget.padding.vertical;
      
      if (child is pw.RichText) {
        final text = _getSpanText(child.text);
        final double textWidth = columnWidth - widget.padding.horizontal;
        // Average char width factor for Arabic/English is ~0.55 of font size (11.0)
        final double charsPerLine = textWidth > 0 ? (textWidth / 6.05) : 35.0;
        
        final lines = text.split('\n');
        double totalLines = 0.0;
        for (final line in lines) {
          if (line.isEmpty) {
            totalLines += 1.0;
          } else {
            totalLines += (line.length / charsPerLine).ceil();
          }
        }
        return (totalLines * 11.0 * 1.5) + verticalPadding;
      }
      
      if (child is pw.Align) {
        final alignChild = child.child;
        if (alignChild is pw.SizedBox || alignChild is pw.Container) {
          // Standard poem line (Sadr & Ajez Row or standalone line)
          final double lineFontSize = 11.5;
          final double lineHeight = 1.5;
          return (lineFontSize * lineHeight) + verticalPadding;
        }
      }

      if (child is pw.Divider) {
        return (child.thickness ?? 0.5) + verticalPadding;
      }

      if (child is pw.SizedBox) {
        return (child.height ?? 0.0) + verticalPadding;
      }
      
      return _estimateWidgetHeight(child, columnWidth) + verticalPadding;
    }
    
    return 40.0;
  }

  static String _getSpanText(pw.InlineSpan span) {
    if (span is pw.TextSpan) {
      final buffer = StringBuffer();
      if (span.text != null) {
        buffer.write(span.text);
      }
      if (span.children != null) {
        for (final child in span.children!) {
          buffer.write(_getSpanText(child));
        }
      }
      return buffer.toString();
    }
    return '';
  }

  /// Parses Sijilli markup tags (like [POEM]) and returns a list of PDF widgets.
  static List<pw.Widget> _parseArticleText(
    String text,
    pw.Font font,
    List<pw.Font> fontFallback, {
    required double columnWidth,
    required bool useTwoColumns,
  }) {
    final List<pw.Widget> widgets = [];
    
    // Strip markdown images: ![alt](url)
    final textWithoutMarkdownImages = text.replaceAll(RegExp(r'!\[.*?\]\(.*?\)'), '');

    // Clean citations in brackets [...] of diacritics to prevent font rendering/ligature distortion
    final cleanedText = textWithoutMarkdownImages.replaceAllMapped(RegExp(r'\[([^\]]+?)\]'), (match) {
      final content = match.group(1)!;
      final cleanedContent = content
          .replaceAll('ٱ', 'ا')
          .replaceAll(RegExp(r'[\u064b-\u0652\u0670]'), '');
      return '[$cleanedContent]';
    });

    final poemPattern = RegExp(r'\[POEM(?:\s+TYPE="([^"]+?)")?\](.*?)\[/POEM\]', dotAll: true, caseSensitive: false);
    int lastMatchEnd = 0;

    for (final match in poemPattern.allMatches(cleanedText)) {
      final preText = cleanedText.substring(lastMatchEnd, match.start).trim();
      if (preText.isNotEmpty) {
        widgets.addAll(_parseParagraphs(preText, font, fontFallback, useTwoColumns: useTwoColumns));
      }

      final type = match.group(1)?.toUpperCase() ?? 'STANDARD';
      final poemContent = match.group(2)?.trim() ?? '';
      if (poemContent.isNotEmpty) {
        widgets.addAll(_buildPdfPoem(
          poemContent,
          font,
          fontFallback,
          columnWidth: columnWidth,
          useTwoColumns: useTwoColumns,
          type: type,
        ));
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
          child: pw.SizedBox(
            width: double.infinity,
            child: pw.Directionality(
              textDirection: isLineArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
              child: pw.RichText(
                text: pw.TextSpan(children: inlineSpans),
                textAlign: textAlign,
              ),
            ),
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
    if (trimmed.contains('/api/files/')) return true;

    final lower = trimmed.toLowerCase();
    if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.bmp')) {
      return true;
    }

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

  /// Parses and groups poetry lines inside [POEM] tags, rendering Sadr and Ajez as individual
  /// page-breakable elements with a dynamic side-by-side or intertwined layout (matching the screen view).
  static List<pw.Widget> _buildPdfPoem(
    String poemText,
    pw.Font font,
    List<pw.Font> fontFallback, {
    required double columnWidth,
    required bool useTwoColumns,
    required String type,
  }) {
    final lines = poemText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final List<pw.Widget> blocks = [];
    final bool isRtl = BidiUtils.isRtl(poemText);

    final double fontSize = useTwoColumns ? 10.5 : 11.5;
    final style = pw.TextStyle(
      font: font,
      fontFallback: fontFallback,
      fontSize: fontSize,
      height: 1.5,
    );

    // Helper to clean formatting and alignment tags from the hemistich for width estimation
    String cleanTextForEstimation(String text) {
      String cleanText = text;
      if ((cleanText.startsWith('=') && cleanText.endsWith('=')) ||
          (cleanText.startsWith('~') && cleanText.endsWith('~'))) {
        if (cleanText.length > 1) cleanText = cleanText.substring(1, cleanText.length - 1).trim();
      } else if ((cleanText.startsWith('--') && cleanText.endsWith('--')) ||
                 (cleanText.startsWith('++') && cleanText.endsWith('++'))) {
        if (cleanText.length > 3) cleanText = cleanText.substring(2, cleanText.length - 2).trim();
      }
      return cleanText
          .replaceAll(RegExp(r'\[/?(BOLD|B|HIGHLIGHT|CENTER|JUSTIFY|LEFT|RIGHT)\]', caseSensitive: false), '')
          .trim();
    }

    // Helper to estimate the natural width of a hemistich
    double estimateWidth(String text) {
      final cleaned = cleanTextForEstimation(text);
      if (cleaned.isEmpty) return 0.0;
      final bool isArabic = BidiUtils.isRtl(cleaned);
      final double charWidthFactor = isArabic ? 0.45 : 0.52;
      return cleaned.length * fontSize * charWidthFactor;
    }

    // Parse the poem lines into local data structures
    final List<_PdfPoemItem> items = [];

    if (type == 'TAKHMEES') {
      for (int i = 0; i < lines.length; i += 5) {
        final remaining = lines.length - i;
        if (remaining >= 5) {
          items.add(_PdfPoemVerse(lines[i], lines[i + 1]));
          items.add(_PdfPoemVerse(lines[i + 2], lines[i + 3], isAjezBold: true));
          items.add(_PdfPoemStandalone(
            lines[i + 4],
            isCentered: true,
            isLeftAligned: false,
            isRightAligned: false,
            isBold: true,
            hasDividerBelow: true,
            hasSpacingBelow: true,
          ));
        } else if (remaining == 4) {
          items.add(_PdfPoemVerse(lines[i], lines[i + 1]));
          items.add(_PdfPoemVerse(lines[i + 2], lines[i + 3], isAjezBold: true));
        } else if (remaining == 3) {
          items.add(_PdfPoemVerse(lines[i], lines[i + 1]));
          items.add(_PdfPoemStandalone(
            lines[i + 2],
            isCentered: true,
            isLeftAligned: false,
            isRightAligned: false,
            isBold: true,
            hasDividerBelow: true,
            hasSpacingBelow: true,
          ));
        } else if (remaining == 2) {
          items.add(_PdfPoemVerse(lines[i], lines[i + 1]));
        } else if (remaining == 1) {
          items.add(_PdfPoemStandalone(
            lines[i],
            isCentered: true,
            isLeftAligned: false,
            isRightAligned: false,
            isBold: true,
            hasDividerBelow: true,
            hasSpacingBelow: true,
          ));
        }
      }
    } else {
      // Standard parsing loop
      String? pendingSadr;
      for (final line in lines) {
        final isCentered = (line.toUpperCase().startsWith('[CENTER]') && line.toUpperCase().endsWith('[/CENTER]')) ||
                           (line.startsWith('=') && line.endsWith('=') && line.length > 1);

        String cleanLineForWordCheck = line;
        if ((cleanLineForWordCheck.startsWith('=') && cleanLineForWordCheck.endsWith('=')) ||
            (cleanLineForWordCheck.startsWith('~') && cleanLineForWordCheck.endsWith('~'))) {
          if (cleanLineForWordCheck.length > 1) {
            cleanLineForWordCheck = cleanLineForWordCheck.substring(1, cleanLineForWordCheck.length - 1).trim();
          }
        } else if ((cleanLineForWordCheck.startsWith('--') && cleanLineForWordCheck.endsWith('--')) ||
                   (cleanLineForWordCheck.startsWith('++') && cleanLineForWordCheck.endsWith('++'))) {
          if (cleanLineForWordCheck.length > 3) {
            cleanLineForWordCheck = cleanLineForWordCheck.substring(2, cleanLineForWordCheck.length - 2).trim();
          }
        }
        cleanLineForWordCheck = cleanLineForWordCheck
            .replaceAll(RegExp(r'\[/?(BOLD|B|HIGHLIGHT|CENTER|JUSTIFY|LEFT|RIGHT)\]', caseSensitive: false), '')
            .trim();
        final words = cleanLineForWordCheck.split(RegExp(r'\s+')).where((w) => w.trim().isNotEmpty).toList();
        final isSingleWord = words.length <= 1;

        if (isCentered || isSingleWord) {
          if (pendingSadr != null) {
            items.add(_PdfPoemVerse(pendingSadr, ''));
            pendingSadr = null;
          }
          final isLeftAligned = line.toUpperCase().contains('[LEFT]') || line.startsWith('--');
          final isRightAligned = line.toUpperCase().contains('[RIGHT]') || line.startsWith('++');
          items.add(_PdfPoemStandalone(line, isCentered: isCentered, isLeftAligned: isLeftAligned, isRightAligned: isRightAligned));
        } else {
          if (pendingSadr == null) {
            pendingSadr = line;
          } else {
            items.add(_PdfPoemVerse(pendingSadr, line));
            pendingSadr = null;
          }
        }
      }
      if (pendingSadr != null) {
        items.add(_PdfPoemVerse(pendingSadr, ''));
      }

      // Post-process styling for TASHTEER and TARBEE
      if (type == 'TASHTEER') {
        int verseIndex = 0;
        for (int k = 0; k < items.length; k++) {
          final item = items[k];
          if (item is _PdfPoemVerse) {
            final isEven = verseIndex % 2 == 0;
            items[k] = _PdfPoemVerse(
              item.sadr,
              item.ajez,
              isSadrBold: isEven,
              isAjezBold: !isEven,
            );
            verseIndex++;
          }
        }
      } else if (type == 'TARBEE') {
        int verseIndex = 0;
        for (int k = 0; k < items.length; k++) {
          final item = items[k];
          if (item is _PdfPoemVerse) {
            final isLastInStanza = verseIndex % 2 == 1;
            items[k] = _PdfPoemVerse(
              item.sadr,
              item.ajez,
              isSadrBold: false,
              isAjezBold: isLastInStanza,
              hasDividerBelow: isLastInStanza,
              hasSpacingBelow: isLastInStanza,
            );
            verseIndex++;
          }
        }
      }
    }

    // Measure estimated widths of Sadr, Ajez, and Centered text
    double maxSadrWidth = 0.0;
    double maxAjezWidth = 0.0;
    double maxCenteredWidth = 0.0;

    for (final item in items) {
      if (item is _PdfPoemStandalone && item.isCentered) {
        final w = estimateWidth(item.text);
        if (w > maxCenteredWidth) maxCenteredWidth = w;
      } else if (item is _PdfPoemVerse) {
        if (item.sadr.isNotEmpty) {
          final w = estimateWidth(item.sadr);
          if (w > maxSadrWidth) maxSadrWidth = w;
        }
        if (item.ajez.isNotEmpty) {
          final w = estimateWidth(item.ajez);
          if (w > maxAjezWidth) maxAjezWidth = w;
        }
      }
    }

    // Check if the poem should use intertwined layout because Sadr/Ajez are too long for side-by-side
    // We use the actual dynamic columnWidth passed from onLayout
    final double maxAllowedWidth = columnWidth;
    final double maxHalfWidth = maxSadrWidth > maxAjezWidth ? maxSadrWidth : maxAjezWidth;
    const double middleGap = 32.0;

    final bool shouldIntertwine = maxHalfWidth > (maxAllowedWidth - middleGap) / 2;

    double containerWidth;
    double finalSadrWidth;
    double finalAjezWidth;

    if (shouldIntertwine) {
      // Intertwined layout: Sadr and Ajez overlap, taking maximum allowed width
      finalSadrWidth = maxHalfWidth > maxAllowedWidth ? maxAllowedWidth : maxHalfWidth;
      finalAjezWidth = finalSadrWidth;
      const double overlapPixels = 40.0;
      containerWidth = finalSadrWidth + finalAjezWidth - overlapPixels;
    } else {
      // Side-by-side layout: Sadr and Ajez fit next to each other
      finalSadrWidth = maxHalfWidth;
      finalAjezWidth = maxHalfWidth;
      containerWidth = maxHalfWidth * 2 + middleGap;
    }

    final double finalCenteredWidth = maxCenteredWidth > maxAllowedWidth ? maxAllowedWidth : maxCenteredWidth;
    if (containerWidth < finalCenteredWidth) {
      containerWidth = finalCenteredWidth;
    }

    if (containerWidth < maxAllowedWidth * 0.5) containerWidth = maxAllowedWidth * 0.5;
    if (containerWidth > maxAllowedWidth) containerWidth = maxAllowedWidth;

    // Helper to build a clean single hemistich (Sadr or Ajez) to a fixed column width,
    // scaling it down if the text exceeds the column width to prevent wrapping,
    // without introducing artificial spacing between words.
    pw.Widget buildPoemLine(String text, pw.TextStyle style, double width, pw.Alignment alignment) {
      final cleanedText = cleanTextForEstimation(text);
      return pw.Container(
        width: width,
        alignment: alignment,
        child: pw.FittedBox(
          fit: pw.BoxFit.scaleDown,
          alignment: alignment,
          child: pw.Text(
            cleanedText,
            style: style,
          ),
        ),
      );
    }

    // Helper to justify a single hemistich (Sadr or Ajez) to a fixed column width,
    // scaling it down if the text exceeds the column width to prevent wrapping.
    pw.Widget buildJustifiedPoemLine(String text, pw.TextStyle style, double columnWidth) {
      final cleanedText = cleanTextForEstimation(text);
      final words = cleanedText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
      if (words.isEmpty) {
        return pw.SizedBox(width: columnWidth);
      }
      if (words.length == 1) {
        return pw.Container(
          width: columnWidth,
          alignment: pw.Alignment.center,
          child: pw.Text(
            words.first,
            style: style,
          ),
        );
      }

      final bool isArabic = BidiUtils.isRtl(cleanedText);
      final double charWidthFactor = isArabic ? 0.45 : 0.52;
      final double estimatedNaturalWidth = cleanedText.length * (style.fontSize ?? fontSize) * charWidthFactor;
      final double targetWidth = estimatedNaturalWidth > columnWidth ? estimatedNaturalWidth : columnWidth;

      return pw.SizedBox(
        width: columnWidth,
        child: pw.FittedBox(
          fit: pw.BoxFit.scaleDown,
          child: pw.SizedBox(
            width: targetWidth,
            child: pw.Directionality(
              textDirection: isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: words.map((word) => pw.Text(word, style: style)).toList(),
              ),
            ),
          ),
        ),
      );
    }

    // Helper to render a verse (Sadr & Ajez)
    List<pw.Widget> renderVerse(
      String sadr,
      String ajez,
      bool isSadrBold,
      bool isAjezBold, {
      bool hasDivider = false,
      bool hasSpacing = false,
    }) {
      final List<pw.Widget> list = [];
      if (shouldIntertwine) {
        if (sadr.isNotEmpty) {
          list.add(
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 3),
              child: pw.Align(
                alignment: pw.Alignment.center,
                child: pw.Container(
                  width: containerWidth,
                  alignment: isRtl ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
                  child: buildPoemLine(
                    sadr,
                    isSadrBold ? style.copyWith(fontWeight: pw.FontWeight.bold) : style,
                    finalSadrWidth,
                    isRtl ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
                  ),
                ),
              ),
            ),
          );
        }
        if (ajez.isNotEmpty) {
          list.add(
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 3),
              child: pw.Align(
                alignment: pw.Alignment.center,
                child: pw.Container(
                  width: containerWidth,
                  alignment: isRtl ? pw.Alignment.centerLeft : pw.Alignment.centerRight,
                  child: buildPoemLine(
                    ajez,
                    isAjezBold ? style.copyWith(fontWeight: pw.FontWeight.bold) : style,
                    finalAjezWidth,
                    isRtl ? pw.Alignment.centerLeft : pw.Alignment.centerRight,
                  ),
                ),
              ),
            ),
          );
        }
      } else {
        list.add(
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 3),
            child: pw.Align(
              alignment: pw.Alignment.center,
              child: pw.SizedBox(
                width: containerWidth,
                child: pw.Directionality(
                  textDirection: isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      buildJustifiedPoemLine(
                        sadr,
                        isSadrBold ? style.copyWith(fontWeight: pw.FontWeight.bold) : style,
                        finalSadrWidth,
                      ),
                      buildJustifiedPoemLine(
                        ajez,
                        isAjezBold ? style.copyWith(fontWeight: pw.FontWeight.bold) : style,
                        finalAjezWidth,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }

      if (hasDivider) {
        list.add(
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 8),
            child: pw.Divider(thickness: 0.5, color: PdfColors.grey400),
          ),
        );
      }
      if (hasSpacing) {
        list.add(pw.SizedBox(height: 8));
      }

      return list;
    }

    // Helper to render a standalone line
    List<pw.Widget> renderStandalone(
      String text,
      bool isCentered,
      bool isBold, {
      bool hasDivider = false,
      bool hasSpacing = false,
      bool isLeftAligned = false,
      bool isRightAligned = false,
    }) {
      final List<pw.Widget> list = [];
      String cleanText = text;
      pw.TextAlign align = pw.TextAlign.center;
      if (isCentered) {
        if (cleanText.toUpperCase().startsWith('[CENTER]') && cleanText.toUpperCase().endsWith('[/CENTER]')) {
          cleanText = cleanText.substring(8, cleanText.length - 9).trim();
        } else if (cleanText.startsWith('=') && cleanText.endsWith('=')) {
          cleanText = cleanText.substring(1, cleanText.length - 1).trim();
        }
      } else {
        if (isLeftAligned) {
          align = pw.TextAlign.left;
        } else if (isRightAligned) {
          align = pw.TextAlign.right;
        }
        cleanText = cleanTextForEstimation(text);
      }

      if (type == 'TAKHMEES' && isCentered) {
        final double widthLimit = finalSadrWidth * 1.2 > containerWidth ? containerWidth : (finalSadrWidth > 0 ? finalSadrWidth * 1.2 : containerWidth * 0.6);
        final standaloneStyle = pw.TextStyle(
          font: font,
          fontFallback: fontFallback,
          fontSize: fontSize,
          height: 1.5,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
        );

        list.add(
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 3),
            child: pw.Align(
              alignment: pw.Alignment.center,
              child: pw.Container(
                width: containerWidth,
                alignment: pw.Alignment.center,
                child: buildJustifiedPoemLine(
                  cleanText,
                  standaloneStyle,
                  widthLimit,
                ),
              ),
            ),
          ),
        );
      } else {
        final standaloneStyle = pw.TextStyle(
          font: font,
          fontFallback: fontFallback,
          fontSize: fontSize,
          height: 1.5,
          fontWeight: isBold ? pw.FontWeight.bold : (isCentered ? pw.FontWeight.bold : pw.FontWeight.normal),
        );

        list.add(
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 3),
            child: pw.Align(
              alignment: pw.Alignment.center,
              child: pw.Container(
                width: containerWidth,
                alignment: align == pw.TextAlign.center
                    ? pw.Alignment.center
                    : (align == pw.TextAlign.left ? pw.Alignment.centerLeft : pw.Alignment.centerRight),
                child: pw.Text(
                  cleanText,
                  textAlign: align,
                  style: standaloneStyle,
                ),
              ),
            ),
          ),
        );
      }

      if (hasDivider) {
        list.add(
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 8),
            child: pw.Divider(thickness: 0.5, color: PdfColors.grey400),
          ),
        );
      }
      if (hasSpacing) {
        list.add(pw.SizedBox(height: 8));
      }

      return list;
    }

    if (type == 'TAKHMEES') {
      for (int i = 0; i < lines.length; i += 5) {
        final remaining = lines.length - i;
        final List<pw.Widget> stanzaWidgets = [];
        if (remaining >= 5) {
          stanzaWidgets.addAll(renderVerse(lines[i], lines[i + 1], false, false));
          stanzaWidgets.addAll(renderVerse(lines[i + 2], lines[i + 3], false, true));
          stanzaWidgets.addAll(renderStandalone(lines[i + 4], true, true, hasDivider: true, hasSpacing: true));
        } else if (remaining == 4) {
          stanzaWidgets.addAll(renderVerse(lines[i], lines[i + 1], false, false));
          stanzaWidgets.addAll(renderVerse(lines[i + 2], lines[i + 3], false, true));
        } else if (remaining == 3) {
          stanzaWidgets.addAll(renderVerse(lines[i], lines[i + 1], false, false));
          stanzaWidgets.addAll(renderStandalone(lines[i + 2], true, true, hasDivider: true, hasSpacing: true));
        } else if (remaining == 2) {
          stanzaWidgets.addAll(renderVerse(lines[i], lines[i + 1], false, false));
        } else if (remaining == 1) {
          stanzaWidgets.addAll(renderStandalone(lines[i], true, true, hasDivider: true, hasSpacing: true));
        }
        blocks.add(
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: stanzaWidgets,
          ),
        );
      }
    } else if (type == 'TARBEE') {
      for (int i = 0; i < lines.length; i += 4) {
        final remaining = lines.length - i;
        final List<pw.Widget> stanzaWidgets = [];
        if (remaining >= 4) {
          stanzaWidgets.addAll(renderVerse(lines[i], lines[i + 1], false, false));
          stanzaWidgets.addAll(renderVerse(lines[i + 2], lines[i + 3], false, true, hasDivider: true, hasSpacing: true));
        } else if (remaining == 3) {
          stanzaWidgets.addAll(renderVerse(lines[i], lines[i + 1], false, false));
          stanzaWidgets.addAll(renderVerse(lines[i + 2], '', false, true, hasDivider: true, hasSpacing: true));
        } else if (remaining == 2) {
          stanzaWidgets.addAll(renderVerse(lines[i], lines[i + 1], false, false));
        } else if (remaining == 1) {
          stanzaWidgets.addAll(renderVerse(lines[i], '', false, false));
        }
        blocks.add(
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: stanzaWidgets,
          ),
        );
      }
    } else {
      // Standard or TASHTEER layout
      final List<_PdfPoemItem> standardItems = [];
      String? pendingSadr;

      for (final line in lines) {
        final isCentered = (line.toUpperCase().startsWith('[CENTER]') && line.toUpperCase().endsWith('[/CENTER]')) ||
                           (line.startsWith('=') && line.endsWith('=') && line.length > 1);

        String cleanLineForWordCheck = line;
        if ((cleanLineForWordCheck.startsWith('=') && cleanLineForWordCheck.endsWith('=')) ||
            (cleanLineForWordCheck.startsWith('~') && cleanLineForWordCheck.endsWith('~'))) {
          if (cleanLineForWordCheck.length > 1) {
            cleanLineForWordCheck = cleanLineForWordCheck.substring(1, cleanLineForWordCheck.length - 1).trim();
          }
        } else if ((cleanLineForWordCheck.startsWith('--') && cleanLineForWordCheck.endsWith('--')) ||
                   (cleanLineForWordCheck.startsWith('++') && cleanLineForWordCheck.endsWith('++'))) {
          if (cleanLineForWordCheck.length > 3) {
            cleanLineForWordCheck = cleanLineForWordCheck.substring(2, cleanLineForWordCheck.length - 2).trim();
          }
        }
        cleanLineForWordCheck = cleanLineForWordCheck
            .replaceAll(RegExp(r'\[/?(BOLD|B|HIGHLIGHT|CENTER|JUSTIFY|LEFT|RIGHT)\]', caseSensitive: false), '')
            .trim();
        final words = cleanLineForWordCheck.split(RegExp(r'\s+')).where((w) => w.trim().isNotEmpty).toList();
        final isSingleWord = words.length <= 1;

        if (isCentered || isSingleWord) {
          if (pendingSadr != null) {
            standardItems.add(_PdfPoemVerse(pendingSadr, ''));
            pendingSadr = null;
          }
          final isLeftAligned = line.toUpperCase().contains('[LEFT]') || line.startsWith('--');
          final isRightAligned = line.toUpperCase().contains('[RIGHT]') || line.startsWith('++');
          standardItems.add(_PdfPoemStandalone(line, isCentered: isCentered, isLeftAligned: isLeftAligned, isRightAligned: isRightAligned));
        } else {
          if (pendingSadr == null) {
            pendingSadr = line;
          } else {
            standardItems.add(_PdfPoemVerse(pendingSadr, line));
            pendingSadr = null;
          }
        }
      }
      if (pendingSadr != null) {
        standardItems.add(_PdfPoemVerse(pendingSadr, ''));
      }

      if (type == 'TASHTEER') {
        int verseIndex = 0;
        for (int k = 0; k < standardItems.length; k++) {
          final item = standardItems[k];
          if (item is _PdfPoemVerse) {
            final isEven = verseIndex % 2 == 0;
            standardItems[k] = _PdfPoemVerse(
              item.sadr,
              item.ajez,
              isSadrBold: isEven,
              isAjezBold: !isEven,
            );
            verseIndex++;
          }
        }
      }

      // Render each item as its own block
      for (final item in standardItems) {
        final List<pw.Widget> blockWidgets = [];
        if (item is _PdfPoemStandalone) {
          blockWidgets.addAll(renderStandalone(
            item.text,
            item.isCentered,
            item.isBold,
            hasDivider: item.hasDividerBelow,
            hasSpacing: item.hasSpacingBelow,
            isLeftAligned: item.isLeftAligned,
            isRightAligned: item.isRightAligned,
          ));
        } else if (item is _PdfPoemVerse) {
          blockWidgets.addAll(renderVerse(
            item.sadr,
            item.ajez,
            item.isSadrBold,
            item.isAjezBold,
            hasDivider: item.hasDividerBelow,
            hasSpacing: item.hasSpacingBelow,
          ));
        }
        blocks.add(
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: blockWidgets,
          ),
        );
      }
    }

    return blocks;
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

abstract class _PdfPoemItem {}

class _PdfPoemVerse extends _PdfPoemItem {
  final String sadr;
  final String ajez;
  final bool isSadrBold;
  final bool isAjezBold;
  final bool hasDividerBelow;
  final bool hasSpacingBelow;

  _PdfPoemVerse(
    this.sadr,
    this.ajez, {
    this.isSadrBold = false,
    this.isAjezBold = false,
    this.hasDividerBelow = false,
    this.hasSpacingBelow = false,
  });
}

class _PdfPoemStandalone extends _PdfPoemItem {
  final String text;
  final bool isCentered;
  final bool isLeftAligned;
  final bool isRightAligned;
  final bool isBold;
  final bool hasDividerBelow;
  final bool hasSpacingBelow;

  _PdfPoemStandalone(
    this.text, {
    required this.isCentered,
    required this.isLeftAligned,
    required this.isRightAligned,
    this.isBold = false,
    this.hasDividerBelow = false,
    this.hasSpacingBelow = false,
  });
}
