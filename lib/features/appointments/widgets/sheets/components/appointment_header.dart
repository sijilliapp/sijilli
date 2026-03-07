import 'package:flutter/material.dart';
import 'package:sijilli/core/constants/app_colors.dart';
import 'package:sijilli/core/constants/app_dimens.dart';

class AppointmentHeader extends StatelessWidget {
  final String title;
  final String? smartLocation;
  final bool hasLocation;

  const AppointmentHeader({
    super.key,
    required this.title,
    this.smartLocation,
    this.hasLocation = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppDimens.textSizeXL,
              fontWeight: FontWeight.w900,
              color: AppColors.getTextPrimary(context),
            ),
            maxLines: 2, // Allow up to 2 lines
            overflow: TextOverflow.ellipsis,
          ),
        const SizedBox(height: AppDimens.spaceXS),
        if (hasLocation && smartLocation != null)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible( // Constrain width to prevent overflow
                child: Text(
                  smartLocation!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: AppDimens.textSize,
                    color: AppColors.getTextSecondary(context),
                  ),
                  maxLines: 1, // Smart truncation
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
