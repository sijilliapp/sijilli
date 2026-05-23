import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimens.dart';

class NowPulseCapsule extends StatefulWidget {
  final Widget child;
  const NowPulseCapsule({super.key, required this.child});

  @override
  State<NowPulseCapsule> createState() => _NowPulseCapsuleState();
}

class _NowPulseCapsuleState extends State<NowPulseCapsule> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _glowAnimation = Tween<double>(begin: 4.0, end: 12.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimens.radiusCircle),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.4 * (1.0 - (_glowAnimation.value - 4.0) / 8.0)),
                blurRadius: _glowAnimation.value,
                spreadRadius: _glowAnimation.value / 2,
              ),
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.2),
                blurRadius: _glowAnimation.value / 2,
                spreadRadius: 1.0,
              ),
            ],
          ),
          child: widget.child,
        );
      },
    );
  }
}
