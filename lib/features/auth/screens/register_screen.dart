// 📍 lib/features/auth/screens/register_screen.dart
// 📝 شاشة إنشاء حساب جديد

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_config.dart';
import 'login_screen.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/extensions/context_l10n.dart';
import '../widgets/register_form_widget.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // تمكين تغيير حجم الشاشة مع الكيبورد
      resizeToAvoidBottomInset: true,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
        child: GestureDetector(
          // إخفاء الكيبورد عند النقر خارج الحقول
          onTap: () => FocusScope.of(context).unfocus(),
          child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // حساب ارتفاع الكيبورد
              final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
              final isKeyboardVisible = keyboardHeight > 0;
              
              return SingleChildScrollView(
                // تمكين التمرير عند ظهور الكيبورد
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        AppDimens.spaceXL, // 24
                        isKeyboardVisible ? AppDimens.space : AppDimens.spaceXXL, // 16 : 32 (Adjusted from 40 for consistency)
                        AppDimens.spaceXL,
                        AppDimens.spaceXL,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // مفتاح تبديل اللغة في الأعلى
                          _buildLanguageToggle(),
                          const SizedBox(height: AppDimens.space),
                          // الشعار والترحيب - يصغر مع الكيبورد
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            child: _buildHeader(isKeyboardVisible),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            height: isKeyboardVisible ? AppDimens.space : AppDimens.spaceXXL, // 16 : 32
                          ),
                          
                          // نموذج التسجيل
                          AppConfig.isRegistrationEnabled 
                            ? const RegisterFormWidget()
                            : _buildRegistrationDisabledMessage(),
                          
                          // العناصر الأقل أهمية - تختفي مع الكيبورد
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: !isKeyboardVisible
                                ? Column(
                                    key: const ValueKey('full_content'),
                                    children: [
                                      SizedBox(height: AppDimens.spaceXXL), // Removed const
                                      _buildDivider(),
                                      SizedBox(height: AppDimens.spaceXXL), // Removed const
                                      _buildLoginLink(),
                                    ],
                                  )
                                : const SizedBox(
                                    key: ValueKey('compact_content'),
                                    height: 16,
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ),
   );
  }

  Widget _buildHeader(bool isKeyboardVisible) {
    // حجم مصغر مع الكيبورد
    final logoSize = isKeyboardVisible ? AppDimens.avatarSizeL : AppDimens.avatarSizeXXL; // 56 : 80
    final titleSize = isKeyboardVisible ? AppDimens.textSizeL : AppDimens.textSizeXXL; // 20 : 28ish -> use XXL (28)
    final subtitleSize = isKeyboardVisible ? AppDimens.textSizeXS : AppDimens.textSize; // 12 : 16ish -> use textSize (16)
    
    return Column(
      children: [
        // الشعار
        Container(
          width: logoSize,
          height: logoSize,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(isKeyboardVisible ? 10 : 16),
          ),
          child: Icon(
            Icons.person_add,
            size: logoSize * 0.5,
            color: Colors.white,
          ),
        ),
        SizedBox(height: isKeyboardVisible ? AppDimens.spaceS : AppDimens.space), // 8 : 16
        
        // العنوان
        Text(
          context.l10n.createNewAccount,
          style: TextStyle(
            fontSize: titleSize,
            fontWeight: FontWeight.bold,
            color: AppColors.getTextPrimary(context),
          ),
        ),
        
        // الوصف - يختفي مع الكيبورد
        if (!isKeyboardVisible) ...[
          const SizedBox(height: AppDimens.spaceS), // 8.0
          Text(
            context.l10n.loginToContinue,
            style: TextStyle(
              fontSize: subtitleSize,
              color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
        ],
      ],
    );
  }


  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: Theme.of(context).dividerColor)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            context.l10n.or,
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade400 : Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(child: Divider(color: Theme.of(context).dividerColor)),
      ],
    );
  }

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          context.l10n.alreadyHaveAccount,
          style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade400 : Colors.grey.shade600),
        ),
        TextButton(
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const LoginScreen(),
              ),
            );
          },
          child: Text(
            context.l10n.login,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildRegistrationDisabledMessage() {
    return Container(
      padding: const EdgeInsets.all(AppDimens.space),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppDimens.radius),
        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.info_outline, color: AppColors.warning, size: 32),
          const SizedBox(height: 12),
          Text(
            'التسجيل مغلق مؤقتاً بقرار من الإدارة. يرجى المحاولة في وقت لاحق.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.getTextPrimary(context),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'شكراً لتفهمكم.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.language, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    provider.isArabic ? 'English' : 'عربي',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
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