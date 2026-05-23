import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import 'poetry/poem_view.dart';

class ArticleContentRenderer extends StatelessWidget {
  final String text;

  const ArticleContentRenderer({super.key, required this.text});

  TextSpan _parseInlineFormatting(String text, BuildContext context) {
    final defaultStyle = TextStyle(
      fontSize: AppDimens.textSizeM,
      height: 1.8,
      color: AppColors.getTextPrimary(context),
    );

    final List<TextSpan> spans = [];
    final pattern = RegExp(r'\[B\](.*?)\[/B\]|\*(.*?)\*', caseSensitive: false, dotAll: true);
    
    int lastMatchEnd = 0;
    
    for (final match in pattern.allMatches(text)) {
      final preText = text.substring(lastMatchEnd, match.start);
      if (preText.isNotEmpty) {
        spans.add(TextSpan(text: preText, style: defaultStyle));
      }
      
      final boldText = match.group(1) ?? match.group(2) ?? '';
      if (boldText.isNotEmpty) {
        spans.add(TextSpan(
          text: boldText,
          style: defaultStyle.copyWith(fontWeight: FontWeight.w900),
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
      
      if ((cleanLine.startsWith('[CENTER]') && cleanLine.endsWith('[/CENTER]')) ||
          (cleanLine.startsWith('=') && cleanLine.endsWith('=') && cleanLine.length > 1)) {
        textAlign = TextAlign.center;
        if (cleanLine.startsWith('=')) {
          cleanLine = cleanLine.substring(1, cleanLine.length - 1).trim();
        } else {
          cleanLine = cleanLine.substring('[CENTER]'.length, cleanLine.length - '[/CENTER]'.length).trim();
        }
      } else if ((cleanLine.startsWith('[JUSTIFY]') && cleanLine.endsWith('[/JUSTIFY]')) ||
                 (cleanLine.startsWith('~') && cleanLine.endsWith('~') && cleanLine.length > 1)) {
        textAlign = TextAlign.justify;
        if (cleanLine.startsWith('~')) {
          cleanLine = cleanLine.substring(1, cleanLine.length - 1).trim();
        } else {
          cleanLine = cleanLine.substring('[JUSTIFY]'.length, cleanLine.length - '[/JUSTIFY]'.length).trim();
        }
      } else if ((cleanLine.startsWith('[LEFT]') && cleanLine.endsWith('[/LEFT]')) ||
                 (cleanLine.startsWith('--') && cleanLine.endsWith('--') && cleanLine.length > 3)) {
        textAlign = TextAlign.left;
        if (cleanLine.startsWith('-')) {
          cleanLine = cleanLine.substring(2, cleanLine.length - 2).trim();
        } else {
          cleanLine = cleanLine.substring('[LEFT]'.length, cleanLine.length - '[/LEFT]'.length).trim();
        }
      } else if ((cleanLine.startsWith('[RIGHT]') && cleanLine.endsWith('[/RIGHT]')) ||
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
    final poemPattern = RegExp(r'\[POEM\](.*?)\[/POEM\]', dotAll: true);
    
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
        widgets.add(PoemView(poemText: poemContent));
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
