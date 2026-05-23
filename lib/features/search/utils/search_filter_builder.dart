// 📍 lib/features/search/utils/search_filter_builder.dart
// 🔍 باني فلاتر البحث لضمان الخصوصية والتحكم الإداري

class SearchFilterBuilder {
  
  /// بناء فلتر البحث عن المستخدمين
  /// [query] نص البحث
  /// [showAdmins] هل تظهر حسابات المشرفين في النتائج؟
  /// بناء فلتر البحث عن المستخدمين بشكل مرن (يتجاهل الرموز وحالة الأحرف)
  static String buildUserSearchFilter({
    required String query,
    bool showAdmins = false,
  }) {
    // 1. تنظيف وتوحيد نص البحث (استبدال الرموز بمسافات والتقسيم لكلمات)
    final normalizedQuery = query.trim().toLowerCase().replaceAll(RegExp(r'[_\-\.,/\\|]'), ' ');
    final parts = normalizedQuery.split(' ').where((p) => p.isNotEmpty).toList();
    
    String filter = '';
    
    if (parts.isEmpty) {
      filter = 'hideFromSearch = false';
    } else {
      // بناء استعلام يبحث عن كل جزء من الكلمات في الاسم أو اسم المستخدم
      final List<String> nameConditions = [];
      final List<String> usernameConditions = [];
      
      for (var part in parts) {
        nameConditions.add('name ~ "$part"');
        usernameConditions.add('username ~ "$part"');
      }
      
      filter = '((${nameConditions.join(' && ')}) || (${usernameConditions.join(' && ')}))';
      filter += ' && hideFromSearch = false';
    }
    
    // 3. فلتر المشرفين والأدوار
    if (!showAdmins) {
      filter += ' && role != "admin"';
    }
    
    return filter;
  }

  /// بناء فلتر استكشاف المواعيد (Explore)
  /// يظهر فقط المواعيد العامة (Public)
  static String buildExploreAppointmentsFilter({String? userRegion}) {
    String filter = 'privacy = "public" && post_status = "published"';
    
    if (userRegion != null) {
      filter += ' && region = "$userRegion"';
    }
    
    return filter;
  }
}
