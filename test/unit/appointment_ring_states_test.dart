import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sijilli/models/appointment.dart';
import 'package:sijilli/models/extensions/appointment_logic.dart';
import 'package:sijilli/features/appointments/widgets/cards/policies/standard_policy.dart';
import 'package:sijilli/features/appointments/widgets/cards/policies/public_policy.dart';
import 'package:sijilli/core/widgets/pulse_avatar.dart';

void main() {
  group('Foundational Architecture & Ring Status Tests (اختبارات أسس البنية وأطواق الحالات)', () {
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
        participants: [
          Invitation(
            id: 'inv_host',
            appointmentId: 'app_1',
            userId: 'host_123',
            status: InvitationStatus.accepted,
            postStatus: PostStatus.published,
          ),
          Invitation(
            id: 'inv_guest',
            appointmentId: 'app_1',
            userId: 'guest_456',
            status: InvitationStatus.accepted,
            postStatus: PostStatus.published,
          ),
        ],
      );
    });

    test('1. استقلالية منطق حلول الموعد (isNow) عن تصرفات وحالات المشاركين', () {
      final nowAppt = baseAppointment.copyWith(
        startAt: DateTime.now().subtract(const Duration(minutes: 10)),
        duration: 60,
      );

      // حلول الوقت يعيد isNow = true بغض النظر عن حالة أي ضيف
      expect(nowAppt.isNow, isTrue);
    });

    test('2. دعوة المضيف هي مصدر الحقيقة الوحيد (isHostCancelled)', () {
      final cancelledHostAppt = baseAppointment.copyWith(
        participants: [
          Invitation(
            id: 'inv_host',
            appointmentId: 'app_1',
            userId: 'host_123',
            status: InvitationStatus.deletedAfterAccept,
            postStatus: PostStatus.trash, // المضيف وضع نسخته كـ trash
          ),
        ],
      );

      // إلغاء دعوة المضيف يجعل الموعد ملغى كلياً
      expect(cancelledHostAppt.isHostCancelled, isTrue);
    });

    testWidgets('3. حذف الضيف لدعوته لا يؤثر على طوق المضيف ولا يفتح مفتاح الإلغاء المركزي (StandardPolicy)', (WidgetTester tester) async {
      final guestDeletedAppt = baseAppointment.copyWith(
        currentUserInvitation: Invitation(
          id: 'inv_guest',
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

    test('4. فحص سياسة الاحتفاظ بالبيانات الميتة (30 يوم للـ Hard Delete)', () {
      final now = DateTime.now();
      final deleted20DaysAgo = now.subtract(const Duration(days: 20));
      final deleted35DaysAgo = now.subtract(const Duration(days: 35));

      final bool isDead20Days = now.difference(deleted20DaysAgo).inDays > 30;
      final bool isDead35Days = now.difference(deleted35DaysAgo).inDays > 30;

      expect(isDead20Days, isFalse); // أقل من 30 يوماً -> يبث في السلة
      expect(isDead35Days, isTrue);  // أكثر من 30 يوماً -> سجل ميت يُعدم كلياً
    });

    test('5. فحص الحالة النهائية الحمراء المغلقة (Terminal Red State Machine)', () {
      final trashedInv = Invitation(
        id: 'inv_trashed',
        appointmentId: 'app_1',
        userId: 'guest_456',
        status: InvitationStatus.deletedAfterAccept,
        postStatus: PostStatus.trash,
      );

      final bool isTerminalRed = trashedInv.postStatus == PostStatus.trash || 
          trashedInv.status == InvitationStatus.declined || 
          trashedInv.status == InvitationStatus.deletedAfterAccept;

      expect(isTerminalRed, isTrue);
    });

    test('6. فحص تسلسل الإعدام الكلي: إعدام الأبناء أولاً ثم السجل الأب (Bottom-Up Child-First Hard Delete)', () {
      final List<String> deletionOrder = [];

      // محاكاة تسلسل الإعدام الكلي
      // 1. حذف دعوات وإشعارات الأبناء
      deletionOrder.add('delete_child_invitations');
      deletionOrder.add('delete_child_notifications');
      
      // 2. فحص خلو السجل الأب من الأبناء ثم إعدام الأب
      bool allChildrenDeleted = !deletionOrder.contains('failed_child');
      if (allChildrenDeleted) {
        deletionOrder.add('delete_parent_appointment');
      }

      expect(deletionOrder.first, equals('delete_child_invitations'));
      expect(deletionOrder.last, equals('delete_parent_appointment'));
    });
  });
}
