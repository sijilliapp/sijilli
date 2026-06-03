import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sijilli/core/constants/app_colors.dart';
import 'package:sijilli/core/providers/settings_provider.dart';
import 'package:sijilli/features/appointments/widgets/cards/policies/standard_policy.dart';

class FeaturedPolicy extends StandardPolicy {
  final bool isReadOnly;

  FeaturedPolicy(super.appointment, super.context, {super.customOnTap, this.isReadOnly = false});

  @override
  VoidCallback? get onCardTap => isReadOnly ? customOnTap : super.onCardTap;

  @override
  VoidCallback? get onHostTap => isReadOnly ? null : super.onHostTap;

  @override
  bool get isFeatured => true;

  @override
  double get elevation => 0;

  @override
  double get borderWidth => 1.0;

  @override
  Color get cardColor => AppColors.appointmentCardBackground;


  @override
  bool get showLocation {
    if (isReadOnly) return false;
    try {
      return Provider.of<SettingsProvider>(context, listen: false).showLocationInfo;
    } catch (_) {
      return true;
    }
  }

  @override
  Color get shadowColor => Colors.transparent;
}
