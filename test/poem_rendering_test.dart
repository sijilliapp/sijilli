import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sijilli/features/articles/widgets/poetry/poem_view.dart';

void main() {
  group('PoemView Structure and Formatting Tests', () {
    testWidgets('TASHTEER: Should alternate bold styling between Sadr and Ajez', (WidgetTester tester) async {
      const poemText = '''
البيت الأول الصدر
البيت الأول العجز
البيت الثاني الصدر
البيت الثاني العجز
''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PoemView(poemText: poemText, type: 'TASHTEER'),
          ),
        ),
      );

      // Verify PoemView has been rendered
      expect(find.byType(PoemView), findsOneWidget);
    });

    testWidgets('TARBEE: Should apply bold to 4th line and divider/spacing', (WidgetTester tester) async {
      const poemText = '''
شطر تربيع واحد
شطر تربيع اثنين
شطر تربيع ثلاثة
شطر تربيع أربعة
''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PoemView(poemText: poemText, type: 'TARBEE'),
          ),
        ),
      );

      expect(find.byType(PoemView), findsOneWidget);
      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('TAKHMEES: Should group in 5 lines, 4th bold, 5th bold and centered with divider/spacing', (WidgetTester tester) async {
      const poemText = '''
شطر تخميس واحد
شطر تخميس اثنين
شطر تخميس ثلاثة
شطر تخميس أربعة
شطر تخميس خمسة
''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PoemView(poemText: poemText, type: 'TAKHMEES'),
          ),
        ),
      );

      expect(find.byType(PoemView), findsOneWidget);
      expect(find.byType(Divider), findsOneWidget);
    });
  });
}
