import 'package:flutter/material.dart';
import 'package:hijri/hijri_calendar.dart';
import '../models/appointment_model.dart';
import '../models/user_model.dart';
import '../utils/date_converter.dart';

/// بطاقة بسيطة للموعد المؤرشف
class ArchivedAppointmentCard extends StatelessWidget {
  final AppointmentModel appointment;
  final UserModel? host;
  final VoidCallback onTap;
  final bool isExpired; // ✅ لتمييز المواعيد المنتهية

  const ArchivedAppointmentCard({
    super.key,
    required this.appointment,
    required this.host,
    required this.onTap,
    this.isExpired = false, // افتراضياً مؤرشف
  });

  @override
  Widget build(BuildContext context) {
    // ✅ تحديد اللون حسب النوع
    final backgroundColor = isExpired 
        ? const Color(0xFFFFCDD2)  // أحمر فاتح للمنتهية تلقائياً (Red 100)
        : const Color(0xFFE3F2FD); // أزرق فاتح جداً للمؤرشفة يدوياً (Blue 50)
    
    final borderColor = isExpired
        ? const Color(0xFFE57373)  // حدود حمراء للمنتهية (Red 300)
        : const Color(0xFF90CAF9); // حدود زرقاء للمؤرشفة (Blue 300)

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // العنوان (عريض)
              Text(
                appointment.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              
              // سطر البيانات: المنشئ • التاريخ • المكان
              Text(
                _buildInfoLine(),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildInfoLine() {
    final parts = <String>[];
    
    // المنشئ
    if (host != null) {
      parts.add(host!.name);
    }
    
    // التاريخ
    parts.add(_formatDate());
    
    // المكان
    if (appointment.region?.isNotEmpty ?? false) {
      final location = appointment.building?.isNotEmpty ?? false
          ? '${appointment.region} - ${appointment.building}'
          : appointment.region!;
      parts.add(location);
    }
    
    return parts.join(' • ');
  }

  String _formatDate() {
    try {
      if (appointment.dateType == 'hijri') {
        final hijri = HijriCalendar()
          ..hDay = appointment.hijriDay!
          ..hMonth = appointment.hijriMonth!
          ..hYear = appointment.hijriYear!;
        return DateConverter.formatHijri(hijri);
      } else {
        return DateConverter.formatGregorian(appointment.appointmentDate);
      }
    } catch (e) {
      return 'تاريخ غير محدد';
    }
  }
}
