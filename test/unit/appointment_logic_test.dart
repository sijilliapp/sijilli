import 'package:flutter_test/flutter_test.dart';
import 'package:sijilli/models/appointment.dart';
import 'package:sijilli/models/invitation.dart';
import 'package:sijilli/models/extensions/appointment_logic.dart';

void main() {
  group('Appointment Logic Tests (اختبارات أتمتة منطق المواعيد)', () {
    test('الموعد القادم المنشور والمقبول يجب أن يُحسب كـ isActiveUpcomingAccepted', () {
      final now = DateTime.now();
      final futureDate = now.add(const Duration(days: 5));

      final appointment = Appointment(
        id: 'appt_1',
        title: 'موعد تجريبي قادم',
        hostId: 'user_1',
        date: futureDate,
        startAt: futureDate,
        createdAt: now,
        updatedAt: now,
        time: '15:00',
        duration: 60,
        privacy: 'public',
        isCancelled: false,
        currentUserInvitation: Invitation(
          id: 'inv_1',
          appointmentId: 'appt_1',
          userId: 'user_1',
          status: InvitationStatus.accepted,
          postStatus: PostStatus.published,
          privacy: 'public',
        ),
      );

      expect(appointment.isActiveUpcomingAccepted, isTrue);
      expect(appointment.isPast, isFalse);
    });

    test('الموعد الملغى يجب ألا يُحسب كـ isActiveUpcomingAccepted', () {
      final now = DateTime.now();
      final futureDate = now.add(const Duration(days: 2));

      final appointment = Appointment(
        id: 'appt_2',
        title: 'موعد ملغى',
        hostId: 'user_1',
        date: futureDate,
        startAt: futureDate,
        createdAt: now,
        updatedAt: now,
        time: '18:00',
        duration: 30,
        privacy: 'public',
        isCancelled: true,
        currentUserInvitation: Invitation(
          id: 'inv_2',
          appointmentId: 'appt_2',
          userId: 'user_1',
          status: InvitationStatus.accepted,
          postStatus: PostStatus.published,
          privacy: 'public',
        ),
      );

      expect(appointment.isActiveUpcomingAccepted, isFalse);
    });

    test('تسلسل الخصوصية لجدول المواعيد يجب أن يعيد public أو null فقط لعدم كسر السيرفر', () {
      final now = DateTime.now();
      final apptPublic = Appointment(
        id: 'appt_3',
        title: 'عام',
        hostId: 'user_1',
        date: now,
        startAt: now,
        createdAt: now,
        updatedAt: now,
        time: '10:00',
        duration: 30,
        privacy: 'public',
      );

      final apptFollowers = Appointment(
        id: 'appt_4',
        title: 'معتمدون',
        hostId: 'user_1',
        date: now,
        startAt: now,
        createdAt: now,
        updatedAt: now,
        time: '10:00',
        duration: 30,
        privacy: 'followers',
      );

      final jsonPublic = apptPublic.toJson();
      final jsonFollowers = apptFollowers.toJson();

      expect(jsonPublic['privacy'], equals('public'));
      expect(jsonFollowers['privacy'], isNull);
    });
  });
}
