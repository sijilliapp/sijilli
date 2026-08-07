import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/notification.dart';
import '../../../routes/app_router.dart';

/// 🔔 مدير وموفر الإشعارات داخل التطبيق (In-App Notification Banner Manager)
class InAppNotificationBanner {
  static final List<_QueuedNotification> _queue = [];
  static bool _isShowing = false;
  static OverlayEntry? _currentEntry;
  static Timer? _dismissTimer;

  /// عرض إشعار علوي داخل التطبيق
  static void show(
    NotificationModel notification, {
    String? localizedTitle,
    String? localizedMessage,
  }) {
    _queue.add(_QueuedNotification(
      notification: notification,
      title: localizedTitle ?? notification.title,
      message: localizedMessage ?? notification.message,
    ));
    _checkQueue();
  }

  static void _checkQueue() {
    if (_isShowing || _queue.isEmpty) return;
    
    final next = _queue.removeAt(0);
    _showOverlay(next);
  }

  static void _showOverlay(_QueuedNotification item) {
    final context = AppRouter.navigatorKey.currentContext;
    final overlayState = AppRouter.navigatorKey.currentState?.overlay;
    
    if (context == null || overlayState == null) {
      // إذا لم تكن الواجهة جاهزة بعد، ننتظر قليلاً ونحاول مجدداً
      Future.delayed(const Duration(milliseconds: 500), _checkQueue);
      return;
    }

    _isShowing = true;

    _currentEntry = OverlayEntry(
      builder: (context) {
        return _InAppNotificationWidget(
          notification: item.notification,
          title: item.title,
          message: item.message,
          onDismiss: () {
            _dismissCurrent();
          },
        );
      },
    );

    overlayState.insert(_currentEntry!);

    // تلقائي التلاشي بعد 4 ثوانٍ
    _dismissTimer = Timer(const Duration(seconds: 4), () {
      _dismissCurrent();
    });
  }

  static void _dismissCurrent() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    
    if (_currentEntry != null) {
      // إزالة الإشعار فوراً والبدء بالتالي بعد فترة قصيرة للحفاظ على سلاسة الحركة
      _currentEntry?.remove();
      _currentEntry = null;
      
      Future.delayed(const Duration(milliseconds: 300), () {
        _isShowing = false;
        _checkQueue();
      });
    } else {
      _isShowing = false;
      _checkQueue();
    }
  }

  /// مسح كافة الإشعارات المعلقة في الطابور
  static void clearQueue() {
    _queue.clear();
    _dismissCurrent();
  }
}

class _QueuedNotification {
  final NotificationModel notification;
  final String title;
  final String message;

  _QueuedNotification({
    required this.notification,
    required this.title,
    required this.message,
  });
}

class _InAppNotificationWidget extends StatefulWidget {
  final NotificationModel notification;
  final String title;
  final String message;
  final VoidCallback onDismiss;

  const _InAppNotificationWidget({
    required this.notification,
    required this.title,
    required this.message,
    required this.onDismiss,
  });

  @override
  State<_InAppNotificationWidget> createState() => _InAppNotificationWidgetState();
}

class _InAppNotificationWidgetState extends State<_InAppNotificationWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;
  
  double _dragOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleDismiss() async {
    await _animationController.reverse();
    widget.onDismiss();
  }

  IconData _getIcon() {
    switch (widget.notification.type) {
      case NotificationType.reminder:
        return Icons.access_time_rounded;
      case NotificationType.follow:
        return Icons.person_add_alt_1_rounded;
      case NotificationType.cancel:
        return Icons.cancel_outlined;
      case NotificationType.invite:
        return Icons.calendar_today_rounded;
      case NotificationType.system:
        return Icons.campaign_rounded;
      case NotificationType.approvalRequest:
        return Icons.fact_check_rounded;
      case NotificationType.visit:
        return Icons.visibility_outlined;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  Color _getIconColor() {
    switch (widget.notification.type) {
      case NotificationType.reminder:
        return Colors.blue;
      case NotificationType.follow:
        return Colors.green;
      case NotificationType.cancel:
        return Colors.red;
      case NotificationType.invite:
        return Colors.purple;
      case NotificationType.system:
        return Colors.amber.shade700;
      case NotificationType.approvalRequest:
        return Colors.orange;
      case NotificationType.visit:
        return Colors.teal;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10 + _dragOffset,
      left: 12,
      right: 12,
      child: GestureDetector(
        onVerticalDragUpdate: (details) {
          if (details.primaryDelta! < 0) {
            // سحب لأعلى للتخلص من الإشعار
            setState(() {
              _dragOffset += details.primaryDelta!;
            });
            if (_dragOffset < -20) {
              _handleDismiss();
            }
          }
        },
        onVerticalDragEnd: (details) {
          if (_dragOffset >= -20) {
            setState(() {
              _dragOffset = 0.0;
            });
          }
        },
        onTap: () {
          _handleDismiss();
          AppRouter.handleNotificationTap(widget.notification);
        },
        child: SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Material(
              color: Colors.transparent,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark 
                          ? Colors.grey.shade900.withOpacity(0.85) 
                          : Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark 
                            ? Colors.white10 
                            : Colors.grey.shade200.withOpacity(0.8),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.4 : 0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        )
                      ],
                    ),
                    child: Row(
                      textDirection: TextDirection.rtl,
                      children: [
                        // الأيقونة المصممة بنعومة
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _getIconColor().withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _getIcon(),
                            color: _getIconColor(),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        // محتوى الإشعار
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            textDirection: TextDirection.rtl,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.title,
                                textDirection: TextDirection.rtl,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isDark ? Colors.white : Colors.grey.shade900,
                                  fontFamily: 'NotoSansArabic',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.message,
                                textDirection: TextDirection.rtl,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade600,
                                  fontFamily: 'NotoSansArabic',
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // مقبض أو مؤشر السحب البسيط للتخلص من الإشعار
                        Icon(
                          Icons.drag_handle_rounded,
                          color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
