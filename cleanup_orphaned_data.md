# تنظيف البيانات اليتيمة (Orphaned Data) في PocketBase

## المشكلة
عند حذف مستخدم، قد تبقى سجلات في جداول أخرى تشير إليه، مما يسبب أخطاء عند محاولة جلب البيانات.

## الحل: تنظيف قاعدة البيانات

### 1. تنظيف جدول `appointments`

افتح PocketBase Admin Panel → Collections → appointments

**البحث عن المواعيد اليتيمة:**
- ابحث عن المواعيد التي `host` يشير لمستخدم محذوف
- في حالتك: `host = "07f4hv90kajdr0s"`

**الحل:**
- احذف جميع المواعيد التي host محذوف
- أو غيّر host إلى مستخدم آخر (admin مثلاً)

### 2. تنظيف جدول `invitations`

افتح PocketBase Admin Panel → Collections → invitations

**البحث عن الدعوات اليتيمة:**
- ابحث عن الدعوات التي `guest` يشير لمستخدم محذوف
- أو `appointment` يشير لموعد محذوف

**الحل:**
- احذف جميع الدعوات اليتيمة

### 3. تنظيف جدول `user_appointment_status`

افتح PocketBase Admin Panel → Collections → user_appointment_status

**البحث عن السجلات اليتيمة:**
- ابحث عن السجلات التي `user` يشير لمستخدم محذوف
- أو `appointment` يشير لموعد محذوف

**الحل:**
- احذف جميع السجلات اليتيمة

### 4. تنظيف جدول `follows` أو `friendship`

افتح PocketBase Admin Panel → Collections → friendship

**البحث عن العلاقات اليتيمة:**
- ابحث عن السجلات التي `follower` يشير لمستخدم محذوف
- أو `following` يشير لمستخدم محذوف

**الحل:**
- احذف جميع العلاقات اليتيمة

### 5. تنظيف جدول `posts`

افتح PocketBase Admin Panel → Collections → posts

**البحث عن المقالات اليتيمة:**
- ابحث عن المقالات التي `author` يشير لمستخدم محذوف

**الحل:**
- احذف جميع المقالات اليتيمة

### 6. تنظيف جدول `visits`

افتح PocketBase Admin Panel → Collections → visits

**البحث عن الزيارات اليتيمة:**
- ابحث عن الزيارات التي `visitor` أو `visited` يشير لمستخدم محذوف

**الحل:**
- احذف جميع الزيارات اليتيمة

## الحل الأفضل: إضافة Cascade Delete في PocketBase

لمنع هذه المشكلة في المستقبل، يجب إعداد PocketBase لحذف السجلات المرتبطة تلقائياً عند حذف مستخدم.

### خطوات الإعداد:

1. افتح PocketBase Admin Panel
2. اذهب إلى Collections → appointments
3. افتح حقل `host` (Relation field)
4. فعّل خيار **"Cascade delete"**
5. كرر نفس الخطوات لجميع الحقول من نوع Relation في جميع الجداول:
   - `invitations.guest` → Cascade delete
   - `invitations.appointment` → Cascade delete
   - `user_appointment_status.user` → Cascade delete
   - `user_appointment_status.appointment` → Cascade delete
   - `follows.follower` → Cascade delete
   - `follows.following` → Cascade delete
   - `posts.author` → Cascade delete
   - `visits.visitor` → Cascade delete
   - `visits.visited` → Cascade delete

## سكريبت تنظيف سريع (SQL)

إذا كان لديك وصول مباشر لقاعدة البيانات SQLite:

```sql
-- حذف المواعيد اليتيمة
DELETE FROM appointments 
WHERE host NOT IN (SELECT id FROM users);

-- حذف الدعوات اليتيمة
DELETE FROM invitations 
WHERE guest NOT IN (SELECT id FROM users)
   OR appointment NOT IN (SELECT id FROM appointments);

-- حذف حالات المواعيد اليتيمة
DELETE FROM user_appointment_status 
WHERE user NOT IN (SELECT id FROM users)
   OR appointment NOT IN (SELECT id FROM appointments);

-- حذف العلاقات اليتيمة
DELETE FROM follows 
WHERE follower NOT IN (SELECT id FROM users)
   OR following NOT IN (SELECT id FROM users);

-- حذف المقالات اليتيمة
DELETE FROM posts 
WHERE author NOT IN (SELECT id FROM users);

-- حذف الزيارات اليتيمة
DELETE FROM visits 
WHERE visitor NOT IN (SELECT id FROM users)
   OR visited NOT IN (SELECT id FROM users);
```

## ملاحظات مهمة:

1. **قبل التنظيف:** اعمل نسخة احتياطية من قاعدة البيانات
2. **بعد التنظيف:** أعد تشغيل التطبيق للتأكد من عدم وجود أخطاء
3. **للمستقبل:** فعّل Cascade delete لجميع العلاقات لمنع هذه المشكلة

## الحل المؤقت في الكود:

إذا لم تستطع تنظيف قاعدة البيانات الآن، يمكنك إضافة معالجة للأخطاء في الكود:

```dart
try {
  final appointments = await pb.collection('appointments').getFullList(
    filter: 'host = "$userId"',
    sort: '-appointment_date',
  );
} catch (e) {
  print('⚠️ خطأ في جلب المواعيد (قد يكون المستخدم محذوف): $e');
  // تجاهل الخطأ والاستمرار
  return [];
}
```

لكن هذا حل مؤقت فقط. الحل الأفضل هو تنظيف قاعدة البيانات وإعداد Cascade delete.
