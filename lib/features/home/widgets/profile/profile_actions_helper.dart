import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sijilli/core/constants/app_colors.dart';
import 'package:sijilli/core/utils/image_saver_util.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';
import 'package:sijilli/l10n/app_localizations.dart';
import 'package:sijilli/models/user.dart';

class ProfileActionsHelper {
  static void showAvatarActions({
    required BuildContext context,
    required UserModel targetUser,
    UserModel? currentUser,
    String? streamLink,
  }) {
    if (!targetUser.hasAvatar) return;

    // If there is an active stream link, priority is to show the options (Watch/Download)
    if (streamLink != null && streamLink.isNotEmpty) {
      showModalBottomSheet(
        context: context,
        useRootNavigator: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                _buildHandle(context),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.play_circle_outline, color: AppColors.primary),
                  title: Text(context.l10n.watchLive),
                  onTap: () {
                    Navigator.pop(context);
                    launchStream(streamLink);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.download_outlined, color: Colors.grey),
                  title: Text(context.l10n.saveImage),
                  onTap: () {
                    Navigator.pop(context);
                    _showDownloadConfirmation(context, targetUser, currentUser);
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      );
    } else {
      // Normal case: Just the download confirmation
      _showDownloadConfirmation(context, targetUser, currentUser);
    }
  }

  static void _showDownloadConfirmation(BuildContext context, UserModel targetUser, UserModel? currentUser) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(
          context.l10n.downloadFullImageConfirm,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.cancel, style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              downloadAvatar(context, targetUser, currentUser);
            },
            child: Text(context.l10n.download),
          ),
        ],
      ),
    );
  }

  static Widget _buildHandle(BuildContext context) {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade700 : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  static Future<void> launchStream(String? streamLink) async {
    if (streamLink == null) return;
    
    String sanitizedUrl = streamLink.trim();
    if (sanitizedUrl.contains('//') && !sanitizedUrl.contains('://')) {
      sanitizedUrl = sanitizedUrl.replaceFirst('//', '://');
    }
    if (!sanitizedUrl.startsWith('http://') && !sanitizedUrl.startsWith('https://')) {
      sanitizedUrl = 'https://$sanitizedUrl';
    }

    final url = Uri.parse(sanitizedUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  static Future<void> downloadAvatar(BuildContext context, UserModel targetUser, UserModel? currentUser) async {
    final bool isApproved = currentUser?.isApproved ?? false;
    final bool isAdmin = currentUser?.isAdmin ?? false;
    
    // Detailed check for certified members (Approved or Admin)
    final String? avatarUrl = targetUser.getAvatarUrl(
      'https://sijilli.pockethost.io', 
      thumb: (isApproved || isAdmin) ? null : '300x300'
    );

    if (avatarUrl == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.savingImage)),
    );

    final success = await ImageSaverUtil.saveImageFromUrl(
      avatarUrl, 
      'sijilli_avatar_${targetUser.username}.jpg'
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? context.l10n.imageSaved : context.l10n.imageSaveFailed),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  static void showContactOptions(BuildContext context, UserModel user) {
    if ((user.phone == null || user.phone!.isEmpty) && (user.socialLink == null || user.socialLink!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.noContactMethods)),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              _buildHandle(context),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  context.l10n.contactMethods,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
              ),
              if (user.phone != null && user.phone!.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.phone, color: Colors.green),
                  title: Text(user.phone!),
                  subtitle: Text(context.l10n.directCall),
                  onTap: () async {
                    Navigator.pop(context);
                    final uri = Uri.parse('tel:${user.phone}');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                  },
                ),
              if (user.socialLink != null && user.socialLink!.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.link, color: Colors.blue),
                  title: Text(user.socialLink!),
                  subtitle: Text(context.l10n.visitLink),
                  onTap: () async {
                    Navigator.pop(context);
                    var urlStr = user.socialLink!.trim();
                    if (!urlStr.startsWith('http://') && !urlStr.startsWith('https://')) {
                      urlStr = 'https://$urlStr';
                    }
                    try {
                      final uri = Uri.parse(urlStr);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    } catch (e) {
                      debugPrint('Error: $e');
                    }
                  },
                ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
