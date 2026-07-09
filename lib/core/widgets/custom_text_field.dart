import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimens.dart';

class CustomTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String label;
  final String? hint;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final void Function(String)? onFieldSubmitted;
  final int? maxLines;
  final int? maxLength;
  final bool enabled;
  final FocusNode? focusNode;
  final TextDirection? textDirection;
  final List<TextInputFormatter>? inputFormatters;
  final bool showCountdown;
  final bool autoScrollHint;

  const CustomTextField({
    super.key,
    this.controller,
    required this.label,
    this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onFieldSubmitted,
    this.maxLines = 1,
    this.maxLength,
    this.enabled = true,
    this.focusNode,
    this.textDirection,
    this.inputFormatters,
    this.showCountdown = false,
    this.autoScrollHint = false,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  late final FocusNode _effectiveFocusNode;
  bool _hasFocus = false;
  bool _isEmpty = true;

  @override
  void initState() {
    super.initState();
    _effectiveFocusNode = widget.focusNode ?? FocusNode();
    _effectiveFocusNode.addListener(_onFocusChange);

    if (widget.controller != null) {
      _isEmpty = widget.controller!.text.isEmpty;
      widget.controller!.addListener(_onTextChange);
    }
  }

  @override
  void didUpdateWidget(covariant CustomTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      _effectiveFocusNode.removeListener(_onFocusChange);
      if (oldWidget.focusNode == null) {
        _effectiveFocusNode.dispose();
      }
      _effectiveFocusNode = widget.focusNode ?? FocusNode();
      _effectiveFocusNode.addListener(_onFocusChange);
    }

    if (widget.controller != oldWidget.controller) {
      if (oldWidget.controller != null) {
        oldWidget.controller!.removeListener(_onTextChange);
      }
      if (widget.controller != null) {
        widget.controller!.addListener(_onTextChange);
        _isEmpty = widget.controller!.text.isEmpty;
      }
    }
  }

  @override
  void dispose() {
    _effectiveFocusNode.removeListener(_onFocusChange);
    if (widget.focusNode == null) {
      _effectiveFocusNode.dispose();
    }
    if (widget.controller != null) {
      widget.controller!.removeListener(_onTextChange);
    }
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() {
        _hasFocus = _effectiveFocusNode.hasFocus;
      });
    }
  }

  void _onTextChange() {
    if (mounted) {
      final empty = widget.controller!.text.isEmpty;
      if (empty != _isEmpty) {
        setState(() {
          _isEmpty = empty;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isRTL = (widget.textDirection ?? Directionality.of(context)) == TextDirection.rtl;

    final showScrollingHint = widget.autoScrollHint && _isEmpty && !_hasFocus && widget.hint != null;

    final Widget inputField = TextFormField(
      controller: widget.controller,
      obscureText: widget.obscureText,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      validator: widget.validator,
      onFieldSubmitted: widget.onFieldSubmitted,
      maxLines: widget.maxLines,
      maxLength: widget.maxLength,
      enabled: widget.enabled,
      focusNode: _effectiveFocusNode,
      inputFormatters: widget.inputFormatters,
      textDirection: widget.textDirection ?? Directionality.of(context),
      buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: showScrollingHint ? null : widget.hint,
        floatingLabelBehavior: widget.autoScrollHint ? FloatingLabelBehavior.always : null,
        alignLabelWithHint: widget.maxLines == null || widget.maxLines! > 1,
        prefixIcon: widget.prefixIcon != null ? Icon(widget.prefixIcon, color: AppColors.primary) : null,
        suffixIcon: (widget.showCountdown && widget.maxLength != null && widget.controller != null) || widget.suffixIcon != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (widget.showCountdown && widget.maxLength != null && widget.controller != null)
                    ListenableBuilder(
                      listenable: widget.controller!,
                      builder: (context, _) {
                        final remaining = widget.maxLength! - widget.controller!.text.length;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            remaining.toString(),
                            style: TextStyle(
                              color: remaining < 5 ? AppColors.error : AppColors.primary.withOpacity(0.5),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
                  if (widget.suffixIcon != null) widget.suffixIcon!,
                  const SizedBox(width: 8),
                ],
              )
            : null,
        filled: true,
        fillColor: isDark ? Colors.grey.shade800 : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimens.padding,
          vertical: AppDimens.padding,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radius),
          borderSide: BorderSide(color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radius),
          borderSide: BorderSide(color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radius),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radius),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radius),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        labelStyle: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade700),
        floatingLabelStyle: const TextStyle(color: AppColors.primary),
      ),
    );

    if (showScrollingHint) {
      final hintStyle = TextStyle(
        color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
        fontSize: 14,
      );

      final prefixPadding = 16.0 + (widget.prefixIcon != null ? 36.0 : 0.0);
      final suffixPadding = 16.0 + ((widget.showCountdown || widget.suffixIcon != null) ? 44.0 : 0.0);

      final leftPadding = isRTL ? suffixPadding : prefixPadding;
      final rightPadding = isRTL ? prefixPadding : suffixPadding;

      return Stack(
        alignment: isRTL ? Alignment.centerRight : Alignment.centerLeft,
        children: [
          inputField,
          Positioned(
            left: leftPadding,
            right: rightPadding,
            top: 24, // Aligned with the input area
            child: AutoScrollingHint(
              text: widget.hint!,
              style: hintStyle,
              isRTL: isRTL,
            ),
          ),
        ],
      );
    }

    return inputField;
  }
}

class AutoScrollingHint extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final bool isRTL;
  const AutoScrollingHint({
    super.key,
    required this.text,
    this.style,
    this.isRTL = false,
  });

  @override
  State<AutoScrollingHint> createState() => _AutoScrollingHintState();
}

class _AutoScrollingHintState extends State<AutoScrollingHint> with SingleTickerProviderStateMixin {
  late final ScrollController _scrollController;
  late final AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..addListener(() {
        if (_scrollController.hasClients) {
          final maxExtent = _scrollController.position.maxScrollExtent;
          if (maxExtent > 0) {
            final offset = maxExtent * _animationController.value;
            _scrollController.jumpTo(offset);
          }
        }
      });

    _animationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Directionality(
        textDirection: widget.isRTL ? TextDirection.rtl : TextDirection.ltr,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          controller: _scrollController,
          child: Text(
            widget.text,
            style: widget.style,
            maxLines: 1,
          ),
        ),
      ),
    );
  }
}
