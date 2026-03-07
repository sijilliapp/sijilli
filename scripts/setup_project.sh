#!/bin/bash

# 🛠️ نص إعداد مشروع سجلي

echo "🚀 بدء إعداد مشروع سجلي..."

# التحقق من متطلبات النظام
echo "🔍 فحص متطلبات النظام..."

# فحص Flutter
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter غير مثبت. يرجى تثبيت Flutter أولاً."
    exit 1
fi

# فحص إصدار Flutter
FLUTTER_VERSION=$(flutter --version | head -n 1 | cut -d ' ' -f 2)
echo "✅ Flutter $FLUTTER_VERSION مثبت"

# فحص Dart
if ! command -v dart &> /dev/null; then
    echo "❌ Dart غير مثبت."
    exit 1
fi

DART_VERSION=$(dart --version | cut -d ' ' -f 4)
echo "✅ Dart $DART_VERSION مثبت"

# تنظيف المشروع
echo "🧹 تنظيف المشروع..."
flutter clean

# تحميل التبعيات
echo "📦 تحميل التبعيات..."
flutter pub get

# إنشاء ملفات الإعداد
echo "⚙️ إنشاء ملفات الإعداد..."

# إنشاء ملف البيئة للتطوير
cat > .env.development << EOF
# بيئة التطوير
POCKETBASE_URL=http://localhost:8080
DEBUG_MODE=true
LOG_LEVEL=debug
EOF

# إنشاء ملف البيئة للإنتاج
cat > .env.production << EOF
# بيئة الإنتاج
POCKETBASE_URL=https://sijilli.pockethost.io
DEBUG_MODE=false
LOG_LEVEL=error
EOF

# إنشاء ملف gitignore إضافي
cat >> .gitignore << EOF

# ملفات البيئة
.env.*
!.env.example

# ملفات التطوير
*.log
.vscode/settings.json
.idea/workspace.xml

# ملفات النشر
*.keystore
*.jks
key.properties
EOF

# إعداد Android
echo "🤖 إعداد Android..."
if [ -d "android" ]; then
    # إنشاء ملف key.properties للتوقيع
    cat > android/key.properties.example << EOF
storePassword=your_store_password
keyPassword=your_key_password
keyAlias=your_key_alias
storeFile=../sijilli-key.jks
EOF
    
    echo "📝 تم إنشاء android/key.properties.example"
    echo "   انسخه إلى key.properties وأضف بياناتك الحقيقية"
fi

# إعداد iOS
echo "🍎 إعداد iOS..."
if [ -d "ios" ]; then
    echo "📝 تذكر إعداد Bundle Identifier في Xcode"
    echo "   وإضافة الشهادات المطلوبة"
fi

# فحص الكود
echo "🔍 فحص الكود..."
flutter analyze

# تشغيل الاختبارات
echo "🧪 تشغيل الاختبارات..."
flutter test

# إنشاء أيقونة التطبيق
echo "🎨 إعداد أيقونة التطبيق..."
if [ -f "assets/icons/app_icon.png" ]; then
    flutter pub run flutter_launcher_icons:main
else
    echo "⚠️  لم يتم العثور على assets/icons/app_icon.png"
    echo "   أضف أيقونة التطبيق وشغل: flutter pub run flutter_launcher_icons:main"
fi

# رسالة النجاح
echo ""
echo "🎉 تم إعداد المشروع بنجاح!"
echo ""
echo "📋 الخطوات التالية:"
echo "   1. أضف أيقونة التطبيق في assets/icons/app_icon.png"
echo "   2. انسخ android/key.properties.example إلى android/key.properties"
echo "   3. أضف بيانات التوقيع الحقيقية"
echo "   4. اختبر التطبيق: flutter run"
echo ""
echo "📚 للمزيد من المعلومات، راجع:"
echo "   - README.md"
echo "   - ARCHITECTURE.md"
echo "   - docs/CODING_GUIDE.md"
echo ""