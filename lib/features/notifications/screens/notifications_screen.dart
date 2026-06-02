import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../appointments/providers/appointment_provider.dart';
import '../providers/notification_provider.dart';
import '../../../models/appointment.dart';
import '../../../models/notification.dart';
import '../widgets/invitation_tile.dart';
import '../widgets/notification_item.dart';
import '../../../core/extensions/context_l10n.dart';
import '../../../routes/app_router.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _hideAnswered = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppointmentProvider>().fetchAllInvitations();
      
      // 🔔 Mark all notifications as read when screen is opened
      final userId = context.read<AuthProvider>().user?.id;
      if (userId != null) {
        context.read<NotificationProvider>().fetchNotifications(userId);
        context.read<NotificationProvider>().markAllAsRead(userId);
      }
    });
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hideAnswered = prefs.getBool('hide_answered_notifications') ?? false;
    });
  }

  Future<void> _toggleHideAnswered() async {
    final prefs = await SharedPreferences.getInstance();
    final newValue = !_hideAnswered;
    await prefs.setBool('hide_answered_notifications', newValue);
    setState(() {
      _hideAnswered = newValue;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(context.l10n.notifications),
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDark ? Theme.of(context).appBarTheme.backgroundColor : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        actions: [
          IconButton(
            icon: Icon(
              _hideAnswered ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: _hideAnswered ? AppColors.primary : (isDark ? Colors.grey.shade400 : Colors.grey),
            ),
            tooltip: _hideAnswered ? context.l10n.showAll : context.l10n.hideAnswered,
            onPressed: _toggleHideAnswered,
          ),
        ],
      ),
      body: Consumer2<AppointmentProvider, NotificationProvider>(
        builder: (context, apptProvider, notifProvider, _) {
          // Get current user ID
          final userId = context.read<AuthProvider>().user?.id;
          
          if (userId == null) return const SizedBox.shrink();

          // 1. Invitations (Where I am a GUEST)
          final receivedInvitations = apptProvider.appointments.where((a) {
            final isNotHost = a.hostId != userId;
            final hasInvitation = a.currentUserInvitation != null;
            return isNotHost && hasInvitation;
          }).toList();

          // Combined List (Only received invitations for guests, host outgoing invitations are excluded)
          final List<Appointment> combinedList = receivedInvitations;

          // Sort by date desc
          combinedList.sort((a, b) {
            return b.createdAt.compareTo(a.createdAt);
          });


          List<Appointment> filteredList = combinedList;
          
          if (_hideAnswered) {
             filteredList = combinedList.where((item) {
                final isPending = item.currentUserInvitation?.status == InvitationStatus.pending;
                final isNotPast = !item.isPast;
                return isPending && isNotPast;
             }).toList();
          }

          // General notifications from provider (includes cancels, acceptances, follows, visits, system alerts, reminders, and approval requests)
          final List<NotificationModel> generalNotifications = notifProvider.notifications.where((item) {
            if (item.type == NotificationType.cancel) return true;
            if (item.type == NotificationType.invite && 
                (item.title.toLowerCase().contains('accept') || item.title.contains('قبول') || item.title.contains('قبل'))) {
              return true;
            }
            return item.type == NotificationType.follow ||
                item.type == NotificationType.visit ||
                item.type == NotificationType.system ||
                item.type == NotificationType.reminder ||
                item.type == NotificationType.approvalRequest;
          }).toList();

          if ((apptProvider.isLoading || notifProvider.isLoading) && filteredList.isEmpty && generalNotifications.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (filteredList.isEmpty && generalNotifications.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async {
                 await apptProvider.fetchAllInvitations();
                 await notifProvider.fetchNotifications(userId);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                   SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                   _buildEmptyState(),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
               await apptProvider.fetchAllInvitations();
               await notifProvider.fetchNotifications(userId);
            },
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                if (filteredList.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'دعوات بانتظار ردك 📥',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  ...filteredList.map((item) => InvitationTile(appointment: item)),
                  const SizedBox(height: 16),
                ],
                
                if (generalNotifications.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'صندوق الإشعارات والأنشطة 🔔',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                      ),
                    ),
                  ),
                  ...generalNotifications.map((item) => NotificationItem(
                    notification: item,
                    onTap: () {
                      AppRouter.handleNotificationTap(item);
                    },
                  )),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_outlined,
            size: 64,
            color: isDark ? Colors.grey.shade700 : Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.noNotificationsCurrently,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.newInvitesDesc,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}