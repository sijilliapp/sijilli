import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sijilli/core/constants/app_colors.dart';
import 'package:sijilli/core/constants/app_dimens.dart';
import 'package:sijilli/models/user.dart';
import 'package:sijilli/features/auth/providers/auth_provider.dart';
import 'package:sijilli/features/appointments/providers/appointment_provider.dart';
import 'package:sijilli/core/widgets/pulse_avatar.dart';
import 'package:sijilli/core/widgets/user_name_with_badge.dart';
import 'profile/social_stats_row.dart';
import 'profile/profile_actions_helper.dart';
import '../../profile/widgets/user_follow_button.dart';
import 'package:sijilli/features/profile/screens/follows_screen.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';

class ProfileHeader extends StatelessWidget {
  final UserModel? user;
  final AvatarStatus? customStatus;
  final bool isPublicView;
  final bool showStats;
  final String? streamLink;
  
  const ProfileHeader({
    super.key, 
    this.user, 
    this.customStatus,
    this.isPublicView = false,
    this.showStats = false,
    this.streamLink,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, AuthProvider authProvider, _) {
        final displayUser = user ?? authProvider.user;

        if (displayUser == null) {
          return const SizedBox.shrink();
        }
        
        return Container(
          padding: const EdgeInsets.only(top: 20, bottom: 10),
          child: Column(
            children: [
              // Avatar
                Consumer<AppointmentProvider>(
                  builder: (context, AppointmentProvider appointmentProvider, _) {
                    final currentStatus = customStatus ?? appointmentProvider.avatarStatus;
  
                    return PulseAvatar(
                      imageUrl: displayUser.getAvatarUrl('https://sijilli.pockethost.io'),
                      status: currentStatus,
                      size: AppDimens.avatarSizeProfile,
                      onTap: () => ProfileActionsHelper.showAvatarActions(
                        context: context, 
                        targetUser: displayUser, 
                        currentUser: authProvider.user,
                        streamLink: streamLink,
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: AppDimens.spaceS),
                
                InkWell(
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: displayUser.profileUrl));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(context.l10n.linkCopied), 
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(AppDimens.radius),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.spaceS, 
                      vertical: AppDimens.spaceXS, 
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            displayUser.profileUrl,
                            style: TextStyle(
                              fontSize: AppDimens.textSizeS,
                              fontWeight: FontWeight.normal,
                              fontStyle: FontStyle.italic,
                              color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade400 : Colors.grey.shade500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppDimens.spaceXS),
                        Icon(
                          Icons.copy_rounded,
                          size: AppDimens.iconSizeXS,
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade500 : Colors.grey.shade500,
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: AppDimens.spaceTiny),
              
                UserNameWithBadge(
                  name: displayUser.name,
                  isVerified: displayUser.isOfficial,
                  style: TextStyle(
                    fontSize: AppDimens.textSizeXL,
                    fontWeight: FontWeight.bold,
                    color: AppColors.getTextPrimary(context),
                  ),
                ),
                
                if (showStats) ...[
                  const SizedBox(height: AppDimens.spaceTiny),
                  SocialStatsRow(userId: displayUser.id),
                ],
                
                if (displayUser.hasBio) ...[
                  const SizedBox(height: AppDimens.spaceTiny),
                  Text(
                    displayUser.bio!,
                    style: TextStyle(
                      fontSize: AppDimens.textSizeS,
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade300 : Colors.grey.shade600,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                
                const SizedBox(height: AppDimens.spaceCompact),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                      if (isPublicView && displayUser.id != authProvider.user?.id) ...[
                      UserFollowButton(
                        userId: displayUser.id,
                        isHeaderStyle: true,
                        isPublic: displayUser.isPublic,
                        onFollowChanged: () {},
                      ),
                    ] else ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: AppDimens.space),
                          height: AppDimens.buttonHeightXS,
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(AppDimens.radiusCircle),
                            border: Border.all(color: Theme.of(context).dividerColor),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withValues(alpha: 0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => FollowsScreen(userId: displayUser.id),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(22),
                              child: Directionality(
                                textDirection: context.l10n.localeName == 'ar' ? TextDirection.rtl : TextDirection.ltr,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.people_outline, color: AppColors.primary, size: AppDimens.iconSizeXS),
                                    const SizedBox(width: AppDimens.spaceTiny),
                                    Text(
                                      context.l10n.accreditations, 
                                      style: TextStyle(
                                        color: Theme.of(context).textTheme.bodyMedium?.color,
                                        fontWeight: FontWeight.w600,
                                        fontSize: AppDimens.textSizeXS,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
  
                      const SizedBox(width: AppDimens.spaceS),
  
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Theme.of(context).dividerColor),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withValues(alpha: 0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(AppDimens.radiusCircle),
                            onTap: () {
                              ProfileActionsHelper.showContactOptions(context, displayUser);
                            },
                            child: const Icon(Icons.link, color: AppColors.primary, size: AppDimens.iconSizeXS),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
          ),
        );
      },
    );
  }
}
