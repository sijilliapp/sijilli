import 'package:flutter/material.dart';
import 'package:sijilli/core/constants/app_colors.dart';
import 'package:sijilli/models/appointment.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';
import 'package:sijilli/features/articles/screens/article_details_screen.dart';
import 'package:sijilli/features/articles/providers/article_provider.dart';
import 'package:sijilli/features/auth/providers/auth_provider.dart';
import 'package:sijilli/features/appointments/providers/appointment_provider.dart';
import 'package:provider/provider.dart';

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
        _buildSimpleDetailRow(context, context.l10n.detailsSunset, sunsetTime ?? '...'),
        _buildSimpleDetailRow(context, context.l10n.detailsDuration, durationText ?? '...'),
        
        const SizedBox(height: 12),

        // 1. General Note (Description)
        if ((appointment.description != null && appointment.description!.isNotEmpty) || isHost)
          _buildNoteBanner(
            context,
            label: context.l10n.detailsGeneralNoteLabel, 
            value: appointment.description,
            fallbackValue: isHost ? context.l10n.detailsGeneralNoteAdd : context.l10n.detailsGeneralNoteNone,
            icon: Icons.notes_rounded,
            isEditable: isHost, 
            onEdit: () => onEdit('description', appointment.description),
          ),

        // 2. Personal Note (Private)
        _buildNoteBanner(
          context,
          label: context.l10n.detailsPersonalNoteLabel, 
          value: appointment.currentUserInvitation?.personalNote,
          fallbackValue: context.l10n.detailsPersonalNoteAdd,
          icon: Icons.lock_outline_rounded,
          isEditable: true, 
          onEdit: () => onEdit('personalNote', appointment.currentUserInvitation?.personalNote),
        ),
        
        // 3. Link
        if ((appointment.streamLink != null && appointment.streamLink!.isNotEmpty) || isHost)
          _buildNoteBanner(
            context,
            label: context.l10n.detailsLinkLabel, 
            value: appointment.streamLink,
            fallbackValue: isHost ? context.l10n.detailsLinkAdd : context.l10n.detailsLinkNone,
            icon: Icons.videocam_outlined,
            isEditable: isHost, 
            isLink: true,
            onEdit: () => onEdit('streamLink', appointment.streamLink),
          ),

        // 4. Linked Article (For the current user's invitation)
        _buildLinkedArticleBanner(context),
      ],
    );
  }

  Widget _buildNoteBanner(BuildContext context, {
    required String label, 
    String? value, 
    required String fallbackValue,
    required IconData icon,
    bool isEditable = false, 
    bool isLink = false, 
    VoidCallback? onEdit
  }) {
    final hasValue = value != null && value.isNotEmpty;
    final displayValue = hasValue ? value : fallbackValue;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        onTap: isLink && hasValue ? () => launchUrlString(value!) : (isEditable ? onEdit : null),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.getCardBackground(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.getBorder(context)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: hasValue ? AppColors.primary : Colors.grey),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.replaceAll(':', ''), // Remove trailing colon if exists
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.getTextSecondary(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      displayValue,
                      style: TextStyle(
                        color: hasValue 
                            ? (isLink ? AppColors.primary : AppColors.getTextPrimary(context)) 
                            : Colors.grey, 
                        fontSize: 14, 
                        fontWeight: hasValue ? FontWeight.w500 : FontWeight.normal,
                        decoration: isLink && hasValue ? TextDecoration.underline : null,
                        decorationColor: isLink && hasValue ? AppColors.primary : null,
                      ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isEditable && onEdit != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: InkWell(
                    onTap: onEdit,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.edit, size: 14, color: AppColors.primary),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLinkedArticleBanner(BuildContext context) {
    final article = appointment.currentUserInvitation?.linkedArticle;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        onTap: () {
          if (article != null) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ArticleDetailsScreen(article: article)),
            );
          } else {
            _showArticleSelectionSheet(context);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: article != null ? AppColors.primary.withValues(alpha: 0.08) : AppColors.getCardBackground(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: article != null ? AppColors.primary.withValues(alpha: 0.3) : AppColors.getBorder(context)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.article_rounded, size: 20, color: article != null ? AppColors.primary : Colors.grey),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'المقال المرتبط بـك',
                      style: TextStyle(
                        fontSize: 12,
                        color: article != null ? AppColors.primary.withValues(alpha: 0.7) : AppColors.getTextSecondary(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      article != null 
                          ? (article.title.isNotEmpty ? article.title : 'بدون عنوان') 
                          : 'اضغط لربط مقال من مقالاتك بمشاركتك',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: article != null ? FontWeight.w600 : FontWeight.normal,
                        color: article != null ? AppColors.primary : Colors.grey,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (article != null && !article.isPublished)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('غير منشور', style: TextStyle(fontSize: 10, color: AppColors.warning, fontWeight: FontWeight.bold)),
                ),
              Icon(
                article != null ? Icons.arrow_forward_ios_rounded : Icons.add_link_rounded, 
                size: 16, 
                color: article != null ? AppColors.primary : Colors.grey
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showArticleSelectionSheet(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final userId = auth.user?.id ?? '';
    final articleProvider = context.read<ArticleProvider>();

    // Fetch articles to ensure the list is populated
    articleProvider.fetchUserArticles(userId, refresh: true, isCurrentUser: true);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.6,
          decoration: BoxDecoration(
            color: AppColors.getCardBackground(ctx),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              const Text('اختر مقالاً لربطه بمشاركتك', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Expanded(
                child: Consumer<ArticleProvider>(
                  builder: (context, provider, child) {
                    final myArticles = provider.getUserArticles(userId);
                    
                    if (provider.isLoading && myArticles.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (myArticles.isEmpty) {
                      return const Center(child: Text('لا توجد مقالات لديك'));
                    }

                    return ListView.builder(
                      itemCount: myArticles.length,
                      itemBuilder: (context, index) {
                        final a = myArticles[index];
                        return ListTile(
                          leading: const Icon(Icons.article_outlined, color: AppColors.primary),
                          title: Text(a.title.isNotEmpty ? a.title : 'بدون عنوان', maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: !a.isPublished 
                              ? const Text('غير منشور', style: TextStyle(color: AppColors.warning, fontSize: 12)) 
                              : null,
                          onTap: () async {
                            Navigator.pop(ctx);
                            try {
                              await context.read<AppointmentProvider>().updateInvitationSettings(
                                appointment.id,
                                linkedArticleId: a.id,
                                linkedArticle: a,
                              );
                            } catch (e) {
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('فشل الربط: $e')));
                              }
                            }
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSimpleDetailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label, 
              style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: AppColors.getTextPrimary(context), 
                fontSize: 14, 
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
