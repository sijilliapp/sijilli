#!/bin/bash

# 🎨 نص توليد القوالب - مشروع سجلي

# ألوان للإخراج
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# دالة المساعدة
show_help() {
    echo "🎨 مولد القوالب - مشروع سجلي"
    echo ""
    echo "الاستخدام:"
    echo "  ./generate_template.sh [النوع] [الاسم]"
    echo ""
    echo "الأنواع المتاحة:"
    echo "  feature    - إنشاء ميزة جديدة كاملة"
    echo "  screen     - إنشاء شاشة جديدة"
    echo "  widget     - إنشاء عنصر واجهة"
    echo "  service    - إنشاء خدمة جديدة"
    echo "  model      - إنشاء نموذج بيانات"
    echo "  provider   - إنشاء مزود حالة"
    echo ""
    echo "أمثلة:"
    echo "  ./generate_template.sh feature notes"
    echo "  ./generate_template.sh screen profile_edit"
    echo "  ./generate_template.sh widget custom_button"
    echo "  ./generate_template.sh service notification"
    echo ""
}

# التحقق من المعاملات
if [ $# -lt 2 ]; then
    show_help
    exit 1
fi

TYPE=$1
NAME=$2

# تحويل الاسم إلى تنسيقات مختلفة
SNAKE_CASE=$(echo "$NAME" | sed 's/\([A-Z]\)/_\L\1/g' | sed 's/^_//')
PASCAL_CASE=$(echo "$NAME" | sed 's/_\([a-z]\)/\U\1/g' | sed 's/^[a-z]/\U&/')
CAMEL_CASE=$(echo "$PASCAL_CASE" | sed 's/^[A-Z]/\L&/')

print_info "إنشاء $TYPE باسم: $NAME"
print_info "Snake case: $SNAKE_CASE"
print_info "Pascal case: $PASCAL_CASE"
print_info "Camel case: $CAMEL_CASE"

# دالة إنشاء ميزة كاملة
generate_feature() {
    local feature_name=$1
    local feature_dir="lib/features/$feature_name"
    
    print_info "إنشاء ميزة: $feature_name"
    
    # إنشاء المجلدات
    mkdir -p "$feature_dir/screens"
    mkdir -p "$feature_dir/widgets"
    mkdir -p "$feature_dir/providers"
    mkdir -p "$feature_dir/services"
    
    # إنشاء الشاشة الرئيسية
    cat > "$feature_dir/screens/${feature_name}_screen.dart" << EOF
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/${feature_name}_provider.dart';
import '../widgets/${feature_name}_list.dart';
import '../../core/widgets/loading_widget.dart';
import '../../core/widgets/error_widget.dart';
import '../../core/constants/app_strings.dart';

/// شاشة $feature_name الرئيسية
class ${PASCAL_CASE}Screen extends StatelessWidget {
  const ${PASCAL_CASE}Screen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<${PASCAL_CASE}Provider>(
      builder: (context, provider, child) {
        return Scaffold(
          appBar: _buildAppBar(),
          body: _buildBody(provider),
          floatingActionButton: _buildFAB(context, provider),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(AppStrings.${CAMEL_CASE}Title),
    );
  }

  Widget _buildBody(${PASCAL_CASE}Provider provider) {
    if (provider.isLoading) {
      return const LoadingWidget();
    }

    if (provider.hasError) {
      return ErrorWidget(
        message: provider.errorMessage,
        onRetry: provider.retry,
      );
    }

    return ${PASCAL_CASE}List(items: provider.items);
  }

  Widget? _buildFAB(BuildContext context, ${PASCAL_CASE}Provider provider) {
    return FloatingActionButton(
      onPressed: () => provider.add${PASCAL_CASE}(),
      child: const Icon(Icons.add),
    );
  }
}
EOF

    # إنشاء المزود
    cat > "$feature_dir/providers/${feature_name}_provider.dart" << EOF
import 'package:flutter/foundation.dart';
import '../services/${feature_name}_service.dart';
import '../../models/${feature_name}_model.dart';

/// مزود حالة $feature_name
class ${PASCAL_CASE}Provider extends ChangeNotifier {
  final ${PASCAL_CASE}Service _service = ${PASCAL_CASE}Service();

  List<${PASCAL_CASE}Model> _items = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<${PASCAL_CASE}Model> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  bool get hasError => _errorMessage != null;
  String? get errorMessage => _errorMessage;

  /// تحميل البيانات
  Future<void> loadItems() async {
    _setLoading(true);
    _setError(null);

    try {
      _items = await _service.getItems();
    } catch (e) {
      _setError('فشل في تحميل البيانات: \$e');
    } finally {
      _setLoading(false);
    }
  }

  /// إضافة عنصر جديد
  Future<void> add${PASCAL_CASE}() async {
    try {
      final newItem = await _service.createItem();
      _items.add(newItem);
      notifyListeners();
    } catch (e) {
      _setError('فشل في إضافة العنصر: \$e');
    }
  }

  /// إعادة المحاولة
  Future<void> retry() async {
    await loadItems();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }
}
EOF

    # إنشاء الخدمة
    cat > "$feature_dir/services/${feature_name}_service.dart" << EOF
import 'package:flutter/foundation.dart';
import '../../core/services/pocketbase_service.dart';
import '../../models/${feature_name}_model.dart';

/// خدمة $feature_name
class ${PASCAL_CASE}Service {
  static final ${PASCAL_CASE}Service _instance = ${PASCAL_CASE}Service._internal();
  factory ${PASCAL_CASE}Service() => _instance;
  ${PASCAL_CASE}Service._internal();

  final PocketBaseService _pocketBase = PocketBaseService();

  /// جلب جميع العناصر
  Future<List<${PASCAL_CASE}Model>> getItems() async {
    try {
      debugPrint('🔍 جلب عناصر $feature_name...');
      
      final response = await _pocketBase.collection('${feature_name}s').getList();
      
      final items = response.items
          .map((item) => ${PASCAL_CASE}Model.fromJson(item.toJson()))
          .toList();

      debugPrint('✅ تم جلب \${items.length} عنصر');
      return items;
    } catch (e) {
      debugPrint('❌ خطأ في جلب العناصر: \$e');
      rethrow;
    }
  }

  /// إنشاء عنصر جديد
  Future<${PASCAL_CASE}Model> createItem() async {
    try {
      debugPrint('➕ إنشاء عنصر $feature_name جديد...');
      
      final response = await _pocketBase.collection('${feature_name}s').create(
        body: {
          'title': 'عنصر جديد',
          'created': DateTime.now().toIso8601String(),
        },
      );

      final item = ${PASCAL_CASE}Model.fromJson(response.toJson());
      
      debugPrint('✅ تم إنشاء العنصر بنجاح');
      return item;
    } catch (e) {
      debugPrint('❌ خطأ في إنشاء العنصر: \$e');
      rethrow;
    }
  }
}
EOF

    # إنشاء عنصر القائمة
    cat > "$feature_dir/widgets/${feature_name}_list.dart" << EOF
import 'package:flutter/material.dart';
import '../../models/${feature_name}_model.dart';
import '${feature_name}_item.dart';

/// قائمة عناصر $feature_name
class ${PASCAL_CASE}List extends StatelessWidget {
  final List<${PASCAL_CASE}Model> items;

  const ${PASCAL_CASE}List({
    super.key,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: Text('لا توجد عناصر'),
      );
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        return ${PASCAL_CASE}Item(item: items[index]);
      },
    );
  }
}
EOF

    # إنشاء عنصر واحد
    cat > "$feature_dir/widgets/${feature_name}_item.dart" << EOF
import 'package:flutter/material.dart';
import '../../models/${feature_name}_model.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';

/// عنصر $feature_name واحد
class ${PASCAL_CASE}Item extends StatelessWidget {
  final ${PASCAL_CASE}Model item;

  const ${PASCAL_CASE}Item({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimens.padding,
        vertical: AppDimens.paddingSmall,
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary,
          child: Text(item.title.substring(0, 1)),
        ),
        title: Text(item.title),
        subtitle: Text(item.description ?? ''),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {
          // التنقل لتفاصيل العنصر
        },
      ),
    );
  }
}
EOF

    print_success "✅ تم إنشاء ميزة $feature_name بنجاح!"
    print_info "📁 الملفات المنشأة:"
    echo "   - $feature_dir/screens/${feature_name}_screen.dart"
    echo "   - $feature_dir/providers/${feature_name}_provider.dart"
    echo "   - $feature_dir/services/${feature_name}_service.dart"
    echo "   - $feature_dir/widgets/${feature_name}_list.dart"
    echo "   - $feature_dir/widgets/${feature_name}_item.dart"
    echo ""
    print_warning "📝 لا تنس:"
    echo "   1. إنشاء النموذج في lib/models/${feature_name}_model.dart"
    echo "   2. إضافة النصوص في lib/core/constants/app_strings.dart"
    echo "   3. إضافة التوجيه في lib/routes/"
    echo "   4. تسجيل المزود في main.dart"
}

