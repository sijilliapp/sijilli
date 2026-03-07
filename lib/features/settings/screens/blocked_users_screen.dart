import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/pulse_avatar.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/pulse_avatar.dart';
import '../../profile/providers/moderation_provider.dart';
import 'package:sijilli/l10n/app_localizations.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';

class BlockedUsersScreen extends StatelessWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(context.l10n.blockedUsers),
      ),
      body: Consumer<ModerationProvider>(
        builder: (context, moderation, _) {
          if (moderation.isLoading && moderation.blockedUsers.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (moderation.blockedUsers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Icon(Icons.block, size: 64, color: Colors.grey.shade200),
                  const SizedBox(height: 16),
                  Text(
                    context.l10n.noBlockedUsers,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: moderation.blockedUsers.length,
            separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade100),
            itemBuilder: (context, index) {
              final user = moderation.blockedUsers[index];
              return ListTile(
                leading: PulseAvatar(
                  image: user.getAvatarUrl('https://sijilli.pockethost.io') != null 
                      ? NetworkImage(user.getAvatarUrl('https://sijilli.pockethost.io')!) 
                      : null,
                  size: 40,
                ),
                title: Text(user.name ?? user.username, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('@${user.username}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                trailing: TextButton(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(context.l10n.unblockTitle),
                        content: Text(context.l10n.unblockConfirm(user.name ?? user.username)),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.l10n.cancel)),
                          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(context.l10n.unblockConfirmAction, style: const TextStyle(color: AppColors.primary))),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await moderation.unblockUser(user.id);
                    }
                  },
                  child: Text(context.l10n.unblockTitle),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
