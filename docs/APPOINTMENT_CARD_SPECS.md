# مواصفات بطاقة الموعد (Appointment Card Specifications)

## 📋 نظرة عامة

بطاقة الموعد هي المكون الأساسي لعرض المواعيد في التطبيق. تتكون من نموذج أساسي (`BaseAppointmentCard`) يستخدم نظام السياسات (`Policy Pattern`) لتحديد المظهر والسلوك حسب حالة الموعد.

---

## 🏗️ البنية الأساسية

### 1. المكونات الرئيسية

```
BaseAppointmentCard
├── Card Container (الحاوية الخارجية)
│   ├── Header (الرأس)
│   │   ├── Privacy Badge (شارة الخصوصية)
│   │   ├── Status Capsule (كبسولة الحالة)
│   │   └── Guest Capsule (كبسولة الضيف)
│   └── Body (الجسم)
│       ├── Host Avatar (صورة المنشئ)
│       └── Appointment Details (تفاصيل الموعد)
│           ├── Host Name (اسم المنشئ)
│           ├── Title (العنوان)
│           ├── Location (الموقع - اختياري)
│           └── Date & Time (التاريخ والوقت)
```

---

## 🎨 المواصفات التصميمية

### القياسات الأساسية

| العنصر | القيمة | الوصف |
|--------|--------|-------|
| **Border Radius** | `20.0` | نصف قطر حواف البطاقة |
| **Border Width** | `1.5` | عرض الحدود |
| **Card Padding** | `12.0` | المسافة الداخلية للبطاقة |
| **Margin Horizontal** | `0.0` | الهامش الأفقي |
| **Margin Vertical** | `8.0` (AppDimens.spaceS) | الهامش العمودي |
| **Header-Body Spacing** | `12.0` | المسافة بين الرأس والجسم |
| **Avatar Size** | `44.0` | حجم صورة المنشئ |
| **Avatar-Details Spacing** | `14.0` | المسافة بين الصورة والتفاصيل |

### الألوان حسب الحالة

#### حدود البطاقة (Border Colors)

| الحالة | اللون | القيمة |
|--------|------|--------|
| **Now (الآن)** | Primary | `#3B82F6` |
| **Upcoming (قادم)** | Primary | `#3B82F6` (أزرق كامل) |
| **Past (ماضي)** | Grey 30% | `#4D9CA3AF` |
| **Error/Deleted** | Red 50% | `#80EF4444` |
| **Cancelled** | Error Border | `#80EF4444` |

#### خلفية البطاقة (Card Background)

| السياسة | اللون | الوصف |
|---------|------|-------|
| **Standard (عادي)** | Card Blue | `#F3F9FF` (أزرق فاتح موحد للبطاقات) |
| **Pending Invitation** | Alert Light 12% | `#FCD34D` بشفافية 12% |
| **Deleted** | Red 2% | `#EF4444` بشفافية 2% |
| **Archived** | Grey 50 | `#F9FAFB` |

#### كبسولة الحالة (Status Capsule)

| الحالة | Border | Background | Text |
|--------|--------|------------|------|
| **Now** | Primary | Primary | White |
| **Urgent** | Alert | Alert 10% | Alert |
| **Normal** | Main Status | Main Status 5% | Main Status |

---

## 📐 تفاصيل العناصر

### 1. Header (الرأس)

#### Privacy Badge (شارة الخصوصية)
- **الحجم**: ديناميكي حسب المحتوى
- **الموضع**: يمين الرأس
- **الظهور**: حسب `showPrivacyCapsule` في السياسة

#### Status Capsule (كبسولة الحالة)
```dart
// المكونات
- Icon: 10px (check_circle_outline / access_time / white dot)
- Text: 10px fontSize
- Padding: 6px horizontal, 4px vertical
- Border Radius: 12px
- Border Width: 1px
```

#### Guest Capsule (كبسولة الضيف)
```dart
// المكونات
- Avatar: 20px (اختياري)
- Name: 11px fontSize
- Extra Count Badge: 16px × 16px
- Status Indicator: 6px dot
- Padding: 6px horizontal, 4px vertical
```

### 2. Body (الجسم)

