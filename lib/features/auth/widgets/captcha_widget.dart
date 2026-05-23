import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/extensions/context_l10n.dart';

class CaptchaWidget extends StatefulWidget {
  final Function(bool) onVerified;
  final VoidCallback? onSubmitted;
  final FocusNode? focusNode;
  
  const CaptchaWidget({
    super.key, 
    required this.onVerified,
    this.onSubmitted,
    this.focusNode,
  });

  @override
  State<CaptchaWidget> createState() => _CaptchaWidgetState();
}

class _CaptchaWidgetState extends State<CaptchaWidget> {
  late int _num1;
  late int _num2;
  late int _sum;
  final TextEditingController _controller = TextEditingController();
  bool _isSolved = false;

  @override
  void initState() {
    super.initState();
    _generateCaptcha(notify: false);
  }

  void _generateCaptcha({bool notify = true}) {
    final random = Random();
    _num1 = random.nextInt(10) + 1;
    _num2 = random.nextInt(10) + 1;
    _sum = _num1 + _num2;
    _controller.clear();
    _isSolved = false;
    
    if (notify) {
      widget.onVerified(false);
      setState(() {});
    }
  }

  void _checkResult(String value) {
    final input = int.tryParse(value);
    final solved = input == _sum;
    if (solved != _isSolved) {
      setState(() => _isSolved = solved);
      widget.onVerified(solved);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isSolved 
              ? Colors.green.withValues(alpha: 0.5) 
              : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
          width: _isSolved ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          // القسم الأول: المعادلة (50%)
          Expanded(
            flex: 1,
            child: Container(
              height: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade50,
                borderRadius: const BorderRadiusDirectional.only(
                  topStart: Radius.circular(15),
                  bottomStart: Radius.circular(15),
                ),
              ),
              child: Text(
                '$_num1 + $_num2 = ',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          
          // القسم الثاني: الإجابة (50%)
          Expanded(
            flex: 1,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: widget.focusNode,
                    keyboardType: TextInputType.number,
                    onChanged: _checkResult,
                    onSubmitted: (_) {
                      if (_isSolved && widget.onSubmitted != null) {
                        widget.onSubmitted!();
                      }
                    },
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: '?',
                      contentPadding: EdgeInsets.zero,
                      filled: true,
                      fillColor: Colors.transparent,
                      border: InputBorder.none,
                      suffixIcon: _isSolved 
                          ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
                          : null,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _generateCaptcha,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 40),
                  tooltip: 'تحديث',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
