// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'article_schema.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LocalArticleAdapter extends TypeAdapter<LocalArticle> {
  @override
  final int typeId = 4;

  @override
  LocalArticle read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LocalArticle()
      ..id = fields[0] as String
      ..authorId = fields[1] as String
      ..text = fields[2] as String
      ..isPublished = fields[3] as bool
      ..createdAt = fields[4] as DateTime
      ..updatedAt = fields[5] as DateTime
      ..image = fields[6] as String?
      ..likes = (fields[7] as List).cast<String>()
      ..authorJson = fields[8] as String?
      ..poetryMetadataJson = fields[9] as String?
      ..highlightsMetadataJson = fields[10] as String?;
  }

  @override
  void write(BinaryWriter writer, LocalArticle obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.authorId)
      ..writeByte(2)
      ..write(obj.text)
      ..writeByte(3)
      ..write(obj.isPublished)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.updatedAt)
      ..writeByte(6)
      ..write(obj.image)
      ..writeByte(7)
      ..write(obj.likes)
      ..writeByte(8)
      ..write(obj.authorJson)
      ..writeByte(9)
      ..write(obj.poetryMetadataJson)
      ..writeByte(10)
      ..write(obj.highlightsMetadataJson);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalArticleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
