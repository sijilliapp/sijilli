sijilli/                              # 📦 جذر المشروع

├── 📄 .cursorrules                   # 📍 قواعد المساعد AI (الأهم!)

├── 📄 README.md                      # 🚀 واجهة المشروع الرئيسية

├── 📄 ARCHITECTURE.md                # 🏗️ هندسة المشروع الكاملة

├── 📄 analysis\_options.yaml          # ✅ قواعد صارمة للكود

│

├── 📁 docs/                          # 📚 التوثيق الكامل

│   ├── CODING\_GUIDE.md               # 📝 دليل البرمجة

│   ├── API\_DOCS.md                   # 🔌 واجهات API

│   ├── DATABASE\_SCHEMA.md            # 🗄️ مخطط قاعدة البيانات

│   ├── ARCHITECTURE.md               # 🏗️ الهندسة

│   └── DEPLOYMENT.md                 # 🚀 دليل النشر

│

├── 📁 templates/                     # 🎨 قوالب جاهزة

│   ├── new\_feature/                  # قالب إضافة ميزة جديدة

│   ├── new\_screen/                   # قالب شاشة جديدة

│   ├── new\_widget/                   # قالب عنصر واجهة

│   └── new\_service/                  # قالب خدمة جديدة

│

├── 📁 scripts/                       # 🛠️ نصوص مساعدة

│   ├── setup\_project.sh              # إعداد المشروع

│   ├── code\_analysis.sh              # تحليل الكود

│   └── generate\_template.sh          # توليد القوالب

│

├── 📁 assets/                        # 🖼️ الموارد

│   ├── images/                       # الصور

│   ├── icons/                        # الأيقونات

│   ├── fonts/                        # الخطوط

│   └── lottie/                       # التحريك

│

