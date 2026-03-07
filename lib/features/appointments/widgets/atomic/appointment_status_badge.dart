import 'package:flutter/material.dart';
import '../../../../models/appointment.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimens.dart';
import 'package:sijilli/l10n/app_localizations.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';
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
        color: statusColor.withOpacity(0.1),
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
