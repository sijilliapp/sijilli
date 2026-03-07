import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';

class SunsetSeparator extends StatelessWidget {
  final DateTime sunsetTime;

  const SunsetSeparator({
    super.key,
    required this.sunsetTime,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
      child: Row(
        children: [
          // Icon
          const Icon(
            Icons.wb_twilight_rounded, // or nightlight_round
            color: Colors.orange,
            size: 20,
          ),
          const SizedBox(width: 8),
          
          // Time
          Text(
            'وقت الغروب  ${DateFormat('h:mm a').format(sunsetTime)}',
            style: const TextStyle(
              color: Colors.orange,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 12),

          // Divider Line
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.orange.withOpacity(0.5),
                    Colors.orange.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