└── 📁 lib/                           # ⚡ قلب التطبيق

    │

    ├── 📄 main.dart                  # 🎬 نقطة البداية فقط

    │

    ├── 📁 core/                      # 🎯 الأساسيات المشتركة

    │   ├── 📁 constants/             # الثوابت فقط

    │   │   ├── README.md             # توثيق: ماذا يوضع هنا؟

    │   │   ├── app\_colors.dart       # 🎨 الألوان فقط

    │   │   ├── app\_strings.dart      # 📝 النصوص فقط

    │   │   ├── app\_dimens.dart       # 📏 القياسات فقط

    │   │   └── app\_styles.dart       # ✨ الأنماط فقط

    │   │

    │   ├── 📁 utils/                 # 🛠️ الأدوات المساعدة

    │   │   ├── README.md             # توثيق: ماذا يوضع هنا؟

    │   │   ├── date\_formatter.dart   # ⏰ تنسيق التواريخ

    │   │   ├── arabic\_search.dart    # 🔍 بحث عربي

    │   │   ├── hijri\_converter.dart  # 📅 تحويل هجري

    │   │   └── validators.dart       # ✅ مدخلات التحقق

    │   │

    │   ├── 📁 widgets/               # 🧩 عناصر واجهة عامة

    │   │   ├── README.md             # توثيق: ماذا يوضع هنا؟

    │   │   ├── buttons/              # أزرار مشتركة

    │   │   ├── cards/                # بطاقات مشتركة

    │   │   ├── dialogs/              # حوارات مشتركة

    │   │   └── loaders/              # مؤشرات تحميل

    │   │

    │   ├── 📁 services/              # 🔧 خدمات مشتركة

    │   │   ├── README.md             # توثيق: ماذا يوضع هنا؟

    │   │   ├── pocketbase\_service.dart # 🗄️ اتصال PocketBase

    │   │   ├── cache\_service.dart    # 💾 التخزين المؤقت

    │   │   ├── notification\_service.dart # 🔔 الإشعارات

    │   │   └── connectivity\_service.dart # 🌐 الاتصال

    │   │

    │   └── 📁 styles/                # 🎨 التصاميم المشتركة

    │       ├── theme.dart            # ثيم التطبيق

    │       └── animations.dart       # التحريك المشترك

    │

    ├── 📁 features/                  # 🎪 الميزات (كل جزء رئيسي)

    │   ├── 📁 auth/                  # 🔐 المصادقة

    │   │   ├── screens/              # شاشات المصادقة

    │   │   ├── widgets/              # عناصر المصادقة

    │   │   ├── providers/            # حالة المصادقة

    │   │   └── services/             # خدمات المصادقة

    │   │

    │   ├── 📁 home/                  # 🏠 التبويب 1: الرئيسية (بروفايل كبير + تبويبان)

    │   │   ├── README.md             # توثيق هذا التبويب

    │   │   ├── screens/              # الشاشات فقط

    │   │   │   └── home\_screen.dart  # 🎯 شاشة الرئيسية الكاملة

    │   │   ├── widgets/              # عناصر خاصة بالرئيسية

    │   │   │   ├── profile\_header.dart    # 👤 البروفايل الكبير (مثل TikTok)

    │   │   │   ├── home\_tab\_bar.dart      # 📌 شريط التبويبات: \[مواعيد | مقالات]

    │   │   │   ├── appointments\_tab.dart  # 🗓️ محتوى تبويب المواعيد

    │   │   │   └── articles\_tab.dart      # 📝 محتوى تبويب المقالات

    │   │   ├── providers/            # حالة الرئيسية

    │   │   │   └── home\_provider.dart

    │   │   └── services/             # خدمات الرئيسية

    │   │       └── home\_cache\_service.dart

    │   │

    │   ├── 📁 search/                # 🔍 التبويب 2: البحث الشامل

    │   │   ├── README.md             # توثيق نظام البحث

    │   │   ├── screens/              # شاشات البحث

    │   │   │   └── search\_screen.dart      # شاشة البحث الرئيسية

    │   │   ├── widgets/              # عناصر البحث

    │   │   │   ├── search\_bar.dart         # شريط البحث

    │   │   │   ├── result\_tabs.dart        # تبويبات النتائج

    │   │   │   ├── user\_result\_card.dart   # بطاقة نتيجة مستخدم

    │   │   │   ├── appointment\_result\_card.dart # بطاقة نتيجة موعد

    │   │   │   └── article\_result\_card.dart     # بطاقة نتيجة مقال

    │   │   ├── providers/            # حالة البحث

    │   │   │   └── search\_provider.dart

    │   │   └── services/             # خدمات البحث

    │   │       └── search\_service.dart

    │   │

    │   ├── 📁 add/                   # ➕ التبويب 3: إضافة موعد فقط

    │   │   ├── README.md             # توثيق نظام الإضافة

    │   │   ├── screens/              # شاشات الإضافة

    │   │   │   └── add\_appointment.dart    # ⭐ فقط إضافة موعد

    │   │   ├── widgets/              # عناصر نموذج الإضافة

    │   │   │   ├── appointment\_form.dart   # نموذج إضافة موعد

    │   │   │   ├── participant\_selector.dart # اختيار المشاركين

    │   │   │   └── location\_picker.dart    # اختيار الموقع

    │   │   ├── providers/            # حالة الإضافة

    │   │   │   └── add\_provider.dart

    │   │   └── services/             # خدمات الإضافة

    │   │       └── add\_service.dart

    │   │

    │   ├── 📁 notifications/         # 🔔 التبويب 4: الإشعارات

    │   │   ├── README.md             # توثيق نظام الإشعارات

    │   │   ├── screens/              # شاشات الإشعارات

    │   │   │   └── notifications\_screen.dart # شاشة الإشعارات

    │   │   ├── widgets/              # عناصر الإشعارات

    │   │   │   ├── notification\_item.dart    # عنصر إشعار

    │   │   │   └── notification\_badge.dart   # شارة الإشعارات

    │   │   ├── providers/            # حالة الإشعارات

    │   │   │   └── notifications\_provider.dart

    │   │   └── services/             # خدمات الإشعارات

    │   │       ├── in\_app\_service.dart  # إشعارات داخل التطبيق

    │   │       └── push\_service.dart    # إشعارات Push

    │   │

    │   ├── 📁 settings/              # ⚙️ التبويب 5: الإعدادات

    │   │   ├── README.md             # توثيق نظام الإعدادات

    │   │   ├── screens/              # شاشات الإعدادات

    │   │   │   ├── settings\_screen.dart      # الشاشة الرئيسية

    │   │   │   ├── profile\_edit\_screen.dart  # تعديل الملف

    │   │   │   └── archive\_screen.dart       # الأرشيف والمحذوفات

    │   │   ├── widgets/              # عناصر الإعدادات

    │   │   │   ├── settings\_item.dart        # عنصر إعداد

    │   │   │   └── language\_selector.dart    # اختيار اللغة

    │   │   ├── providers/            # حالة الإعدادات

    │   │   │   └── settings\_provider.dart

    │   │   └── services/             # خدمات الإعدادات

    │   │       └── settings\_service.dart

    │   │

    │   ├── 📁 appointments/          # 🗓️ نظام المواعيد (ليس تبويباً)

    │   │   ├── README.md             # توثيق نظام المواعيد

    │   │   ├── screens/              # شاشات تفصيلية

    │   │   │   ├── appointment\_details.dart      # تفاصيل موعد

    │   │   │   └── participant\_management.dart   # إدارة المشاركين

    │   │   ├── widgets/              # عناصر المواعيد

    │   │   │   ├── appointment\_card.dart         # بطاقة موعد

    │   │   │   ├── status\_indicator.dart         # مؤشر الحالة

    │   │   │   └── countdown\_timer.dart          # عداد تنازلي

    │   │   ├── providers/            # حالة المواعيد

    │   │   │   └── appointments\_provider.dart

    │   │   └── services/             # خدمات المواعيد

    │   │       └── appointments\_service.dart

    │   │

    │   └── 📁 articles/              # 📝 نظام المقالات (ليس تبويباً)

    │       ├── README.md             # توثيق نظام المقالات

    │       ├── screens/              # شاشات تفصيلية

    │       │   ├── article\_details.dart      # قراءة مقال

    │       │   └── create\_article.dart       # ⭐ إضافة مقال (من داخل تبويب المقالات)

    │       ├── widgets/              # عناصر المقالات

    │       │   ├── article\_card.dart         # بطاقة مقال

    │       │   ├── editor\_toolbar.dart       # شريط محرر النص

    │       │   └── comment\_section.dart      # قسم التعليقات

    │       ├── providers/            # حالة المقالات

    │       │   └── articles\_provider.dart

    │       └── services/             # خدمات المقالات

    │           └── articles\_service.dart

    │

    ├── 📁 models/                    # 📦 النماذج فقط

    │   ├── README.md                 # توثيق: ماذا يوضع هنا؟

    │   ├── user.dart                 # 👤 نموذج المستخدم

    │   ├── appointment.dart          # 🗓️ نموذج الموعد

    │   ├── article.dart              # 📝 ⭐ جديد: نموذج المقال

    │   ├── invitation.dart           # 📨 نموذج الدعوة

    │   ├── notification.dart         # 🔔 نموذج الإشعار

    │   ├── comment.dart              # 💬 ⭐ جديد: نموذج التعليق

    │   ├── like.dart                 # ❤️  ⭐ جديد: نموذج الإعجاب

    │   └── appointment\_template.dart # 🎨 نموذج القالب

    │

    ├── 📁 routes/                    # 🧭 التوجيه فقط

    │   ├── app\_router.dart           # جهاز التوجيه

    │   ├── route\_names.dart          # أسماء المسارات

    │   └── route\_transitions.dart    # انتقالات الشاشات

    │

    └── 📁 state/                     # 🧠 إدارة الحالة

        ├── README.md                 # توثيق: ماذا يوضع هنا؟

        ├── app\_state.dart            # حالة التطبيق العامة

        └── user\_state.dart           # حالة المستخدم

