import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/extensions/context_l10n.dart';
import '../../../core/providers/global_config_provider.dart';
import 'login_screen.dart';

/// 🔒 شاشة "التسجيل مغلق" - تظهر عندما يعطل المالك التسجيل من لوحة التحكم
class RegistrationClosedScreen extends StatelessWidget {
  const RegistrationClosedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.getTextPrimary(context),
            size: 20,
          ),
          onPressed: () => _navigateToLogin(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceXL),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 🎨 أيقونة الحالة (رسمة توضيحية بسيطة ومتميزة)
              _buildIconSection(context),
              
              const SizedBox(height: AppDimens.spaceXL),
              
              // 📝 العنوان والرسالة
              Text(
                context.l10n.registrationClosedTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextPrimary(context),
                ),
              ),
              const SizedBox(height: AppDimens.space),
              Text(
                context.l10n.registrationClosedMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.getTextSecondary(context),
                  height: 1.5,
                ),
              ),
              
              const SizedBox(height: AppDimens.spaceXXL),
              
              // 📞 قسم التواصل
              _buildContactSection(context, isDark),
              
              const Spacer(),
              
              // 🔙 زر العودة لتسجيل الدخول
              _buildBackButton(context),
              const SizedBox(height: AppDimens.spaceXL),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconSection(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // دوائر مشعة في الخلفية
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
        ),
        // الأيقونة الأساسية
        const Icon(
          Icons.shield_outlined,
          size: 70,
          color: AppColors.primary,
        ),
        // أيقونة القفل الصغيرة
        Positioned(
          bottom: 15,
          right: 15,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: AppColors.alert,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock,
              size: 20,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContactSection(BuildContext context, bool isDark) {
    final config = context.read<GlobalConfigProvider>();
    final whatsapp = config.contactWhatsApp.replaceAll('+', '').trim();
    final email = config.contactEmail.trim();

    return Column(
      children: [
        Text(
          context.l10n.contactUsForInvite,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.getTextPrimary(context).withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: AppDimens.spaceL),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildContactCard(
              context: context,
              icon: Icons.chat_bubble_outline,
              label: context.l10n.whatsapp,
              color: const Color(0xFF25D366),
              onTap: () async {
                final url = Uri.parse('https://wa.me/$whatsapp');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
            ),
            const SizedBox(width: AppDimens.spaceL),
            _buildContactCard(
              context: context,
              icon: Icons.alternate_email,
              label: context.l10n.ourEmail,
              color: AppColors.primary,
              onTap: () async {
                final url = Uri.parse('mailto:$email');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildContactCard({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 120,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.getTextPrimary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: () => _navigateToLogin(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radius),
          ),
        ),
        child: Text(
          context.l10n.backToLogin,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _navigateToLogin(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }
}
