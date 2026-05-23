// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_schema.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LocalUserAdapter extends TypeAdapter<LocalUser> {
  @override
  final int typeId = 0;

  @override
  LocalUser read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LocalUser()
      ..userId = fields[0] as String
      ..username = fields[1] as String
      ..email = fields[2] as String
      ..name = fields[3] as String
      ..avatar = fields[4] as String?
      ..bio = fields[5] as String?
      ..socialLink = fields[6] as String?
      ..phone = fields[7] as String?
      ..hijriAdjustment = fields[8] as double?
      ..role = fields[9] as String
      ..isPublic = fields[10] as bool
      ..verified = fields[11] as bool
      ..emailVisibility = fields[12] as bool
      ..date = fields[13] as DateTime?
      ..created = fields[14] as DateTime
      ..updated = fields[15] as DateTime
      ..joiningDate = fields[16] as DateTime
      ..token = fields[17] as String?
      ..phoneVerified = fields[18] as bool;
  }

  @override
  void write(BinaryWriter writer, LocalUser obj) {
    writer
      ..writeByte(19)
      ..writeByte(0)
      ..write(obj.userId)
      ..writeByte(1)
      ..write(obj.username)
      ..writeByte(2)
      ..write(obj.email)
      ..writeByte(3)
      ..write(obj.name)
      ..writeByte(4)
      ..write(obj.avatar)
      ..writeByte(5)
      ..write(obj.bio)
      ..writeByte(6)
      ..write(obj.socialLink)
      ..writeByte(7)
      ..write(obj.phone)
      ..writeByte(8)
      ..write(obj.hijriAdjustment)
      ..writeByte(9)
      ..write(obj.role)
      ..writeByte(10)
      ..write(obj.isPublic)
      ..writeByte(11)
      ..write(obj.verified)
      ..writeByte(12)
      ..write(obj.emailVisibility)
      ..writeByte(13)
      ..write(obj.date)
      ..writeByte(14)
      ..write(obj.created)
      ..writeByte(15)
      ..write(obj.updated)
      ..writeByte(16)
      ..write(obj.joiningDate)
      ..writeByte(17)
      ..write(obj.token)
      ..writeByte(18)
      ..write(obj.phoneVerified);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalUserAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
