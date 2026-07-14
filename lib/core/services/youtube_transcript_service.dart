import 'dart:convert';
import 'package:http/http.dart' as http;

/// نموذج يمثّل سطراً واحداً من التفريغ النصي لفيديو YouTube
class YouTubeSubtitleLine {
  final Duration start;
  final Duration duration;
  final String text;

  YouTubeSubtitleLine({
    required this.start,
    required this.duration,
    required this.text,
  });

  Map<String, dynamic> toJson() => {
        'start': start.inMilliseconds,
        'duration': duration.inMilliseconds,
        'text': text,
      };

  factory YouTubeSubtitleLine.fromJson(Map<String, dynamic> json) =>
      YouTubeSubtitleLine(
        start: Duration(milliseconds: (json['start'] as num).toInt()),
        duration: Duration(milliseconds: (json['duration'] as num).toInt()),
        text: json['text'] as String,
      );
}

/// خدمة جلب التفريغ النصي من يوتيوب عبر Vercel API
/// المسار: GET https://sijilli.vercel.app/api/youtube-transcript?videoId=XXX
class YouTubeTranscriptService {
  static const String _apiBase = 'https://sijilli.vercel.app';

  /// جلب التفريغ النصي لفيديو يوتيوب بمعرّفه
  static Future<List<YouTubeSubtitleLine>> fetchTranscript(
      String videoId) async {
    final uri = Uri.parse('$_apiBase/api/youtube-transcript')
        .replace(queryParameters: {'videoId': videoId});

    final response = await http
        .get(uri, headers: {'Accept': 'application/json'}).timeout(
      const Duration(seconds: 30),
      onTimeout: () =>
          throw Exception('انتهت مهلة الاتصال — يرجى المحاولة مرة أخرى'),
    );

    final Map<String, dynamic> body;
    try {
      body = json.decode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('استجابة غير صالحة من الخادم');
    }

    if (response.statusCode != 200) {
      final msg = body['error']?.toString() ??
          'فشل جلب التفريغ النصي (${response.statusCode})';
      throw Exception(msg);
    }

    final rawLines = body['lines'];
    if (rawLines == null || rawLines is! List || rawLines.isEmpty) {
      throw Exception('التفريغ النصي لهذا الفيديو فارغ أو غير متاح');
    }

    return rawLines
        .cast<Map<String, dynamic>>()
        .map(YouTubeSubtitleLine.fromJson)
        .toList();
  }
}
