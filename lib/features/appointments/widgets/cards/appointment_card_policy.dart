import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../models/appointment.dart';
import '../../../../core/widgets/pulse_avatar.dart';
import '../../../../core/providers/settings_provider.dart';

/// Abstract policy for defining visual and interactive behavior of appointment cards.
abstract class AppointmentCardPolicy {
  final Appointment appointment;
  final BuildContext context;
  final VoidCallback? customOnTap;

  AppointmentCardPolicy(this.appointment, this.context, {this.customOnTap});

  // --- Visuals ---
  Color get mainStatusColor;
  Color get borderColor;
  double get borderWidth => 1.0;
  Color get cardColor;
  Color get shadowColor;
  double get elevation;
  
  // --- Text & Icons ---
  Color get titleColor => const Color(0xFF2D3142);
  Color get hostNameColor;
  AvatarStatus get hostAvatarStatus;
  String get hostName; // Added for flexibility (e.g. Deleted vs Standard)
  Color get iconColor;
  
  // --- Status & Capsules ---
  Color get statusCapsuleBorderColor;
  Color get statusCapsuleBackgroundColor;
  Color get statusCapsuleTextColor;
  
  // --- Guest Capsule Policy ---
  String get guestActionText;
  IconData? get guestActionIcon;
  bool get canInviteGuest;
  
  // --- Interactions ---
  VoidCallback? get onCardTap;
  VoidCallback? get onHostTap;
  VoidCallback? get onGuestTap;
  VoidCallback? get onGuestActionTap;
  
  // --- Flags ---
  bool get isFeatured => false;
  bool get showPrivacyCapsule => true;
  bool get showLocation {
    try {
      return Provider.of<SettingsProvider>(context, listen: false).showLocationInfo;
    } catch (_) {
      return true;
    }
  }
  bool get canReport;

  // --- Layout ---
  EdgeInsetsGeometry get margin => const EdgeInsets.symmetric(horizontal: 0, vertical: 8.0); // Default spaceS
}
