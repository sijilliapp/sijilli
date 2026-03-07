import 'package:flutter/material.dart';
import '../../../../core/constants/app_dimens.dart';

class InteractionCapsule extends StatelessWidget {
  final Widget child;
  final Color borderColor;
  final Color backgroundColor;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final double borderOpacity;
  final List<BoxShadow>? boxShadow;

  const InteractionCapsule({
    super.key,
    required this.child,
    required this.borderColor,
    this.backgroundColor = Colors.white,
    this.onTap,
    this.padding,
    this.borderOpacity = 0.3, 
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.radiusCircle),
      child: Container(
        height: 28, // Unified height for all capsules
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(AppDimens.radiusCircle),
          border: Border.all(color: borderColor.withOpacity(borderOpacity), width: 1.5), // Slightly thicker/white border support
          boxShadow: boxShadow,
        ),
        child: child,
      ),
    );
  }
}
