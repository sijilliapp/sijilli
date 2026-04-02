import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../appointments/providers/appointment_provider.dart';
import '../../../models/appointment.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/pulse_avatar.dart';
import '../../../core/widgets/user_name_with_badge.dart';
import '../../../core/utils/app_date_formatter.dart';
import '../../home/screens/public_profile_screen.dart';
import '../../../core/extensions/context_l10n.dart';
import 'invitation_time_row.dart';
import 'invitation_action_buttons.dart';

class InvitationTile extends StatefulWidget {
  // Force reload
  final Appointment appointment;

  const InvitationTile({super.key, required this.appointment});

  @override
  State<InvitationTile> createState() => _InvitationTileState();
}

class _InvitationTileState extends State<InvitationTile> {
  bool _isAccepting = false;
  bool _isRejecting = false;

  Future<void> _handleResponse(InvitationStatus status) async {
    final invitationId = widget.appointment.currentUserInvitation?.id;
    if (invitationId == null) return;

    // 1. Conflict Check (Only for Accept)
    if (status == InvitationStatus.accepted) {
       final provider = context.read<AppointmentProvider>();
       final conflicts = provider.getConflictingAppointments(
          widget.appointment.startAt, 
          widget.appointment.duration,
          excludeId: widget.appointment.id
       );
       
       if (conflicts.isNotEmpty) {
           final bool continueDespiteConflict = await showDialog(
               context: context,
               builder: (context) {
                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  return AlertDialog(
                   title: Row(
                     children: [
                       const Icon(Icons.warning_amber_rounded, color: Colors.orange), 
                       const SizedBox(width: 8), 
                       Text(context.l10n.conflictWarning, style: const TextStyle(fontSize: 18))
                     ]
                   ),
                   content: Text(
                     context.l10n.conflictDesc(conflicts.length),
                     style: TextStyle(height: 1.5, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                   ),
                   actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false), 
                        child: Text(context.l10n.cancel, style: const TextStyle(color: Colors.grey))
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true), 
                        child: Text(context.l10n.acceptAndContinue, style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold))
                      ),
                   ],
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
               );
               }
           ) ?? false;
           
           if (!continueDespiteConflict) return;
       }
    }

    setState(() {
      if (status == InvitationStatus.accepted) {
        _isAccepting = true;
      } else {
        _isRejecting = true;
      }
    });

    try {
      final currentUser = context.read<AuthProvider>().user;

      await context.read<AppointmentProvider>().respondToInvitation(
        widget.appointment.id, 
        status,
        fcfsNote: context.l10n.fcfsAutoDecline,
        fcfsHostNote: context.l10n.appointmentBookedBy(currentUser?.name ?? currentUser?.username ?? ''),
        acceptanceTitle: context.l10n.inviteAcceptedTitle,
        acceptanceMsg: context.l10n.inviteAcceptedMsg(
          currentUser?.name ?? currentUser?.username ?? '',
          widget.appointment.title
        ),
      );
      
      if (mounted) {
        final message = status == InvitationStatus.accepted ? context.l10n.inviteAccepted : context.l10n.inviteRejected;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: AppColors.success)
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.failedToUpdateStatus(e.toString())), backgroundColor: AppColors.error)
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAccepting = false;
          _isRejecting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final host = widget.appointment.host;
    final status = widget.appointment.currentUserInvitation?.status ?? InvitationStatus.pending;
    final invitationId = widget.appointment.currentUserInvitation?.id;

    // Determine background color based on status
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color backgroundColor = isDark ? Theme.of(context).cardColor : Colors.white;
    if (status == InvitationStatus.pending && !widget.appointment.isDeleted) {
       // 🟡 Waiting color (Light Alert)
       backgroundColor = isDark ? AppColors.alert.withValues(alpha: 0.15) : AppColors.alertLight.withValues(alpha: 0.12);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), // Tighter vertical
      padding: const EdgeInsets.all(6), // Elegant 6px padding
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20), // 20px Radius
        border: status == InvitationStatus.pending && !widget.appointment.isDeleted
            ? Border.all(color: AppColors.alert.withValues(alpha: 0.3), width: 1)
            : null,
        boxShadow: [
          if (!isDark)
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Time Ago (Top End/Corner)
          PositionedDirectional(
            end: 6, // Adjusted for padding, responds to RTL/LTR
            top: 6,  // Adjusted for padding
            child: Text(
              AppDateFormatter.timeAgo(widget.appointment.createdAt.toLocal(), Localizations.localeOf(context).languageCode, context.l10n),
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 11,
              ),
            ),
          ),
          
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Header (Avatar + Name + Invite Context)
              _buildRow(
                icon: PulseAvatar(
                  image: host?.hasAvatar == true 
                      ? NetworkImage(host!.getAvatarUrl('https://sijilli.pockethost.io')!) 
                      : null,
                  size: 38, // Slightly larger to anchor the two lines
                  status: _getAvatarStatus(status, widget.appointment),
                  ringThickness: 2.5,
                  gapThickness: 2.0,
                ),
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Host Name
                    InkWell(
                      onTap: () {
                        if (host != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PublicProfileScreen(usernameOrId: host.username),
                            ),
                          );
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 2.0), // Slight spacing
                        child: UserNameWithBadge(
                          name: host?.name ?? context.l10n.user,
                          isVerified: host?.isOfficial ?? false,
                          style: TextStyle(
                            fontWeight: FontWeight.bold, 
                            fontSize: 14,
                            height: 1.1, // Tighter line height to "raise" it visually
                            color: _getNameColor(status, widget.appointment),
                          ),
                        ),
                      ),
                    ),
                    
                    // "Invites you to..."
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: context.l10n.invitesYouTo, // Removed colon for flow
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                          TextSpan(
                            text: widget.appointment.title,
                            style: TextStyle(
                              color: AppColors.getTextPrimary(context),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Row 3: Location (Only if present)
              if (widget.appointment.hasLocation) ...[
                _buildRow(
                  icon: Icon(Icons.location_on_outlined, size: 20, color: Colors.grey.shade400),
                  content: Text(
                    widget.appointment.smartLocation!,
                    style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Row 4: Time (Full Width)
              InvitationTimeRow(
                appointment: widget.appointment,
                status: status,
              ),

              const SizedBox(height: 8),

              // Buttons
              InvitationActionButtons(
                appointment: widget.appointment,
                status: status,
                invitationId: invitationId,
                isAccepting: _isAccepting,
                isRejecting: _isRejecting,
                onResponse: _handleResponse,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRow({required Widget icon, required Widget content}) {
    return Row(
      children: [
        SizedBox(width: 32, child: Center(child: icon)),
        const SizedBox(width: 12),
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: content,
          ),
        ),
      ],
    );
  }

  AvatarStatus _getAvatarStatus(InvitationStatus status, Appointment appointment) {
    if (appointment.isDeleted || status == InvitationStatus.deletedAfterAccept) {
      return AvatarStatus.deleted; // Red
    }
    
    // Check for Past or Cancelled or Declined
    final endAt = appointment.startAt.toLocal().add(Duration(minutes: appointment.duration));
    final isPast = endAt.isBefore(DateTime.now());
    
    if (appointment.isCancelled || isPast || status == InvitationStatus.declined) {
      return AvatarStatus.none; // Gray
    }
    
    // Active (Pending or Accepted & Future)
    return AvatarStatus.upcoming; // Blue
  }

  Color _getNameColor(InvitationStatus status, Appointment appointment) {
    // 🔒 FINAL LOGIC: MATCHING CARD AVATAR RING EXACTLY
    final avatarStatus = _getAvatarStatus(status, appointment);

    switch (avatarStatus) {
      case AvatarStatus.deleted:
        return Colors.red;
      case AvatarStatus.active:
      case AvatarStatus.upcoming:
        return AppColors.primary;
      case AvatarStatus.none:
        return Colors.grey;
    }
  }
}
