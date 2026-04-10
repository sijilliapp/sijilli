// 📍 lib/features/auth/screens/login_screen.dart
// 🔐 شاشة تسجيل الدخول

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';

import '../providers/auth_provider.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/auth_button.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/extensions/context_l10n.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _identifierFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  
  bool _obscurePassword = true;

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
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppDimens.spaceXL, // 24
                    isKeyboardVisible ? AppDimens.space : AppDimens.spaceXXL, // 16 : 32
                    AppDimens.spaceXL,
                    AppDimens.spaceXL,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // مفتاح تبديل اللغة في الأعلى
                        _buildLanguageToggle(),
                        const SizedBox(height: AppDimens.space),
                        // الشعار والترحيب - مضغوط إلى الأعلى
                        _buildHeader(isKeyboardVisible),
                        SizedBox(height: isKeyboardVisible ? AppDimens.spaceSubtitle : AppDimens.spaceL), // Adjusted to 18 : 20ish -> spaceM/spaceL
                        
                        // نموذج تسجيل الدخول
                        _buildLoginForm(),
                        const SizedBox(height: 16), // مسافة مناسبة بين "تذكرني" وزر الدخول
                        
                        // زر تسجيل الدخول
                        _buildLoginButton(),
                        
                        // العناصر الأقل أهمية
                        if (!isKeyboardVisible) ...[
                          const SizedBox(height: AppDimens.spaceM), // Removed const
                          _buildForgotPassword(),
                          const SizedBox(height: AppDimens.spaceL), // Removed const
                          _buildDivider(),
                          const SizedBox(height: AppDimens.spaceL), // Removed const
                          _buildRegisterLink(),
                          // إضافة فراغ في الأسفل
                          SizedBox(height: constraints.maxHeight * 0.15), // 15% من ارتفاع الشاشة
                        ] else ...[
                          const SizedBox(height: 12),
                          _buildCompactForgotPassword(),
                        ],
                      ],
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
    // أحجام مضغوطة أكثر
    final logoSize = isKeyboardVisible ? AppDimens.avatarSizeL : AppDimens.avatarSizeXL; // 56 : 64ish
    final titleSize = isKeyboardVisible ? AppDimens.textSizeL : AppDimens.textSizeXL; // 20 : 24
    final subtitleSize = isKeyboardVisible ? AppDimens.textSizeXS : AppDimens.textSizeS; // 12 : 14
    
    return Column(
      children: [
        // الشعار
        Container(
          width: logoSize,
          height: logoSize,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(isKeyboardVisible ? 10 : 14),
          ),
          child: Icon(
            Icons.calendar_today,
            size: logoSize * 0.5,
            color: Colors.white,
          ),
        ),
        SizedBox(height: isKeyboardVisible ? 8 : 16), // مسافة أقل
        
        // العنوان
        Text(
          context.l10n.welcomeBack,
          style: TextStyle(
            fontSize: titleSize,
            fontWeight: FontWeight.bold,
            color: AppColors.getTextPrimary(context),
          ),
        ),
        
        // الوصف - يختفي مع الكيبورد
        if (!isKeyboardVisible) ...[
          const SizedBox(height: AppDimens.spaceTiny), // Removed const
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

  Widget _buildLoginForm() {
    return Column(
      children: [
        // البريد الإلكتروني أو اسم المستخدم
        RawAutocomplete<String>(
          textEditingController: _identifierController,
          focusNode: _identifierFocusNode,
          optionsBuilder: (TextEditingValue textEditingValue) {
            final authProvider = context.read<AuthProvider>();
            final options = authProvider.recentUsernames;
            if (textEditingValue.text.isEmpty) {
              return options;
            }
            return options.where((String option) {
              return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
            });
          },
          onSelected: (String selection) {
            _passwordFocusNode.requestFocus();
          },
          fieldViewBuilder: (BuildContext context, TextEditingController textEditingController,
              FocusNode focusNode, VoidCallback onFieldSubmitted) {
            return AuthTextField(
              controller: textEditingController,
              focusNode: focusNode,
              label: context.l10n.emailOrUsername,
              hint: context.l10n.emailOrUsername,
              prefixIcon: Icons.person_outline,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) {
                // الانتقال لحقل كلمة المرور
                _passwordFocusNode.requestFocus();
              },
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return context.l10n.fieldRequired;
                }
                return null;
              },
            );
          },
          optionsViewBuilder: (BuildContext context, AutocompleteOnSelected<String> onSelected, Iterable<String> options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4.0,
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: 200,
                    maxWidth: MediaQuery.of(context).size.width - 48,
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (BuildContext context, int index) {
                      final String option = options.elementAt(index);
                      return InkWell(
                        onTap: () => onSelected(option),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
                          child: Row(
                            children: [
                              const Icon(Icons.history, size: 20, color: Colors.grey),
                              const SizedBox(width: 12),
                              Text(option, style: TextStyle(color: AppColors.getTextPrimary(context))),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: AppDimens.fontSizeCaption), // Removed const
        
        // كلمة المرور
        AuthTextField(
          controller: _passwordController,
          focusNode: _passwordFocusNode,
          label: context.l10n.password,
          hint: context.l10n.enterPassword,
          prefixIcon: Icons.lock_outline,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) {
            // تسجيل الدخول عند الضغط على Done
            _handleLogin();
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
              return context.l10n.invalidPassword;
            }
            return null;
          },
        ),
        // مسافة مناسبة بين كلمة المرور وزر الدخول
      ],
    );
  }

  Widget _buildLoginButton() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return AuthButton(
          text: context.l10n.login,
          isLoading: authProvider.isLoading,
          onPressed: _handleLogin,
        );
      },
    );
  }

  Widget _buildCompactForgotPassword() {
    return Align(
      alignment: Alignment.center,
      child: TextButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ForgotPasswordScreen(),
            ),
          );
        },
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          minimumSize: const Size(0, 32),
        ),
        child: Text(
          context.l10n.forgotPassword,
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildForgotPassword() {
    return Align(
      alignment: Alignment.center,
      child: TextButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ForgotPasswordScreen(),
            ),
          );
        },
        child: Text(
          context.l10n.forgotPassword,
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
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

  Widget _buildRegisterLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          context.l10n.noAccount,
          style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade400 : Colors.grey.shade600),
        ),
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const RegisterScreen(),
              ),
            );
          },
          child: Text(
            context.l10n.createNewAccount,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    final success = await authProvider.login(
      identifier: _identifierController.text.trim(),
      password: _passwordController.text,
    );

    // AuthWrapper يتولى التنقل تلقائياً عند تغيير الحالة إلى authenticated.
    // لا نحتاج Navigator هنا — التنقل المزدوج كان يسبب شاشة فارغة.
    if (!success && mounted && authProvider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage!),
          backgroundColor: AppColors.warning,
        ),
      );
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
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

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    _identifierFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }
}