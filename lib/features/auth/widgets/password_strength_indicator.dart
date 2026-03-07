// 📍 lib/features/auth/widgets/password_strength_indicator.dart

import 'package:flutter/material.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/extensions/context_l10n.dart';

class PasswordStrengthIndicator extends StatelessWidget {
  final String password;

  const PasswordStrengthIndicator({super.key, required this.password});

  int _calculatePasswordStrength(String password) {
    if (password.isEmpty) return 0;
    
    int strength = 0;
    
    // الطول الأساسي (8+ أحرف)
    if (password.length >= 8) strength++;
    
    // طول إضافي (12+ أحرف)
    if (password.length >= 12) strength++;
    
    // تنوع الأحرف
    if (RegExp(r'[a-z]').hasMatch(password)) strength++; // أحرف صغيرة
    if (RegExp(r'[A-Z]').hasMatch(password)) strength++; // أحرف كبيرة
    if (RegExp(r'\d').hasMatch(password)) strength++;    // أرقام
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) strength++; // رموز خاصة
    
    // تحديد القوة النهائية (من 0 إلى 4) - أكثر تسامحاً
    if (strength <= 1) return 0; // ضعيفة جداً
    if (strength == 2) return 1; // ضعيفة
    if (strength == 3) return 2; // متوسطة
    if (strength == 4) return 3; // قوية
    return 4; // قوية جداً (5+ معايير)
  }

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();

    final strength = _calculatePasswordStrength(password);
    
    Color strengthColor;
    String strengthText;
    String strengthTip = '';
    
    switch (strength) {
      case 0:
        strengthColor = Colors.red;
        strengthText = context.l10n.passwordStrengthVeryWeak;
        strengthTip = context.l10n.passwordTipVeryWeak;
        break;
      case 1:
        strengthColor = Colors.orange;
        strengthText = context.l10n.passwordStrengthWeak;
        strengthTip = context.l10n.passwordTipWeak;
        break;
      case 2:
        strengthColor = Colors.yellow.shade700;
        strengthText = context.l10n.passwordStrengthMedium;
        strengthTip = context.l10n.passwordTipMedium;
        break;
      case 3:
        strengthColor = Colors.lightGreen;
        strengthText = context.l10n.passwordStrengthStrong;
        strengthTip = context.l10n.passwordTipStrong;
        break;
      case 4:
        strengthColor = Colors.green;
        strengthText = context.l10n.passwordStrengthVeryStrong;
        strengthTip = context.l10n.passwordTipVeryStrong;
        break;
      default:
        strengthColor = Colors.grey;
        strengthText = '';
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: strength / 4,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(strengthColor),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              strengthText,
              style: TextStyle(
                fontSize: AppDimens.textSizeXS, // 12
                color: strengthColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        if (strengthTip.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            strengthTip,
            style: TextStyle(
              fontSize: AppDimens.textSizeXXS + 1, // 11
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }
}
