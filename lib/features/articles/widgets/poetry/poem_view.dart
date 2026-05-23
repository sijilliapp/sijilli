import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimens.dart';

class PoemView extends StatelessWidget {
  final String poemText;

  const PoemView({super.key, required this.poemText});

  @override
  Widget build(BuildContext context) {
    if (poemText.trim().isEmpty) return const SizedBox.shrink();

    final lines = poemText.split('\n').where((l) => l.trim().isNotEmpty).toList();
    final screenWidth = MediaQuery.of(context).size.width;
    final maxAllowedWidth = screenWidth * 0.65; // Max 65% for Sadr or Ajez
    
    double maxSadrWidth = 0.0;
    double maxAjezWidth = 0.0;
    
    final textStyle = TextStyle(
      fontSize: AppDimens.textSize, // Base size 16
      height: 1.8,
      color: AppColors.getTextPrimary(context),
      fontWeight: FontWeight.w600,
    );

    // Calculate max exact widths
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      final isSadr = i % 2 == 0;
      
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
    
    // Safety bounds for container
    if (containerWidth < screenWidth * 0.5) containerWidth = screenWidth * 0.5;
    if (containerWidth > screenWidth - 32) containerWidth = screenWidth - 32;

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
            final line = lines[index].trim();
            final isSadr = index % 2 == 0;
            final targetWidth = isSadr ? finalSadrWidth : finalAjezWidth;
            
            final words = line.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

            return Align(
              alignment: isSadr ? Alignment.centerRight : Alignment.centerLeft,
              child: SizedBox(
                width: targetWidth,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6.0), // Reduced from 12.0
                  child: words.length <= 1
                      ? Text(
                          line,
                          style: textStyle.copyWith(height: 1.6), // Reduced height
                          textAlign: isSadr ? TextAlign.right : TextAlign.left,
                        )
                      : Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          textDirection: TextDirection.rtl,
                          children: words.map((w) => Text(w, style: textStyle.copyWith(height: 1.6))).toList(),
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
