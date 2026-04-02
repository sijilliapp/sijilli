import 'package:flutter/material.dart';

class AppointmentDetailItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  final Widget? trailing;

  const AppointmentDetailItem({
    super.key,
    required this.icon,
    required this.text,
    this.color,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultIconColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final defaultTextColor = isDark ? Colors.grey.shade300 : Colors.grey.shade700;

    return Row(
      children: [
        Icon(icon, size: 16, color: color ?? defaultIconColor),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              color: color ?? defaultTextColor,
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 6),
          trailing!,
        ],
      ],
    );
  }
}
