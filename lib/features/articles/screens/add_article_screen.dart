import 'dart:io';
import 'package:sijilli/core/utils/audio_helper.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/local/local_db_service.dart';
import '../../../models/article.dart';
import '../../../models/tag.dart';
import '../providers/article_provider.dart';
import '../providers/tag_provider.dart';
import '../widgets/formatting_text_controller.dart';
import '../widgets/article_content_renderer.dart';
import '../widgets/tag_selector_sheet.dart';
import '../widgets/inline_audio_player.dart';
import 'package:file_picker/file_picker.dart';
import '../widgets/tag_chip.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';
import '../../../core/providers/global_config_provider.dart';
import '../services/quran_service.dart';
import '../../../core/utils/bidi_utils.dart';

class AddArticleScreen extends StatefulWidget {
  final Article? article;
  final List<String>? initialTagIds;
  
  const AddArticleScreen({super.key, this.article, this.initialTagIds});

  @override
  State<AddArticleScreen> createState() => _AddArticleScreenState();
}

class _AddArticleScreenState extends State<AddArticleScreen> {
  /// المتحكم المخصص: يُخفي رموز التنسيق ويعرض النص نظيفاً
  late final FormattingTextEditingController _textController;
  final FocusNode _textFocusNode = FocusNode();
  File? _selectedImage;
  bool _deleteExistingImage = false;
  List<File> _selectedAudios = [];
  List<String> _existingAudios = [];
  bool _isPublished = false;
  bool _isLoading = false;
  bool _isPreviewMode = false;
  bool _isSelecting = false;
  int? _selectionAnchor;
  String? _draftArticleId;

  Timer? _debounce;
  String _lastRawText = '';
  bool _hasText = false;

  Future<Article?>? _autosaveFuture;
  bool _isCreating = false;
  List<String> _selectedTagIds = [];
  TextSelection? _lastSelection;
  Offset? _lastPointerDownOffset;
  late final ScrollController _editorScrollController;

  String? _activeStreamingAudioUrl;
  int _streamingStartIndex = -1;
  int _lastStreamingInsertedLength = 0;

