// 📍 lib/features/settings/screens/profile_screen.dart
// 👤 شاشة تعديل الملف الشخصي

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sijilli/core/constants/app_colors.dart';
import 'package:sijilli/core/constants/app_dimens.dart';
import 'package:sijilli/features/auth/providers/auth_provider.dart';
import 'package:sijilli/features/appointments/providers/appointment_provider.dart';
import 'package:sijilli/core/widgets/editable_avatar_widget.dart';
import 'package:sijilli/l10n/app_localizations.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';
import 'package:sijilli/core/widgets/custom_text_field.dart';
import 'package:sijilli/features/home/widgets/profile_header.dart';
import 'package:sijilli/features/home/widgets/profile/social_stats_row.dart';
import 'package:sijilli/features/settings/screens/widgets/delete_account_button.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key}); // Forced reload check

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  late TextEditingController _bioController;
  late TextEditingController _phoneController;
  late TextEditingController _socialLinkController;
  late TextEditingController _emailController;
  int _hijriAdjustment = 0;
  
  bool _isPublic = false;
  String? _selectedAvatarPath;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    
    _nameController = TextEditingController(text: user?.name ?? '');
    _usernameController = TextEditingController(text: user?.username ?? '');
    _bioController = TextEditingController(text: user?.bio ?? '');
    _phoneController = TextEditingController(text: user?.phone?.toString() ?? '');
    _socialLinkController = TextEditingController(text: user?.socialLink ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _hijriAdjustment = (user?.hijriAdjustment ?? 0).toInt();
    _isPublic = user?.isPublic ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _phoneController.dispose();
    _socialLinkController.dispose();
    _emailController.dispose();
    super.dispose();
  }


  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    FocusScope.of(context).unfocus();

    final provider = context.read<AuthProvider>();
    
    final newUsername = _usernameController.text.trim();

    // Security Refactor: 
    // We no longer pre-check availability via public endpoints to prevent data leakage.
    // The `provider.updateUser` call will handle uniqueness constraints and return a localized error if taken.

    final Map<String, dynamic> data = {
      'name': _nameController.text.trim(),
      'username': newUsername,
      'bio': _bioController.text.trim(),
      'social_link': _socialLinkController.text.trim(),
      'hijri_adjustment': _hijriAdjustment,
      'isPublic': _isPublic,
    };

    final phoneText = _phoneController.text.trim();
    if (phoneText.isNotEmpty) {
      final num? phoneNum = num.tryParse(phoneText);
      if (phoneNum != null) {
        data['phone'] = phoneNum;
      }
    } else {
      data['phone'] = null;
    }
    
    final success = await provider.updateUser(data, avatarPath: _selectedAvatarPath);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.appointmentUpdated), // Reusing similar key or should have profileUpdated
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage ?? context.l10n.errorOccurred),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(context.l10n.editProfile),
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Theme.of(context).brightness == Brightness.dark ? Brightness.light : Brightness.dark,
          statusBarBrightness: Theme.of(context).brightness == Brightness.dark ? Brightness.dark : Brightness.light,
        ),
        actions: [
          TextButton(
            onPressed: context.watch<AuthProvider>().isLoading ? null : _saveProfile,
            child: context.watch<AuthProvider>().isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  )
                : Text(
                    context.l10n.save,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
      body: Consumer<AuthProvider>(
        builder: (context, provider, _) {
          final user = provider.user;
          final isVerified = user?.isOfficial ?? false;
          final isApproved = user?.isApproved ?? false;
          final isAdmin = user?.isAdmin ?? false;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimens.padding),
                child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                children: [
                   // Header Section
                  Center(
                    child: Column(
                      children: [
                        Consumer<AppointmentProvider>(
                          builder: (context, apptProvider, _) {
                            return EditableAvatarWidget(
                              user: user,
                              avatarStatus: apptProvider.avatarStatus,
                              onImageCropped: (path) {
                                setState(() {
                                  _selectedAvatarPath = path;
                                });
                              },
                            );
                          },
                        ),
                        const SizedBox(height: AppDimens.spaceM),
                        // Name and Badges
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              user?.name ?? '',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (isVerified) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.verified, color: Colors.blue, size: 20),
                            ],
                            if (isApproved || isAdmin) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isAdmin ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: isAdmin ? Colors.red : Colors.green,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  user?.roleDisplayName ?? '',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isAdmin ? Colors.red : Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: AppDimens.spaceL),

                // Stats Section
                if (provider.user != null)
                  SocialStatsRow(
                    userId: provider.user!.id,
                    isPrimaryStyle: true,
                  ),

                const SizedBox(height: AppDimens.spaceXL),

                  // Fields
                   CustomTextField(
                    controller: _usernameController,
                    label: context.l10n.username,
                    prefixIcon: Icons.alternate_email,
                    maxLength: 30, 
                    textDirection: TextDirection.ltr,
                    validator: (v) {
                       if (v == null || v.isEmpty) return context.l10n.fieldRequired;
                       if (v.length < 4) return context.l10n.fieldRequired; // Use more specific if available
                       if (!RegExp(r'^[a-zA-Z0-9_\.]+$').hasMatch(v)) return context.l10n.errorOccurred;
                       return null;
                    },
                  ),
                  const SizedBox(height: AppDimens.spaceS),
  
                  CustomTextField(
                    controller: _emailController,
                    label: context.l10n.email,
                    prefixIcon: Icons.email_outlined,
                    enabled: false, 
                    keyboardType: TextInputType.emailAddress,
                    textDirection: TextDirection.ltr,
                  ),
                  const SizedBox(height: AppDimens.spaceS),
 
                  CustomTextField(
                    controller: _nameController,
                    label: context.l10n.fullName,
                    prefixIcon: Icons.person_outline,
                    maxLength: 50, 
                    validator: (v) => v?.isEmpty == true ? context.l10n.fieldRequired : null,
                  ),
                  const SizedBox(height: AppDimens.spaceS),
                  
                  CustomTextField(
                    controller: _bioController,
                    label: 'Bio', // Should add to ARB if needed, or use existing
                    prefixIcon: Icons.info_outline,
                    maxLines: 3,
                    maxLength: 150, 
                  ),
                  const SizedBox(height: AppDimens.spaceS),
 
                  CustomTextField(
                    controller: _phoneController,
                    label: 'Phone',
                    prefixIcon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    maxLength: 15,
                    textDirection: TextDirection.ltr,
                    validator: (v) {
                       if (v == null || v.isEmpty) return null; 
                       if (!RegExp(r'^\+?[0-9\s\-]+$').hasMatch(v)) return context.l10n.errorOccurred;
                       return null;
                    },
                  ),
                  const SizedBox(height: AppDimens.spaceS),
 
                  CustomTextField(
                    controller: _socialLinkController,
                    label: 'Social Link',
                    prefixIcon: Icons.link,
                    keyboardType: TextInputType.url,
                    maxLength: 100,
                    textDirection: TextDirection.ltr,
                    validator: (v) {
                       if (v == null || v.isEmpty) return null; 
                       if (!v.contains('.')) return context.l10n.errorOccurred;
                       return null;
                    },
                  ),
                  const SizedBox(height: AppDimens.spaceM),
 
                  // Hijri Adjustment
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                       color: Theme.of(context).cardColor,
                       borderRadius: BorderRadius.circular(AppDimens.radius),
                       border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month, color: AppColors.primary),
                        const SizedBox(width: AppDimens.spaceM),
                        Expanded(
                          child: Text(
                            'تعديل التقويم الهجري',
                            style: TextStyle(fontSize: 16, color: AppColors.getTextPrimary(context)),
                          ),
                        ),
                        DropdownButton<int>(
                          value: _hijriAdjustment,
                          underline: const SizedBox(),
                          items: List.generate(5, (index) {
                            final val = index - 2; 
                            return DropdownMenuItem(
                              value: val,
                              child: Text(val == 0 ? '0' : (val > 0 ? '+$val' : '$val')),
                            );
                          }),
                          onChanged: (val) {
                            if (val != null) setState(() => _hijriAdjustment = val);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimens.spaceL),
 
                  // Public Switch
                  Container(
                    padding: const EdgeInsets.all(AppDimens.padding),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(AppDimens.radius),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.public, color: AppColors.primary),
                        const SizedBox(width: AppDimens.spaceM),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'حساب عام',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                'السماح للآخرين برؤية ملفك الشخصي',
                                style: TextStyle(
                                  color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade400 : Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _isPublic, 
                          onChanged: (val) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('هذه الميزة قيد التدشين حالياً (الحساب عام افتراضياً)'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  const DeleteAccountButton(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

}
