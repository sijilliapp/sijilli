
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/autocomplete_service.dart';

class WordRiverWidget extends StatelessWidget {
  final List<String> suggestions;
  final ValueChanged<String> onWordSelected;
  // Pivot Logic
  final List<PivotMatch> pivotSuggestions;
  final ValueChanged<PivotMatch>? onPivotSelected;

  final bool isLoading;

  const WordRiverWidget({
    super.key,
    required this.suggestions,
    required this.onWordSelected,
    this.pivotSuggestions = const [],
    this.onPivotSelected,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty && pivotSuggestions.isEmpty) {
      return const SizedBox.shrink();
    }
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Combined Count
    final count = pivotSuggestions.length + suggestions.length;

    return Container(
      height: 52,
      margin: EdgeInsets.zero,
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: Stack(
        children: [
          // 1. Inner Shadow (Top)
          Positioned(
            top: 0, left: 0, right: 0,
            height: 6,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          
          // 2. Inner Shadow (Bottom)
          Positioned(
            bottom: 0, left: 0, right: 0,
            height: 3,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // 3. The River Content
          Positioned.fill(
            child: ShaderMask(
              shaderCallback: (Rect rect) {
                return LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.black.withValues(alpha: 0), 
                    Colors.black, 
                    Colors.black, 
                    Colors.black.withValues(alpha: 0)
                  ],
                  stops: const [0.0, 0.05, 0.95, 1.0],
                ).createShader(rect);
              },
              blendMode: BlendMode.dstIn,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                itemCount: count,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  // Render Pivots FIRST (Priority)
                  if (index < pivotSuggestions.length) {
                     final match = pivotSuggestions[index];
                     return _buildAnimatedItem(
                       index,
                       _SuggestionChip(
                         label: match.differentiator,
                         onTap: () => onPivotSelected?.call(match),
                         isPivot: true,
                       ),
                     );
                  }
                  
                  final word = suggestions[index - pivotSuggestions.length];
                  return _buildAnimatedItem(
                    index,
                     _SuggestionChip(
                      label: word,
                      onTap: () => onWordSelected(word),
                      isPivot: false,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAnimatedItem(int index, Widget child) {
      return TweenAnimationBuilder<double>(
        duration: Duration(milliseconds: 300 + (index * 40)),
        tween: Tween(begin: 0.0, end: 1.0),
        curve: Curves.easeOutQuart,
        builder: (context, value, c) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(30 * (1 - value), 0), 
              child: c,
            ),
          );
        },
        child: child,
      );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isPivot;

  const _SuggestionChip({
    required this.label,
    required this.onTap,
    this.isPivot = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Material(
        color: isPivot 
            ? AppColors.primary.withValues(alpha: 0.15) 
            : (isDark ? Colors.grey.shade800 : Colors.white),
        elevation: isPivot ? 1 : 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isPivot ? AppColors.primary : (isDark ? Colors.white24 : Colors.grey.shade300), 
            width: isPivot ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              label,
              style: TextStyle(
                color: isPivot 
                    ? AppColors.primary 
                    : (isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87),
                fontWeight: isPivot ? FontWeight.bold : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
