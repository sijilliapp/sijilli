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
        height: 28,
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(AppDimens.radiusCircle),
          border: Border.all(color: borderColor.withValues(alpha: borderOpacity), width: 1.5),
          boxShadow: boxShadow,
        ),
        child: Center(
          widthFactor: 1.0,  // Prevents horizontal expansion in Row/Flexible layouts
          heightFactor: 1.0, // Centers the child vertically inside the 28px height
          child: DefaultTextStyle(
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
              fontSize: 13, 
              fontWeight: FontWeight.w600,
              height: 1.1, // Inspired by GuestCapsule for better vertical centering
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
