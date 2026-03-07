import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_dimens.dart';

class AppStyles {
  AppStyles._();

  // الأنماط الأساسية باستخدام الثوابت الموجودة
  static const TextStyle headlineLarge = TextStyle(
    fontSize: AppDimens.textSizeXL,
    fontWeight: FontWeight.bold,
    color: AppColors.lightTextPrimary,
    height: 1.2,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: AppDimens.textSizeL,
    fontWeight: FontWeight.w600,
    color: AppColors.lightTextPrimary,
    height: 1.3,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: AppDimens.textSize,
    fontWeight: FontWeight.normal,
    color: AppColors.lightTextPrimary,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: AppDimens.textSizeS,
    fontWeight: FontWeight.normal,
    color: AppColors.lightTextSecondary,
    height: 1.5,
  );

  static const TextStyle buttonText = TextStyle(
    fontSize: AppDimens.textSize,
    fontWeight: FontWeight.w500,
    color: Colors.white,
  );

  static const TextStyle cardTitle = TextStyle(
    fontSize: AppDimens.textSizeM,
    fontWeight: FontWeight.w600,
    color: AppColors.lightTextPrimary,
  );

  static const TextStyle cardSubtitle = TextStyle(
    fontSize: AppDimens.textSizeS,
    fontWeight: FontWeight.normal,
    color: AppColors.lightTextSecondary,
  );

  static const TextStyle errorText = TextStyle(
    fontSize: AppDimens.textSizeXS,
    fontWeight: FontWeight.normal,
    color: AppColors.warning,
  );

  static ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: AppColors.primary,
    foregroundColor: Colors.white,
    textStyle: buttonText,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppDimens.radius)),
    ),
    padding: const EdgeInsets.symmetric(
      horizontal: AppDimens.space,
      vertical: AppDimens.spaceS,
    ),
    minimumSize: const Size(AppDimens.buttonMinWidth, AppDimens.buttonHeight),
  );

  static InputDecoration get inputDecoration => const InputDecoration(
    border: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppDimens.radiusS)),
      borderSide: BorderSide(color: AppColors.lightBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppDimens.radiusS)),
      borderSide: BorderSide(color: AppColors.lightBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppDimens.radiusS)),
      borderSide: BorderSide(color: AppColors.primary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppDimens.radiusS)),
      borderSide: BorderSide(color: AppColors.warning),
    ),
    filled: true,
    fillColor: AppColors.lightSurface,
    contentPadding: EdgeInsets.all(AppDimens.spaceM),
  );

  // ملاحظة: الثوابت المفقودة تحتاج إضافتها أولاً لاستخدام باقي الأنماط
}
