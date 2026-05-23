import 'package:hive/hive.dart';

part 'article_schema.g.dart';

@HiveType(typeId: 4)
class LocalArticle extends HiveObject {
  @HiveField(0)
  String id = '';

  @HiveField(1)
  String authorId = '';

  @HiveField(2)
  String text = '';

  @HiveField(3)
  bool isPublished = false;

  @HiveField(4)
  DateTime createdAt = DateTime.now();

  @HiveField(5)
  DateTime updatedAt = DateTime.now();

  @HiveField(6)
  String? image;

  @HiveField(7)
  List<String> likes = [];

  // Store author as JSON string instead of nested object to simplify schema
  @HiveField(8)
  String? authorJson;

  // Store poetry metadata as JSON string if exists
  @HiveField(9)
  String? poetryMetadataJson;
  
  @HiveField(10)
  String? highlightsMetadataJson;
}
