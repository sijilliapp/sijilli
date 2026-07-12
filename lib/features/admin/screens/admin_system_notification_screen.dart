// 📍 lib/features/admin/screens/admin_system_notification_screen.dart
// 🛡️ شاشة إرسال وبث إشعارات النظام الجماعية للفئات المستهدفة

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../models/user.dart';
import '../../auth/services/pb_role_service.dart';
import '../providers/admin_provider.dart';
import '../../../core/providers/broadcast_provider.dart';
import '../../../core/utils/app_pickers.dart';

class AdminSystemNotificationScreen extends StatefulWidget {
  const AdminSystemNotificationScreen({super.key});

  @override
  State<AdminSystemNotificationScreen> createState() => _AdminSystemNotificationScreenState();
}

class _AdminSystemNotificationScreenState extends State<AdminSystemNotificationScreen> {
  // Target roles state
  final Set<String> _selectedRoles = {};
  List<UserRoleMetadata> _roles = [];
  bool _isLoadingRoles = true;

  // Nerve Tapping Game form controllers
  late final TextEditingController _nerveTitleController;
  late final TextEditingController _nerveMessageController;

  // Group Event form controllers
  late final TextEditingController _eventTitleController;
  late final TextEditingController _eventContentController;
  DateTime? _eventExpiryDateTime;

  // Group Article form controllers
  late final TextEditingController _articleTitleController;
  late final TextEditingController _articleContentController;

  final PbRoleService _roleService = PbRoleService();

  @override
  void initState() {
    super.initState();
    _nerveTitleController = TextEditingController(text: 'تحدّي الأعصاب اليومي ⚡');
    _nerveMessageController = TextEditingController(
      text: 'اضغط 10 مرات متتالية بأسرع ما يمكن وسجل نتيجتك في قائمة التحدي اليومية!',
    );
    _eventTitleController = TextEditingController(text: 'تحذير للصيانة ⚠️');
    _eventContentController = TextEditingController(
      text: 'سيقوم فريق سجلي بتحليل البيانات وتخزين نسخة احتياطية من قاعدة البيانات.',
    );
    _articleTitleController = TextEditingController(text: 'بيان رسمي جديد 📢');
    _articleContentController = TextEditingController(
      text: 'يسرنا إعلان تحديثات هامة في نظام المواعيد والنشرات العامة لتسهيل استخدام التطبيق.',
    );
    _loadRoles();
  }

  @override
  void dispose() {
    _nerveTitleController.dispose();
    _nerveMessageController.dispose();
    _eventTitleController.dispose();
    _eventContentController.dispose();
    _articleTitleController.dispose();
    _articleContentController.dispose();
    super.dispose();
  }

  Future<void> _loadRoles() async {
    // 1. محاولة التحميل من الكاش المحلي أولاً لعرض الواجهة فوراً
    final cached = await _roleService.getCachedUserRoles();
    if (cached.isNotEmpty) {
      setState(() {
        _roles = cached;
        _isLoadingRoles = false;
        // تفعيل كافة الأدوار افتراضياً
        for (var role in cached) {
          _selectedRoles.add(role.key);
        }
      });
    }

    // 2. الاستعلام من خادم PocketBase لجلب أحدث الفئات
    final fresh = await _roleService.fetchAndCacheUserRoles();
    if (mounted && fresh.isNotEmpty) {
      setState(() {
        _roles = fresh;
        _isLoadingRoles = false;
        // إذا كان الكاش فارغاً، نحدد الكل افتراضياً
        if (cached.isEmpty) {
          _selectedRoles.clear();
          for (var role in fresh) {
            _selectedRoles.add(role.key);
          }
        }
      });
    } else if (mounted && _roles.isEmpty) {
      // احتياطي طوارئ (Fallback) في حال فشل الاتصال ولم يكن هناك كاش
      final fallbackRoles = [
        const UserRoleMetadata(key: 'user', displayNameAr: 'مستخدم', displayNameEn: 'User', permissions: {}),
        const UserRoleMetadata(key: 'writer', displayNameAr: 'كاتب', displayNameEn: 'Writer', permissions: {}),
        const UserRoleMetadata(key: 'admin', displayNameAr: 'مشرف', displayNameEn: 'Admin', permissions: {}),
        const UserRoleMetadata(key: 'organization', displayNameAr: 'مؤسسة', displayNameEn: 'Organization', permissions: {}),
      ];
      setState(() {
        _roles = fallbackRoles;
        _isLoadingRoles = false;
        for (var role in fallbackRoles) {
          _selectedRoles.add(role.key);
        }
      });
    }
  }

