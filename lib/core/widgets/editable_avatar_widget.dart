import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../constants/app_colors.dart';
import 'pulse_avatar.dart';
import '../../models/user.dart';
import '../../l10n/app_localizations.dart';

class EditableAvatarWidget extends StatefulWidget {
  final UserModel? user;
  final AvatarStatus avatarStatus;
  final ValueChanged<String?> onImageCropped;

  const EditableAvatarWidget({
    super.key,
    required this.user,
    required this.onImageCropped,
    this.avatarStatus = AvatarStatus.none,
  });

  @override
  State<EditableAvatarWidget> createState() => _EditableAvatarWidgetState();
}

class _EditableAvatarWidgetState extends State<EditableAvatarWidget> {
  final ImagePicker _picker = ImagePicker();
  String? _selectedAvatarPath;

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted) {
      _cropImage(image.path);
    }
  }

  Future<void> _cropImage(String sourcePath) async {
    // Determine the locale for translated title
    final l10nTitle = Localizations.localeOf(context).languageCode == 'ar' 
        ? 'تعديل الصورة' 
        : 'Edit Image';

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: sourcePath,
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
        ),
      ],
    );

    if (croppedFile != null && mounted) {
      setState(() {
        _selectedAvatarPath = croppedFile.path;
      });
      widget.onImageCropped(croppedFile.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTap: _pickImage,
          child: PulseAvatar(
            size: 100,
            image: _selectedAvatarPath != null
                ? FileImage(File(_selectedAvatarPath!)) as ImageProvider
                : (widget.user?.hasAvatar == true
                    ? NetworkImage(widget.user!.getAvatarUrl('https://sijilli.pockethost.io')!)
                    : null),
            status: widget.avatarStatus,
            onTap: _pickImage,
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          child: GestureDetector(
            onTap: _pickImage,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.camera_alt,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
