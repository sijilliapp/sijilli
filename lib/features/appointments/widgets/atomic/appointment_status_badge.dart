import 'package:flutter/material.dart';
import '../../../../models/appointment.dart';
import '../../../../core/constants/app_colors.dart';
import 'package:sijilli/features/appointments/widgets/cards/appointment_card_helper.dart';

class AppointmentStatusBadge extends StatelessWidget {
  final Appointment appointment;

  const AppointmentStatusBadge({
    super.key,
    required this.appointment,
  });

  @override
  Widget build(BuildContext context) {
    final Color statusColor;
    if (appointment.isCancelled) {
      statusColor = Colors.red;
    } else if (appointment.isPast) {
      statusColor = Colors.grey;
    } else if (appointment.isNow) {
      statusColor = AppColors.primary;
    } else {
      statusColor = Colors.green;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            AppointmentCardHelper.getStatusText(appointment, context),
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              color: statusColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
