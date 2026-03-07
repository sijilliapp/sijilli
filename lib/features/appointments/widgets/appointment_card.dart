import 'package:flutter/material.dart';
import 'package:sijilli/models/appointment.dart';
import 'package:sijilli/features/appointments/widgets/cards/base_appointment_card.dart';
import 'package:sijilli/features/appointments/widgets/cards/policies/standard_policy.dart';
import 'package:sijilli/features/appointments/widgets/cards/policies/public_policy.dart';
import 'package:sijilli/features/appointments/widgets/cards/policies/featured_policy.dart';
import 'package:sijilli/features/appointments/widgets/cards/policies/archived_policy.dart';
import 'package:sijilli/features/appointments/widgets/cards/policies/deleted_policy.dart';
import 'package:sijilli/features/appointments/widgets/cards/appointment_card_policy.dart';

class AppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final bool isFeatured;
  final bool readOnly;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const AppointmentCard({
    super.key,
    required this.appointment,
    this.isFeatured = false,
    this.readOnly = false,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    AppointmentCardPolicy policy;

    if (isFeatured) {
      policy = FeaturedPolicy(appointment, context, customOnTap: onTap, isReadOnly: readOnly);
    } else if (readOnly) {
      policy = PublicPolicy(appointment, context, customOnTap: onTap);
    } else if (appointment.isArchived) {
      policy = ArchivedPolicy(appointment, context, customOnTap: onTap);
    } else if (appointment.isDeleted || appointment.isUserDeleted) {
      policy = DeletedPolicy(appointment, context, customOnTap: onTap);
    } else {
      policy = StandardPolicy(appointment, context, customOnTap: onTap);
    }

    return BaseAppointmentCard(policy: policy);
  }
}


