import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../config/constants.dart';
import '../services/auth_service.dart';

/// مربع حوار تأكيد إرسال الموعد
class AppointmentConfirmationDialog extends StatefulWidget {
  final String title;
  final List<String>? guestNames;
  final List<UserModel>? guests; // قائمة الضيوف الكاملة
  final DateTime appointmentDateTime;
  final String? location; // المنطقة والمبنى
  final Future<void> Function() onConfirm;
  final VoidCallback onReview;

  const AppointmentConfirmationDialog({
    super.key,
    required this.title,
    this.guestNames,
    this.guests,
    required this.appointmentDateTime,
    this.location,
    required this.onConfirm,
    required this.onReview,
  });

  @override
  State<AppointmentConfirmationDialog> createState() =>
      _AppointmentConfirmationDialogState();
}

class _AppointmentConfirmationDialogState
    extends State<AppointmentConfirmationDialog>
    with SingleTickerProviderStateMixin {
  bool _isProcessing = false;
  bool _isSuccess = false;
  late AnimationController _animationController;
  final AuthService _authService = AuthService();
  late Animation<double> _scaleAnimation;
  late Animation<double> _checkAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    );

    _checkAnimation = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.65, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleConfirm() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      // تنفيذ عملية الحفظ
      await widget.onConfirm();

      // انتظار قليلاً لإظهار شعور المعالجة
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      setState(() {
        _isProcessing = false;
        _isSuccess = true;
      });

      // تشغيل أنيميشن الصح
      _animationController.forward();

      // الانتظار قليلاً ثم إغلاق الحوار
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      // في حالة الخطأ، نغلق الحوار ونعيد الخطأ
      if (mounted) {
        Navigator.of(context).pop(false);
        // إظهار رسالة الخطأ
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء حفظ الموعد: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // تنسيق التاريخ والوقت بشكل يدوي لتجنب مشاكل Locale
    final date = widget.appointmentDateTime;

    // أسماء الأشهر بالعربية
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

    final formattedDate =
        '${date.day} ${arabicMonths[date.month - 1]} ${date.year}';
    final hour = date.hour > 12
        ? date.hour - 12
        : (date.hour == 0 ? 12 : date.hour);
    final period = date.hour >= 12 ? 'مساءً' : 'صباحاً';
    final formattedTime =
        '${hour}:${date.minute.toString().padLeft(2, '0')} $period';

    // حساب الأيام المتبقية
    final now = DateTime.now();
    final difference = date.difference(now);
    final daysRemaining = difference.inDays;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(32),
        child: _isSuccess
            ? _buildSuccessView()
            : _buildConfirmationView(
                formattedDate,
                formattedTime,
                daysRemaining,
              ),
      ),
    );
  }

  Widget _buildConfirmationView(
    String formattedDate,
    String formattedTime,
    int daysRemaining,
  ) {
    // اسم الضيف الأول (إذا وجد)
    final firstGuestName = widget.guestNames?.isNotEmpty == true
        ? widget.guestNames!.first
        : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // النص العلوي
        if (firstGuestName != null) ...[
          Text(
            'أنت على وشك إرسال طلب توثيق موعد لـ($firstGuestName):',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
        ],

        // الصور المتداخلة (placeholder - سنضيف الصور الحقيقية لاحقاً)
        _buildOverlappingAvatars(),
        const SizedBox(height: 24),

        // عنوان الموعد (كبير وواضح)
        Text(
          widget.title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),

        // المكان (إذا وجد)
        if (widget.location != null && widget.location!.isNotEmpty) ...[
          Text(
            widget.location!,
            style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
        ],

        // التاريخ
        Directionality(
          textDirection: TextDirection.rtl,
          child: Text(
            formattedDate,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 12),

        // الوقت
        Directionality(
          textDirection: TextDirection.rtl,
          child: Text(
            formattedTime,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 20),

        // الأيام المتبقية
        if (daysRemaining >= 0)
          Text(
            daysRemaining == 0
                ? 'الموعد اليوم'
                : daysRemaining == 1
                ? 'تبقى على الموعد يوم واحد'
                : 'تبقى على الموعد $daysRemaining أيام',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: 32),

        // الأزرار
        if (_isProcessing)
          const SizedBox(
            height: 50,
            child: Center(child: CircularProgressIndicator()),
          )
        else
          Row(
            children: [
              // زر المراجعة
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pop(false);
                    widget.onReview();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade700,
                    backgroundColor: Colors.grey.shade100,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    side: BorderSide.none,
                  ),
                  child: const Text(
                    'مراجعة',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // زر الإرسال
              Expanded(
                child: ElevatedButton(
                  onPressed: _handleConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'إرسال',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  // بناء الصور المتداخلة
  Widget _buildOverlappingAvatars() {
    // الحصول على الضيف الأول
    final firstGuest = widget.guests?.isNotEmpty == true
        ? widget.guests!.first
        : null;

    // الحصول على المستخدم الحالي
    final currentUser = _authService.currentUser;

    return SizedBox(
      height: 90,
      width: 140,
      child: Stack(
        children: [
          // صورة المستخدم (كبيرة - يمين)
          Positioned(
            right: 0,
            child: _buildAvatar(size: 90, user: currentUser, isHost: true),
          ),
          // صورة الضيف (صغيرة - يسار متداخلة)
          if (firstGuest != null)
            Positioned(
              left: 0,
              bottom: 0,
              child: _buildAvatar(size: 70, user: firstGuest, isHost: false),
            ),
        ],
      ),
    );
  }

  // بناء صورة واحدة (مستخدم أو ضيف)
  Widget _buildAvatar({
    required double size,
    required UserModel? user,
    required bool isHost,
  }) {
    // الحصول على رابط الصورة
    String? avatarUrl;
    if (user?.avatar != null && user!.avatar!.isNotEmpty) {
      final cleanAvatar = user.avatar!
          .replaceAll('[', '')
          .replaceAll(']', '')
          .replaceAll('"', '');
      avatarUrl =
          '${AppConstants.pocketbaseUrl}/api/files/${AppConstants.usersCollection}/${user.id}/$cleanAvatar';
    }

    // لون الطوق: أزرق للداعي، رمادي للمدعوين
    final ringColor = isHost ? const Color(0xFF2196F3) : Colors.grey.shade400;
    final ringWidth = 3.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ringColor, width: ringWidth),
      ),
      child: Padding(
        padding: EdgeInsets.all(ringWidth),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: avatarUrl == null
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isHost
                        ? [
                            const Color(0xFF2196F3).withValues(alpha: 0.1),
                            const Color(0xFF2196F3).withValues(alpha: 0.05),
                          ]
                        : [Colors.grey.shade300, Colors.grey.shade200],
                  )
                : null,
          ),
          child: ClipOval(
            child: avatarUrl != null
                ? Image.network(
                    avatarUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Icon(
                          isHost ? Icons.person : Icons.person_outline,
                          size: size * 0.4,
                          color: isHost
                              ? const Color(0xFF2196F3).withValues(alpha: 0.6)
                              : Colors.grey.shade600,
                        ),
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: ringColor,
                        ),
                      );
                    },
                  )
                : Center(
                    child: Icon(
                      isHost ? Icons.person : Icons.person_outline,
                      size: size * 0.4,
                      color: isHost
                          ? const Color(0xFF2196F3).withValues(alpha: 0.6)
                          : Colors.grey.shade600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // أنيميشن الصح
        ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: AnimatedBuilder(
              animation: _checkAnimation,
              builder: (context, child) {
                return CustomPaint(
                  painter: CheckMarkPainter(
                    progress: _checkAnimation.value,
                    color: const Color(0xFF2196F3),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'تم الإرسال بنجاح!',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
      ],
    );
  }
}

/// رسام علامة الصح
class CheckMarkPainter extends CustomPainter {
  final double progress;
  final Color color;

  CheckMarkPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();

    // نقطة البداية
    final startX = size.width * 0.25;
    final startY = size.height * 0.5;

    // نقطة المنتصف
    final midX = size.width * 0.45;
    final midY = size.height * 0.7;

    // نقطة النهاية
    final endX = size.width * 0.75;
    final endY = size.height * 0.3;

    path.moveTo(startX, startY);

    if (progress < 0.5) {
      // رسم الجزء الأول من الصح
      final currentProgress = progress * 2;
      path.lineTo(
        startX + (midX - startX) * currentProgress,
        startY + (midY - startY) * currentProgress,
      );
    } else {
      // رسم الجزء الأول كاملاً
      path.lineTo(midX, midY);

      // رسم الجزء الثاني
      final currentProgress = (progress - 0.5) * 2;
      path.lineTo(
        midX + (endX - midX) * currentProgress,
        midY + (endY - midY) * currentProgress,
      );
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CheckMarkPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
