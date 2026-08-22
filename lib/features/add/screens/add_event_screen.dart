// 📍 lib/features/add/screens/add_event_screen.dart
// ➕ شاشة إضافة موعد جديد - مبسطة ومقسمة

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/appointment.dart';
import '../../../models/user.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/providers/global_config_provider.dart';
import '../../settings/screens/request_upgrade_screen.dart';
import '../widgets/add_event_form_body.dart';

class AddEventScreen extends StatelessWidget {
  final Appointment? initialAppointment;
  final UserModel? initialGuest;
  const AddEventScreen({super.key, this.initialAppointment, this.initialGuest});

  @override
  Widget build(BuildContext context) {
    // التحقق من صلاحية إنشاء موعد (للمواعيد الجديدة فقط)
    if (initialAppointment == null) {
      final authProvider = context.read<AuthProvider>();
      final config = context.read<GlobalConfigProvider>();
      final user = authProvider.user;
      if (user != null && !config.canCreateAppointment(user)) {
        return Scaffold(
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: Theme.of(context).iconTheme.color),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_outline_rounded, size: 64, color: Colors.orangeAccent),
                  const SizedBox(height: 16),
                  const Text(
                    'ميزة غير متاحة',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'تدوين المواعيد غير متاح لخطة عضويتك الحالية. يرجى طلب الترقية من الإعدادات أو مراجعة الإدارة.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const RequestUpgradeScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text('طلب ترقية العضوية', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }
    return AddEventFormBody(initialAppointment: initialAppointment, initialGuest: initialGuest);
  }
}
