import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimens.dart';
import '../constants/app_config.dart';
import 'package:cached_network_image/cached_network_image.dart';


enum AvatarStatus {
  none,     // ⚪ Gray ring (Empty)
  upcoming, // 🔵 Blue ring (Within 24h)
  active,   // 🔦 Pulsing Blue (Now)
  deleted   // 🔴 Red ring (Host deleted)
}

class PulseAvatar extends StatefulWidget {
  final ImageProvider? image;
  final String? imageUrl; // Support URL directly for caching
  final double size;
  final AvatarStatus status;
  final VoidCallback? onTap;
  final bool showGlow; // Control whether to show pulsing glow effect
  final double? ringThickness; // Optional override for ring thickness
  final double? gapThickness; // Optional override for separation gap

  const PulseAvatar({
    super.key,
    this.image,
    this.imageUrl,
    this.size = AppDimens.avatarSizeProfile, // Default to 140
    this.status = AvatarStatus.none,
    this.onTap,
    this.showGlow = true, // Default to true for backward compatibility
    this.ringThickness,
    this.gapThickness,
  });

  @override
  State<PulseAvatar> createState() => _PulseAvatarState();
}

class _PulseAvatarState extends State<PulseAvatar> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: AppConfig.avatarPulseDurationMs), // From AppConfig
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut), 
    );

    _opacityAnimation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.status == AvatarStatus.active) {
      _controller.repeat(reverse: true); // Breathing effect
    }
  }

  @override
  void didUpdateWidget(PulseAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status != oldWidget.status) {
      if (widget.status == AvatarStatus.active) {
        _controller.repeat();
      } else {
        _controller.stop();
        _controller.reset();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getRingColor() {
    switch (widget.status) {
      case AvatarStatus.active:
      case AvatarStatus.upcoming:
        return AppColors.primary;
      case AvatarStatus.deleted:
        return Colors.red;
      case AvatarStatus.none:
      default:
        return Colors.grey.shade300;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Glow extends beyond the widget size without affecting layout
    // We used to calculate totalSize here, but now we strictly respect widget.size
    final ringWidth = widget.ringThickness ?? widget.size * AppDimens.avatarRingWidthRatio; 
    
    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none, // Allow glow to paint outside bounds
          children: [
            // ✨ Pulsing Glow Effect (Behind) - only if showGlow is true
            if (widget.status == AvatarStatus.active && widget.showGlow)
              Positioned(
                // Use a large overflow box to contain the glow
                top: -widget.size / 2,
                bottom: -widget.size / 2,
                left: -widget.size / 2,
                right: -widget.size / 2,
                child: Center(
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      // Scale proportionally, slightly larger than the avatar
                      final scale = _scaleAnimation.value * 1.02; 
                      return Container(
                        width: widget.size * scale,
                        height: widget.size * scale,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            // 🌟 التوهج الداخلي الساطع (Inner sharp glow)
                            BoxShadow(
                              color: AppColors.primary.withValues(
                                alpha: _opacityAnimation.value * AppConfig.avatarGlowOpacity,
                              ),
                              blurRadius: (widget.size * 0.08) * _scaleAnimation.value,
                              spreadRadius: (widget.size * 0.015) * _scaleAnimation.value,
                            ),
                            // 🌟 التوهج الخارجي الناعم (Outer soft glow)
                            BoxShadow(
                              color: AppColors.primary.withValues(
                                alpha: (_opacityAnimation.value * 0.45) * AppConfig.avatarGlowOpacity,
                              ),
                              blurRadius: (widget.size * 0.2) * _scaleAnimation.value,
                              spreadRadius: (widget.size * 0.03) * _scaleAnimation.value,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),

            // Static Outer Ring (Using CustomPaint for better Web Anti-Aliasing)
            CustomPaint(
              size: Size(widget.size, widget.size),
              painter: _RingPainter(
                color: _getRingColor(),
                strokeWidth: ringWidth,
              ),
            ),
            
            // Avatar Image
            Builder(
              builder: (context) {
                 final gapWidth = widget.gapThickness ?? widget.size * AppDimens.avatarRingGapRatio;
                 final innerSize = widget.size - (ringWidth * 2) - (gapWidth * 2);
                 return Container(
                  width: innerSize,
                  height: innerSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey.shade200,
                    image: (widget.imageUrl != null || widget.image != null)
                        ? DecorationImage(
                            image: widget.imageUrl != null 
                                ? CachedNetworkImageProvider(widget.imageUrl!) 
                                : widget.image!,
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: (widget.imageUrl == null && widget.image == null)
                      ? Icon(
                          Icons.person,
                          size: widget.size * 0.5,
                          color: Colors.grey,
                        )
                      : null,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _RingPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..isAntiAlias = true;

    // Size is the full size of the widget.
    // The radius needs to account for half of the stroke width so it doesn't clip out of bounds.
    final radius = (size.width - strokeWidth) / 2;
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), radius, paint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}
