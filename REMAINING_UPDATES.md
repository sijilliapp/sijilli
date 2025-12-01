# التحديثات المتبقية

## ✅ **ما تم إنجازه:**

1. ✅ تحديث `AppointmentModel` - إضافة userId, appointmentGroupId, isHost, timeString, myNote, deletedAt
2. ✅ تحديث `InvitationModel` - تحديث appointmentGroupId, appointment (nullable)
3. ✅ تحديث `AppConstants` - إزالة userAppointmentStatusCollection
4. ✅ إنشاء `AppointmentService` جديد
5. ✅ حذف `UserAppointmentStatusModel` و `UserAppointmentStatusService`
6. ✅ تحديث `appointment_details_screen.dart` جزئياً (imports, _statusService)

---

## ⏳ **ما تبقى:**

### **1. appointment_details_screen.dart:**

#### **المشاكل المتبقية:**
- `participantsStatus` - لم يعد موجوداً، يجب استبداله بجلب سجلات appointments مباشرة
- `hostId` - استبدل بـ `userId` + `isHost`
- `_buildParticipantStatus()` - يحتاج إعادة كتابة
- `_buildStatusTimeline()` - يحتاج إعادة كتابة

#### **الحل:**
بدلاً من تمرير `participantsStatus` كـ parameter، يجب:
1. جلب جميع سجلات appointments للموعد باستخدام `appointmentGroupId`
2. استخدام هذه السجلات لتحديد حالة كل مشارك

### **2. home_screen.dart:**
- إزالة `participantsStatus` من constructor
- تحديث منطق جلب المواعيد
- استخدام `AppointmentService` بدلاً من `UserAppointmentStatusService`

### **3. deleted_appointments_screen.dart:**
- إزالة `participantsStatus`
- تحديث منطق جلب المواعيد المحذوفة
- استخدام `AppointmentService.getDeletedAppointments()`

### **4. archive_screen.dart:**
- إزالة `participantsStatus`
- تحديث منطق جلب المواعيد المؤرشفة
- استخدام `AppointmentService.getArchivedAppointments()`

### **5. user_profile_screen.dart:**
- تحديث منطق جلب مواعيد المستخدم
- إزالة استخدام `userAppointmentStatusCollection`

### **6. main_screen.dart:**
- تحديث منطق إنشاء المواعيد
- استخدام `AppointmentService.createAppointment()`
- إزالة `_createUserAppointmentStatusRecords()`

### **7. notifications_screen.dart:**
- تحديث منطق قبول/رفض الدعوات
- استخدام `AppointmentService.acceptInvitation()` و `rejectInvitation()`
- إزالة منطق إنشاء `user_appointment_status`

### **8. appointment_card.dart:**
- تحديث منطق عرض الألوان
- استخدام `appointment.status` مباشرة بدلاً من `participantsStatus`

---

## 🎯 **الأولوية:**

1. **عالية:** main_screen.dart, notifications_screen.dart (إنشاء وقبول المواعيد)
2. **متوسطة:** home_screen.dart, deleted_appointments_screen.dart (عرض المواعيد)
3. **منخفضة:** appointment_details_screen.dart (التفاصيل), appointment_card.dart (UI)

---

## 💡 **ملاحظات:**

### **منطق جديد لجلب حالات المشاركين:**

```dart
// بدلاً من:
final participantsStatus = await _statusService.getAllParticipantsStatus(appointmentId);

// استخدم:
final allRecords = await _appointmentService.getAppointmentGroupRecords(appointmentGroupId);
// allRecords يحتوي على سجل لكل مشارك (مضيف + ضيوف)
```

### **منطق جديد لتحديد المضيف:**

```dart
// بدلاً من:
final isHost = currentUserId == appointment.hostId;

// استخدم:
final isHost = appointment.isHost;
```

### **منطق جديد لتحديد حالة المشارك:**

```dart
// بدلاً من:
final userStatus = participantsStatus[userId];
final status = userStatus?.status ?? 'active';

// استخدم:
final userRecord = allRecords.firstWhere((r) => r.userId == userId);
final status = userRecord.status; // active, archived, deleted
```

---

## 🚀 **الخطوة التالية:**

سأبدأ بتحديث `main_screen.dart` لأنه الأهم (إنشاء المواعيد).

