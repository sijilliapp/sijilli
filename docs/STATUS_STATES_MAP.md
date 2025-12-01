# خارطة الحالات في تطبيق سِجِلّي
## Status States Map - Sijilli Application

> **📌 ملاحظة للمبرمج:**  
> هذا الملف يوثق نظام الحالات الكامل في التطبيق. اقرأه بعناية قبل أي تعديل على منطق الحالات أو الألوان.

---

## 🗂️ **الجداول الأساسية**

### **1. جدول `appointments`**
يحتوي على سجل لكل مستخدم في كل موعد (المضيف والضيوف).

**الحقول المهمة:**
- `userId` - معرف المستخدم صاحب السجل
- `appointmentGroupId` - UUID مشترك يربط جميع سجلات نفس الموعد
- `isHost` - `true` للمضيف، `false` للضيف
- `status` - حالة السجل: `active`, `archived`, `deleted`
- `deletedAt` - تاريخ الحذف (للحذف النهائي بعد 30 يوم)

---

### **2. جدول `invitations`**
يحتوي على دعوات الضيوف فقط (المضيف ليس له سجل دعوة).

**الحقول المهمة:**
- `appointmentGroupId` - UUID الموعد المشترك
- `appointment` - relation لسجل الضيف في `appointments` (يكون `null` إذا لم يقبل)
- `guest` - معرف الضيف
- `status` - حالة الدعوة: `pending`, `accepted`, `rejected`, `deleted_after_accepted`
- `respondedAt` - تاريخ الرد على الدعوة

---

## 👤 **حالات المضيف (Host)**

### **مصدر الحالة:** جدول `appointments` فقط

| الحالة | القيمة في DB | الوصف | متى تحدث |
|--------|-------------|-------|----------|
| **نشط** | `active` | الموعد نشط في حساب المضيف | عند إنشاء الموعد (افتراضي) |
| **مؤرشف** | `archived` | الموعد مؤرشف | عند أرشفة الموعد |
| **محذوف** | `deleted` | الموعد محذوف | عند حذف الموعد (يبقى 30 يوم ثم حذف نهائي) |

### **الكود:**
```dart
// عند إنشاء موعد جديد
await pb.collection('appointments').create(body: {
  'userId': hostId,
  'appointmentGroupId': groupId,
  'isHost': true,
  'status': 'active',  // ← المضيف دائماً يبدأ بـ active
  // ...
});
```

---

## 👥 **حالات الضيف (Guest)**

### **مصدر الحالة:** جدول `invitations` (الأساسي) + جدول `appointments` (بعد القبول)

| الحالة | القيمة في `invitations.status` | سجل في `appointments`? | الوصف |
|--------|-------------------------------|----------------------|-------|
| **منتظر** | `pending` | ❌ لا يوجد | الضيف لم يرد على الدعوة بعد |
| **مرفوض** | `rejected` | ❌ لا يوجد | الضيف رفض الدعوة |
| **مقبول** | `accepted` | ✅ نعم (`status: active`) | الضيف قبل الدعوة |
| **محذوف بعد القبول** | `deleted_after_accepted` | ✅ نعم (`status: deleted`) | الضيف قبل ثم حذف |

### **الكود:**

#### **1. إنشاء دعوة (pending):**
```dart
// المضيف يدعو ضيف
await pb.collection('invitations').create(body: {
  'appointmentGroupId': groupId,
  'guest': guestId,
  'appointment': null,  // ← null لأنه لا يوجد سجل في appointments بعد
  'status': 'pending',
});
```

#### **2. قبول الدعوة (accepted):**
```dart
// 1. إنشاء سجل في appointments
final appointmentRecord = await pb.collection('appointments').create(body: {
  'userId': guestId,
  'appointmentGroupId': groupId,
  'isHost': false,
  'status': 'active',  // ← نشط
  // ...
});

// 2. تحديث الدعوة
await pb.collection('invitations').update(invitationId, body: {
  'appointment': appointmentRecord.id,  // ← ربط بالسجل الجديد
  'status': 'accepted',
  'respondedAt': DateTime.now().toIso8601String(),
});
```

#### **3. رفض الدعوة (rejected):**
```dart
// فقط تحديث الدعوة - لا سجل في appointments
await pb.collection('invitations').update(invitationId, body: {
  'status': 'rejected',
  'respondedAt': DateTime.now().toIso8601String(),
});
```

#### **4. حذف بعد القبول (deleted_after_accepted):**
```dart
// 1. تحديث سجل الموعد
await pb.collection('appointments').update(appointmentId, body: {
  'status': 'deleted',
  'deletedAt': DateTime.now().toIso8601String(),
});

// 2. تحديث الدعوة
final invitation = await pb.collection('invitations').getFirstListItem(
  'appointment = "$appointmentId"',
);

await pb.collection('invitations').update(invitation.id, body: {
  'status': 'deleted_after_accepted',  // ← الحالة الجديدة!
});
```

---

## 🎨 **نظام الألوان في البطاقة المشتركة**

### **ألوان الطوق (Ring Color) حول الصورة:**

> **📍 الموقع في الكود:** `lib/widgets/appointment_card.dart` - دالة `_getRingColor()`

| الحالة | اللون | الكود | متى يظهر |
|--------|------|------|----------|
| **لم يرد / رفض** | 🔘 رمادي | `Colors.grey` | `pending` أو `rejected` |
| **وافق (نشط)** | 🔵 أزرق | `Colors.blue` | `accepted` → `active` |
| **حذف بعد الموافقة** | 🔴 أحمر | `Color(0xFFC62828)` | `deleted_after_accepted` → `deleted` |
| **مؤرشف** | 🔘 رمادي | `Colors.grey` | `archived` |

