import 'package:flutter/material.dart';
import 'package:sijilli/core/constants/app_colors.dart';

class CollapsibleContent extends StatefulWidget {
  final Widget child;
  final double maxHeight;
  final String buttonText;

  /// يُستدعى عند ضغط المستخدم على زر "المقال كاملاً"
  final VoidCallback? onExpand;

  const CollapsibleContent({
    super.key,
    required this.child,
    this.maxHeight = 420.0, // مختصر أكثر حتى يظهر الزر مباشرة
    required this.buttonText,
    this.onExpand,
  });

  @override
  State<CollapsibleContent> createState() => _CollapsibleContentState();
}

class _CollapsibleContentState extends State<CollapsibleContent>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  double? _naturalHeight;
  final GlobalKey _childKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final renderBox =
          _childKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        setState(() {
          _naturalHeight = renderBox.size.height;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool exceeds =
        _naturalHeight == null || _naturalHeight! > widget.maxHeight;

    if (!exceeds) {
      return Container(
        key: _childKey,
        child: widget.child,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // المحتوى المطوي / الممتد
        AnimatedSize(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              _isExpanded
                  ? Container(
                      key: const ValueKey('expanded'),
                      child: widget.child,
                    )
                  : SizedBox(
                      key: const ValueKey('collapsed'),
                      height: widget.maxHeight,
                      child: SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: Container(
                          key: _childKey,
                          child: widget.child,
                        ),
                      ),
                    ),
              // تدرج يوحي بأن هناك محتوى تحت
              if (!_isExpanded)
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.getBackground(context).withValues(alpha: 0.0),
                        AppColors.getBackground(context).withValues(alpha: 0.75),
                        AppColors.getBackground(context),
                      ],
                      stops: const [0.0, 0.55, 1.0],
                    ),
                  ),
                ),
            ],
          ),
        ),

        // زر "المقال كاملاً" — يظهر دائماً أسفل المحتوى مباشرة بدون سحب
        if (!_isExpanded) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: TextButton(
              style: TextButton.styleFrom(
                backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.0),
                  side: const BorderSide(color: AppColors.primary, width: 1.0),
                ),
                elevation: 0,
              ),
              onPressed: () {
                setState(() => _isExpanded = true);
                widget.onExpand?.call();
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.buttonText,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.keyboard_arrow_down, size: 20),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
