import 'package:flutter/material.dart';
import '../../../../models/appointment.dart';
import 'interaction_capsule.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';

class AppointmentPrivacyBadge extends StatelessWidget {
  final Appointment appointment;

  const AppointmentPrivacyBadge({
    super.key,
    required this.appointment,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    Color contentColor;
    Color bgColor;
    Color borderColor;
    IconData icon;
    String label;

    if (appointment.isPublic) {
      contentColor = isDark ? Colors.blue.shade300 : Colors.blue.shade700;
      bgColor = isDark ? Colors.blue.shade900.withValues(alpha: 0.3) : Colors.blue.shade50;
      borderColor = isDark ? Colors.blue.shade300.withValues(alpha: 0.5) : Colors.blue.shade300.withValues(alpha: 0.5);
      icon = Icons.public;
      label = context.l10n.privacyPublic;
    } else if (appointment.isFollowers) {
      contentColor = isDark ? Colors.orange.shade300 : Colors.orange.shade800;
      bgColor = isDark ? Colors.orange.shade900.withValues(alpha: 0.3) : Colors.orange.shade50; // Crisp Orange
      borderColor = isDark ? Colors.orange.shade300.withValues(alpha: 0.5) : Colors.orange.shade300.withValues(alpha: 0.5);
      icon = Icons.people_outline;
      label = context.l10n.privacyFollowers;
    } else {
      // Private
      contentColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
      bgColor = isDark ? Colors.grey.shade800 : Colors.grey.shade50; // Crisp Grey
      borderColor = isDark ? Colors.grey.shade600 : Colors.grey.shade400;
      icon = Icons.lock_outline;
      label = context.l10n.privacyPrivate;
    }

    return InteractionCapsule(
      borderColor: borderColor,
      borderOpacity: 1.0,
      backgroundColor: bgColor,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: contentColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: contentColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
