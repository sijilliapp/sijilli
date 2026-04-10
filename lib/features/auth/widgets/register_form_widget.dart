// 📍 lib/features/auth/widgets/register_form_widget.dart
// 🧩 مكون واجهة نموذج التسجيل

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../providers/auth_provider.dart';
import 'auth_text_field.dart';
import 'auth_button.dart';
import 'password_strength_indicator.dart';
import '../../../core/extensions/context_l10n.dart';
import '../screens/privacy_policy_screen.dart';

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
  
  final _fullNameFocusNode = FocusNode();
  final _usernameFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();
  
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptTerms = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    
    _fullNameFocusNode.dispose();
    _usernameFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    
    super.dispose();
  }


  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.agreeToTerms), // Fallback: 'يجب الموافقة على الشروط والأحكام'
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    final success = await authProvider.register(
      name: _fullNameController.text.trim(),
      username: _usernameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      passwordConfirm: _confirmPasswordController.text,
      phone: '', // اختياري
    );

    if (success) {
      // AuthWrapper يتولى التنقل تلقائياً
    } else {
      if (mounted && authProvider.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.errorMessage!),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // الاسم الكامل
          AuthTextField(
            controller: _fullNameController,
            focusNode: _fullNameFocusNode,
            label: context.l10n.fullName,
            hint: context.l10n.fullName, 
            prefixIcon: Icons.person_outline,
            keyboardType: TextInputType.name,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) {
              _usernameFocusNode.requestFocus();
            },
            validator: (value) {
              if (value?.isEmpty ?? true) {
                return context.l10n.fieldRequired;
              }
              if (value!.length < 2) {
                return context.l10n.fieldRequired;
              }
              return null;
            },
          ),
          const SizedBox(height: AppDimens.space), // 16.0
          
          // اسم المستخدم
          AuthTextField(
            controller: _usernameController,
            focusNode: _usernameFocusNode,
            label: context.l10n.username,
            hint: context.l10n.username,
            prefixIcon: Icons.alternate_email,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) {
              _emailFocusNode.requestFocus();
            },
            onChanged: (value) {
              // Real-time server checks removed for security (data leakage prevention)
            },
            validator: (value) {
              if (value?.isEmpty ?? true) {
                return context.l10n.fieldRequired;
              }
              if (value!.length < 3) {
                return context.l10n.fieldRequired;
              }
              if (!RegExp(r'^[a-z0-9_.]+$').hasMatch(value)) {
                return context.l10n.dataError; 
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          // البريد الإلكتروني
          AuthTextField(
            controller: _emailController,
            focusNode: _emailFocusNode,
            label: context.l10n.email,
            hint: context.l10n.email,
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) {
              _passwordFocusNode.requestFocus();
            },
            onChanged: (value) {
              // Real-time server checks removed for security (data leakage prevention)
            },
            validator: (value) {
              if (value?.isEmpty ?? true) {
                return context.l10n.fieldRequired;
              }
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value!)) {
                return context.l10n.invalidEmail;
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          // كلمة المرور
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AuthTextField(
                controller: _passwordController,
                focusNode: _passwordFocusNode,
                label: context.l10n.password,
                hint: context.l10n.enterPassword,
                prefixIcon: Icons.lock_outline,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) {
                  _confirmPasswordFocusNode.requestFocus();
                },
                onChanged: (value) {
                  setState(() {}); // لتحديث مؤشر القوة
                },
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  ),
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return context.l10n.fieldRequired;
                  }
                  if (value!.length < 8) {
                    return context.l10n.passwordMinLength;
                  }
                  // Enforce at least one letter and one number for minimal professional security
                  if (!RegExp(r'^(?=.*[A-Za-z])(?=.*\d).{8,}$').hasMatch(value)) {
                    return context.l10n.invalidPassword; // Reuse or add custom message if needed
                  }
                  return null;
                },
              ),
              // مؤشر قوة كلمة المرور
              if (_passwordController.text.isNotEmpty) ...[
                const SizedBox(height: 8),
                PasswordStrengthIndicator(password: _passwordController.text),
              ],
            ],
          ),
          const SizedBox(height: 16),
          
          // تأكيد كلمة المرور
          AuthTextField(
            controller: _confirmPasswordController,
            focusNode: _confirmPasswordFocusNode,
            label: context.l10n.confirmPassword,
            hint: context.l10n.enterPassword,
            prefixIcon: Icons.lock_outline,
            obscureText: _obscureConfirmPassword,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) {
              _handleRegister();
            },
            suffixIcon: IconButton(
              onPressed: () {
                setState(() {
                  _obscureConfirmPassword = !_obscureConfirmPassword;
                });
              },
              icon: Icon(
                _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
              ),
            ),
            validator: (value) {
              if (value?.isEmpty ?? true) {
                return context.l10n.fieldRequired;
              }
              if (value != _passwordController.text) {
                return context.l10n.passwordsNotMatch;
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          // الموافقة على الشروط
          _buildTermsCheckbox(),

          const SizedBox(height: AppDimens.spaceXL), // 24
          
          // زر التسجيل
          _buildRegisterButton(),
        ],
      ),
    );
  }

  Widget _buildTermsCheckbox() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: _acceptTerms,
            onChanged: (value) {
              setState(() {
                _acceptTerms = value ?? false;
              });
            },
            activeColor: AppColors.primary,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey.shade300
                    : Colors.black87,
              ),
              children: [
                TextSpan(text: context.l10n.iAgreeToThe),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PrivacyPolicyScreen(),
                        ),
                      );
                    },
                    child: Text(
                      context.l10n.termsAndConditions,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterButton() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return AuthButton(
          text: context.l10n.registerAction,
          isLoading: authProvider.isLoading,
          onPressed: _acceptTerms ? _handleRegister : null,
        );
      },
    );
  }
}
