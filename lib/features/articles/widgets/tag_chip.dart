import 'package:flutter/material.dart';
import '../../../models/tag.dart';

class TagChip extends StatelessWidget {
  final Tag tag;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;
  final bool showDeleteIcon;
  final VoidCallback? onDelete;

  const TagChip({
    super.key,
    required this.tag,
    this.onTap,
    this.onLongPress,
    this.isSelected = false,
    this.showDeleteIcon = false,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = tag.color;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
        decoration: BoxDecoration(
          color: isSelected 
              ? baseColor 
              : baseColor.withValues(alpha: isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected 
                ? baseColor 
                : baseColor.withValues(alpha: isDark ? 0.35 : 0.25),
            width: 1.0,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: baseColor.withValues(alpha: 0.3),
              blurRadius: 6,
              offset: const Offset(0, 2),
            )
          ] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Colored dot
            if (!isSelected && !showDeleteIcon)
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: baseColor,
                  shape: BoxShape.circle,
                ),
              ),
            if (!isSelected && !showDeleteIcon) const SizedBox(width: 4),
            
            Text(
              tag.name,
              style: TextStyle(
                color: isSelected 
                    ? Colors.white 
                    : isDark 
                        ? Color.lerp(baseColor, Colors.white, 0.65) 
                        : Color.lerp(baseColor, Colors.black, 0.1),
                fontSize: 11,
                fontWeight: FontWeight.bold,
                height: 1.1, // Forces centering and controls height
              ),
            ),
            
            if (showDeleteIcon && onDelete != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onDelete,
                child: Icon(
                  Icons.close,
                  size: 13,
                  color: isSelected 
                      ? Colors.white70 
                      : baseColor.withValues(alpha: 0.8),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
