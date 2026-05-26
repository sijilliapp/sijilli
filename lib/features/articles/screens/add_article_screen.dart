import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import '../../../core/constants/app_colors.dart';
import '../../../core/local/local_db_service.dart';
import '../../../models/article.dart';
import '../providers/article_provider.dart';
import '../widgets/formatting_text_controller.dart';
import '../widgets/article_content_renderer.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';
import '../../../core/providers/global_config_provider.dart';

class AddArticleScreen extends StatefulWidget {
  final Article? article;
  
  const AddArticleScreen({super.key, this.article});

  @override
  State<AddArticleScreen> createState() => _AddArticleScreenState();
}

class _AddArticleScreenState extends State<AddArticleScreen> {
  /// المتحكم المخصص: يُخفي رموز التنسيق ويعرض النص نظيفاً
  late final FormattingTextEditingController _textController;
  final FocusNode _textFocusNode = FocusNode();
  File? _selectedImage;
  bool _deleteExistingImage = false;
  bool _isPublished = false;
  bool _isLoading = false;
  bool _isPreviewMode = false;
  bool _isSelecting = false;
  int? _selectionAnchor;
  String? _draftArticleId;

  Timer? _debounce;
  String _lastRawText = '';
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _textController = FormattingTextEditingController(
      rawText: widget.article?.text ?? '',
    );
    _hasText = _textController.rawText.trim().isNotEmpty;
    _lastRawText = _textController.rawText;
    _isPublished = widget.article?.isPublished ?? false;

    _textController.addListener(_unifiedTextListener);

