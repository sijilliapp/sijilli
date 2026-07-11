import 'package:flutter/material.dart';
import 'package:sijilli/models/appointment.dart';
import 'package:sijilli/features/appointments/widgets/cards/base_appointment_card.dart';
import 'package:sijilli/features/appointments/widgets/cards/policies/standard_policy.dart';
import 'package:sijilli/features/appointments/widgets/cards/policies/public_policy.dart';
import 'package:sijilli/features/appointments/widgets/cards/policies/featured_policy.dart';
import 'package:sijilli/features/appointments/widgets/cards/policies/archived_policy.dart';
import 'package:sijilli/features/appointments/widgets/cards/policies/deleted_policy.dart';
import 'package:sijilli/features/appointments/widgets/cards/appointment_card_policy.dart';
import '../../../core/constants/app_colors.dart';

class AppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final bool isFeatured;
  final bool readOnly;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool shouldGlow;

  const AppointmentCard({
    super.key,
    required this.appointment,
    this.isFeatured = false,
    this.readOnly = false,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.shouldGlow = false,
  });

  @override
  Widget build(BuildContext context) {
    AppointmentCardPolicy policy;

    if (isFeatured) {
      policy = FeaturedPolicy(appointment, context, customOnTap: onTap, isReadOnly: readOnly);
    } else if (readOnly) {
      policy = PublicPolicy(appointment, context, customOnTap: onTap);
    } else if (appointment.isArchived) {
      policy = ArchivedPolicy(appointment, context, customOnTap: onTap);
    } else if (appointment.isDeleted || appointment.isUserDeleted) {
      policy = DeletedPolicy(appointment, context, customOnTap: onTap);
    } else {
      policy = StandardPolicy(appointment, context, customOnTap: onTap);
    }

    return GlowWrapper(
      shouldGlow: shouldGlow,
      child: BaseAppointmentCard(policy: policy),
    );
  }
}

class GlowWrapper extends StatefulWidget {
  final Widget child;
  final bool shouldGlow;

  const GlowWrapper({
    super.key,
    required this.child,
    required this.shouldGlow,
  });

  @override
  State<GlowWrapper> createState() => _GlowWrapperState();
}

class _GlowWrapperState extends State<GlowWrapper> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _glowAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.0), weight: 60),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    if (widget.shouldGlow) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(GlowWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shouldGlow && !oldWidget.shouldGlow) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        final val = _glowAnimation.value;
        if (val == 0.0) return widget.child;

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.5 * val),
                blurRadius: 15.0 * val,
                spreadRadius: 4.0 * val,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}


