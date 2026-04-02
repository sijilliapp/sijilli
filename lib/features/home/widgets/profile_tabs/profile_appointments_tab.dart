import 'package:flutter/material.dart';
import '../../../../core/constants/app_dimens.dart';
import '../../../../core/utils/app_date_formatter.dart';
import '../../../../models/appointment.dart';
import '../../../../models/user.dart';
import 'package:sijilli/features/appointments/widgets/appointment_card.dart';
import '../timeline_separator.dart';
import '../date_header.dart';
import '../private_profile_wall.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';

class ProfileAppointmentsTab extends StatelessWidget {
  final List<Appointment> appointments;
  final UserModel? user;
  final Future<void> Function() onRefresh;

  const ProfileAppointmentsTab({
    super.key,
    required this.appointments,
    this.user,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (appointments.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(8.0, AppDimens.spaceS, 8.0, AppDimens.spaceGiant),
          children: [
            DateHeader(
              hijriAdjustment: (user?.hijriAdjustment ?? 0).toInt(),
            ),
            const SizedBox(height: AppDimens.spaceXS),
            SizedBox(height: MediaQuery.of(context).size.height * 0.1),
            ProfileEmptyState(
              icon: Icons.event_busy_outlined,
              title: context.l10n.noPublicAppointments,
              description: context.l10n.noPublicAppointmentsDesc,
              action: const SizedBox(),
            ),
          ],
        ),
      );
    }

    // Sort appointments: Now > Active/Upcoming > Past
    final sortedAppointments = List<Appointment>.from(appointments);
    sortedAppointments.sort((a, b) {
      int score(Appointment app) {
        if (app.isNow) return 0;
        if (app.isFuture || app.isUpcoming) return 1;
        return 2;
      }
      
      final sA = score(a);
      final sB = score(b);
      
      if (sA != sB) return sA.compareTo(sB);
      
      if (sA == 2) {
        return b.fullDateTime.compareTo(a.fullDateTime);
      }
      
      return a.fullDateTime.compareTo(b.fullDateTime);
    });

    final nextAppt = sortedAppointments.first;
    final otherAppts = sortedAppointments.length > 1 ? sortedAppointments.sublist(1) : <Appointment>[];

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(8.0, 4.0, 8.0, 80.0),
          children: [
            DateHeader(
              hijriAdjustment: (user?.hijriAdjustment ?? 0).toInt(),
            ),
            
            const SizedBox(height: 2),

            AppointmentCard(
              appointment: nextAppt,
              readOnly: true,
            ),

            if (otherAppts.isNotEmpty)
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: otherAppts.length,
                itemBuilder: (context, index) {
                  final currentAppt = otherAppts[index];
                  final prevAppt = index == 0 ? nextAppt : otherAppts[index - 1];

                  Widget? separator;
                  if (!DateUtils.isSameDay(prevAppt.date, currentAppt.date)) {
                    final diff = currentAppt.date.difference(prevAppt.date);
                    final locale = Localizations.localeOf(context).languageCode;
                    final durationText = AppDateFormatter.formatDuration(diff, locale, context.l10n);
                    final dateText = AppDateFormatter.formatMediumDate(prevAppt.date, locale);

                    separator = TimelineSeparator(
                      dateText: dateText,
                      durationText: durationText,
                    );
                  }

                  return Column(
                    children: [
                      if (separator != null) separator,
                      AppointmentCard(
                        appointment: currentAppt,
                        readOnly: true,
                      ),
                    ],
                  );
                },
              ),
            const SizedBox(height: AppDimens.spaceGiant),
          ],
        ),
      ),
    );
  }
}
