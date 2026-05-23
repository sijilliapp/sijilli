// 📍 lib/features/admin/screens/admin_messages_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/app_date_formatter.dart';
import '../providers/admin_provider.dart';
import '../../../models/contact_message.dart';
import '../widgets/message_detail_sheet.dart';

class AdminMessagesScreen extends StatefulWidget {
  const AdminMessagesScreen({super.key});

  @override
  State<AdminMessagesScreen> createState() => _AdminMessagesScreenState();
}

class _AdminMessagesScreenState extends State<AdminMessagesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedType = 'all'; // all, inquiry, complaint, suggestion, other
  final List<String> _statusFilters = ['all', 'new', 'read', 'replied', 'closed'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _statusFilters.length, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // لتحديث الواجهة وتطبيق الفرز عند تغيير التبويب
    });
    
    // جلب الرسائل من السيرفر فور الدخول
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().fetchContactMessages();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'مراسلات الدعم الفني',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'الكل'),
            Tab(text: 'جديدة 🆕'),
            Tab(text: 'مقروءة'),
            Tab(text: 'تم الرد عليها'),
            Tab(text: 'مغلقة'),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 🔎 شريط الفرز بحسب النوع
            _buildTypeFilterRow(isDark),
            
            // 📜 قائمة الرسائل المفلترة
            Expanded(
              child: Consumer<AdminProvider>(
                builder: (context, admin, child) {
                  if (admin.isFetchingMessages && admin.messages.isEmpty) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  // تطبيق الفلاتر
                  final filteredMessages = admin.messages.where((m) {
                    final statusFilter = _statusFilters[_tabController.index];
                    final matchesStatus = statusFilter == 'all' || m.status == statusFilter;
                    final matchesType = _selectedType == 'all' || m.type == _selectedType;
                    return matchesStatus && matchesType;
                  }).toList();

                  if (filteredMessages.isEmpty) {
                    return _buildEmptyState(isDark);
                  }

                  return RefreshIndicator(
                    onRefresh: () => admin.fetchContactMessages(),
                    color: AppColors.primary,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredMessages.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final msg = filteredMessages[index];
                        return _buildMessageCard(context, msg, isDark);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeFilterRow(bool isDark) {
    final types = [
      {'key': 'all', 'label': 'الكل'},
      {'key': 'inquiry', 'label': 'استفسار'},
      {'key': 'suggestion', 'label': 'اقتراح'},
      {'key': 'complaint', 'label': 'شكوى'},
      {'key': 'other', 'label': 'أخرى'},
    ];

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: types.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final type = types[index];
          final isSelected = _selectedType == type['key'];
          return ChoiceChip(
            label: Text(
              type['label']!,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
              ),
            ),
            selected: isSelected,
            selectedColor: AppColors.primary,
            backgroundColor: isDark ? AppColors.darkSurface : Colors.grey.shade100,
            checkmarkColor: Colors.white,
            onSelected: (val) {
              if (val) {
                setState(() {
                  _selectedType = type['key']!;
                });
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildMessageCard(BuildContext context, ContactMessageModel msg, bool isDark) {
    final hasUser = msg.user != null;
    final senderName = hasUser ? msg.user!.name : 'زائر غير مسجل';
    
    // الألوان والأيقونات الخاصة بنوع الرسالة
    Color typeColor;
    String typeLabel;
    switch (msg.type) {
      case 'suggestion':
        typeColor = Colors.green;
        typeLabel = 'اقتراح';
        break;
      case 'complaint':
        typeColor = Colors.red;
        typeLabel = 'شكوى';
        break;
      case 'inquiry':
        typeColor = Colors.blue;
        typeLabel = 'استفسار';
        break;
      default:
        typeColor = Colors.orange;
        typeLabel = 'أخرى';
    }

    // الألوان الخاصة بحالة الرسالة
    Color statusBgColor;
    Color statusTextColor;
    String statusLabel;
    switch (msg.status) {
      case 'new':
        statusBgColor = Colors.amber.shade800.withValues(alpha: 0.15);
        statusTextColor = Colors.amber.shade900;
        statusLabel = 'جديدة';
        break;
      case 'read':
        statusBgColor = Colors.blueGrey.shade100.withValues(alpha: 0.3);
        statusTextColor = Colors.blueGrey.shade700;
        statusLabel = 'مقروءة';
        break;
      case 'replied':
        statusBgColor = Colors.teal.shade50;
        statusTextColor = Colors.teal.shade800;
        statusLabel = 'تم الرد';
        break;
      case 'closed':
        statusBgColor = Colors.grey.shade200;
        statusTextColor = Colors.grey.shade600;
        statusLabel = 'مغلقة';
        break;
      default:
        statusBgColor = Colors.grey.shade100;
        statusTextColor = Colors.grey.shade700;
        statusLabel = msg.status;
    }

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          width: 1,
        ),
      ),
      color: isDark ? AppColors.darkSurface : Colors.white,
      child: InkWell(
        onTap: () {
          // فتح تفاصيل الرسالة
          showMessageDetailSheet(context, msg);
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🏷️ نوع الرسالة وحالتها في الأعلى
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: typeColor.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      typeLabel,
                      style: TextStyle(
                        color: typeColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusBgColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusTextColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // 📌 عنوان الرسالة
              Text(
                msg.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              
              const SizedBox(height: 6),
              
              // 💬 مقتطف من محتوى الرسالة
              Text(
                msg.message,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              
              const SizedBox(height: 12),
              
              const Divider(height: 1),
              
              const SizedBox(height: 8),
              
              // 👤 المرسل والتاريخ
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline_rounded,
                        size: 16,
                        color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        senderName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    AppDateFormatter.timeAgo(msg.created, 'ar'),
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mark_email_read_outlined,
              size: 70,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'صندوق الوارد نظيف تماماً!',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'لا توجد رسائل واردة تطابق الفلاتر المحددة حالياً.',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
