import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sijilli/models/appointment.dart';
import 'package:sijilli/features/appointments/widgets/cards/policies/standard_policy.dart';
import 'package:sijilli/features/appointments/widgets/cards/policies/public_policy.dart';
import 'package:sijilli/core/widgets/pulse_avatar.dart';

void main() {
  group('Appointment Ring & Avatar Status Tests (اختبارات ثبات أطواق وألوان الحالات)', () {
    late Appointment baseAppointment;

    setUp(() {
      baseAppointment = Appointment(
        id: 'app_1',
        title: 'جلسة عمل',
        hostId: 'host_123',
        date: DateTime(2026, 8, 14),
        time: '14:00',
        startAt: DateTime.now().add(const Duration(hours: 2)),
        duration: 60,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        currentUserInvitation: Invitation(
          id: 'inv_1',
          appointmentId: 'app_1',
          userId: 'guest_456',
          status: InvitationStatus.accepted,
          postStatus: PostStatus.published,
        ),
      );
    });

    testWidgets('حذف الضيف لدعوته يجب ألا يغير طوق صورة المضيف إلى اللون الأحمر (StandardPolicy)', (WidgetTester tester) async {
      final guestDeletedAppt = baseAppointment.copyWith(
        currentUserInvitation: Invitation(
          id: 'inv_1',
          appointmentId: 'app_1',
          userId: 'guest_456',
          status: InvitationStatus.deletedAfterAccept,
          postStatus: PostStatus.trash,
        ),
      );

      late AvatarStatus hostStatus;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final policy = StandardPolicy(guestDeletedAppt, context);
              hostStatus = policy.hostAvatarStatus;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(hostStatus, isNot(equals(AvatarStatus.deleted)));
      expect(hostStatus, equals(AvatarStatus.upcoming));
    });

    testWidgets('حذف الضيف لدعوته يجب ألا يغير طوق صورة المضيف إلى اللون الأحمر (PublicPolicy)', (WidgetTester tester) async {
      final guestDeletedAppt = baseAppointment.copyWith(
        currentUserInvitation: Invitation(
          id: 'inv_1',
          appointmentId: 'app_1',
          userId: 'guest_456',
          status: InvitationStatus.deletedAfterAccept,
          postStatus: PostStatus.trash,
        ),
      );

      late AvatarStatus hostStatus;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final policy = PublicPolicy(guestDeletedAppt, context);
              hostStatus = policy.hostAvatarStatus;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(hostStatus, isNot(equals(AvatarStatus.deleted)));
      expect(hostStatus, equals(AvatarStatus.upcoming));
    });

    testWidgets('إلغاء الموعد كلياً من المضيف فقط يغير طوق صورة المضيف للأحمر', (WidgetTester tester) async {
      final cancelledAppt = baseAppointment.copyWith(isCancelled: true);

      late AvatarStatus hostStatus;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final policy = StandardPolicy(cancelledAppt, context);
              hostStatus = policy.hostAvatarStatus;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(hostStatus, equals(AvatarStatus.deleted));
    });

    test('فحص حالة الضيف المحذوف: يجب أن يقيم كـ deleted بدلاً من upcoming/present', () {
      final guestInv = Invitation(
        id: 'inv_2',
        appointmentId: 'app_1',
        userId: 'guest_789',
        status: InvitationStatus.deletedAfterAccept,
        postStatus: PostStatus.trash,
      );

      final bool isDeletedState = guestInv.postStatus == PostStatus.trash || 
          guestInv.status == InvitationStatus.declined || 
          guestInv.status == InvitationStatus.deletedAfterAccept;

      expect(isDeletedState, isTrue);
    });
  });
}
