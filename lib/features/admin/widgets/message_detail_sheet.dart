// 📍 lib/features/admin/widgets/message_detail_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/utils/app_date_formatter.dart';
import '../../../core/widgets/pulse_avatar.dart';
import '../../../models/contact_message.dart';
import '../providers/admin_provider.dart';
import '../../../core/extensions/context_l10n.dart';

void showMessageDetailSheet(BuildContext context, ContactMessageModel message) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _MessageDetailSheet(message: message),
  );
}

class _MessageDetailSheet extends StatefulWidget {
  final ContactMessageModel message;

  const _MessageDetailSheet({required this.message});

  @override
  State<_MessageDetailSheet> createState() => _MessageDetailSheetState();
}

class _MessageDetailSheetState extends State<_MessageDetailSheet> {
  bool _isUpdating = false;
  late String _currentStatus;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.message.status;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasUser = widget.message.user != null;
    final senderName = hasUser ? widget.message.user!.name : context.l10n.unregisteredVisitor;
    final username = hasUser ? '@${widget.message.user!.username}' : context.l10n.unknown;

    // الألوان والأيقونات الخاصة بنوع الرسالة
    Color typeColor;
    String typeLabel;
    switch (widget.message.type) {
      case 'suggestion':
        typeColor = Colors.green;
        typeLabel = context.l10n.messageTypeSuggestion;
        break;
      case 'complaint':
        typeColor = Colors.red;
        typeLabel = context.l10n.messageTypeComplaint;
        break;
      case 'inquiry':
        typeColor = Colors.blue;
        typeLabel = context.l10n.messageTypeInquiry;
        break;
      default:
        typeColor = Colors.orange;
        typeLabel = context.l10n.messageTypeOther;
    }

    final statusOptions = [
      {'key': 'new', 'label': '${context.l10n.messageStatusNew} 🆕'},
      {'key': 'read', 'label': '${context.l10n.messageStatusRead} 👁️'},
      {'key': 'replied', 'label': '${context.l10n.messageStatusReplied} 💬'},
      {'key': 'closed', 'label': '${context.l10n.messageStatusClosed} 🔒'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 8,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ➖ مقبض السحب العلوي
            Center(
              child: Container(
                width: 40,
                height: 4.5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // 🏷️ نوع الرسالة الحالي
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: typeColor.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    typeLabel,
                    style: TextStyle(
                      color: typeColor,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  AppDateFormatter.formatFullDateTime(widget.message.created, Localizations.localeOf(context).languageCode),
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // 📌 عنوان الرسالة
            Text(
              widget.message.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 12),
            
            // 💬 صندوق محتوى الرسالة
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900.withValues(alpha: 0.5) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                ),
              ),
              constraints: const BoxConstraints(maxHeight: 220),
              child: Scrollbar(
                thumbVisibility: true,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    Text(
                      widget.message.message,
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            const Divider(height: 1),
            
            const SizedBox(height: 16),
            
            // 👤 معلومات المرسل
            Text(
              context.l10n.messageSenderHeader,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            
            const SizedBox(height: 8),
            
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900.withValues(alpha: 0.3) : Colors.grey.shade50.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.grey.shade800.withValues(alpha: 0.5) : Colors.grey.shade200.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  PulseAvatar(
                    image: hasUser && widget.message.user!.getAvatarUrl('https://sijilli.pockethost.io') != null
                        ? NetworkImage(widget.message.user!.getAvatarUrl('https://sijilli.pockethost.io')!)
                        : null,
                    size: 40,
                    status: AvatarStatus.none,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          senderName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          username,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (hasUser) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'يتم الرد على هذا المشترك خارج التطبيق عبر البريد الإلكتروني أو الواتساب الموضحين أدناه.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.amber.shade200 : Colors.amber.shade800,
                              height: 1.4,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (widget.message.user!.email.isNotEmpty)
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.grey.withOpacity(0.3)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                              icon: const Icon(Icons.email_outlined, size: 16),
                              label: const Text('نسخ البريد', style: TextStyle(fontSize: 12)),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: widget.message.user!.email));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('تم نسخ البريد الإلكتروني بنجاح')),
                                );
                              },
                            ),
                          ),
                        if (widget.message.user!.email.isNotEmpty && widget.message.user!.phone != null && widget.message.user!.phone!.isNotEmpty)
                          const SizedBox(width: 8),
                        if (widget.message.user!.phone != null && widget.message.user!.phone!.isNotEmpty)
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.grey.withOpacity(0.3)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                              icon: const Icon(Icons.phone_outlined, size: 16),
                              label: const Text('نسخ الهاتف', style: TextStyle(fontSize: 12)),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: widget.message.user!.phone!));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('تم نسخ رقم الهاتف بنجاح')),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 24),
            
            // ⚙️ تغيير حالة الرسالة
            Row(
              children: [
                const Icon(Icons.settings_outlined, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  context.l10n.updateMessageStatusTitle,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _currentStatus,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                        ),
                      ),
                      filled: true,
                      fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
                    ),
                    items: statusOptions.map((opt) {
                      return DropdownMenuItem<String>(
                        value: opt['key'],
                        child: Text(opt['label']!),
                      );
                    }).toList(),
                    onChanged: _isUpdating ? null : (val) async {
                      if (val != null && val != _currentStatus) {
                        setState(() {
                          _isUpdating = true;
                        });
                        
                        final success = await context.read<AdminProvider>().updateMessageStatus(
                          widget.message.id,
                          val,
                        );
                        
                        if (mounted) {
                          setState(() {
                            _isUpdating = false;
                            if (success) {
                              _currentStatus = val;
                            }
                          });
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(success ? context.l10n.messageStatusUpdateSuccess : context.l10n.messageStatusUpdateFailed),
                              backgroundColor: success ? Colors.green : Colors.red,
                            ),
                          );
                        }
                      }
                    },
                  ),
                ),
                if (_isUpdating) ...[
                  const SizedBox(width: 16),
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ],
              ],
            ),
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
