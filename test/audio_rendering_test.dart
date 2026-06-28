import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sijilli/features/articles/widgets/article_content_renderer.dart';
import 'package:sijilli/features/articles/widgets/inline_audio_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock the just_audio platform channel to prevent MissingPluginException in tests
  setupJustAudioMocks();

  group('ArticleContentRenderer Audio Parsing Tests', () {
    testWidgets('Should render InlineAudioPlayer when [AUDIO] tag is encountered', (WidgetTester tester) async {
      const text = 'بعض النصوص قبل\n[AUDIO]\nبعض النصوص بعد';
      const audioUrl = 'https://sijilli.pockethost.io/api/files/articles/123/voice.mp3';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  ArticleContentRenderer(text: text, audioUrls: [audioUrl]),
                ],
              ),
            ),
          ),
        ),
      );

      // Verify that InlineAudioPlayer is rendered
      expect(find.byType(InlineAudioPlayer), findsOneWidget);
    });

    testWidgets('Should render multiple InlineAudioPlayer widgets sequentially for multiple [AUDIO] tags', (WidgetTester tester) async {
      const text = 'النص الأول\n[AUDIO]\nالنص الثاني\n[AUDIO]\nالنص الثالث';
      final audioUrls = [
        'https://example.com/audio1.mp3',
        'https://example.com/audio2.mp3',
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  ArticleContentRenderer(text: text, audioUrls: audioUrls),
                ],
              ),
            ),
          ),
        ),
      );

      // Verify that two InlineAudioPlayers are rendered
      expect(find.byType(InlineAudioPlayer), findsNWidgets(2));
    });

    testWidgets('Should render InlineAudioPlayer for direct audio file links', (WidgetTester tester) async {
      const text = 'رابط مباشر:\nhttps://example.com/podcast.mp3';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  ArticleContentRenderer(text: text),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(InlineAudioPlayer), findsOneWidget);
    });
  });
}

void setupJustAudioMocks() {
  const channel = MethodChannel('com.ryanheise.just_audio');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (methodCall) async {
    if (methodCall.method == 'init') {
      return {};
    }
    return null;
  });
}
