import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:sijilli/features/articles/widgets/article_content_renderer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ArticleContentRenderer Image Parsing Tests', () {
    testWidgets('Should render CachedNetworkImage when [IMAGE] tag is encountered', (WidgetTester tester) async {
      const text = 'بعض النصوص قبل\n[IMAGE]\nبعض النصوص بعد';
      const imageUrl = 'https://sijilli.pockethost.io/api/files/articles/123/photo.jpg';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  ArticleContentRenderer(text: text, imageFiles: [imageUrl]),
                ],
              ),
            ),
          ),
        ),
      );

      // Verify that CachedNetworkImage is rendered
      expect(find.byType(CachedNetworkImage), findsOneWidget);
    });

    testWidgets('Should render warning container when [IMAGE] is specified but imageFiles is empty', (WidgetTester tester) async {
      const text = 'بعض النصوص قبل\n[IMAGE]\nبعض النصوص بعد';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  ArticleContentRenderer(text: text, imageFiles: []),
                ],
              ),
            ),
          ),
        ),
      );

      // Verify that warning icon is displayed instead
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.text('الصورة المدمجة الخاصة بهذا التضمين غير متوفرة'), findsOneWidget);
    });
  });
}
