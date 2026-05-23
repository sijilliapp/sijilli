// 📍 lib/features/admin/screens/admin_users_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/local/local_db_service.dart';
import '../../../core/widgets/pulse_avatar.dart';
import '../providers/admin_provider.dart';
import '../../../models/user.dart';
import 'admin_user_edit_screen.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<UserModel> _recentSearches = [];

  @override
  void initState() {
    super.initState();
    // تنظيف نتائج البحث السابقة فور الفتح لتبدأ الواجهة نظيفة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().clearUserSearch();
    });
    // تحميل عمليات البحث الأخيرة المخزنة محلياً
    _loadRecentSearches();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadRecentSearches() async {
    try {
      final recent = await LocalDbService.instance.getRecentSearches();
      if (mounted) {
        setState(() {
          _recentSearches = recent;
        });
      }
    } catch (e) {
      debugPrint('Error loading recent searches: $e');
    }
  }

  Future<void> _saveRecentSearch(UserModel user) async {
    try {
      await LocalDbService.instance.saveRecentSearch(user);
      _loadRecentSearches();
    } catch (e) {
      debugPrint('Error saving recent search: $e');
    }
  }

  Future<void> _clearRecentSearches() async {
    try {
      final box = await LocalDbService.instance.recentSearchesBox;
      await box?.clear();
      _loadRecentSearches();
    } catch (e) {
      debugPrint('Error clearing recent searches: $e');
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        context.read<AdminProvider>().searchUsers(query);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'إدارة المشتركين',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 🔎 حقل البحث الأنيق
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'ابحث بالاسم أو اسم المستخدم...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            _searchController.clear();
                            context.read<AdminProvider>().clearUserSearch();
                            _loadRecentSearches();
                            setState(() {});
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark ? AppColors.darkSurface : Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),
            ),

            // 📜 نتائج البحث أو عمليات البحث الأخيرة
            Expanded(
              child: Consumer<AdminProvider>(
                builder: (context, admin, child) {
                  if (admin.isSearchingUsers) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  // إذا كان حقل البحث فارغاً، نعرض قائمة آخر المبحوث عنهم
                  if (_searchController.text.trim().isEmpty) {
                    if (_recentSearches.isEmpty) {
                      return _buildInitialState(isDark);
                    }
                    return _buildRecentSearchesSection(isDark);
                  }

                  if (admin.userSearchResults.isEmpty) {
                    return _buildEmptyState(isDark);
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: admin.userSearchResults.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final user = admin.userSearchResults[index];
                      return _buildUserCard(context, user, isDark);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentSearchesSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'آخر المبحوث عنهم',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                ),
              ),
              TextButton(
                onPressed: _clearRecentSearches,
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'مسح الكل',
                  style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _recentSearches.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final user = _recentSearches[index];
              return _buildUserCard(context, user, isDark);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUserCard(BuildContext context, UserModel user, bool isDark) {
    // تحديد شارة الصلاحية واللون
    Color roleColor;
    String roleLabel;
    switch (user.role) {
      case 'admin':
        roleColor = Colors.amber.shade800;
        roleLabel = 'مشرف عام';
        break;
      case 'approved':
        roleColor = AppColors.primary;
        roleLabel = 'معتمد';
        break;
      default:
        roleColor = Colors.grey;
        roleLabel = 'مستخدم عادي';
    }

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          width: 1,
        ),
      ),
      color: isDark ? AppColors.darkSurface : Colors.white,
      child: InkWell(
        onTap: () async {
          // حفظ هذا المستخدم في آخر المبحوث عنهم
          await _saveRecentSearch(user);

          if (!mounted) return;

          // الانتقال لشاشة التعديل والتحكم
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AdminUserEditScreen(user: user),
            ),
          );
          // بعد العودة، نحدث البحث لرؤية التغييرات المطبقة
          if (mounted) {
            if (_searchController.text.isNotEmpty) {
              context.read<AdminProvider>().searchUsers(_searchController.text);
            } else {
              _loadRecentSearches();
            }
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              PulseAvatar(
                image: user.getAvatarUrl('https://sijilli.pockethost.io') != null
                    ? NetworkImage(user.getAvatarUrl('https://sijilli.pockethost.io')!)
                    : null,
                size: 40,
                status: AvatarStatus.none,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: roleColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: roleColor.withValues(alpha: 0.15)),
                          ),
                          child: Text(
                            roleLabel,
                            style: TextStyle(
                              color: roleColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${user.username}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: Theme.of(context).dividerColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInitialState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search_rounded,
              size: 70,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'ابحث عن مشترك',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'اكتب الحروف الأولى من اسم المشترك أو معرفه للبدء.',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_search_outlined,
              size: 70,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'لم نجد أي نتائج!',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'تأكد من كتابة الاسم أو اسم المستخدم بشكل صحيح.',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
