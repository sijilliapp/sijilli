import 'package:sijilli/core/utils/json_utils.dart';
import 'package:sijilli/models/user.dart';

class NerveScore {
  final String id;
  final String userId;
  final double timeSeconds;
  final DateTime created;
  final UserModel? user; // Expanded relation

  const NerveScore({
    required this.id,
    required this.userId,
    required this.timeSeconds,
    required this.created,
    this.user,
  });

  factory NerveScore.fromJson(Map<String, dynamic> json) {
    UserModel? parsedUser;
    if (json['expand'] != null && json['expand']['user'] != null) {
      parsedUser = UserModel.fromJson(json['expand']['user']);
    }

    return NerveScore(
      id: JsonUtils.parseString(json['id']) ?? '',
      userId: JsonUtils.parseString(json['user']) ?? '',
      timeSeconds: JsonUtils.parseDouble(json['time_seconds']) ?? 0.0,
      created: JsonUtils.parseDateTime(json['created']) ?? DateTime.now(),
      user: parsedUser,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user': userId,
      'time_seconds': timeSeconds,
      'created': created.toIso8601String(),
    };
  }
}