  @override
  void initState() {
    super.initState();
    _editorScrollController = ScrollController();
    _textController = FormattingTextEditingController(
      rawText: widget.article?.text ?? '',
    );
    _hasText = _textController.rawText.trim().isNotEmpty;
    _lastRawText = _textController.rawText;
    _isPublished = widget.article?.isPublished ?? false;
    _selectedTagIds = widget.article?.tagIds ?? widget.initialTagIds ?? [];
    if (widget.article != null) {
      _existingAudios = List.from(widget.article!.audioFiles);
    }
 
    _textController.addListener(_unifiedTextListener);

    if (widget.article == null) {
      _loadDraft();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<TagProvider>().fetchTags();
        _restoreCursorPosition();
      }
    });
  }

  void _saveCursorPosition() async {
    final selection = _textController.selection;
    if (selection != _lastSelection) {
      _lastSelection = selection;
      if (selection.baseOffset >= 0) {
        final draftId = widget.article?.id ?? _draftArticleId ?? 'local_draft';
        final isDraft = widget.article == null || widget.article!.isDraft;
        if (isDraft) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('draft_cursor_base_$draftId', selection.baseOffset);
          await prefs.setInt('draft_cursor_extent_$draftId', selection.extentOffset);
        }
      }
    }
  }

  void _restoreCursorPosition() async {
    final isDraft = widget.article == null || widget.article!.isDraft;
    if (!isDraft) return;

    final draftId = widget.article?.id ?? _draftArticleId ?? 'local_draft';
    final prefs = await SharedPreferences.getInstance();
    final base = prefs.getInt('draft_cursor_base_$draftId');
    final extent = prefs.getInt('draft_cursor_extent_$draftId');

    if (base != null && extent != null && mounted) {
      final textLength = _textController.text.length;
      if (base <= textLength && extent <= textLength) {
        setState(() {
          _textController.selection = TextSelection(baseOffset: base, extentOffset: extent);
        });
        _textFocusNode.requestFocus();
      }
    }
  }

  Future<void> _loadDraft() async {
    final draft = await LocalDbService.instance.getArticleDraft();
    if (draft != null && draft.trim().isNotEmpty && mounted) {
      setState(() {
        _textController.setRawText(draft);
        _textController.clearHistory();
      });

      // Restore cursor position for local_draft
      final prefs = await SharedPreferences.getInstance();
      final base = prefs.getInt('draft_cursor_base_local_draft');
      final extent = prefs.getInt('draft_cursor_extent_local_draft');
      if (base != null && extent != null && mounted) {
        final textLength = _textController.text.length;
        if (base <= textLength && extent <= textLength) {
          setState(() {
            _textController.selection = TextSelection(baseOffset: base, extentOffset: extent);
          });
          _textFocusNode.requestFocus();
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.articleDraftRestored)),
      );
    }
  }

  void _applyMagicFormatting() {
    final text = _textController.text;
    if (text.isEmpty) return;
    
    int changesCount = 0;

    String replaceWithCount(String source, Pattern pattern, String Function(Match) replace) {
      return source.replaceAllMapped(pattern, (match) {
        changesCount++;
        return replace(match);
      });
    }

    bool isParagraphEnglish(String paragraph) {
      final clean = paragraph.trim();
      if (clean.isEmpty) return false;

      final arabicRegExp = RegExp(r'[\u0600-\u06FF]');
      final latinRegExp = RegExp(r'[a-zA-Z]');
      
      final arabicCount = arabicRegExp.allMatches(clean).length;
      final latinCount = latinRegExp.allMatches(clean).length;
      
      return latinCount > arabicCount;
    }

    final paragraphs = text.split('\n');
    final formattedParagraphs = <String>[];

    for (int i = 0; i < paragraphs.length; i++) {
      var para = paragraphs[i];
      if (para.trim().isEmpty) {
        formattedParagraphs.add(para);
        continue;
      }

      final format = i < _textController.lineFormats.length ? _textController.lineFormats[i] : ParagraphFormat.none;
      final isFormattedLine = format != ParagraphFormat.none;

      if (isParagraphEnglish(para)) {
        // --- ENGLISH PARAGRAPH ---
        // 1. Convert Arabic punctuation to English if typed by mistake
        para = replaceWithCount(para, '،', (m) => ',');
        para = replaceWithCount(para, '؟', (m) => '?');

        // 2. Clean spaces around brackets
        para = replaceWithCount(para, RegExp(r'\(\s+'), (m) => '(');
        para = replaceWithCount(para, RegExp(r'\s+\)'), (m) => ')');

        // 3. Punctuation spacing (no space before, one space after)
        para = replaceWithCount(para, RegExp(r'\s+([,.;:?!])'), (match) => match.group(1)!);
        para = replaceWithCount(para, RegExp(r'([,.;:?!])(?=[^\s,.;:?!"\d])'), (match) => '${match.group(1)} ');

        // 4. Indentation for English paragraphs
        if (!isFormattedLine && para.isNotEmpty && !para.startsWith(RegExp(r'[\s\u2003=~\[]'))) {
          para = '\u2003$para';
          changesCount++;
        }

        // 5. English spelling fixes for absolute errors
        final englishSpellingFixes = {
          'teh': 'the',
          'dont': "don't",
          'cant': "can't",
          'wont': "won't",
          'im': "I'm",
          'ive': "I've",
          'id': "I'd",
          'youre': "you're",
          'theyre': "they're",
          'weve': "we've",
          'shouldnt': "shouldn't",
          'wouldnt': "wouldn't",
          'couldnt': "couldn't",
          'didnt': "didn't",
          'doesnt': "doesn't",
          'isnt': "isn't",
          'arent': "aren't",
          'wasnt': "wasn't",
          'werent': "weren't",
          'hasnt': "hasn't",
          'havent': "haven't",
          'hadnt': "hadn't",
          'reiceve': 'receive',
          'reiceved': 'received',
          'reiceving': 'receiving',
          'seperate': 'separate',
          'seperated': 'separated',
          'seperating': 'separating',
          'seperation': 'separation',
          'occured': 'occurred',
          'occurence': 'occurrence',
          'alot': 'a lot',
          'wierd': 'weird',
          'goverment': 'government',
          'enviroment': 'environment',
        };

        englishSpellingFixes.forEach((wrong, correct) {
          final pattern = RegExp('\\b' + RegExp.escape(wrong) + '\\b', caseSensitive: false);
          para = replaceWithCount(para, pattern, (match) {
            final matchedText = match.group(0)!;
            if (matchedText.startsWith(RegExp(r'[A-Z]'))) {
              return correct[0].toUpperCase() + correct.substring(1);
            }
            return correct;
          });
        });
      } else {
        // --- ARABIC PARAGRAPH ---
        // 1. Convert English punctuation to Arabic
        para = replaceWithCount(para, ',', (m) => '،');
        para = replaceWithCount(para, '?', (m) => '؟');

        // 2. Double quotes to Arabic quote brackets
        para = replaceWithCount(para, RegExp(r'"([^"]*)"'), (match) => '«${match.group(1)}»');

        // 3. Clean spaces around brackets/quotes
        para = replaceWithCount(para, RegExp(r'\(\s+'), (m) => '(');
        para = replaceWithCount(para, RegExp(r'\s+\)'), (m) => ')');
        para = replaceWithCount(para, RegExp(r'«\s+'), (m) => '«');
        para = replaceWithCount(para, RegExp(r'\s+»'), (m) => '»');

        // 4. Punctuation spacing
        para = replaceWithCount(para, RegExp(r'\s+([،.؛:؟!])'), (match) => match.group(1)!);
        para = replaceWithCount(para, RegExp(r'([،.؛:؟!])(?=[^\s،.؛:؟!])'), (match) => '${match.group(1)} ');

        // 5. Conjunction "و"
        para = replaceWithCount(para, RegExp(r'(?<=\s|^)و([\u064B-\u0652]*)\s+'), (match) => 'و${match.group(1)}');

        // 6. Indentation
        if (!isFormattedLine && para.isNotEmpty && !para.startsWith(RegExp(r'[\s\u2003=~\[]'))) {
          para = '\u2003$para';
          changesCount++;
        }

        // 7. Arabic spelling fixes (static & dynamic)
        final spellingFixes = {
          'انشاء الله': 'إن شاء الله',
          'إنشاء الله': 'إن شاء الله',
          'اللهم صلي': 'اللهم صلِّ',
          'هاذا': 'هذا',
          'هاذه': 'هذه',
          'هاذان': 'هذان',
          'هاؤلاء': 'هؤلاء',
          'ذالك': 'ذلك',
          'كذالك': 'كذلك',
          'لاكن': 'لكن',
          'لاكنه': 'لكنه',
          'لاكنها': 'لكنها',
          'لاكنهم': 'لكنهم',
          'انتي': 'أنتِ',
          'أنتي': 'أنتِ',
          'إسم': 'اسم',
          'أسم': 'اسم',
          'إبن': 'ابن',
          'إمرأة': 'امرأة',
          'أمرأة': 'امرأة',
          'شئ': 'شيء',
          'مأئة': 'مئة',
          'مائة': 'مئة',
          'داوود': 'داود',
          'طاووس': 'طاوس',
          'أولائك': 'أولئك',
          'الى': 'إلى',
          'او': 'أو',
          'ايجاد': 'إيجاد',
          'انشاء': 'إنشاء',
          'ndcwa': 'ندعو',
          'ندعوا': 'ندعو',
          'نرجوا': 'نرجو',
          'مديروا': 'مديرو',
          'اللة': 'الله',
          'حتي': 'حتى',
          'مستشفي': 'مستشفى',
          'جزاكي': 'جزاكِ',
        };

        final dynamicFixes = context.read<GlobalConfigProvider>().spellingFixes;
        final mergedFixes = {...spellingFixes, ...dynamicFixes};

        mergedFixes.forEach((wrong, correct) {
          final baseWrong = wrong.replaceAll(RegExp(r'[\u064B-\u0652]'), '');
          final patternParts = baseWrong.split('').map((char) {
            if (char == ' ') return r'\s+';
            return RegExp.escape(char) + r'[\u064B-\u0652]*';
          }).join('');
          final pattern = RegExp('(?<![\\u0600-\\u06FF])' + patternParts + '(?![\\u0600-\\u06FF])');
          para = replaceWithCount(para, pattern, (match) => correct);
        });
      }

      // Universal paragraph space clean
      para = replaceWithCount(para, RegExp(r'[ \t]{2,}'), (m) => ' ');
      
      formattedParagraphs.add(para);
    }

    String newText = formattedParagraphs.join('\n');
    
    // Clean excessive newlines on the joined text
    newText = replaceWithCount(newText, RegExp(r'\n{3,}'), (m) => '\n\n');

    int wordCount = text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    int score = 100;
    if (wordCount > 0) {
      double errorRate = (changesCount / wordCount) * 100;
      score = (100 - errorRate).clamp(0, 100).toInt();
    }

    String message;
    if (changesCount == 0) {
      message = 'النص سليم تماماً.\nنسبة سلامة النص: 100%';
    } else {
      message = 'تم الانتهاء من التنسيق التلقائي.\n\nعدد التعديلات التي تم تطبيقها: $changesCount\nنسبة سلامة النص الأصلية: $score%';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _MagicFormattingProgressDialog(
        resultMessage: message,
        onComplete: () {
          if (changesCount > 0) {
            setState(() {
              _textController.updateValueProgrammatically(TextEditingValue(
                text: newText,
                selection: TextSelection.collapsed(offset: newText.length),
              ));
            });
          }
          _textFocusNode.requestFocus();
        },
      ),
    );
  }

  void _showQuranInstructionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.menu_book, color: AppColors.primary),
            SizedBox(width: 8),
            Text('تنسيق القرآن'),
          ],
        ),
        content: const Text('حدد نص قرآني لتصحيحه وتنسيقه', style: TextStyle(fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _textFocusNode.requestFocus();
            },
            child: const Text('تم', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _formatQuranVerse() async {
    final selection = _textController.selection;
    if (selection.isCollapsed || selection.start < 0 || selection.end < 0) {
      _showQuranInstructionDialog();
      return;
    }

    final String selectedText = _textController.text.substring(selection.start, selection.end).trim();
    if (selectedText.isEmpty) {
      _showQuranInstructionDialog();
      return;
    }

    final QuranMatch? match = await QuranService.searchAndFormatVerse(selectedText);
    
    if (match != null) {
      final String formattedNum = QuranService.toEasternNumerals(match.verseNumber.toString());
      final String cleanVerse = '﴿${match.uthmaniText}﴾';
      final String citation = ' [${match.surahName}: $formattedNum]';
      final String insertText = '$cleanVerse$citation';
      
      final String currentText = _textController.text;
      final String newText = currentText.replaceRange(selection.start, selection.end, insertText);
      
      setState(() {
        _textController.updateValueProgrammatically(TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: selection.start + insertText.length),
        ));
        _textController.addSpan(selection.start, selection.start + cleanVerse.length, SpanType.bold);
      });
      _textFocusNode.requestFocus();
    } else {
      _showQuranInstructionDialog();
    }
  }

  void _clearFormatting() {
    final raw = _textController.rawText;
    if (raw.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('مسح التنسيقات'),
        content: const Text('هل أنت متأكد من مسح جميع علامات التنسيق من المقال؟\nلا يمكن التراجع عن هذه الخطوة.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              final cleanText = Article.stripFormatting(raw);
              setState(() {
                _textController.setRawText(cleanText);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم مسح جميع علامات التنسيق 🧹'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
              _textFocusNode.requestFocus();
            },
            child: const Text('مسح', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showSearchAndReplaceDialog() {
    final searchController = TextEditingController();
    final replaceController = TextEditingController();
    bool isReplaceMode = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('البحث والاستبدال'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: searchController,
                    decoration: const InputDecoration(
                      labelText: 'الكلمة المبحوثة',
                      hintText: 'أدخل الكلمة للبحث عنها',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('تفعيل الاستبدال'),
                    value: isReplaceMode,
                    onChanged: (val) {
                      setDialogState(() {
                        isReplaceMode = val;
                      });
                    },
                    activeThumbColor: AppColors.primary,
                    activeTrackColor: AppColors.primary.withValues(alpha: 0.5),
                    contentPadding: EdgeInsets.zero,
                  ),
                  AnimatedCrossFade(
                    firstChild: const SizedBox(width: double.infinity, height: 0),
                    secondChild: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: TextField(
                        controller: replaceController,
                        decoration: const InputDecoration(
                          labelText: 'البديل (اتركه فارغاً للحذف)',
                          hintText: 'أدخل الكلمة البديلة الجديدة',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.find_replace),
                        ),
                      ),
                    ),
                    crossFadeState: isReplaceMode
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 250),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () {
                  final searchWord = searchController.text.trim();
                  final replaceWord = replaceController.text;

                  if (searchWord.isEmpty) {
                    Navigator.pop(context);
                    return;
                  }

                  // نبحث في النص النظيف (ما يراه المستخدم) متجاهلين الحركات
                  final cleanText = _textController.cleanText;
                  final baseWord = searchWord.replaceAll(RegExp(r'[\u064B-\u0652]'), '');
                  if (baseWord.isEmpty) {
                    Navigator.pop(context);
                    return;
                  }
                  final regexPattern = baseWord.split('').map((char) => RegExp.escape(char)).join(r'[\u064B-\u0652]*');
                  final diacriticsInsensitiveRegex = RegExp(regexPattern);

                  final matches = diacriticsInsensitiveRegex.allMatches(cleanText);
                  if (matches.isEmpty) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('الكلمة المبحوثة غير موجودة في النص.')),
                    );
                    return;
                  }

                  if (isReplaceMode) {
                    // نطبّق الاستبدال على النص الخام أيضاً
                    final newRaw = _textController.rawText.replaceAll(diacriticsInsensitiveRegex, replaceWord);
                    setState(() {
                      _textController.highlightQuery = null;
                      _textController.setRawText(newRaw);
                    });

                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('تم استبدال ${matches.length} من الكلمات بنجاح.')),
                    );
                  } else {
                    setState(() {
                      _textController.highlightQuery = searchWord;
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('تم العثور على ${matches.length} مطابقة (مطابقات) للكلمة في النص. تم تظليلها باللون الأصفر.')),
                    );
                  }
                  _textFocusNode.requestFocus();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: Text(isReplaceMode ? 'استبدال الكُل' : 'بحث'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _unifiedTextListener() {
    _saveCursorPosition();

    // نتتبع rawText للـ autosave
    final bool currentHasText = _textController.rawText.trim().isNotEmpty;
    if (currentHasText != _hasText) {
      setState(() {
        _hasText = currentHasText;
      });
    }

    if (_textController.rawText != _lastRawText) {
      _lastRawText = _textController.rawText;
      if (_textController.highlightQuery != null) {
        _textController.highlightQuery = null;
      }
      if (_isSelecting) {
        setState(() {
          _isSelecting = false;
          _selectionAnchor = null;
        });
      }

      if (widget.article == null && _draftArticleId == null && !_isCreating) {
        if (_debounce?.isActive ?? false) _debounce!.cancel();
        _debounce = Timer(const Duration(milliseconds: 1500), () async {
          if (_textController.rawText.trim().isNotEmpty && mounted && !_isCreating && _draftArticleId == null) {
            _isCreating = true;
            final provider = context.read<ArticleProvider>();
            final Future<Article?> saveOperation = () async {
              try {
                final draft = await provider.addArticle(
                  text: _textController.rawText,
                  isPublished: _isPublished,
                  isDraft: true,
                  silent: true,
                  tagIds: _selectedTagIds,
                );
                if (draft != null && mounted) {
                  final oldId = 'local_draft';
                  final newId = draft.id;
                  _draftArticleId = newId;
                  LocalDbService.instance.clearArticleDraft();

                  // Migrate cursor position SharedPreferences keys
                  final prefs = await SharedPreferences.getInstance();
                  final base = prefs.getInt('draft_cursor_base_$oldId');
                  final extent = prefs.getInt('draft_cursor_extent_$oldId');
                  if (base != null && extent != null) {
                    await prefs.setInt('draft_cursor_base_$newId', base);
                    await prefs.setInt('draft_cursor_extent_$newId', extent);
                    await prefs.remove('draft_cursor_base_$oldId');
                    await prefs.remove('draft_cursor_extent_$oldId');
                  }
                }
                return draft;
              } finally {
                _isCreating = false;
                _autosaveFuture = null;
              }
            }();
            _autosaveFuture = saveOperation;
            await saveOperation;
          }
        });
      } else {
        if (_debounce?.isActive ?? false) _debounce!.cancel();
        _debounce = Timer(const Duration(milliseconds: 1500), () async {
          final id = widget.article?.id ?? _draftArticleId;
          if (id != null && _textController.rawText.trim().isNotEmpty && mounted) {
            final updated = await context.read<ArticleProvider>().updateArticle(
              id: id,
              text: _textController.rawText,
              isPublished: _isPublished,
              isDraft: true,
              silent: true,
              tagIds: _selectedTagIds,
            );
            if (updated != null && mounted) {
              if (_draftArticleId == id && _draftArticleId != updated.id) {
                setState(() {
                  _draftArticleId = updated.id;
                });
              }
            }
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _textController.removeListener(_unifiedTextListener);
    _textController.dispose();
    _textFocusNode.dispose();
    _editorScrollController.dispose();
    super.dispose();
  }


  void _confirmDeleteImage() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إزالة الصورة'),
        content: const Text('هل أنت متأكد من رغبتك في إزالة صورة غلاف المقال؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _selectedImage = null;
                if (widget.article?.image != null) {
                  _deleteExistingImage = true;
                }
              });
            },
            child: const Text('إزالة', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _pasteFromClipboard() async {
    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null && data.text!.isNotEmpty) {
      final textToPaste = data.text!;
      final text = _textController.text;
      final selection = _textController.selection;
      
      String newText;
      int pasteStart;
      int pasteEnd;
      
      if (selection.isValid) {
        newText = text.replaceRange(selection.start, selection.end, textToPaste);
        pasteStart = selection.start;
        pasteEnd = selection.start + textToPaste.length;
      } else {
        pasteStart = text.length;
        newText = text + textToPaste;
        pasteEnd = newText.length;
      }
      
      setState(() {
        _textController.updateValueProgrammatically(TextEditingValue(
          text: newText,
          selection: TextSelection(
            baseOffset: pasteStart,
            extentOffset: pasteEnd,
          ),
        ));
      });
      _textFocusNode.requestFocus();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الحافظة فارغة أو لا تحتوي على نص.')),
      );
    }
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);

      if (image != null) {
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: image.path,
          compressQuality: 60, // Reduces size to < 100KB typically
          compressFormat: ImageCompressFormat.jpg,
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: context.l10n.editArticleCover,
              toolbarColor: AppColors.primary,
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.original,
              lockAspectRatio: false,
              aspectRatioPresets: [
                CropAspectRatioPreset.original,
                CropAspectRatioPreset.square,
                CropAspectRatioPreset.ratio3x2,
                CropAspectRatioPreset.ratio4x3,
                CropAspectRatioPreset.ratio16x9,
              ],
            ),
            IOSUiSettings(
              title: context.l10n.editArticleCover,
              aspectRatioLockEnabled: false,
              aspectRatioPresets: [
                CropAspectRatioPreset.original,
                CropAspectRatioPreset.square,
                CropAspectRatioPreset.ratio3x2,
                CropAspectRatioPreset.ratio4x3,
                CropAspectRatioPreset.ratio16x9,
              ],
            ),
            WebUiSettings(
              context: context,
              presentStyle: WebPresentStyle.dialog,
              size: const CropperSize(
                width: 380,
                height: 380,
              ),
              translations: WebTranslations(
                title: context.l10n.editArticleCover,
                rotateLeftTooltip: 'تدوير لليسار',
                rotateRightTooltip: 'تدوير لليمين',
                cancelButton: 'إلغاء',
                cropButton: 'قص',
              ),
            ),
          ],
        );

        if (croppedFile != null) {
          setState(() {
            _selectedImage = File(croppedFile.path);
            _deleteExistingImage = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  int _findTagInsertionIndex(String rawText, String cleanName) {
    final lines = rawText.split('\n');
    int tagLineIndex = -1;
    
    for (int i = 0; i < lines.length; i++) {
      final lineUpper = lines[i].toUpperCase().trim();
      if (lineUpper.startsWith('[AUDIO_ADVANCED') && lineUpper.toLowerCase().contains(cleanName)) {
        tagLineIndex = i;
        break;
      }
    }
    
    if (tagLineIndex == -1) {
      for (int i = 0; i < lines.length; i++) {
        final lineUpper = lines[i].toUpperCase().trim();
        if (lineUpper == '[AUDIO_ADVANCED]') {
          tagLineIndex = i;
          break;
        }
      }
    }
    
    if (tagLineIndex != -1) {
      int offset = 0;
      for (int i = 0; i <= tagLineIndex; i++) {
        offset += lines[i].length + 1;
      }
      return offset - 1;
    }
    
    return -1;
  }

  void _handleAITextGenerated(String generatedText, String audioUrl, bool isFinal) {
    final rawText = _textController.rawText;
    final originalName = audioUrl.split('/').last;
    final cleanName = AudioHelper.getCleanAudioTitle(originalName).toLowerCase();

    // 1. Initialize active streaming session if needed
    if (_activeStreamingAudioUrl != audioUrl) {
      final int tagOffset = _findTagInsertionIndex(rawText, cleanName);
      
      if (tagOffset != -1) {
        _streamingStartIndex = tagOffset;
      } else {
        final currentSelection = _textController.selection;
        _streamingStartIndex = currentSelection.isValid ? currentSelection.start : rawText.length;
      }
      
      _activeStreamingAudioUrl = audioUrl;
      _lastStreamingInsertedLength = 0;
    }

    // 2. Perform in-place range replacement
    final String replacement = '\n$generatedText\n';
    final String updatedText = rawText.replaceRange(
      _streamingStartIndex,
      _streamingStartIndex + _lastStreamingInsertedLength,
      replacement,
    );
    
    _lastStreamingInsertedLength = replacement.length;
    final int newCursorOffset = _streamingStartIndex + replacement.length;

    setState(() {
      _textController.setRawText(updatedText);
      _textController.selection = TextSelection.collapsed(offset: newCursorOffset);
    });
  }

  void _showAudioTypeBottomSheet(File pickedFile) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.getCardBackground(context),
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimens.radiusL)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'اختر نوع إدراج الملف الصوتي',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextPrimary(context),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.audiotrack_rounded, color: Colors.blueAccent),
                title: const Text('ملف صوتي بسيط', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('يمكن إدراج عدة ملفات متتابعة في المقال الواحد.'),
                onTap: () {
                  Navigator.pop(context);
                  _processAudioInsertion(pickedFile, isAdvanced: false);
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.spatial_audio_off_rounded, color: Colors.teal),
                title: const Text('ملف صوتي متقدم', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('ملف صوتي وحيد مع تحكم كامل بالسرعة، تكرار A-B، وتفريغ/تلخيص بالذكاء الاصطناعي.'),
                onTap: () {
                  Navigator.pop(context);
                  _processAudioInsertion(pickedFile, isAdvanced: true);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _processAudioInsertion(File pickedFile, {required bool isAdvanced}) {
    final totalFiles = _existingAudios.length + _selectedAudios.length;
    final bool hasAdvanced = _textController.rawText.toUpperCase().contains('[AUDIO_ADVANCED');

    if (isAdvanced) {
      if (totalFiles > 0) {
        _showErrorSnackBar('المشغل المتقدم يتطلب أن يكون هو الملف الوحيد في المقال. يرجى حذف الملفات الصوتية الحالية أولاً.');
        return;
      }
    } else {
      if (hasAdvanced) {
        _showErrorSnackBar('هذا المقال مخصص لملف صوتي متقدم وحيد. لا يمكن إدراج ملفات بسيطة إضافية.');
        return;
      }
    }

    final int fileSize = pickedFile.lengthSync();
    final configProvider = Provider.of<GlobalConfigProvider>(context, listen: false);
    final double maxFileMb = configProvider.audioMaxSizeMb.toDouble();
    final double totalCapacityMb = configProvider.audioTotalCapacityMb.toDouble();

    if (fileSize > maxFileMb * 1024 * 1024) {
      _showErrorSnackBar('حجم الملف الصوتي (${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB) يتجاوز الحد المسموح به للملف الواحد وهو $maxFileMb ميجابايت.');
      return;
    }

    int totalLocalSize = 0;
    for (final f in _selectedAudios) {
      totalLocalSize += f.lengthSync();
    }

    final int totalSize = totalLocalSize + fileSize + (_existingAudios.length * 4 * 1024 * 1024);
    if (totalSize > totalCapacityMb * 1024 * 1024) {
      _showErrorSnackBar('إجمالي حجم الملفات الصوتية (${(totalSize / (1024 * 1024)).toStringAsFixed(1)}MB) يتجاوز السعة الإجمالية المسموح بها وهي $totalCapacityMb ميجابايت.');
      return;
    }

    setState(() {
      _selectedAudios.add(pickedFile);
    });

    final String originalName = pickedFile.path.split('/').last;
    final String cleanFilename = AudioHelper.getCleanAudioTitle(originalName);
    final String audioTag = isAdvanced 
        ? '\n[AUDIO_ADVANCED: $cleanFilename]\n' 
        : '\n[AUDIO: $cleanFilename]\n';

    final currentSelection = _textController.selection;
    final rawText = _textController.rawText;
    
    String newText;
    int newCursorOffset;
    if (currentSelection.isValid) {
      final start = currentSelection.start;
      final end = currentSelection.end;
      newText = rawText.replaceRange(start, end, audioTag);
      newCursorOffset = start + audioTag.length;
    } else {
      newText = '$rawText$audioTag';
      newCursorOffset = newText.length;
    }
    
    _textController.setRawText(newText);
    _textController.selection = TextSelection.collapsed(offset: newCursorOffset);
    _textFocusNode.requestFocus();
  }

  Future<void> _pickAudio() async {
    try {
      final globalConfig = context.read<GlobalConfigProvider>();
      final maxFiles = globalConfig.audioMaxFiles;
      final bool hasAdvanced = _textController.rawText.toUpperCase().contains('[AUDIO_ADVANCED');

      if (hasAdvanced) {
        _showErrorSnackBar('هذا المقال مخصص لملف صوتي متقدم وحيد. لا يمكن إدراج ملفات إضافية.');
        return;
      }

      final int currentCount = _existingAudios.length + _selectedAudios.length;
      if (currentCount >= maxFiles) {
        _showErrorSnackBar('لقد تجاوزت الحد الأقصى للملفات الصوتية المسموح بها وهو $maxFiles ملفات.');
        return;
      }

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'opus', 'ogg', 'caf'],
      );
      if (result != null && result.files.single.path != null) {
        final pickedFile = File(result.files.single.path!);
        _showAudioTypeBottomSheet(pickedFile);
      }
    } catch (e) {
      debugPrint('Error picking audio: $e');
    }
  }
 
  void _confirmDeleteExistingAudio(String fileName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إزالة الملف الصوتي'),
        content: const Text('هل أنت متأكد من رغبتك في حذف هذا الملف الصوتي من المقال نهائياً؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _existingAudios.remove(fileName);
              });
            },
            child: Text(
              context.l10n.delete,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _submit() async {
    if (_textController.rawText.trim().isEmpty) return;

    _debounce?.cancel();
    if (_autosaveFuture != null) {
      setState(() => _isLoading = true);
      await _autosaveFuture;
    }

    setState(() => _isLoading = true);

    final provider = context.read<ArticleProvider>();
    Article? resultArticle;

    if (widget.article != null || _draftArticleId != null) {
      final id = widget.article?.id ?? _draftArticleId!;
      resultArticle = await provider.updateArticle(
        id: id,
        text: _textController.rawText,
        isPublished: _isPublished,
        isDraft: false,
        imageFile: _selectedImage,
        removeImage: _deleteExistingImage,
        audioFiles: _selectedAudios,
        existingAudios: _existingAudios,
        tagIds: _selectedTagIds,
      );
    } else {
      resultArticle = await provider.addArticle(
        text: _textController.rawText,
        isPublished: _isPublished,
        isDraft: false,
        imageFile: _selectedImage,
        audioFiles: _selectedAudios,
        tagIds: _selectedTagIds,
      );
    }

    setState(() => _isLoading = false);

    if (resultArticle != null) {
      if (widget.article == null) {
        await LocalDbService.instance.clearArticleDraft();
      }

      // Clear cursor position keys
      final prefs = await SharedPreferences.getInstance();
      final draftId = widget.article?.id ?? _draftArticleId ?? 'local_draft';
      await prefs.remove('draft_cursor_base_$draftId');
      await prefs.remove('draft_cursor_extent_$draftId');
      if (widget.article == null || widget.article?.id != _draftArticleId) {
        await prefs.remove('draft_cursor_base_local_draft');
        await prefs.remove('draft_cursor_extent_local_draft');
      }

      if (mounted) Navigator.pop(context);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(provider.errorMessage ?? context.l10n.errorOccurred)),
        );
      }
    }
  }

  void _clearDraft() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.clearFormTitle),
        content: Text(context.l10n.clearFormConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() {
                _textController.clear();
                _selectedImage = null;
                _selectedAudios.clear();
                _existingAudios.clear();
                _isPublished = false;
              });
              if (widget.article == null) {
                await LocalDbService.instance.clearArticleDraft();
              }

              // Clear cursor position keys
              final prefs = await SharedPreferences.getInstance();
              final draftId = widget.article?.id ?? _draftArticleId ?? 'local_draft';
              await prefs.remove('draft_cursor_base_$draftId');
              await prefs.remove('draft_cursor_extent_$draftId');
              await prefs.remove('draft_cursor_base_local_draft');
              await prefs.remove('draft_cursor_extent_local_draft');

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.l10n.formClearedSuccessfully)),
                );
              }
            },
            child: Text(context.l10n.clear, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  int? _getCorrectedOffset(Offset localPosition) {
    final text = _textController.text;
    if (text.isEmpty) return null;

    final RenderBox? renderBox = _textFocusNode.context?.findRenderObject() as RenderBox?;
    if (renderBox == null) return null;

    final double paddingLeft = 16.0;
    final double paddingTop = 16.0;
    final double paddingRight = 16.0;
    
    final double scrollY = _editorScrollController.hasClients ? _editorScrollController.offset : 0.0;
    
    final double x = localPosition.dx - paddingLeft;
    final double y = localPosition.dy - paddingTop + scrollY;

    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 18,
          height: 1.5,
          color: AppColors.getTextPrimary(context),
        ),
      ),
      textDirection: BidiUtils.getDirection(text, fallback: Localizations.localeOf(context).languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr),
      textAlign: TextAlign.start,
    );

    final double maxWidth = renderBox.size.width - (paddingLeft + paddingRight);
    if (maxWidth <= 0) return null;
    
    textPainter.layout(maxWidth: maxWidth);

    // Get line metrics
    final lineMetrics = textPainter.computeLineMetrics();
    if (lineMetrics.isEmpty) return null;

    // Find which line the tap y-coordinate belongs to
    int tapLineIdx = -1;
    double currentY = 0;
    for (int i = 0; i < lineMetrics.length; i++) {
      final lineH = lineMetrics[i].height;
      if (y >= currentY && y <= currentY + lineH) {
        tapLineIdx = i;
        break;
      }
      currentY += lineH;
    }

    if (tapLineIdx == -1) {
      if (y > currentY) {
        return text.length;
      }
      return null;
    }

    // Get the default resolved position for this offset
    final TextPosition resolvedPosition = textPainter.getPositionForOffset(Offset(x, y));
    final int originalResolvedOffset = resolvedPosition.offset;

    // Helper to find the visual line index of a vertical caret coordinate
    int getVisualLineIdxForY(double yCoordinate) {
      double curY = 0;
      for (int i = 0; i < lineMetrics.length; i++) {
        final lineH = lineMetrics[i].height;
        if (yCoordinate >= curY && yCoordinate < curY + lineH) {
          return i;
        }
        curY += lineH;
      }
      if (yCoordinate >= curY) {
        return lineMetrics.length - 1;
      }
      return 0;
    }

    // Find visual line of original resolved offset using caret dy position
    final double originalResolvedCaretY = textPainter.getOffsetForCaret(resolvedPosition, Rect.zero).dy;
    final int originalResolvedLineIdx = getVisualLineIdxForY(originalResolvedCaretY);

    if (originalResolvedLineIdx > tapLineIdx) {
      // Compute center of tapLineIdx
      double tapLineCenterY = 0;
      for (int i = 0; i < tapLineIdx; i++) {
        tapLineCenterY += lineMetrics[i].height;
      }
      tapLineCenterY += lineMetrics[tapLineIdx].height / 2;

      final int leftOffset = textPainter.getPositionForOffset(Offset(0, tapLineCenterY)).offset;
      final int rightOffset = textPainter.getPositionForOffset(Offset(maxWidth, tapLineCenterY)).offset;
      int correctedOffset = leftOffset > rightOffset ? leftOffset : rightOffset;
      
      // Apply newline correction to the corrected offset as well
      if (correctedOffset > 0 && text.codeUnitAt(correctedOffset - 1) == 10) {
        correctedOffset--;
      }

      return correctedOffset;
    }

    return null;
  }

  String _generatePoemTemplate({
    required bool hasTitle,
    required String titleText,
    required String poetName,
    required String poetLocation,
    required String poemType,
    required bool hasSeparators,
  }) {
    final List<String> lines = [];
    lines.add('[POEM]');
    
    if (hasTitle && titleText.trim().isNotEmpty) {
      lines.add('= ${titleText.trim()} =');
    }
    
    if (poetLocation == 'top' && poetName.trim().isNotEmpty) {
      lines.add('= للشاعر: ${poetName.trim()} =');
    }
    
    if (poemType == 'classical') {
      lines.add('البيت الأول صدر');
      lines.add('البيت الأول عجز');
      if (hasSeparators) {
        lines.add('= * * * =');
      } else {
        lines.add('');
      }
      lines.add('البيت الثاني صدر');
      lines.add('البيت الثاني عجز');
    } else if (poemType == 'quatrain') {
      lines.add('الشطر الأول');
      lines.add('الشطر الثاني');
      lines.add('الشطر الثالث');
      lines.add('الشطر الرابع');
      if (hasSeparators) {
        lines.add('= * * * =');
      } else {
        lines.add('');
      }
      lines.add('الشطر الخامس');
      lines.add('الشطر السادس');
      lines.add('الشطر السابع');
      lines.add('الشطر الثامن');
    } else if (poemType == 'quintain') {
      lines.add('السطر الأول');
      lines.add('السطر الثاني');
      lines.add('السطر الثالث');
      lines.add('السطر الرابع');
      lines.add('السطر الخامس');
      if (hasSeparators) {
        lines.add('= * * * =');
      } else {
        lines.add('');
      }
      lines.add('السطر السادس');
      lines.add('السطر السابع');
      lines.add('السطر الثامن');
      lines.add('السطر التاسع');
      lines.add('السطر العاشر');
    } else {
      lines.add('السطر الشعري الأول');
      lines.add('السطر الشعري الثاني');
      lines.add('السطر الشعري الثالث');
    }
    
    if (poetLocation == 'bottom' && poetName.trim().isNotEmpty) {
      lines.add('-- للشاعر: ${poetName.trim()} --');
    }
    
    lines.add('[/POEM]');
    return lines.join('\n');
  }

  void _showPoemSetupDialog(BuildContext context, int lineIndex) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return const PoemSetupDialog();
      },
    ).then((result) {
      if (result != null && result is Map<String, dynamic>) {
        final hasTitle = result['hasTitle'] as bool;
        final titleText = result['titleText'] as String;
        final poetName = result['poetName'] as String;
        final poetLocation = result['poetLocation'] as String;
        final poemType = result['poemType'] as String;
        final hasSeparators = result['hasSeparators'] as bool;

        final template = _generatePoemTemplate(
          hasTitle: hasTitle,
          titleText: titleText,
          poetName: poetName,
          poetLocation: poetLocation,
          poemType: poemType,
          hasSeparators: hasSeparators,
        );

        setState(() {
          _textController.insertPoemTemplateAtLine(lineIndex, template);
        });
        _textFocusNode.requestFocus();
      }
    });
  }

  void _handlePoemToolbarAction() {
    // PoemSetupDialog is temporarily disabled until further notice.
    _textController.toggleParagraphFormat(ParagraphFormat.poem);
    _textFocusNode.requestFocus();
  }

  Widget _buildCategoriesBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Consumer<TagProvider>(
      builder: (context, tagProvider, child) {
        final List<Tag> selectedTags = [];
        for (final id in _selectedTagIds) {
          final tag = tagProvider.tags.firstWhere(
            (t) => t.id == id,
            orElse: () => Tag(id: id, name: id, colorHex: '6B7280', userId: ''),
          );
          selectedTags.add(tag);
        }

        final voidCallback = () {
          TagSelectorSheet.show(
            context,
            initialSelectedTagIds: _selectedTagIds,
            onSelectionChanged: (selectedIds, tags) {
              setState(() {
                _selectedTagIds = selectedIds;
              });
            },
          );
        };

        return Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: isDark ? Colors.white10 : Colors.grey.shade200,
                width: 1.0,
              ),
            ),
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Row(
              children: [
                IconButton(
                  tooltip: context.l10n.articleCategoryTooltip,
                  icon: const Icon(Icons.label_outline),
                  color: AppColors.primary,
                  onPressed: voidCallback,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: voidCallback,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: selectedTags.isEmpty
                          ? Text(
                              context.l10n.noCategoryAddedYet,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white30 : Colors.grey.shade400,
                              ),
                            )
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Row(
                                children: selectedTags.map((tag) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                    child: TagChip(
                                      tag: tag,
                                      onTap: voidCallback,
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isKeyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(44.0),
        child: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.getTextPrimary(context),
          systemOverlayStyle: Theme.of(context).brightness == Brightness.dark 
              ? SystemUiOverlayStyle.light 
              : SystemUiOverlayStyle.dark,
          actions: [
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
              )
            else ...[
              if (_hasText || _selectedImage != null)
                TextButton(
                  onPressed: _clearDraft,
                  child: Text(context.l10n.clear, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                ),
              TextButton(
                onPressed: _hasText ? _submit : null,
                child: Text(context.l10n.save, style: TextStyle(color: _hasText ? AppColors.primary : Colors.grey, fontWeight: FontWeight.bold)),
              ),
            ]
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCategoriesBar(),
          // Text Formatting Toolbar
          Container(
            color: AppColors.getCardBackground(context),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            // 1. الضبط: الفقرة الحالية
                            ListenableBuilder(
                              listenable: _textController,
                              builder: (context, _) {
                                final active = _textController.currentParagraphFormat == ParagraphFormat.justify;
                                return IconButton(
                                  tooltip: context.l10n.justifyTooltip,
                                  icon: const Icon(Icons.format_align_justify),
                                  color: active ? AppColors.error : AppColors.primary,
                                  onPressed: () {
                                    _textController.toggleParagraphFormat(ParagraphFormat.justify);
                                    _textFocusNode.requestFocus();
                                  },
                                );
                              },
                            ),
                            // 2. التوسيط: الفقرة الحالية
                            ListenableBuilder(
                              listenable: _textController,
                              builder: (context, _) {
                                final active = _textController.currentParagraphFormat == ParagraphFormat.center;
                                return IconButton(
                                  tooltip: context.l10n.centerTooltip,
                                  icon: const Icon(Icons.format_align_center),
                                  color: active ? AppColors.error : AppColors.primary,
                                  onPressed: () {
                                    _textController.toggleParagraphFormat(ParagraphFormat.center);
                                    _textFocusNode.requestFocus();
                                  },
                                );
                              },
                            ),
                            // 3. محاذاة يسار / تغيير الاتجاه: الفقرة الحالية
                            ListenableBuilder(
                              listenable: _textController,
                              builder: (context, _) {
                                final active = _textController.currentParagraphFormat == ParagraphFormat.left;
                                return IconButton(
                                  tooltip: 'محاذاة لليسار (تغيير الاتجاه)',
                                  icon: const Icon(Icons.format_align_left),
                                  color: active ? AppColors.error : AppColors.primary,
                                  onPressed: () {
                                    _textController.toggleParagraphFormat(ParagraphFormat.left);
                                    _textFocusNode.requestFocus();
                                  },
                                );
                              },
                            ),
                            // 4. تنسيق الشعر: الفقرة الحالية (مع استخدام رمز عمودين مخصص)
                            if (Localizations.localeOf(context).languageCode == 'ar')
                              ListenableBuilder(
                                listenable: _textController,
                                builder: (context, _) {
                                  final active = _textController.currentParagraphFormat == ParagraphFormat.poem;
                                  return IconButton(
                                    tooltip: context.l10n.poemTooltip,
                                    icon: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: List.generate(5, (index) {
                                            return Padding(
                                              padding: EdgeInsets.only(bottom: index == 4 ? 0 : 2),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Container(
                                                    width: 8,
                                                    height: 2,
                                                    decoration: BoxDecoration(
                                                      color: active ? AppColors.error : AppColors.primary,
                                                      borderRadius: BorderRadius.circular(1),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Container(
                                                    width: 8,
                                                    height: 2,
                                                    decoration: BoxDecoration(
                                                      color: active ? AppColors.error : AppColors.primary,
                                                      borderRadius: BorderRadius.circular(1),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }),
                                        ),
                                      ),
                                    ),
                                    onPressed: _handlePoemToolbarAction,
                                  );
                                },
                              ),
                            // 5. تعريض الخط: الجزء المحدد
                            ListenableBuilder(
                              listenable: _textController,
                              builder: (context, _) => IconButton(
                                tooltip: context.l10n.boldTooltip,
                                icon: const Icon(Icons.format_bold),
                                color: AppColors.primary,
                                onPressed: () {
                                  _textController.toggleBoldAtCursor();
                                  _textFocusNode.requestFocus();
                                },
                              ),
                            ),
                            // 5.5. تمييز النص (قلم التظليل)
                            ListenableBuilder(
                              listenable: _textController,
                              builder: (context, _) => IconButton(
                                tooltip: 'قلم التظليل',
                                icon: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Cap/Tip (Black)
                                        Container(
                                          width: 5,
                                          height: 3,
                                          decoration: const BoxDecoration(
                                            color: Colors.black,
                                            borderRadius: BorderRadius.vertical(top: Radius.circular(1)),
                                          ),
                                        ),
                                        // Body (Yellow)
                                        Container(
                                          width: 7,
                                          height: 11,
                                          color: const Color(0xFFFFEB3B), // Yellow color for highlighter
                                        ),
                                        // Base (Black)
                                        Container(
                                          width: 7,
                                          height: 3,
                                          decoration: const BoxDecoration(
                                            color: Colors.black,
                                            borderRadius: BorderRadius.vertical(bottom: Radius.circular(1)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                onPressed: () {
                                  _textController.toggleHighlightAtCursor();
                                  _textFocusNode.requestFocus();
                                },
                              ),
                            ),
                            // 5.7. تنسيق آية قرآنية
                            if (Localizations.localeOf(context).languageCode == 'ar')
                              IconButton(
                                tooltip: 'تنسيق آية قرآنية',
                                icon: Text(
                                  '﴿آية﴾',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppColors.primary,
                                  ),
                                ),
                                onPressed: _formatQuranVerse,
                              ),
                            // 6. تصحيح إملائي
                            IconButton(
                              tooltip: 'تصحيح إملائي',
                              icon: const Icon(Icons.auto_fix_high),
                              color: AppColors.primary,
                              onPressed: _applyMagicFormatting,
                            ),
                            // 7. إلغاء التنسيق
                            IconButton(
                              tooltip: 'مسح التنسيقات',
                              icon: const Icon(Icons.format_clear),
                              color: AppColors.error,
                              onPressed: _clearFormatting,
                            ),
                            // 8. بحث واستبدال
                            IconButton(
                              tooltip: 'بحث واستبدال',
                              icon: const Icon(Icons.find_replace),
                              color: AppColors.primary,
                              onPressed: _showSearchAndReplaceDialog,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // السطر الثاني للأزرار (مرتب من اليسار إلى اليمين LTR)
          Container(
            color: AppColors.getCardBackground(context),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // من اليسار: زر الصورة وزر الصوت
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Builder(
                        builder: (context) {
                          final hasImage = _selectedImage != null || (widget.article?.image != null && widget.article!.image!.isNotEmpty && !_deleteExistingImage);
                          return IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: hasImage ? 'إزالة الصورة' : 'إضافة صورة غلاف',
                            icon: Icon(
                              hasImage ? Icons.no_photography : Icons.add_photo_alternate_outlined,
                              color: hasImage ? AppColors.error : AppColors.primary,
                            ),
                            onPressed: hasImage ? _confirmDeleteImage : _pickImage,
                          );
                        },
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'إضافة ملف صوتي/واتساب 🎙️',
                        icon: const Icon(
                          Icons.mic_none_outlined,
                          color: AppColors.primary,
                        ),
                        onPressed: _pickAudio,
                      ),
                    ],
                  ),
                  // بالوسط: أدوات تحريك المؤشر والتظليل
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'تحريك المؤشر لليمين',
                        icon: const Icon(Icons.arrow_back, size: 20),
                        color: AppColors.primary,
                        onPressed: () {
                          final text = _textController.text;
                          final selection = _textController.selection;
                          if (selection.isValid) {
                            setState(() {
                              final currentExtent = selection.extentOffset;
                              final newOffset = currentExtent < text.length ? currentExtent + 1 : text.length;
                              if (_isSelecting && _selectionAnchor != null) {
                                _textController.selection = TextSelection(baseOffset: _selectionAnchor!, extentOffset: newOffset);
                              } else {
                                _textController.selection = TextSelection.collapsed(offset: newOffset);
                              }
                            });
                            _textFocusNode.requestFocus();
                          }
                        },
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: _isSelecting ? 'إلغاء التظليل' : 'بدء التظليل',
                        icon: Icon(_isSelecting ? Icons.highlight_remove : Icons.highlight, size: 20),
                        color: _isSelecting ? AppColors.error : AppColors.primary,
                        onPressed: () {
                          setState(() {
                            _isSelecting = !_isSelecting;
                            if (_isSelecting) {
                              _selectionAnchor = _textController.selection.isValid ? _textController.selection.extentOffset : 0;
                            } else {
                              _selectionAnchor = null;
                            }
                          });
                          _textFocusNode.requestFocus();
                        },
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'تحريك المؤشر لليسار',
                        icon: const Icon(Icons.arrow_forward, size: 20),
                        color: AppColors.primary,
                        onPressed: () {
                          final selection = _textController.selection;
                          if (selection.isValid) {
                            setState(() {
                              final currentExtent = selection.extentOffset;
                              final newOffset = currentExtent > 0 ? currentExtent - 1 : 0;
                              if (_isSelecting && _selectionAnchor != null) {
                                _textController.selection = TextSelection(baseOffset: _selectionAnchor!, extentOffset: newOffset);
                              } else {
                                _textController.selection = TextSelection.collapsed(offset: newOffset);
                              }
                            });
                            _textFocusNode.requestFocus();
                          }
                        },
                      ),
                    ],
                  ),
                  // باليمين: أزرار التراجع والتقدم، زر المعاينة، وزر اللصق
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListenableBuilder(
                        listenable: _textController,
                        builder: (context, _) => IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'تراجع (Undo)',
                          icon: const Icon(Icons.undo),
                          color: _textController.canUndo ? AppColors.primary : AppColors.getHintColor(context).withValues(alpha: 0.5),
                          onPressed: _textController.canUndo
                              ? () {
                                  _textController.undo();
                                  _textFocusNode.requestFocus();
                                }
                              : null,
                        ),
                      ),
                      ListenableBuilder(
                        listenable: _textController,
                        builder: (context, _) => IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'إعادة/تقدم (Redo)',
                          icon: const Icon(Icons.redo),
                          color: _textController.canRedo ? AppColors.primary : AppColors.getHintColor(context).withValues(alpha: 0.5),
                          onPressed: _textController.canRedo
                              ? () {
                                  _textController.redo();
                                  _textFocusNode.requestFocus();
                                }
                              : null,
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: _isPreviewMode ? context.l10n.closePreview : context.l10n.livePreview,
                        icon: Icon(
                          _isPreviewMode ? Icons.visibility_off : Icons.visibility,
                          color: _isPreviewMode ? AppColors.error : AppColors.primary,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPreviewMode = !_isPreviewMode;
                          });
                        },
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'لصق من الحافظة',
                        icon: const Icon(Icons.content_paste),
                        color: AppColors.primary,
                        onPressed: _pasteFromClipboard,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const Divider(height: 1),

          const Divider(height: 1),

          // Hide cover image preview when keyboard is visible to free up vertical space for the text editor
          if (!isKeyboardVisible) ...[
            if (_selectedImage != null) ...[
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 120, // Compact height
                  width: double.infinity,
                  color: AppColors.getCardBackground(context),
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(_selectedImage!, fit: BoxFit.cover),
                      Container(color: Colors.black26),
                      const Center(
                        child: Icon(Icons.edit, color: Colors.white, size: 24),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
            ] else if (widget.article?.image != null && widget.article!.image!.isNotEmpty && !_deleteExistingImage) ...[
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 120, // Compact height
                  width: double.infinity,
                  color: AppColors.getCardBackground(context),
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        'https://sijilli.pockethost.io/api/files/articles/${widget.article!.id}/${widget.article!.image}',
                        fit: BoxFit.cover,
                      ),
                      Container(color: Colors.black26),
                      const Center(
                        child: Icon(Icons.edit, color: Colors.white, size: 24),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
            ],
          ],

          if (_existingAudios.isNotEmpty || _selectedAudios.isNotEmpty) ...[
            Builder(
              builder: (context) {
                final globalConfig = context.watch<GlobalConfigProvider>();
                final maxFiles = globalConfig.audioMaxFiles;
                final totalCapacityMb = globalConfig.audioTotalCapacityMb;
                
                int totalLocalSize = 0;
                for (final f in _selectedAudios) {
                  totalLocalSize += f.lengthSync();
                }
                final double totalSizeMb = (totalLocalSize / (1024 * 1024)) + (_existingAudios.length * 4.0);
                final int currentCount = _existingAudios.length + _selectedAudios.length;
                
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  color: AppColors.getCardBackground(context).withOpacity(0.6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.insert_drive_file_outlined, size: 14, color: AppColors.getTextSecondary(context)),
                          const SizedBox(width: 4),
                          Text(
                            'عدد الملفات: $currentCount / $maxFiles',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.getTextSecondary(context)),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(Icons.cloud_queue_rounded, size: 14, color: AppColors.getTextSecondary(context)),
                          const SizedBox(width: 4),
                          Text(
                            'السعة: ${totalSizeMb.toStringAsFixed(1)}MB / ${totalCapacityMb}MB',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.getTextSecondary(context)),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }
            ),
            const Divider(height: 1),
            // Wrap list in a ConstrainedBox & SingleChildScrollView so it doesn't grow infinitely and push editor off-screen
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: isKeyboardVisible ? 60.0 : 120.0,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ..._existingAudios.map((file) {
                      final displayName = AudioHelper.getAudioDisplayName(
                        file,
                        _textController.rawText,
                        _existingAudios,
                      );
                      return Container(
                        key: ValueKey('existing_$file'),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        color: AppColors.getCardBackground(context),
                        child: Row(
                          children: [
                            const Icon(Icons.audiotrack_rounded, color: Colors.green, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                displayName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                _confirmDeleteExistingAudio(file);
                              },
                            ),
                          ],
                        ),
                      );
                    }),
                    ..._selectedAudios.map((file) {
                      final displayName = file.path.split('/').last;
                      return Container(
                        key: ValueKey('selected_${file.path}'),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        color: AppColors.getCardBackground(context),
                        child: Row(
                          children: [
                            const Icon(Icons.audiotrack_rounded, color: AppColors.primary, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                displayName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: Colors.red, size: 18),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                setState(() {
                                  _selectedAudios.remove(file);
                                });
                              },
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
          ],

          // Editor & Preview Area
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_isPreviewMode) ...[
                  // Top Half: Live Preview
                  Expanded(
                    flex: 1,
                    child: GestureDetector(
                      onTap: () {
                        // When the user taps the preview, focus the text editor below
                        _textFocusNode.requestFocus();
                      },
                      child: Container(
                        color: AppColors.getBackground(context),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16.0),
                          child: ListenableBuilder(
                            listenable: _textController,
                            builder: (context, _) {
                              final List<String> previewAudioUrls = [];
                              if (widget.article != null) {
                                for (final file in _existingAudios) {
                                  previewAudioUrls.add('https://sijilli.pockethost.io/api/files/articles/${widget.article!.id}/$file');
                                }
                              }
                              for (final file in _selectedAudios) {
                                previewAudioUrls.add(file.path);
                              }
                              return ArticleContentRenderer(
                                text: _textController.rawText,
                                audioUrls: previewAudioUrls,
                                onTextGenerated: _handleAITextGenerated,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 2, thickness: 2),
                ],
                // Bottom Half: Text Editor
                // NOTE: TextField with maxLines:null and scrollPhysics handles its own
                // scrolling. Wrapping it in SingleChildScrollView caused two bugs:
                // 1. Scroll conflict made touch-hold selection in the first line unreliable.
                // 2. Keyboard avoidance computed wrong offsets for the first few lines.
                Expanded(
                  child: Listener(
                    onPointerDown: (event) {
                      _lastPointerDownOffset = event.localPosition;
                    },
                    child: TextField(
                      controller: _textController,
                      focusNode: _textFocusNode,
                      scrollController: _editorScrollController,
                      maxLines: null,
                      expands: true,
                      keyboardType: TextInputType.multiline,
                      textAlignVertical: TextAlignVertical.top,
                      textDirection: BidiUtils.getDirection(_textController.text, fallback: Localizations.localeOf(context).languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr),
                      selectionWidthStyle: ui.BoxWidthStyle.tight,
                      selectionHeightStyle: ui.BoxHeightStyle.tight,
                      style: TextStyle(
                        fontSize: 18,
                        height: 1.5,
                        color: AppColors.getTextPrimary(context),
                      ),
                      onTap: () {
                        if (_lastPointerDownOffset != null && mounted) {
                          final corrected = _getCorrectedOffset(_lastPointerDownOffset!);
                          if (corrected != null) {
                            setState(() {
                              _textController.selection = TextSelection.collapsed(offset: corrected);
                            });
                          }
                          _lastPointerDownOffset = null;
                        }
                      },
                      decoration: InputDecoration(
                        hintText: context.l10n.writeArticleHint,
                        hintStyle: TextStyle(color: AppColors.getHintColor(context)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(16.0),
                      ),
                      maxLength: context.read<GlobalConfigProvider>().articleMaxChars,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MagicFormattingProgressDialog extends StatefulWidget {
  final VoidCallback onComplete;
  final String resultMessage;

  const _MagicFormattingProgressDialog({
    required this.onComplete,
    required this.resultMessage,
  });

  @override
  State<_MagicFormattingProgressDialog> createState() => _MagicFormattingProgressDialogState();
}

class _MagicFormattingProgressDialogState extends State<_MagicFormattingProgressDialog> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progress;
  final List<String> _words = [
    'جاري التدقيق...',
    'تحليل الكلمات...',
    'ضبط القواعد...',
    'تصحيح الإملاء...',
    'تنسيق الفقرات...',
    'معالجة النصوص...'
  ];
  String _currentWord = 'جاري التدقيق...';
  bool _isDone = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500));
    _progress = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    
    _controller.addListener(() {
      if (mounted) {
        setState(() {
          int wordIndex = (_progress.value * _words.length).floor();
          if (wordIndex >= _words.length) wordIndex = _words.length - 1;
          _currentWord = _words[wordIndex];
        });
      }
    });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          setState(() {
            _isDone = true;
          });
          widget.onComplete();
        }
      }
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isDone) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('اكتمل التدقيق'),
          ],
        ),
        content: Text(widget.resultMessage, style: const TextStyle(fontSize: 16, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('تم', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      );
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('التدقيق الآلي', textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _progress.value,
              minHeight: 10,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '${(_progress.value * 100).toInt()}%',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              _currentWord,
              key: ValueKey<String>(_currentWord),
              style: const TextStyle(color: Colors.grey, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class PoemSetupDialog extends StatefulWidget {
  const PoemSetupDialog({super.key});

  @override
  State<PoemSetupDialog> createState() => _PoemSetupDialogState();
}

class _PoemSetupDialogState extends State<PoemSetupDialog> {
  bool _hasTitle = false;
  final TextEditingController _titleController = TextEditingController();
  
  String _poemType = 'classical'; // 'classical', 'quatrain', 'quintain', 'free'
  String _poetLocation = 'none'; // 'none', 'top', 'bottom'
  final TextEditingController _poetNameController = TextEditingController();
  
  bool _hasSeparators = true;

  @override
  void dispose() {
    _titleController.dispose();
    _poetNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      title: const Row(
        children: [
          Text('📜 ', style: TextStyle(fontSize: 24)),
          Text(
            'إعداد قالب القصيدة',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. هل يوجد عنوان للقصيدة؟
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: AppColors.primary,
                title: const Text(
                  'هل يوجد عنوان للقصيدة؟',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                value: _hasTitle,
                onChanged: (val) => setState(() => _hasTitle = val),
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      hintText: 'أدخل عنوان القصيدة...',
                      filled: true,
                      fillColor: isDark ? Colors.white10 : Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                      ),
                    ),
                  ),
                ),
                crossFadeState: _hasTitle ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
              const Divider(),
              // 2. نوع القصيدة
              const Text(
                'نوع القصيدة / القالب الفني:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _poemType,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: isDark ? Colors.white10 : Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: const [
                  DropdownMenuItem(value: 'classical', child: Text('عمودية (شطرين: صدر وعجز)')),
                  DropdownMenuItem(value: 'quatrain', child: Text('رباعية (مجموعات ٤ أشطر)')),
                  DropdownMenuItem(value: 'quintain', child: Text('خماسية (مجموعات ٥ أشطر)')),
                  DropdownMenuItem(value: 'free', child: Text('حرة / تفعيلة (سطر تلو الآخر)')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _poemType = val);
                },
              ),
              const SizedBox(height: 12),
              const Divider(),
              // 3. اسم الشاعر وموقعه
              const Text(
                'اسم الشاعر وموقعه:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _poetLocation,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: isDark ? Colors.white10 : Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: const [
                  DropdownMenuItem(value: 'none', child: Text('لا يوجد اسم شاعر')),
                  DropdownMenuItem(value: 'top', child: Text('في الأعلى (قبل الأبيات)')),
                  DropdownMenuItem(value: 'bottom', child: Text('في الأسفل (توقيع يسار)')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _poetLocation = val);
                },
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: TextField(
                    controller: _poetNameController,
                    decoration: InputDecoration(
                      hintText: 'أدخل اسم الشاعر...',
                      filled: true,
                      fillColor: isDark ? Colors.white10 : Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                      ),
                    ),
                  ),
                ),
                crossFadeState: _poetLocation != 'none' ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
              const Divider(),
              // 4. هل هناك فواصل؟
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: AppColors.primary,
                title: const Text(
                  'إضافة فواصل بين الأبيات؟ (* * *)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                value: _hasSeparators,
                onChanged: (val) => setState(() => _hasSeparators = val),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'إلغاء',
            style: TextStyle(color: isDark ? Colors.grey : Colors.grey.shade600),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () {
            Navigator.pop(context, {
              'hasTitle': _hasTitle,
              'titleText': _titleController.text,
              'poetName': _poetNameController.text,
              'poetLocation': _poetLocation,
              'poemType': _poemType,
              'hasSeparators': _hasSeparators,
            });
          },
          child: const Text('إدراج القالب', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
