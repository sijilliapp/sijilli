import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sijilli/features/add/providers/add_event_provider.dart';
import 'package:sijilli/models/appointment.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Add Event Mode & Time Suggestions Tests (اختبارات النمط السريع وترتيب كبسولات الأوقات)', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final tempDir = await Directory.systemTemp.createTemp();
      Hive.init(tempDir.path);
    });

    test('يجب أن يكون النمط الافتراضي هو النمط المتقدم (advanced)', () {
      final provider = AddEventProvider();
      expect(provider.mode, AddEventMode.advanced);
    });

    test('يجب حفظ النمط الأخير والاحتفاظ به عبر SharedPreferences', () async {
      final provider = AddEventProvider();
      await provider.setMode(AddEventMode.advanced);
      expect(provider.mode, AddEventMode.advanced);

      final newProvider = AddEventProvider();
      await newProvider.loadSavedMode();
      expect(newProvider.mode, AddEventMode.advanced);
    });

    test('يجب أن تُرتّب الأوقات المقترحة بحسب تكرار الاستخدام وليس بالترتيب الزمني', () async {
      final provider = AddEventProvider();
      final now = DateTime.now();

      Appointment makeAppt(String id, int hour, int minute) {
        final start = DateTime(now.year, now.month, now.day, hour, minute);
        return Appointment(
          id: id,
          title: 'موعد $id',
          hostId: 'u1',
          startAt: start,
          date: start,
          time: '${start.hour}:${start.minute}',
          createdAt: now,
          updatedAt: now,
        );
      }

      final List<Appointment> history = [
        makeAppt('1', 20, 0),
        makeAppt('2', 20, 0),
        makeAppt('3', 20, 0),
        makeAppt('4', 15, 30),
        makeAppt('5', 15, 30),
        makeAppt('6', 10, 0),
      ];

      await provider.init(null, history);

      final frequentTimes = provider.frequentTimes;
      expect(frequentTimes.isNotEmpty, isTrue);

      // الوقت الأول يجب أن يكون 20:00 (الأكثر تكراراً 3 مرات)
      expect(frequentTimes[0], equals(const TimeOfDay(hour: 20, minute: 0)));

      // الوقت الثاني يجب أن يكون 15:30 (تكرر مرتان)
      expect(frequentTimes[1], equals(const TimeOfDay(hour: 15, minute: 30)));

      // الوقت الثالث يجب أن يكون 10:00 (تكرر مرة واحدة)
      expect(frequentTimes[2], equals(const TimeOfDay(hour: 10, minute: 0)));
    });
  });
}
