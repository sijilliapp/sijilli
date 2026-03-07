// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'appointment_schema.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LocalAppointmentAdapter extends TypeAdapter<LocalAppointment> {
  @override
  final int typeId = 1;

  @override
  LocalAppointment read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LocalAppointment()
      ..id = fields[0] as String
      ..title = fields[1] as String
      ..hostId = fields[2] as String
      ..startAt = fields[3] as DateTime
      ..duration = fields[4] as int
      ..date = fields[5] as DateTime
      ..time = fields[6] as String
      ..region = fields[7] as String?
      ..building = fields[8] as String?
      ..privacy = fields[9] as String
      ..description = fields[10] as String?
      ..participantsCount = fields[11] as int
      ..invitedCount = fields[12] as int
      ..isArchived = fields[13] as bool
      ..isDeleted = fields[14] as bool
      ..isCancelled = fields[15] as bool
      ..hostJson = fields[16] as String?
      ..createdAt = fields[17] as DateTime
      ..updatedAt = fields[18] as DateTime
      ..participants = (fields[19] as List?)?.cast<LocalInvitation>()
      ..currentUserInvitation = fields[20] as LocalInvitation?
      ..isConfirmed = fields[21] as bool
      ..hijriDate = fields[22] as String?
      ..hijriMonth = fields[23] as int?
      ..dateType = fields[24] as String
      ..streamLink = fields[25] as String?
      ..appointmentGroupId = fields[26] as String?;
  }

  @override
  void write(BinaryWriter writer, LocalAppointment obj) {
    writer
      ..writeByte(27)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.hostId)
      ..writeByte(3)
      ..write(obj.startAt)
      ..writeByte(4)
      ..write(obj.duration)
      ..writeByte(5)
      ..write(obj.date)
      ..writeByte(6)
      ..write(obj.time)
      ..writeByte(7)
      ..write(obj.region)
      ..writeByte(8)
      ..write(obj.building)
      ..writeByte(9)
      ..write(obj.privacy)
      ..writeByte(10)
      ..write(obj.description)
      ..writeByte(11)
      ..write(obj.participantsCount)
      ..writeByte(12)
      ..write(obj.invitedCount)
      ..writeByte(13)
      ..write(obj.isArchived)
      ..writeByte(14)
      ..write(obj.isDeleted)
      ..writeByte(15)
      ..write(obj.isCancelled)
      ..writeByte(16)
      ..write(obj.hostJson)
      ..writeByte(17)
      ..write(obj.createdAt)
      ..writeByte(18)
      ..write(obj.updatedAt)
      ..writeByte(19)
      ..write(obj.participants)
      ..writeByte(20)
      ..write(obj.currentUserInvitation)
      ..writeByte(21)
      ..write(obj.isConfirmed)
      ..writeByte(22)
      ..write(obj.hijriDate)
      ..writeByte(23)
      ..write(obj.hijriMonth)
      ..writeByte(24)
      ..write(obj.dateType)
      ..writeByte(25)
      ..write(obj.streamLink)
      ..writeByte(26)
      ..write(obj.appointmentGroupId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalAppointmentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class LocalInvitationAdapter extends TypeAdapter<LocalInvitation> {
  @override
  final int typeId = 2;

  @override
  LocalInvitation read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LocalInvitation()
      ..id = fields[0] as String
      ..appointmentId = fields[1] as String
      ..userId = fields[2] as String
      ..status = fields[3] as String
      ..isDeleted = fields[4] as bool
      ..isArchived = fields[5] as bool
      ..personalNote = fields[6] as String?
      ..userJson = fields[7] as String?
      ..privacy = fields[8] as String
      ..categoryJson = fields[9] as String?
      ..acceptedAt = fields[10] as DateTime?
      ..declinedAt = fields[11] as DateTime?
      ..deletedAt = fields[12] as DateTime?
      ..isComplete = fields[13] as bool
      ..dateType = fields[14] as String?;
  }

  @override
  void write(BinaryWriter writer, LocalInvitation obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.appointmentId)
      ..writeByte(2)
      ..write(obj.userId)
      ..writeByte(3)
      ..write(obj.status)
      ..writeByte(4)
      ..write(obj.isDeleted)
      ..writeByte(5)
      ..write(obj.isArchived)
      ..writeByte(6)
      ..write(obj.personalNote)
      ..writeByte(7)
      ..write(obj.userJson)
      ..writeByte(8)
      ..write(obj.privacy)
      ..writeByte(9)
      ..write(obj.categoryJson)
      ..writeByte(10)
      ..write(obj.acceptedAt)
      ..writeByte(11)
      ..write(obj.declinedAt)
      ..writeByte(12)
      ..write(obj.deletedAt)
      ..writeByte(13)
      ..write(obj.isComplete)
      ..writeByte(14)
      ..write(obj.dateType);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalInvitationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class LocalCategoryAdapter extends TypeAdapter<LocalCategory> {
  @override
  final int typeId = 3;

  @override
  LocalCategory read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LocalCategory()
      ..id = fields[0] as String
      ..name = fields[1] as String
      ..icon = fields[2] as String?
      ..color = fields[3] as String?
      ..userId = fields[4] as String?;
  }

  @override
  void write(BinaryWriter writer, LocalCategory obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.icon)
      ..writeByte(3)
      ..write(obj.color)
      ..writeByte(4)
      ..write(obj.userId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalCategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
