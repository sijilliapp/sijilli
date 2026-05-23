import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sijilli/core/constants/app_colors.dart';
import 'package:sijilli/core/constants/app_dimens.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';
import 'package:sijilli/features/appointments/providers/appointment_provider.dart';
import 'package:sijilli/features/appointments/providers/category_provider.dart';
import 'package:sijilli/features/add/screens/add_event_screen.dart';
import 'package:sijilli/models/appointment.dart';

class PersonalSettingsSheet extends StatefulWidget {
  final Appointment appointment;

  const PersonalSettingsSheet({super.key, required this.appointment});

  @override
  State<PersonalSettingsSheet> createState() => _PersonalSettingsSheetState();
}

class _PersonalSettingsSheetState extends State<PersonalSettingsSheet> {
  late String _selectedPrivacy;
  AppointmentCategory? _selectedCategories;

  @override
  void initState() {
    super.initState();
    _selectedPrivacy = widget.appointment.currentUserInvitation?.privacy ?? 'private';
    _selectedCategories = widget.appointment.currentUserInvitation?.categories;
  }

  @override
  Widget build(BuildContext context) {
    final catProvider = context.watch<CategoryProvider>();
    
    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceXL),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppDimens.radiusXXL)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l10n.detailsPersonalSettings,
                style: const TextStyle(fontSize: AppDimens.textSizeM, fontWeight: FontWeight.bold),
              ),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: AppDimens.spaceL),
          
          // الخصوصية
          Text(context.l10n.privacyProfileTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: AppDimens.spaceM),
          Row(
            children: [
              _buildPrivacyOption('public', context.l10n.privacyPublicLabel, Icons.public),
              const SizedBox(width: AppDimens.spaceS),
              _buildPrivacyOption('followers', context.l10n.privacyFollowersLabel, Icons.people),
              const SizedBox(width: AppDimens.spaceS),
              _buildPrivacyOption('private', context.l10n.privacyPrivateLabel, Icons.lock),
            ],
          ),
          
          const SizedBox(height: AppDimens.spaceXL),
          
          // التصنيف
          Text(context.l10n.detailsPersonalCategory, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: AppDimens.spaceM),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                // خيار بدون تصنيف
                Padding(
                  padding: const EdgeInsets.only(left: AppDimens.spaceS),
                  child: ChoiceChip(
                    label: Text(context.l10n.detailsNoCategory),
                    selected: _selectedCategories == null,
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
                    onSelected: (val) => setState(() => _selectedCategories = null),
                  ),
                ),
                // التصنيفات المتاحة
                ...catProvider.categories.map((cat) => Padding(
                  padding: const EdgeInsets.only(left: AppDimens.spaceS),
                  child: ChoiceChip(
                    label: Text(cat.name),
                    selected: _selectedCategories?.id == cat.id,
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
                    onSelected: (val) => setState(() => _selectedCategories = cat),
                  ),
                )),
                // إضافة تصنيف جديد
                ActionChip(
                  avatar: const Icon(Icons.add, size: 16, color: AppColors.primary),
                  label: Text(context.l10n.detailsAddNew),
                  onPressed: () => _showAddCategoryDialog(context),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: AppDimens.spaceXL),
          
          // إجراءات سريعة
          if (!widget.appointment.isUserDeleted) ...[
            Text(context.l10n.detailsQuickActions, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppDimens.spaceM),
            Row(
              children: [
                _buildActionButton(
                  label: context.l10n.detailsClone,
                  icon: Icons.copy_rounded,
                  color: AppColors.primary,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddEventScreen(initialAppointment: widget.appointment),
                      ),
                    );
                  },
                ),
                const SizedBox(width: AppDimens.spaceS),
                _buildActionButton(
                  label: widget.appointment.isArchived ? context.l10n.detailsUnarchive : context.l10n.detailsArchive,
                  icon: widget.appointment.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
                  color: widget.appointment.isArchived ? Colors.green : Colors.amber.shade700,
                  onTap: () {
                    if (widget.appointment.isArchived) {
                      context.read<AppointmentProvider>().unarchiveInvitation(widget.appointment.id);
                    } else {
                      context.read<AppointmentProvider>().archiveInvitation(widget.appointment.id);
                    }
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(width: AppDimens.spaceS),
                _buildActionButton(
                  label: context.l10n.delete,
                  icon: Icons.delete_outline_rounded,
                  color: Colors.redAccent,
                  onTap: () {
                    _showDeleteConfirmation(context);
                  },
                ),
              ],
            ),
          ] else ...[
             // For Trash items: "Cannot be restored, only cloned"
             Text(context.l10n.detailsQuickActions, style: const TextStyle(fontWeight: FontWeight.bold)),
             const SizedBox(height: AppDimens.spaceM),
             Row(
              children: [
                _buildActionButton(
                  label: context.l10n.detailsClone,
                  icon: Icons.copy_rounded,
                  color: AppColors.primary,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddEventScreen(initialAppointment: widget.appointment),
                      ),
                    );
                  },
                ),
              ],
             ),
             const SizedBox(height: AppDimens.spaceS),
             Container(
               padding: const EdgeInsets.all(12),
               decoration: BoxDecoration(
                 color: Colors.red.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.15 : 0.05),
                 borderRadius: BorderRadius.circular(8),
               ),
               child: Row(
                 children: [
                   const Icon(Icons.info_outline, color: Colors.red, size: 20),
                   const SizedBox(width: 8),
                   Expanded(
                     child: Text(
                       context.l10n.detailsTrashWarning,
                       style: TextStyle(
                         color: Theme.of(context).brightness == Brightness.dark ? Colors.red.shade200 : Colors.red.shade800,
                         fontSize: 12,
                       ),
                     ),
                   ),
                 ],
               ),
             ),
          ],
          
          const SizedBox(height: AppDimens.spaceXXL),
          
          // زر حفظ
          Container(
            width: double.infinity,
            height: AppDimens.buttonHeightL,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDimens.radiusL),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimens.radiusL)),
              ),
              onPressed: () {
                context.read<AppointmentProvider>().updateInvitationSettings(
                  widget.appointment.id,
                  privacy: _selectedPrivacy,
                  categories: _selectedCategories,
                );
                Navigator.pop(context);
              },
              child: Text(
                context.l10n.detailsSavePersonalSettings, 
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: AppDimens.textSize),
              ),
            ),
          ),
          const SizedBox(height: AppDimens.space),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusM),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceM),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppDimens.radiusM),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(height: AppDimens.spaceTiny),
              Text(
                label,
                style: TextStyle(
                  fontSize: AppDimens.textSizeXXS + 1,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(context.l10n.detailsDeleteTitleGuest),
            content: Text(context.l10n.detailsDeleteConfirmGuest),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(ctx), 
                child: Text(context.l10n.cancel),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent, 
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.redAccent.withValues(alpha: 0.6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimens.radius)),
                ),
                onPressed: isLoading ? null : () async {
                  setState(() => isLoading = true);
                  try {
                    await context.read<AppointmentProvider>().deleteInvitation(widget.appointment.id);
                    if (ctx.mounted) Navigator.pop(ctx); // Close dialog
                    if (mounted) Navigator.pop(context); // Close sheet
                  } catch (e) {
                    if (ctx.mounted) setState(() => isLoading = false);
                  }
                },
                child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(context.l10n.delete),
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildPrivacyOption(String value, String label, IconData icon) {
    final isSelected = _selectedPrivacy == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedPrivacy = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceM),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : (isDark ? Colors.grey.shade800 : Colors.grey.shade50),
            borderRadius: BorderRadius.circular(AppDimens.radiusM),
            border: Border.all(color: isSelected ? AppColors.primary : (isDark ? Colors.grey.shade700 : Colors.grey.shade200)),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: isSelected ? AppColors.primary : (isDark ? Colors.grey.shade400 : Colors.grey)),
              const SizedBox(height: AppDimens.spaceXS),
              Text(
                label, 
                style: TextStyle(
                  fontSize: AppDimens.textSizeXXS, 
                  color: isSelected ? AppColors.primary : (isDark ? Colors.grey.shade400 : Colors.grey),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                )
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.detailsNewCategory),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: context.l10n.detailsCategoryHint),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.l10n.cancel)),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                final newCat = await context.read<CategoryProvider>().addCategory(controller.text);
                if (newCat != null) {
                  setState(() => _selectedCategories = newCat);
                }
                Navigator.pop(ctx);
              }
            },
            child: Text(context.l10n.add),
          ),
        ],
      ),
    );
  }
}
