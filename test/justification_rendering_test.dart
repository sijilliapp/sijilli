import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sijilli/core/providers/settings_provider.dart';
import 'package:sijilli/features/articles/widgets/article_content_renderer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ArticleContentRenderer Justification Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('Should justify paragraphs and apply word spacing when justifyArticles setting is enabled', (WidgetTester tester) async {
      // Create settings provider and enable justification
      final settingsProvider = SettingsProvider();
      await settingsProvider.loadSettings();
      await settingsProvider.setJustifyArticles(true);

      // Paragraph with >= 10 words
      const text = 'هذا سطر طويل كافٍ لتجربة ميزة الضبط التلقائي للفقرات للتأكد من المحاذاة والتباعد الجميل';

      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settingsProvider,
          child: const MaterialApp(
            home: Scaffold(
              body: ArticleContentRenderer(text: text),
            ),
          ),
        ),
      );

      // Find the rendered SelectableText widget
      final textFinder = find.byType(SelectableText);
      expect(textFinder, findsOneWidget);

      final selectableTextWidget = tester.widget<SelectableText>(textFinder);
      
      // Verify that it is justified
      expect(selectableTextWidget.textAlign, equals(TextAlign.justify));

      // Verify that wordSpacing is set to -0.4 to prevent huge spacing gaps on the children spans
      final span = selectableTextWidget.textSpan as TextSpan?;
      expect(span, isNotNull);
      expect(span!.children, isNotEmpty);
      expect(span.children!.first.style?.wordSpacing, equals(-0.4));
    });

    testWidgets('Should not justify short paragraphs even when justifyArticles is enabled', (WidgetTester tester) async {
      final settingsProvider = SettingsProvider();
      await settingsProvider.loadSettings();
      await settingsProvider.setJustifyArticles(true);

      // Paragraph with < 10 words
      const text = 'سطر قصير جداً';

      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settingsProvider,
          child: const MaterialApp(
            home: Scaffold(
              body: ArticleContentRenderer(text: text),
            ),
          ),
        ),
      );

      final textFinder = find.byType(SelectableText);
      expect(textFinder, findsOneWidget);

      final selectableTextWidget = tester.widget<SelectableText>(textFinder);
      
      // Verify that it remains start-aligned (natural alignment)
      expect(selectableTextWidget.textAlign, equals(TextAlign.start));

      final span = selectableTextWidget.textSpan as TextSpan?;
      expect(span, isNotNull);
      expect(span!.style?.wordSpacing, isNull);
    });

    testWidgets('Should not justify standard paragraphs when justifyArticles is disabled', (WidgetTester tester) async {
      final settingsProvider = SettingsProvider();
      await settingsProvider.loadSettings();
      await settingsProvider.setJustifyArticles(false);

      const text = 'هذا سطر طويل كافٍ لتجربة ميزة الضبط التلقائي للفقرات للتأكد من المحاذاة والتباعد الجميل';

      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settingsProvider,
          child: const MaterialApp(
            home: Scaffold(
              body: ArticleContentRenderer(text: text),
            ),
          ),
        ),
      );

      final textFinder = find.byType(SelectableText);
      expect(textFinder, findsOneWidget);

      final selectableTextWidget = tester.widget<SelectableText>(textFinder);
      
      // Verify that it remains start-aligned
      expect(selectableTextWidget.textAlign, equals(TextAlign.start));
    });
  });
}