    if (widget.article == null) {
      _loadDraft();
    }
  }

  Future<void> _loadDraft() async {
    final draft = await LocalDbService.instance.getArticleDraft();
    if (draft != null && draft.trim().isNotEmpty && mounted) {
      setState(() {
        _textController.setRawText(draft);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.articleDraftRestored)),
      );
    }
  }

  void _applyMagicFormatting() {
    final text = _textController.text;
    if (text.isEmpty) return;
    
    int changesCount = 0;
    String newText = text;

    String replaceWithCount(String source, Pattern pattern, String Function(Match) replace) {
      return source.replaceAllMapped(pattern, (match) {
        changesCount++;
        return replace(match);
      });
    }

    // 1. تعريب الرموز الإنجليزية
    newText = replaceWithCount(newText, ',', (m) => '،');
    newText = replaceWithCount(newText, '?', (m) => '؟');

    // 2. هندسة علامات التنصيص (الأقواس)
    newText = replaceWithCount(newText, RegExp(r'"([^"]*)"'), (match) => '«${match.group(1)}»');

    // 3. تنظيف المسافات المحيطة بالأقواس
    newText = replaceWithCount(newText, RegExp(r'\(\s+'), (m) => '(');
    newText = replaceWithCount(newText, RegExp(r'\s+\)'), (m) => ')');
    newText = replaceWithCount(newText, RegExp(r'«\s+'), (m) => '«');
    newText = replaceWithCount(newText, RegExp(r'\s+»'), (m) => '»');

    // 4. هندسة المسافات حول علامات الترقيم
    newText = replaceWithCount(newText, RegExp(r'\s+([،.؛:؟!])'), (match) => match.group(1)!);
    newText = replaceWithCount(newText, RegExp(r'([،.؛:؟!])(?=[^\s،.؛:؟!])'), (match) => '${match.group(1)} ');

    // 5. واو العطف (نلصق الواو المتبوعة بمسافة والتي لا تسبقها كلمة)
    newText = replaceWithCount(newText, RegExp(r'(?<=\s|^)و([\u064B-\u0652]*)\s+'), (match) => 'و${match.group(1)}');

    // 6. تنظيف الفراغات الزائدة
    newText = replaceWithCount(newText, RegExp(r'[ \t]{2,}'), (m) => ' ');
    newText = replaceWithCount(newText, RegExp(r'\n{3,}'), (m) => '\n\n');

    // 7. المسافة البادئة (Indentation) للفقرات
    // إضافة مسافة بادئة (Em Space) بعد كل سطر جديد (أو بداية النص) إذا لم تكن موجودة وإذا كان السطر يحتوي نصاً وليس رموز تنسيق
    if (newText.isNotEmpty && !newText.startsWith(RegExp(r'[\s=~\[]'))) {
      newText = '\u2003$newText';
      changesCount++;
    }
    newText = replaceWithCount(newText, RegExp(r'\n(?=[^\s=~\[\n])'), (match) => '\n\u2003');

    // 8. القاموس المصغر للأخطاء المطلقة (الصريحة التي لا تحتمل وجهين)
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
      'ndcwa': 'ندعو', // Note: keep original strings in case there are transliterated values, or check original:
      'ندعوا': 'ندعو',
      'نرجوا': 'نرجو',
      'مديروا': 'مديرو',
      'اللة': 'الله',
      'حتي': 'حتى',
      'مستشفي': 'مستشفى',
      'جزاكي': 'جزاكِ',
    };

    spellingFixes.forEach((wrong, correct) {
      // نستخدم حدود الكلمة العربية لتجنب تغيير أجزاء من كلمات أخرى (مثل: هلاكن -> هلكن)
      // الحروف العربية تقع في النطاق \u0600-\u06FF
      final baseWrong = wrong.replaceAll(RegExp(r'[\u064B-\u0652]'), '');
      final patternParts = baseWrong.split('').map((char) {
        if (char == ' ') return r'\s+';
        return RegExp.escape(char) + r'[\u064B-\u0652]*';
      }).join('');
      final pattern = RegExp('(?<![\\u0600-\\u06FF])' + patternParts + '(?![\\u0600-\\u06FF])');
      newText = replaceWithCount(newText, pattern, (match) => correct);
    });

    if (changesCount > 0) {
      setState(() {
        _textController.text = newText;
        _textController.selection = TextSelection.collapsed(offset: newText.length);
      });
    }

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
      builder: (context) => AlertDialog(
        title: const Text('التدقيق الآلي'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _textFocusNode.requestFocus();
            },
            child: const Text('تم'),
          ),
        ],
      ),
    );
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

      if (widget.article == null && _draftArticleId == null) {
        if (_debounce?.isActive ?? false) _debounce!.cancel();
        _debounce = Timer(const Duration(milliseconds: 1500), () async {
          if (_textController.rawText.trim().isNotEmpty && mounted) {
            final provider = context.read<ArticleProvider>();
            final draft = await provider.addArticle(
              text: _textController.rawText,
              isPublished: _isPublished,
              isDraft: true,
              silent: true,
            );
            if (draft != null && mounted) {
              _draftArticleId = draft.id;
              LocalDbService.instance.clearArticleDraft();
            }
          }
        });
      } else {
        if (_debounce?.isActive ?? false) _debounce!.cancel();
        _debounce = Timer(const Duration(milliseconds: 1500), () {
          final id = widget.article?.id ?? _draftArticleId;
          if (id != null && _textController.rawText.trim().isNotEmpty && mounted) {
            context.read<ArticleProvider>().updateArticle(
              id: id,
              text: _textController.rawText,
              isPublished: _isPublished,
              isDraft: true,
              silent: true,
            );
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
      int newCursorPosition;
      
      if (selection.isValid) {
        newText = text.replaceRange(selection.start, selection.end, textToPaste);
        newCursorPosition = selection.start + textToPaste.length;
      } else {
        newText = text + textToPaste;
        newCursorPosition = newText.length;
      }
      
      setState(() {
        _textController.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: newCursorPosition),
        );
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
          aspectRatio: const CropAspectRatio(ratioX: 16, ratioY: 9),
          compressQuality: 60, // Reduces size to < 100KB typically
          compressFormat: ImageCompressFormat.jpg,
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: context.l10n.editArticleCover,
              toolbarColor: AppColors.primary,
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.ratio16x9,
              lockAspectRatio: false,
            ),
            IOSUiSettings(
              title: context.l10n.editArticleCover,
            ),
          ],
        );

        if (croppedFile != null) {
          setState(() {
            _selectedImage = File(croppedFile.path);
          });
        }
      }
    } catch (e) {
      print('Error picking image: $e');
    }
  }

  void _submit() async {
    if (_textController.rawText.trim().isEmpty) return;

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
      );
    } else {
      resultArticle = await provider.addArticle(
        text: _textController.rawText,
        isPublished: _isPublished,
        isDraft: false,
        imageFile: _selectedImage,
      );
    }

    setState(() => _isLoading = false);

    if (resultArticle != null) {
      if (widget.article == null) {
        await LocalDbService.instance.clearArticleDraft();
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
                _isPublished = false;
              });
              if (widget.article == null) {
                await LocalDbService.instance.clearArticleDraft();
              }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                            // 4. تنسيق الشعر: الفقرة الحالية (مع استخدام رمز أسطر متداخلة)
                            ListenableBuilder(
                              listenable: _textController,
                              builder: (context, _) {
                                final active = _textController.currentParagraphFormat == ParagraphFormat.poem;
                                return IconButton(
                                  tooltip: context.l10n.poemTooltip,
                                  icon: const Icon(Icons.notes),
                                  color: active ? AppColors.error : AppColors.primary,
                                  onPressed: () {
                                    _textController.toggleParagraphFormat(ParagraphFormat.poem);
                                    _textFocusNode.requestFocus();
                                  },
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
                            // 6. تصحيح وتنسيق سحري
                            IconButton(
                              tooltip: 'تنسيق سحري وتصحيح',
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
                  // من اليسار: زر الصورة (إضافة أو إزالة مع صندوق تأكيد)
                  Builder(
                    builder: (context) {
                      final hasImage = _selectedImage != null || (widget.article?.image != null && !_deleteExistingImage);
                      return IconButton(
                        tooltip: hasImage ? 'إزالة الصورة' : 'إضافة صورة غلاف',
                        icon: Icon(
                          hasImage ? Icons.no_photography : Icons.add_photo_alternate_outlined,
                          color: hasImage ? AppColors.error : AppColors.primary,
                        ),
                        onPressed: hasImage ? _confirmDeleteImage : _pickImage,
                      );
                    },
                  ),
                  // بالوسط: أدوات تحريك المؤشر والتظليل
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'تحريك المؤشر لليمين',
                        icon: const Icon(Icons.arrow_back, size: 20),
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
                      IconButton(
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
                        tooltip: 'تحريك المؤشر لليسار',
                        icon: const Icon(Icons.arrow_forward, size: 20),
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
                    ],
                  ),
                  // باليمين: زر المعاينة + زر اللصق من الحافظة
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
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

          if (_selectedImage != null) ...[
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                width: double.infinity,
                color: AppColors.getCardBackground(context),
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(_selectedImage!, fit: BoxFit.cover),
                    Container(color: Colors.black26),
                    const Center(
                      child: Icon(Icons.edit, color: Colors.white, size: 32),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
          ] else if (widget.article?.image != null && !_deleteExistingImage) ...[
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
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
                      child: Icon(Icons.edit, color: Colors.white, size: 32),
                    ),
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
                          child: ArticleContentRenderer(text: _textController.text),
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
                  child: TextField(
                    controller: _textController,
                    focusNode: _textFocusNode,
                    maxLines: null,
                    expands: true,
                    keyboardType: TextInputType.multiline,
                    textAlignVertical: TextAlignVertical.top,
                    textDirection: TextDirection.rtl,
                    selectionWidthStyle: ui.BoxWidthStyle.tight,
                    selectionHeightStyle: ui.BoxHeightStyle.tight,
                    style: TextStyle(
                      fontSize: 18,
                      height: 1.5,
                      color: AppColors.getTextPrimary(context),
                    ),
                    decoration: InputDecoration(
                      hintText: context.l10n.writeArticleHint,
                      hintStyle: TextStyle(color: AppColors.getHintColor(context)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16.0),
                    ),
                    maxLength: context.read<GlobalConfigProvider>().articleMaxChars,
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
