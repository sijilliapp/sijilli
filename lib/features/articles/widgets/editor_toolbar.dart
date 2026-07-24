import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sijilli/core/constants/app_colors.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';
import 'package:sijilli/core/providers/settings_provider.dart';
import 'package:sijilli/features/auth/providers/auth_provider.dart';
import 'formatting_text_controller.dart';

class EditorToolbar extends StatelessWidget {
  final FormattingTextEditingController textController;
  final FocusNode textFocusNode;
  final bool isPreviewMode;
  final VoidCallback onTogglePreview;
  final VoidCallback onPickCoverImage;
  final VoidCallback onConfirmDeleteCoverImage;
  final bool hasCoverImage;
  final VoidCallback onPickAudio;
  final VoidCallback onPickInlineImage;
  final VoidCallback onFormatQuranVerse;
  final VoidCallback onApplyMagicFormatting;
  final VoidCallback onClearFormatting;
  final VoidCallback onShowSearchAndReplace;
  final VoidCallback onPoemAction;
  final VoidCallback onPasteFromClipboard;

  const EditorToolbar({
    super.key,
    required this.textController,
    required this.textFocusNode,
    required this.isPreviewMode,
    required this.onTogglePreview,
    required this.onPickCoverImage,
    required this.onConfirmDeleteCoverImage,
    required this.hasCoverImage,
    required this.onPickAudio,
    required this.onPickInlineImage,
    required this.onFormatQuranVerse,
    required this.onApplyMagicFormatting,
    required this.onClearFormatting,
    required this.onShowSearchAndReplace,
    required this.onPoemAction,
    required this.onPasteFromClipboard,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // السطر الأول: أدوات التنسيق النصي
        Container(
          color: AppColors.getCardBackground(context),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                // 1. الضبط: الفقرة الحالية
                ListenableBuilder(
                  listenable: Provider.of<SettingsProvider>(context),
                  builder: (context, _) {
                    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
                    final active = settingsProvider.justifyArticles;
                    return IconButton(
                      tooltip: context.l10n.justifyTooltip,
                      icon: const Icon(Icons.format_align_justify),
                      color: active ? AppColors.error : AppColors.primary,
                      onPressed: () async {
                        await settingsProvider.setJustifyArticles(!active);
                        textFocusNode.requestFocus();
                      },
                    );
                  },
                ),
                // 2. التوسيط: الفقرة الحالية
                ListenableBuilder(
                  listenable: textController,
                  builder: (context, _) {
                    final active = textController.currentParagraphFormat == ParagraphFormat.center;
                    return IconButton(
                      tooltip: context.l10n.centerTooltip,
                      icon: const Icon(Icons.format_align_center),
                      color: active ? AppColors.error : AppColors.primary,
                      onPressed: () {
                        textController.toggleParagraphFormat(ParagraphFormat.center);
                        textFocusNode.requestFocus();
                      },
                    );
                  },
                ),
                // 3. محاذاة يسار: الفقرة الحالية
                ListenableBuilder(
                  listenable: textController,
                  builder: (context, _) {
                    final active = textController.currentParagraphFormat == ParagraphFormat.left;
                    return IconButton(
                      tooltip: context.l10n.leftAlignTooltip,
                      icon: const Icon(Icons.format_align_left),
                      color: active ? AppColors.error : AppColors.primary,
                      onPressed: () {
                        textController.toggleParagraphFormat(ParagraphFormat.left);
                        textFocusNode.requestFocus();
                      },
                    );
                  },
                ),
                // 4. تنسيق الشعر: الفقرة الحالية
                if (isArabic)
                  ListenableBuilder(
                    listenable: textController,
                    builder: (context, _) {
                      final active = textController.currentParagraphFormat == ParagraphFormat.poem;
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
                        onPressed: onPoemAction,
                      );
                    },
                  ),
                // 5. تعريض الخط: الجزء المحدد
                ListenableBuilder(
                  listenable: textController,
                  builder: (context, _) => IconButton(
                    tooltip: context.l10n.boldTooltip,
                    icon: const Icon(Icons.format_bold),
                    color: AppColors.primary,
                    onPressed: () {
                      textController.toggleBoldAtCursor();
                      textFocusNode.requestFocus();
                    },
                  ),
                ),
                // 5.5. تمييز النص (قلم التظليل)
                ListenableBuilder(
                  listenable: textController,
                  builder: (context, _) => IconButton(
                    tooltip: context.l10n.highlightTooltip,
                    icon: SizedBox(
                      width: 24,
                      height: 24,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5,
                              height: 3,
                              decoration: const BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.vertical(top: Radius.circular(1)),
                              ),
                            ),
                            Container(
                              width: 7,
                              height: 11,
                              color: const Color(0xFFFFEB3B),
                            ),
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
                      textController.toggleHighlightAtCursor();
                      textFocusNode.requestFocus();
                    },
                  ),
                ),
                // 5.7. تنسيق آية قرآنية
                if (isArabic)
                  IconButton(
                    tooltip: context.l10n.quranVerseTooltip,
                    icon: Text(
                      '﴿آية﴾',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.primary,
                      ),
                    ),
                    onPressed: onFormatQuranVerse,
                  ),
                // 6. تصحيح إملائي
                IconButton(
                  tooltip: context.l10n.spellCheckTooltip,
                  icon: const Icon(Icons.auto_fix_high),
                  color: AppColors.primary,
                  onPressed: onApplyMagicFormatting,
                ),
                // 7. إلغاء التنسيق
                IconButton(
                  tooltip: context.l10n.clearFormattingTooltip,
                  icon: const Icon(Icons.format_clear),
                  color: AppColors.error,
                  onPressed: onClearFormatting,
                ),
                // 8. بحث واستبدال
                IconButton(
                  tooltip: context.l10n.searchReplaceTooltip,
                  icon: const Icon(Icons.find_replace),
                  color: AppColors.primary,
                  onPressed: onShowSearchAndReplace,
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1, thickness: 1),
        // السطر الثاني للأزرار (مرتب LTR ومفتوح للتمرير الأفقي)
        Container(
          color: AppColors.getCardBackground(context),
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  children: [
                    // من اليسار: أزرار الوسائط
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: hasCoverImage ? context.l10n.removeCoverImageTooltip : context.l10n.addCoverImageTooltip,
                      icon: Icon(
                        hasCoverImage ? Icons.no_photography : Icons.add_photo_alternate_outlined,
                        color: hasCoverImage ? AppColors.error : AppColors.primary,
                      ),
                      onPressed: hasCoverImage ? onConfirmDeleteCoverImage : onPickCoverImage,
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: context.l10n.addAudioTooltip,
                      icon: const Icon(
                        Icons.mic_none_outlined,
                        color: AppColors.primary,
                      ),
                      onPressed: onPickAudio,
                    ),
                    Builder(
                      builder: (context) {
                        final user = context.watch<AuthProvider>().user;
                        final isWriterOrAdmin = user?.role == 'writer' || user?.role == 'admin';
                        if (!isWriterOrAdmin) return const SizedBox.shrink();

                        return IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: context.l10n.insertImageTooltip,
                          icon: const Icon(
                            Icons.image_search_outlined,
                            color: AppColors.primary,
                          ),
                          onPressed: onPickInlineImage,
                        );
                      },
                    ),

                    // فاصل مرئي
                    Container(
                      width: 1,
                      height: 20,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      color: isDark ? Colors.white12 : Colors.black12,
                    ),

                    // باليمين: أزرار التراجع والتقدم، وزر المعاينة المباشرة
                    ListenableBuilder(
                      listenable: textController,
                      builder: (context, _) => IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: context.l10n.undoTooltip,
                        icon: const Icon(Icons.undo),
                        color: textController.canUndo
                            ? AppColors.primary
                            : AppColors.getHintColor(context).withValues(alpha: 0.5),
                        onPressed: textController.canUndo
                            ? () {
                                textController.undo();
                                textFocusNode.requestFocus();
                              }
                            : null,
                      ),
                    ),
                    ListenableBuilder(
                      listenable: textController,
                      builder: (context, _) => IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: context.l10n.redoTooltip,
                        icon: const Icon(Icons.redo),
                        color: textController.canRedo
                            ? AppColors.primary
                            : AppColors.getHintColor(context).withValues(alpha: 0.5),
                        onPressed: textController.canRedo
                            ? () {
                                textController.redo();
                                textFocusNode.requestFocus();
                              }
                            : null,
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: isPreviewMode ? context.l10n.closePreview : context.l10n.livePreview,
                      icon: Icon(
                        isPreviewMode ? Icons.edit_note : Icons.visibility_outlined,
                        color: AppColors.primary,
                      ),
                      onPressed: onTogglePreview,
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: context.l10n.pasteFromClipboardTooltip,
                      icon: const Icon(Icons.content_paste),
                      color: AppColors.primary,
                      onPressed: onPasteFromClipboard,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
