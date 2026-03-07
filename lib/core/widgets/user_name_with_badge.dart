import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class UserNameWithBadge extends StatelessWidget {
  final String name;
  final bool isVerified;
  final TextStyle? style;
  final double badgeSize;
  final Color? badgeColor;

  const UserNameWithBadge({
    super.key,
    required this.name,
    this.isVerified = false,
    this.style,
    this.badgeSize = 16, // تصغير الحجم قليلاً
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    // تحديد اتجاه النص بناءً على الحرف الأول من الاسم
    final isArabic = RegExp(r'^[\u0600-\u06FF]').hasMatch(name.trim());
    final textDirection = isArabic ? TextDirection.rtl : TextDirection.ltr;

    return Directionality(
      textDirection: textDirection,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start, // محاذاة للأعلى
        children: [
          Flexible(
            child: Text(
              name,
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isVerified) ...[
            const SizedBox(width: 4),
            Padding(
              padding: const EdgeInsets.only(top: 4.0), // ضبط المحاذاة مع النص
              child: Icon(
                Icons.verified,
                size: badgeSize,
                color: badgeColor ?? AppColors.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
