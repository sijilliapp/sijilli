import 'package:flutter_test/flutter_test.dart';
import 'package:sijilli/features/game/providers/nerve_game_provider.dart';

void main() {
  group('NerveGameProvider Tests', () {
    late NerveGameProvider provider;

    setUp(() {
      provider = NerveGameProvider();
    });

    test('Initial values are set correctly on startNewSession', () {
      provider.startNewSession();
      expect(provider.state, NerveGameState.idle);
      expect(provider.tapCount, 0);
      expect(provider.attemptIndex, 1);
      expect(provider.bestScoreOfSession, isNull);
      expect(provider.currentAttemptScore, isNull);
      expect(provider.elapsedSeconds, 0.0);
    });

    test('Timer starts and tapCount increments on first tap', () {
      provider.startNewSession();
      expect(provider.state, NerveGameState.idle);
      provider.tap();
      expect(provider.state, NerveGameState.playing);
      expect(provider.tapCount, 1);
    });

    test('Attempts are limited to a maximum of 3', () {
      provider.startNewSession();
      expect(provider.attemptIndex, 1);
      
      // Simulate attempts transition
      provider.nextAttempt(); // goes to 2
      expect(provider.attemptIndex, 2);

      provider.nextAttempt(); // goes to 3
      expect(provider.attemptIndex, 3);

      provider.nextAttempt(); // should stay at 3
      expect(provider.attemptIndex, 3);
    });
  });
}