#### Host Avatar (صورة المنشئ)
```dart
Size: 44px
Border Radius: 22px (دائري)
Ring Width: 1.5px (حسب الحالة)
Ring Gap: 1.5px
Status Colors:
  - Active (Now): Primary (#3B82F6)
  - Upcoming: Primary (#3B82F6)
  - Deleted: Red (#EF4444)
  - None: Transparent
```

#### Host Name (اسم المنشئ)
```dart
Font Size: 13px
Font Weight: 500 (Medium)
Height: 1.0
Color: حسب السياسة
  - Normal: Primary (#3B82F6)
  - Cancelled/Deleted: Red (#EF4444)
```

#### Title (العنوان)
```dart
Font Size: 17px
Font Weight: 900 (Black)
Color: #2D3142
Height: 1.2
Max Lines: 2
Overflow: Ellipsis
```

#### Location (الموقع)
```dart
Icon: location_on (16px)
Font Size: 13px
Color: Grey 500 (أو Red للمحذوف)
Spacing: 6px بين الأيقونة والنص
Bottom Margin: 6px
```

#### Date & Time (التاريخ والوقت)
```dart
Icon: access_time_filled (16px)
Font Size: 14px
Color: Grey 700 (أسود داكن) - أو Red للمحذوف
Format: "اليوم، التاريخ | الوقت"
  - Hijri: "الإثنين، 15 رمضان 1446"
  - Gregorian: "الإثنين 22 يناير 2026"
```

---

## 🎯 نظام السياسات (Policy System)

### السياسات المتاحة

#### 1. StandardPolicy (السياسة العادية)
```dart
Use Case: المواعيد الشخصية للمستخدم
Features:
  - إمكانية الدعوة
  - فتح إعدادات الموعد عند النقر
  - عرض حالة الدعوة
  - تفاعل كامل مع العناصر
```

#### 2. FeaturedPolicy (السياسة المميزة)
```dart
Use Case: الموعد المميز في الصفحة الرئيسية
Features:
  - نفس StandardPolicy
  - يمكن تعطيل التفاعل (readOnly)
  - Elevation: 0
  - Border Width: 1.0
```

#### 3. PublicPolicy (السياسة العامة)
```dart
Use Case: عرض المواعيد في الملفات العامة
Features:
  - لا يمكن الدعوة
  - لا تفاعل مع المنشئ
  - عرض فقط
  - Ripple effect فقط
```

#### 4. DeletedPolicy (سياسة المحذوف)
```dart
Use Case: المواعيد المحذوفة
Features:
  - لون أحمر
  - خلفية حمراء شفافة
  - لا يمكن الدعوة
  - نص "محذوف" في كبسولة الضيف
  - أيقونة delete_outline
```

#### 5. ArchivedPolicy (سياسة المؤرشف)
```dart
Use Case: المواعيد المؤرشفة
Features:
  - ألوان رمادية
  - خلفية رمادية فاتحة
  - لا يمكن الدعوة
  - نص "مؤرشف" في كبسولة الضيف
  - أيقونة archive_outlined
```

---

## 🔧 خصائص السياسة (Policy Properties)

### الألوان (Colors)

```dart
// الألوان الأساسية
Color mainStatusColor        // اللون الرئيسي للحالة
Color borderColor            // لون الحدود
Color cardColor              // لون خلفية البطاقة
Color shadowColor            // لون الظل
Color titleColor             // لون العنوان (ثابت: #2D3142)
Color hostNameColor          // لون اسم المنشئ
Color iconColor              // لون الأيقونات

// ألوان الكبسولات
Color statusCapsuleBorderColor      // حدود كبسولة الحالة
Color statusCapsuleBackgroundColor  // خلفية كبسولة الحالة
Color statusCapsuleTextColor        // نص كبسولة الحالة
```

### القياسات (Dimensions)

```dart
double borderWidth           // عرض الحدود (افتراضي: 1.0)
double elevation             // ارتفاع الظل
```

### النصوص والأيقونات (Text & Icons)

```dart
String guestActionText       // نص زر الضيف
IconData? guestActionIcon    // أيقونة زر الضيف
```

### الأعلام (Flags)

```dart
bool isFeatured              // هل البطاقة مميزة
bool showPrivacyCapsule      // إظهار شارة الخصوصية
bool canInviteGuest          // إمكانية دعوة ضيف
```

