import 'package:flutter/material.dart';
import 'package:sijilli/core/constants/app_colors.dart';
import 'package:sijilli/core/constants/app_dimens.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';

class AppointmentActionButtons extends StatelessWidget {
  final bool isArchived;
  final VoidCallback onClone;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  const AppointmentActionButtons({
    super.key,
    required this.isArchived,
    required this.onClone,
    required this.onArchive,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Align(
          alignment: context.l10n.localeName == 'ar' ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(
            context.l10n.detailsQuickActions,
            style: TextStyle(
              fontSize: AppDimens.textSize,
              fontWeight: FontWeight.bold,
              color: AppColors.getTextSecondary(context),
            ),
          ),
        ),
        const SizedBox(height: AppDimens.space),
        Row(
          children: [
            _buildQuickActionBtn(
              icon: Icons.copy,
              label: context.l10n.detailsClone,
              color: AppColors.primary,
              onTap: onClone,
            ),
            const SizedBox(width: AppDimens.space),
            _buildQuickActionBtn(
              icon: isArchived ? Icons.unarchive : Icons.archive,
              label: isArchived ? context.l10n.detailsUnarchive : context.l10n.detailsArchive,
              color: isArchived ? Colors.green : AppColors.alert,
              onTap: onArchive,
            ),
            const SizedBox(width: AppDimens.space),
            _buildQuickActionBtn(
              icon: Icons.delete_outline,
              label: context.l10n.delete,
              color: AppColors.warning,
              onTap: onDelete,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionBtn({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return Expanded(
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppDimens.radiusM),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimens.radiusM),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppDimens.radiusM),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
