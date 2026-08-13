import 'package:flutter_test/flutter_test.dart';
import 'package:sijilli/core/services/pocketbase_client.dart';

void main() {
  group('PocketBaseClient Tests', () {
    test('PocketBaseClient instantiation', () {
      final client = PocketBaseClient.instance;
      expect(client, isNotNull);
    });
  });
}
