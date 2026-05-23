import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sijilli/core/constants/app_colors.dart';
import 'package:sijilli/core/constants/app_dimens.dart';
import 'package:sijilli/models/appointment.dart';
import 'package:sijilli/features/profile/providers/moderation_provider.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';
import 'package:sijilli/features/add/screens/add_event_screen.dart';
import 'package:sijilli/features/appointments/providers/appointment_provider.dart';
import 'package:sijilli/features/auth/providers/auth_provider.dart';
import 'package:sijilli/features/articles/screens/article_details_screen.dart';

class PublicAppointmentDetailsSheet extends StatelessWidget {
  final Appointment appointment;

  const PublicAppointmentDetailsSheet({super.key, required this.appointment});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final isAdmin = auth.user?.isAdmin ?? false;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.getCardBackground(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppDimens.radiusXXL)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min, // This makes it shrink-wrap its content
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.getBorder(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(AppDimens.padding, 0, AppDimens.padding, 12),
              child: Column(
                children: [
                  // Clone Button
                  _buildLongActionButton(
                    context: context,
                    icon: Icons.copy_rounded,
                    label: context.l10n.detailsClone,
                    color: AppColors.primary,
                    onTap: () => _handleClone(context),
                  ),

                  // Linked Article Button (Only if published)
                  if (appointment.linkedArticle != null && appointment.linkedArticle!.isPublished)
                    _buildLongActionButton(
                      context: context,
                      icon: Icons.article_rounded,
                      label: 'موضوع مرتبط',
                      color: AppColors.primary,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => ArticleDetailsScreen(article: appointment.linkedArticle!)),
                        );
                      },
                    ),

                  // Save (Sync) Button
                  Builder(
                    builder: (context) {
                      final isBookmarked = appointment.currentUserInvitation?.postStatus == PostStatus.bookmarked;
                      return _buildLongActionButton(
                        context: context,
                        icon: isBookmarked ? Icons.bookmark_added_rounded : Icons.bookmark_border_rounded,
                        label: isBookmarked ? 'إلغاء الحفظ' : context.l10n.save,
                        color: AppColors.primary,
                        onTap: () => _handleSave(context),
                      );
                    },
                  ),

                  // Report Button (Red with Flag Icon)
                  _buildLongActionButton(
                    context: context,
                    icon: Icons.flag_rounded,
                    label: context.l10n.report,
                    color: Colors.red,
                    onTap: () => _handleReport(context),
                  ),

                  if (isAdmin) ...[
                    const SizedBox(height: 4),
                    _buildLongActionButton(
                      context: context,
                      icon: Icons.delete_forever_rounded,
                      label: context.l10n.detailsDeleteTitleHost, // "إلغاء الموعد نهائياً"
                      color: Colors.redAccent,
                      onTap: () => _handleDelete(context),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSave(BuildContext context) async {
    final appointmentProvider = context.read<AppointmentProvider>();
    final auth = context.read<AuthProvider>();

    if (auth.user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.pleaseLoginFirst)),
      );
      return;
    }

    // Pop immediately as requested
    Navigator.pop(context);

    try {
      final success = await appointmentProvider.toggleBookmark(appointment, auth.user!);
      
      // Show success popup only if it actually worked
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'تم الحفظ في المحفوظات' : 'تمت الإزالة من المحفوظات'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        // More descriptive error for the developer user
        String errorMsg = context.l10n.errorOccurred;
        if (e.toString().contains('bookmarked')) {
          errorMsg = 'خطأ: يرجى إضافة "bookmarked" لخيارات post_status في PocketBase';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _handleClone(BuildContext context) {
    final stripped = Appointment(
      id: '',
      title: appointment.title,
      hostId: '', 
      startAt: appointment.startAt,
      date: appointment.date,
      time: appointment.time,
      dateType: appointment.dateType,
      hijriDate: appointment.hijriDate,
      hijriMonth: appointment.hijriMonth,
      duration: appointment.duration,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEventScreen(initialAppointment: stripped),
      ),
    );
  }

  Widget _buildLongActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 4),
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 22),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.1),
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 18),
          elevation: 0,
          alignment: Alignment.center,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: color.withValues(alpha: 0.2)),
          ),
        ),
      ),
    );
  }

  Future<void> _handleReport(BuildContext context) async {
    final moderation = context.read<ModerationProvider>();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: Text(context.l10n.reportAppointment),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(hintText: context.l10n.reportReason),
            maxLines: 3,
            autofocus: true,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.cancel)),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text), 
              child: Text(context.l10n.send),
            ),
          ],
        );
      },
    );

    if (reason != null && reason.isNotEmpty) {
      await moderation.reportContent(
        subjectType: 'appointment',
        subjectId: appointment.id,
        reason: reason,
      );
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.reportSent), backgroundColor: AppColors.success)
        );
      }
    }
  }

  Future<void> _handleDelete(BuildContext context) async {
    final appointmentProvider = context.read<AppointmentProvider>();

    final bool? confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.detailsDeleteTitleHost),
        content: Text(context.l10n.detailsDeleteConfirmHost),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.detailsUndo),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10n.detailsCancelAppointment),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (context.mounted) Navigator.pop(context);
      try {
        await appointmentProvider.deleteInvitation(appointment.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.appointmentCancelled),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.errorOccurred),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }
}
