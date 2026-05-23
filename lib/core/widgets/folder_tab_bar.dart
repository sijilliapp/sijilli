import 'package:flutter/material.dart';
import 'package:sijilli/core/constants/app_colors.dart';

class FolderTabBar extends StatelessWidget implements PreferredSizeWidget {
  final TabController tabController;
  final List<String> tabTitles;
  final List<Widget?>? tabActions; // New parameter for icons/widgets next to titles
  final VoidCallback? onMenuPressed;
  final Color backgroundColor;

  const FolderTabBar({
    super.key,
    required this.tabController,
    required this.tabTitles,
    this.tabActions,
    this.onMenuPressed,
    this.backgroundColor = const Color(0xFFF3F4F6), // lightSurface
    this.activeTabShadowColor,
  });

  final Color? activeTabShadowColor;

  @override
  Size get preferredSize => const Size.fromHeight(52); // 8 (padding) + 44 (height)

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // 1. Continuous Bottom Line (The "Stroke")
          Container(
            height: 1,
            width: double.infinity,
            color: Theme.of(context).dividerColor, // Dynamic divider
          ),

          // 2. Tabs Area
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Menu Button (Optional)
                if (onMenuPressed != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: InkWell(
                      onTap: onMenuPressed,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 40,
                        width: 40,
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor, // Dynamic card color
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Theme.of(context).dividerColor),
                        ),
                        child: Icon(Icons.menu, color: Theme.of(context).iconTheme.color, size: 20),
                      ),
                    ),
                  ),

                // Tabs
                Expanded(
                  child: AnimatedBuilder(
                    animation: tabController,
                    builder: (context, _) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(tabTitles.length, (index) {
                          final isSelected = tabController.index == index;
                          final isRtl = Directionality.of(context) == TextDirection.rtl;
                          final isFirst = index == 0;
                          final isLast = index == tabTitles.length - 1;
                          
                          // Determine if we should extend to the edge
                          final bool extendRight = isRtl ? isFirst : isLast;
                          final bool extendLeft = isRtl ? isLast : isFirst;

                          return Expanded(
                            child: GestureDetector(
                              onTap: () => tabController.animateTo(index),
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                height: 44, // Tab Height
                                color: Colors.transparent, // Ensures hit testing works on the whole area
                                child: Stack(
                                  children: [
                                    if (isSelected)
                                      Positioned.fill(
                                        child: CustomPaint(
                                          painter: FolderTabPainter(
                                            color: Theme.of(context).scaffoldBackgroundColor, // Match content bg
                                            borderColor: Theme.of(context).dividerColor,
                                            radius: 12,
                                            extendLeft: extendLeft,
                                            extendRight: extendRight,
                                            shadowColor: activeTabShadowColor,
                                          ),
                                        ),
                                      ),
                                    Align(
                                      alignment: Alignment.center,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (tabActions != null && index < tabActions!.length && tabActions![index] != null) ...[
                                            tabActions![index]!,
                                            const SizedBox(width: 8),
                                          ],
                                          Text(
                                            tabTitles[index],
                                            style: TextStyle(
                                              color: isSelected ? AppColors.primary : Theme.of(context).disabledColor,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      );
                    },
                  ),
                ),
                
                // Removed trailing SizedBox(width: 8) to allow full extension
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FolderTabPainter extends CustomPainter {
  final Color color;
  final Color borderColor;
  final double radius;
  final bool extendLeft;
  final bool extendRight;

  FolderTabPainter({
    required this.color,
    required this.borderColor,
    required this.radius,
    this.extendLeft = false,
    this.extendRight = false,
    this.shadowColor,
  });

  final Color? shadowColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // 1. Draw Shadow if color provided
    if (shadowColor != null) {
      final shadowPaint = Paint()
        ..color = shadowColor!
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4); // Soft blur
      
      canvas.save();
      // Shift shadow up to appear "outside" the top stroke
      canvas.translate(0, -2); 
      
      final shadowPath = _createPath(size, radius);
      // Clip to remove bottom shadow if needed, but since it's behind, it's fine.
      // However, to be clean, we can clip the bottom part.
      // For now, let's just draw it.
      canvas.drawPath(shadowPath, shadowPaint);
      canvas.restore();
    }

    // 2. Draw Fill
    final path = _createPath(size, radius);
    canvas.drawPath(path, paint);

    // 3. Draw Border (Open at bottom)
    final borderPath = Path();
    final double R = radius;
    
    // Start Logic
    if (extendLeft) {
      // Start at Top-Left (Skip vertical up line)
      borderPath.moveTo(0, 0);
    } else {
      // Start at Bottom-Left (Standard rounded corner)
      borderPath.moveTo(0, size.height);
      borderPath.lineTo(0, R);
      borderPath.arcToPoint(Offset(R, 0), radius: Radius.circular(R));
    }
    
    // Right Side / Corner
    if (extendRight) {
      borderPath.lineTo(size.width, 0); // Go straight to top-right corner
      // STOP HERE: Do not draw line down
    } else {
      borderPath.lineTo(size.width - R, 0);
      borderPath.arcToPoint(Offset(size.width, R), radius: Radius.circular(R));
      borderPath.lineTo(size.width, size.height);
    }
    
    canvas.drawPath(borderPath, borderPaint);
  }

  Path _createPath(Size size, double radius) {
    final path = Path();
    final double R = radius;

    // Start bottom-left (slightly below to overlap divider)
    path.moveTo(0, size.height + 1);
    
    // Top-Left Corner
    if (extendLeft) {
      path.lineTo(0, 0); // Square corner
    } else {
      path.lineTo(0, R);
      path.arcToPoint(Offset(R, 0), radius: Radius.circular(R)); // Rounded
    }
    
    // Top-Right Corner
    if (extendRight) {
      path.lineTo(size.width, 0); // Square corner
    } else {
      path.lineTo(size.width - R, 0);
      path.arcToPoint(Offset(size.width, R), radius: Radius.circular(R)); // Rounded
    }
    
    // Bottom-Right Corner
    path.lineTo(size.width, size.height + 1);
    
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant FolderTabPainter oldDelegate) {
    return color != oldDelegate.color || 
           borderColor != oldDelegate.borderColor ||
           extendLeft != oldDelegate.extendLeft ||
           extendRight != oldDelegate.extendRight;
  }
}

class SliverFolderHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  SliverFolderHeaderDelegate({
    required this.child,
    this.height = 52.0,
  });

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(SliverFolderHeaderDelegate oldDelegate) {
    return false;
  }
}
