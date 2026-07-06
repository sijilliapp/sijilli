import 'package:flutter_test/flutter_test.dart';
import 'package:sijilli/models/appointment.dart';

void main() {
  group('Appointment Logic Tests', () {
    final now = DateTime.now().toUtc();

    test('isNow should be true during the duration window', () {
      final appointment = Appointment(
        id: '1',
        title: 'Active Test',
        hostId: 'host1',
        startAt: now.subtract(const Duration(minutes: 10)), // Started 10 mins ago
        duration: 45,
        date: DateTime.now(),
        time: '12:00',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(appointment.isNow, isTrue);
      expect(appointment.isPast, isFalse);
    });

    test('isNow should be false after duration ends', () {
      final appointment = Appointment(
        id: '2',
        title: 'Past Test',
        hostId: 'host1',
        startAt: now.subtract(const Duration(minutes: 50)), // Started 50 mins ago (duration 45)
        duration: 45,
        date: DateTime.now(),
        time: '12:00',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(appointment.isNow, isFalse);
      expect(appointment.isPast, isTrue);
    });

    test('isNow should be true exactly at startAt', () {
      final appointment = Appointment(
        id: '3',
        title: 'Start Moment Test',
        hostId: 'host1',
        startAt: now,
        duration: 45,
        date: DateTime.now(),
        time: '12:00',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(appointment.isNow, isTrue);
    });

    test('statusText priority test', () {
      final appointment = Appointment(
        id: '4',
        title: 'Priority Test',
        hostId: 'host1',
        startAt: now.subtract(const Duration(minutes: 10)),
        duration: 45,
        date: DateTime.now(),
        time: '12:00',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(appointment.statusText, 'جاري الآن');
    });

    test('Location formatting tests when region is empty but building is provided', () {
      final appointment = Appointment(
        id: '5',
        title: 'Empty Region Test',
        hostId: 'host1',
        startAt: now,
        duration: 45,
        date: DateTime.now(),
        time: '12:00',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        region: '',
        building: 'مبنى البركة',
      );

      expect(appointment.fullLocation, 'مبنى البركة');
      expect(appointment.smartLocation, 'مبنى البركة');
    });

    test('Location formatting tests when region is null but building is provided', () {
      final appointment = Appointment(
        id: '6',
        title: 'Null Region Test',
        hostId: 'host1',
        startAt: now,
        duration: 45,
        date: DateTime.now(),
        time: '12:00',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        region: null,
        building: 'مبنى البركة',
      );

      expect(appointment.fullLocation, 'مبنى البركة');
      expect(appointment.smartLocation, 'مبنى البركة');
    });

    test('Location formatting tests when region is provided but building is empty', () {
      final appointment = Appointment(
        id: '7',
        title: 'Empty Building Test',
        hostId: 'host1',
        startAt: now,
        duration: 45,
        date: DateTime.now(),
        time: '12:00',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        region: 'المنطقة الشرقية',
        building: '',
      );

      expect(appointment.fullLocation, 'المنطقة الشرقية');
      expect(appointment.smartLocation, 'المنطقة الشرقية');
    });

    test('inviteToken and inviteLinkActive serialization tests', () {
      final appointment = Appointment(
        id: '8',
        title: 'Invite Token Test',
        hostId: 'host1',
        startAt: now,
        duration: 45,
        date: DateTime.now(),
        time: '12:00',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        inviteToken: 'test-uuid-token',
        inviteLinkActive: true,
      );

      expect(appointment.inviteToken, 'test-uuid-token');
      expect(appointment.inviteLinkActive, isTrue);

      final json = appointment.toJson();
      expect(json['invite_token'], 'test-uuid-token');
      expect(json['invite_link_active'], isTrue);

      final parsed = Appointment.fromJson(json);
      expect(parsed.inviteToken, 'test-uuid-token');
      expect(parsed.inviteLinkActive, isTrue);
    });
  });
}
