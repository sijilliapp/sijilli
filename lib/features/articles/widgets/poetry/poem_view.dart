import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimens.dart';
import '../../../../core/providers/theme_provider.dart';
import 'poem_formatter_utils.dart';

class PoemView extends StatelessWidget {
  final String poemText;
  final String? fontFamily;

  const PoemView({super.key, required this.poemText, this.fontFamily});

  @override
  Widget build(BuildContext context) {
    if (poemText.trim().isEmpty) return const SizedBox.shrink();

    final lines = poemText.split('\n').where((l) => l.trim().isNotEmpty).toList();
    final screenWidth = MediaQuery.of(context).size.width;
    final maxAllowedWidth = screenWidth - 48; // Allow poem lines to take up to screen width minus padding
    
    double maxSadrWidth = 0.0;
    double maxAjezWidth = 0.0;
    double maxCenteredWidth = 0.0;
    
    final double fontSize = AppDimens.textSize;
    final double lineHeight = 1.8;
    final FontWeight fontWeight = FontWeight.w600;
    
    final baseStyle = TextStyle(
      fontSize: fontSize, // Base size 16
      height: lineHeight,
      color: AppColors.getTextPrimary(context),
      fontWeight: fontWeight,
    );

    final textStyle = ThemeProvider.getTextStyleForFont(fontFamily ?? 'Default', baseStyle);

    int poetryLineIndex = 0;
    // Calculate max exact widths
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      final isCentered = (line.toUpperCase().startsWith('[CENTER]') && line.toUpperCase().endsWith('[/CENTER]')) ||
                         (line.startsWith('=') && line.endsWith('=') && line.length > 1);
      
      if (isCentered) {
        String cleanLine = line;
        if (line.startsWith('=')) {
          cleanLine = line.substring(1, line.length - 1).trim();
        } else {
          cleanLine = line.substring(8, line.length - 9).trim();
        }
        final parsedCentered = PoemFormatterUtils.parseInlineText(cleanLine, textStyle, context);
        final textPainter = TextPainter(
          text: TextSpan(children: parsedCentered),
          textDirection: TextDirection.rtl,
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        if (textPainter.width > maxCenteredWidth) maxCenteredWidth = textPainter.width;
        continue;
      }

      // التحقق إذا كان السطر عبارة عن كلمة واحدة (مع تجاهل علامات التنسيق والرموز)
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

      if (isSingleWord) {
        // لا يحتسب صدراً ولا عجزاً في حسابات الهوامش
        continue;
      }
      
      final isSadr = poetryLineIndex % 2 == 0;
      poetryLineIndex++;
      
      final parsedLine = PoemFormatterUtils.parseInlineText(line, textStyle, context);
      final textPainter = TextPainter(
        text: TextSpan(children: parsedLine),
        textDirection: TextDirection.rtl,
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      
      if (isSadr && textPainter.width > maxSadrWidth) maxSadrWidth = textPainter.width;
      if (!isSadr && textPainter.width > maxAjezWidth) maxAjezWidth = textPainter.width;
    }

    // Apply constraints and ensure Sadr and Ajez have the same width
    final double maxHalfWidth = maxSadrWidth > maxAjezWidth ? maxSadrWidth : maxAjezWidth;
    final double finalSadrWidth = maxHalfWidth > maxAllowedWidth ? maxAllowedWidth : maxHalfWidth;
    final double finalAjezWidth = finalSadrWidth;
    
    // Calculate overlap to enforce 'interlocking fingers' perfectly
    const double overlapPixels = 40.0;
    double containerWidth = finalSadrWidth + finalAjezWidth - overlapPixels;
    
    // Make sure container fits the largest centered line as well
    final double finalCenteredWidth = maxCenteredWidth > maxAllowedWidth ? maxAllowedWidth : maxCenteredWidth;
    if (containerWidth < finalCenteredWidth) {
      containerWidth = finalCenteredWidth;
    }
    
    // Safety bounds for container
    if (containerWidth < screenWidth * 0.5) containerWidth = screenWidth * 0.5;
    if (containerWidth > screenWidth - 32) containerWidth = screenWidth - 32;

    int renderPoetryLineIndex = 0;

    return Center(
      child: Container(
        width: containerWidth,
        margin: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 8.0),
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
        decoration: BoxDecoration(
          color: AppColors.getCardBackground(context),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: List.generate(lines.length, (index) {
            final originalLine = lines[index].trim();
            final isCentered = (originalLine.toUpperCase().startsWith('[CENTER]') && originalLine.toUpperCase().endsWith('[/CENTER]')) ||
                               (originalLine.startsWith('=') && originalLine.endsWith('=') && originalLine.length > 1);
            
            // التحقق إذا كان السطر عبارة عن كلمة واحدة
            String cleanLineForWordCheck = originalLine;
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

            if (isSingleWord && !isCentered) {
              final isLeftAligned = originalLine.toUpperCase().contains('[LEFT]');
              
              String displayLine = originalLine;
              // تنظيف علامات التنسيق والفقرات للعرض النظيف
              if ((displayLine.startsWith('=') && displayLine.endsWith('=')) ||
                  (displayLine.startsWith('~') && displayLine.endsWith('~'))) {
                if (displayLine.length > 1) displayLine = displayLine.substring(1, displayLine.length - 1).trim();
              } else if ((displayLine.startsWith('--') && displayLine.endsWith('--')) ||
                         (displayLine.startsWith('++') && displayLine.endsWith('++'))) {
                if (displayLine.length > 3) displayLine = displayLine.substring(2, displayLine.length - 2).trim();
              }
              displayLine = displayLine
                  .replaceAll(RegExp(r'\[/?(BOLD|B|HIGHLIGHT|CENTER|JUSTIFY|LEFT|RIGHT)\]', caseSensitive: false), '')
                  .trim();
              
              final parsedSpans = PoemFormatterUtils.parseInlineText(displayLine, textStyle.copyWith(height: 1.6), context);
              
              return Align(
                alignment: isLeftAligned ? Alignment.centerLeft : Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: Text.rich(
                    TextSpan(children: parsedSpans),
                    softWrap: false,
                    maxLines: 1,
                  ),
                ),
              );
            }

            String line = originalLine;
            if (isCentered) {
              if (line.startsWith('=')) {
                line = line.substring(1, line.length - 1).trim();
              } else {
                line = line.substring(8, line.length - 9).trim();
              }
              
              final parsedCentered = PoemFormatterUtils.parseInlineText(line, textStyle.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.getTextPrimary(context),
              ), context);
              
              final centeredWordSpans = PoemFormatterUtils.splitSpansIntoWords(parsedCentered);
              final double targetCenteredWidth = finalCenteredWidth > containerWidth ? containerWidth : finalCenteredWidth;
              
              return Align(
                alignment: Alignment.center,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: centeredWordSpans.length <= 1
                      ? SizedBox(
                          width: targetCenteredWidth,
                          child: Text.rich(
                            TextSpan(children: parsedCentered),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          child: SizedBox(
                            width: targetCenteredWidth,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              textDirection: TextDirection.rtl,
                              children: centeredWordSpans.map((span) => Text.rich(
                                span,
                                softWrap: false,
                                maxLines: 1,
                              )).toList(),
                            ),
                          ),
                        ),
                ),
              );
            }

            // إزالة أي وسوم محاذاة أو تنسيق فقرات قد تتداخل داخل أسطر القصيدة
            if ((line.startsWith('=') && line.endsWith('=')) ||
                (line.startsWith('~') && line.endsWith('~'))) {
              if (line.length > 1) line = line.substring(1, line.length - 1).trim();
            } else if ((line.startsWith('--') && line.endsWith('--')) ||
                       (line.startsWith('++') && line.endsWith('++'))) {
              if (line.length > 3) line = line.substring(2, line.length - 2).trim();
            } else if (line.toUpperCase().startsWith('[CENTER]') && line.toUpperCase().endsWith('[/CENTER]')) {
              line = line.substring(8, line.length - 9).trim();
            } else if (line.toUpperCase().startsWith('[JUSTIFY]') && line.toUpperCase().endsWith('[/JUSTIFY]')) {
              line = line.substring(9, line.length - 10).trim();
            } else if (line.toUpperCase().startsWith('[LEFT]') && line.toUpperCase().endsWith('[/LEFT]')) {
              line = line.substring(6, line.length - 7).trim();
            } else if (line.toUpperCase().startsWith('[RIGHT]') && line.toUpperCase().endsWith('[/RIGHT]')) {
              line = line.substring(7, line.length - 8).trim();
            }
            final isSadr = renderPoetryLineIndex % 2 == 0;
            renderPoetryLineIndex++;
            final targetWidth = isSadr ? finalSadrWidth : finalAjezWidth;
            
            final parsedSpans = PoemFormatterUtils.parseInlineText(line, textStyle.copyWith(height: 1.6), context);
            final wordSpans = PoemFormatterUtils.splitSpansIntoWords(parsedSpans);

            final textPainter = TextPainter(
              text: TextSpan(children: parsedSpans),
              textDirection: TextDirection.rtl,
              textScaler: MediaQuery.textScalerOf(context),
            )..layout();
            final double naturalWidth = textPainter.width;

            return Align(
              alignment: isSadr ? Alignment.centerRight : Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: wordSpans.length <= 1
                    ? SizedBox(
                        width: targetWidth,
                        child: Align(
                          alignment: isSadr ? Alignment.centerRight : Alignment.centerLeft,
                          child: naturalWidth > targetWidth
                              ? FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text.rich(
                                    TextSpan(children: parsedSpans),
                                    softWrap: false,
                                    maxLines: 1,
                                  ),
                                )
                              : Text.rich(
                                  TextSpan(children: parsedSpans),
                                  textAlign: isSadr ? TextAlign.right : TextAlign.left,
                                  softWrap: false,
                                  maxLines: 1,
                                ),
                        ),
                      )
                    : SizedBox(
                        width: targetWidth,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: SizedBox(
                            width: naturalWidth > targetWidth ? naturalWidth : targetWidth,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              textDirection: TextDirection.rtl,
                              children: wordSpans.map((span) => Text.rich(
                                span,
                                softWrap: false,
                                maxLines: 1,
                              )).toList(),
                            ),
                          ),
                        ),
                      ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
