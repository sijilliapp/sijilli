import 'package:flutter/material.dart';

/// مربع حوار تأكيد إرسال الموعد
class AppointmentConfirmationDialog extends StatefulWidget {
  final String title;
  final List<String>? guestNames;
  final DateTime appointmentDateTime;
  final Future<void> Function() onConfirm;
  final VoidCallback onReview;

  const AppointmentConfirmationDialog({
    super.key,
    required this.title,
    this.guestNames,
    required this.appointmentDateTime,
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
    final formattedDate = '${date.year}/${date.month}/${date.day}';
    final hour = date.hour > 12
        ? date.hour - 12
        : (date.hour == 0 ? 12 : date.hour);
    final period = date.hour >= 12 ? 'م' : 'ص';
    final formattedTime =
        '${hour}:${date.minute.toString().padLeft(2, '0')} $period';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _isSuccess
            ? _buildSuccessView()
            : _buildConfirmationView(formattedDate, formattedTime),
      ),
    );
  }

  Widget _buildConfirmationView(String formattedDate, String formattedTime) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // أيقونة التنبيه
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.send_rounded,
            size: 32,
            color: Colors.blue.shade700,
          ),
        ),
        const SizedBox(height: 20),

        // العنوان
        const Text(
          'أنت على وشك إرسال طلب',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),

        // تفاصيل الموعد
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // العنوان
              _buildDetailRow(Icons.title, 'العنوان', widget.title),
              if (widget.guestNames != null &&
                  widget.guestNames!.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildDetailRow(
                  Icons.person,
                  'مع',
                  widget.guestNames!.length == 1
                      ? widget.guestNames!.first
                      : '${widget.guestNames!.first} و${widget.guestNames!.length - 1} آخرين',
                ),
              ],
              const SizedBox(height: 12),
              _buildDetailRow(Icons.calendar_today, 'التاريخ', formattedDate),
              const SizedBox(height: 12),
              // الوقت بالعريض
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 20,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'الساعة:',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      formattedTime,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // سؤال التأكيد
        const Text(
          'هل أنت متأكد من ذلك؟',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF424242),
          ),
        ),
        const SizedBox(height: 24),

        // الأزرار
        if (_isProcessing)
          const SizedBox(
            height: 50,
            child: Center(child: CircularProgressIndicator()),
          )
        else
          Column(
            children: [
              // زر الإرسال
              SizedBox(
                width: double.infinity,
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
              const SizedBox(height: 12),
              // زر المراجعة
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pop(false);
                    widget.onReview();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: const Text(
                    'مراجعة الطلب',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Text(
          '$label:',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
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
