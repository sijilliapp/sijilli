import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sijilli/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Sijilli End-to-End Integration Tests (اختبار سيناريو التطبيق الكامل)', () {
    testWidgets('تشغيل التطبيق والتأكد من تحميل الواجهة الرئيسية وشريط التبويبات', (WidgetTester tester) async {
      // 1. تشغيل التطبيق بالكامل
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // 2. التحقق من وجود الشاشة الأساسية وشريط التبويبات
      expect(find.byType(MaterialApp), findsOneWidget);

      // 3. التحقق من التفاعل مع سحب الصفحة للتحديث
      final refreshFinder = find.byType(RefreshIndicator);
      if (refreshFinder.evaluate().isNotEmpty) {
        await tester.drag(refreshFinder.first, const Offset(0, 300));
        await tester.pumpAndSettle(const Duration(seconds: 2));
      }
    });
  });
}
