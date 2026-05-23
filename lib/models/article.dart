import 'package:sijilli/core/utils/json_utils.dart';
import 'package:sijilli/models/user.dart';

class Article {
  final String id;
  final String authorId;
  final String text;
  final bool isPublished;
  final bool isDraft;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? image;
  
  // Relations
  final UserModel? author;
  final List<String> likes; // مصفوفة بأسماء أو أرقام المعجبين
  
  // Poetry & Correction Metadata placeholders
  final Map<String, dynamic>? poetryMetadata;
  final List<dynamic>? highlightsMetadata;

  Article({
    required this.id,
    required this.authorId,
    required this.text,
    required this.isPublished,
    this.isDraft = false,
    required this.createdAt,
    required this.updatedAt,
    this.image,
    this.author,
    this.likes = const [],
    this.poetryMetadata,
    this.highlightsMetadata,
  });

  /// Computed Title: استخراج أول الكلمات لتكون عنوان المقال
  String get title {
    if (text.trim().isEmpty) return 'مقال بدون عنوان';
    
    final lines = stripFormatting(text)
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();
        
    if (lines.isEmpty) return 'مقال بدون عنوان';
    
    final String firstLine = lines.first;
    
    // استلال أول 5 كلمات كحد أقصى للعنوان
    final words = firstLine.split(RegExp(r'\s+'));
    if (words.length <= 5) {
      return firstLine;
    }
    
    return '${words.take(5).join(' ')}...';
  }
  
  /// النص مجرداً من كل علامات التنسيق الخاصة بسجلي
  String get plainText {
    return stripFormatting(text);
  }
  
  int get wordCount {
    if (text.trim().isEmpty) return 0;
    String cleanText = stripFormatting(text);
    return cleanText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  }
  
  static String stripFormatting(String input) {
    if (input.isEmpty) return '';
    
    // إزالة وسوم التنسيق المباشرة
    String cleanText = input.replaceAll(RegExp(r'\[/?(POEM|CENTER|JUSTIFY|LEFT|RIGHT|B)\]', caseSensitive: false), '');
    // إزالة النجمات (للبنط العريض) وعلامات التنسيق المزدوجة القديمة
    cleanText = cleanText.replaceAll(RegExp(r'==|~~|--|\+\+|\*'), '');
    
    // تنظيف علامات المحاذاة الفردية إذا كانت في بداية ونهاية السطر (مثل =مقال=)
    final lines = cleanText.split('\n');
    final cleanedLines = lines.map((l) {
      String trimmed = l.trim();
      if (trimmed.length > 1) {
        if ((trimmed.startsWith('=') && trimmed.endsWith('=')) ||
            (trimmed.startsWith('~') && trimmed.endsWith('~')) ||
            (trimmed.startsWith('-') && trimmed.endsWith('-')) ||
            (trimmed.startsWith('+') && trimmed.endsWith('+'))) {
          trimmed = trimmed.substring(1, trimmed.length - 1).trim();
        }
      }
      return trimmed;
    });
    
    return cleanedLines.join('\n').trim();
  }

  /// مدة القراءة المقدرة (استناداً إلى 200 كلمة في الدقيقة كمتوسط)
  int get estimatedReadingTimeMinutes {
    final count = wordCount;
    if (count == 0) return 1;
    final minutes = (count / 200).ceil();
    return minutes == 0 ? 1 : minutes;
  }

  /// نص المقال بالكامل بعد استبعاد السطر الأول (العنوان) لتجنب التكرار إذا كان عنواناً منفرداً (وليس جزءاً من قصيدة)
  String get textWithoutTitle {
    if (text.trim().isEmpty) return '';
    
    final lines = text.split('\n');
    int firstLineIndex = -1;
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].trim().isNotEmpty) {
        firstLineIndex = i;
        break;
      }
    }
    
    if (firstLineIndex == -1) return '';
    
    // إذا كان المقال يبدأ بقصيدة، لا نحذف السطر الأول لكي لا نخرّب بناء القصيدة الفني والوزني
    if (lines[firstLineIndex].contains('[POEM]')) {
      return text;
    }
    
    final remainingLines = lines.sublist(firstLineIndex + 1);
    return remainingLines.join('\n');
  }

  factory Article.fromJson(Map<String, dynamic> json) {
    final expand = json['expand'] as Map<String, dynamic>?;
    
    var userData = expand?['author'];
    if (userData is List && userData.isNotEmpty) userData = userData.first;
    final Map<String, dynamic>? userJson = userData is Map<String, dynamic> ? userData : null;

    final likesList = (json['likes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

    return Article(
      id: JsonUtils.parseString(json['id']) ?? '',
      authorId: JsonUtils.parseString(json['author']) ?? '',
      text: JsonUtils.parseString(json['text']) ?? '',
      isPublished: JsonUtils.parseBool(json['is_published']),
      isDraft: JsonUtils.parseBool(json['is_draft']),
      createdAt: JsonUtils.parseDateTime(json['created']) ?? DateTime.now(),
      updatedAt: JsonUtils.parseDateTime(json['updated']) ?? DateTime.now(),
      image: JsonUtils.parseString(json['image']),
      author: userJson != null ? UserModel.fromJson(userJson) : null,
      likes: likesList,
      poetryMetadata: json['poetry_metadata'] as Map<String, dynamic>?,
      highlightsMetadata: json['highlights_metadata'] as List<dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'author': authorId,
      'text': text,
      'is_published': isPublished,
      'is_draft': isDraft,
      'created': createdAt.toUtc().toIso8601String(),
      'updated': updatedAt.toUtc().toIso8601String(),
      'image': image,
      'likes': likes,
      'poetry_metadata': poetryMetadata,
      'highlights_metadata': highlightsMetadata,
    };
  }

  Article copyWith({
    String? id,
    String? authorId,
    String? text,
    bool? isPublished,
    bool? isDraft,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? image,
    UserModel? author,
    List<String>? likes,
    Map<String, dynamic>? poetryMetadata,
    List<dynamic>? highlightsMetadata,
  }) {
    return Article(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      text: text ?? this.text,
      isPublished: isPublished ?? this.isPublished,
      isDraft: isDraft ?? this.isDraft,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      image: image ?? this.image,
      author: author ?? this.author,
      likes: likes ?? this.likes,
      poetryMetadata: poetryMetadata ?? this.poetryMetadata,
      highlightsMetadata: highlightsMetadata ?? this.highlightsMetadata,
    );
  }
}
