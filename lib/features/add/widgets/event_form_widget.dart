import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/services/autocomplete_service.dart';
import 'word_river_widget.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';

class EventFormWidget extends StatelessWidget {
  final TextEditingController titleController;
  final TextEditingController locationController;
  final TextEditingController buildingController;
  final TextEditingController? streamLinkController; 
  final String privacy;
  final ValueChanged<String> onPrivacyChanged;
  final String? Function(String?)? titleValidator;
  
  final List<String> suggestions;
  final ValueChanged<String>? onWordSelected;
  
  final FocusNode? titleFocusNode;
  final bool isTitleFocused;

  final List<PivotMatch> pivotSuggestions;
  final ValueChanged<PivotMatch>? onPivotSelected;

  final FocusNode? locationFocusNode;
  final bool isLocationFocused;
  final FocusNode? buildingFocusNode;
  final bool isBuildingFocused;
  final List<String> regionSuggestions;
  final List<String> buildingSuggestions;
  final ValueChanged<String>? onRegionSelected;
  final ValueChanged<String>? onBuildingSelected;

  final bool pinAddress;
  final ValueChanged<bool>? onPinAddressChanged;
  final VoidCallback? onOpenLocationPicker;

  const EventFormWidget({
    super.key,
    required this.titleController,
    required this.locationController,
    required this.buildingController,
    this.streamLinkController,
    required this.privacy,
    required this.onPrivacyChanged,
    this.titleValidator,
    this.suggestions = const [],
    this.onWordSelected,
    this.titleFocusNode,
    this.isTitleFocused = false,
    this.pivotSuggestions = const [],
    this.onPivotSelected,
    this.locationFocusNode,
    this.isLocationFocused = false,
    this.buildingFocusNode,
    this.isBuildingFocused = false,
    this.regionSuggestions = const [],
    this.buildingSuggestions = const [],
    this.onRegionSelected,
    this.onBuildingSelected,
    this.pinAddress = false,
    this.onPinAddressChanged,
    this.onOpenLocationPicker,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPrivacyToggle(context),
        const SizedBox(height: 6),

        CustomTextField(
          controller: titleController,
          focusNode: titleFocusNode,
          label: context.l10n.subject,
          hint: context.l10n.subjectHint,
          maxLength: 50,
          showCountdown: true,
          validator: titleValidator,
        ),
        
        LayoutBuilder(
          builder: (context, constraints) {
            final showTitleSuggestions = isTitleFocused && (suggestions.isNotEmpty || pivotSuggestions.isNotEmpty);
            
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: showTitleSuggestions
                  ? Container(
                      key: const ValueKey('title_suggestions'),
                      decoration: const BoxDecoration(
                        color: Colors.transparent, // Making it "free"
                      ),
                      width: MediaQuery.of(context).size.width,
                      child: WordRiverWidget(
                        suggestions: suggestions,
                        onWordSelected: onWordSelected!,
                        pivotSuggestions: pivotSuggestions,
                        onPivotSelected: onPivotSelected,
                      ),
                    )
                  : const SizedBox.shrink(key: ValueKey('no_title_suggestions')),
            );
          },
        ),

        const SizedBox(height: 6),
        
        Row(
          children: [
            Expanded(
              child: CustomTextField(
                controller: locationController,
                focusNode: locationFocusNode,
                label: context.l10n.region,
                hint: context.l10n.regionHint,
                maxLength: 30,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: CustomTextField(
                controller: buildingController,
                focusNode: buildingFocusNode,
                label: context.l10n.building,
                hint: context.l10n.buildingHint,
                maxLength: 60, // Increased to support building name + coordinate string suffix
                suffixIcon: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.primary, width: 1.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(
                      Icons.map_outlined,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ),
                  onPressed: onOpenLocationPicker,
                ),
              ),
            ),
          ],
        ),

        // Pin Address Switch
        if (onPinAddressChanged != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.l10n.localeName == 'ar' ? 'ثبِّت واستخدم هذا العنوان تلقائياً' : 'Pin and use this address automatically',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade300 : Colors.grey.shade800,
                  ),
                ),
                Switch(
                  value: pinAddress,
                  onChanged: onPinAddressChanged,
                  activeColor: AppColors.primary,
                ),
              ],
            ),
          ),
        
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _shouldShowLocationSuggestions()
              ? Container(
                  key: const ValueKey('location_suggestions'),
                  decoration: const BoxDecoration(
                    color: Colors.transparent,
                  ),
                  width: MediaQuery.of(context).size.width,
                  child: WordRiverWidget(
                    suggestions: isLocationFocused ? regionSuggestions : buildingSuggestions,
                    onWordSelected: isLocationFocused
                        ? (word) => onRegionSelected?.call(word)
                        : (word) => onBuildingSelected?.call(word),
                    pivotSuggestions: const [],
                  ),
                )
              : const SizedBox.shrink(key: ValueKey('no_location_suggestions')),
        ),

        if (streamLinkController != null) ...[
          const SizedBox(height: 6),
           Text(context.l10n.streamLink, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
           const SizedBox(height: 2),
           Builder(
             builder: (context) {
               final isDark = Theme.of(context).brightness == Brightness.dark;
               return TextFormField(
                  controller: streamLinkController,
                  textDirection: TextDirection.ltr,
                  keyboardType: TextInputType.url,
                  maxLength: 500,
                  decoration: InputDecoration(
                    hintText: context.l10n.streamLinkHint,
                    prefixIcon: const Icon(Icons.link),
                    filled: true,
                    fillColor: isDark ? Colors.grey.shade800 : Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                    ),
                  ),
               );
             }
           ),
        ],
      ],
    );
  }

  Widget _buildPrivacyToggle(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.appointmentPrivacy,
          style: TextStyle(
            fontSize: 14, 
            color: isDark ? Colors.white : Colors.black87
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              _buildPrivacyOption('public', context.l10n.privacyPublic, Icons.public, context),
              _buildPrivacyOption('followers', context.l10n.privacyFollowers, Icons.people_outline, context),
              _buildPrivacyOption('private', context.l10n.privacyPrivate, Icons.lock_outline, context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPrivacyOption(String value, String label, IconData icon, BuildContext context) {
    bool isSelected = privacy == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Expanded(
      child: GestureDetector(
        onTap: () => onPrivacyChanged(value),
        child: Container(
          height: 44,
          margin: EdgeInsets.zero,
          decoration: BoxDecoration(
            color: isSelected 
                ? (isDark ? Colors.grey.shade700 : Colors.white) 
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected ? [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2)),
            ] : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon, 
                size: 16, 
                color: isSelected ? AppColors.primary : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? AppColors.primary : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _shouldShowLocationSuggestions() {
    return (isLocationFocused && regionSuggestions.isNotEmpty) || 
           (isBuildingFocused && buildingSuggestions.isNotEmpty);
  }
}
