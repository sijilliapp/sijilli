import 'package:flutter/material.dart';
import 'dart:ui';
import '../../../core/constants/app_colors.dart';

class AuthBackground extends StatelessWidget {
  final Widget child;

  const AuthBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        // 🎨 Background Base
        Container(
          color: Theme.of(context).scaffoldBackgroundColor,
        ),

        // 🎇 Soft Gradients for Premium Feel
        Positioned(
          top: -100,
          right: -50,
          child: _CircleGradient(
            size: 300,
            color: AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.1),
          ),
        ),
        Positioned(
          bottom: -50,
          left: -50,
          child: _CircleGradient(
            size: 250,
            color: AppColors.primary.withValues(alpha: isDark ? 0.1 : 0.05),
          ),
        ),

        // 📄 Content
        child,
      ],
    );
  }
}

class _CircleGradient extends StatelessWidget {
  final double size;
  final Color color;

  const _CircleGradient({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color,
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}
