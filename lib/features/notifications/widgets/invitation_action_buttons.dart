import 'package:flutter/material.dart';
import '../../../models/appointment.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/context_l10n.dart';

class InvitationActionButtons extends StatelessWidget {
  final Appointment appointment;
  final InvitationStatus status;
  final String? invitationId;
  final bool isAccepting;
  final bool isRejecting;
  final ValueChanged<InvitationStatus> onResponse;

  const InvitationActionButtons({
    super.key,
    required this.appointment,
    required this.status,
    this.invitationId,
    required this.isAccepting,
    required this.isRejecting,
    required this.onResponse,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inv = appointment.currentUserInvitation;
    final bool isFCFSCancelled = (appointment.isFirstComeFirstServed && appointment.isConfirmed && status != InvitationStatus.accepted) ||
                                (status == InvitationStatus.declined && 
                                 (inv?.personalNote?.contains(context.l10n.priorityFeature) == true || 
                                  inv?.personalNote?.contains('FCFS') == true ||
                                  inv?.personalNote?.contains('cancelled') == true ||
                                  inv?.personalNote?.contains('الأسبقية') == true ||
                                  inv?.personalNote?.contains('الأسرع') == true));

    // 1. إذا تم الرد مسبقاً (الأولوية لتاريخ المستخدم)
    if (status == InvitationStatus.accepted) {
      return _buildFullWidthButton(context, context.l10n.accepted, AppColors.primary);
    }
    if (status == InvitationStatus.declined) {
      return _buildFullWidthButton(context, context.l10n.declined, Colors.red.shade400);
    }

    // 2. حالة الموعد الملغى أو المحذوف (من قبل المضيف) أو الضيف المحذوف
    if (appointment.isDeleted || 
        appointment.isCancelled || 
        inv?.postStatus == PostStatus.trash) {
      return _buildFullWidthButton(context, context.l10n.appointmentCancelled, Colors.grey.shade600);
    }

    // 3. حالة الأسبقية (إذا تم حجز الموعد من قبل شخص آخر)
    if (isFCFSCancelled) {
      return _buildFullWidthButton(context, context.l10n.appointmentCancelled, Colors.grey.shade600);
    }

    // 4. حالة الموعد الفائت (فقط إذا لم يتم الرد بعد)
    // يبقى الرد متاحاً حتى نهاية وقت الموعد
    final endAt = appointment.startAt.toLocal().add(Duration(minutes: appointment.duration));
    final isPast = endAt.isBefore(DateTime.now());
    
    if (isPast) {
      return _buildFullWidthButton(context, context.l10n.pastStatus, Colors.grey);
    }

    // 4. الأزرار التفاعلية (Pending + Active)
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: (isAccepting || isRejecting || invitationId == null)
                ? null
                : () => onResponse(InvitationStatus.accepted),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: isAccepting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Text(context.l10n.confirm, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton(
            onPressed: (isAccepting || isRejecting || invitationId == null)
                ? null
                : () => onResponse(InvitationStatus.declined),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              side: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
            ),
            child: isRejecting
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.grey.shade400, strokeWidth: 2),
                  )
                : Text(context.l10n.delete, style: TextStyle(color: isDark ? Colors.grey.shade300 : Colors.grey.shade600, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildFullWidthButton(BuildContext context, String label, Color color) {
    // If it's a 'frozen' label, use a greyish background
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isFrozen = color == Colors.grey.shade600 || color == Colors.grey;
    
    final bgColor = isFrozen 
        ? (isDark ? Colors.grey.shade800 : Colors.grey.shade100) 
        : color.withValues(alpha: 0.1);
        
    final borderColor = isFrozen 
        ? (isDark ? Colors.grey.shade600 : Colors.grey.shade300) 
        : color.withValues(alpha: 0.3);
        
    final textColor = isFrozen 
        ? (isDark ? Colors.grey.shade400 : Colors.grey.shade700) 
        : color;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
