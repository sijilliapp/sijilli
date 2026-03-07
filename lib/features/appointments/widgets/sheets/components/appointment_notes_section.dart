import 'package:flutter/material.dart';
import 'package:sijilli/core/constants/app_colors.dart';
import 'package:sijilli/models/appointment.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';

class AppointmentNotesSection extends StatelessWidget {
  final Appointment appointment;
  final bool isHost;
  final String? sunsetTime;
  final String? durationText;
  final Function(String field, String? currentValue) onEdit;

  const AppointmentNotesSection({
    super.key,
    required this.appointment,
    required this.isHost,
    this.sunsetTime,
    this.durationText,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildDetailRow(context, context.l10n.detailsSunset, sunsetTime ?? '...'),
        _buildDetailRow(context, context.l10n.detailsDuration, durationText ?? '...'),
        
        // 1. General Note (Description) - Editable by HOST ONLY
        _buildDetailRow(
          context,
          context.l10n.detailsGeneralNoteLabel, 
          (appointment.description != null && appointment.description!.isNotEmpty) 
              ? appointment.description! 
              : (isHost ? context.l10n.detailsGeneralNoteAdd : context.l10n.detailsGeneralNoteNone),
          isEditable: isHost, 
          onEdit: () => onEdit('description', appointment.description),
        ),

        // 2. Personal Note (Private) - Editable by OWNER
        _buildDetailRow(
          context,
          context.l10n.detailsPersonalNoteLabel, 
          (appointment.currentUserInvitation?.personalNote != null && appointment.currentUserInvitation!.personalNote!.isNotEmpty) 
              ? appointment.currentUserInvitation!.personalNote! 
              : context.l10n.detailsPersonalNoteAdd,
          isEditable: true, 
          onEdit: () => onEdit('personalNote', appointment.currentUserInvitation?.personalNote),
        ),
        
        // Link (Editable by HOST ONLY)
        _buildDetailRow(
          context,
          context.l10n.detailsLinkLabel, 
          (appointment.streamLink != null && appointment.streamLink!.isNotEmpty) 
              ? appointment.streamLink! 
              : (isHost ? context.l10n.detailsLinkAdd : context.l10n.detailsLinkNone),
          isEditable: isHost, 
          isLink: appointment.streamLink != null && appointment.streamLink!.isNotEmpty,
          onEdit: () => onEdit('streamLink', appointment.streamLink),
        ),

        // ---------------------------------------------------------
        // [Developer Note]: Add Future Fields Here
        // simply verify if the field is present in Appointment model
        // and call _buildDetailRow(context, 'Label:', value, ...);
        // ---------------------------------------------------------
      ],
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value, {bool isEditable = false, bool isLink = false, VoidCallback? onEdit}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label (Right Side)
          SizedBox(
            width: 100, // Increased to prevent wrapping
            child: Text(
              label, 
              style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 14),
            ),
          ),
          
          // Value (Left Side)
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: isLink ? () => launchUrlString(value) : (isEditable ? onEdit : null),
                    child: Text(
                      value,
                      style: TextStyle(
                        color: isLink ? AppColors.primary : AppColors.getTextPrimary(context), 
                        fontSize: 14, 
                        fontWeight: FontWeight.w500,
                        decoration: isLink ? TextDecoration.underline : null,
                        decorationColor: isLink ? AppColors.primary : null,
                      ),
                      maxLines: 4, // Increased from 2 to 4 for better visibility
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                
                // Edit Icon
                if (isEditable && onEdit != null)
                   Padding(
                     padding: const EdgeInsets.only(right: 8.0),
                     child: InkWell(
                       onTap: onEdit,
                       child: const Icon(Icons.edit, size: 16, color: AppColors.primary),
                     ),
                   ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
