import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/hijri_service.dart';
import '../config/constants.dart';
import '../models/user_model.dart';
import 'login_screen.dart';
import 'internal_settings_screen.dart';

class EditableSettingsScreen extends StatefulWidget {
  const EditableSettingsScreen({super.key});

  @override
  State<EditableSettingsScreen> createState() => _EditableSettingsScreenState();
}

class _EditableSettingsScreenState extends State<EditableSettingsScreen> {
  final AuthService _authService = AuthService();
  final HijriService _hijriService = HijriService();
  final ImagePicker _picker = ImagePicker();

  // State management
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isRefreshing = false;
  
  // Image handling
  File? _selectedImage;
  Uint8List? _selectedImageBytes;

  // Hijri adjustment state
  int _currentHijriAdjustment = 0;
  int _originalHijriAdjustment = 0;

  // Field controllers organized in a map
  final Map<String, TextEditingController> _controllers = {
    'name': TextEditingController(),
    'username': TextEditingController(),
    'email': TextEditingController(),
    'phone': TextEditingController(),
    'socialLink': TextEditingController(),
    'bio': TextEditingController(),
    'joiningDate': TextEditingController(),
  };

  // Field configurations
  final List<EditableField> _editableFields = [
    EditableField(
      key: 'name',
      label: 'الاسم الكامل',
      icon: Icons.person_outline,
      editable: true,
    ),
    EditableField(
      key: 'username',
      label: 'اسم المستخدم',
      icon: Icons.alternate_email,
      editable: false,
    ),
    EditableField(
      key: 'email',
      label: 'البريد الإلكتروني',
      icon: Icons.email_outlined,
      editable: false,
      keyboardType: TextInputType.emailAddress,
    ),
    EditableField(
      key: 'phone',
      label: 'رقم الهاتف',
      icon: Icons.phone_outlined,
      editable: true,
      keyboardType: TextInputType.phone,
    ),
    EditableField(
      key: 'socialLink',
      label: 'الرابط الاجتماعي',
      icon: Icons.link_outlined,
      editable: true,
      keyboardType: TextInputType.url,
    ),
    EditableField(
      key: 'bio',
      label: 'نبذة شخصية',
      icon: Icons.info_outline,
      editable: true,
      maxLines: 3,
    ),
    EditableField(
      key: 'joiningDate',
      label: 'تاريخ الانضمام',
      icon: Icons.calendar_today_outlined,
      editable: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initAuth();
  }

  @override
  void dispose() {
    // Dispose all controllers
    _controllers.forEach((key, controller) => controller.dispose());
    super.dispose();
  }

  // Check if there are unsaved changes
  bool get _hasUnsavedChanges {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return false;

    return _currentHijriAdjustment != _originalHijriAdjustment ||
        _controllers['name']!.text != currentUser.name ||
        _controllers['phone']!.text != (currentUser.phone ?? '') ||
        _controllers['socialLink']!.text != (currentUser.socialLink ?? '') ||
        _controllers['bio']!.text != (currentUser.bio ?? '') ||
        _selectedImage != null ||
        _selectedImageBytes != null;
  }

  // Initialize authentication and user data
  Future<void> _initAuth({bool forceRefresh = false}) async {
    if (mounted) {
      setState(() {
        if (forceRefresh) {
          _isRefreshing = true;
        } else {
          _isLoading = true;
        }
      });
    }

    try {
      await _authService.initAuth(forceRefresh: forceRefresh);
      final user = _authService.currentUser;

      if (user != null) {
        await _loadUserData(user);
      }
    } catch (e) {
      _logError('فشل تحميل بيانات المستخدم', e);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  // Load user data into controllers
  Future<void> _loadUserData(UserModel user) async {
    _controllers['name']!.text = user.name;
    _controllers['username']!.text = user.username;
    _controllers['email']!.text = user.email;
    _controllers['phone']!.text = user.phone ?? '';
    _controllers['socialLink']!.text = user.socialLink ?? '';
    _controllers['bio']!.text = user.bio ?? '';

    // Display actual creation date for joining date
    if (user.createdDate != null) {
      final formatter = DateFormat('dd/MM/yyyy HH:mm');
      _controllers['joiningDate']!.text = formatter.format(user.createdDate!);
    } else {
      _controllers['joiningDate']!.text = user.joiningDate ?? '';
    }

    // Set hijri adjustment
    _currentHijriAdjustment = user.hijriAdjustment ?? 0;
    _originalHijriAdjustment = _currentHijriAdjustment;
    
    // Apply the adjustment immediately
    _hijriService.setTemporaryAdjustment(_currentHijriAdjustment);
  }

  // Save user data
  Future<void> _saveUserData() async {
    if (!mounted) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) return;

      // Prepare avatar file if selected
      dynamic avatarFile;
      final hasImage = _selectedImage != null || _selectedImageBytes != null;

      if (hasImage) {
        avatarFile = await _prepareAvatarFile();
      }

      // Update user data
      final updatedUser = await _authService.updateUser(
        name: _controllers['name']!.text.trim(),
        phone: _controllers['phone']!.text.trim(),
        socialLink: _controllers['socialLink']!.text.trim(),
        bio: _controllers['bio']!.text.trim(),
        hijriAdjustment: _currentHijriAdjustment,
        avatar: avatarFile,
      );

      // Update original values after successful save
      _originalHijriAdjustment = _currentHijriAdjustment;

      // Clear temporary files and exit edit mode
      setState(() {
        _isEditing = false;
        _selectedImage = null;
        _selectedImageBytes = null;
      });

      _showSuccessMessage(
        hasImage ? 'تم حفظ البيانات ورفع الصورة بنجاح' : 'تم حفظ البيانات بنجاح',
      );

    } catch (e) {
      _showErrorMessage('خطأ في حفظ البيانات: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // Prepare avatar file for upload
  Future<dynamic> _prepareAvatarFile() async {
    if (kIsWeb && _selectedImageBytes != null) {
      return http.MultipartFile.fromBytes(
        'avatar',
        _selectedImageBytes!,
        filename: 'avatar.jpg',
      );
    } else if (!kIsWeb && _selectedImage != null) {
      return await http.MultipartFile.fromPath(
        'avatar',
        _selectedImage!.path,
      );
    }
    return null;
  }

  // Pick image from gallery
  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        if (kIsWeb) {
          final bytes = await pickedFile.readAsBytes();
          setState(() {
            _selectedImageBytes = bytes;
            _selectedImage = null;
          });
        } else {
          setState(() {
            _selectedImage = File(pickedFile.path);
            _selectedImageBytes = null;
          });
        }
      }
    } catch (e) {
      _showErrorMessage('خطأ في اختيار الصورة: ${e.toString()}');
    }
  }

  // Update hijri adjustment
  void _updateHijriAdjustment(int newValue) {
    if (newValue != _currentHijriAdjustment) {
      setState(() {
        _currentHijriAdjustment = newValue;
        _hijriService.setTemporaryAdjustment(newValue);
      });
    }
  }

  // Cancel editing and reset to original values
  void _cancelEditing() {
    if (_hasUnsavedChanges) {
      _showDiscardChangesDialog();
    } else {
      _resetToOriginalValues();
    }
  }

  // Reset all values to original
  void _resetToOriginalValues() {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

    setState(() {
      _isEditing = false;
      _currentHijriAdjustment = _originalHijriAdjustment;
      _hijriService.setTemporaryAdjustment(_originalHijriAdjustment);
      
      _controllers['name']!.text = currentUser.name;
      _controllers['phone']!.text = currentUser.phone ?? '';
      _controllers['socialLink']!.text = currentUser.socialLink ?? '';
      _controllers['bio']!.text = currentUser.bio ?? '';
      
      _selectedImage = null;
      _selectedImageBytes = null;
    });
  }

  // Show discard changes dialog
  void _showDiscardChangesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تجاهل التغييرات؟'),
        content: const Text('لديك تغييرات غير محفوظة. هل تريد تجاهلها؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('البقاء'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resetToOriginalValues();
            },
            child: const Text(
              'تجاهل',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  // Logout user
  Future<void> _logout() async {
    try {
      await _authService.logout();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    } catch (e) {
      _showErrorMessage('خطأ في تسجيل الخروج: ${e.toString()}');
    }
  }

  // Helper methods for messages and logging
  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _logError(String message, dynamic error) {
    debugPrint('🚨 $message: $error');
  }

  // Get today's Hijri date with current adjustment
  String _getTodaysHijriDate() {
    return _hijriService.getTodayHijriString();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _authService.currentUser;

    if (_isLoading) {
      return _buildLoadingScreen();
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: SafeArea(
          child: Column(
            children: [
              _buildAppBar(currentUser),
              if (currentUser != null) _buildUserProfile(currentUser),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: const Center(
        child: CircularProgressIndicator(color: Color(0xFF2196F3)),
      ),
    );
  }

  Widget _buildAppBar(UserModel? currentUser) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'الإعدادات',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const InternalSettingsScreen(),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.settings,
                  color: Color(0xFF2196F3),
                  size: 24,
                ),
              ),
              if (currentUser != null) _buildEditSaveButtons(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditSaveButtons() {
    return _isEditing
        ? Row(
            children: [
              TextButton(
                onPressed: _cancelEditing,
                child: const Text(
                  'إلغاء',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              TextButton(
                onPressed: _isSaving ? null : _saveUserData,
                child: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'حفظ',
                        style: TextStyle(color: Color(0xFF2196F3)),
                      ),
              ),
            ],
          )
        : TextButton(
            onPressed: () {
              setState(() {
                _isEditing = true;
              });
            },
            child: const Text(
              'تحرير',
              style: TextStyle(color: Color(0xFF2196F3)),
            ),
          );
  }

  Widget _buildUserProfile(UserModel currentUser) {
    return Expanded(
      child: RefreshIndicator(
        onRefresh: () => _initAuth(forceRefresh: true),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_authService.needsSync) _buildSyncIndicator(),
              _buildAvatarSection(currentUser),
              const SizedBox(height: 24),
              ..._buildEditableFields(),
              const SizedBox(height: 16),
              _buildHijriAdjustmentField(),
              const SizedBox(height: 32),
              _buildLocalStorageInfo(),
              _buildLogoutButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSyncIndicator() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.sync_problem, size: 16, color: Colors.orange),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'يحتاج إلى مزامنة - اسحب للتحديث',
              style: TextStyle(fontSize: 12, color: Colors.orange),
            ),
          ),
          GestureDetector(
            onTap: () => _initAuth(forceRefresh: true),
            child: Text(
              'مزامنة',
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarSection(UserModel currentUser) {
    return Row(
      children: [
        GestureDetector(
          onTap: _isEditing ? _pickImage : null,
          child: Stack(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.shade200,
                  border: Border.all(color: const Color(0xFF2196F3), width: 2),
                ),
                child: _buildAvatarImage(currentUser),
              ),
              if (_isEditing)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2196F3),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt, size: 12, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            _isEditing ? 'تحرير البيانات الشخصية' : currentUser.name,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarImage(UserModel currentUser) {
    if (_selectedImageBytes != null) {
      return ClipOval(
        child: Image.memory(
          _selectedImageBytes!,
          fit: BoxFit.cover,
          width: 60,
          height: 60,
        ),
      );
    } else if (_selectedImage != null) {
      return ClipOval(
        child: Image.file(
          _selectedImage!,
          fit: BoxFit.cover,
          width: 60,
          height: 60,
        ),
      );
    } else if (currentUser.avatar != null && currentUser.avatar!.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          '${AppConstants.pocketbaseUrl}/api/files/${AppConstants.usersCollection}/${currentUser.id}/${currentUser.avatar!.replaceAll('[', '').replaceAll(']', '')}',
          fit: BoxFit.cover,
          width: 60,
          height: 60,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                    : null,
                strokeWidth: 2,
                color: const Color(0xFF2196F3),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            _logError('خطأ في تحميل الصورة', error);
            return Icon(Icons.person, size: 30, color: Colors.grey.shade600);
          },
        ),
      );
    } else {
      return Icon(Icons.person, size: 30, color: Colors.grey.shade600);
    }
  }

  List<Widget> _buildEditableFields() {
    return _editableFields.map((field) {
      return Column(
        children: [
          _buildEditableField(field),
          const SizedBox(height: 16),
        ],
      );
    }).toList();
  }

  Widget _buildEditableField(EditableField field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          field.label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: field.editable && _isEditing 
                  ? const Color(0xFF2196F3) 
                  : Colors.grey.shade300,
            ),
          ),
          child: TextFormField(
            controller: _controllers[field.key],
            enabled: field.editable && _isEditing,
            keyboardType: field.keyboardType,
            maxLines: field.maxLines,
            style: TextStyle(
              color: (field.editable && _isEditing) ? Colors.black87 : Colors.grey.shade700,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              prefixIcon: Icon(
                field.icon,
                color: (field.editable && _isEditing) 
                    ? const Color(0xFF2196F3) 
                    : Colors.grey.shade500,
                size: 20,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              hintText: (field.editable && _isEditing) ? 'أدخل ${field.label}' : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHijriAdjustmentField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'تصحيح التاريخ الهجري',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: _isEditing ? const Color(0xFF2196F3) : Colors.grey.shade300,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_month_outlined,
                  color: _isEditing ? const Color(0xFF2196F3) : Colors.grey.shade500,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _getTodaysHijriDate(),
                        style: TextStyle(
                          color: _isEditing ? Colors.black87 : Colors.grey.shade700,
                          fontSize: 14,
                        ),
                      ),
                      if (_isEditing) _buildHijriAdjustmentControls(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_isEditing) const SizedBox(height: 4),
        if (_isEditing) _buildHijriAdjustmentInfo(),
      ],
    );
  }

  Widget _buildHijriAdjustmentControls() {
    return Row(
      children: [
        IconButton(
          onPressed: _currentHijriAdjustment > -2 ? () {
            _updateHijriAdjustment(_currentHijriAdjustment - 1);
          } : null,
          icon: const Icon(Icons.remove),
          iconSize: 18,
          color: _currentHijriAdjustment > -2 ? const Color(0xFF2196F3) : Colors.grey,
        ),
        Container(
          width: 40,
          alignment: Alignment.center,
          child: Text(
            '$_currentHijriAdjustment',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        IconButton(
          onPressed: _currentHijriAdjustment < 2 ? () {
            _updateHijriAdjustment(_currentHijriAdjustment + 1);
          } : null,
          icon: const Icon(Icons.add),
          iconSize: 18,
          color: _currentHijriAdjustment < 2 ? const Color(0xFF2196F3) : Colors.grey,
        ),
      ],
    );
  }

  Widget _buildHijriAdjustmentInfo() {
    return Text(
      'لتصحيح التاريخ الهجري (من -2 إلى +2 أيام) - التصحيح الحالي: ${_currentHijriAdjustment >= 0 ? '+' : ''}$_currentHijriAdjustment',
      style: TextStyle(
        fontSize: 12,
        color: _currentHijriAdjustment != 0 ? Colors.blue.shade600 : Colors.grey.shade600,
        fontWeight: _currentHijriAdjustment != 0 ? FontWeight.w500 : FontWeight.normal,
      ),
    );
  }

  Widget _buildLocalStorageInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.offline_bolt, size: 16, color: Colors.blue),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'البيانات محفوظة محلياً - تعمل بدون إنترنت',
              style: TextStyle(fontSize: 12, color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Center(
      child: GestureDetector(
        onTap: _logout,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.logout, size: 16, color: Colors.red),
              const SizedBox(width: 8),
              Text(
                'تسجيل الخروج',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

// Supporting data class for editable fields
class EditableField {
  final String key;
  final String label;
  final IconData icon;
  final bool editable;
  final TextInputType? keyboardType;
  final int maxLines;

  const EditableField({
    required this.key,
    required this.label,
    required this.icon,
    required this.editable,
    this.keyboardType,
    this.maxLines = 1,
  });
}