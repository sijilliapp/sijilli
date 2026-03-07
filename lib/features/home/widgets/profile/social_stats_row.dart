import 'package:flutter/material.dart';
import 'package:sijilli/core/constants/app_colors.dart';
import 'package:sijilli/core/constants/app_dimens.dart';
import 'package:sijilli/features/settings/services/pb_user_service.dart';
import 'package:sijilli/features/profile/screens/follows_screen.dart';
import 'package:sijilli/l10n/app_localizations.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';

class SocialStatsRow extends StatefulWidget {
  final String userId;
  final bool isPrimaryStyle;
  const SocialStatsRow({
    super.key,
    required this.userId, 
    this.isPrimaryStyle = false,
  });

  @override
  State<SocialStatsRow> createState() => _SocialStatsRowState();
}

class _SocialStatsRowState extends State<SocialStatsRow> {
  final PbUserService _userService = PbUserService();
  int _followers = 0;
  int _following = 0;
  int _appointments = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCounts();
  }

  Future<void> _fetchCounts() async {
    try {
      final counts = await _userService.getFollowCounts(widget.userId);
      if (mounted) {
        setState(() {
          _followers = counts['followers'] ?? 0;
          _following = counts['following'] ?? 0;
          _appointments = counts['appointments'] ?? 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStatColumn(context.l10n.followers, _followers, 0),
        _buildDivider(),
        _buildStatColumn(context.l10n.following, _following, 1),
        if (widget.isPrimaryStyle) ...[
          _buildDivider(),
          _buildStatColumn(context.l10n.appointments, _appointments, -1),
        ],
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 30,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: AppDimens.spaceL),
      color: Theme.of(context).dividerColor,
    );
  }

  Widget _buildStatColumn(String label, int count, int tabIndex) {
    return InkWell(
      onTap: tabIndex == -1 ? null : () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FollowsScreen(
              userId: widget.userId,
              initialIndex: tabIndex,
            ),
          ),
        );
        _fetchCounts(); 
      },
      borderRadius: BorderRadius.circular(AppDimens.radius),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceS, 
          vertical: AppDimens.spaceXS,
        ),
        child: Column(
          children: [
            _isLoading 
              ? Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: SizedBox(
                    width: 16, 
                    height: 16, 
                    child: CircularProgressIndicator(
                      strokeWidth: 2, 
                      color: Theme.of(context).primaryColor.withOpacity(0.5),
                    )
                  ),
                )
              : Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: AppDimens.textSizeL,
                    fontWeight: FontWeight.bold,
                    color: widget.isPrimaryStyle ? AppColors.primary : AppColors.getTextPrimary(context),
                  ),
                ),
            Text(
              label,
              style: TextStyle(
                fontSize: AppDimens.textSizeXS,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
