import 'package:flutter/material.dart';
import 'package:sijilli/features/appointments/widgets/cards/policies/standard_policy.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';

class ArchivedPolicy extends StandardPolicy {
  ArchivedPolicy(super.appointment, super.context, {super.customOnTap});

  @override
  double get elevation => 0.5;

  @override
  bool get canInviteGuest => false;

  @override
  String get guestActionText => context.l10n.statusArchived; // نص توضيحي

  @override
  IconData? get guestActionIcon => Icons.archive_outlined;

  @override
  VoidCallback? get onGuestActionTap => null; // Disable tap for archived state

  @override
  EdgeInsetsGeometry get margin => const EdgeInsets.symmetric(horizontal: 0, vertical: 4.0);
}
