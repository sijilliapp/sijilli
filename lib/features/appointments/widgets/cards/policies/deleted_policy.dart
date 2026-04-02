import 'package:flutter/material.dart';
import 'package:sijilli/core/constants/app_colors.dart';
import 'package:sijilli/features/appointments/widgets/cards/policies/standard_policy.dart';

import 'package:provider/provider.dart';
import 'package:sijilli/features/auth/providers/auth_provider.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';

class DeletedPolicy extends StandardPolicy {
  DeletedPolicy(super.appointment, super.context, {super.customOnTap});

  @override
  Color get mainStatusColor => AppColors.warning; // Red for deleted

  @override
  double get elevation => 1;

  @override
  bool get canInviteGuest => false;

  @override
  String get guestActionText => context.l10n.statusUnavailable; // "Unavailable" - Replacement for Invite button

  @override
  IconData? get guestActionIcon => Icons.block; // Block icon to indicate disabled slot

  @override
  VoidCallback? get onGuestActionTap => null; // Disable tap

  @override
  String get hostName {
    // 🔒 Garbage Collection Context: 
    // If I am the host, show my name explicitly instead of "You" or local "Me" alias.
    // This fixes the "Creator says You" issue in trash bin.
    final currentUser = context.read<AuthProvider>().user;
    if (currentUser != null && appointment.hostId == currentUser.id) {
       return currentUser.name; 
    }
    return super.hostName;
  }
}
