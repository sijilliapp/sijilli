import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import 'poetry/poem_view.dart';

class ArticleContentRenderer extends StatelessWidget {
  final String text;
  final String? fontFamily;

  const ArticleContentRenderer({super.key, required this.text, this.fontFamily});

  TextSpan _parseInlineFormatting(String text, BuildContext context) {
    final isTraditionalArabic = fontFamily == 'Traditional_Arabic';
    final double fontSize = isTraditionalArabic
        ? AppDimens.textSizeM * 1.5
        : AppDimens.textSizeM;
    final double lineHeight = isTraditionalArabic ? 1.3 : 1.8;
    final FontWeight? fontWeight = isTraditionalArabic ? FontWeight.bold : null;

    final defaultStyle = TextStyle(
      fontSize: fontSize,
      height: lineHeight,
      color: AppColors.getTextPrimary(context),
      fontFamily: fontFamily,
      fontWeight: fontWeight,
    );

    final List<TextSpan> spans = [];
    final pattern = RegExp(
      r'\[BOLD\](.*?)\[/BOLD\]'
      r'|\[B\](.*?)\[/B\]'
      r'|\*(.*?)\*'
      r'|\[HIGHLIGHT\](.*?)\[/HIGHLIGHT\]',
      caseSensitive: false,
      dotAll: true,
    );
    
    int lastMatchEnd = 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    for (final match in pattern.allMatches(text)) {
      final preText = text.substring(lastMatchEnd, match.start);
      if (preText.isNotEmpty) {
        spans.add(TextSpan(text: preText, style: defaultStyle));
      }
      
      final isBold = match.group(1) != null || match.group(2) != null || match.group(3) != null;
      final isHighlight = match.group(4) != null;
      final formattedText = match.group(1) ?? match.group(2) ?? match.group(3) ?? match.group(4) ?? '';
      
      if (formattedText.isNotEmpty) {
        spans.add(TextSpan(
          text: formattedText,
          style: defaultStyle.copyWith(
            fontWeight: isBold ? FontWeight.w900 : null,
            backgroundColor: isHighlight 
                ? (isDark ? const Color(0xFF78350F).withValues(alpha: 0.5) : const Color(0xFFFEF08A))
                : null,
            color: isHighlight
                ? (isDark ? const Color(0xFFFFFBEB) : const Color(0xFF1E293B))
                : null,
          ),
        ));
      }
      lastMatchEnd = match.end;
    }
    
    final postText = text.substring(lastMatchEnd);
    if (postText.isNotEmpty) {
      spans.add(TextSpan(text: postText, style: defaultStyle));
    }
    
    if (spans.isEmpty) {
      return TextSpan(text: text, style: defaultStyle);
    }
    
    return TextSpan(children: spans);
  }

  List<Widget> _renderTextBlock(BuildContext context, String blockText) {
    final List<Widget> widgets = [];
    final lines = blockText.split('\n');
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 12));
        continue;
      }
      
      TextAlign textAlign = TextAlign.start;
      String cleanLine = line.trim();
      final cleanLineUpper = cleanLine.toUpperCase();
      
      if ((cleanLineUpper.startsWith('[CENTER]') && cleanLineUpper.endsWith('[/CENTER]')) ||
          (cleanLine.startsWith('=') && cleanLine.endsWith('=') && cleanLine.length > 1)) {
        textAlign = TextAlign.center;
        if (cleanLine.startsWith('=')) {
          cleanLine = cleanLine.substring(1, cleanLine.length - 1).trim();
        } else {
          cleanLine = cleanLine.substring('[CENTER]'.length, cleanLine.length - '[/CENTER]'.length).trim();
        }
      } else if ((cleanLineUpper.startsWith('[JUSTIFY]') && cleanLineUpper.endsWith('[/JUSTIFY]')) ||
                 (cleanLine.startsWith('~') && cleanLine.endsWith('~') && cleanLine.length > 1)) {
        textAlign = TextAlign.justify;
        if (cleanLine.startsWith('~')) {
          cleanLine = cleanLine.substring(1, cleanLine.length - 1).trim();
        } else {
          cleanLine = cleanLine.substring('[JUSTIFY]'.length, cleanLine.length - '[/JUSTIFY]'.length).trim();
        }
      } else if ((cleanLineUpper.startsWith('[LEFT]') && cleanLineUpper.endsWith('[/LEFT]')) ||
                 (cleanLine.startsWith('--') && cleanLine.endsWith('--') && cleanLine.length > 3)) {
        textAlign = TextAlign.left;
        if (cleanLine.startsWith('-')) {
          cleanLine = cleanLine.substring(2, cleanLine.length - 2).trim();
        } else {
          cleanLine = cleanLine.substring('[LEFT]'.length, cleanLine.length - '[/LEFT]'.length).trim();
        }
      } else if ((cleanLineUpper.startsWith('[RIGHT]') && cleanLineUpper.endsWith('[/RIGHT]')) ||
                 (cleanLine.startsWith('++') && cleanLine.endsWith('++') && cleanLine.length > 3)) {
        textAlign = TextAlign.right;
        if (cleanLine.startsWith('+')) {
          cleanLine = cleanLine.substring(2, cleanLine.length - 2).trim();
        } else {
          cleanLine = cleanLine.substring('[RIGHT]'.length, cleanLine.length - '[/RIGHT]'.length).trim();
        }
      }
      
      widgets.add(Padding(
        padding: EdgeInsets.only(bottom: i == lines.length - 1 ? 0.0 : 8.0),
        child: Text.rich(
          _parseInlineFormatting(cleanLine, context),
          textAlign: textAlign,
        ),
      ));
    }
    
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) {
      return const SizedBox.shrink();
    }

    final List<Widget> widgets = [];
    final poemPattern = RegExp(r'\[POEM\](.*?)\[/POEM\]', dotAll: true, caseSensitive: false);
    
    int lastMatchEnd = 0;
    
    for (final match in poemPattern.allMatches(text)) {
      // Add preceding normal text if any
      final preText = text.substring(lastMatchEnd, match.start).trim();
      if (preText.isNotEmpty) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _renderTextBlock(context, preText),
          ),
        ));
      }
      
      // Add PoemView
      final poemContent = match.group(1)?.trim() ?? '';
      if (poemContent.isNotEmpty) {
        widgets.add(PoemView(poemText: poemContent, fontFamily: fontFamily));
      }
      
      lastMatchEnd = match.end;
    }
    
    // Add remaining normal text
    final postText = text.substring(lastMatchEnd).trim();
    if (postText.isNotEmpty) {
      widgets.add(Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _renderTextBlock(context, postText),
      ));
    }
    
    // If no text or poems were added at all, just render the original string
    if (widgets.isEmpty && text.isNotEmpty) {
      widgets.addAll(_renderTextBlock(context, text));
    }
 
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: widgets,
    );
  }
}
