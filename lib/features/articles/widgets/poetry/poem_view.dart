import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimens.dart';
import '../../../../core/providers/theme_provider.dart';
import 'poem_formatter_utils.dart';

class PoemView extends StatelessWidget {
  final String poemText;
  final String? fontFamily;
  final String type;

  const PoemView({super.key, required this.poemText, this.fontFamily, this.type = 'STANDARD'});

  @override
  Widget build(BuildContext context) {
    if (poemText.trim().isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final lines = poemText.split('\n').where((l) => l.trim().isNotEmpty).toList();
        final double maxAllowedWidth = (constraints.maxWidth - 48) > 0 ? (constraints.maxWidth - 48) : constraints.maxWidth;

        final double fontSize = AppDimens.textSize;
        final double lineHeight = 1.8;
        final FontWeight fontWeight = FontWeight.w600;

        final baseStyle = TextStyle(
          fontSize: fontSize,
          height: lineHeight,
          color: AppColors.getTextPrimary(context),
          fontWeight: fontWeight,
        );
        final textStyle = ThemeProvider.getTextStyleForFont(fontFamily ?? 'Default', baseStyle);

        // Parse the poem lines into PoemItems based on structure type
        final List<PoemItem> items = [];

        if (type == 'TAKHMEES') {
          for (int i = 0; i < lines.length; i += 5) {
            final remaining = lines.length - i;
            if (remaining >= 5) {
              items.add(PoemVerse(lines[i], lines[i + 1]));
              items.add(PoemVerse(lines[i + 2], lines[i + 3], isAjezBold: true));
              items.add(PoemStandalone(
                lines[i + 4],
                isCentered: true,
                isLeftAligned: false,
                isBold: true,
                hasDividerBelow: true,
                hasSpacingBelow: true,
              ));
            } else if (remaining == 4) {
              items.add(PoemVerse(lines[i], lines[i + 1]));
              items.add(PoemVerse(lines[i + 2], lines[i + 3], isAjezBold: true));
            } else if (remaining == 3) {
              items.add(PoemVerse(lines[i], lines[i + 1]));
              items.add(PoemStandalone(
                lines[i + 2],
                isCentered: true,
                isLeftAligned: false,
                isBold: true,
                hasDividerBelow: true,
                hasSpacingBelow: true,
              ));
            } else if (remaining == 2) {
              items.add(PoemVerse(lines[i], lines[i + 1]));
            } else if (remaining == 1) {
              items.add(PoemStandalone(
                lines[i],
                isCentered: true,
                isLeftAligned: false,
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
                items.add(PoemVerse(pendingSadr, ''));
                pendingSadr = null;
              }
              final isLeftAligned = line.toUpperCase().contains('[LEFT]') || line.startsWith('--');
              items.add(PoemStandalone(line, isCentered: isCentered, isLeftAligned: isLeftAligned));
            } else {
              if (pendingSadr == null) {
                pendingSadr = line;
              } else {
                items.add(PoemVerse(pendingSadr, line));
                pendingSadr = null;
              }
            }
          }
          if (pendingSadr != null) {
            items.add(PoemVerse(pendingSadr, ''));
          }

          // Post-process styling for TASHTEER and TARBEE
          if (type == 'TASHTEER') {
            int verseIndex = 0;
            for (int k = 0; k < items.length; k++) {
              final item = items[k];
              if (item is PoemVerse) {
                final isEven = verseIndex % 2 == 0;
                items[k] = PoemVerse(
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
              if (item is PoemVerse) {
                final isLastInStanza = verseIndex % 2 == 1;
                items[k] = PoemVerse(
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

        // Measure widths of Sadr, Ajez, and Centered text to decide on layout
        double maxSadrWidth = 0.0;
        double maxAjezWidth = 0.0;
        double maxCenteredWidth = 0.0;

        for (final item in items) {
          if (item is PoemStandalone && item.isCentered) {
            String cleanLine = item.text;
            if (cleanLine.toUpperCase().startsWith('[CENTER]') && cleanLine.toUpperCase().endsWith('[/CENTER]')) {
              cleanLine = cleanLine.substring(8, cleanLine.length - 9).trim();
            } else if (cleanLine.startsWith('=') && cleanLine.endsWith('=')) {
              cleanLine = cleanLine.substring(1, cleanLine.length - 1).trim();
            }
            final parsed = PoemFormatterUtils.parseInlineText(cleanLine, textStyle, context);
            final tp = TextPainter(
              text: TextSpan(children: parsed),
              textDirection: TextDirection.rtl,
              textScaler: MediaQuery.textScalerOf(context),
            )..layout();
            if (tp.width > maxCenteredWidth) maxCenteredWidth = tp.width;
          } else if (item is PoemVerse) {
            if (item.sadr.isNotEmpty) {
              final parsed = PoemFormatterUtils.parseInlineText(item.sadr, textStyle, context);
              final tp = TextPainter(
                text: TextSpan(children: parsed),
                textDirection: TextDirection.rtl,
                textScaler: MediaQuery.textScalerOf(context),
              )..layout();
              if (tp.width > maxSadrWidth) maxSadrWidth = tp.width;
            }
            if (item.ajez.isNotEmpty) {
              final parsed = PoemFormatterUtils.parseInlineText(item.ajez, textStyle, context);
              final tp = TextPainter(
                text: TextSpan(children: parsed),
                textDirection: TextDirection.rtl,
                textScaler: MediaQuery.textScalerOf(context),
              )..layout();
              if (tp.width > maxAjezWidth) maxAjezWidth = tp.width;
            }
          }
        }

        final double maxHalfWidth = maxSadrWidth > maxAjezWidth ? maxSadrWidth : maxAjezWidth;
        const double middleGap = 32.0;

        // Check if the poem should use intertwined layout because Sadr/Ajez are too long for side-by-side
        final bool shouldIntertwine = maxHalfWidth > (maxAllowedWidth - middleGap) / 2;

        double containerWidth;
        double finalSadrWidth;
        double finalAjezWidth;

        if (shouldIntertwine) {
          // Intertwined layout: Sadr and Ajez overlap, taking maximum allowed width
          finalSadrWidth = maxHalfWidth > maxAllowedWidth ? maxAllowedWidth : maxHalfWidth;
          finalAjezWidth = finalSadrWidth;
          const double overlapPixels = 40.0;
          containerWidth = finalSadrWidth + finalAjezWidth - overlapPixels + 32.0; // Add 32.0 for container padding
        } else {
          // Side-by-side layout: Sadr and Ajez fit next to each other
          finalSadrWidth = maxHalfWidth;
          finalAjezWidth = maxHalfWidth;
          containerWidth = maxHalfWidth * 2 + middleGap + 32.0; // Add 32.0 for container padding
        }

        final double finalCenteredWidth = maxCenteredWidth > maxAllowedWidth ? maxAllowedWidth : maxCenteredWidth;
        if (containerWidth < finalCenteredWidth) {
          containerWidth = finalCenteredWidth;
        }

        if (containerWidth < constraints.maxWidth * 0.5) containerWidth = constraints.maxWidth * 0.5;
        if (containerWidth > constraints.maxWidth - 16) containerWidth = constraints.maxWidth - 16; // 16 for margin (8*2)

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
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: items.map((item) {
                if (item is PoemStandalone) {
                  if (item.isCentered) {
                    String line = item.text;
                    if (line.toUpperCase().startsWith('[CENTER]') && line.toUpperCase().endsWith('[/CENTER]')) {
                      line = line.substring(8, line.length - 9).trim();
                    } else if (line.startsWith('=') && line.endsWith('=')) {
                      line = line.substring(1, line.length - 1).trim();
                    }
                    final parsedCentered = PoemFormatterUtils.parseInlineText(line, textStyle.copyWith(
                      fontWeight: item.isBold ? FontWeight.bold : FontWeight.w600,
                      color: AppColors.getTextPrimary(context),
                    ), context);
                    final centeredWordSpans = PoemFormatterUtils.splitSpansIntoWords(parsedCentered);
                    
                    // Unified width for centered Takhmees lines: finalSadrWidth * 1.2 capped at containerWidth
                    final double widthLimit = type == 'TAKHMEES'
                        ? (finalSadrWidth * 1.2 > containerWidth ? containerWidth : (finalSadrWidth > 0 ? finalSadrWidth * 1.2 : containerWidth * 0.6))
                        : (finalCenteredWidth > containerWidth ? containerWidth : (finalCenteredWidth > 0 ? finalCenteredWidth : containerWidth * 0.6));

                    return Align(
                      alignment: Alignment.center,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            centeredWordSpans.length <= 1
                                ? SizedBox(
                                    width: widthLimit,
                                    child: Text.rich(
                                      TextSpan(children: parsedCentered),
                                      textAlign: TextAlign.center,
                                    ),
                                  )
                                : FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: SizedBox(
                                      width: widthLimit,
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
                            if (item.hasDividerBelow) ...[
                              const SizedBox(height: 12.0),
                              Divider(thickness: 1.0, color: Colors.grey.withOpacity(0.3)),
                            ],
                            if (item.hasSpacingBelow)
                              const SizedBox(height: 12.0),
                          ],
                        ),
                      ),
                    );
                  } else {
                    // Standalone word/line aligned left or right
                    final isLeftAligned = item.isLeftAligned;
                    String displayLine = item.text;
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

                    final parsedSpans = PoemFormatterUtils.parseInlineText(displayLine, textStyle.copyWith(
                      height: 1.6,
                      fontWeight: item.isBold ? FontWeight.bold : FontWeight.w600,
                    ), context);
                    return Align(
                      alignment: isLeftAligned ? Alignment.centerLeft : Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 6.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: isLeftAligned ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                          children: [
                            Text.rich(
                              TextSpan(children: parsedSpans),
                              softWrap: false,
                              maxLines: 1,
                            ),
                            if (item.hasDividerBelow) ...[
                              const SizedBox(height: 12.0),
                              Divider(thickness: 1.0, color: Colors.grey.withOpacity(0.3)),
                            ],
                            if (item.hasSpacingBelow)
                              const SizedBox(height: 12.0),
                          ],
                        ),
                      ),
                    );
                  }
                } else if (item is PoemVerse) {
                  if (shouldIntertwine) {
                    // Intertwined layout: Sadr and Ajez are rendered on separate vertical lines
                    final widgets = <Widget>[];
                    if (item.sadr.isNotEmpty) {
                      widgets.add(_buildIntertwinedHemistich(
                        item.sadr,
                        true,
                        finalSadrWidth,
                        item.isSadrBold ? textStyle.copyWith(fontWeight: FontWeight.bold) : textStyle,
                        context,
                      ));
                    }
                    if (item.ajez.isNotEmpty) {
                      widgets.add(_buildIntertwinedHemistich(
                        item.ajez,
                        false,
                        finalAjezWidth,
                        item.isAjezBold ? textStyle.copyWith(fontWeight: FontWeight.bold) : textStyle,
                        context,
                      ));
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ...widgets,
                        if (item.hasDividerBelow) ...[
                          const SizedBox(height: 8.0),
                          Divider(thickness: 1.0, color: Colors.grey.withOpacity(0.3)),
                        ],
                        if (item.hasSpacingBelow)
                          const SizedBox(height: 8.0),
                      ],
                    );
                  } else {
                    // Side-by-side layout: Sadr and Ajez are rendered on the same horizontal line
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            textDirection: TextDirection.rtl,
                            children: [
                              _buildSideBySideHemistich(
                                item.sadr,
                                finalSadrWidth,
                                item.isSadrBold ? textStyle.copyWith(fontWeight: FontWeight.bold) : textStyle,
                                context,
                              ),
                              _buildSideBySideHemistich(
                                item.ajez,
                                finalAjezWidth,
                                item.isAjezBold ? textStyle.copyWith(fontWeight: FontWeight.bold) : textStyle,
                                context,
                              ),
                            ],
                          ),
                          if (item.hasDividerBelow) ...[
                            const SizedBox(height: 8.0),
                            Divider(thickness: 1.0, color: Colors.grey.withOpacity(0.3)),
                          ],
                          if (item.hasSpacingBelow)
                            const SizedBox(height: 8.0),
                        ],
                      ),
                    );
                  }
                }
                return const SizedBox.shrink();
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildIntertwinedHemistich(String text, bool isSadr, double targetWidth, TextStyle textStyle, BuildContext context) {
    // Clean paragraph alignment tags from the hemistich
    String cleanText = text;
    if ((cleanText.startsWith('=') && cleanText.endsWith('=')) ||
        (cleanText.startsWith('~') && cleanText.endsWith('~'))) {
      if (cleanText.length > 1) cleanText = cleanText.substring(1, cleanText.length - 1).trim();
    } else if ((cleanText.startsWith('--') && cleanText.endsWith('--')) ||
               (cleanText.startsWith('++') && cleanText.endsWith('++'))) {
      if (cleanText.length > 3) cleanText = cleanText.substring(2, cleanText.length - 2).trim();
    }
    cleanText = cleanText
        .replaceAll(RegExp(r'\[/?(BOLD|B|HIGHLIGHT|CENTER|JUSTIFY|LEFT|RIGHT)\]', caseSensitive: false), '')
        .trim();

    final parsedSpans = PoemFormatterUtils.parseInlineText(cleanText, textStyle.copyWith(height: 1.6), context);
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
  }

  Widget _buildSideBySideHemistich(String text, double targetWidth, TextStyle textStyle, BuildContext context) {
    if (text.isEmpty) return SizedBox(width: targetWidth);

    // Clean paragraph alignment tags from the hemistich
    String cleanText = text;
    if ((cleanText.startsWith('=') && cleanText.endsWith('=')) ||
        (cleanText.startsWith('~') && cleanText.endsWith('~'))) {
      if (cleanText.length > 1) cleanText = cleanText.substring(1, cleanText.length - 1).trim();
    } else if ((cleanText.startsWith('--') && cleanText.endsWith('--')) ||
               (cleanText.startsWith('++') && cleanText.endsWith('++'))) {
      if (cleanText.length > 3) cleanText = cleanText.substring(2, cleanText.length - 2).trim();
    }
    cleanText = cleanText
        .replaceAll(RegExp(r'\[/?(BOLD|B|HIGHLIGHT|CENTER|JUSTIFY|LEFT|RIGHT)\]', caseSensitive: false), '')
        .trim();

    final parsedSpans = PoemFormatterUtils.parseInlineText(cleanText, textStyle.copyWith(height: 1.6), context);
    final wordSpans = PoemFormatterUtils.splitSpansIntoWords(parsedSpans);

    final textPainter = TextPainter(
      text: TextSpan(children: parsedSpans),
      textDirection: TextDirection.rtl,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final double naturalWidth = textPainter.width;

    return wordSpans.length <= 1
        ? SizedBox(
            width: targetWidth,
            child: Align(
              alignment: Alignment.center,
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
                      textAlign: TextAlign.center,
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
          );
  }
}

abstract class PoemItem {}

class PoemVerse extends PoemItem {
  final String sadr;
  final String ajez;
  final bool isSadrBold;
  final bool isAjezBold;
  final bool hasDividerBelow;
  final bool hasSpacingBelow;

  PoemVerse(
    this.sadr,
    this.ajez, {
    this.isSadrBold = false,
    this.isAjezBold = false,
    this.hasDividerBelow = false,
    this.hasSpacingBelow = false,
  });
}

class PoemStandalone extends PoemItem {
  final String text;
  final bool isCentered;
  final bool isLeftAligned;
  final bool isBold;
  final bool hasDividerBelow;
  final bool hasSpacingBelow;

  PoemStandalone(
    this.text, {
    required this.isCentered,
    required this.isLeftAligned,
    this.isBold = false,
    this.hasDividerBelow = false,
    this.hasSpacingBelow = false,
  });
}