### التفاعلات (Interactions)

```dart
VoidCallback? onCardTap       // عند النقر على البطاقة
VoidCallback? onHostTap       // عند النقر على المنشئ
VoidCallback? onGuestTap      // عند النقر على الضيف
VoidCallback? onGuestActionTap // عند النقر على زر الضيف
```

---

## 📊 جدول مقارنة السياسات

| الخاصية | Standard | Featured | Public | Deleted | Archived |
|---------|----------|----------|--------|---------|----------|
| **Elevation** | 0 | 0 | 0 | 1 | 0.5 |
| **Border Width** | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 |
| **Can Invite** | ✅ | ✅ | ❌ | ❌ | ❌ |
| **Card Tap** | Settings | Custom/Settings | Ripple | Settings | Settings |
| **Host Tap** | Profile | Profile/None | None | Profile | Profile |
| **Guest Action** | Invite | Invite | None | None | None |
| **Privacy Badge** | ✅ | ✅ | ✅ | ✅ | ✅ |

---

## 🎨 أمثلة الألوان حسب الحالة

### StandardPolicy

#### Pending Invitation (دعوة معلقة)
```dart
mainStatusColor: Grey 400 (#9CA3AF)
borderColor: حسب التوقيت
cardColor: Alert Light 12% (#FCD34D12)
hostNameColor: Primary (#3B82F6)
boxShadow: None
```

#### Accepted & Now (مقبول والآن)
```dart
mainStatusColor: Primary (#3B82F6)
borderColor: Primary (#3B82F6)
cardColor: Primary 3% (#083B82F6) // أزرق فاتح موحد
statusCapsule: Primary background, White text
elevation: 6.0 // ظل واضح للبروز
shadowColor: Black 12%
```

#### Accepted & Upcoming (مقبول وقادم)
```dart
mainStatusColor: Primary (#3B82F6)
borderColor: Primary (#3B82F6) // أزرق كامل
cardColor: Primary 3% (#083B82F6) // أزرق فاتح موحد
statusCapsule: Primary 5% background, Primary text
boxShadow: None
```

#### Cancelled (ملغي)
```dart
mainStatusColor: Grey 400 (#9CA3AF)
borderColor: Error Border (#80EF4444)
cardColor: Primary 3% (#083B82F6) // أزرق فاتح موحد
hostNameColor: Red (#EF4444)
boxShadow: None
```

#### Deleted After Accept (محذوف بعد القبول)
```dart
mainStatusColor: Red (#EF4444)
borderColor: Error Border (#80EF4444)
cardColor: Primary 3% (#083B82F6) // أزرق فاتح موحد
hostNameColor: Red (#EF4444)
boxShadow: None
```

---

## 🔄 حالات الموعد (Appointment States)

### التوقيت (Timing)

| الحالة | الشرط | التأثير |
|--------|-------|---------|
| **isNow** | الموعد جاري الآن | حدود زرقاء، كبسولة زرقاء، نقطة بيضاء، توهج أزرق خارجي خفيف |
| **isUpcoming** | موعد قادم | حدود زرقاء، أيقونة ساعة |
| **isPast** | موعد ماضي | حدود رمادية شفافة، أيقونة تحقق |
| **isUrgent** | أقل من ساعة | كبسولة برتقالية |

### الحالة (Status)

| الحالة | الشرط | التأثير |
|--------|-------|---------|
| **isCancelled** | ملغي | حدود حمراء، اسم أحمر |
| **isUserDeleted** | المستخدم محذوف | حدود حمراء، اسم أحمر، Avatar deleted |
| **isDeleted** | الموعد محذوف | سياسة DeletedPolicy |

### الدعوة (Invitation)

| الحالة | الشرط | التأثير |
|--------|-------|---------|
| **pending** | معلق | خلفية صفراء شفافة، لون رمادي |
| **accepted** | مقبول | ألوان عادية |
| **declined** | مرفوض | لا يظهر في القائمة |
| **deletedAfterAccept** | محذوف بعد القبول | لون أحمر |

---

## 📝 ملاحظات التطوير

### استخدام السياسات

