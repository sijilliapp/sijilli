import 'package:flutter/material.dart';
import 'package:sijilli/core/constants/app_colors.dart';
import 'package:sijilli/core/constants/app_dimens.dart';
import 'package:url_launcher/url_launcher_string.dart';

class AppointmentHeader extends StatelessWidget {
  final String title;
  final String? smartLocation;
  final bool hasLocation;
  final String? coordinates;

  const AppointmentHeader({
    super.key,
    required this.title,
    this.smartLocation,
    this.hasLocation = false,
    this.coordinates,
  });

  @override
  Widget build(BuildContext context) {
    final hasCoords = coordinates != null && coordinates!.isNotEmpty;

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
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppDimens.spaceXS),
        if (hasLocation && smartLocation != null)
          GestureDetector(
            onTap: hasCoords
                ? () async {
                    final url = 'https://www.google.com/maps/search/?api=1&query=$coordinates';
                    if (await canLaunchUrlString(url)) {
                      await launchUrlString(url, mode: LaunchMode.externalApplication);
                    }
                  }
                : null,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasCoords) ...[
                  const Icon(
                    Icons.location_on_outlined,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    smartLocation!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: AppDimens.textSize,
                      color: hasCoords ? AppColors.primary : AppColors.getTextSecondary(context),
                      fontWeight: hasCoords ? FontWeight.bold : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
