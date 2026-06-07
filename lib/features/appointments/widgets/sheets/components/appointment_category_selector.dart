import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sijilli/models/appointment.dart';
import 'package:sijilli/features/appointments/providers/category_provider.dart';
import 'package:sijilli/core/constants/app_colors.dart';
import 'package:sijilli/core/constants/app_dimens.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';

class AppointmentCategorySelector extends StatelessWidget {
  final Appointment appointment;
  final AppointmentCategory? selectedCategory;
  final Function(AppointmentCategory?) onCategoryChanged;
  final VoidCallback onAddCategory;

  const AppointmentCategorySelector({
    super.key,
    required this.appointment,
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.onAddCategory,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
             Text(context.l10n.detailsPersonalCategory, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: AppDimens.spaceS),
        
        Consumer<CategoryProvider>(
          builder: (context, catProvider, child) {
            return SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  // خيار بدون تصنيف
                  Padding(
                    padding: const EdgeInsets.only(left: AppDimens.spaceS),
                    child: ChoiceChip(
                      label: Text(context.l10n.detailsNoCategory),
                      selected: selectedCategory == null,
                      selectedColor: AppColors.primary.withValues(alpha: 0.2),
                      onSelected: (val) => onCategoryChanged(null),
                    ),
                  ),
                  // التصنيفات المتاحة
                  ...catProvider.categories.map((cat) {
                    final isSelected = selectedCategory?.id == cat.id;
                    return Padding(
                      padding: const EdgeInsets.only(left: AppDimens.spaceS),
                      child: GestureDetector(
                        onLongPress: () => _showEditCategoryDialog(context, cat, isSelected),
                        child: ChoiceChip(
                          label: Text(cat.name),
                          selected: isSelected,
                          selectedColor: AppColors.primary.withValues(alpha: 0.2),
                          onSelected: (val) => onCategoryChanged(cat),
                        ),
                      ),
                    );
                  }),
                  // إضافة تصنيف جديد
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 16, color: AppColors.primary),
                    label: Text(context.l10n.detailsAddNew),
                    onPressed: onAddCategory,
                  ),
                ],
              ),
            );
          }
        ),
      ],
    );
  }

  void _showEditCategoryDialog(BuildContext context, AppointmentCategory cat, bool isSelected) {
    final controller = TextEditingController(text: cat.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديل التصنيف'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'اسم التصنيف'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('حذف التصنيف'),
                  content: Text('هل أنت متأكد من حذف التصنيف "${cat.name}"؟'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('إلغاء'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('حذف', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                if (context.mounted) {
                  await context.read<CategoryProvider>().deleteCategory(cat.id);
                  if (isSelected) {
                    onCategoryChanged(null);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              }
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty && controller.text != cat.name) {
                final updated = await context.read<CategoryProvider>().updateCategory(cat.id, controller.text);
                if (updated != null && isSelected) {
                  onCategoryChanged(updated);
                }
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}
