#!/bin/bash

# 🔍 نص تحليل الكود - مشروع سجلي

echo "🔍 بدء تحليل شامل للكود..."

# ألوان للإخراج
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# دالة طباعة ملونة
print_status() {
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

# متغيرات العد
TOTAL_ERRORS=0
TOTAL_WARNINGS=0
TOTAL_FILES=0

# 1. فحص بنية المشروع
print_status "فحص بنية المشروع..."

# التحقق من وجود الملفات المطلوبة
REQUIRED_FILES=(
    "lib/main.dart"
    "pubspec.yaml"
    "README.md"
    "ARCHITECTURE.md"
    ".cursorrules"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        print_success "✓ $file موجود"
    else
        print_error "✗ $file مفقود"
        ((TOTAL_ERRORS++))
    fi
done

# التحقق من بنية المجلدات
REQUIRED_DIRS=(
    "lib/core"
    "lib/features"
    "lib/models"
    "lib/routes"
    "lib/state"
    "assets"
    "docs"
    "templates"
    "scripts"
)

for dir in "${REQUIRED_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        print_success "✓ مجلد $dir موجود"
    else
        print_warning "⚠ مجلد $dir مفقود"
        ((TOTAL_WARNINGS++))
    fi
done

# 2. تحليل Dart
print_status "تحليل كود Dart..."

# تشغيل flutter analyze
ANALYZE_OUTPUT=$(flutter analyze 2>&1)
ANALYZE_EXIT_CODE=$?

if [ $ANALYZE_EXIT_CODE -eq 0 ]; then
    print_success "✓ لا توجد مشاكل في تحليل Dart"
else
    print_error "✗ توجد مشاكل في الكود:"
    echo "$ANALYZE_OUTPUT"
    ((TOTAL_ERRORS++))
fi

# 3. فحص التبعيات
print_status "فحص التبعيات..."

# التحقق من التبعيات المحدثة
OUTDATED_OUTPUT=$(flutter pub outdated 2>&1)
if echo "$OUTDATED_OUTPUT" | grep -q "All dependencies are up to date"; then
    print_success "✓ جميع التبعيات محدثة"
else
    print_warning "⚠ توجد تبعيات قديمة:"
    echo "$OUTDATED_OUTPUT"
    ((TOTAL_WARNINGS++))
fi

# 4. فحص أمان التبعيات
print_status "فحص أمان التبعيات..."

# البحث عن تبعيات معروفة بمشاكل أمنية
SECURITY_ISSUES=()

# فحص pubspec.yaml للتبعيات المشكوك فيها
if grep -q "path:" pubspec.yaml; then
    SECURITY_ISSUES+=("استخدام تبعيات محلية (path:) قد يكون غير آمن")
fi

if grep -q "git:" pubspec.yaml; then
    SECURITY_ISSUES+=("استخدام تبعيات Git مباشرة قد يكون غير آمن")
fi

if [ ${#SECURITY_ISSUES[@]} -eq 0 ]; then
    print_success "✓ لا توجد مشاكل أمنية واضحة"
else
    for issue in "${SECURITY_ISSUES[@]}"; do
        print_warning "⚠ $issue"
        ((TOTAL_WARNINGS++))
    done
fi

# 5. فحص جودة الكود
print_status "فحص جودة الكود..."

# عد الملفات
DART_FILES=$(find lib -name "*.dart" | wc -l)
TOTAL_FILES=$DART_FILES
print_status "عدد ملفات Dart: $DART_FILES"

# فحص أحجام الملفات
LARGE_FILES=$(find lib -name "*.dart" -exec wc -l {} + | awk '$1 > 200 {print $2 " (" $1 " سطر)"}')
if [ -n "$LARGE_FILES" ]; then
    print_warning "⚠ ملفات كبيرة (أكثر من 200 سطر):"
    echo "$LARGE_FILES"
    ((TOTAL_WARNINGS++))
else
    print_success "✓ جميع الملفات بحجم مناسب"
fi

# فحص التعليقات
FILES_WITHOUT_COMMENTS=$(find lib -name "*.dart" -exec grep -L "//" {} \;)
if [ -n "$FILES_WITHOUT_COMMENTS" ]; then
    print_warning "⚠ ملفات بدون تعليقات:"
    echo "$FILES_WITHOUT_COMMENTS"
    ((TOTAL_WARNINGS++))
fi

# 6. فحص الاختبارات
print_status "فحص الاختبارات..."

if [ -d "test" ]; then
    TEST_FILES=$(find test -name "*_test.dart" | wc -l)
    print_status "عدد ملفات الاختبار: $TEST_FILES"
    
    if [ $TEST_FILES -eq 0 ]; then
        print_warning "⚠ لا توجد اختبارات"
        ((TOTAL_WARNINGS++))
    else
        # تشغيل الاختبارات
        print_status "تشغيل الاختبارات..."
        TEST_OUTPUT=$(flutter test 2>&1)
        TEST_EXIT_CODE=$?
        
        if [ $TEST_EXIT_CODE -eq 0 ]; then
            print_success "✓ جميع الاختبارات نجحت"
        else
            print_error "✗ فشل في الاختبارات:"
            echo "$TEST_OUTPUT"
            ((TOTAL_ERRORS++))
        fi
    fi
else
    print_warning "⚠ مجلد الاختبارات غير موجود"
    ((TOTAL_WARNINGS++))
fi

# 7. فحص الأداء
print_status "فحص الأداء..."

# البحث عن مشاكل أداء شائعة
PERFORMANCE_ISSUES=()

# فحص استخدام setState غير الضروري
SETSTATE_ISSUES=$(grep -r "setState" lib --include="*.dart" | wc -l)
if [ $SETSTATE_ISSUES -gt 50 ]; then
    PERFORMANCE_ISSUES+=("استخدام مفرط لـ setState ($SETSTATE_ISSUES مرة)")
fi

# فحص استخدام ListView بدون builder
LISTVIEW_ISSUES=$(grep -r "ListView(" lib --include="*.dart" | grep -v "builder" | wc -l)
if [ $LISTVIEW_ISSUES -gt 0 ]; then
    PERFORMANCE_ISSUES+=("استخدام ListView بدون builder ($LISTVIEW_ISSUES مرة)")
fi

if [ ${#PERFORMANCE_ISSUES[@]} -eq 0 ]; then
    print_success "✓ لا توجد مشاكل أداء واضحة"
else
    for issue in "${PERFORMANCE_ISSUES[@]}"; do
        print_warning "⚠ $issue"
        ((TOTAL_WARNINGS++))
    done
fi

# 8. فحص إمكانية الوصول
print_status "فحص إمكانية الوصول..."

# البحث عن عناصر بدون semantics
ACCESSIBILITY_ISSUES=()

# فحص الصور بدون alt text
IMAGES_WITHOUT_ALT=$(grep -r "Image\." lib --include="*.dart" | grep -v "semanticLabel" | wc -l)
if [ $IMAGES_WITHOUT_ALT -gt 0 ]; then
    ACCESSIBILITY_ISSUES+=("صور بدون نص بديل ($IMAGES_WITHOUT_ALT)")
fi

# فحص الأزرار بدون tooltip
BUTTONS_WITHOUT_TOOLTIP=$(grep -r "IconButton\|FloatingActionButton" lib --include="*.dart" | grep -v "tooltip" | wc -l)
if [ $BUTTONS_WITHOUT_TOOLTIP -gt 0 ]; then
    ACCESSIBILITY_ISSUES+=("أزرار بدون tooltip ($BUTTONS_WITHOUT_TOOLTIP)")
fi

if [ ${#ACCESSIBILITY_ISSUES[@]} -eq 0 ]; then
    print_success "✓ لا توجد مشاكل إمكانية وصول واضحة"
else
    for issue in "${ACCESSIBILITY_ISSUES[@]}"; do
        print_warning "⚠ $issue"
        ((TOTAL_WARNINGS++))
    done
fi

# 9. تقرير نهائي
echo ""
echo "📊 تقرير التحليل النهائي"
echo "=========================="
echo "📁 إجمالي الملفات: $TOTAL_FILES"
echo "❌ الأخطاء: $TOTAL_ERRORS"
echo "⚠️  التحذيرات: $TOTAL_WARNINGS"

# تقييم الجودة
if [ $TOTAL_ERRORS -eq 0 ] && [ $TOTAL_WARNINGS -eq 0 ]; then
    print_success "🎉 ممتاز! الكود بجودة عالية"
    exit 0
elif [ $TOTAL_ERRORS -eq 0 ] && [ $TOTAL_WARNINGS -lt 5 ]; then
    print_success "✅ جيد! بعض التحسينات البسيطة مطلوبة"
    exit 0
elif [ $TOTAL_ERRORS -lt 3 ]; then
    print_warning "⚠️  مقبول، لكن يحتاج تحسينات"
    exit 1
else
    print_error "❌ يحتاج عمل كبير لتحسين الجودة"
    exit 2
fi