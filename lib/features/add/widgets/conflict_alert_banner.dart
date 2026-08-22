import 'package:flutter/material.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';

class ConflictAlertBanner extends StatelessWidget {
  const ConflictAlertBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.conflictAlert,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  context.l10n.conflictMessage,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.orange.shade200 : Colors.orange.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
