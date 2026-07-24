import 'package:sijilli/core/utils/json_utils.dart';
import 'package:sijilli/core/utils/audio_helper.dart';
import 'package:sijilli/models/user.dart';
import 'package:sijilli/models/appointment.dart';
import 'package:sijilli/models/tag.dart';

class Article {
  final String id;
  final String authorId;
  final String text;
  final PostStatus postStatus;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? image;
  final List<String> audioFiles;
  final List<String> imageFiles;
  
  // Relations
  final UserModel? author;
  final List<String> likes; // مصفوفة بأسماء أو أرقام المعجبين
  final List<String> tagIds;
  final List<Tag> tags;
  final int viewsCount; // عدد مرات فتح/قراءة المقال
  final bool isReadOnly; // هل المقال للقراءة فقط (مثل مقالات الترحيب)
  final bool isHelpArticle; // مقال مساعدة من المشرف يظهر لجميع المستخدمين
  
  // Poetry & Correction Metadata placeholders
  final Map<String, dynamic>? poetryMetadata;
  final List<dynamic>? highlightsMetadata;
  final Map<String, dynamic>? audioMetadata;

  Article({
    required this.id,
    required this.authorId,
    required this.text,
    required this.postStatus,
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
    this.image,
    this.audioFiles = const [],
    this.imageFiles = const [],
    this.author,
    this.likes = const [],
    this.tagIds = const [],
    this.tags = const [],
    this.viewsCount = 0,
    this.isReadOnly = false,
    this.isHelpArticle = false,
    this.poetryMetadata,
    this.highlightsMetadata,
    this.audioMetadata,
  });

  bool get isPublished => postStatus == PostStatus.published;
  bool get isDraft => postStatus == PostStatus.draft;

  /// Computed Title: استخراج أول الكلمات لتكون عنوان المقال
  String get title {
    if (text.trim().isEmpty) {
      if (audioFiles.isNotEmpty) {
        return _getCleanAudioTitle(audioFiles.first);
      }
      return 'مقال بدون عنوان';
    }
    
    // Clean all tags and markers
    String clean = text;
    clean = clean.replaceAll(RegExp(r'\[/?(POEM|CENTER|JUSTIFY|LEFT|RIGHT|B|BOLD|HIGHLIGHT|POEM_LEFT|POEM_CENTER|AUDIO(?:_[^\]]+|:\s*[^\]]+)?|IMAGE(?:_[^\]]+|:\s*[^\]]+)?)/?\]', caseSensitive: false), '');
    clean = clean.replaceAll(RegExp(r'\[/'), '');
    clean = clean.replaceAll(RegExp(r'==|~~|--|\+\+|\*'), '');
    
    final lines = clean.split('\n');
    final List<String> cleanLines = [];
    
    final imageRegex = RegExp(r'^(?:https?:\/\/\S+?\.(?:jpg|jpeg|png|webp|gif|bmp)(?:\?\S*)?)$', caseSensitive: false);
    final unsplashRegex = RegExp(r'^(?:https?:\/\/images\.unsplash\.com\/\S+|https?:\/\/unsplash\.com\/photo-\S+)$', caseSensitive: false);
    final youtubeRegex = RegExp(r'^(?:https?:\/\/)?(?:www\.)?(?:m\.)?(?:youtube\.com\/(?:watch\?(?:.*&)?v=|embed\/|v\/|shorts\/)|youtu\.be\/)([a-zA-Z0-9_-]{11})(?:\S*)?$', caseSensitive: false);

    for (final line in lines) {
      String trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      
      // Clean leading/trailing alignment markers
      if (trimmed.length > 1) {
        if ((trimmed.startsWith('=') && trimmed.endsWith('=')) ||
            (trimmed.startsWith('~') && trimmed.endsWith('~')) ||
            (trimmed.startsWith('-') && trimmed.endsWith('-')) ||
            (trimmed.startsWith('+') && trimmed.endsWith('+'))) {
          trimmed = trimmed.substring(1, trimmed.length - 1).trim();
        }
      }
      
      // Skip media links and URLs
      if (imageRegex.hasMatch(trimmed) || 
          unsplashRegex.hasMatch(trimmed) || 
          youtubeRegex.hasMatch(trimmed) ||
          trimmed.toLowerCase().endsWith('.mp3') ||
          trimmed.toLowerCase().endsWith('.m4a') ||
          trimmed.toLowerCase().endsWith('.wav') ||
          trimmed.toLowerCase().endsWith('.opus') ||
          trimmed.toLowerCase().endsWith('.ogg') ||
          trimmed.startsWith('http://') ||
          trimmed.startsWith('https://')) {
        continue;
      }
      
      cleanLines.add(trimmed);
    }
    
    if (cleanLines.isEmpty) {
      if (audioFiles.isNotEmpty) {
        return _getCleanAudioTitle(audioFiles.first);
      }
      return 'مقال بدون عنوان';
    }
    
    final String firstLine = cleanLines.first;
    final words = firstLine.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) {
      if (audioFiles.isNotEmpty) {
        return _getCleanAudioTitle(audioFiles.first);
      }
      return 'مقال بدون عنوان';
    }
    