```dart
// مثال: بطاقة عادية
BaseAppointmentCard(
  policy: StandardPolicy(appointment, context),
)

// مثال: بطاقة مميزة
BaseAppointmentCard(
  policy: FeaturedPolicy(appointment, context),
)

// مثال: بطاقة عامة
BaseAppointmentCard(
  policy: PublicPolicy(appointment, context),
)

// مثال: بطاقة مع تفاعل مخصص
BaseAppointmentCard(
  policy: FeaturedPolicy(
    appointment, 
    context,
    customOnTap: () => print('Custom action'),
  ),
)
```

### إنشاء سياسة مخصصة

```dart
class CustomPolicy extends AppointmentCardPolicy {
  CustomPolicy(super.appointment, super.context, {super.customOnTap});

  @override
  Color get mainStatusColor => Colors.purple;

  @override
  Color get borderColor => Colors.purple.withOpacity(0.5);

  @override
  Color get cardColor => Colors.purple.withOpacity(0.05);

  @override
  Color get shadowColor => Colors.transparent;

  @override
  double get elevation => 0;

  @override
  Color get hostNameColor => Colors.purple;

  @override
  Color get iconColor => Colors.grey.shade500;

  @override
  Color get statusCapsuleBorderColor => Colors.purple;

  @override
  Color get statusCapsuleBackgroundColor => Colors.purple.withOpacity(0.1);

  @override
  Color get statusCapsuleTextColor => Colors.purple;

  @override
  String get guestActionText => 'مخصص';

  @override
  IconData? get guestActionIcon => Icons.star;

  @override
  bool get canInviteGuest => false;

  @override
  VoidCallback? get onCardTap => customOnTap;

  @override
  VoidCallback? get onHostTap => null;

  @override
  VoidCallback? get onGuestTap => null;

  @override
  VoidCallback? get onGuestActionTap => null;
}
```

---

## 🎯 أفضل الممارسات

### 1. استخدام الثوابت
```dart
// ✅ صحيح
borderRadius: BorderRadius.circular(20)
padding: EdgeInsets.all(12)

// ❌ خطأ
borderRadius: BorderRadius.circular(AppDimens.radiusXL)
padding: EdgeInsets.all(AppDimens.spaceM)
```

### 2. الألوان الديناميكية
```dart
// ✅ صحيح - استخدام السياسة
color: policy.hostNameColor

// ❌ خطأ - ألوان ثابتة
color: AppColors.primary
```

### 3. التفاعلات
```dart
// ✅ صحيح - التحقق من null
onTap: policy.onCardTap

// ❌ خطأ - تفاعل مباشر
onTap: () => showDialog(...)
```

### 4. الحالات المركبة
```dart
// ✅ صحيح - استخدام دوال مساعدة
AvatarStatus _getAvatarStatus() {
  if (appointment.isUserDeleted) return AvatarStatus.deleted;
  if (appointment.isNow) return AvatarStatus.active;
  // ...
}

// ❌ خطأ - شروط معقدة في build
status: appointment.isUserDeleted ? AvatarStatus.deleted : 
        appointment.isNow ? AvatarStatus.active : ...
```

---

## 📚 المراجع

- **الملفات الأساسية**:
  - `lib/features/appointments/widgets/cards/base_appointment_card.dart`
  - `lib/features/appointments/widgets/cards/appointment_card_policy.dart`

- **السياسات**:
  - `lib/features/appointments/widgets/cards/policies/standard_policy.dart`
  - `lib/features/appointments/widgets/cards/policies/featured_policy.dart`
  - `lib/features/appointments/widgets/cards/policies/public_policy.dart`
  - `lib/features/appointments/widgets/cards/policies/deleted_policy.dart`
  - `lib/features/appointments/widgets/cards/policies/archived_policy.dart`

- **الثوابت**:
  - `lib/core/constants/app_colors.dart`
  - `lib/core/constants/app_dimens.dart`

- **المكونات الذرية**:
  - `lib/features/appointments/widgets/atomic/appointment_privacy_badge.dart`
  - `lib/features/appointments/widgets/atomic/interaction_capsule.dart`
  - `lib/features/appointments/widgets/atomic/guest_capsule.dart`
  - `lib/features/appointments/widgets/atomic/appointment_detail_item.dart`

---

**آخر تحديث**: 22 يناير 2026
