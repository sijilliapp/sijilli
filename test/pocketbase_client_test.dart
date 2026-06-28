import 'package:flutter_test/flutter_test.dart';
import 'package:sijilli/core/services/pocketbase_client.dart';
import 'package:http/http.dart' as http;

void main() {
  group('PocketBaseHttpClient Tests', () {
    test('PocketBaseHttpClient instantiation', () {
      final client = PocketBaseHttpClient();
      expect(client, isNotNull);
      expect(client, isA<http.BaseClient>());
    });
    test('PocketBaseHttpClient should immediately fail if closed and not retry', () async {
      final client = PocketBaseHttpClient();
      client.close();

      final request = http.Request('GET', Uri.parse('http://localhost/api/health'));
      expect(
        () => client.send(request),
        throwsA(isA<http.ClientException>()),
      );
    });
  });
}
