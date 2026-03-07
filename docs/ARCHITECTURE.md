\# 🏗️ هندسة مشروع سجلي



\## 📋 نظرة عامة



يتبع مشروع سجلي مبادئ Clean Architecture مع تنظيم Feature-First لضمان:

\- قابلية الصيانة العالية

\- سهولة الاختبار

\- فصل الاهتمامات

\- قابلية التوسع



\## 🎯 المبادئ الأساسية



\### 1. Feature-First Organization

كل ميزة (تبويب) في مجلد منفصل مع:

\- `screens/` - الشاشات فقط

\- `widgets/` - عناصر واجهة خاصة

\- `providers/` - إدارة حالة الميزة

\- `services/` - منطق العمل



\### 2. Single Responsibility

\- كل ملف له مسؤولية واحدة واضحة

\- الشاشات: عرض UI فقط (50 سطر حد أقصى)

\- الخدمات: منطق العمل فقط

\- النماذج: بيانات فقط



\### 3. Dependency Injection

\- الخدمات تُحقن عبر Provider

\- لا استدعاء مباشر للخدمات من UI

\- فصل كامل بين الطبقات



\## 📁 هيكل المجلدات



\### `/core` - الأساسيات المشتركة

```

core/

├── constants/    # الثوابت (ألوان، نصوص، قياسات)

├── utils/        # أدوات مساعدة (تواريخ، بحث، تحقق)

├── widgets/      # عناصر واجهة مشتركة

├── services/     # خدمات مشتركة (قاعدة بيانات، شبكة)

└── styles/       # تصاميم وثيمات

```



\### `/features` - الميزات

```

features/

├── auth/         # المصادقة

├── home/         # التبويب 1: الرئيسية

├── search/       # التبويب 2: البحث

├── add\_event/    # التبويب 3: إضافة موعد

├── notifications/# التبويب 4: الإشعارات

└── settings/     # التبويب 5: الإعدادات

```



\### `/models` - نماذج البيانات

نماذج immutable مع:

\- `fromJson()` و `toJson()`

\- `copyWith()` للتحديث

\- `==` و `hashCode`



\### `/routes` - التوجيه

\- `app\_router.dart` - جهاز التوجيه الرئيسي

\- `route\_names.dart` - أسماء المسارات

\- `route\_transitions.dart` - انتقالات مخصصة



\### `/state` - إدارة الحالة

\- `app\_state.dart` - حالة التطبيق العامة

\- `user\_state.dart` - حالة المستخدم



\## 🔄 تدفق البيانات



```

UI Layer (Screens/Widgets)

&nbsp;   ↓ Events

Provider Layer (State Management)

&nbsp;   ↓ Business Logic

Service Layer (API/Cache/DB)

&nbsp;   ↓ Data

Model Layer (Data Classes)

```



\## 🎨 طبقة العرض (UI Layer)



\### الشاشات (Screens)

\- \*\*المسؤولية\*\*: عرض UI فقط

\- \*\*الحد الأقصى\*\*: 50 سطر

\- \*\*القواعد\*\*: 

&nbsp; - لا منطق عمل

&nbsp; - استخدام Provider للحالة

&nbsp; - استخدام widgets مشتركة



\### العناصر (Widgets)

\- \*\*مشتركة\*\*: في `/core/widgets`

\- \*\*خاصة\*\*: في `/features/\[feature]/widgets`

\- \*\*قابلة للإعادة\*\*: مع parameters واضحة



\## 🧠 طبقة الحالة (State Layer)



\### Provider Pattern

```dart

class HomeProvider extends ChangeNotifier {

&nbsp; final HomeService \_service;

&nbsp; 

&nbsp; // State variables

&nbsp; List<Appointment> \_appointments = \[];

&nbsp; bool \_isLoading = false;

&nbsp; 

&nbsp; // Getters

&nbsp; List<Appointment> get appointments => \_appointments;

&nbsp; bool get isLoading => \_isLoading;

&nbsp; 

&nbsp; // Methods

&nbsp; Future<void> loadAppointments() async {

&nbsp;   \_isLoading = true;

&nbsp;   notifyListeners();

&nbsp;   

&nbsp;   try {

&nbsp;     \_appointments = await \_service.getAppointments();

&nbsp;   } catch (e) {

&nbsp;     // Handle error

&nbsp;   } finally {

&nbsp;     \_isLoading = false;

&nbsp;     notifyListeners();

&nbsp;   }

&nbsp; }

}

```



