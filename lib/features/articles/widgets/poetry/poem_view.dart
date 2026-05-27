import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimens.dart';

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
    
    final isTraditionalArabic = fontFamily == 'Traditional_Arabic';
    final double fontSize = isTraditionalArabic
        ? AppDimens.textSize * 1.5
        : AppDimens.textSize;
    final double lineHeight = isTraditionalArabic ? 1.3 : 1.8;
    final FontWeight fontWeight = isTraditionalArabic ? FontWeight.bold : FontWeight.w600;
    
    final textStyle = TextStyle(
      fontSize: fontSize, // Base size 16
      height: lineHeight,
      color: AppColors.getTextPrimary(context),
      fontWeight: fontWeight,
      fontFamily: fontFamily,
    );

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
        final textPainter = TextPainter(
          text: TextSpan(text: cleanLine, style: textStyle),
          textDirection: TextDirection.rtl,
        )..layout();
        if (textPainter.width > maxCenteredWidth) maxCenteredWidth = textPainter.width;
        continue;
      }
      
      final isSadr = poetryLineIndex % 2 == 0;
      poetryLineIndex++;
      
      final textPainter = TextPainter(
        text: TextSpan(text: line, style: textStyle),
        textDirection: TextDirection.rtl,
      )..layout();
      
      if (isSadr && textPainter.width > maxSadrWidth) maxSadrWidth = textPainter.width;
      if (!isSadr && textPainter.width > maxAjezWidth) maxAjezWidth = textPainter.width;
    }

    // Apply constraints
    final double finalSadrWidth = maxSadrWidth > maxAllowedWidth ? maxAllowedWidth : maxSadrWidth;
    final double finalAjezWidth = maxAjezWidth > maxAllowedWidth ? maxAllowedWidth : maxAjezWidth;
    
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
            
            String line = originalLine;
            if (isCentered) {
              if (line.startsWith('=')) {
                line = line.substring(1, line.length - 1).trim();
              } else {
                line = line.substring(8, line.length - 9).trim();
              }
              final centeredWords = line.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
              final double targetCenteredWidth = finalCenteredWidth > containerWidth ? containerWidth : finalCenteredWidth;
              
              return Align(
                alignment: Alignment.center,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: centeredWords.length <= 1
                      ? SizedBox(
                          width: targetCenteredWidth,
                          child: Text(
                            line,
                            style: textStyle.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.getTextPrimary(context),
                            ),
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
                              children: centeredWords.map((w) => Text(
                                w,
                                style: textStyle.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.getTextPrimary(context),
                                ),
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
            
            final words = line.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

            return Align(
              alignment: isSadr ? Alignment.centerRight : Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: words.length <= 1
                    ? SizedBox(
                        width: targetWidth,
                        child: Text(
                          line,
                          style: textStyle.copyWith(height: 1.6),
                          textAlign: isSadr ? TextAlign.right : TextAlign.left,
                        ),
                      )
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        child: SizedBox(
                          width: targetWidth,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            textDirection: TextDirection.rtl,
                            children: words.map((w) => Text(w, style: textStyle.copyWith(height: 1.6))).toList(),
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
