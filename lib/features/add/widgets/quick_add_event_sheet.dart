import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/context_l10n.dart';
import '../../../../core/providers/global_config_provider.dart';
import '../../../../core/services/autocomplete_service.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../auth/providers/auth_provider.dart';
import '../../appointments/providers/appointment_provider.dart';
import '../providers/add_event_provider.dart';
import 'suggested_time_capsules_bar.dart';
import 'unified_date_picker.dart';
import 'word_river_widget.dart';

class QuickAddEventSheet extends StatefulWidget {
  final VoidCallback? onSwitchToAdvanced;

  const QuickAddEventSheet({
    super.key,
    this.onSwitchToAdvanced,
  });

  static Future<bool?> show(BuildContext context, {VoidCallback? onSwitchToAdvanced}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: QuickAddEventSheet(onSwitchToAdvanced: onSwitchToAdvanced),
      ),
    );
  }

  @override
  State<QuickAddEventSheet> createState() => _QuickAddEventSheetState();
}

class _QuickAddEventSheetState extends State<QuickAddEventSheet> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final FocusNode _titleFocusNode = FocusNode();
  bool _isTitleFocused = false;

  @override
  void initState() {
    super.initState();
    _titleFocusNode.addListener(_onTitleFocusChange);
  }

  @override
  void dispose() {
    _titleFocusNode.removeListener(_onTitleFocusChange);
    _titleController.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  void _onTitleFocusChange() {
    if (mounted) {
      setState(() {
        _isTitleFocused = _titleFocusNode.hasFocus;
      });
    }
  }

  void _onWordSelected(String word) {
    final current = _titleController.text;
    final updated = current.isEmpty ? word : '$current $word';
    _titleController.text = updated;
    _titleController.selection = TextSelection.fromPosition(
      TextPosition(offset: updated.length),
    );
    final provider = context.read<AddEventProvider>();
    provider.onTitleChanged(updated);
  }

  void _onPivotSelected(PivotMatch match) {
    _titleController.text = match.fullTitle;
    _titleController.selection = TextSelection.fromPosition(
      TextPosition(offset: match.fullTitle.length),
    );
    final provider = context.read<AddEventProvider>();
    provider.onTitleChanged(match.fullTitle);
  }

  Future<void> _saveQuickEvent(AddEventProvider provider) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    
    final auth = context.read<AuthProvider>();
    final apptProvider = context.read<AppointmentProvider>();
    final globalConfig = context.read<GlobalConfigProvider>();
    
    if (auth.user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.pleaseLoginFirst)),
      );
      return;
    }
    
    final host = auth.user!;
    
    final result = await provider.saveEvent(
      title: _titleController.text.trim(),
      location: '',
      building: '',
      description: '',
      currentUser: host,
      appointmentProvider: apptProvider,
      locale: context.l10n.localeName,
      dailyLimit: globalConfig.dailyAppointmentLimit(host),
    );

    if (result != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result), backgroundColor: AppColors.error),
        );
      }
      return;
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Localizations.localeOf(context).languageCode == 'ar' 
                ? 'تم حفظ الموعد بنجاح ⚡' 
                : 'Appointment saved successfully ⚡',
          ),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<AddEventProvider>();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).cardColor : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header: Title + Switch to Advanced Mode Capsule
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        Localizations.localeOf(context).languageCode == 'ar'
                            ? 'إضافة موعد سريع ⚡'
                            : 'Quick Add Appointment ⚡',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () {
                      provider.setMode(AddEventMode.advanced);
                      Navigator.of(context).pop(false);
                      widget.onSwitchToAdvanced?.call();
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        border: Border.all(color: AppColors.primary, width: 1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.tune, size: 13, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            Localizations.localeOf(context).languageCode == 'ar' ? 'متقدم ⚙️' : 'Advanced ⚙️',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Subject Input
              CustomTextField(
                controller: _titleController,
                focusNode: _titleFocusNode,
                label: context.l10n.subject,
                hint: context.l10n.subjectHint,
                maxLength: 50,
                showCountdown: true,
                validator: (val) => val == null || val.trim().isEmpty ? context.l10n.fieldRequired : null,
              ),
              const SizedBox(height: 4),

              LayoutBuilder(
                builder: (context, constraints) {
                  final showTitleSuggestions = _isTitleFocused && (provider.suggestions.isNotEmpty || provider.pivotSuggestions.isNotEmpty);
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: showTitleSuggestions
                        ? Container(
                            key: const ValueKey('quick_title_suggestions'),
                            width: MediaQuery.of(context).size.width,
                            child: WordRiverWidget(
                              suggestions: provider.suggestions,
                              onWordSelected: _onWordSelected,
                              pivotSuggestions: provider.pivotSuggestions,
                              onPivotSelected: _onPivotSelected,
                            ),
                          )
                        : const SizedBox.shrink(key: ValueKey('no_quick_title_suggestions')),
                  );
                },
              ),

              const SizedBox(height: 12),

              // Unified Date Picker (بدون بار أوقات الشمس وبدون سطر الهوية)
              Consumer<AuthProvider>(
                builder: (context, auth, _) {
                  return UnifiedDatePicker(
                    initialDate: provider.selectedDate ?? DateTime.now(),
                    initialMode: provider.isHijri,
                    hijriAdjustment: (auth.user?.hijriAdjustment ?? 0).toInt(),
                    onDateChanged: provider.setDate,
                    onModeChanged: provider.setIsHijri,
                  );
                },
              ),

              const SizedBox(height: 12),

              // Suggested Time Capsules Bar
              SuggestedTimeCapsulesBar(
                selectedTime: provider.selectedTime,
                onSelectTime: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: provider.selectedTime ?? TimeOfDay.now(),
                  );
                  if (time != null) {
                    provider.setTime(time);
                  }
                },
                frequentTimes: provider.frequentTimes,
                onTimePicked: (tod) => provider.setTime(tod),
              ),

              const SizedBox(height: 18),

              // Single Unique Save Button (حفظ الموعد ⚡)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: provider.isSaving ? null : () => _saveQuickEvent(provider),
                child: provider.isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        Localizations.localeOf(context).languageCode == 'ar' ? 'حفظ الموعد ⚡' : 'Save Appointment ⚡',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
