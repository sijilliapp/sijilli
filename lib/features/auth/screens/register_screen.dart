// 📍 lib/features/auth/screens/register_screen.dart
// 📝 شاشة إنشاء حساب جديد المطورة

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import 'login_screen.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/extensions/context_l10n.dart';
import '../../../core/providers/global_config_provider.dart';
import 'registration_closed_screen.dart';
import '../widgets/register_form_widget.dart';
import '../widgets/auth_background.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with SingleTickerProviderStateMixin {
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
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRegistrationEnabled = context.watch<GlobalConfigProvider>().isRegistrationEnabled;
    
    if (!isRegistrationEnabled) {
      return const RegistrationClosedScreen();
    }

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
                          const SizedBox(height: AppDimens.space),
                          _buildLanguageToggle(),
                          const SizedBox(height: 20),
                          _buildHeader(),
                          const SizedBox(height: 32),
                          const RegisterFormWidget(),
                          const SizedBox(height: 24),
                           
                           // Privacy Assurance Note
                           Container(
                             padding: const EdgeInsets.all(16),
                             decoration: BoxDecoration(
                               color: AppColors.primary.withValues(alpha: 0.05),
                               borderRadius: BorderRadius.circular(12),
                               border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
                             ),
                             child: Row(
                               children: [
                                 const Icon(Icons.security_rounded, color: AppColors.primary, size: 20),
                                 const SizedBox(width: 12),
                                 Expanded(
                                   child: Text(
                                     'خصوصيتك أولويتنا؛ جميع مواعيدك تظهر افتراضياً للأشخاص المعتمدين فقط، ويمكنك تغيير ذلك لكل موعد.',
                                     style: TextStyle(
                                       fontSize: 12,
                                       color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                                       height: 1.4,
                                     ),
                                   ),
                                 ),
                               ],
                             ),
                           ),
                           
                           const SizedBox(height: 32),
                          _buildDivider(),
                          const SizedBox(height: 32),
                          _buildLoginLink(),
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
            width: 100,
            height: 100,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          context.l10n.createNewAccount,
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

  Widget _buildLoginLink() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          context.l10n.alreadyHaveAccount,
          style: TextStyle(
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            fontSize: 14,
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
              ),
            );
          },
          child: Text(
            context.l10n.login,
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