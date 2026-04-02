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
                  ...catProvider.categories.map((cat) => Padding(
                    padding: const EdgeInsets.only(left: AppDimens.spaceS),
                    child: ChoiceChip(
                      label: Text(cat.name),
                      selected: selectedCategory?.id == cat.id,
                      selectedColor: AppColors.primary.withValues(alpha: 0.2),
                      onSelected: (val) => onCategoryChanged(cat),
                    ),
                  )),
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
}
