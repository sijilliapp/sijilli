import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sijilli/core/constants/app_colors.dart';

void main() {
  group('Theme & Colors Testing (اختبار أتمتة ألوان المظهر الليلي والنهاري)', () {
    testWidgets('فحص استجابة ألوان getBackground و getTextPrimary للمظهر النهاري (Light Theme)', (WidgetTester tester) async {
      late Color bg;
      late Color textPrimary;
      late Color cardBg;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Builder(
            builder: (context) {
              bg = AppColors.getBackground(context);
              textPrimary = AppColors.getTextPrimary(context);
              cardBg = AppColors.getCardBackground(context);
              return const SizedBox();
            },
          ),
        ),
      );

      // التأكد من استلام ألوان المظهر النهاري المناسبة
      expect(bg, equals(AppColors.lightBackground));
      expect(textPrimary, equals(AppColors.lightTextPrimary));
      expect(cardBg, equals(AppColors.lightCardBackground));
    });

    testWidgets('فحص استجابة ألوان getBackground و getTextPrimary للمظهر الليلي (Dark Theme)', (WidgetTester tester) async {
      late Color bg;
      late Color textPrimary;
      late Color cardBg;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Builder(
            builder: (context) {
              bg = AppColors.getBackground(context);
              textPrimary = AppColors.getTextPrimary(context);
              cardBg = AppColors.getCardBackground(context);
              return const SizedBox();
            },
          ),
        ),
      );

      // التأكد من استلام ألوان المظهر الليلي المناسبة
      expect(bg, equals(AppColors.darkBackground));
      expect(textPrimary, equals(AppColors.darkTextPrimary));
      expect(cardBg, equals(AppColors.darkCardBackground));
    });

    test('فحص التباين والوضوح: لون النص الداكن في النهاري وأبيض في الليلي', () {
      // النص النهاري يجب أن يكون داكناً لسهولة القراءة على خلفية فاتحة
      expect(AppColors.lightTextPrimary.computeLuminance(), lessThan(0.5));

      // النص الليلي يجب أن يكون فاتحاً لسهولة القراءة على خلفية داكنة
      expect(AppColors.darkTextPrimary.computeLuminance(), greaterThan(0.5));
    });
  });
}
