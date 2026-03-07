import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import 'package:sijilli/l10n/app_localizations.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 💡 Prevent text from being hidden behind system status bar (safe area)
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(context.l10n.termsAndConditions),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSection(
                context.l10n.privacyIntroTitle,
                context.l10n.privacyIntroContent,
              ),
              _buildSection(
                context.l10n.privacyDataTitle,
                context.l10n.privacyDataContent,
              ),
              _buildSection(
                context.l10n.privacySecurityTitle,
                context.l10n.privacySecurityContent,
              ),
              _buildSection(
                context.l10n.privacyUsageTitle,
                context.l10n.privacyUsageContent,
              ),
              _buildSection(
                context.l10n.privacyUGCTitle,
                context.l10n.privacyUGCContent,
              ),
              _buildSection(
                context.l10n.privacyChildrenTitle,
                context.l10n.privacyChildrenContent,
              ),
              _buildSection(
                context.l10n.privacyDeletionTitle,
                context.l10n.privacyDeletionContent,
              ),
              _buildSection(
                context.l10n.privacySharingTitle,
                context.l10n.privacySharingContent,
              ),
              const SizedBox(height: 30),
              Center(
                child: SelectableText(
                  context.l10n.privacyContact,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: SelectableText(
                  context.l10n.privacyLastUpdate,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 10),
          SelectableText(
            content,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade800,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
