import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_dimens.dart';

/// Represents a single action item in the [AppActionSheet].
class AppActionItem {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDestructive;

  AppActionItem({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isDestructive = false,
  });
}

/// A centralized, reusable bottom sheet for displaying a list of actions.
/// Ensures consistent styling (borders, handles, items) across the entire application.
class AppActionSheet extends StatelessWidget {
  final List<AppActionItem> actions;
  final String? title;

  const AppActionSheet({
    super.key,
    required this.actions,
    this.title,
  });

  /// Helper to display the sheet easily.
  static Future<T?> show<T>(BuildContext context, {required List<AppActionItem> actions, String? title}) {
    return showModalBottomSheet<T>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AppActionSheet(actions: actions, title: title),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.getCardBackground(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppDimens.radiusXL)),
      ),
      padding: const EdgeInsets.fromLTRB(AppDimens.padding, AppDimens.padding, AppDimens.padding, AppDimens.padding * 1.5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Indicator Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppDimens.spaceL),
          
          if (title != null) ...[
            Text(
              title!,
              style: const TextStyle(
                fontSize: AppDimens.textSizeM,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppDimens.spaceM),
          ],

          // Actions List
          ...List.generate(actions.length, (index) {
            final action = actions[index];
            final color = action.isDestructive ? AppColors.error : AppColors.primary;
            final isDark = Theme.of(context).brightness == Brightness.dark;
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                    foregroundColor: color,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimens.radius),
                    ),
                  ),
                  icon: Icon(action.icon, color: color),
                  label: Text(
                    action.label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: AppDimens.textSizeM,
                      color: action.isDestructive ? AppColors.error : AppColors.getTextPrimary(context),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    action.onTap();
                  },
                ),
              ),
            );
          }),
          
          // Empty space at the bottom equivalent to one button height (~56px)
          const SizedBox(height: 56),
        ],
      ),
    );
  }
}
