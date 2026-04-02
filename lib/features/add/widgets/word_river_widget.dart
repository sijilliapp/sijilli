
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
    
    // Combined Count
    final count = pivotSuggestions.length + suggestions.length;

    return SizedBox(
      height: 48, // Increased height for Material chips
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
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
                 isPivot: true, // Special Style
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
    );
  }
  
  Widget _buildAnimatedItem(int index, Widget child) {
      return TweenAnimationBuilder<double>(
        duration: Duration(milliseconds: 400 + (index * 50)),
        tween: Tween(begin: 0.0, end: 1.0),
        curve: Curves.easeOutQuart,
        builder: (context, value, c) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(-20 * (1 - value), 0), 
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
    return Material(
      color: isPivot ? AppColors.primary.withValues(alpha: 0.05) : Colors.white, // Light tint for pivot
      elevation: isPivot ? 2 : 1,
      shadowColor: isPivot ? AppColors.primary.withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          // ✨ Blue Frame for Pivot Words
          color: isPivot ? AppColors.primary : Colors.grey.shade300, 
          width: isPivot ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isPivot ? AppColors.primary : Colors.grey.shade700,
                fontWeight: isPivot ? FontWeight.bold : FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
