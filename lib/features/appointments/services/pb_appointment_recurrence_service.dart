import 'package:pocketbase/pocketbase.dart';
import 'package:hijri/hijri_calendar.dart';
import '../../../core/services/pocketbase_client.dart';
import '../../../models/appointment.dart';

class PbAppointmentRecurrenceService {
  final PocketBase _pb = PocketBaseClient.instance.pb;
  static const String collectionAppointments = 'appointments';
  static const String collectionInvitations = 'invitations';

  /// ينفذ عملية التدوير: أرشفة النسخة الحالية وتحديث السجل للمستقبل
  Future<void> performRollover(Appointment appt) async {
    print('🔄 Performing Rollover for: ${appt.title} (${appt.id})');
    try {
      // 1. Snapshot: Save the passed event as history
      await _createSnapshot(appt);

      // 2. Update Master: Move to next date
      await _updateMasterRecord(appt);
      
      print('✅ Rollover Complete');
    } catch (e) {
      print('❌ Rollover Failed: $e');
      rethrow;
    }
  }

  Future<void> _createSnapshot(Appointment appt) async {
    print('📸 Creating Snapshot...');
    final body = appt.toJson();
    body.remove('id'); 
    body.remove('created');
    body.remove('updated');
    body['is_snapshot'] = true; 
    
    // Create the "Historic" Appointment
    final snapshotRecord = await _pb.collection(collectionAppointments).create(body: body);
    final snapshotId = snapshotRecord.id;

    // 2. Clone Invitations
    final invites = await _pb.collection(collectionInvitations).getFullList(
      filter: 'appointment = "${appt.id}"',
    );

    for (final inv in invites) {
      final invBody = inv.toJson();
      invBody.remove('id');
      invBody.remove('created');
      invBody.remove('updated');
      invBody['appointment'] = snapshotId;
      invBody['post_status'] = 'archived'; 
      
      await _pb.collection(collectionInvitations).create(body: invBody);
    }
    print('✅ Snapshot Created: $snapshotId with ${invites.length} invitations');
  }

  Future<void> _updateMasterRecord(Appointment appt) async {
    print('⏩ Updating Master Record...');
    
    // Calculate Next Date
    final nextDate = _calculateNextDate(appt);
    
    // Calculate Next Index
    final nextIndex = (appt.recurrenceIndex ?? 0) + 1;
    
    final body = {
      'start_at': nextDate.toUtc().toIso8601String(),
      'date': nextDate.toIso8601String().split('T')[0], 
      'recurrence_index': nextIndex,
    };
    
    if (appt.dateType == 'hijri') {
       HijriCalendar.setLocal('ar');
       final h = HijriCalendar.fromDate(nextDate);
       body['hijri_date'] = '${h.hYear}-${h.hMonth.toString().padLeft(2,'0')}-${h.hDay.toString().padLeft(2,'0')}';
       body['hijri_month'] = h.hMonth;
    }

    await _pb.collection(collectionAppointments).update(appt.id, body: body);
    print('✅ Master Record Updated to: $nextDate (Index: $nextIndex)');
  }

  DateTime _calculateNextDate(Appointment appt) {
    final current = appt.startAt;
    
    if (appt.dateType == 'hijri') {
       final h = HijriCalendar.fromDate(current);
       int hYear = h.hYear;
       int hMonth = h.hMonth;
       int hDay = h.hDay;

       if (appt.recurrenceType == 'daily') {
          return current.add(const Duration(days: 1));
       } else if (appt.recurrenceType == 'weekly') {
          return current.add(const Duration(days: 7));
       } else if (appt.recurrenceType == 'monthly') {
          hMonth++;
          if (hMonth > 12) {
             hMonth = 1;
             hYear++;
          }
       } else if (appt.recurrenceType == 'annual') {
          hYear++;
       }

       final hCalc = HijriCalendar();
       hCalc.hYear = hYear;
       hCalc.hMonth = hMonth;
       hCalc.hDay = hDay;
       
       DateTime next;
       if (hCalc.isValid()) {
         next = hCalc.hijriToGregorian(hYear, hMonth, hDay);
       } else {
          next = hCalc.hijriToGregorian(hYear, hMonth, 29);
       }
       
       return DateTime(
         next.year, next.month, next.day,
         current.hour, current.minute, current.second
       );

    } else {
      switch (appt.recurrenceType) {
        case 'daily':
          return current.add(const Duration(days: 1));
        case 'weekly':
          return current.add(const Duration(days: 7));
        case 'monthly':
          int nextMonth = current.month + 1;
          int nextYear = current.year;
          if (nextMonth > 12) {
            nextMonth = 1;
            nextYear++;
          }
          final lastDayOfNextMonth = DateTime(nextYear, nextMonth + 1, 0).day;
          final nextDay = current.day > lastDayOfNextMonth ? lastDayOfNextMonth : current.day;
          return DateTime(nextYear, nextMonth, nextDay, current.hour, current.minute);
          
        case 'annual':
           int nextYear = current.year + 1;
           if (current.month == 2 && current.day == 29) {
             return DateTime(nextYear, 2, 28, current.hour, current.minute);
           }
           return DateTime(nextYear, current.month, current.day, current.hour, current.minute);
        default:
          return current.add(const Duration(days: 1));
      }
    }
  }
}
