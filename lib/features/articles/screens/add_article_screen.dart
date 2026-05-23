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
import '../widgets/poetry/poem_formatter_utils.dart';
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
  late final TextEditingController _textController;
  final FocusNode _textFocusNode = FocusNode();
  File? _selectedImage;
  bool _isPublished = false;
  bool _isLoading = false;
  bool _isPreviewMode = false;
  bool _isSelecting = false;
  int? _selectionAnchor;
  String? _draftArticleId;

  Timer? _debounce;
  String _lastText = '';
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.article?.text ?? '');
    _hasText = _textController.text.trim().isNotEmpty;
    _lastText = _textController.text;
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
        _textController.text = draft;
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
    newText = replaceWithCount(newText, RegExp(r'(?<=\s|^)و\s+'), (match) => 'و');

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
      final pattern = RegExp('(?<![\\u0600-\\u06FF])' + wrong + '(?![\\u0600-\\u06FF])');
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
    final text = _textController.text;
    if (text.isEmpty) return;

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
              String cleanText = Article.stripFormatting(text);

              setState(() {
                _textController.text = cleanText;
                _textController.selection = TextSelection.collapsed(offset: cleanText.length);
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

  bool _isWhitespace(String c) {
    return c == ' ' || c == '\n' || c == '\t' || c == '\u2003' || c == '\u200B' || c == '\r';
  }

  void _showSearchAndReplaceDialog() {
    final searchController = TextEditingController();
    final replaceController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('بحث واستبدال'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: searchController,
              decoration: const InputDecoration(
                labelText: 'الكلمة المبحوثة',
                hintText: 'الكلمة المراد استبدالها أو حذفها',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: replaceController,
              decoration: const InputDecoration(
                labelText: 'البديل (اتركه فارغاً للحذف)',
                hintText: 'أدخل الكلمة البديلة',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              final searchWord = searchController.text;
              final replaceWord = replaceController.text;
              
              if (searchWord.isEmpty) {
                Navigator.pop(context);
                return;
              }

              final text = _textController.text;
              if (!text.contains(searchWord)) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('الكلمة المبحوثة غير موجودة في النص.')),
                );
                return;
              }

              final newText = text.replaceAll(searchWord, replaceWord);
              
              setState(() {
                _textController.text = newText;
                // Move cursor to the end or keep it where it was safely
                _textController.selection = TextSelection.collapsed(offset: newText.length);
              });

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم إكمال عملية البحث والاستبدال بنجاح.')),
              );
              _textFocusNode.requestFocus();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('تطبيق'),
          ),
        ],
      ),
    );
  }

  void _unifiedTextListener() {
    final bool currentHasText = _textController.text.trim().isNotEmpty;
    if (currentHasText != _hasText) {
      setState(() {
        _hasText = currentHasText;
      });
    }

    // --- Workaround for Flutter RTL Selection Stretch Bug ---
    // Prevent the selection bounds from capturing newlines or Em spaces at the edges,
    // which causes the `RenderEditable` to draw a full-width blue box in RTL mode.
    final selection = _textController.selection;
    if (selection.isValid && !selection.isCollapsed) {
      final text = _textController.text;
      int start = selection.start;
      int end = selection.end;
      bool changed = false;

      // Prevent selection from starting exactly on any whitespace
      while (start < end && _isWhitespace(text[start])) {
        start++;
        changed = true;
      }
      
      // Prevent selection from ending exactly on any whitespace
      while (end > start && _isWhitespace(text[end - 1])) {
        end--;
        changed = true;
      }

      if (changed && start <= end) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _textController.selection == selection) {
            _textController.selection = TextSelection(
              baseOffset: selection.isDirectional && selection.baseOffset > selection.extentOffset ? end : start,
              extentOffset: selection.isDirectional && selection.baseOffset > selection.extentOffset ? start : end,
            );
          }
        });
      }
    }
    // --------------------------------------------------------

    if (_textController.text != _lastText) {
      _lastText = _textController.text;
      if (_isSelecting) {
        setState(() {
          _isSelecting = false;
          _selectionAnchor = null;
        });
      }

      if (widget.article == null && _draftArticleId == null) {
        if (_debounce?.isActive ?? false) _debounce!.cancel();
        _debounce = Timer(const Duration(milliseconds: 1500), () async {
          if (_textController.text.trim().isNotEmpty && mounted) {
             final provider = context.read<ArticleProvider>();
             final draft = await provider.addArticle(
               text: _textController.text,
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
          if (id != null && _textController.text.trim().isNotEmpty && mounted) {
             context.read<ArticleProvider>().updateArticle(
               id: id,
               text: _textController.text,
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

  /// دالة محسنة للتوسيط تعمل على النص المحدد ككل
  String _toggleCenterAlignmentForSelection(String selectedText) {
    if (selectedText.isEmpty) return '';
    
    final match = RegExp(r'^(\s*)(.*?)(\s*)$', dotAll: true).firstMatch(selectedText);
    final leadingSpaces = match?.group(1) ?? '';
    final text = match?.group(2) ?? '';
    final trailingSpaces = match?.group(3) ?? '';
    
    if (text.isEmpty) return selectedText;

    String formatted;
    // التحقق إذا كان النص يحتوي بالفعل على علامات توسيط
    if ((text.startsWith('[CENTER]') && text.endsWith('[/CENTER]')) ||
        (text.startsWith('=') && text.endsWith('='))) {
      // إزالة علامات التوسيط
      if (text.startsWith('=')) {
        formatted = text.substring(1, text.length - 1).trim();
      } else {
        formatted = text.substring('[CENTER]'.length, text.length - '[/CENTER]'.length).trim();
      }
    }
    // التحقق إذا كان النص يحتوي على علامات ضبط
    else if ((text.startsWith('[JUSTIFY]') && text.endsWith('[/JUSTIFY]')) ||
        (text.startsWith('~') && text.endsWith('~'))) {
      // إزالة علامات الضبط وإضافة علامات التوسيط
      String withoutJustify = text;
      if (text.startsWith('~')) {
        withoutJustify = text.substring(1, text.length - 1).trim();
      } else {
        withoutJustify = text.substring('[JUSTIFY]'.length, text.length - '[/JUSTIFY]'.length).trim();
      }
      formatted = '=$withoutJustify=';
    } else {
      // إضافة علامات التوسيط
      formatted = '=$text=';
    }
    return '$leadingSpaces$formatted$trailingSpaces';
  }

  /// دالة محسنة للضبط تعمل على النص المحدد ككل
  String _toggleJustifyAlignmentForSelection(String selectedText) {
    if (selectedText.isEmpty) return '';
    
    final match = RegExp(r'^(\s*)(.*?)(\s*)$', dotAll: true).firstMatch(selectedText);
    final leadingSpaces = match?.group(1) ?? '';
    final text = match?.group(2) ?? '';
    final trailingSpaces = match?.group(3) ?? '';
    
    if (text.isEmpty) return selectedText;

    String formatted;
    // التحقق إذا كان النص يحتوي بالفعل على علامات ضبط
    if ((text.startsWith('[JUSTIFY]') && text.endsWith('[/JUSTIFY]')) ||
        (text.startsWith('~') && text.endsWith('~'))) {
      // إزالة علامات الضبط
      if (text.startsWith('~')) {
        formatted = text.substring(1, text.length - 1).trim();
      } else {
        formatted = text.substring('[JUSTIFY]'.length, text.length - '[/JUSTIFY]'.length).trim();
      }
    }
    // التحقق إذا كان النص يحتوي على علامات توسيط
    else if ((text.startsWith('[CENTER]') && text.endsWith('[/CENTER]')) ||
        (text.startsWith('=') && text.endsWith('='))) {
      // إزالة علامات التوسيط وإضافة علامات الضبط
      String withoutCenter = text;
      if (text.startsWith('=')) {
        withoutCenter = text.substring(1, text.length - 1).trim();
      } else {
        withoutCenter = text.substring('[CENTER]'.length, text.length - '[/CENTER]'.length).trim();
      }
      formatted = '~$withoutCenter~';
    } else {
      // إضافة علامات الضبط
      formatted = '~$text~';
    }
    return '$leadingSpaces$formatted$trailingSpaces';
  }

  /// دالة محسنة للقصيدة تعمل على النص المحدد ككل
  String _formatAsPoemForSelection(String selectedText) {
    if (selectedText.isEmpty) return '';
    
    final match = RegExp(r'^(\s*)(.*?)(\s*)$', dotAll: true).firstMatch(selectedText);
    final leadingSpaces = match?.group(1) ?? '';
    final text = match?.group(2) ?? '';
    final trailingSpaces = match?.group(3) ?? '';
    
    if (text.isEmpty) return selectedText;

    String formatted;
    // التحقق إذا كان النص يحتوي بالفعل على علامات قصيدة
    if (text.startsWith('[POEM]') && text.endsWith('[/POEM]')) {
      // إزالة علامات القصيدة
      formatted = text.substring('[POEM]'.length, text.length - '[/POEM]'.length).trim();
    } else {
      // إضافة علامات القصيدة
      formatted = '[POEM]\n$text\n[/POEM]';
    }
    return '$leadingSpaces$formatted$trailingSpaces';
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
    if (_textController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);

    final provider = context.read<ArticleProvider>();
    Article? resultArticle;
    
    if (widget.article != null || _draftArticleId != null) {
      final id = widget.article?.id ?? _draftArticleId!;
      resultArticle = await provider.updateArticle(
        id: id,
        text: _textController.text,
        isPublished: _isPublished,
        isDraft: false,
        imageFile: _selectedImage,
      );
    } else {
      resultArticle = await provider.addArticle(
        text: _textController.text,
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
                        IconButton(
                  tooltip: context.l10n.boldTooltip,
                  icon: const Icon(Icons.format_bold),
                  color: AppColors.primary,
                  onPressed: () {
                    final text = _textController.text;
                    final selection = _textController.selection;
                    
                    if (!selection.isValid || selection.isCollapsed) {
                      final pos = selection.isValid ? selection.start : text.length;
                      final newText = text.replaceRange(pos, pos, '*نص*');
                      setState(() {
                        _textController.text = newText;
                        _textController.selection = TextSelection(baseOffset: pos + 1, extentOffset: pos + 3);
                      });
                      _textFocusNode.requestFocus();
                      return;
                    }

                    final selectedText = text.substring(selection.start, selection.end);
                    
                    final match = RegExp(r'^(\s*)(.*?)(\s*)$', dotAll: true).firstMatch(selectedText);
                    final leadingSpaces = match?.group(1) ?? '';
                    final innerText = match?.group(2) ?? '';
                    final trailingSpaces = match?.group(3) ?? '';
                    
                    String formattedText;
                    if (innerText.isEmpty) {
                      formattedText = selectedText;
                    } else if ((innerText.startsWith('[B]') && innerText.endsWith('[/B]')) ||
                        (innerText.startsWith('*') && innerText.endsWith('*'))) {
                      if (innerText.startsWith('*')) {
                        formattedText = innerText.substring(1, innerText.length - 1);
                      } else {
                        formattedText = innerText.substring('[B]'.length, innerText.length - '[/B]'.length);
                      }
                    } else {
                      formattedText = '*$innerText*';
                    }
                    
                    final newText = text.replaceRange(selection.start, selection.end, '$leadingSpaces$formattedText$trailingSpaces');
                    
                    setState(() {
                      _textController.text = newText;
                      _textController.selection = TextSelection.collapsed(
                        offset: selection.start + formattedText.length,
                      );
                    });
                    _textFocusNode.requestFocus();
                  },
                ),
                IconButton(
                  tooltip: context.l10n.poemTooltip,
                  icon: const Icon(Icons.menu_book),
                  color: AppColors.primary,
                  onPressed: () {
                    final text = _textController.text;
                    final selection = _textController.selection;
                    
                    if (!selection.isValid || selection.isCollapsed) {
                      final pos = selection.isValid ? selection.start : text.length;
                      const placeholder = 'الشطر الأول = الشطر الثاني';
                      final newText = text.replaceRange(pos, pos, '[POEM]\n$placeholder\n[/POEM]');
                      setState(() {
                        _textController.text = newText;
                        _textController.selection = TextSelection(baseOffset: pos + 7, extentOffset: pos + 7 + placeholder.length);
                      });
                      _textFocusNode.requestFocus();
                      return;
                    }

                    final selectedText = text.substring(selection.start, selection.end);
                    
                    // دالة محسنة للقصيدة تعمل على النص ككل
                    final formattedPoem = _formatAsPoemForSelection(selectedText);
                    
                    final newText = text.replaceRange(selection.start, selection.end, formattedPoem);
                    
                    setState(() {
                      _textController.text = newText;
                      _textController.selection = TextSelection.collapsed(
                        offset: selection.start + formattedPoem.length,
                      );
                    });
                    _textFocusNode.requestFocus();
                  },
                ),
                IconButton(
                  tooltip: context.l10n.centerTooltip,
                  icon: const Icon(Icons.format_align_center),
                  color: AppColors.primary,
                  onPressed: () {
                    final text = _textController.text;
                    final selection = _textController.selection;
                    
                    if (!selection.isValid || selection.isCollapsed) {
                      final pos = selection.isValid ? selection.start : text.length;
                      final newText = text.replaceRange(pos, pos, '=نص=');
                      setState(() {
                        _textController.text = newText;
                        _textController.selection = TextSelection(baseOffset: pos + 1, extentOffset: pos + 3);
                      });
                      _textFocusNode.requestFocus();
                      return;
                    }

                    final selectedText = text.substring(selection.start, selection.end);
                    
                    // دالة محسنة للتوسيط تعمل على النص ككل وليس كل سطر على حدة
                    final formattedText = _toggleCenterAlignmentForSelection(selectedText);
                    
                    final newText = text.replaceRange(selection.start, selection.end, formattedText);
                    
                    setState(() {
                      _textController.text = newText;
                      _textController.selection = TextSelection.collapsed(
                        offset: selection.start + formattedText.length,
                      );
                    });
                    _textFocusNode.requestFocus();
                  },
                ),
                IconButton(
                  tooltip: context.l10n.justifyTooltip,
                  icon: const Icon(Icons.format_align_justify),
                  color: AppColors.primary,
                  onPressed: () {
                    final text = _textController.text;
                    final selection = _textController.selection;
                    
                    if (!selection.isValid || selection.isCollapsed) {
                      final pos = selection.isValid ? selection.start : text.length;
                      final newText = text.replaceRange(pos, pos, '~نص~');
                      setState(() {
                        _textController.text = newText;
                        _textController.selection = TextSelection(baseOffset: pos + 1, extentOffset: pos + 3);
                      });
                      _textFocusNode.requestFocus();
                      return;
                    }

                    final selectedText = text.substring(selection.start, selection.end);
                    
                    // دالة محسنة للضبط تعمل على النص ككل وليس كل سطر على حدة
                    final formattedText = _toggleJustifyAlignmentForSelection(selectedText);
                    
                    final newText = text.replaceRange(selection.start, selection.end, formattedText);
                    
                    setState(() {
                      _textController.text = newText;
                      _textController.selection = TextSelection.collapsed(
                        offset: selection.start + formattedText.length,
                      );
                    });
                    _textFocusNode.requestFocus();
                  },
                ),
                // زر المحاذاة لليمين
                IconButton(
                  tooltip: 'محاذاة لليمين',
                  icon: const Icon(Icons.format_align_right),
                  color: AppColors.primary,
                  onPressed: () {
                    final text = _textController.text;
                    final selection = _textController.selection;
                    
                    if (!selection.isValid || selection.isCollapsed) {
                      final pos = selection.isValid ? selection.start : text.length;
                      final newText = text.replaceRange(pos, pos, '++نص++');
                      setState(() {
                        _textController.text = newText;
                        _textController.selection = TextSelection(baseOffset: pos + 2, extentOffset: pos + 4);
                      });
                      _textFocusNode.requestFocus();
                      return;
                    }

                    final selectedText = text.substring(selection.start, selection.end);
                    
                    final match = RegExp(r'^(\s*)(.*?)(\s*)$', dotAll: true).firstMatch(selectedText);
                    final leadingSpaces = match?.group(1) ?? '';
                    final innerText = match?.group(2) ?? '';
                    final trailingSpaces = match?.group(3) ?? '';
                    
                    String formattedText = '++$innerText++';
                    if (innerText.isEmpty) {
                       formattedText = selectedText;
                    } else if (innerText.startsWith('++') && innerText.endsWith('++')) {
                       formattedText = innerText.substring(2, innerText.length - 2);
                    } else if (innerText.startsWith('[RIGHT]') && innerText.endsWith('[/RIGHT]')) {
                       formattedText = innerText.substring('[RIGHT]'.length, innerText.length - '[/RIGHT]'.length);
                    }
                    
                    final newText = text.replaceRange(selection.start, selection.end, '$leadingSpaces$formattedText$trailingSpaces');
                    
                    setState(() {
                      _textController.text = newText;
                      _textController.selection = TextSelection.collapsed(
                        offset: selection.start + formattedText.length,
                      );
                    });
                    _textFocusNode.requestFocus();
                  },
                ),
                // زر المحاذاة لليسار
                IconButton(
                  tooltip: 'محاذاة لليسار',
                  icon: const Icon(Icons.format_align_left),
                  color: AppColors.primary,
                  onPressed: () {
                    final text = _textController.text;
                    final selection = _textController.selection;
                    
                    if (!selection.isValid || selection.isCollapsed) {
                      final pos = selection.isValid ? selection.start : text.length;
                      final newText = text.replaceRange(pos, pos, '--نص--');
                      setState(() {
                        _textController.text = newText;
                        _textController.selection = TextSelection(baseOffset: pos + 2, extentOffset: pos + 4);
                      });
                      _textFocusNode.requestFocus();
                      return;
                    }

                    final selectedText = text.substring(selection.start, selection.end);
                    
                    final match = RegExp(r'^(\s*)(.*?)(\s*)$', dotAll: true).firstMatch(selectedText);
                    final leadingSpaces = match?.group(1) ?? '';
                    final innerText = match?.group(2) ?? '';
                    final trailingSpaces = match?.group(3) ?? '';
                    
                    String formattedText = '--$innerText--';
                    if (innerText.isEmpty) {
                       formattedText = selectedText;
                    } else if (innerText.startsWith('--') && innerText.endsWith('--')) {
                       formattedText = innerText.substring(2, innerText.length - 2);
                    } else if (innerText.startsWith('[LEFT]') && innerText.endsWith('[/LEFT]')) {
                       formattedText = innerText.substring('[LEFT]'.length, innerText.length - '[/LEFT]'.length);
                    }
                    
                    final newText = text.replaceRange(selection.start, selection.end, '$leadingSpaces$formattedText$trailingSpaces');
                    
                    setState(() {
                      _textController.text = newText;
                      _textController.selection = TextSelection.collapsed(
                        offset: selection.start + formattedText.length,
                      );
                    });
                    _textFocusNode.requestFocus();
                  },
                ),
                // الزر السحري للتدقيق والتنسيق التلقائي
                IconButton(
                  tooltip: 'تنسيق سحري',
                  icon: const Icon(Icons.auto_fix_high),
                  color: AppColors.primary,
                  onPressed: _applyMagicFormatting,
                ),
                // زر مسح التنسيقات
                IconButton(
                  tooltip: 'مسح التنسيقات',
                  icon: const Icon(Icons.format_clear),
                  color: AppColors.error,
                  onPressed: _clearFormatting,
                ),
                // زر بحث واستبدال
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
    const SizedBox(height: 4),
    // Row 2: أدوات التحديد والمؤشر وأزرار العرض والصورة
    Row(
      children: [
        Expanded(child: const SizedBox()), // Empty space to balance
        // Selection Controls in the center
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'تحريك المؤشر لليمين',
              icon: const Directionality(
                textDirection: TextDirection.ltr,
                child: Icon(Icons.arrow_back_ios, size: 16),
              ),
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
              icon: Icon(_isSelecting ? Icons.highlight_remove : Icons.highlight, size: 18),
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
              icon: const Directionality(
                textDirection: TextDirection.ltr,
                child: Icon(Icons.arrow_forward_ios, size: 16),
              ),
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
        // Preview and Image on the far left (End of Row)
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
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
                tooltip: context.l10n.addArticleCoverOptional,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                color: AppColors.primary,
                onPressed: _pickImage,
              ),
            ],
          ),
        ),
      ],
    ),
  ],
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
                Expanded(
                  child: SingleChildScrollView(
                    child: TextField(
                      controller: _textController,
                      focusNode: _textFocusNode,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