# دالة إنشاء شاشة
generate_screen() {
    local screen_name=$1
    local screen_file="lib/screens/${screen_name}_screen.dart"
    
    print_info "إنشاء شاشة: $screen_name"
    
    mkdir -p "lib/screens"
    
    cat > "$screen_file" << EOF
import 'package:flutter/material.dart';
import '../core/constants/app_strings.dart';
import '../core/constants/app_colors.dart';

/// شاشة $screen_name
class ${PASCAL_CASE}Screen extends StatelessWidget {
  const ${PASCAL_CASE}Screen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(AppStrings.${CAMEL_CASE}Title),
      backgroundColor: AppColors.primary,
    );
  }

  Widget _buildBody() {
    return const Center(
      child: Text('شاشة $screen_name'),
    );
  }
}
EOF

    print_success "✅ تم إنشاء الشاشة: $screen_file"
}

# دالة إنشاء عنصر واجهة
generate_widget() {
    local widget_name=$1
    local widget_file="lib/widgets/${widget_name}_widget.dart"
    
    print_info "إنشاء عنصر واجهة: $widget_name"
    
    mkdir -p "lib/widgets"
    
    cat > "$widget_file" << EOF
import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_dimens.dart';

/// عنصر واجهة $widget_name
class ${PASCAL_CASE}Widget extends StatelessWidget {
  final String title;
  final VoidCallback? onTap;

  const ${PASCAL_CASE}Widget({
    super.key,
    required this.title,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.padding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.borderRadius),
        border: Border.all(color: AppColors.outline),
      ),
      child: InkWell(
        onTap: onTap,
        child: Text(
          title,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
EOF

    print_success "✅ تم إنشاء العنصر: $widget_file"
}

# دالة إنشاء خدمة
generate_service() {
    local service_name=$1
    local service_file="lib/services/${service_name}_service.dart"
    
    print_info "إنشاء خدمة: $service_name"
    
    mkdir -p "lib/services"
    
    cat > "$service_file" << EOF
import 'package:flutter/foundation.dart';

/// خدمة $service_name
class ${PASCAL_CASE}Service {
  static final ${PASCAL_CASE}Service _instance = ${PASCAL_CASE}Service._internal();
  factory ${PASCAL_CASE}Service() => _instance;
  ${PASCAL_CASE}Service._internal();

  bool _isInitialized = false;

  /// تهيئة الخدمة
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('🔄 تهيئة خدمة $service_name...');
      
      // منطق التهيئة هنا
      
      _isInitialized = true;
      debugPrint('✅ تم تهيئة خدمة $service_name بنجاح');
    } catch (e) {
      debugPrint('❌ خطأ في تهيئة خدمة $service_name: \$e');
      rethrow;
    }
  }

  /// عملية أساسية
  Future<void> performAction() async {
    try {
      debugPrint('🔄 تنفيذ عملية $service_name...');
      
      // منطق العملية هنا
      
      debugPrint('✅ تم تنفيذ العملية بنجاح');
    } catch (e) {
      debugPrint('❌ خطأ في تنفيذ العملية: \$e');
      rethrow;
    }
  }

  /// تنظيف الموارد
  void dispose() {
    debugPrint('🧹 تنظيف موارد خدمة $service_name');
    _isInitialized = false;
  }
}
EOF

    print_success "✅ تم إنشاء الخدمة: $service_file"
}

# دالة إنشاء نموذج
generate_model() {
    local model_name=$1
    local model_file="lib/models/${model_name}_model.dart"
    
    print_info "إنشاء نموذج: $model_name"
    
    mkdir -p "lib/models"
    
    cat > "$model_file" << EOF
/// نموذج بيانات $model_name
class ${PASCAL_CASE}Model {
  final String id;
  final String title;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ${PASCAL_CASE}Model({
    required this.id,
    required this.title,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  /// إنشاء من JSON
  factory ${PASCAL_CASE}Model.fromJson(Map<String, dynamic> json) {
    return ${PASCAL_CASE}Model(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['created'] as String),
      updatedAt: DateTime.parse(json['updated'] as String),
    );
  }

  /// تحويل إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'created': createdAt.toIso8601String(),
      'updated': updatedAt.toIso8601String(),
    };
  }

  /// إنشاء نسخة محدثة
  ${PASCAL_CASE}Model copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ${PASCAL_CASE}Model(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ${PASCAL_CASE}Model && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return '${PASCAL_CASE}Model(id: \$id, title: \$title)';
  }
}
EOF

    print_success "✅ تم إنشاء النموذج: $model_file"
}

