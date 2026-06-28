import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/global_config_provider.dart';
import '../providers/admin_provider.dart';
import '../../../core/extensions/context_l10n.dart';

class AdminArticlePrefsScreen extends StatefulWidget {
  const AdminArticlePrefsScreen({super.key});

  @override
  State<AdminArticlePrefsScreen> createState() => _AdminArticlePrefsScreenState();
}

class _AdminArticlePrefsScreenState extends State<AdminArticlePrefsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddWordDialog(
    BuildContext context,
    Map<String, String> currentFixes,
    GlobalConfigProvider configProvider,
    AdminProvider adminProvider,
  ) {
    final wrongController = TextEditingController();
    final correctController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          context.l10n.addWordBtn,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: wrongController,
              decoration: InputDecoration(
                labelText: context.l10n.typoWordHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: correctController,
              decoration: InputDecoration(
                labelText: context.l10n.correctedWordHint,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(context.l10n.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final wrong = wrongController.text.trim();
              final correct = correctController.text.trim();
              if (wrong.isEmpty || correct.isEmpty) return;

              final updated = Map<String, String>.from(currentFixes);
              updated[wrong] = correct;

              Navigator.pop(dialogCtx);
              final success = await adminProvider.updateConfigString(
                'spelling_fixes',
                json.encode(updated),
                configProvider,
              );

              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.l10n.wordAddedSuccess),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: Text(context.l10n.add),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteWord(
    BuildContext context,
    String wrong,
    Map<String, String> currentFixes,
    GlobalConfigProvider configProvider,
    AdminProvider adminProvider,
  ) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(context.l10n.confirmDeleteArticle),
        content: Text(context.l10n.deleteWordConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              final updated = Map<String, String>.from(currentFixes);
              updated.remove(wrong);

              Navigator.pop(dialogCtx);
              final success = await adminProvider.updateConfigString(
                'spelling_fixes',
                json.encode(updated),
                configProvider,
              );

              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.l10n.wordDeletedSuccess),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            child: Text(context.l10n.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _showNumberEditDialog({
    required BuildContext context,
    required String title,
    required double currentValue,
    required String configKey,
    required GlobalConfigProvider configProvider,
    required AdminProvider adminProvider,
  }) async {
    final controller = TextEditingController(text: currentValue.toInt().toString());
    final result = await showDialog<int>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: context.l10n.enterNewValue,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              final val = int.tryParse(controller.text);
              if (val != null) {
                Navigator.pop(dialogCtx, val);
              }
            },
            child: Text(context.l10n.save),
          ),
        ],
      ),
    );

    if (result != null && context.mounted) {
      await adminProvider.updateConfigNumber(
        configKey,
        result.toDouble(),
        configProvider,
      );
    }
  }

  Widget _buildLimitCard({
    required BuildContext context,
    required String title,
    required String description,
    required String value,
    required IconData icon,
    required bool isLoading,
    required VoidCallback onEdit,
    required bool isDark,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
      ),
      color: isDark ? AppColors.darkSurface : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        value,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      foregroundColor: AppColors.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    icon: const Icon(Icons.edit, size: 14),
                    label: Text(context.l10n.edit),
                    onPressed: onEdit,
                  ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(
            context.l10n.articlePrefs,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          elevation: 0,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          foregroundColor: isDark ? Colors.white : Colors.black,
          bottom: TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: isDark ? Colors.white70 : Colors.black54,
            indicatorColor: AppColors.primary,
            tabs: const [
              Tab(
                icon: Icon(Icons.settings_suggest_rounded),
                text: 'الحدود والقيود',
              ),
              Tab(
                icon: Icon(Icons.spellcheck_rounded),
                text: 'القاموس الإملائي',
              ),
            ],
          ),
        ),
        body: Consumer2<GlobalConfigProvider, AdminProvider>(
          builder: (context, config, admin, _) {
            final fixes = config.spellingFixes;
            final filteredKeys = fixes.keys
                .where((k) => k.contains(_searchQuery) || fixes[k]!.contains(_searchQuery))
                .toList();

            return TabBarView(
              children: [
                // 📊 Tab 1: Limits & Controls
                SafeArea(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildLimitCard(
                        context: context,
                        title: context.l10n.articleMaxCharacters,
                        description: 'الحد الأقصى لحروف نص المقال',
                        value: '${config.articleMaxChars} حرف',
                        icon: Icons.text_fields_rounded,
                        isLoading: admin.isLoading,
                        isDark: isDark,
                        onEdit: () => _showNumberEditDialog(
                          context: context,
                          title: context.l10n.articleMaxCharacters,
                          currentValue: config.articleMaxChars.toDouble(),
                          configKey: 'article_max_chars',
                          configProvider: config,
                          adminProvider: admin,
                        ),
                      ),
                      _buildLimitCard(
                        context: context,
                        title: 'الحد الأقصى لعدد الصوتيات',
                        description: 'عدد ملفات الصوت المسموح بها لكل مقال',
                        value: '${config.audioMaxFiles} ملفات',
                        icon: Icons.audiotrack_rounded,
                        isLoading: admin.isLoading,
                        isDark: isDark,
                        onEdit: () => _showNumberEditDialog(
                          context: context,
                          title: 'الحد الأقصى لعدد الصوتيات',
                          currentValue: config.audioMaxFiles.toDouble(),
                          configKey: 'audio_max_files',
                          configProvider: config,
                          adminProvider: admin,
                        ),
                      ),
                      _buildLimitCard(
                        context: context,
                        title: 'الحد الأقصى لحجم الصوت',
                        description: 'حجم ملف الصوت الواحد المرفق الأقصى',
                        value: '${config.audioMaxSizeMb}MB',
                        icon: Icons.file_upload_outlined,
                        isLoading: admin.isLoading,
                        isDark: isDark,
                        onEdit: () => _showNumberEditDialog(
                          context: context,
                          title: 'الحد الأقصى لحجم ملف الصوت (MB)',
                          currentValue: config.audioMaxSizeMb.toDouble(),
                          configKey: 'audio_max_size_mb',
                          configProvider: config,
                          adminProvider: admin,
                        ),
                      ),
                      _buildLimitCard(
                        context: context,
                        title: 'السعة الإجمالية للصوتيات',
                        description: 'السعة التخزينية الإجمالية القصوى للصوتيات',
                        value: '${config.audioTotalCapacityMb}MB',
                        icon: Icons.cloud_queue_rounded,
                        isLoading: admin.isLoading,
                        isDark: isDark,
                        onEdit: () => _showNumberEditDialog(
                          context: context,
                          title: 'السعة الإجمالية للصوتيات (MB)',
                          currentValue: config.audioTotalCapacityMb.toDouble(),
                          configKey: 'audio_total_capacity_mb',
                          configProvider: config,
                          adminProvider: admin,
                        ),
                      ),
                    ],
                  ),
                ),

                // 📚 Tab 2: Spelling Dictionary
                SafeArea(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            context.l10n.typoDictionary,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: const Icon(Icons.add, size: 16),
                            label: Text(context.l10n.addWordBtn),
                            onPressed: () => _showAddWordDialog(context, fixes, config, admin),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: context.l10n.searchDictionaryHint,
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    setState(() {
                                      _searchController.clear();
                                      _searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val.trim();
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      Card(
                        margin: EdgeInsets.zero,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                          ),
                        ),
                        color: isDark ? AppColors.darkSurface : Colors.white,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: filteredKeys.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.all(24.0),
                                  child: Center(
                                    child: Text(
                                      _searchQuery.isEmpty
                                          ? context.l10n.emptyDictionary
                                          : context.l10n.noResultsFound,
                                      style: const TextStyle(color: Colors.grey),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                )
                              : Table(
                                  columnWidths: const {
                                    0: FlexColumnWidth(2),
                                    1: FlexColumnWidth(2),
                                    2: IntrinsicColumnWidth(),
                                  },
                                  border: TableBorder(
                                    horizontalInside: BorderSide(
                                      color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                                      width: 1,
                                    ),
                                  ),
                                  children: [
                                    TableRow(
                                      decoration: BoxDecoration(
                                        color: isDark ? Colors.black26 : Colors.grey.shade50,
                                      ),
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(12.0),
                                          child: Text(
                                            context.l10n.typoWordHeader,
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(12.0),
                                          child: Text(
                                            context.l10n.correctedWordHeader,
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(12.0),
                                          child: Text(
                                            context.l10n.actionHeader,
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ],
                                    ),
                                    ...filteredKeys.map((wrong) {
                                      final correct = fixes[wrong] ?? '';
                                      return TableRow(
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                                            child: Align(
                                              alignment: AlignmentDirectional.centerStart,
                                              child: Text(
                                                wrong,
                                                style: const TextStyle(fontWeight: FontWeight.w500),
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                                            child: Align(
                                              alignment: AlignmentDirectional.centerStart,
                                              child: Text(
                                                correct,
                                                style: const TextStyle(
                                                  color: Colors.green,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                            child: Center(
                                              child: IconButton(
                                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                                onPressed: () => _confirmDeleteWord(
                                                  context,
                                                  wrong,
                                                  fixes,
                                                  config,
                                                  admin,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    }),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
