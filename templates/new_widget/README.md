# 🧩 قالب عنصر واجهة جديد

## 🎯 قالب StatelessWidget

```dart
import 'package:flutter/material.dart';

/// وصف العنصر وما يفعله
class [WidgetName]Widget extends StatelessWidget {
  final String title;
  final VoidCallback? onTap;
  final bool isEnabled;

  const [WidgetName]Widget({
    super.key,
    required this.title,
    this.onTap,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.padding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.borderRadius),
        border: Border.all(color: AppColors.outline),
      ),
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    return Row(
      children: [
        Icon(
          Icons.info,
          color: isEnabled ? AppColors.primary : AppColors.disabled,
        ),
        const SizedBox(width: AppDimens.spacing),
        Expanded(
          child: Text(
            title,
            style: AppStyles.bodyMedium.copyWith(
              color: isEnabled ? AppColors.onSurface : AppColors.disabled,
            ),
          ),
        ),
      ],
    );
  }
}
```

## 🎯 قالب StatefulWidget

```dart
import 'package:flutter/material.dart';

/// وصف العنصر وما يفعله
class [WidgetName]Widget extends StatefulWidget {
  final String initialValue;
  final ValueChanged<String>? onChanged;

  const [WidgetName]Widget({
    super.key,
    required this.initialValue,
    this.onChanged,
  });

  @override
  State<[WidgetName]Widget> createState() => _[WidgetName]WidgetState();
}

class _[WidgetName]WidgetState extends State<[WidgetName]Widget> {
  late TextEditingController _controller;
  bool _isValid = true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _controller.text;
    final isValid = _validateInput(text);
    
    if (_isValid != isValid) {
      setState(() {
        _isValid = isValid;
      });
    }

    if (isValid) {
      widget.onChanged?.call(text);
    }
  }

  bool _validateInput(String text) {
    // منطق التحقق
    return text.isNotEmpty && text.length >= 3;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderSide: BorderSide(
                color: _isValid ? AppColors.outline : AppColors.error,
              ),
            ),
            errorText: _isValid ? null : 'النص قصير جداً',
          ),
        ),
        if (!_isValid) ...[
          const SizedBox(height: AppDimens.spacingSmall),
          Text(
            'يجب أن يكون النص 3 أحرف على الأقل',
            style: AppStyles.caption.copyWith(color: AppColors.error),
          ),
        ],
      ],
    );
  }
}
```

## 📝 قائمة التحقق

- [ ] اسم واضح ووصفي
- [ ] معاملات مطلوبة واختيارية واضحة
- [ ] استخدام الثوابت للقيم
- [ ] معالجة الحالات المختلفة
- [ ] تنظيف الموارد في dispose
- [ ] تعليقات عربية واضحة
- [ ] اختبار التفاعل
- [ ] دعم إمكانية الوصول