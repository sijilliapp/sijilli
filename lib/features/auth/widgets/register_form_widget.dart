// 📍 lib/features/auth/widgets/register_form_widget.dart
// 🧩 مكون واجهة نموذج التسجيل المطور مع التوسيم الموحد

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../providers/auth_provider.dart';
import 'auth_text_field.dart';
import 'auth_button.dart';
import 'captcha_widget.dart';
import 'password_strength_indicator.dart';
import '../../../core/extensions/context_l10n.dart';

class RegisterFormWidget extends StatefulWidget {
  const RegisterFormWidget({super.key});

  @override
  State<RegisterFormWidget> createState() => _RegisterFormWidgetState();
}

class _RegisterFormWidgetState extends State<RegisterFormWidget> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  
  String _countryCode = '+973';
  
  final _fullNameFocusNode = FocusNode();
  final _usernameFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();
  
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptTerms = false;
  bool _isCaptchaVerified = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _fullNameFocusNode.dispose();
    _usernameFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isCaptchaVerified) return;
    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.agreeToTerms),
          backgroundColor: Colors.orangeAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    final fullName = _fullNameController.text.trim().split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');

    final success = await authProvider.register(
      name: fullName,
      username: _usernameController.text.trim().toLowerCase(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      passwordConfirm: _confirmPasswordController.text,
      phone: _phoneController.text.trim().isEmpty 
          ? null 
          : '$_countryCode${_phoneController.text.trim()}',
    );

    if (success) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    } else {
      if (mounted && authProvider.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.errorMessage!),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Form(
      key: _formKey,
      child: Column(
        children: [
          AuthTextField(
            controller: _fullNameController,
            focusNode: _fullNameFocusNode,
            label: context.l10n.fullName,
            hint: context.l10n.fullName, 
            prefixIcon: Icons.person_outline_rounded,
            keyboardType: TextInputType.name,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => _usernameFocusNode.requestFocus(),
            validator: (value) => (value?.isEmpty ?? true) ? context.l10n.fieldRequired : null,
          ),
          const SizedBox(height: 16),
          AuthTextField(
            controller: _usernameController,
            focusNode: _usernameFocusNode,
            label: context.l10n.username,
            hint: context.l10n.username,
            prefixIcon: Icons.alternate_email_rounded,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => _emailFocusNode.requestFocus(),
            inputFormatters: [
              LengthLimitingTextInputFormatter(24), // PocketBase max length
            ],
            validator: (value) {
              if (value?.isEmpty ?? true) return context.l10n.fieldRequired;
              if (!RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(value!)) return context.l10n.dataError;
              return null;
            },
          ),
          const SizedBox(height: 16),
          AuthTextField(
            controller: _emailController,
            focusNode: _emailFocusNode,
            label: context.l10n.email,
            hint: context.l10n.email,
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: (value) {
              if (value?.isEmpty ?? true) return context.l10n.fieldRequired;
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value!)) return context.l10n.invalidEmail;
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildPhoneField(isDark),
          const SizedBox(height: 16),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AuthTextField(
                controller: _passwordController,
                focusNode: _passwordFocusNode,
                label: context.l10n.password,
                hint: context.l10n.enterPassword,
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) => _confirmPasswordFocusNode.requestFocus(),
                onChanged: (_) => setState(() {}),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(_obscurePassword ? Icons.visibility_rounded : Icons.visibility_off_rounded, size: 20),
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) return context.l10n.fieldRequired;
                  if (value!.length < 8) return context.l10n.passwordMinLength;
                  return null;
                },
              ),
              if (_passwordController.text.isNotEmpty) ...[
                const SizedBox(height: 12),
                PasswordStrengthIndicator(password: _passwordController.text),
              ],
            ],
          ),
          const SizedBox(height: 16),
          AuthTextField(
            controller: _confirmPasswordController,
            focusNode: _confirmPasswordFocusNode,
            label: context.l10n.confirmPassword,
            hint: context.l10n.enterPassword,
            prefixIcon: Icons.lock_outline_rounded,
            obscureText: _obscureConfirmPassword,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _handleRegister(),
            suffixIcon: IconButton(
              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
              icon: Icon(_obscureConfirmPassword ? Icons.visibility_rounded : Icons.visibility_off_rounded, size: 20),
            ),
            validator: (value) {
              if (value?.isEmpty ?? true) return context.l10n.fieldRequired;
              if (value != _passwordController.text) return context.l10n.passwordsNotMatch;
              return null;
            },
          ),
          const SizedBox(height: 20),
          _buildTermsCheckbox(isDark),
          const SizedBox(height: 16),
          CaptchaWidget(
            onVerified: (verified) => setState(() => _isCaptchaVerified = verified),
          ),
          const SizedBox(height: 24),
          _buildRegisterButton(),
        ],
      ),
    );
  }

  Widget _buildPhoneField(bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 100,
          child: DropdownButtonFormField<String>(
            value: _countryCode,
            decoration: InputDecoration(
              labelText: 'كود',
              labelStyle: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, fontSize: 12),
              filled: true,
              fillColor: isDark ? AppColors.darkSurface : Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200)),
            ),
            onChanged: (val) => setState(() => _countryCode = val!),
            items: [
              const DropdownMenuItem(value: '+973', child: Text('🇧🇭', style: TextStyle(fontSize: 16))),
              const DropdownMenuItem(value: '+966', child: Text('🇸🇦', style: TextStyle(fontSize: 16))),
              const DropdownMenuItem(value: '+971', child: Text('🇦🇪', style: TextStyle(fontSize: 16))),
              const DropdownMenuItem(value: '+965', child: Text('🇰🇼', style: TextStyle(fontSize: 16))),
              const DropdownMenuItem(value: '+968', child: Text('🇴🇲', style: TextStyle(fontSize: 16))),
              const DropdownMenuItem(value: '+974', child: Text('🇶🇦', style: TextStyle(fontSize: 16))),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AuthTextField(
            controller: _phoneController,
            label: 'رقم الهاتف (اختياري)',
            hint: '3xxxxxxx',
            prefixIcon: Icons.phone_android_rounded,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
            validator: (value) {
              if (value == null || value.isEmpty) return null;
              if (!RegExp(r'^[0-9]+$').hasMatch(value)) return context.l10n.invalidPhone;
              if (value.length < 8 || value.length > 12) return context.l10n.invalidPhone;
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTermsCheckbox(bool isDark) {
    return InkWell(
      onTap: () => setState(() => _acceptTerms = !_acceptTerms),
      child: Row(
        children: [
          Checkbox(
            value: _acceptTerms,
            onChanged: (value) => setState(() => _acceptTerms = value ?? false),
            activeColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 14, color: isDark ? Colors.grey.shade300 : Colors.grey.shade800),
                children: [
                  TextSpan(text: context.l10n.iAgreeToThe),
                  TextSpan(
                    text: ' ${context.l10n.termsAndConditions}',
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterButton() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return AuthButton(
          text: context.l10n.registerAction,
          isLoading: authProvider.isLoading,
          onPressed: (_acceptTerms && _isCaptchaVerified) ? _handleRegister : null,
        );
      },
    );
  }
}
