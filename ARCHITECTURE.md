# 🏗️ هندسة مشروع سجلي

## 📋 نظرة عامة

يتبع مشروع سجلي مبادئ Clean Architecture مع تنظيم Feature-First لضمان:
- قابلية الصيانة العالية
- سهولة الاختبار
- فصل الاهتمامات
- قابلية التوسع

## 🎯 المبادئ الأساسية

### 1. Feature-First Organization
كل ميزة (تبويب) في مجلد منفصل مع:
- `screens/` - الشاشات فقط
- `widgets/` - عناصر واجهة خاصة
- `providers/` - إدارة حالة الميزة
- `services/` - منطق العمل

### 2. Single Responsibility
- كل ملف له مسؤولية واحدة واضحة
- الشاشات: عرض UI فقط (50 سطر حد أقصى)
- الخدمات: منطق العمل فقط
- النماذج: بيانات فقط

### 3. Dependency Injection
- الخدمات تُحقن عبر Provider
- لا استدعاء مباشر للخدمات من UI
- فصل كامل بين الطبقات

## 📁 هيكل المجلدات

### `/core` - الأساسيات المشتركة
```
core/
├── constants/    # الثوابت (ألوان، نصوص، قياسات)
├── utils/        # أدوات مساعدة (تواريخ، بحث، تحقق)
├── widgets/      # عناصر واجهة مشتركة
├── services/     # خدمات مشتركة (قاعدة بيانات، شبكة)
└── styles/       # تصاميم وثيمات
```

### `/features` - الميزات
```
features/
├── auth/         # المصادقة
├── home/         # التبويب 1: الرئيسية
├── search/       # التبويب 2: البحث
├── add_event/    # التبويب 3: إضافة موعد
├── notifications/# التبويب 4: الإشعارات
└── settings/     # التبويب 5: الإعدادات
```

### `/models` - نماذج البيانات
نماذج immutable مع:
- `fromJson()` و `toJson()`
- `copyWith()` للتحديث
- `==` و `hashCode`

### `/routes` - التوجيه
- `app_router.dart` - جهاز التوجيه الرئيسي
- `route_names.dart` - أسماء المسارات
- `route_transitions.dart` - انتقالات مخصصة

### `/state` - إدارة الحالة
- `app_state.dart` - حالة التطبيق العامة
- `user_state.dart` - حالة المستخدم

## 🔄 تدفق البيانات

```
UI Layer (Screens/Widgets)
    ↓ Events
Provider Layer (State Management)
    ↓ Business Logic
Service Layer (API/Cache/DB)
    ↓ Data
Model Layer (Data Classes)
```

## 🎨 طبقة العرض (UI Layer)

### الشاشات (Screens)
- **المسؤولية**: عرض UI فقط
- **الحد الأقصى**: 50 سطر
- **القواعد**: 
  - لا منطق عمل
  - استخدام Provider للحالة
  - استخدام widgets مشتركة

### العناصر (Widgets)
- **مشتركة**: في `/core/widgets`
- **خاصة**: في `/features/[feature]/widgets`
- **قابلة للإعادة**: مع parameters واضحة

## 🧠 طبقة الحالة (State Layer)

### Provider Pattern
```dart
class HomeProvider extends ChangeNotifier {
  final HomeService _service;
  
  // State variables
  List<Appointment> _appointments = [];
  bool _isLoading = false;
  
  // Getters
  List<Appointment> get appointments => _appointments;
  bool get isLoading => _isLoading;
  
  // Methods
  Future<void> loadAppointments() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      _appointments = await _service.getAppointments();
    } catch (e) {
      // Handle error
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
```

## 🔧 طبقة الخدمات (Service Layer)

### خدمات مشتركة
- `PocketBaseService` - اتصال قاعدة البيانات
- `CacheService` - تخزين مؤقت
- `NotificationService` - إشعارات
- `ConnectivityService` - حالة الشبكة

### خدمات الميزات
- خاصة بكل ميزة
- تستخدم الخدمات المشتركة
- تحتوي على منطق العمل

## 📦 طبقة النماذج (Model Layer)

```dart
class Appointment {
  final String id;
  final String title;
  final DateTime date;
  final String? description;
  
  const Appointment({
    required this.id,
    required this.title,
    required this.date,
    this.description,
  });
  
  factory Appointment.fromJson(Map<String, dynamic> json) {
    return Appointment(
      id: json['id'],
      title: json['title'],
      date: DateTime.parse(json['date']),
      description: json['description'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'date': date.toIso8601String(),
      'description': description,
    };
  }
  
  Appointment copyWith({
    String? id,
    String? title,
    DateTime? date,
    String? description,
  }) {
    return Appointment(
      id: id ?? this.id,
      title: title ?? this.title,
      date: date ?? this.date,
      description: description ?? this.description,
    );
  }
}
```

## 🔀 التوجيه (Routing)

### مسارات مسماة
```dart
class RouteNames {
  static const String splash = '/';
  static const String login = '/login';
  static const String home = '/home';
  static const String addEvent = '/add-event';
  // ...
}
```

### انتقالات مخصصة
- انزلاق من اليمين للعربية
- تلاشي للحوارات
- تكبير للشاشات المهمة

## 🧪 الاختبار

### هيكل الاختبارات
```
test/
├── unit/         # اختبارات الوحدة
├── widget/       # اختبارات العناصر
├── integration/  # اختبارات التكامل
└── mocks/        # بيانات وهمية
```

### استراتيجية الاختبار
- **Models**: اختبار serialization
- **Services**: اختبار منطق العمل
- **Providers**: اختبار إدارة الحالة
- **Widgets**: اختبار UI

## 📱 الأداء

### تحسينات الأداء
- Lazy loading للشاشات
- Image caching للصور
- Database indexing للبحث
- Widget rebuilding optimization

### مراقبة الأداء
- Memory usage monitoring
- Network request optimization
- Battery usage optimization
- Startup time optimization

## 🔒 الأمان

### حماية البيانات
- تشفير البيانات الحساسة
- Token-based authentication
- Secure storage للمفاتيح
- Input validation شامل

### خصوصية المستخدم
- إذن صريح للبيانات
- تحكم في مشاركة البيانات
- حذف البيانات عند الطلب
- شفافية في جمع البيانات