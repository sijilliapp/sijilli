import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
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
import 'package:sijilli/features/notifications/providers/notification_provider.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';
import 'package:sijilli/core/widgets/auth_wrapper.dart';

class ProfileHeader extends StatefulWidget {
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
  State<ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends State<ProfileHeader> {
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickAndUploadImage(BuildContext context, ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null && mounted) {
        await _cropAndUploadImage(context, image);
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _cropAndUploadImage(BuildContext context, XFile sourceFile) async {
    final l10nTitle = Localizations.localeOf(context).languageCode == 'ar' 
        ? 'تعديل الصورة' 
        : 'Edit Image';

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: sourceFile.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: l10nTitle,
          toolbarColor: AppColors.primary,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: l10nTitle,
          aspectRatioLockEnabled: true,
        ),
        WebUiSettings(
          context: context,
          presentStyle: WebPresentStyle.dialog,
          size: const CropperSize(
            width: 380,
            height: 380,
          ),
          translations: WebTranslations(
            title: l10nTitle,
            rotateLeftTooltip: 'تدوير لليسار',
            rotateRightTooltip: 'تدوير لليمين',
            cancelButton: 'إلغاء',
            cropButton: 'قص',
          ),
        ),
      ],
    );

    if (croppedFile != null && mounted) {
      setState(() {
        _isUploading = true;
      });

      try {
        final authProvider = context.read<AuthProvider>();
        final success = await authProvider.updateUser({}, avatarFile: XFile(croppedFile.path));
        
        if (mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(Localizations.localeOf(context).languageCode == 'ar' 
                    ? 'تم تحديث الصورة الشخصية بنجاح' 
                    : 'Profile picture updated successfully'),
                backgroundColor: AppColors.success,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(authProvider.errorMessage ?? (Localizations.localeOf(context).languageCode == 'ar' 
                    ? 'فشل تحديث الصورة الشخصية' 
                    : 'Failed to update profile picture')),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('Error uploading avatar: $e');
      } finally {
        if (mounted) {
          setState(() {
            _isUploading = false;
          });
        }
      }
    }
  }

  Future<void> _removeProfilePicture(BuildContext context) async {
    setState(() {
      _isUploading = true;
    });
    try {
      final authProvider = context.read<AuthProvider>();
      final success = await authProvider.updateUser({'avatar': null});
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(Localizations.localeOf(context).languageCode == 'ar' 
                  ? 'تم حذف الصورة الشخصية بنجاح' 
                  : 'Profile picture removed successfully'),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(authProvider.errorMessage ?? (Localizations.localeOf(context).languageCode == 'ar' 
                  ? 'فشل حذف الصورة الشخصية' 
                  : 'Failed to remove profile picture')),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error removing avatar: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  void _showImageOptionsSheet(BuildContext context, UserModel displayUser) {
    final hasAvatar = displayUser.hasAvatar;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
                title: Text(Localizations.localeOf(sheetContext).languageCode == 'ar'
                    ? 'اختيار من الاستوديو'
                    : 'Choose from Gallery'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickAndUploadImage(context, ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
                title: Text(Localizations.localeOf(sheetContext).languageCode == 'ar'
                    ? 'التقاط صورة'
                    : 'Take Photo'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickAndUploadImage(context, ImageSource.camera);
                },
              ),
              if (hasAvatar)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: Text(Localizations.localeOf(sheetContext).languageCode == 'ar'
                      ? 'حذف الصورة الشخصية'
                      : 'Remove Profile Picture'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _removeProfilePicture(context);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, AuthProvider authProvider, _) {
        final displayUser = widget.user ?? authProvider.user;

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
                    final currentStatus = widget.customStatus ?? appointmentProvider.avatarStatus;
                    final isMe = !widget.isPublicView && displayUser.id == authProvider.user?.id;
  
                    Widget avatarWidget = PulseAvatar(
                      imageUrl: displayUser.getAvatarUrl('https://sijilli.pockethost.io'),
                      status: currentStatus,
                      size: AppDimens.avatarSizeProfile,
                      onTap: () {
                        if (authProvider.user == null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const AuthWrapper()),
                          );
                          return;
                        }
                        if (isMe) {
                          _showImageOptionsSheet(context, displayUser);
                        } else {
                          ProfileActionsHelper.showAvatarActions(
                            context: context, 
                            targetUser: displayUser, 
                            currentUser: authProvider.user,
                            streamLink: widget.streamLink,
                          );
                        }
                      },
                    );

                    if (isMe) {
                      avatarWidget = Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          avatarWidget,
                          if (_isUploading)
                            Positioned.fill(
                              child: Container(
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black45,
                                ),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                              ),
                            ),
                          PositionedDirectional(
                            bottom: 2,
                            end: 2,
                            child: GestureDetector(
                              onTap: () => _showImageOptionsSheet(context, displayUser),
                              child: Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.15),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  size: 18,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    return avatarWidget;
                  },
                ),
                
                const SizedBox(height: AppDimens.spaceS),
                
                InkWell(
                  onTap: () async {
                    if (authProvider.user == null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AuthWrapper()),
                      );
                      return;
                    }
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
                
                const SizedBox(height: AppDimens.spaceXXS),
              
                UserNameWithBadge(
                  name: displayUser.name,
                  isVerified: displayUser.isOfficial,
                  style: TextStyle(
                    fontSize: AppDimens.textSizeXL,
                    fontWeight: FontWeight.bold,
                    color: AppColors.getTextPrimary(context),
                  ),
                ),
                
                if (widget.showStats) ...[
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
                
                const SizedBox(height: AppDimens.spaceL),
 
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.isPublicView && displayUser.id != authProvider.user?.id) ...[
                      UserFollowButton(
                        userId: displayUser.id,
                        isHeaderStyle: true,
                        isPublic: displayUser.isPublic,
                        onFollowChanged: () {},
                      ),
                    ] else ...[
                      Consumer<NotificationProvider>(
                        builder: (context, notifProvider, _) {
                          final hasPending = notifProvider.pendingFollowsCount > 0;
                          
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
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
                                        mainAxisSize: MainAxisSize.min,
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
                              if (hasPending)
                                Positioned(
                                  right: -2,
                                  top: -2,
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.1),
                                          blurRadius: 2,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
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
                            if (authProvider.user == null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const AuthWrapper()),
                              );
                              return;
                            }
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
