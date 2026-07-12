import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/providers/broadcast_provider.dart';
import '../../../models/broadcast.dart';
import '../../auth/providers/auth_provider.dart';

class SystemArticlesScreen extends StatefulWidget {
  const SystemArticlesScreen({super.key});

  @override
  State<SystemArticlesScreen> createState() => _SystemArticlesScreenState();
}

class _SystemArticlesScreenState extends State<SystemArticlesScreen> {
  String _formatArabicDateTime(DateTime dt) {
    final hourVal = dt.hour == 12 ? 12 : dt.hour % 12;
    final hourStr = hourVal == 0 ? '12' : hourVal.toString();
    final minuteStr = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'مساءً' : 'صباحاً';
    
    final day = dt.day.toString();
    final year = dt.year.toString();
    
    const months = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
    final monthName = months[dt.month - 1];
    
    String toArabicDigits(String input) {
      const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
      const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
      var result = input;
      for (int i = 0; i < english.length; i++) {
        result = result.replaceAll(english[i], arabic[i]);
      }
      return result;
    }
    
    final timePart = toArabicDigits('$hourStr:$minuteStr');
    final datePart = toArabicDigits(day) + ' ' + monthName + ' ' + toArabicDigits(year);
    
    return '$timePart $period $datePart';
  }

  void _showArticleDetails(BuildContext context, Broadcast article) {
    // Mark as read immediately when viewed
    context.read<BroadcastProvider>().markAsRead(article.id);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
            title: Row(
              children: [
                const Icon(Icons.campaign, color: AppColors.primary, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    article.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatArabicDateTime(article.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    article.content,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: isDark ? Colors.grey.shade200 : Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إغلاق', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('مقالات ونشرات النظام', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Consumer<BroadcastProvider>(
          builder: (context, provider, _) {
            final articles = provider.getFilteredBroadcasts(user?.role, type: 'article');

            if (provider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (articles.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimens.space),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.campaign_outlined,
                        size: 64,
                        color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'لا توجد نشرات أو مقالات عامة حالياً.',
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(AppDimens.spaceXS),
              itemCount: articles.length,
              itemBuilder: (context, index) {
                final a = articles[index];
                final isUnread = !provider.readBroadcastIds.contains(a.id);

                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isUnread 
                          ? AppColors.primary.withValues(alpha: 0.5)
                          : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                      width: isUnread ? 1.5 : 1.0,
                    ),
                  ),
                  color: isUnread
                      ? (isDark ? AppColors.primary.withValues(alpha: 0.1) : AppColors.primary.withValues(alpha: 0.05))
                      : (isDark ? AppColors.darkCardBackground : Colors.white),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isUnread 
                            ? AppColors.primary.withValues(alpha: 0.2)
                            : (isDark ? Colors.grey.shade800 : Colors.grey.shade100),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.campaign, 
                        color: isUnread ? AppColors.primary : Colors.grey.shade500,
                        size: 24,
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            a.title,
                            style: TextStyle(
                              fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isUnread)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          a.content,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formatArabicDateTime(a.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                    onTap: () => _showArticleDetails(context, a),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
