import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'config/constants.dart';

class TestImageScreen extends StatefulWidget {
  const TestImageScreen({super.key});

  @override
  State<TestImageScreen> createState() => _TestImageScreenState();
}

class _TestImageScreenState extends State<TestImageScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    await _authService.initAuth();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  String? _getUserAvatarUrl(dynamic user) {
    if (user?.avatar == null || user.avatar.isEmpty) {
      return null;
    }
    
    // استخدام نفس الطريقة المستخدمة في الإعدادات
    final cleanAvatar = user.avatar.replaceAll('[', '').replaceAll(']', '').replaceAll('"', '');
    return '${AppConstants.pocketbaseUrl}/api/files/${AppConstants.usersCollection}/${user.id}/$cleanAvatar';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('اختبار الصورة'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final user = _authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('اختبار الصورة'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('معلومات المستخدم:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            
            if (user != null) ...[
              Text('الاسم: ${user.name}'),
              Text('ID: ${user.id}'),
              Text('الصورة الخام: ${user.avatar ?? "لا توجد"}'),
              Text('نوع البيانات: ${user.avatar.runtimeType}'),
              if (_getUserAvatarUrl(user) != null)
                Text('الرابط: ${_getUserAvatarUrl(user)}'),
              
              const SizedBox(height: 20),
              const Text('اختبار عرض الصورة:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              
              // اختبار 1: الطريقة الحالية
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _getUserAvatarUrl(user) != null
                    ? Image.network(
                        _getUserAvatarUrl(user)!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Text('خطأ في التحميل', style: TextStyle(color: Colors.red)),
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(child: CircularProgressIndicator());
                        },
                      )
                    : const Center(child: Text('لا توجد صورة')),
              ),
              
              const SizedBox(height: 20),
              
              // اختبار 2: الطريقة المستخدمة في الإعدادات
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.green, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: user.avatar != null && user.avatar!.isNotEmpty
                    ? Image.network(
                        '${AppConstants.pocketbaseUrl}/api/files/${AppConstants.usersCollection}/${user.id}/${user.avatar!.replaceAll('[', '').replaceAll(']', '')}',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Text('خطأ في التحميل', style: TextStyle(color: Colors.red)),
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(child: CircularProgressIndicator());
                        },
                      )
                    : const Center(child: Text('لا توجد صورة')),
              ),

              const SizedBox(height: 20),

              // معلومات إضافية
              const Text('معلومات إضافية:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              Text('PocketHost URL: ${AppConstants.pocketbaseUrl}'),
              Text('Users Collection: ${AppConstants.usersCollection}'),
              const Text('ملاحظة: نجلب من PocketHost ونحفظ في Cache محلي',
                   style: TextStyle(fontSize: 12, color: Colors.blue, fontStyle: FontStyle.italic)),

            ] else ...[
              const Text('لم يتم تسجيل الدخول'),
              ElevatedButton(
                onPressed: () => _authService.initAuth(forceRefresh: true),
                child: const Text('إعادة تحميل البيانات'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
