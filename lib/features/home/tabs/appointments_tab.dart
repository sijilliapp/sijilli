import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/utils/app_date_formatter.dart';
import '../../../models/appointment.dart';
import '../../appointments/providers/appointment_provider.dart';
import '../../appointments/widgets/appointment_card.dart';
import '../../auth/providers/auth_provider.dart';
import '../widgets/date_header.dart';
import '../widgets/timeline_separator.dart';

import '../../../core/extensions/context_l10n.dart';

import '../../add/providers/add_event_provider.dart';
import '../screens/home_screen.dart';

class AppointmentsTab extends StatefulWidget {
  const AppointmentsTab({super.key});

  @override
  State<AppointmentsTab> createState() => _AppointmentsTabState();
}

class _AppointmentsTabState extends State<AppointmentsTab> {
  final Map<String, GlobalKey> _cardKeys = {};

  void _showAppointmentDetails(BuildContext context, Appointment appointment) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.5,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              appointment.title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  AppDateFormatter.formatFullDate(appointment.date, Localizations.localeOf(context).languageCode),
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (appointment.hasLocation) ...[
              Text(context.l10n.location, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(appointment.fullLocation!),
              const SizedBox(height: 24),
            ],
            Text(context.l10n.time, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              appointment.isAllDay 
                  ? context.l10n.durationAllDay 
                  : AppDateFormatter.formatTime12h(appointment.fullDateTime, Localizations.localeOf(context).languageCode)
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(context.l10n.close),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppointmentProvider>(
      builder: (context, provider, _) {
        final hasData = provider.appointments.isNotEmpty;

        if (provider.isLoading && !hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.errorMessage != null && !hasData) {
           return Center(
             child: Padding(
               padding: const EdgeInsets.all(AppDimens.padding),
               child: Column(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                   const SizedBox(height: 16),
                   Text('${context.l10n.errorOccurred}: ${provider.errorMessage}', textAlign: TextAlign.center),
                   const SizedBox(height: 16),
                   ElevatedButton(
                     onPressed: () => provider.fetchAppointments(),
                     child: Text(context.l10n.retry),
                   ),
                 ],
               ),
             ),
           );
        }
        
        // ... rest of logic remains same ...
        final userId = context.read<AuthProvider>().user?.id;
        final rawAppointments = provider.appointments.where((a) {
          final status = a.currentUserInvitation?.status;
          return a.hostId == userId || 
                 status == InvitationStatus.accepted;
        }).toList();

        final List<Appointment> appointments = [];
        final Set<String> processedGroups = {};
        rawAppointments.sort((a, b) => a.startAt.compareTo(b.startAt));

        for (var a in rawAppointments) {
          if (a.appointmentGroupId == null || a.appointmentGroupId!.isEmpty) {
            appointments.add(a);
            continue;
          }
          if (a.isPast) {
            appointments.add(a);
            continue;
          }
          if (!processedGroups.contains(a.appointmentGroupId)) {
            appointments.add(a);
            processedGroups.add(a.appointmentGroupId!);
          }
        }

        appointments.sort((a, b) {
          int score(Appointment app) {
            if (app.isNow) return 0;
            if (app.isFuture || app.isUpcoming) return 1;
            return 2;
          }
          final sA = score(a);
          final sB = score(b);
          if (sA != sB) return sA.compareTo(sB);
          if (sA == 2) return b.startAt.compareTo(a.startAt);
          return a.startAt.compareTo(b.startAt);
        });

        return RefreshIndicator(
          onRefresh: () => provider.fetchAppointments(),
          color: AppColors.primary,
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(8.0, 4.0, 8.0, 80.0),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Consumer<AuthProvider>(
                          builder: (context, auth, _) {
                            return DateHeader(
                              hijriAdjustment: (auth.user?.hijriAdjustment ?? 0).toInt(),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),

                if (appointments.isNotEmpty) ...[
                  Builder(
                    builder: (context) {
                      final addEventProvider = context.watch<AddEventProvider>();
                      final highlightId = addEventProvider.highlightedAppointmentId;

                      if (highlightId != null) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          final key = _cardKeys[highlightId];
                          final cardContext = key?.currentContext;
                          if (cardContext != null) {
                            final homeState = context.findAncestorStateOfType<HomeScreenState>();
                            if (homeState != null) {
                              homeState.setSnappingSuspended(true);
                              Scrollable.ensureVisible(
                                cardContext,
                                duration: const Duration(milliseconds: 1200),
                                curve: Curves.easeInOut,
                              ).then((_) {
                                Future.delayed(const Duration(milliseconds: 500), () {
                                  homeState.setSnappingSuspended(false);
                                });
                              });
                            } else {
                              Scrollable.ensureVisible(
                                cardContext,
                                duration: const Duration(milliseconds: 1200),
                                curve: Curves.easeInOut,
                              );
                            }
                          }
                          context.read<AddEventProvider>().clearHighlight();
                        });
                      }

                      final List<Widget> timelineWidgets = [];
                      for (int i = 0; i < appointments.length; i++) {
                        final currentAppt = appointments[i];
                        final prevAppt = i > 0 ? appointments[i - 1] : null;
                        if (prevAppt != null && !DateUtils.isSameDay(prevAppt.date, currentAppt.date)) {
                          final diff = currentAppt.date.difference(prevAppt.date);
                          final locale = Localizations.localeOf(context).languageCode;
                          final durationText = AppDateFormatter.formatDuration(diff, locale, context.l10n);
                          final dateText = AppDateFormatter.formatMediumDate(prevAppt.date, locale);
                          timelineWidgets.add(TimelineSeparator(dateText: dateText, durationText: durationText));
                        }
                        
                        final isHighlighted = currentAppt.id == highlightId;
                        final key = _cardKeys.putIfAbsent(currentAppt.id, () => GlobalKey());

                        timelineWidgets.add(
                          Column(
                            key: ValueKey(currentAppt.id),
                            children: [
                              AppointmentCard(
                                key: key,
                                appointment: currentAppt,
                                shouldGlow: isHighlighted,
                              ),
                            ],
                          )
                        );
                      }
                      return Column(children: timelineWidgets);
                    },
                  ),
                ] else ...[
                   Padding(
                     padding: const EdgeInsets.only(top: 60),
                     child: Center(
                       child: Column(
                         mainAxisAlignment: MainAxisAlignment.center,
                         children: [
                           Container(
                             padding: const EdgeInsets.all(20),
                             decoration: BoxDecoration(
                               color: AppColors.primary.withValues(alpha: 0.08),
                               shape: BoxShape.circle,
                             ),
                             child: Icon(Icons.event_note, size: 48, color: AppColors.primary.withValues(alpha: 0.5)),
                           ),
                           const SizedBox(height: 16),
                           Text(
                             context.l10n.welcomeToSijilli,
                             style: TextStyle(
                               fontSize: 18, 
                               fontWeight: FontWeight.bold,
                               color: AppColors.getTextPrimary(context)
                             ),
                           ),
                           const SizedBox(height: 8),
                           Text(
                             context.l10n.emptyAppointmentsDesc,
                             textAlign: TextAlign.center,
                             style: TextStyle(color: AppColors.getTextSecondary(context), height: 1.5),
                           ),
                         ],
                       ),
                     ),
                   ),
                ],
                const SizedBox(height: 80),
              ],
            ),
          ),
        );
      },
    );
  }
}
