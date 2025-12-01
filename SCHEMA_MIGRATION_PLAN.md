# خطة ترحيل Schema القاعدة

## 📋 **ملخص التغييرات**

### **Schema القديم:**
- جدول `appointments` - يحتوي على الموعد الأساسي فقط (host)
- جدول `user_appointment_status` - يحتوي على حالة كل مستخدم مع الموعد
- جدول `invitations` - يحتوي على دعوات الضيوف

### **Schema الجديد:**
- جدول `appointments` - يحتوي على سجل لكل مستخدم (مضيف + ضيوف)
  - `userId` - معرف المستخدم صاحب السجل
  - `appointmentGroupId` - UUID مشترك يربط جميع سجلات نفس الموعد
  - `isHost` - true للمضيف، false للضيف
  - `status` - active, archived, deleted
  - `myNote` - ملاحظة خاصة للمستخدم
  - `deletedAt` - تاريخ الحذف
- جدول `invitations` - يحتوي على دعوات الضيوف فقط
  - `appointmentGroupId` - UUID الموعد المشترك
  - `appointment` - relation لسجل الضيف (null إذا لم يقبل)
  - `status` - pending, accepted, rejected, deleted_after_accepted

---

## 🗑️ **الملفات المطلوب حذفها:**

1. ✅ `lib/models/user_appointment_status_model.dart`
2. ✅ `lib/services/user_appointment_status_service.dart`

---

## 📝 **الملفات المطلوب تحديثها:**

### **1. Models (مكتمل ✅):**
- ✅ `lib/models/appointment_model.dart` - إضافة userId, appointmentGroupId, isHost, timeString, myNote, deletedAt
- ✅ `lib/models/invitation_model.dart` - تحديث appointmentGroupId, appointment (nullable)

### **2. Constants (مكتمل ✅):**
- ✅ `lib/config/constants.dart` - إزالة userAppointmentStatusCollection

### **3. Services:**
- ⏳ إنشاء `lib/services/appointment_service.dart` جديد لإدارة المواعيد
- ⏳ تحديث جميع الملفات التي تستخدم `UserAppointmentStatusService`

### **4. Screens:**
- ⏳ `lib/screens/main_screen.dart` - تحديث منطق إنشاء المواعيد
- ⏳ `lib/screens/notifications_screen.dart` - تحديث منطق قبول الدعوات
- ⏳ `lib/screens/user_profile_screen.dart` - تحديث جلب المواعيد
- ⏳ `lib/screens/deleted_appointments_screen.dart` - تحديث جلب المواعيد المحذوفة
- ⏳ `lib/screens/appointment_details_screen.dart` - تحديث عرض التفاصيل

### **5. Widgets:**
- ⏳ `lib/widgets/appointment_card.dart` - تحديث عرض البطاقة والألوان

---

## 🔄 **منطق العمل الجديد:**

### **إنشاء موعد جديد:**
```dart
// 1. إنشاء UUID مشترك
final appointmentGroupId = generateUUID();

// 2. إنشاء سجل للمضيف
await pb.collection('appointments').create(body: {
  'userId': hostId,
  'appointmentGroupId': appointmentGroupId,
  'isHost': true,
  'status': 'active',
  'title': title,
  // ... باقي البيانات
});

// 3. إنشاء دعوات للضيوف
for (final guestId in guestIds) {
  await pb.collection('invitations').create(body: {
    'appointmentGroupId': appointmentGroupId,
    'appointment': null, // null لأنه لم يقبل بعد
    'guest': guestId,
    'status': 'pending',
  });
}
```

### **قبول دعوة:**
```dart
// 1. إنشاء سجل للضيف في appointments
final appointmentRecord = await pb.collection('appointments').create(body: {
  'userId': guestId,
  'appointmentGroupId': groupId,
  'isHost': false,
  'status': 'active',
  // ... نسخ البيانات من الموعد الأصلي
});

// 2. تحديث الدعوة
await pb.collection('invitations').update(invitationId, body: {
  'appointment': appointmentRecord.id,
  'status': 'accepted',
  'respondedAt': DateTime.now().toIso8601String(),
});
```

### **حذف موعد:**
```dart
// تحديث سجل المستخدم فقط
await pb.collection('appointments').update(appointmentId, body: {
  'status': 'deleted',
  'deletedAt': DateTime.now().toIso8601String(),
});

// إذا كان ضيف، تحديث الدعوة أيضاً
if (!isHost) {
  await pb.collection('invitations').update(invitationId, body: {
    'status': 'deleted_after_accepted',
  });
}
```

---

## ⚠️ **ملاحظات مهمة:**

1. **لا يوجد cascade delete تلقائي** - يجب حذف السجلات يدوياً
2. **المضيف ليس له سجل دعوة** - فقط الضيوف
3. **كل مستخدم له نسخة مستقلة** - يمكن حذفها دون التأثير على الآخرين
4. **الحذف النهائي بعد 30 يوم** - يحتاج Cloud Function

---

## 📊 **الخطوات التالية:**

1. ✅ تحديث Models
2. ✅ تحديث Constants
3. ⏳ إنشاء AppointmentService جديد
4. ⏳ تحديث Screens
5. ⏳ تحديث Widgets
6. ⏳ اختبار شامل