\## 🔧 طبقة الخدمات (Service Layer)



\### خدمات مشتركة

\- `PocketBaseService` - اتصال قاعدة البيانات

\- `CacheService` - تخزين مؤقت

\- `NotificationService` - إشعارات

\- `ConnectivityService` - حالة الشبكة



\### خدمات الميزات

\- خاصة بكل ميزة

\- تستخدم الخدمات المشتركة

\- تحتوي على منطق العمل



\## 📦 طبقة النماذج (Model Layer)



```dart

class Appointment {

&nbsp; final String id;

&nbsp; final String title;

&nbsp; final DateTime date;

&nbsp; final String? description;

&nbsp; 

&nbsp; const Appointment({

&nbsp;   required this.id,

&nbsp;   required this.title,

&nbsp;   required this.date,

&nbsp;   this.description,

&nbsp; });

&nbsp; 

&nbsp; factory Appointment.fromJson(Map<String, dynamic> json) {

&nbsp;   return Appointment(

&nbsp;     id: json\['id'],

&nbsp;     title: json\['title'],

&nbsp;     date: DateTime.parse(json\['date']),

&nbsp;     description: json\['description'],

&nbsp;   );

&nbsp; }

&nbsp; 

&nbsp; Map<String, dynamic> toJson() {

&nbsp;   return {

&nbsp;     'id': id,

&nbsp;     'title': title,

&nbsp;     'date': date.toIso8601String(),

&nbsp;     'description': description,

&nbsp;   };

&nbsp; }

&nbsp; 

&nbsp; Appointment copyWith({

&nbsp;   String? id,

&nbsp;   String? title,

&nbsp;   DateTime? date,

&nbsp;   String? description,

&nbsp; }) {

&nbsp;   return Appointment(

&nbsp;     id: id ?? this.id,

&nbsp;     title: title ?? this.title,

&nbsp;     date: date ?? this.date,

&nbsp;     description: description ?? this.description,

&nbsp;   );

&nbsp; }

}

```



\## 🔀 التوجيه (Routing)



\### مسارات مسماة

```dart

class RouteNames {

&nbsp; static const String splash = '/';

&nbsp; static const String login = '/login';

&nbsp; static const String home = '/home';

&nbsp; static const String addEvent = '/add-event';

&nbsp; // ...

}

```



\### انتقالات مخصصة

\- انزلاق من اليمين للعربية

\- تلاشي للحوارات

\- تكبير للشاشات المهمة



\## 🧪 الاختبار



\### هيكل الاختبارات

```

test/

├── unit/         # اختبارات الوحدة

├── widget/       # اختبارات العناصر

├── integration/  # اختبارات التكامل

└── mocks/        # بيانات وهمية

```



\### استراتيجية الاختبار

\- \*\*Models\*\*: اختبار serialization

\- \*\*Services\*\*: اختبار منطق العمل

\- \*\*Providers\*\*: اختبار إدارة الحالة

\- \*\*Widgets\*\*: اختبار UI



\## 📱 الأداء



\### تحسينات الأداء

\- Lazy loading للشاشات

\- Image caching للصور

\- Database indexing للبحث

\- Widget rebuilding optimization



\### مراقبة الأداء

\- Memory usage monitoring

\- Network request optimization

\- Battery usage optimization

\- Startup time optimization



\## 🔒 الأمان



\### حماية البيانات

\- تشفير البيانات الحساسة

\- Token-based authentication

\- Secure storage للمفاتيح

\- Input validation شامل



\### خصوصية المستخدم

\- إذن صريح للبيانات

\- تحكم في مشاركة البيانات

\- حذف البيانات عند الطلب

\- شفافية في جمع البيانات

