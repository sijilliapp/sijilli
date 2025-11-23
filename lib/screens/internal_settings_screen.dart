import 'package:flutter/material.dart';
import 'deleted_appointments_screen.dart';

class InternalSettingsScreen extends StatefulWidget {
  const InternalSettingsScreen({super.key});

  @override
  State<InternalSettingsScreen> createState() => _InternalSettingsScreenState();
}

class _InternalSettingsScreenState extends State<InternalSettingsScreen> {
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;
  String _selectedLanguage = 'العربية';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'الإعدادات المتقدمة',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Notifications Section
            _buildSectionCard(
              title: 'الإشعارات',
              children: [
                _buildSwitchTile(
                  title: 'تفعيل الإشعارات',
                  subtitle: 'استقبال إشعارات المواعيد الجديدة',
                  value: _notificationsEnabled,
                  onChanged: (value) {
                    setState(() {
                      _notificationsEnabled = value;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Appearance Section
            _buildSectionCard(
              title: 'المظهر',
              children: [
                _buildSwitchTile(
                  title: 'الوضع الليلي',
                  subtitle: 'تغيير المظهر إلى الوضع الليلي',
                  value: _darkModeEnabled,
                  onChanged: (value) {
                    setState(() {
                      _darkModeEnabled = value;
                    });
                  },
                ),
                const Divider(height: 1),
                _buildLanguageTile(),
              ],
            ),
            const SizedBox(height: 16),

            // Privacy Section
            _buildSectionCard(
              title: 'الخصوصية والأمان',
              children: [
                _buildActionTile(
                  icon: Icons.lock_outline,
                  title: 'تغيير كلمة المرور',
                  subtitle: 'تحديث كلمة مرور حسابك',
                  onTap: () {
                    // TODO: Navigate to change password screen
                    _showComingSoonSnackBar('تغيير كلمة المرور');
                  },
                ),
                const Divider(height: 1),
                _buildActionTile(
                  icon: Icons.security_outlined,
                  title: 'إعدادات الخصوصية',
                  subtitle: 'التحكم في من يمكنه رؤية معلوماتك',
                  onTap: () {
                    // TODO: Navigate to privacy settings
                    _showComingSoonSnackBar('إعدادات الخصوصية');
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Data Management Section
            _buildSectionCard(
              title: 'إدارة البيانات',
              children: [
                _buildActionTile(
                  icon: Icons.delete_outline,
                  title: 'المحذوفات',
                  subtitle: 'عرض المواعيد المحذوفة',
                  onTap: () {
                    _navigateToDeletedAppointments();
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Support Section
            _buildSectionCard(
              title: 'الدعم والمساعدة',
              children: [
                _buildActionTile(
                  icon: Icons.help_outline,
                  title: 'مركز المساعدة',
                  subtitle: 'الأسئلة الشائعة والدعم الفني',
                  onTap: () {
                    _showComingSoonSnackBar('مركز المساعدة');
                  },
                ),
                const Divider(height: 1),
                _buildActionTile(
                  icon: Icons.feedback_outlined,
                  title: 'إرسال ملاحظات',
                  subtitle: 'شاركنا رأيك واقتراحاتك',
                  onTap: () {
                    _showComingSoonSnackBar('إرسال الملاحظات');
                  },
                ),
                const Divider(height: 1),
                _buildActionTile(
                  icon: Icons.info_outline,
                  title: 'حول التطبيق',
                  subtitle: 'معلومات النسخة والفريق',
                  onTap: () {
                    _showAboutDialog();
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: const Color(0xFF2196F3),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Icon(icon, color: const Color(0xFF2196F3), size: 24),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Colors.grey.shade400,
      ),
      onTap: onTap,
    );
  }

  Widget _buildLanguageTile() {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: const Icon(Icons.language, color: Color(0xFF2196F3), size: 24),
      title: const Text(
        'اللغة',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      subtitle: Text(
        _selectedLanguage,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Colors.grey.shade400,
      ),
      onTap: () {
        _showLanguageSelector();
      },
    );
  }

  void _showLanguageSelector() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'اختر اللغة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('العربية'),
              trailing: _selectedLanguage == 'العربية'
                  ? const Icon(Icons.check, color: Color(0xFF2196F3))
                  : null,
              onTap: () {
                setState(() {
                  _selectedLanguage = 'العربية';
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('English'),
              trailing: _selectedLanguage == 'English'
                  ? const Icon(Icons.check, color: Color(0xFF2196F3))
                  : null,
              onTap: () {
                setState(() {
                  _selectedLanguage = 'English';
                });
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showComingSoonSnackBar(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature - قريباً'),
        backgroundColor: const Color(0xFF2196F3),
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حول سجلي'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('النسخة: 1.0.0'),
            SizedBox(height: 8),
            Text('تطبيق سجلي لإدارة المواعيد والأحداث'),
            SizedBox(height: 8),
            Text('© 2024 فريق سجلي'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('موافق'),
          ),
        ],
      ),
    );
  }

  void _navigateToDeletedAppointments() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const DeletedAppointmentsScreen(),
      ),
    );
  }
}
