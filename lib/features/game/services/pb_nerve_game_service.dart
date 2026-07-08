import 'package:pocketbase/pocketbase.dart';
import 'package:sijilli/core/services/pocketbase_client.dart';
import 'package:sijilli/models/nerve_score.dart';

class PbNerveGameService {
  PocketBase get _pb => PocketBaseClient.instance.pb;
  static const String collectionNerveLeaderboard = 'nerve_leaderboard';

  /// إرسال نتيجة جديدة
  Future<bool> submitScore(double seconds) async {
    try {
      final userId = _pb.authStore.record?.id;
      if (userId == null) throw Exception('User not authenticated');

      await _pb.collection(collectionNerveLeaderboard).create(body: {
        'user': userId,
        'time_seconds': seconds,
      });
      return true;
    } catch (e) {
      print('❌ Failed to submit nerve game score: $e');
      return false;
    }
  }

  /// جلب لوحة الشرف لليوم الحالي مرتبة تصاعدياً (أسرع وقت)
  Future<List<NerveScore>> getTodayLeaderboard() async {
    try {
      // الحصول على بداية اليوم الحالي بتوقيت UTC
      final now = DateTime.now().toUtc();
      final todayStart = DateTime.utc(now.year, now.month, now.day).toIso8601String();

      final records = await _pb.collection(collectionNerveLeaderboard).getFullList(
        filter: 'created >= "$todayStart"',
        sort: '+time_seconds',
        expand: 'user',
      );

      // تصفية المتسابقين بحيث يظهر كل متسابق مرة واحدة فقط (أفضل توقيت له)
      final Map<String, NerveScore> uniqueScores = {};
      for (final rec in records) {
        final score = NerveScore.fromJson(rec.toJson());
        final currentBest = uniqueScores[score.userId];
        if (currentBest == null || score.timeSeconds < currentBest.timeSeconds) {
          uniqueScores[score.userId] = score;
        }
      }

      final sortedScores = uniqueScores.values.toList()
        ..sort((a, b) => a.timeSeconds.compareTo(b.timeSeconds));

      // أخذ أفضل 10 نتائج فقط
      return sortedScores.take(10).toList();
    } catch (e) {
      print('❌ Failed to fetch nerve game leaderboard: $e');
      return [];
    }
  }
}
