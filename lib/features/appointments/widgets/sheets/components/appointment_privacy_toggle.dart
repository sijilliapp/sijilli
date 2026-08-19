import 'package:flutter/material.dart';
import 'package:sijilli/core/constants/app_colors.dart';
import 'package:sijilli/core/constants/app_dimens.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';

class AppointmentPrivacyToggle extends StatelessWidget {
  final String selectedPrivacy;
  final Function(String) onPrivacyChanged;

  const AppointmentPrivacyToggle({
    super.key,
    required this.selectedPrivacy,
    required this.onPrivacyChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimens.radiusM),
            border: Border.all(color: AppColors.getBorder(context)),
          ),
          child: Row(
            children: [
              _buildPrivacyOption(context, 'public', context.l10n.privacyPublicLabel, Icons.public),
              Container(width: 1, height: 40, color: AppColors.getBorder(context)),
              _buildPrivacyOption(context, 'followers', context.l10n.privacyFollowersLabel, Icons.people),
              Container(width: 1, height: 40, color: AppColors.getBorder(context)),
              _buildPrivacyOption(context, 'private', context.l10n.privacyPrivateLabel, Icons.lock),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPrivacyOption(BuildContext context, String value, String label, IconData icon) {
    final isSelected = selectedPrivacy == value;

    return Expanded(
      child: InkWell(
        onTap: () => onPrivacyChanged(value),
        borderRadius: BorderRadius.circular(AppDimens.radiusM),
        child: Container(
          height: 80,
          color: isSelected ? AppColors.primary.withValues(alpha: 0.05) : Colors.transparent,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon, 
                color: isSelected ? AppColors.primary : AppColors.getTextSecondary(context),
                size: 20,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: isSelected ? AppColors.primary : AppColors.getTextSecondary(context),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
