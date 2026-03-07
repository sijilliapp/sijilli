import 'package:hive/hive.dart';

part 'user_schema.g.dart';

@HiveType(typeId: 0)
class LocalUser extends HiveObject {
  @HiveField(0)
  late String userId; // PocketBase ID

  @HiveField(1)
  late String username;

  @HiveField(2)
  late String email;

  @HiveField(3)
  late String name;

  @HiveField(4)
  String? avatar;

  @HiveField(5)
  String? bio;

  @HiveField(6)
  String? socialLink;

  @HiveField(7)
  String? phone;
  
  @HiveField(8)
  double? hijriAdjustment;
  
  @HiveField(9)
  String role = 'user';

  @HiveField(10)
  bool isPublic = false;

  @HiveField(11)
  bool verified = false;

  @HiveField(12)
  bool emailVisibility = false;

  @HiveField(13)
  DateTime? date;

  @HiveField(14)
  late DateTime created;

  @HiveField(15)
  late DateTime updated;

  @HiveField(16)
  late DateTime joiningDate;

  @HiveField(17)
  String? token;
}
