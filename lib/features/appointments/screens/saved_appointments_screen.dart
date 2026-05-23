import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sijilli/core/constants/app_colors.dart';
import 'package:sijilli/core/constants/app_dimens.dart';
import 'package:sijilli/features/appointments/providers/appointment_provider.dart';
import 'package:sijilli/features/appointments/widgets/cards/base_appointment_card.dart';
import 'package:sijilli/features/appointments/widgets/cards/policies/public_policy.dart';

class SavedAppointmentsScreen extends StatelessWidget {
  const SavedAppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المحفوظات'), 
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Consumer<AppointmentProvider>(
        builder: (context, provider, child) {
          final saved = provider.bookmarkedAppointments;

          if (saved.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bookmark_border_rounded, size: 64, color: AppColors.getTextSecondary(context)),
                  const SizedBox(height: 16),
                  Text(
                    'لا توجد محفوظات حالياً',
                    style: TextStyle(
                      fontSize: 18,
                      color: AppColors.getTextSecondary(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppDimens.padding),
            itemCount: saved.length,
            itemBuilder: (context, index) {
              final appointment = saved[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: AppDimens.space),
                child: BaseAppointmentCard(
                  policy: PublicPolicy(appointment, context),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
