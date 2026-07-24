import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sijilli/features/articles/widgets/tag_chip.dart';
import 'package:sijilli/models/tag.dart';
import 'package:sijilli/models/user.dart';
import 'package:sijilli/features/articles/widgets/article_content_renderer.dart';
import 'package:sijilli/features/articles/widgets/youtube_video_with_actions.dart';
import 'package:cached_network_image/cached_network_image.dart';

void main() {
  testWidgets('TagChip renders tag name', (WidgetTester tester) async {
    const testTag = Tag(
      id: '1',
      name: 'شعر',
      colorHex: '4F46E5',
      userId: 'user1',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TagChip(tag: testTag),
        ),
      ),
    );

    expect(find.text('شعر'), findsOneWidget);
  });

  testWidgets('ArticleContentRenderer renders YoutubeVideoWithActions for youtube link', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ArticleContentRenderer(text: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
        ),
      ),
    );

    expect(find.byType(YoutubeVideoWithActions), findsOneWidget);
    expect(find.text('تشغيل الفيديو'), findsOneWidget);
  });

  testWidgets('ArticleContentRenderer renders CachedNetworkImage for image link', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ArticleContentRenderer(text: 'https://example.com/image.png'),
        ),
      ),
    );

    expect(find.byType(CachedNetworkImage), findsOneWidget);
  });

  test('UserModel parses disableCopying correctly', () {
    final user = UserModel.fromJson({
      'id': 'user123',
      'username': 'ali',
      'email': 'ali@example.com',
      'name': 'Ali',
      'disable_copying': true,
      'isPublic': true,
      'hideFromSearch': false,
      'verified': false,
      'emailVisibility': false,
    });
    expect(user.disableCopying, isTrue);

    final json = user.toJson();
    expect(json['disable_copying'], isTrue);
  });
}

