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

          // 1. Invitations (Rich Tiles)
          final receivedInvitations = apptProvider.appointments.where((a) {
            final isNotHost = a.hostId != userId;
            final hasInvitation = a.currentUserInvitation != null;
            return isNotHost && hasInvitation;
          }).toList();

          // 2. Notifications (Simple Items) - Filter out 'invites' as they are shown above
          // Also filter out 'cancel' notifications as per user request (ambiguous/useless).
          final otherNotifications = notifProvider.notifications.where((n) {
             return n.type != NotificationType.invite && n.type != NotificationType.cancel;
          }).toList();

          // Combined List Item Wrapper
          // We need a way to sort them together.
          // Let's create a wrapper class or use a list of abstract items.
          final List<dynamic> combinedList = [
            ...receivedInvitations,
            ...otherNotifications
          ];

          // Sort by date desc
          combinedList.sort((a, b) {
            DateTime dateA;
            if (a is Appointment) {
               // For appointments, we use createdAt of the invitation or appointment?
               // Usually notification lists show when the *event* happened (invite received).
               // Appt createdAt might be old, but invite is new?
               // Use updated?
               dateA = a.createdAt; 
            } else if (a is NotificationModel) {
               dateA = a.created;
            } else {
               dateA = DateTime(2000);
            }

            DateTime dateB; 
            if (b is Appointment) {
               dateB = b.createdAt;
            } else if (b is NotificationModel) {
               dateB = b.created;
            } else {
               dateB = DateTime(2000);
            }
            
            return dateB.compareTo(dateA);
          });


          // Filter Hide Answered
          // For Appointments: Pending + Future/Present (Not Past)
          // For Notifications: Unread? Or just show all history? 
          // "Hide Answered" usually implies "Hide Actioned/Done".
          // For notifications, maybe "Hide Read"?
          // Let's stick to the current logic for Appointments, and maybe hide Read notifications if toggle is on?
          
          List<dynamic> filteredList = combinedList;
          
          if (_hideAnswered) {
             filteredList = combinedList.where((item) {
                if (item is Appointment) {
                   final isPending = item.currentUserInvitation?.status == InvitationStatus.pending;
                   final isNotPast = !item.isPast;
                   return isPending && isNotPast;
                } else if (item is NotificationModel) {
                   return !item.isRead; // Only show unread notifications
                }
                return true;
             }).toList();
          }

          if ((apptProvider.isLoading || notifProvider.isLoading) && filteredList.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (filteredList.isEmpty) {
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
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: filteredList.length,
              itemBuilder: (context, index) {
                final item = filteredList[index];
                
                if (item is Appointment) {
                   return InvitationTile(appointment: item);
                } else if (item is NotificationModel) {
                   return NotificationItem(
                     notification: item,
                     onTap: () {
                        // Mark as read
                        if (!item.isRead) {
                           notifProvider.markAsRead(item.id);
                        }
                        // Handle navigation if needed (e.g. to appointment details if relatedId exists)
                     },
                   );
                }
                
                return const SizedBox.shrink();
              },
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