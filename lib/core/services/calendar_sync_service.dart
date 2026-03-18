import 'package:device_calendar/device_calendar.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../../models/appointment.dart';

class CalendarSyncService {
  final DeviceCalendarPlugin _deviceCalendarPlugin = DeviceCalendarPlugin();

  Future<int> syncAppointments(List<Appointment> appointments) async {
    // 1. Check/Request Permissions
    var status = await Permission.calendarFullAccess.status;
    if (!status.isGranted) {
      status = await Permission.calendarFullAccess.request();
      if (!status.isGranted) return -1; // Permission denied
    }

    // 2. Get Default Calendar
    final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
    if (!calendarsResult.isSuccess || calendarsResult.data == null || calendarsResult.data!.isEmpty) {
      return -2; // No calendars found
    }

    // Prefer a writable, non-read-only calendar
    final calendar = calendarsResult.data!.firstWhere(
      (c) => c.isReadOnly == false,
      orElse: () => calendarsResult.data!.first,
    );

    int newEventsCount = 0;

    for (final appt in appointments) {
      // 3. Duplicate Check
      // We check for events with same title and same start time 
      // within a window to avoid duplicates.
      final bool exists = await _eventExists(calendar.id!, appt);
      if (exists) continue;

      // 4. Create Event
      final event = Event(
        calendar.id,
        title: appt.title,
        description: (appt.description ?? '') + 
            ((appt.streamLink != null && appt.streamLink!.isNotEmpty) 
                ? '\n\nLink: ${appt.streamLink}' 
                : ''),
        location: appt.fullLocation,
        start: tz.TZDateTime.from(appt.startAt, tz.local),
        end: tz.TZDateTime.from(appt.startAt.add(Duration(minutes: appt.duration)), tz.local),
        allDay: appt.isAllDay,
      );

      final result = await _deviceCalendarPlugin.createOrUpdateEvent(event);
      if (result?.isSuccess ?? false) {
        newEventsCount++;
      }
    }

    return newEventsCount;
  }

  Future<bool> _eventExists(String calendarId, Appointment appt) async {
    final start = appt.startAt.subtract(const Duration(minutes: 5));
    final end = appt.startAt.add(const Duration(minutes: 5));

    final retrieveResult = await _deviceCalendarPlugin.retrieveEvents(
      calendarId,
      RetrieveEventsParams(startDate: start, endDate: end),
    );

    if (retrieveResult.isSuccess && retrieveResult.data != null) {
      return retrieveResult.data!.any((e) => e.title == appt.title);
    }
    return false;
  }
}