### **الكود الفعلي:**
```dart
// lib/widgets/appointment_card.dart - السطر 297
Color _getRingColor(String status, String guestId) {
  final guestStatus = widget.participantsStatus?[guestId];

  if (guestStatus != null) {
    // من جدول appointments
    switch (guestStatus.status.toLowerCase()) {
      case 'deleted':
        return const Color(0xFFC62828); // 🔴 أحمر داكن
      case 'archived':
        return Colors.grey; // 🔘 رمادي
      case 'active':
        return Colors.blue; // 🔵 أزرق
      default:
        return Colors.grey;
    }
  } else {
    // من جدول invitations (fallback)
    switch (status.toLowerCase()) {
      case 'active': // accepted
        return Colors.blue; // 🔵 أزرق
      case 'deleted': // deleted_after_accepted
        return const Color(0xFFC62828); // 🔴 أحمر داكن
      case 'cancelled': // rejected
        return Colors.transparent; // مخفي
      case 'pending':
      default:
        return Colors.grey; // 🔘 رمادي
    }
  }
}
```

---

## 🔍 **الاستعلامات (Queries)**

### **1. المواعيد النشطة للمستخدم:**
```dart
filter: 'userId = "${userId}" && status = "active"'
```

### **2. المواعيد المؤرشفة:**
```dart
filter: 'userId = "${userId}" && status = "archived"'
```

### **3. المواعيد المحذوفة (سلة المحذوفات):**
```dart
filter: 'userId = "${userId}" && status = "deleted"'
```

### **4. كشف التعارض (النشطة فقط):**
```dart
filter: 'userId = "${userId}" && status = "active" && appointment_date >= "${startDate}" && appointment_date <= "${endDate}"'
```

### **5. جميع المشاركين في موعد (البطاقة المشتركة):**
```dart
// من appointments
filter: 'appointmentGroupId = "${groupId}"'

// من invitations
filter: 'appointmentGroupId = "${groupId}"'
```

---

## 📊 **مثال عملي كامل**

### **السيناريو: مضيف + 4 ضيوف**

#### **جدول `appointments`:**
| id | userId | appointmentGroupId | isHost | status |
|----|--------|-------------------|--------|--------|
| rec1 | host | group-A | true | active |
| rec3 | guest3 | group-A | false | active |
| rec4 | guest4 | group-A | false | deleted |

#### **جدول `invitations`:**
| id | appointmentGroupId | appointment | guest | status |
|----|-------------------|-------------|-------|--------|
| inv1 | group-A | null | guest1 | pending |
| inv2 | group-A | null | guest2 | rejected |
| inv3 | group-A | rec3 | guest3 | accepted |
| inv4 | group-A | rec4 | guest4 | deleted_after_accepted |

#### **النتيجة في البطاقة المشتركة:**
| المستخدم | الحالة | لون الطوق | يظهر في البطاقة؟ |
|---------|--------|-----------|-----------------|
| Host | active | 🔵 أزرق | ✅ نعم |
| Guest1 | pending | 🔘 رمادي | ✅ نعم |
| Guest2 | rejected | مخفي | ❌ لا (مخفي) |
| Guest3 | accepted → active | 🔵 أزرق | ✅ نعم |
| Guest4 | deleted_after_accepted | 🔴 أحمر | ✅ نعم |

---

## 🗑️ **الحذف النهائي (بعد 30 يوم)**

### **Cloud Function / Cron Job:**
```dart
// يعمل يومياً
final thirtyDaysAgo = DateTime.now().subtract(Duration(days: 30));

final toDelete = await pb.collection('appointments').getList(
  filter: 'status = "deleted" && deletedAt <= "${thirtyDaysAgo.toIso8601String()}"',
);

for (var record in toDelete.items) {
  await pb.collection('appointments').delete(record.id);
  // ← cascade delete سيحذف الدعوة المرتبطة تلقائياً
}
```

---

## ⚠️ **ملاحظات مهمة للمبرمج**

### **1. المضيف ليس له سجل دعوة:**
- ✅ المضيف موجود في `appointments` فقط
- ❌ المضيف **لا يوجد** في `invitations`
- ✅ حالة المضيف تؤخذ من `appointments.status` مباشرة

### **2. الضيف له مصدرين للحالة:**
- ✅ **الأساسي:** `invitations.status` (pending, accepted, rejected, deleted_after_accepted)
- ✅ **الثانوي:** `appointments.status` (فقط بعد القبول: active, archived, deleted)

### **3. منطق عرض الحالة في الكود:**
```dart
// للضيف
if (invitation.status == 'accepted') {
  // استخدم appointments.status
  final appointmentStatus = appointment.status; // active/archived/deleted
} else {
  // استخدم invitations.status
  final invitationStatus = invitation.status; // pending/rejected/deleted_after_accepted
}
```

### **4. الحذف لا رجعة فيه:**
- ✅ بمجرد الحذف، الموعد يذهب لسلة المحذوفات
- ✅ يبقى 30 يوم ثم حذف نهائي
- ❌ **لا يوجد استرجاع** من سلة المحذوفات

### **5. cascade delete:**
- ✅ عند حذف سجل من `appointments` نهائياً
- ✅ الدعوة المرتبطة في `invitations` تُحذف تلقائياً
- ✅ بسبب `cascadeDelete: true` في relation

---

## 📝 **تاريخ التحديث**
- **آخر تحديث:** 2024-01-28
- **الإصدار:** 1.0
- **المبرمج:** تطبيق سِجِلّي

---

**🔗 ملفات ذات صلة:**
- `lib/widgets/appointment_card.dart` - عرض البطاقة والألوان
- `lib/screens/appointment_details_screen.dart` - تفاصيل الموعد
- `lib/services/appointment_service.dart` - منطق الحالات
- `my_data/pb_schema_final.json` - Schema القاعدة


