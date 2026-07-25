// 📍 lib/features/auth/screens/login_screen.dart
// 🔐 شاشة تسجيل الدخول المطورة

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';

import '../providers/auth_provider.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/auth_button.dart';
import '../widgets/auth_background.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import '../widgets/captcha_widget.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/extensions/context_l10n.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _identifierFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _captchaFocusNode = FocusNode();
  
  bool _obscurePassword = true;
  bool _isCaptchaVerified = false;
  int _failedAttempts = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    _identifierFocusNode.dispose();
    _passwordFocusNode.dispose();
    _captchaFocusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      resizeToAvoidBottomInset: true,
      body: AuthBackground(
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          ),
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: SafeArea(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceXL),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 10),
                          _buildLanguageToggle(),
                          const SizedBox(height: 5),
                          _buildHeader(),
                          const SizedBox(height: 20), // مسافة أقل قبل النموذج
                          _buildLoginForm(),
                          const SizedBox(height: 12), // مسافة موحدة
                          _buildLoginButton(),
                          const SizedBox(height: 12),
                          _buildForgotPassword(),
                          const SizedBox(height: 24),
                          _buildDivider(),
                          const SizedBox(height: 24),
                          _buildRegisterLink(),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Hero(
          tag: 'app_logo',
          child: Image.asset(
            'assets/logo/pAsset12.png',
            width: 120,
            height: 80,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          context.l10n.welcomeBack,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.loginToContinue,
          style: TextStyle(
            fontSize: 16,
            color: Theme.of(context).brightness == Brightness.dark 
                ? Colors.grey.shade400 
                : Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _formKey,
      child: AutofillGroup(
        child: Column(
          children: [
            AuthTextField(
              controller: _identifierController,
              focusNode: _identifierFocusNode,
              label: context.l10n.emailOrUsername,
              hint: context.l10n.emailOrUsername,
              prefixIcon: Icons.person_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
              validator: (value) => (value?.isEmpty ?? true) ? context.l10n.fieldRequired : null,
              autofillHints: const [AutofillHints.username, AutofillHints.email],
            ),
            const SizedBox(height: 12),
            AuthTextField(
              controller: _passwordController,
              focusNode: _passwordFocusNode,
              label: context.l10n.password,
              hint: context.l10n.enterPassword,
              prefixIcon: Icons.lock_outline_rounded,
              obscureText: _obscurePassword,
              autofillHints: const [AutofillHints.password],
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                  size: 20,
                ),
              ),
              validator: (value) {
                if (value?.isEmpty ?? true) return context.l10n.fieldRequired;
                // تم تسهيل التحقق في شاشة الدخول لتفادي حظر كلمات مرور الحسابات التجريبية للمراجعين
                return null;
              },
              textInputAction: _failedAttempts >= 3 ? TextInputAction.next : TextInputAction.done,
              onFieldSubmitted: (_) {
                if (_failedAttempts >= 3) {
                  _captchaFocusNode.requestFocus();
                } else {
                  _handleLogin();
                }
              },
            ),
          if (_failedAttempts >= 3) ...[
            const SizedBox(height: 12),
            CaptchaWidget(
              focusNode: _captchaFocusNode,
              onVerified: (verified) => setState(() => _isCaptchaVerified = verified),
              onSubmitted: _handleLogin,
            ),
          ],
        ],
      ),
     ),
    );
  }

  Widget _buildLoginButton() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return AuthButton(
          text: context.l10n.login,
          isLoading: authProvider.isLoading,
          onPressed: (_failedAttempts < 3 || _isCaptchaVerified) ? _handleLogin : null,
        );
      },
    );
  }

  Widget _buildForgotPassword() {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
          );
        },
        style: TextButton.styleFrom(
          minimumSize: Size.zero,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          context.l10n.forgotPassword,
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Expanded(child: Divider(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            context.l10n.or,
            style: TextStyle(
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
        Expanded(child: Divider(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300)),
      ],
    );
  }

  Widget _buildRegisterLink() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          context.l10n.noAccount,
          style: TextStyle(
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            fontSize: 14,
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => const RegisterScreen(),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
              ),
            );
          },
          child: Text(
            context.l10n.createNewAccount,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_failedAttempts >= 3 && !_isCaptchaVerified) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    final success = await authProvider.login(
      identifier: _identifierController.text.trim().toLowerCase(),
      password: _passwordController.text,
    );
    
    if (success) {
      TextInput.finishAutofillContext();
      if (mounted) setState(() => _failedAttempts = 0);
    } else if (mounted) {
      setState(() => _failedAttempts++);
      if (authProvider.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage!),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      }
    }
  }

  Widget _buildLanguageToggle() {
    return Consumer<LocaleProvider>(
      builder: (context, provider, child) {
        return Align(
          alignment: AlignmentDirectional.centerEnd,
          child: InkWell(
            onTap: () => provider.toggleLocale(),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.language_rounded, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    provider.isArabic ? 'English' : 'عربي',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}