    if (words.length <= 5) {
      return words.join(' ');
    }
    return '${words.take(5).join(' ')}...';
  }

  String _getCleanAudioTitle(String filename) {
    final displayName = AudioHelper.getAudioDisplayName(filename, text, audioFiles);
    final dotIndex = displayName.lastIndexOf('.');
    return dotIndex == -1 ? displayName : displayName.substring(0, dotIndex);
  }
  
  /// النص مجرداً من كل علامات التنسيق الخاصة بسجلي
  String get plainText {
    return stripFormatting(text);
  }
  
  /// نص المقال مجرد تماماً من وسوم سجلي وتنسيقاتها دون أي تدخل (مثل دمج الأشطر بـ ***)
  String get pureText {
    return cleanRawText(text);
  }

  static String cleanRawText(String input) {
    if (input.isEmpty) return '';

    String res = input;
    // 1. Remove all BBCode tags (including alternate closing tag formats like [BOLD/])
    res = res.replaceAll(RegExp(r'\[/?(POEM|BOLD|CENTER|JUSTIFY|LEFT|RIGHT|B|HIGHLIGHT|POEM_LEFT|POEM_CENTER|AUDIO(?:_[^\]]+|:\s*[^\]]+)?|IMAGE(?:_[^\]]+|:\s*[^\]]+)?)/?\]', caseSensitive: false), '');
    
    // 2. Remove line alignment/poetry shortcuts at start/end of lines
    final lines = res.split('\n');
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
  
  int get wordCount {
    if (text.trim().isEmpty) return 0;
    String cleanText = stripFormatting(text);
    return cleanText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  }
  
  static String stripFormatting(String input) {
    if (input.isEmpty) return '';
    
    String text = input;
    
    // 1. معالجة قصائد الشعر أولاً وتحويلها لصيغة الصدر والعجز المقروءة: صدر *** عجز
    final poemPattern = RegExp(r'\[POEM\]([\s\S]*?)\[/POEM\]', caseSensitive: false);
    text = text.replaceAllMapped(poemPattern, (match) {
      final poemContent = match.group(1) ?? '';
      final lines = poemContent.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      final List<String> processedLines = [];
      
      String? pendingSadr;
      
      for (final line in lines) {
        final lineUpper = line.toUpperCase();
        
        final isCentered = (lineUpper.startsWith('[CENTER]') && lineUpper.endsWith('[/CENTER]')) ||
                           (line.startsWith('=') && line.endsWith('=') && line.length > 1);
        final isLeft = (lineUpper.startsWith('[LEFT]') && lineUpper.endsWith('[/LEFT]')) ||
                       (line.startsWith('--') && line.endsWith('--') && line.length > 3);
        
        // التحقق إذا كان سطر الشعر عبارة عن كلمة واحدة أو أقل (توقيع أو سطر يتيم قصير)
        String cleanForWordCheck = line
            .replaceAll(RegExp(r'\[/?(BOLD|B|HIGHLIGHT|CENTER|JUSTIFY|LEFT|RIGHT|AUDIO(?:_[^\]]+|:\s*[^\]]+)?|IMAGE(?:_[^\]]+|:\s*[^\]]+)?)/?\]', caseSensitive: false), '')
            .replaceAll(RegExp(r'[=~\-\+\*]'), '')
            .trim();
        final isSingleWord = cleanForWordCheck.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length <= 1;

        if (isCentered || isLeft || isSingleWord) {
          // إذا كان هناك صدر معلق، نضعه أولاً كسطر مستقل
          if (pendingSadr != null) {
            processedLines.add(pendingSadr);
            pendingSadr = null;
          }
          
          // تنظيف السطر الموسط أو الأيسر من علاماته
          String cleanLine = line;
          if (isCentered) {
            if (cleanLine.startsWith('=')) {
              cleanLine = cleanLine.substring(1, cleanLine.length - 1).trim();
            } else {
              cleanLine = cleanLine.substring(8, cleanLine.length - 9).trim();
            }
          } else if (isLeft) {
            if (cleanLine.startsWith('-')) {
              cleanLine = cleanLine.substring(2, cleanLine.length - 2).trim();
            } else {
              cleanLine = cleanLine.substring(6, cleanLine.length - 7).trim();
            }
          }
          processedLines.add(cleanLine);
        } else {
          // سطر شعر عادي (صدر أو عجز)
          if (pendingSadr == null) {
            pendingSadr = line;
          } else {
            processedLines.add('$pendingSadr __POEM_SEP__ $line');
            pendingSadr = null;
          }
        }
      }
      
      if (pendingSadr != null) {
        processedLines.add(pendingSadr);
      }
      
      return processedLines.join('\n');
    });
    
    // 2. إزالة بقية وسوم التنسيق المباشرة (عريض، محاذاة، تظليل) مع وسوم الإغلاق البديلة والوسوم المفتوحة/المكسورة
    String cleanText = text.replaceAll(RegExp(r'\[/?(POEM|BOLD|CENTER|JUSTIFY|LEFT|RIGHT|B|HIGHLIGHT|AUDIO(?:_[^\]]+|:\s*[^\]]+)?|IMAGE(?:_[^\]]+|:\s*[^\]]+)?)/?\]', caseSensitive: false), '');
    cleanText = cleanText.replaceAll(RegExp(r'\[/', caseSensitive: false), '');
    // إزالة النجمات وعلامات التنسيق المزدوجة القديمة
    return cleanText.replaceAll('__POEM_SEP__', '***').trim();
  }
  
  static String stripToPoetry(String input) {
    if (input.isEmpty) return '';
    final lines = input.split('\n');
    final List<String> remainingLines = [];
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.toUpperCase().startsWith('[POEM]') || 
          trimmed.toUpperCase().endsWith('[/POEM]') ||
          trimmed.toUpperCase().startsWith('[IMAGE') ||
          trimmed.toUpperCase().startsWith('[AUDIO')) {
        continue;
      }
      remainingLines.add(line);
    }
    return remainingLines.join('\n');
  }

  /// مدة القراءة المقدرة (استناداً إلى 100 كلمة في الدقيقة كمتوسط)
  int get estimatedReadingTimeMinutes {
    final count = wordCount;
    if (count == 0) return 1;
    final minutes = (count / 100).ceil();
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
    final tagsList = (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

    List<Tag> resolvedTags = [];
    if (expand != null && expand.containsKey('tags')) {
      final tagsData = expand['tags'];
      if (tagsData is List) {
        resolvedTags = tagsData.map((t) => Tag.fromJson(t as Map<String, dynamic>)).toList();
      } else if (tagsData is Map<String, dynamic>) {
        resolvedTags = [Tag.fromJson(tagsData)];
      }
    }

    PostStatus status = PostStatus.published;
    final pbStatusStr = JsonUtils.parseString(json['post_status']);
    if (pbStatusStr != null && pbStatusStr.isNotEmpty) {
      status = PostStatus.fromString(pbStatusStr);
    } else {
      final isPublishedOld = JsonUtils.parseBool(json['is_published']);
      final isDraftOld = JsonUtils.parseBool(json['is_draft']);
      if (isPublishedOld) {
        status = PostStatus.published;
      } else if (isDraftOld) {
        status = PostStatus.draft;
      } else {
        status = PostStatus.written;
      }
    }

    return Article(
      id: JsonUtils.parseString(json['id']) ?? '',
      authorId: JsonUtils.parseString(json['author']) ?? '',
      text: JsonUtils.parseString(json['text']) ?? '',
      postStatus: status,
      deletedAt: JsonUtils.parseDateTime(json['deleted_at']),
      createdAt: JsonUtils.parseDateTime(json['created']) ?? DateTime.now(),
      updatedAt: JsonUtils.parseDateTime(json['updated']) ?? DateTime.now(),
      image: JsonUtils.parseString(json['image']),
      audioFiles: (json['audio'] is List)
          ? (json['audio'] as List<dynamic>).map((e) => e.toString()).toList()
          : (json['audio'] != null && json['audio'].toString().isNotEmpty)
              ? [json['audio'].toString()]
              : <String>[],
      imageFiles: (json['images'] is List)
          ? (json['images'] as List<dynamic>).map((e) => e.toString()).toList()
          : (json['images'] != null && json['images'].toString().isNotEmpty)
              ? [json['images'].toString()]
              : <String>[],
      author: userJson != null ? UserModel.fromJson(userJson) : null,
      likes: likesList,
      tagIds: tagsList,
      tags: resolvedTags,
      viewsCount: JsonUtils.parseInt(json['likes_count']) ?? 0,
      isReadOnly: JsonUtils.parseBool(json['is_read_only']),
      isHelpArticle: JsonUtils.parseBool(json['is_help_article']),
      poetryMetadata: json['poetry_metadata'] as Map<String, dynamic>?,
      highlightsMetadata: json['highlights_metadata'] as List<dynamic>?,
      audioMetadata: json['audio_metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'author': authorId,
      'text': text,
      'post_status': postStatus.toString(),
      'deleted_at': deletedAt?.toUtc().toIso8601String(),
      'is_published': isPublished,
      'is_draft': isDraft,
      'created': createdAt.toUtc().toIso8601String(),
      'updated': updatedAt.toUtc().toIso8601String(),
      'image': image,
      'audio': audioFiles,
      'likes': likes,
      'likes_count': viewsCount,
      'tags': tagIds,
      'is_read_only': isReadOnly,
      'is_help_article': isHelpArticle,
      'poetry_metadata': poetryMetadata,
      'highlights_metadata': highlightsMetadata,
      'audio_metadata': audioMetadata,
    };
  }

  Article copyWith({
    String? id,
    String? authorId,
    String? text,
    PostStatus? postStatus,
    DateTime? deletedAt,
    bool? isPublished,
    bool? isDraft,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? image,
    List<String>? audioFiles,
    UserModel? author,
    List<String>? likes,
    List<String>? tagIds,
    List<Tag>? tags,
    int? viewsCount,
    bool? isReadOnly,
    bool? isHelpArticle,
    Map<String, dynamic>? poetryMetadata,
    List<dynamic>? highlightsMetadata,
    Map<String, dynamic>? audioMetadata,
  }) {
    PostStatus resolvedStatus = postStatus ?? this.postStatus;
    if (isPublished != null) {
      resolvedStatus = isPublished ? PostStatus.published : PostStatus.written;
    } else if (isDraft != null) {
      resolvedStatus = isDraft ? PostStatus.draft : PostStatus.written;
    }

    return Article(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      text: text ?? this.text,
      postStatus: resolvedStatus,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      image: image ?? this.image,
      audioFiles: audioFiles ?? this.audioFiles,
      author: author ?? this.author,
      likes: likes ?? this.likes,
      tagIds: tagIds ?? this.tagIds,
      tags: tags ?? this.tags,
      viewsCount: viewsCount ?? this.viewsCount,
      isReadOnly: isReadOnly ?? this.isReadOnly,
      isHelpArticle: isHelpArticle ?? this.isHelpArticle,
      poetryMetadata: poetryMetadata ?? this.poetryMetadata,
      highlightsMetadata: highlightsMetadata ?? this.highlightsMetadata,
      audioMetadata: audioMetadata ?? this.audioMetadata,
    );
  }
}
