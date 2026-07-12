import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:sijilli/features/add/providers/add_event_provider.dart';
import 'package:sijilli/models/appointment.dart';
import 'package:sijilli/models/user.dart';

import 'dart:io';
import 'package:hive/hive.dart';

void main() {
  group('AddEventProvider Conflict Detection Tests', () {
    late AddEventProvider provider;
    late UserModel mockUser;
    late Directory tempDir;
    
    // We base our dates on 2026-01-15 19:00 local time
    final hospitalStartLocal = DateTime(2026, 1, 15, 19, 0);
    final hospitalStartUtc = hospitalStartLocal.toUtc();

    final mockHistory = [
      Appointment(
        id: 'hospital_id',
        title: 'موعد ضيافة',
        hostId: 'host_1',
        startAt: hospitalStartUtc,
        duration: 45,
        date: DateTime(2026, 1, 15),
        time: '19:00',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        recurrenceType: 'daily',
        recurrenceCount: 3,
        recurrenceIndex: 1,
      )
    ];

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('hive_test');
      Hive.init(tempDir.path);

      provider = AddEventProvider();
      mockUser = UserModel(
        id: 'host_1',
        username: 'test_user',
        email: 'test@sijilli.com',
        name: 'Test User',
        created: DateTime.now(),
        updated: DateTime.now(),
        joiningDate: DateTime.now(),
      );
    });

    tearDown(() async {
      await Hive.close();
    });

    test('Should detect conflict with recurring future occurrence (Jan 16 7:30 PM)', () async {
      // Initialize provider with history
      provider.init(null, mockHistory, currentUser: mockUser);

      // Set new event details to Jan 16, 7:30 PM
      provider.setDate(DateTime(2026, 1, 16));
      provider.setTime(const TimeOfDay(hour: 19, minute: 30));
      provider.setDuration(45); // Jan 16 7:30 PM - 8:15 PM (Overlaps Jan 16 7:00 PM - 7:45 PM)

      expect(provider.hasConflict, isTrue);
    });

    test('Should not detect conflict when time does not overlap on Jan 16 (Jan 16 8:00 PM)', () async {
      provider.init(null, mockHistory, currentUser: mockUser);

      provider.setDate(DateTime(2026, 1, 16));
      provider.setTime(const TimeOfDay(hour: 20, minute: 0));
      provider.setDuration(45); // Jan 16 8:00 PM - 8:45 PM (No overlap)

      expect(provider.hasConflict, isFalse);
    });

    test('Should not detect conflict after recurrence ends (Jan 18 7:00 PM)', () async {
      provider.init(null, mockHistory, currentUser: mockUser);

      provider.setDate(DateTime(2026, 1, 18));
      provider.setTime(const TimeOfDay(hour: 19, minute: 0));
      provider.setDuration(45); // Jan 18 7:00 PM - 7:45 PM (Out of range of 3 days daily recurrence)

      expect(provider.hasConflict, isFalse);
    });
  });
}
