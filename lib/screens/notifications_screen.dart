import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:sijilli/services/auth_service.dart';
import 'package:sijilli/utils/arabic_search_utils.dart';
import 'package:sijilli/screens/user_profile_screen.dart';

import 'package:sijilli/config/constants.dart';
import 'package:sijilli/services/user_appointment_status_service.dart';
import 'package:sijilli/utils/date_converter.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  late TabController _tabController;

  List<NotificationModel> _notifications = [];
  List<VisitorModel> _visitors = [];
  List<NotificationModel> _filteredNotifications = [];
  List<VisitorModel> _filteredVisitors = [];

  bool _isLoading = false;
  String _searchQuery = '';

  // تتبع الدعوات المحدثة محلياً
  final Map<String, String> _localInvitationUpdates = {};
  
  // تتبع حالة التحميل لكل دعوة
  final Map<String, bool> _invitationLoadingStates = {};

  // Timer للبحث المتأخر
  Timer? _searchTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      print('🔄 بداية تحميل البيانات...');
      await _loadNotifications();
      print('🚧 === سجل الزوار: النظام تحت الصيانة ===');
      await _loadVisitors();
      print('✅ تم تحميل البيانات بنجاح');
    } catch (e) {
      print('❌ خطأ في تحميل البيانات: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        print('🏁 انتهاء تحميل البيانات - _isLoading = false');
      }
    }
  }

  Future<void> _loadNotifications() async {
    print('🚀 تحميل الإشعارات مباشرة من قاعدة البيانات');

    try {
      final currentUserId = _authService.currentUser?.id;
      if (currentUserId == null) {
        print('❌ لا يوجد مستخدم مسجل دخول');
        return;
      }

      print('🔍 جلب الدعوات للمستخدم: $currentUserId');

      // جلب الدعوات مع البيانات المرتبطة في استعلام واحد محسن
      final invitationResult = await _authService.pb
          .collection('invitations')
          .getList(
            page: 1,
            perPage: 50, // تحديد عدد الإشعارات لتحسين الأداء
            sort: '-created',
            expand: 'appointment,appointment.host,guest',
            filter:
                'guest = "$currentUserId" || appointment.host = "$currentUserId"',
          );

      final invitationRecords = invitationResult.items;
      print('📊 تم جلب ${invitationRecords.length} دعوة مرتبطة بالمستخدم');

      List<NotificationModel> notifications = [];

      for (final record in invitationRecords) {
        try {
          print('🔍 معالجة دعوة: ${record.id}');

          final guestId = record.data['guest'] as String?;
          final status = record.data['status'] as String?;

          if (guestId == null || status == null) {
            print('❌ بيانات ناقصة في الدعوة ${record.id}');
            continue;
          }

          // استخدام البيانات المحملة مسبقاً من expand
          // الحصول على بيانات الموعد من expand
          final appointmentTitle =
              record.get<String?>('expand.appointment.title') ?? 'موعد';
          final appointmentDate = record.get<String?>(
            'expand.appointment.appointment_date',
          );
          final appointmentDateType = record.get<String?>(
            'expand.appointment.date_type',
          ); // جلب نوع التاريخ
          final appointmentHijriDay = record.get<int?>(
            'expand.appointment.hijri_day',
          );
          final appointmentHijriMonth = record.get<int?>(
            'expand.appointment.hijri_month',
          );
          final appointmentHijriYear = record.get<int?>(
            'expand.appointment.hijri_year',
          );
          final appointmentRegion = record.get<String?>(
            'expand.appointment.region',
          );
          final appointmentBuilding = record.get<String?>(
            'expand.appointment.building',
          );
          final appointmentPrivacy = record.get<String?>(
            'expand.appointment.privacy',
          );
          final appointmentDuration = record.get<int?>(
            'expand.appointment.duration',
          );
          final hostId = record.get<String?>('expand.appointment.host') ?? '';

          // تسجيل بيانات الموعد للتشخيص
          if (appointmentDateType != null) {
            print(
              '📊 بيانات الموعد - العنوان: $appointmentTitle، نوع التاريخ: $appointmentDateType',
            );
          }

          // الحصول على بيانات المضيف من expand
          final hostName =
              record.get<String?>('expand.appointment.expand.host.name') ??
              'مستخدم';
          final hostAvatar =
              record.get<String?>('expand.appointment.expand.host.avatar') ??
              '';

          // الحصول على بيانات الضيف من expand
          final guestName =
              record.get<String?>('expand.guest.name') ?? 'مستخدم';
          final guestAvatar = record.get<String?>('expand.guest.avatar') ?? '';

          // إنشاء الإشعار حسب المستخدم الحالي ونوع الدعوة
          NotificationModel? notification;

          // إنشاء بيانات الدعوة الكاملة
          final appointmentStatus =
              record.get<String?>('expand.appointment.status') ??
              'active'; // افتراضياً active
          print('📋 حالة الموعد: $appointmentStatus');

          // تجاهل الدعوات للمواعيد الملغاة/المحذوفة/المؤرشفة (غير بديهي عرضها)
          if (appointmentStatus == 'deleted' ||
              appointmentStatus == 'cancelled' ||
              appointmentStatus == 'cancelled_by_host' ||
              appointmentStatus == 'archived') {
            print('⚠️ تجاهل دعوة لموعد ملغى/محذوف/مؤرشف: $appointmentTitle');
            continue; // تخطي هذه الدعوة
          }

          final invitationData = {
            'invitation': {
              'id': record.id,
              'appointmentId': record.data['appointment'],
              'guestId': guestId,
              'status': status,
              'privacy': record.data['privacy'],
              'respondedAt': record.data['respondedAt'],
              'created': record.data['created'],
              'updated': record.data['updated'],
            },
            'appointment': {
              'id': record.data['appointment'],
              'title': appointmentTitle,
              'appointmentDate': appointmentDate,
              'date_type': appointmentDateType, // استخدام المتغير المحلي
              'status': appointmentStatus, // حالة الموعد
              'hijri_day': appointmentHijriDay,
              'hijri_month': appointmentHijriMonth,
              'hijri_year': appointmentHijriYear,
              'region': appointmentRegion,
              'building': appointmentBuilding,
              'privacy': appointmentPrivacy,
              'duration': appointmentDuration, // مدة الموعد
              'hostId': hostId,
            },
            'host': {'id': hostId, 'name': hostName, 'avatar': hostAvatar},
            'guest': {'id': guestId, 'name': guestName, 'avatar': guestAvatar},
          };

          if (guestId == currentUserId) {
            // المستخدم الحالي هو الضيف - إظهار الدعوة بجميع حالاتها
            notification = NotificationModel(
              id: 'inv_${record.id}',
              title: 'دعوة موعد',
              message: 'دعاك $hostName لموعد $appointmentTitle',
              type: NotificationType.invitation,
              isRead: false,
              createdAt: DateTime.parse(record.data['created']),
              senderId: hostId,
              senderName: hostName,
              senderAvatar: hostAvatar,
              invitationData: invitationData,
            );

            print(
              '✅ إشعار دعوة للضيف: $hostName -> $appointmentTitle (حالة: $status)',
            );
          } else if (hostId == currentUserId && status != 'invited') {
            // المستخدم الحالي هو المضيف وتم الرد على دعوته
            if (status == 'accepted') {
              notification = NotificationModel(
                id: 'inv_${record.id}',
                title: 'تم قبول الدعوة',
                message: 'وافق $guestName على دعوتك لموعد $appointmentTitle',
                type: NotificationType.acceptance,
                isRead: false,
                createdAt: DateTime.parse(
                  record.data['updated'] ?? record.data['created'],
                ),
                senderId: guestId,
                senderName: guestName,
                senderAvatar: guestAvatar,
                invitationData: invitationData,
              );

              print('✅ إشعار قبول: $guestName -> $appointmentTitle');
            } else if (status == 'rejected') {
              notification = NotificationModel(
                id: 'inv_${record.id}',
                title: 'تم رفض الدعوة',
                message: 'رفض $guestName دعوتك لموعد $appointmentTitle',
                type: NotificationType.rejection,
                isRead: false,
                createdAt: DateTime.parse(
                  record.data['updated'] ?? record.data['created'],
                ),
                senderId: guestId,
                senderName: guestName,
                senderAvatar: guestAvatar,
                invitationData: invitationData,
              );

              print('✅ إشعار رفض: $guestName -> $appointmentTitle');
            }
          }

          if (notification != null) {
            notifications.add(notification);
          }
        } catch (e) {
          print('❌ خطأ في معالجة دعوة ${record.id}: $e');
          continue;
        }
      }

      print('✅ تم إنشاء ${notifications.length} إشعار من قاعدة البيانات');

      if (mounted) {
        setState(() {
          _notifications = notifications;
          _filteredNotifications = List.from(notifications);
        });
      }

      // حفظ البيانات في التخزين المحلي
      await _saveNotificationsToCache(currentUserId, notifications);
    } catch (e) {
      print('❌ خطأ في تحميل الإشعارات: $e');
      if (mounted) {
        setState(() {
          _notifications = [];
          _filteredNotifications = [];
        });
      }
    }
  }

  // حفظ الإشعارات في التخزين المحلي (مع فلترة مسبقة للحالات الملغاة)
  Future<void> _saveNotificationsToCache(
    String userId,
    List<NotificationModel> notifications,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'notifications_$userId';
      final jsonList = notifications
          .map((notification) => notification.toJson())
          .toList();
      await prefs.setString(cacheKey, json.encode(jsonList));
      print('💾 تم حفظ ${notifications.length} إشعار في التخزين المحلي');
    } catch (e) {
      print('❌ خطأ في حفظ البيانات المحلية: $e');
    }
  }

  Future<void> _loadVisitors() async {
    print('🔍 جاري تحميل سجل الزوار...');
    try {
      final currentUserId = _authService.currentUser?.id;
      if (currentUserId == null) {
        print('❌ لا يوجد مستخدم مسجل دخول');
        return;
      }

      // جلب الزيارات من قاعدة البيانات
      final records = await _authService.pb
          .collection(AppConstants.visitsCollection)
          .getFullList(
            filter: 'visited = "$currentUserId"',
            sort: '-created',
            expand: 'visitor',
          );

      print('✅ تم جلب ${records.length} زيارة');

      // تحويل البيانات لـ VisitorModel
      List<VisitorModel> visitors = records.map((record) {
        final visitorData = record.expand['visitor']?.first;

        return VisitorModel(
          id: record.id,
          visitorId: record.data['visitor'] ?? '',
          visitorName: visitorData?.data['name'] ?? 'غير معروف',
          visitorAvatar: visitorData?.data['avatar'] ?? '',
          profileSection: record.data['profile_section'] ?? '',
          visitedAt: DateTime.parse(record.created),
        );
      }).toList();

      if (mounted) {
        setState(() {
          _visitors = visitors;
          _filteredVisitors = List.from(visitors);
        });
      }
    } catch (e) {
      print('❌ خطأ في تحميل الزوار: $e');

      // في حالة الخطأ، عرض قائمة فارغة
      if (mounted) {
        setState(() {
          _visitors = [];
          _filteredVisitors = [];
        });
      }
    }
  }

  // مسح جميع سجلات الزيارة
  Future<void> _clearAllVisits() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('مسح جميع الزيارات'),
        content: const Text('هل أنت متأكد من مسح جميع سجلات الزيارة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('مسح الكل'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final currentUserId = _authService.currentUser?.id;
      if (currentUserId == null) return;

      // حذف جميع الزيارات من قاعدة البيانات
      final records = await _authService.pb
          .collection(AppConstants.visitsCollection)
          .getFullList(filter: 'visited = "$currentUserId"');

      for (final record in records) {
        await _authService.pb
            .collection(AppConstants.visitsCollection)
            .delete(record.id);
      }

      // تحديث الواجهة
      if (mounted) {
        setState(() {
          _visitors.clear();
          _filteredVisitors.clear();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم مسح ${records.length} سجل زيارة'),
            backgroundColor: Colors.green,
          ),
        );
      }

      print('✅ تم مسح ${records.length} سجل زيارة');
    } catch (e) {
      print('❌ خطأ في مسح الزيارات: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('حدث خطأ أثناء مسح الزيارات'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onSearchChanged(String query) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 300), () {
      _filterData(query);
    });
  }

  void _filterData(String query) {
    setState(() {
      _searchQuery = query;

      if (query.isEmpty) {
        _filteredNotifications = List.from(_notifications);
        _filteredVisitors = List.from(_visitors);
      } else {
        _filteredNotifications = _notifications.where((notification) {
          return ArabicSearchUtils.matchesArabicSearch(
                notification.title,
                query,
              ) ||
              ArabicSearchUtils.matchesArabicSearch(
                notification.message,
                query,
              ) ||
              ArabicSearchUtils.matchesArabicSearch(
                notification.senderName,
                query,
              );
        }).toList();

        _filteredVisitors = _visitors.where((visitor) {
          return ArabicSearchUtils.matchesArabicSearch(
                visitor.visitorName,
                query,
              ) ||
              ArabicSearchUtils.matchesArabicSearch(
                visitor.profileSection,
                query,
              );
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'صندوق الوارد',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          // زر مسح الكل - يظهر فقط في تبويب الزيارات
          if (_tabController.index == 1 && _filteredVisitors.isNotEmpty)
            TextButton.icon(
              onPressed: _clearAllVisits,
              icon: const Icon(Icons.delete_sweep, color: Colors.red, size: 20),
              label: const Text(
                'مسح الكل',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          onTap: (index) {
            // تحديث الـ UI عند تغيير التبويب لإظهار/إخفاء زر مسح الكل
            setState(() {});
          },
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: Theme.of(context).primaryColor,
          tabs: [
            Tab(text: 'الإشعارات (${_filteredNotifications.length})'),
            Tab(text: 'سجل الزوار (${_filteredVisitors.length})'),
          ],
        ),
      ),
      body: Column(
        children: [
          // حقل البحث
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'البحث في الإشعارات والزوار...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).primaryColor),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
          ),
          // محتوى التبويبات
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildNotificationsList(), _buildVisitorsList()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList() {
    if (_isLoading && _filteredNotifications.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'جاري تحميل الإشعارات...',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_filteredNotifications.isEmpty) {
      return _buildEmptyState(
        icon: Icons.notifications_outlined,
        title: 'لا توجد إشعارات',
        subtitle: _searchQuery.isEmpty
            ? 'ستظهر الإشعارات هنا عند وصولها'
            : 'لا توجد إشعارات تطابق البحث',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredNotifications.length + (_isLoading ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _filteredNotifications.length && _isLoading) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'جاري التحميل...',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }
          final notification = _filteredNotifications[index];
          return _buildNotificationCard(notification);
        },
      ),
    );
  }

  Widget _buildVisitorsList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_filteredVisitors.isEmpty) {
      return _buildEmptyState(
        icon: Icons.person_search_outlined,
        title: 'لا توجد زيارات',
        subtitle: _searchQuery.isEmpty
            ? 'لم يزر أحد ملفك الشخصي بعد'
            : 'لا توجد زيارات تطابق البحث',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredVisitors.length,
        itemBuilder: (context, index) {
          final visitor = _filteredVisitors[index];
          return _buildVisitorCard(visitor);
        },
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(NotificationModel notification) {
    // كارد دعوة تفاعلي مباشر
    if (notification.type == NotificationType.invitation) {
      return _buildInvitationCard(notification);
    }

    // كارد إشعار عادي
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _getNotificationColor(
              notification.type,
            ).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            _getNotificationIcon(notification.type),
            color: _getNotificationColor(notification.type),
            size: 20,
          ),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: notification.isRead
                ? FontWeight.normal
                : FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              notification.message,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  notification.senderName,
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
                const Spacer(),
                Text(
                  _formatTime(notification.createdAt),
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        onTap: () => _onNotificationTap(notification),
      ),
    );
  }

  Widget _buildVisitorCard(VisitorModel visitor) {
    // بناء رابط الصورة
    String? avatarUrl;
    if (visitor.visitorAvatar.isNotEmpty) {
      final cleanAvatar = visitor.visitorAvatar
          .replaceAll('[', '')
          .replaceAll(']', '')
          .replaceAll('"', '');
      avatarUrl =
          '${AppConstants.pocketbaseUrl}/api/files/${AppConstants.usersCollection}/${visitor.visitorId}/$cleanAvatar';
    }

    return GestureDetector(
      onTap: () => _navigateToUserProfile(visitor.visitorId),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // صورة الزائر
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.blue[100],
              backgroundImage: avatarUrl != null
                  ? NetworkImage(avatarUrl)
                  : null,
              child: avatarUrl == null
                  ? Text(
                      visitor.visitorName.isNotEmpty
                          ? visitor.visitorName[0].toUpperCase()
                          : '؟',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            // النص والوقت
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // اسم الزائر
                  Text(
                    visitor.visitorName,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // الرسالة
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                        fontFamily: 'Cairo',
                      ),
                      children: [
                        const TextSpan(text: 'زار ملفك الشخصي '),
                        TextSpan(
                          text: _getTimeAgo(visitor.visitedAt),
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // أيقونة للإشارة أنه قابل للنقر
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  // كارد دعوة تفاعلي مباشر
  Widget _buildInvitationCard(NotificationModel notification) {
    final invitationId = notification.id.replaceFirst('inv_', '');
    final localStatus = _localInvitationUpdates[invitationId];

    // استخدام البيانات المحفوظة في الإشعار
    if (notification.invitationData == null) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade300, width: 2),
        ),
        child: const Text('بيانات الدعوة غير متوفرة'),
      );
    }

    final invitationData = notification.invitationData!;
    final invitationInfo = invitationData['invitation'] as Map<String, dynamic>;
    final appointmentInfo =
        invitationData['appointment'] as Map<String, dynamic>;
    final hostInfo = invitationData['host'] as Map<String, dynamic>;

    // تطبيق التحديثات المحلية
    final currentStatus = localStatus ?? invitationInfo['status'];

    return _buildInvitationCardContent(
      notification,
      invitationInfo,
      appointmentInfo,
      hostInfo,
      currentStatus,
    );
  }

  // بناء محتوى كارد الدعوة باستخدام البيانات المحفوظة
  Widget _buildInvitationCardContent(
    NotificationModel notification,
    Map<String, dynamic> invitationInfo,
    Map<String, dynamic> appointmentInfo,
    Map<String, dynamic> hostInfo,
    String currentStatus,
  ) {
    final isResponded = currentStatus != 'invited';
    final isAccepted = currentStatus == 'accepted';
    final isRejected = currentStatus == 'rejected';

    // لون البوردر حسب حالة الضيف (ردي على الدعوة)
    Color borderColor;
    if (isAccepted) {
      borderColor = Colors.green; // قبلت الدعوة
    } else if (isRejected) {
      borderColor = Colors.red; // رفضت الدعوة
    } else {
      borderColor = Colors.orange; // دعوة معلقة
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // زر الحذف في الزاوية العلوية
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              onPressed: () => _deleteInvitationFromData(invitationInfo['id']),
              icon: const Icon(Icons.close, size: 20),
              style: IconButton.styleFrom(
                backgroundColor: Colors.grey.shade100,
                padding: const EdgeInsets.all(4),
                minimumSize: const Size(28, 28),
              ),
            ),
          ),

          // محتوى الكارد
          Padding(
            padding: const EdgeInsets.all(14), // تقليل من 16 إلى 14
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // معلومات المضيف - قابل للنقر
                GestureDetector(
                  onTap: () => _navigateToUserProfile(hostInfo['id']),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18, // تقليل الحجم من 20 إلى 18
                        backgroundImage:
                            hostInfo['avatar'] != null &&
                                hostInfo['avatar'].isNotEmpty
                            ? NetworkImage(
                                '${_authService.pb.baseURL}/api/files/_pb_users_auth_/${hostInfo['id']}/${hostInfo['avatar']}',
                              )
                            : null,
                        child:
                            hostInfo['avatar'] == null ||
                                hostInfo['avatar'].isEmpty
                            ? Text(
                                hostInfo['name']?.substring(0, 1) ?? 'م',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 10), // تقليل المسافة من 12 إلى 10
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hostInfo['name'] ?? 'مستخدم',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Colors.blue,
                              ),
                              overflow: TextOverflow
                                  .ellipsis, // اختصار النصوص الطويلة
                            ),
                            Text(
                              'دعاك لموعد${appointmentInfo['region'] != null && appointmentInfo['region'].toString().isNotEmpty ? ' في ${appointmentInfo['region']}' : ''} ${_getTimeAgo(notification.createdAt)}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                              overflow: TextOverflow
                                  .ellipsis, // اختصار النصوص الطويلة
                              textDirection: TextDirection.rtl, // عكس الاتجاه
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12), // تقليل من 16 إلى 12
                // تفاصيل الموعد
                Directionality(
                  textDirection: TextDirection.rtl, // ✅ اتجاه النص من اليمين لليسار
                  child: Container(
                    width: double.infinity, // عرض 100%
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // العنوان في سطر منفصل مع الاختصار
                        Text(
                          appointmentInfo['title'] ?? 'موعد',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 8),
                        // التواريخ والوقت في سطور منفصلة مع الاختصار
                        if (appointmentInfo['appointmentDate'] != null)
                          _buildAppointmentDates(
                            appointmentInfo['appointmentDate'],
                            appointmentInfo['date_type'],
                            appointmentInfo['hijri_day'],
                            appointmentInfo['hijri_month'],
                            appointmentInfo['hijri_year'],
                            appointmentInfo['hostId'],
                            appointmentInfo['duration'], // ✅ إضافة مدة الموعد
                          ),
                        const SizedBox(height: 8),
                        // قائمة الضيوف
                        _buildGuestsList(appointmentInfo['id']),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12), // تقليل من 16 إلى 12
                // أزرار الاستجابة
                if (!isResponded)
                  Builder(
                    builder: (context) {
                      final isLoading = _invitationLoadingStates[invitationInfo['id']] ?? false;
                      
                      return Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: isLoading ? null : () => _respondToInvitationFromData(
                                invitationInfo['id'],
                                'accepted',
                              ),
                              icon: isLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                              label: Text(
                                isLoading ? 'جاري المعالجة...' : 'موافق',
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: isLoading ? null : () => _respondToInvitationFromData(
                                invitationInfo['id'],
                                'rejected',
                              ),
                              icon: isLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.close,
                                      color: Colors.red,
                                      size: 18,
                                    ),
                              label: Text(
                                isLoading ? 'جاري المعالجة...' : 'رفض',
                                style: const TextStyle(color: Colors.red, fontSize: 14),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.red),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                    },
                  )
                else
                  // تم الرد على الدعوة
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isAccepted
                          ? Colors.green.shade50
                          : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isAccepted
                            ? Colors.green.shade200
                            : Colors.red.shade200,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isAccepted ? Icons.check_circle : Icons.cancel,
                          color: isAccepted ? Colors.green : Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isAccepted ? 'أنا وافقت' : 'أنا رفضت',
                          style: TextStyle(
                            color: isAccepted ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // الاستجابة على الدعوة باستخدام البيانات المحفوظة
  Future<void> _respondToInvitationFromData(
    String invitationId,
    String response,
  ) async {
    // تفعيل حالة التحميل فوراً
    setState(() {
      _invitationLoadingStates[invitationId] = true;
    });

    try {
      // تحديث حالة الدعوة
      await _authService.pb
          .collection(AppConstants.invitationsCollection)
          .update(
            invitationId,
            body: {
              'status': response,
              'respondedAt': DateTime.now().toIso8601String(),
            },
          );

      // إذا تم قبول الدعوة، إنشاء سجل user_appointment_status للضيف
      if (response == 'accepted') {
        await _createUserAppointmentStatusOnAcceptance(invitationId);
      }

      // 💾 تحديث الحالة في البيانات المحفوظة محلياً
      final currentUserId = _authService.currentUser?.id;
      if (currentUserId != null) {
        // تحديث القائمة المحلية
        for (var notification in _notifications) {
          if (notification.id == 'inv_$invitationId' &&
              notification.invitationData != null) {
            // تحديث حالة الدعوة في invitationData
            notification.invitationData!['invitation']['status'] = response;
            notification.invitationData!['invitation']['respondedAt'] =
                DateTime.now().toIso8601String();
            break;
          }
        }

        // حفظ التحديث في التخزين المحلي فوراً
        await _saveNotificationsToCache(currentUserId, _notifications);
        print('💾 تم حفظ حالة الضيف ($response) في التخزين المحلي');
      }

      setState(() {
        _localInvitationUpdates[invitationId] = response;
        _invitationLoadingStates[invitationId] = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response == 'accepted' ? 'وافقت على الدعوة' : 'رفضت الدعوة',
          ),
          backgroundColor: response == 'accepted' ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      print('❌ خطأ في الاستجابة على الدعوة: $e');
      
      setState(() {
        _invitationLoadingStates[invitationId] = false;
      });
      
      String errorMessage = 'حدث خطأ أثناء الاستجابة على الدعوة';
      
      // Check if invitation was deleted (404 error)
      if (e.toString().contains('404') || e.toString().contains("wasn't found")) {
        errorMessage = 'هذه الدعوة لم تعد موجودة. سيتم تحديث القائمة.';
        
        // Remove from local cache
        setState(() {
          _notifications.removeWhere((n) => n.id == 'inv_$invitationId');
        });
        
        // Save updated cache
        final currentUserId = _authService.currentUser?.id;
        if (currentUserId != null) {
          _saveNotificationsToCache(currentUserId, _notifications);
        }
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // حذف الدعوة باستخدام البيانات المحفوظة
  Future<void> _deleteInvitationFromData(String invitationId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الإشعار'),
        content: const Text('هل تريد حذف هذا الإشعار؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // 📢 حذف من قاعدة البيانات
        await _authService.pb
            .collection(AppConstants.invitationsCollection)
            .delete(invitationId);
        print('✅ تم حذف الدعوة من قاعدة البيانات: $invitationId');

        // 💾 حذف من القائمة المحلية
        setState(() {
          _notifications.removeWhere((n) => n.id == 'inv_$invitationId');
          _filteredNotifications.removeWhere(
            (n) => n.id == 'inv_$invitationId',
          );
        });

        // 💾 حفظ التحديث في التخزين المحلي فوراً
        final currentUserId = _authService.currentUser?.id;
        if (currentUserId != null) {
          await _saveNotificationsToCache(currentUserId, _notifications);
          print('💾 تم حذف الدعوة من التخزين المحلي');
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ تم حذف الإشعار بنجاح')),
          );
        }
      } catch (e) {
        print('❌ خطأ في حذف الدعوة: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ خطأ في حذف الإشعار: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // تنسيق التاريخ والوقت
  // حساب الوقت المنقضي بالعربية
  String _getTimeAgo(DateTime? dateTime) {
    if (dateTime == null) return '';

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'منذ لحظات';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      if (minutes == 1) return 'منذ دقيقة';
      if (minutes == 2) return 'منذ دقيقتين';
      if (minutes <= 10) return 'منذ $minutes دقائق';
      return 'منذ $minutes دقيقة';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      if (hours == 1) return 'منذ ساعة';
      if (hours == 2) return 'منذ ساعتين';
      if (hours <= 10) return 'منذ $hours ساعات';
      return 'منذ $hours ساعة';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      if (days == 1) return 'منذ يوم';
      if (days == 2) return 'منذ يومين';
      if (days <= 10) return 'منذ $days أيام';
      return 'منذ $days يوم';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      if (weeks == 1) return 'منذ أسبوع';
      if (weeks == 2) return 'منذ أسبوعين';
      if (weeks <= 10) return 'منذ $weeks أسابيع';
      return 'منذ $weeks أسبوع';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      if (months == 1) return 'منذ شهر';
      if (months == 2) return 'منذ شهرين';
      if (months <= 10) return 'منذ $months أشهر';
      return 'منذ $months شهر';
    } else {
      final years = (difference.inDays / 365).floor();
      if (years == 1) return 'منذ سنة';
      if (years == 2) return 'منذ سنتين';
      if (years <= 10) return 'منذ $years سنوات';
      return 'منذ $years سنة';
    }
  }

  // بناء قائمة الضيوف الأفقية
  Widget _buildGuestsList(String? appointmentId) {
    if (appointmentId == null) return const SizedBox.shrink();

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadAppointmentGuests(appointmentId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final guests = snapshot.data!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'الضيوف:',
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2), // تقليل من 4 إلى 2
            SizedBox(
              height: 32, // تقليل من 50 إلى 32 (ضغط أكثر)
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: guests.length,
                itemBuilder: (context, index) {
                  final guest = guests[index];
                  return _buildGuestItem(guest);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // بناء عنصر ضيف واحد
  Widget _buildGuestItem(Map<String, dynamic> guest) {
    return GestureDetector(
      onTap: () => _navigateToUserProfile(guest['id']),
      child: Container(
        margin: const EdgeInsets.only(left: 8), // تقليل من 12 إلى 8
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // صورة الضيف - تصغير بنسبة 60%
            CircleAvatar(
              radius: 10, // تقليل من 16 إلى 10 (حوالي 60% أصغر)
              backgroundColor: Colors.grey.shade300,
              backgroundImage: _buildGuestImage(guest['avatar'], guest['id']),
              child: guest['avatar'] == null || guest['avatar'].isEmpty
                  ? Text(
                      guest['name'].isNotEmpty
                          ? guest['name'][0].toUpperCase()
                          : '؟',
                      style: const TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ), // تقليل من 12 إلى 8
                    )
                  : null,
            ),
            const SizedBox(width: 4), // تقليل من 6 إلى 4
            // اسم الضيف
            Text(
              guest['name'],
              style: const TextStyle(
                fontSize: 10, // تقليل من 12 إلى 10
                color: Colors.blue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // بناء صورة الضيف مع معالجة أفضل للأخطاء
  ImageProvider? _buildGuestImage(String? avatar, String? userId) {
    if (avatar == null || avatar.isEmpty || userId == null || userId.isEmpty)
      return null;

    try {
      // إذا كانت الصورة تبدأ بـ http أو https
      if (avatar.startsWith('http')) {
        return NetworkImage(avatar);
      }
      // إذا كانت الصورة من PocketBase
      else {
        // تنظيف اسم الملف من الأقواس والاقتباسات
        final cleanAvatar = avatar
            .replaceAll('[', '')
            .replaceAll(']', '')
            .replaceAll('"', '');
        final imageUrl =
            '${AppConstants.pocketbaseUrl}/api/files/${AppConstants.usersCollection}/$userId/$cleanAvatar';
        print('🖼️ رابط صورة الضيف: $imageUrl');
        return NetworkImage(imageUrl);
      }
    } catch (e) {
      print('❌ خطأ في تحميل صورة الضيف: $e');
      return null;
    }
  }

  // جلب قائمة المدعوين للموعد (بدون صاحب الموعد)
  Future<List<Map<String, dynamic>>> _loadAppointmentGuests(
    String appointmentId,
  ) async {
    try {
      final invitationRecords = await _authService.pb
          .collection('invitations')
          .getFullList(
            filter: 'appointment = "$appointmentId"',
            expand: 'guest',
          );

      final currentUserId = _authService.currentUser?.id;
      List<Map<String, dynamic>> guests = [];

      for (final record in invitationRecords) {
        try {
          final guestData = record.get<List<dynamic>>('expand.guest');
          if (guestData.isNotEmpty) {
            final guest = guestData.first;
            final guestId = guest['id'] ?? '';

            // استثناء المستخدم الحالي من قائمة الضيوف
            if (guestId != currentUserId) {
              guests.add({
                'id': guestId,
                'name': guest['name'] ?? 'مستخدم',
                'avatar': guest['avatar'] ?? '',
                'status': record.data['status'] ?? 'invited',
              });
            }
          }
        } catch (e) {
          // تجاهل الأخطاء في جلب بيانات الضيف
          continue;
        }
      }
      return guests;
    } catch (e) {
      // تجاهل أخطاء الشبكة الشائعة (abort, timeout)
      if (!e.toString().contains('isAbort: true')) {
        print('❌ خطأ في جلب المدعوين: $e');
      }
      return [];
    }
  }

  // تنسيق التاريخ والوقت بالعربية حسب نوع التاريخ المختار أثناء الإنشاء
  String _formatDateTimeArabic(String? dateTimeString, [String? dateType]) {
    if (dateTimeString == null) return '';
    try {
      // 🕒 تحويل من UTC إلى التوقيت المحلي
      final dateTime = DateTime.parse(dateTimeString).toLocal();

      // تحديد نوع التاريخ بناءً على النوع المحفوظ مع الموعد
      final shouldUseHijri = dateType == 'hijri';

      if (shouldUseHijri) {
        // استخدام تصحيح المستخدم الحالي للتاريخ الهجري
        final userAdjustment = _authService.currentUser?.hijriAdjustment ?? 0;
        return _formatHijriDateTime(dateTime, userAdjustment);
      } else {
        return _formatGregorianDateTime(dateTime);
      }
    } catch (e) {
      print('❌ خطأ في تنسيق التاريخ: $e');
      return dateTimeString;
    }
  }

  // عرض التاريخين والوقت في 3 سطور: التاريخ الأساسي - يوافق الثانوي، والوقت
  Widget _buildAppointmentDates(
    String? dateTimeString,
    String? dateType,
    int? hijriDay,
    int? hijriMonth,
    int? hijriYear,
    String? hostId, [
    int? duration, // ✅ إضافة مدة الموعد
  ]) {
    if (dateTimeString == null) return const SizedBox.shrink();

    try {
      // 🕒 تحويل من UTC إلى التوقيت المحلي
      final dateTime = DateTime.parse(dateTimeString).toLocal();
      final isPrimaryHijri = dateType == 'hijri';
      
      // ✅ التحقق إذا كان الموعد متعدد الأيام
      final appointmentDuration = duration ?? 45;
      final isMultiDay = appointmentDuration >= 1440;

      // ✅ إذا كان الموعد متعدد الأيام، عرض نطاق التاريخ بدون وقت
      if (isMultiDay) {
        final endDate = dateTime.add(Duration(minutes: appointmentDuration));
        return _buildMultiDayDateRange(
          dateTime,
          endDate,
          isPrimaryHijri,
          hijriDay,
          hijriMonth,
          hijriYear,
          hostId,
        );
      }

      // أسماء الأيام بالعربية
      const arabicDays = [
        'الاثنين',
        'الثلاثاء',
        'الأربعاء',
        'الخميس',
        'الجمعة',
        'السبت',
        'الأحد',
      ];
      final dayName = arabicDays[dateTime.weekday - 1];

      String primaryDate;
      String secondaryDate;

      if (isPrimaryHijri &&
          hijriDay != null &&
          hijriMonth != null &&
          hijriYear != null) {
        // التاريخ الأساسي هجري
        final hijriMonths = [
          'محرم',
          'صفر',
          'ربيع الأول',
          'ربيع الآخر',
          'جمادى الأولى',
          'جمادى الآخرة',
          'رجب',
          'شعبان',
          'رمضان',
          'شوال',
          'ذو القعدة',
          'ذو الحجة',
        ];
        final monthName = hijriMonths[hijriMonth - 1];
        primaryDate = '\u200E$dayName $hijriDay $monthName $hijriYear هـ';

        // المعاينة ميلادي
        final gregorianMonths = [
          'يناير',
          'فبراير',
          'مارس',
          'أبريل',
          'مايو',
          'يونيو',
          'يوليو',
          'أغسطس',
          'سبتمبر',
          'أكتوبر',
          'نوفمبر',
          'ديسمبر',
        ];
        final gregMonthName = gregorianMonths[dateTime.month - 1];
        secondaryDate = '${dateTime.day} $gregMonthName ${dateTime.year}';
      } else {
        // التاريخ الأساسي ميلادي
        final gregorianMonths = [
          'يناير',
          'فبراير',
          'مارس',
          'أبريل',
          'مايو',
          'يونيو',
          'يوليو',
          'أغسطس',
          'سبتمبر',
          'أكتوبر',
          'نوفمبر',
          'ديسمبر',
        ];
        final gregMonthName = gregorianMonths[dateTime.month - 1];
        primaryDate =
            '$dayName ${dateTime.day} $gregMonthName ${dateTime.year}';

        // المعاينة هجري بتصحيح صاحب الموعد
        final hostAdjustment = _getHostAdjustment(hostId);
        final hijriDate = DateConverter.toHijri(
          dateTime,
          adjustment: hostAdjustment,
        );
        final hijriMonths = [
          'محرم',
          'صفر',
          'ربيع الأول',
          'ربيع الآخر',
          'جمادى الأولى',
          'جمادى الآخرة',
          'رجب',
          'شعبان',
          'رمضان',
          'شوال',
          'ذو القعدة',
          'ذو الحجة',
        ];
        final hijriMonthName = hijriMonths[hijriDate.hMonth - 1];
        final adjustmentText = hostAdjustment > 0
            ? '+$hostAdjustment '
            : hostAdjustment < 0
            ? '$hostAdjustment '
            : '';
        secondaryDate =
            '$adjustmentText\u200E${hijriDate.hDay} $hijriMonthName ${hijriDate.hYear} هـ';
      }

      // تنسيق الوقت
      final hour = dateTime.hour;
      final minute = dateTime.minute;
      String period;
      int displayHour;

      if (hour == 0) {
        displayHour = 12;
        period = 'صباحاً';
      } else if (hour < 12) {
        displayHour = hour;
        period = 'صباحاً';
      } else if (hour == 12) {
        displayHour = 12;
        period = 'مساءً';
      } else {
        displayHour = hour - 12;
        period = 'مساءً';
      }

      final timeString =
          'الساعة: $displayHour:${minute.toString().padLeft(2, '0')} $period';

      // عرض البيانات في 3 سطور مع نظام الاختصار
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // السطر 1: التاريخ الأساسي - يوافق الثانوي (مع الاختصار)
          Text(
            '$primaryDate - يوافق $secondaryDate',
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 13,
              height: 1.5,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 4),
          // السطر 2: الوقت (مع الاختصار)
          Text(
            timeString,
            style: TextStyle(color: Colors.grey[700], fontSize: 13),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      );
    } catch (e) {
      print('❌ خطأ في عرض التواريخ: $e');
      return Text(
        dateTimeString,
        style: TextStyle(color: Colors.grey[600], fontSize: 13),
      );
    }
  }

  // الحصول على تصحيح صاحب الموعد
  int _getHostAdjustment(String? hostId) {
    // إذا كان صاحب الموعد هو المستخدم الحالي، نستخدم تصحيحه
    if (hostId == _authService.currentUser?.id) {
      return _authService.currentUser?.hijriAdjustment ?? 0;
    }
    // هنا يمكن جلب تصحيح صاحب الموعد من قاعدة البيانات
    // لكن حالياً سنستخدم 0 كافتراضي
    return 0;
  }

  // تنسيق التاريخ والوقت الميلادي
  String _formatGregorianDateTime(DateTime dateTime) {
    // 🕒 التأكد من استخدام التوقيت المحلي
    final localDateTime = dateTime.toLocal();

    // أسماء الأيام بالعربية
    const arabicDays = [
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد',
    ];

    // أسماء الشهور بالعربية
    const arabicMonths = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];

    final dayName = arabicDays[localDateTime.weekday - 1];
    final monthName = arabicMonths[localDateTime.month - 1];

    // تحديد صباحاً أم مساءً
    final hour = localDateTime.hour;
    final minute = localDateTime.minute;
    String period;
    int displayHour;

    if (hour == 0) {
      displayHour = 12;
      period = 'صباحاً';
    } else if (hour < 12) {
      displayHour = hour;
      period = 'صباحاً';
    } else if (hour == 12) {
      displayHour = 12;
      period = 'مساءً';
    } else {
      displayHour = hour - 12;
      period = 'مساءً';
    }

    return '$dayName ${localDateTime.day}-$monthName-${localDateTime.year}  $displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  // تنسيق التاريخ والوقت الهجري باستخدام DateConverter
  String _formatHijriDateTime(DateTime dateTime, int adjustment) {
    try {
      // 🕒 التأكد من استخدام التوقيت المحلي
      final localDateTime = dateTime.toLocal();

      // استخدام DateConverter للتحويل الموحد
      final hijriDate = DateConverter.toHijri(
        localDateTime,
        adjustment: adjustment,
      );

      // أسماء الأيام بالعربية
      const arabicDays = [
        'الاثنين',
        'الثلاثاء',
        'الأربعاء',
        'الخميس',
        'الجمعة',
        'السبت',
        'الأحد',
      ];

      // أسماء الشهور الهجرية بالعربية
      const hijriMonths = [
        'محرم',
        'صفر',
        'ربيع الأول',
        'ربيع الآخر',
        'جمادى الأولى',
        'جمادى الآخرة',
        'رجب',
        'شعبان',
        'رمضان',
        'شوال',
        'ذو القعدة',
        'ذو الحجة',
      ];

      final dayName = arabicDays[localDateTime.weekday - 1];
      final monthName = hijriMonths[hijriDate.hMonth - 1];

      // تحديد صباحاً أم مساءً
      final hour = localDateTime.hour;
      final minute = localDateTime.minute;
      String period;
      int displayHour;

      if (hour == 0) {
        displayHour = 12;
        period = 'صباحاً';
      } else if (hour < 12) {
        displayHour = hour;
        period = 'صباحاً';
      } else if (hour == 12) {
        displayHour = 12;
        period = 'مساءً';
      } else {
        displayHour = hour - 12;
        period = 'مساءً';
      }

      return '\u200E$dayName ${hijriDate.hDay} $monthName ${hijriDate.hYear} هـ  $displayHour:${minute.toString().padLeft(2, '0')} $period';
    } catch (e) {
      // في حالة فشل التحويل، استخدم التاريخ الميلادي
      print('❌ خطأ في تحويل التاريخ الهجري: $e');
      return _formatGregorianDateTime(dateTime);
    }
  }

  Color _getNotificationColor(NotificationType type) {
    switch (type) {
      case NotificationType.invitation:
        return Colors.blue;
      case NotificationType.acceptance:
        return Colors.green;
      case NotificationType.rejection:
        return Colors.red;
      case NotificationType.reminder:
        return Colors.orange;
      case NotificationType.general:
        return Colors.grey;
    }
  }

  IconData _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.invitation:
        return Icons.event_available;
      case NotificationType.acceptance:
        return Icons.check_circle;
      case NotificationType.rejection:
        return Icons.cancel;
      case NotificationType.reminder:
        return Icons.access_time;
      case NotificationType.general:
        return Icons.info;
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'الآن';
    } else if (difference.inMinutes < 60) {
      return 'منذ ${difference.inMinutes} دقيقة';
    } else if (difference.inHours < 24) {
      return 'منذ ${difference.inHours} ساعة';
    } else if (difference.inDays < 7) {
      return 'منذ ${difference.inDays} يوم';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  void _onNotificationTap(NotificationModel notification) {
    if (!notification.isRead) {
      setState(() {
        notification.isRead = true;
      });
    }

    // لا نحتاج للتنقل - الكارد سيكون تفاعلي مباشرة
  }

  // إنشاء سجل user_appointment_status عند قبول الدعوة
  Future<void> _createUserAppointmentStatusOnAcceptance(
    String invitationId,
  ) async {
    try {
      // جلب معلومات الدعوة لمعرفة الموعد
      final invitation = await _authService.pb
          .collection(AppConstants.invitationsCollection)
          .getOne(invitationId);

      final appointmentId = invitation.data['appointment'];
      final currentUserId = _authService.currentUser!.id;

      // إنشاء خدمة user_appointment_status
      final statusService = UserAppointmentStatusService(_authService);

      // إنشاء سجل للضيف الذي قبل الدعوة
      // نسخة الضيف تكون عامة بشكل افتراضي
      await statusService.createUserAppointmentStatus(
        userId: currentUserId,
        appointmentId: appointmentId,
        status: 'active',
        privacy: 'public', // الضيف يقبل الموعد بخصوصية عامة افتراضياً
      );

      print('✅ تم إنشاء سجل user_appointment_status للضيف عند قبول الدعوة');
    } catch (e) {
      print('⚠️ خطأ في إنشاء سجل user_appointment_status عند قبول الدعوة: $e');
      // لا نرمي الخطأ لأن قبول الدعوة تم بنجاح
    }
  }

  // التنقل لحساب المستخدم
  void _navigateToUserProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfileScreen(userId: userId),
      ),
    );
  }

  // ✅ عرض نطاق التاريخ للمواعيد متعددة الأيام (بدون وقت)
  Widget _buildMultiDayDateRange(
    DateTime startDate,
    DateTime endDate,
    bool isPrimaryHijri,
    int? hijriDay,
    int? hijriMonth,
    int? hijriYear,
    String? hostId,
  ) {
    final gregorianMonths = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];

    final hijriMonths = [
      'محرم',
      'صفر',
      'ربيع الأول',
      'ربيع الآخر',
      'جمادى الأولى',
      'جمادى الآخرة',
      'رجب',
      'شعبان',
      'رمضان',
      'شوال',
      'ذو القعدة',
      'ذو الحجة',
    ];

    if (isPrimaryHijri && hijriDay != null && hijriMonth != null && hijriYear != null) {
      // التاريخ الأساسي هجري
      final startHijriText = '$hijriDay ${hijriMonths[hijriMonth - 1]} $hijriYear هـ';
      final startGregText = '${startDate.day} ${gregorianMonths[startDate.month - 1]} ${startDate.year}';

      // حساب التاريخ الهجري للنهاية (تقريبي)
      final hostAdjustment = _getHostAdjustment(hostId);
      final endHijri = DateConverter.toHijri(endDate, adjustment: hostAdjustment);
      final endHijriText = '${endHijri.hDay} ${hijriMonths[endHijri.hMonth - 1]} ${endHijri.hYear} هـ';
      final endGregText = '${endDate.day} ${gregorianMonths[endDate.month - 1]} ${endDate.year}';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'من $startHijriText الموافق $startGregText',
            style: TextStyle(color: Colors.grey[700], fontSize: 13, height: 1.5),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 4),
          Text(
            'إلى $endHijriText الموافق $endGregText',
            style: TextStyle(color: Colors.grey[700], fontSize: 13, height: 1.5),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      );
    } else {
      // التاريخ الأساسي ميلادي
      final startGregText = '${startDate.day} ${gregorianMonths[startDate.month - 1]} ${startDate.year}';
      final endGregText = '${endDate.day} ${gregorianMonths[endDate.month - 1]} ${endDate.year}';

      // حساب التاريخ الهجري
      final hostAdjustment = _getHostAdjustment(hostId);
      final startHijri = DateConverter.toHijri(startDate, adjustment: hostAdjustment);
      final endHijri = DateConverter.toHijri(endDate, adjustment: hostAdjustment);
      
      final startHijriText = '${startHijri.hDay} ${hijriMonths[startHijri.hMonth - 1]} ${startHijri.hYear} هـ';
      final endHijriText = '${endHijri.hDay} ${hijriMonths[endHijri.hMonth - 1]} ${endHijri.hYear} هـ';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'من $startGregText الموافق $startHijriText',
            style: TextStyle(color: Colors.grey[700], fontSize: 13, height: 1.5),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 4),
          Text(
            'إلى $endGregText الموافق $endHijriText',
            style: TextStyle(color: Colors.grey[700], fontSize: 13, height: 1.5),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      );
    }
  }
}

// النماذج
enum NotificationType { invitation, acceptance, rejection, reminder, general }

class NotificationModel {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  bool isRead;
  final DateTime createdAt;
  final String senderId;
  final String senderName;
  final String senderAvatar;

  // بيانات إضافية للدعوات
  final Map<String, dynamic>? invitationData;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    required this.createdAt,
    required this.senderId,
    required this.senderName,
    required this.senderAvatar,
    this.invitationData,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      type: NotificationType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => NotificationType.general,
      ),
      isRead: json['isRead'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
      senderId: json['senderId'] ?? '',
      senderName: json['senderName'] ?? '',
      senderAvatar: json['senderAvatar'] ?? '',
      invitationData: json['invitationData'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': type.toString(),
      'isRead': isRead,
      'createdAt': createdAt.toIso8601String(),
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'invitationData': invitationData,
    };
  }
}

class VisitorModel {
  final String id;
  final String visitorId;
  final String visitorName;
  final String visitorAvatar;
  final String profileSection;
  final DateTime visitedAt;

  VisitorModel({
    required this.id,
    required this.visitorId,
    required this.visitorName,
    required this.visitorAvatar,
    required this.profileSection,
    required this.visitedAt,
  });
}
