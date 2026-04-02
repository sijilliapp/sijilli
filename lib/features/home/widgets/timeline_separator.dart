import 'package:flutter/material.dart';
import '../../../core/constants/app_dimens.dart';

class TimelineSeparator extends StatelessWidget {
  final String dateText;
  final String durationText;

  const TimelineSeparator({
    super.key,
    required this.dateText,
    required this.durationText,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceXS), // 4.0
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: Duration (e.g., "5 أيام")
          Text(
            durationText,
            style: TextStyle(
              fontSize: AppDimens.textSizeXS, // 12
              color: Colors.grey.shade400,
              fontWeight: FontWeight.w500,
            ),
          ),
          
          const SizedBox(width: AppDimens.spaceS),
          
          // Center: Line
          Expanded(
            child: Container(
              height: 1,
              color: Theme.of(context).dividerColor,
            ),
          ),
          
          const SizedBox(width: AppDimens.spaceS),
          
          // Right: Date of the card ABOVE (e.g., "8 Jan 2026")
          // LTR direction for English date
          Text(
            dateText,
            style: TextStyle(
              fontSize: AppDimens.textSizeXS, // 12
              color: Colors.grey.shade400,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
