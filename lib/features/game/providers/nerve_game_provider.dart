import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sijilli/features/game/services/pb_nerve_game_service.dart';
import 'package:sijilli/models/nerve_score.dart';

enum NerveGameState { idle, countdown, playing, completed, submitting, finished }

class NerveGameProvider extends ChangeNotifier {
  final PbNerveGameService _service = PbNerveGameService();

  NerveGameState _state = NerveGameState.idle;
  NerveGameState get state => _state;

  int _tapCount = 0;
  int get tapCount => _tapCount;

  int _attemptIndex = 1;
  int get attemptIndex => _attemptIndex;

  double? _bestScoreOfSession;
  double? get bestScoreOfSession => _bestScoreOfSession;

  double? _currentAttemptScore;
  double? get currentAttemptScore => _currentAttemptScore;

  double _elapsedSeconds = 0.0;
  double get elapsedSeconds => _elapsedSeconds;

  List<NerveScore> _leaderboard = [];
  List<NerveScore> get leaderboard => _leaderboard;

  bool _isLoadingLeaderboard = false;
  bool get isLoadingLeaderboard => _isLoadingLeaderboard;

  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  int _countdownValue = 3;
  int get countdownValue => _countdownValue;
  Timer? _countdownTimer;

  /// بدء جلسة جديدة
  void startNewSession() {
    _state = NerveGameState.idle;
    _tapCount = 0;
    _attemptIndex = 1;
    _bestScoreOfSession = null;
    _currentAttemptScore = null;
    _elapsedSeconds = 0.0;
    _countdownValue = 3;
    _stopwatch.reset();
    _timer?.cancel();
    _countdownTimer?.cancel();
    notifyListeners();
  }

  /// بدء العد التنازلي للتحدي
  void startCountdown() {
    _state = NerveGameState.countdown;
    _countdownValue = 3;
    _tapCount = 0;
    _elapsedSeconds = 0.0;
    _stopwatch.reset();
    notifyListeners();

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownValue > 1) {
        _countdownValue--;
        notifyListeners();
      } else {
        timer.cancel();
        _startPlaying();
      }
    });
  }

  void _startPlaying() {
    _state = NerveGameState.playing;
    _stopwatch.start();
    notifyListeners();

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      _elapsedSeconds = _stopwatch.elapsedMilliseconds / 1000.0;
      notifyListeners();
    });
  }

  /// تسجيل نقرة جديدة
  void tap() {
    if (_state != NerveGameState.playing) return;

    _tapCount++;
    if (_tapCount >= 10) {
      _stopPlaying();
    } else {
      notifyListeners();
    }
  }

  void _stopPlaying() {
    _stopwatch.stop();
    _timer?.cancel();
    
    _elapsedSeconds = _stopwatch.elapsedMilliseconds / 1000.0;
    _currentAttemptScore = _elapsedSeconds;

    if (_bestScoreOfSession == null || _elapsedSeconds < _bestScoreOfSession!) {
      _bestScoreOfSession = _elapsedSeconds;
    }

    _state = NerveGameState.completed;
    notifyListeners();
  }

  /// الانتقال للمحاولة التالية (الحد الأقصى 3)
  void nextAttempt() {
    if (_attemptIndex >= 3) return;
    _attemptIndex++;
    startCountdown();
  }

  /// حفظ أفضل نتيجة في قاعدة البيانات
  Future<bool> submitBestScore() async {
    if (_bestScoreOfSession == null) return false;

    _state = NerveGameState.submitting;
    notifyListeners();

    final success = await _service.submitScore(_bestScoreOfSession!);
    if (success) {
      await fetchLeaderboard();
      _state = NerveGameState.finished;
    } else {
      _state = NerveGameState.completed;
    }
    notifyListeners();
    return success;
  }

  /// جلب لوحة الشرف
  Future<void> fetchLeaderboard() async {
    _isLoadingLeaderboard = true;
    notifyListeners();

    _leaderboard = await _service.getTodayLeaderboard();
    
    _isLoadingLeaderboard = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }
}
