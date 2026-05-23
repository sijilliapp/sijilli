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
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
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
            padding: const EdgeInsets.only(top: 4.0),
            child: Icon(
              Icons.verified,
              size: badgeSize,
              color: badgeColor ?? AppColors.primary,
            ),
          ),
        ],
      ],
    );
  }
}
