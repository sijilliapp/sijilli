import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sijilli/core/services/youtube_transcript_service.dart';

void main() {
  group('YouTubeTranscriptService Tests', () {
    test('Should parse JSON lines from Vercel API successfully', () async {
      final mockClient = MockClient((request) async {
        final urlStr = request.url.toString();
        if (urlStr.contains('sijilli.vercel.app/api/youtube-transcript') && urlStr.contains('videoId=test_video_id')) {
          return http.Response(json.encode({
            'lines': [
              {
                'start': 500,
                'duration': 1500,
                'text': 'السلام عليكم ورحمة الله'
              },
              {
                'start': 2000,
                'duration': 3000,
                'text': 'مرحباً بكم في تطبيق سجلي'
              }
            ]
          }), 200, headers: {'content-type': 'application/json; charset=utf-8'});
        }
        return http.Response('Not Found', 404);
      });

      await http.runWithClient(() async {
        final lines = await YouTubeTranscriptService.fetchTranscript('test_video_id');
        expect(lines, isNotEmpty);
        expect(lines.length, 2);
        
        expect(lines[0].start, const Duration(milliseconds: 500));
        expect(lines[0].duration, const Duration(milliseconds: 1500));
        expect(lines[0].text, 'السلام عليكم ورحمة الله');
        
        expect(lines[1].start, const Duration(milliseconds: 2000));
        expect(lines[1].duration, const Duration(milliseconds: 3000));
        expect(lines[1].text, 'مرحباً بكم في تطبيق سجلي');
      }, () => mockClient);
    });

    test('Should throw exception when Vercel API returns error status', () async {
      final mockClient = MockClient((request) async {
        return http.Response(json.encode({
          'error': 'Video is unavailable or has no transcript'
        }), 400, headers: {'content-type': 'application/json; charset=utf-8'});
      });

      await http.runWithClient(() async {
        expect(
          () => YouTubeTranscriptService.fetchTranscript('invalid_id'),
          throwsA(isA<Exception>()),
        );
      }, () => mockClient);
    });

    test('Should throw exception when transcript lines are empty', () async {
      final mockClient = MockClient((request) async {
        return http.Response(json.encode({
          'lines': []
        }), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      });

      await http.runWithClient(() async {
        expect(
          () => YouTubeTranscriptService.fetchTranscript('empty_video'),
          throwsA(isA<Exception>()),
        );
      }, () => mockClient);
    });
  });
}
