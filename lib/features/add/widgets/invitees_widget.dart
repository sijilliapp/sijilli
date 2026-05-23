// 📍 lib/features/add/widgets/invitees_widget.dart
// 👥 إدارة المدعوين للموعد

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/user.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';

class InviteesWidget extends StatelessWidget {
  final VoidCallback onAddInvitees;
  final Function(int index) onRemoveInvitee;
  final List<UserModel> invitees;
  final bool isFirstComeFirstServed;
  final ValueChanged<bool> onFirstComeChanged;

  const InviteesWidget({
    super.key,
    required this.onAddInvitees,
    required this.onRemoveInvitee,
    required this.isFirstComeFirstServed,
    required this.onFirstComeChanged,
    this.invitees = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.inviteesLabel,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            
            if (invitees.isNotEmpty) ...[
              ...List.generate(invitees.length, (i) => _buildInviteeItem(i, invitees[i])),
              const SizedBox(height: 4),
              
              if (invitees.length >= 2) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.flash_on, color: AppColors.primary, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                context.l10n.priorityFeature,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            context.l10n.priorityFeatureDesc,
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: isFirstComeFirstServed, 
                      onChanged: onFirstComeChanged,
                      activeColor: AppColors.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ],
            
            if (invitees.length < 5) 
            _buildAddInviteesButton(context),
            
            if (invitees.length >= 5) ...[
              const SizedBox(height: 4),
              Center(
                child: Text(
                  context.l10n.maxInviteesWarning,
                  style: const TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInviteeItem(int index, UserModel user) {
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final avatarUrl = user.getAvatarUrl('https://sijilli.pockethost.io');

        return Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey.shade800 : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade200),
          ),
          child: Row(
            children: [
              ClipOval(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: avatarUrl != null
                      ? Image.network(avatarUrl, fit: BoxFit.cover)
                      : Container(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          child: const Icon(Icons.person, size: 16, color: AppColors.primary),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  user.name.isNotEmpty ? user.name : user.username,
                  style: TextStyle(
                    fontWeight: FontWeight.w500, 
                    fontSize: 13,
                    color: isDark ? Colors.white : Colors.black87
                  ),
                ),
              ),
              IconButton(
                onPressed: () => onRemoveInvitee(index),
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
                icon: const Icon(
                  Icons.remove_circle,
                  size: 20,
                  color: Colors.redAccent,
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildAddInviteesButton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onAddInvitees,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.person_add, color: AppColors.primary),
            const SizedBox(width: 12),
            Text(
              context.l10n.addInviteesHint,
              style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.black87),
            ),
          ],
        ),
      ),
    );
  }
}
