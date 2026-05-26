import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/global_config_provider.dart';
import '../providers/admin_provider.dart';

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
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'إضافة خطأ شائع جديد',
          textAlign: TextAlign.right,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: wrongController,
              textDirection: TextDirection.rtl,
              decoration: const InputDecoration(
                labelText: 'الكلمة غير الصحيحة (مثال: هاذا)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: correctController,
              textDirection: TextDirection.rtl,
              decoration: const InputDecoration(
                labelText: 'التصحيح (مثال: هذا)',
                border: OutlineInputBorder(),
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

              Navigator.pop(context);
              final success = await adminProvider.updateConfigString(
                'spelling_fixes',
                json.encode(updated),
                configProvider,
              );

              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تمت إضافة التصحيح بنجاح 🎉'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('إضافة'),
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
      builder: (context) => AlertDialog(
        title: const Text('حذف قاعدة التصحيح'),
        content: Text('هل أنت متأكد من حذف قاعدة تصحيح "$wrong"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              final updated = Map<String, String>.from(currentFixes);
              updated.remove(wrong);

              Navigator.pop(context);
              final success = await adminProvider.updateConfigString(
                'spelling_fixes',
                json.encode(updated),
                configProvider,
              );

              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم حذف قاعدة التصحيح'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'تفضيلات المقالات الإدارية',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      body: Consumer2<GlobalConfigProvider, AdminProvider>(
        builder: (context, config, admin, _) {
          final fixes = config.spellingFixes;
          final filteredKeys = fixes.keys
              .where((k) => k.contains(_searchQuery) || fixes[k]!.contains(_searchQuery))
              .toList();

          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // 📊 القسم الأول: الحد الأقصى لحروف المقال
                const Padding(
                  padding: EdgeInsets.only(bottom: 8.0, right: 4.0),
                  child: Text(
                    'الحدود والضوابط',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
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
                          child: const Icon(Icons.text_fields_rounded, color: AppColors.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'الحد الأقصى لحروف المقال',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'العدد الأقصى للحروف للمقال الواحد: ${config.articleMaxChars}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        admin.isLoading
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
                                ),
                                icon: const Icon(Icons.edit, size: 16),
                                label: const Text('تعديل'),
                                onPressed: () async {
                                  final controller = TextEditingController(
                                    text: config.articleMaxChars.toString(),
                                  );
                                  final result = await showDialog<int>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('تعديل الحد الأقصى للحروف'),
                                      content: TextField(
                                        controller: controller,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          hintText: 'أدخل العدد الجديد...',
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text('إلغاء'),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            final val = int.tryParse(controller.text);
                                            if (val != null) {
                                              Navigator.pop(context, val);
                                            }
                                          },
                                          child: const Text('حفظ'),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (result != null && context.mounted) {
                                    await admin.updateConfigNumber(
                                      'article_max_chars',
                                      result.toDouble(),
                                      config,
                                    );
                                  }
                                },
                              ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // 📚 القسم الثاني: الأخطاء الشائعة
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'إدارة الأخطاء الشائعة والتدقيق',
                      style: TextStyle(
                        fontSize: 14,
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
                      label: const Text('إضافة خطأ شائع'),
                      onPressed: () => _showAddWordDialog(context, fixes, config, admin),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // حقل البحث في الكلمات
                TextField(
                  controller: _searchController,
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(
                    hintText: 'البحث في القاموس المخصص...',
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
                const SizedBox(height: 12),

                // جدول الكلمات الأنيق
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
                                    ? 'لا يوجد كلمات مضافة في القاموس الإداري المخصص بعد.'
                                    : 'لم يتم العثور على نتائج مطابقة للبحث.',
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
                              // ترويسة الجدول
                              TableRow(
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.black26 : Colors.grey.shade50,
                                ),
                                children: const [
                                  Padding(
                                    padding: EdgeInsets.all(12.0),
                                    child: Text(
                                      'الخطأ الشائع',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.all(12.0),
                                    child: Text(
                                      'التصحيح المعتمد',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.all(12.0),
                                    child: Text(
                                      'إجراء',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                              // صفوف الجدول
                              ...filteredKeys.map((wrong) {
                                final correct = fixes[wrong] ?? '';
                                return TableRow(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          wrong,
                                          style: const TextStyle(fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                                      child: Align(
                                        alignment: Alignment.centerRight,
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
          );
        },
      ),
    );
  }
}