# دالة إنشاء مزود
generate_provider() {
    local provider_name=$1
    local provider_file="lib/providers/${provider_name}_provider.dart"
    
    print_info "إنشاء مزود: $provider_name"
    
    mkdir -p "lib/providers"
    
    cat > "$provider_file" << EOF
import 'package:flutter/foundation.dart';

/// مزود حالة $provider_name
class ${PASCAL_CASE}Provider extends ChangeNotifier {
  bool _isLoading = false;
  String? _errorMessage;
  List<dynamic> _items = [];

  // Getters
  bool get isLoading => _isLoading;
  bool get hasError => _errorMessage != null;
  String? get errorMessage => _errorMessage;
  List<dynamic> get items => List.unmodifiable(_items);

  /// تحميل البيانات
  Future<void> loadData() async {
    _setLoading(true);
    _setError(null);

    try {
      // منطق تحميل البيانات هنا
      await Future.delayed(const Duration(seconds: 1)); // محاكاة
      
      _items = []; // البيانات المحملة
      
    } catch (e) {
      _setError('فشل في تحميل البيانات: \$e');
    } finally {
      _setLoading(false);
    }
  }

  /// إضافة عنصر
  void addItem(dynamic item) {
    _items.add(item);
    notifyListeners();
  }

  /// حذف عنصر
  void removeItem(dynamic item) {
    _items.remove(item);
    notifyListeners();
  }

  /// إعادة المحاولة
  Future<void> retry() async {
    await loadData();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }
}
EOF

    print_success "✅ تم إنشاء المزود: $provider_file"
}

# تنفيذ الأمر المطلوب
case $TYPE in
    "feature")
        generate_feature "$SNAKE_CASE"
        ;;
    "screen")
        generate_screen "$SNAKE_CASE"
        ;;
    "widget")
        generate_widget "$SNAKE_CASE"
        ;;
    "service")
        generate_service "$SNAKE_CASE"
        ;;
    "model")
        generate_model "$SNAKE_CASE"
        ;;
    "provider")
        generate_provider "$SNAKE_CASE"
        ;;
    *)
        print_error "نوع غير معروف: $TYPE"
        show_help
        exit 1
        ;;
esac

print_success "🎉 تم إنشاء $TYPE بنجاح!"