  void _toggleRole(String role, bool selected) {
    setState(() {
      if (selected) {
        _selectedRoles.add(role);
      } else {
        if (_selectedRoles.length > 1) {
          _selectedRoles.remove(role);
        } else {
          // منع إلغاء تحديد كافة الفئات
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('الرجاء اختيار جهة مستهدفة واحدة على الأقل')),
          );
        }
      }
    });
  }

  Future<void> _sendNotification({
    required String title,
    required String message,
    String? relatedId,
  }) async {
    if (title.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال العنوان ونص الرسالة')),
      );
      return;
    }

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (loadingContext) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    final success = await context.read<AdminProvider>().sendSystemNotificationToAll(
          title: title,
          message: message,
          relatedId: relatedId,
          targetRoles: _selectedRoles.toList(),
        );

    if (mounted) {
      Navigator.pop(context); // Close loading dialog
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success 
              ? 'تم إرسال الإشعار للفئات المحددة بنجاح' 
              : 'فشل إرسال الإشعار'),
          backgroundColor: success ? AppColors.success : Colors.red,
        ),
      );

      if (success) {
        Navigator.pop(context); // Go back on success
      }
    }
  }

  Future<void> _selectExpiryDateTime() async {
    final now = DateTime.now();
    final pickedDate = await AppPickers.showStyledDatePicker(
      context: context,
      initialDate: _eventExpiryDateTime ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );

    if (pickedDate != null && mounted) {
      final pickedTime = await AppPickers.showStyledTimePicker(
        context,
        initialTime: _eventExpiryDateTime != null 
            ? TimeOfDay.fromDateTime(_eventExpiryDateTime!)
            : TimeOfDay.now(),
      );

      if (pickedTime != null && mounted) {
        setState(() {
          _eventExpiryDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  Future<void> _sendBroadcast({
    required String title,
    required String content,
    required String type,
    DateTime? expiresAt,
  }) async {
    if (title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال العنوان والمحتوى')),
      );
      return;
    }

    if (type == 'event' && expiresAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء تحديد وقت وتاريخ انتهاء الصلاحية للحدث')),
      );
      return;
    }

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (loadingContext) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    final success = await context.read<BroadcastProvider>().createBroadcast(
          title: title,
          content: content,
          type: type,
          expiresAt: expiresAt,
          targetRoles: _selectedRoles.toList(),
        );

    if (mounted) {
      Navigator.pop(context); // Close loading dialog
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success 
              ? 'تم نشر البث الجماعي بنجاح 📣' 
              : 'فشل إرسال البث'),
          backgroundColor: success ? AppColors.success : Colors.red,
        ),
      );

      if (success) {
        if (type == 'event') {
          setState(() {
            _eventExpiryDateTime = null;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('بث إشعار للنظام', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimens.space),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Target Recipients Header Card
              _buildTargetSelectorCard(isDark),
              
              const SizedBox(height: AppDimens.space),

              // 2. Sections Label
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Text(
                  'خيارات البث المتاحة والمستقبلية:',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ),

              const SizedBox(height: 8),

              // 3. Option 1: Daily Nerve Tapping Game Form
              _buildNerveGameCard(isDark),

              const SizedBox(height: AppDimens.spaceXS),

              // 4. Option 2: Group Event (Active 🗓️)
              _buildGroupEventCard(isDark),

              const SizedBox(height: AppDimens.spaceXS),

              // 5. Option 3: Group Article (Active 📰)
              _buildGroupArticleCard(isDark),

              const SizedBox(height: AppDimens.space),

              // 6. Active Broadcasts Manager
              _buildActiveBroadcastsCard(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTargetSelectorCard(bool isDark) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.people_alt_outlined, color: AppColors.primary, size: 20),
                SizedBox(width: 8),
                Text(
                  'اختيار الجهات المستهدفة بالرسالة الجماعية:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isLoadingRoles && _roles.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _roles.map((role) {
                  final key = role.key;
                  final label = role.displayNameAr.isNotEmpty ? role.displayNameAr : role.key;
                  final isSelected = _selectedRoles.contains(key);

                  return FilterChip(
                    label: Text(
                      label,
                      style: TextStyle(
                        color: isSelected ? Colors.white : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (val) => _toggleRole(key, val),
                    selectedColor: AppColors.primary,
                    checkmarkColor: Colors.white,
                    backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  );
                }).toList(),
              ),
            const SizedBox(height: 8),
            Text(
              'سيتم تصفية وبث الإشعار حصراً للمستخدمين الذين يحملون الأدوار المحددة أعلاه من جدول الفئات.',
              style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNerveGameCard(bool isDark) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          leading: const Icon(Icons.flash_on, color: Colors.amber),
          title: const Text(
            'لعبة النقر السريع',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          subtitle: const Text('إطلاق وتفعيل جولة تحدي النقر اليومي وتنبيه المستخدمين'),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nerveTitleController,
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(
                      labelText: 'عنوان الإشعار',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nerveMessageController,
                    maxLines: 3,
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(
                      labelText: 'نص الرسالة',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _sendNotification(
                      title: _nerveTitleController.text.trim(),
                      message: _nerveMessageController.text.trim(),
                      relatedId: 'game_nerve',
                    ),
                    icon: const Icon(Icons.send_rounded, size: 16),
                    label: const Text('إرسال وبدء التحدي ⚡'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupEventCard(bool isDark) {
    final format = DateFormat('yyyy-MM-dd hh:mm a');
    final formattedDate = _eventExpiryDateTime != null 
        ? format.format(_eventExpiryDateTime!)
        : 'لم يتم التحديد';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          leading: const Icon(Icons.event_available, color: Colors.blue),
          title: const Text(
            'حدث جماعي (نشط 🗓️)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          subtitle: const Text('بث تنبيه أو حدث ديني/اجتماعي هام لجميع المشتركين يظهر أعلى المواعيد'),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _eventTitleController,
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(
                      labelText: 'عنوان الحدث / التنبيه',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _eventContentController,
                    maxLines: 3,
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(
                      labelText: 'تفاصيل الحدث',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: _selectExpiryDateTime,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'تاريخ ووقت انتهاء الحدث (يختفي بعد انقضائه)',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        formattedDate,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _sendBroadcast(
                      title: _eventTitleController.text.trim(),
                      content: _eventContentController.text.trim(),
                      type: 'event',
                      expiresAt: _eventExpiryDateTime,
                    ),
                    icon: const Icon(Icons.campaign, size: 18),
                    label: const Text('بث ونشر الحدث 📣'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupArticleCard(bool isDark) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          leading: const Icon(Icons.menu_book, color: Colors.green),
          title: const Text(
            'مقال جماعي (نشط 📰)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          subtitle: const Text('نشر بيان رسمي أو توجيهات للمشتركين تظهر في صفحة مقالات النظام'),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _articleTitleController,
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(
                      labelText: 'عنوان البيان / المقال',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _articleContentController,
                    maxLines: 4,
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(
                      labelText: 'محتوى البيان / المقال',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _sendBroadcast(
                      title: _articleTitleController.text.trim(),
                      content: _articleContentController.text.trim(),
                      type: 'article',
                    ),
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('نشر وبث البيان 📰'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveBroadcastsCard(bool isDark) {
    return Consumer<BroadcastProvider>(
      builder: (context, provider, _) {
        final allBroadcasts = provider.broadcasts;
        if (allBroadcasts.isEmpty) return const SizedBox.shrink();

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: false,
              leading: const Icon(Icons.list_alt, color: Colors.blueGrey),
              title: const Text(
                'إدارة النشرات النشطة حالياً',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              subtitle: Text('عرض النشرات والبيانات وحذفها (${allBroadcasts.length})'),
              children: [
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: allBroadcasts.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final b = allBroadcasts[index];
                    final isEvent = b.type == 'event';
                    final dateLabel = b.expiresAt != null 
                        ? 'ينتهي: ${DateFormat('MM-dd hh:mm a').format(b.expiresAt!)}'
                        : 'لا ينتهي';

                    return ListTile(
                      title: Text(
                        b.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      subtitle: Text(
                        'نوع: ${isEvent ? 'حدث' : 'مقال'} • $dateLabel\n${b.content}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              title: const Text('حذف البث'),
                              content: Text('هل أنت متأكد من رغبتك في حذف بـث "${b.title}" نهائياً من النظام؟'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogContext, false),
                                  child: const Text('إلغاء'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogContext, true),
                                  child: const Text('حذف', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await provider.deleteBroadcast(b.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('تم حذف البث بنجاح')),
                              );
                            }
                          }
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
