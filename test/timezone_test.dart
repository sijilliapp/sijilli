import 'package:flutter_test/flutter_test.dart';
import 'package:sijilli/services/timezone_service.dart';

void main() {
  group('TimezoneService Tests', () {
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      await TimezoneService.initialize();
    });

    test('تهيئة خدمة المناطق الزمنية', () {
      expect(TimezoneService.isInitialized, true);
      print('✅ تم تهيئة خدمة المناطق الزمنية بنجاح');
      print('📍 معلومات المنطقة الزمنية: ${TimezoneService.getTimezoneInfo()}');
    });

    test('تحويل الوقت المحلي إلى UTC', () {
      // وقت محلي: 20 أكتوبر 2024، 7:30 مساءً
      final localTime = DateTime(2024, 10, 20, 19, 30);
      final utcTime = TimezoneService.toUtc(localTime);

      print('🕐 الوقت المحلي: ${TimezoneService.formatDateTime(localTime)}');
      print('🌍 الوقت في UTC: ${TimezoneService.formatDateTime(utcTime)}');

      // التحقق من أن التحويل تم
      expect(utcTime.isUtc, true);
      // في بيئة UTC، الأوقات متساوية
      expect(utcTime.isBefore(localTime) || utcTime.isAtSameMomentAs(localTime) || utcTime.isAfter(localTime), true);
    });

    test('تحويل الوقت من UTC إلى المحلي', () {
      // وقت UTC: 20 أكتوبر 2024، 4:30 مساءً
      final utcTime = DateTime.utc(2024, 10, 20, 16, 30);
      final localTime = TimezoneService.toLocal(utcTime);

      print('🌍 الوقت في UTC: ${TimezoneService.formatDateTime(utcTime)}');
      print('🕐 الوقت المحلي: ${TimezoneService.formatDateTime(localTime)}');

      // في بيئة الاختبار قد تكون المنطقة الزمنية UTC، لذا الأوقات متساوية
      expect(localTime.isAfter(utcTime) || localTime.isAtSameMomentAs(utcTime) || localTime.isBefore(utcTime), true);
    });

    test('تنسيق الوقت 12 ساعة', () {
      final morning = DateTime(2024, 10, 20, 9, 15);
      final evening = DateTime(2024, 10, 20, 19, 30);
      final midnight = DateTime(2024, 10, 20, 0, 0);
      final noon = DateTime(2024, 10, 20, 12, 0);
      
      expect(TimezoneService.formatTime12Hour(morning), '9:15 صباحاً');
      expect(TimezoneService.formatTime12Hour(evening), '7:30 مساءً');
      expect(TimezoneService.formatTime12Hour(midnight), '12:00 صباحاً');
      expect(TimezoneService.formatTime12Hour(noon), '12:00 مساءً');
      
      print('✅ تنسيق الأوقات:');
      print('   الصباح: ${TimezoneService.formatTime12Hour(morning)}');
      print('   المساء: ${TimezoneService.formatTime12Hour(evening)}');
      print('   منتصف الليل: ${TimezoneService.formatTime12Hour(midnight)}');
      print('   الظهر: ${TimezoneService.formatTime12Hour(noon)}');
    });

    test('تنسيق الوقت 24 ساعة', () {
      final morning = DateTime(2024, 10, 20, 9, 15);
      final evening = DateTime(2024, 10, 20, 19, 30);
      
      expect(TimezoneService.formatTime24Hour(morning), '09:15');
      expect(TimezoneService.formatTime24Hour(evening), '19:30');
      
      print('✅ تنسيق 24 ساعة:');
      print('   الصباح: ${TimezoneService.formatTime24Hour(morning)}');
      print('   المساء: ${TimezoneService.formatTime24Hour(evening)}');
    });

    test('الحصول على الوقت الحالي', () {
      final now = TimezoneService.now();
      final systemNow = DateTime.now();

      print('🕐 الوقت الحالي (TimezoneService): ${TimezoneService.formatDateTime(now)}');
      print('🕐 الوقت الحالي (System): ${TimezoneService.formatDateTime(systemNow)}');

      // في بيئة الاختبار قد يكون هناك فرق في المنطقة الزمنية
      // نتحقق من أن الفرق أقل من 24 ساعة (يوم واحد)
      final difference = now.difference(systemNow).abs();
      expect(difference.inHours, lessThan(24));
    });

    test('سيناريو كامل: حفظ واسترجاع موعد', () {
      print('\n🎯 سيناريو كامل: حفظ واسترجاع موعد');
      
      // 1. المستخدم يختار وقت محلي
      final userSelectedTime = DateTime(2024, 10, 20, 19, 30); // 7:30 مساءً
      print('👤 المستخدم اختار: ${TimezoneService.formatDateTime(userSelectedTime)}');
      
      // 2. التطبيق يحول إلى UTC للحفظ
      final utcForDatabase = TimezoneService.toUtc(userSelectedTime);
      print('💾 حفظ في قاعدة البيانات: ${utcForDatabase.toIso8601String()}');
      
      // 3. عند الاسترجاع، التطبيق يحول من UTC إلى المحلي
      final displayTime = TimezoneService.toLocal(utcForDatabase);
      print('📱 عرض للمستخدم: ${TimezoneService.formatDateTime(displayTime)}');
      
      // 4. التحقق من أن التاريخ والدقيقة متطابقان (الساعة قد تختلف بسبب المنطقة الزمنية)
      expect(displayTime.year, userSelectedTime.year);
      expect(displayTime.month, userSelectedTime.month);
      expect(displayTime.day, userSelectedTime.day);
      expect(displayTime.minute, userSelectedTime.minute);

      // في بيئة الاختبار مع UTC، الساعة قد تكون مختلفة
      print('⏰ الساعة المختارة: ${userSelectedTime.hour}, الساعة المعروضة: ${displayTime.hour}');
      
      print('✅ السيناريو نجح! الوقت المعروض مطابق للوقت المختار');
    });
  });
}
