import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sijilli/core/widgets/pulse_avatar.dart';
import 'package:sijilli/features/profile/widgets/user_cards/user_card_policy.dart';
import 'package:sijilli/core/constants/app_colors.dart';
import 'package:sijilli/core/constants/app_dimens.dart';
import 'package:sijilli/features/profile/providers/user_status_provider.dart';

class BaseUserCard extends StatelessWidget {
  final UserCardPolicy policy;

  const BaseUserCard({
    super.key,
    required this.policy,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<UserStatusProvider>(
      builder: (context, statusProvider, _) {
        // Decide status: Use policy's explicit ring if provided, 
        // otherwise fallback to the user's global status.
        AvatarStatus status = policy.avatarStatus;
        if (status == AvatarStatus.none && policy.shouldFetchStatus) {
          status = statusProvider.getStatus(policy.user.id);
          // Proactively fetch status if we haven't checked for this user yet
          statusProvider.fetchStatus(policy.user.id);
        }

        return Container(
          margin: policy.margin,
          decoration: BoxDecoration(
            color: policy.backgroundColor,
            borderRadius: BorderRadius.circular(AppDimens.radiusL),
            border: Border.all(
              color: AppColors.getBorder(context).withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.2 : 0.03),
                blurRadius: 10,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppDimens.radiusL),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: policy.onTap,
                child: Padding(
                  padding: policy.padding,
                  child: Row(
                    children: [
                      // 1. Avatar (Leading)
                      PulseAvatar(
                        image: policy.user.getAvatarUrl('https://sijilli.pockethost.io') != null
                            ? NetworkImage(policy.user.getAvatarUrl('https://sijilli.pockethost.io')!)
                            : null,
                        size: 44, // Slightly larger
                        status: status,
                      ),
                      
                      const SizedBox(width: AppDimens.spaceM),
    
                      // 2. User Info (Middle)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    policy.user.name,
                                    style: policy.nameStyle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (policy.buildBadges() != null) 
                                  policy.buildBadges()!,
                              ],
                            ),
                            policy.buildSecondaryText(),
                            if (policy.buildSubtitle() != null) ...[
                              const SizedBox(height: AppDimens.spaceXXS),
                              policy.buildSubtitle()!,
                            ],
                          ],
                        ),
                      ),
    
                      // 3. Action (Trailing)
                      if (policy.buildAction() != null) ...[
                        const SizedBox(width: AppDimens.spaceS),
                        policy.buildAction()!,
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
