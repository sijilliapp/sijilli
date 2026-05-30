import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/widgets/auth_wrapper.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../settings/services/pb_user_service.dart';
import '../../add/screens/add_event_screen.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/extensions/context_l10n.dart';

class UserFollowButton extends StatefulWidget {
  final String userId;
  final VoidCallback? onFollowChanged;
  final bool isHeaderStyle;
  final bool isCompact;
  final bool? isPublic;
  final Map<String, dynamic>? initialStatusData;

  const UserFollowButton({
    Key? key,
    required this.userId,
    this.onFollowChanged,
    this.isHeaderStyle = false,
    this.isCompact = false,
    this.isPublic,
    this.initialStatusData,
  }) : super(key: key);

  @override
  State<UserFollowButton> createState() => _UserFollowButtonState();
}

class _UserFollowButtonState extends State<UserFollowButton> {
  final PbUserService _userService = PbUserService();
  String _status = 'none'; // 'none', 'pending', 'accepted', 'blocked'
  bool _isFriend = false;
  bool _isBeingFollowed = false;
  bool _isBlocked = false;
  bool _isBlockingMe = false;
  final bool _isActionLoading = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialStatusData != null) {
      _applyStatusData(widget.initialStatusData!);
    } else if (!widget.isCompact) { 
      // Only auto-fetch if NOT in a compact list (like search results) 
      // to avoid flooding the network.
      _checkStatus();
    } else {
      _isLoading = false;
    }
  }

  void _applyStatusData(Map<String, dynamic> data) {
    _status = data['status'] as String? ?? 'none';
    _isFriend = data['isFriend'] as bool? ?? false;
    _isBeingFollowed = data['isBeingFollowed'] as bool? ?? false;
    _isBlocked = data['isBlocked'] as bool? ?? false;
    _isBlockingMe = data['isBlockingMe'] as bool? ?? false;
    _isLoading = false;
  }

  Future<void> _checkStatus() async {
    if (!mounted) return;
    try {
      final results = await _userService.getAccreditationStatus(widget.userId);
      
      if (mounted) {
        setState(() {
          _status = results['status'] as String;
          _isFriend = results['isFriend'] as bool;
          _isBeingFollowed = results['isBeingFollowed'] as bool;
          _isBlocked = results['isBlocked'] as bool;
          _isBlockingMe = results['isBlockingMe'] as bool;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFollow() async {
    final auth = context.read<AuthProvider>();
    if (auth.user == null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AuthWrapper()),
      );
      return;
    }

    if (_isBlocked) {
      try {
        await _userService.unfollowUser(widget.userId); // In friendship table, unblocking is setting status to none
        _checkStatus();
      } catch (e) {}
      return;
    }

    if (_isBlockingMe) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكنك التفاعل مع هذا الحساب')),
      );
      return;
    }

    final oldStatus = _status;
    final isFriend = _isFriend;

    if (oldStatus == 'accepted' && isFriend) {
       // الحذف من قائمة الاعتمادات
       final confirm = await showDialog<bool>(
          context: context,
           builder: (context) => AlertDialog(
            title: Text(context.l10n.removeAccreditation),
            content: Text(context.l10n.removeAccreditationDesc),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.l10n.cancel)),
              TextButton(
                onPressed: () => Navigator.pop(context, true), 
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: Text(context.l10n.yesRemoveAccreditation),
              ),
            ],
          ),
        );
        if (confirm != true) return;

        // ⚡ Optimistic Update
        setState(() {
          _status = 'none';
          _isFriend = false;
        });

        try {
          await _userService.unfollowUser(widget.userId);
          widget.onFollowChanged?.call();
          _checkStatus();
        } catch (e) {
          _checkStatus(); // Revert
        }
        return;
    }

    if (oldStatus == 'pending') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.withdrawRequest),
          content: Text(context.l10n.withdrawDesc),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.l10n.keepRequest)),
            TextButton(onPressed: () => Navigator.pop(context, true), child: Text(context.l10n.yes)),
          ],
        ),
      );
      if (confirm != true) return;
      
      // ⚡ Optimistic Update
      setState(() => _status = 'none');

      try {
        await _userService.unfollowUser(widget.userId);
        _checkStatus();
      } catch (e) {
        _checkStatus(); // Revert
      }
      return;
    }

    // "اعتماد.." state logic
    if (_isBeingFollowed && oldStatus == 'none') {
       final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.l10n.accreditEntity),
            content: Text(
              context.l10n.accreditDesc,
              style: const TextStyle(fontSize: 14),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.l10n.close)),
              TextButton(onPressed: () => Navigator.pop(context, true), child: Text(context.l10n.accreditAction)),
            ],
          ),
        );
        if (confirm != true) return;

        // ⚡ Optimistic Update
        setState(() {
          _status = 'accepted';
          _isFriend = true;
        });

        try {
          await _userService.accreditUser(widget.userId);
          _checkStatus();
        } catch (e) {
          _checkStatus(); // Revert
        }
        return;
    }

    // Default Follow Action
    // ⚡ Optimistic Update
    setState(() {
      if (oldStatus == 'none') {
        _status = widget.isPublic == true ? 'accepted' : 'pending';
      } else {
        _status = 'none';
      }
    });
    
    try {
      if (oldStatus == 'none') {
        await _userService.followUser(widget.userId);
      } else {
        await _userService.unfollowUser(widget.userId);
      }
      
      await _checkStatus();
      widget.onFollowChanged?.call();
    } catch (e) {
      if (mounted) {
        await _checkStatus(); // Revert
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.operationFailed(e.toString()))),
        );
      }
    }
  }

  void _navigateToNewAppointment() async {
    // We need to fetch the target user model to pass it
    final user = await _userService.getPublicProfile(widget.userId);
    if (!mounted) return;
    
    if (user != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddEventScreen(initialGuest: user),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    String label;
    Color color;
    Color textColor;
    IconData? icon;
    bool hasBorder = false;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (_status) {
      case 'blocked':
        label = 'إلغاء الحظر';
        color = Colors.red.shade100;
        textColor = Colors.red;
        icon = Icons.block;
        hasBorder = true;
        break;
      case 'accepted':
        if (_isFriend) {
          if (widget.isHeaderStyle) {
            label = context.l10n.newAppointmentAction;
            color = isDark ? Colors.grey.shade800 : Colors.grey.shade100;
            textColor = AppColors.primary;
            icon = Icons.add;
            hasBorder = true;
          } else {
            label = context.l10n.accreditedBadge;
            color = isDark ? Colors.grey.shade800 : Colors.grey.shade100;
            textColor = isDark ? Colors.white : Colors.black54;
            icon = Icons.verified_user_outlined;
            hasBorder = true;
          }
        } else {
          label = context.l10n.waitingAction;
          color = isDark ? Colors.grey.shade800 : Colors.grey.shade100;
          textColor = isDark ? Colors.white : Colors.black54;
          icon = Icons.access_time;
          hasBorder = true;
        }
        break;
      case 'pending':
        label = context.l10n.waitingAction;
        color = isDark ? Colors.grey.shade800 : Colors.grey.shade100;
        textColor = isDark ? Colors.white : Colors.black54;
        icon = Icons.access_time;
        hasBorder = true;
        break;
      default:
        if (_isBeingFollowed) {
          label = context.l10n.accreditAction;
          color = AppColors.primary;
          textColor = Colors.white;
          icon = Icons.how_to_reg;
          hasBorder = false;
        } else {
          label = context.l10n.connectAction; 
          color = AppColors.primary;
          textColor = Colors.white;
          icon = Icons.person_add_outlined;
        }
    }

    Widget content = Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_isActionLoading)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2, 
                color: textColor.withValues(alpha: 0.5),
              ),
            )
          else ...[
            Icon(icon, color: textColor, size: widget.isCompact ? 14 : 16),
            const SizedBox(width: AppDimens.spaceXS),
          ],
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: widget.isCompact ? 11 : 13,
            ),
          ),
        ],
      ),
    );

    if (widget.isCompact) {
       return InkWell(
        onTap: _isActionLoading ? null : _toggleFollow,
        borderRadius: BorderRadius.circular(AppDimens.radiusRound),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.space, vertical: 6),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppDimens.radiusRound),
            border: hasBorder ? Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300) : null,
          ),
        child: content,
        ),
      );
    }

    if (widget.isHeaderStyle) {
      final isNewAppointmentMode = _status == 'accepted' && _isFriend;
      return InkWell(
        onTap: _isActionLoading ? null : (isNewAppointmentMode ? _navigateToNewAppointment : _toggleFollow),
        borderRadius: BorderRadius.circular(AppDimens.radiusCircle),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceL),
          height: AppDimens.buttonHeightXS, 
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppDimens.radiusCircle),
            border: hasBorder ? Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300) : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: content,
        ),
      );
    }

    // Default Style (Capsule)
    return InkWell(
      onTap: _isActionLoading ? null : _toggleFollow,
      borderRadius: BorderRadius.circular(AppDimens.radiusCircle),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceL, // 16px
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppDimens.radiusCircle),
          border: hasBorder ? Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300) : null,
        ),
        child: Center(child: content),
      ),
    );
  }
}
