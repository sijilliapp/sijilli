import 'package:hive/hive.dart';

part 'appointment_schema.g.dart';

@HiveType(typeId: 1)
class LocalAppointment extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String title;

  @HiveField(2)
  late String hostId;

  @HiveField(3)
  late DateTime startAt;

  @HiveField(4)
  late int duration;

  @HiveField(5)
  late DateTime date;

  @HiveField(6)
  late String time;

  @HiveField(7)
  String? region;

  @HiveField(8)
  String? building;

  @HiveField(9)
  String privacy = 'private';

  @HiveField(10)
  String? description;

  @HiveField(11)
  int participantsCount = 0;

  @HiveField(12)
  int invitedCount = 0;

  @HiveField(13)
  bool isArchived = false;

  @HiveField(14)
  bool isDeleted = false;

  @HiveField(15)
  bool isCancelled = false;
  
  // We store expanded objects as simplified JSON strings or separate HiveObjects if needed.
  // For simplicity and performance, we can store Host details as JSON string or ignore if usually fetched live.
  // But for offline view, we need Basic host info.
  // Let's store Host as JSON map string or just key details.
  // Let's use a simplified approach: Store Host JSON string.
  @HiveField(16)
  String? hostJson; 

  @HiveField(17)
  late DateTime createdAt;

  @HiveField(18)
  late DateTime updatedAt;
  
  @HiveField(19)
  List<LocalInvitation>? participants; // Using nested HiveType
  
  @HiveField(20)
  LocalInvitation? currentUserInvitation;

  @HiveField(21)
  bool isConfirmed = false;

  @HiveField(22)
  String? hijriDate;

  @HiveField(23)
  int? hijriMonth;

  @HiveField(24)
  String dateType = 'gregorian';

  @HiveField(25)
  String? streamLink;

  @HiveField(26)
  String? appointmentGroupId;

  @HiveField(27)
  String? coordinates;
}

@HiveType(typeId: 2)
class LocalInvitation extends HiveObject {
  @HiveField(0)
  late String id;
  
  @HiveField(1)
  late String appointmentId;
  
  @HiveField(2)
  late String userId;

  @HiveField(3)
  String status = 'pending'; // Stored as string

  @HiveField(4)
  bool isDeleted = false;

  @HiveField(5)
  bool isArchived = false;

  @HiveField(6)
  String? personalNote;
  
  @HiveField(7)
  String? userJson; // Guest details as JSON string

  @HiveField(8)
  String privacy = 'private';

  @HiveField(9)
  String? categoryJson;

  @HiveField(10)
  DateTime? acceptedAt;

  @HiveField(11)
  DateTime? declinedAt;

  @HiveField(12)
  DateTime? deletedAt;

  @HiveField(13)
  bool isComplete = false;

  @HiveField(14)
  String? dateType;
}

@HiveType(typeId: 3)
class LocalCategory extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String name;

  @HiveField(2)
  String? icon;

  @HiveField(3)
  String? color;

  @HiveField(4)
  String? userId;
}
