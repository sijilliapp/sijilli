import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  print('Fetching all articles with audio files...');
  final response = await http.get(Uri.parse('https://sijilli.pockethost.io/api/collections/articles/records?page=1&perPage=100&sort=-updated'));
  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    final items = data['items'] as List<dynamic>;
    int count = 0;
    for (final item in items) {
      final audioFiles = List<String>.from(item['audio'] ?? []);
      if (audioFiles.isNotEmpty) {
        count++;
        print('Article ID: ${item['id']} | Status: ${item['post_status']}');
        print('Audio Files: $audioFiles');
        print('Text Snippet: "${item['text']?.toString().substring(0, item['text']?.toString().length.clamp(0, 100))}"');
        print('--------------------------------------');
      }
    }
    print('Total articles with audio: $count');
  } else {
    print('Failed: ${response.statusCode}');
  }
}
