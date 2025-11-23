# إصلاح قواعد الوصول في PocketBase

## المشكلة

قواعد الوصول (API Rules) في PocketBase لا تزال تستخدم الاسم القديم `follows` بدلاً من `friendship`، مما يسبب أخطاء 400 و 404.

## الأخطاء الظاهرة:

```
❌ خطأ 404: Missing collection context (عند محاولة الوصول لجدول follows)
❌ خطأ 400: Something went wrong (عند تطبيق قواعد الوصول التي تشير لجدول follows)
```

## الحل: تحديث قواعد الوصول

### 1. تحديث قواعد جدول `appointments`

**الخطوات:**
1. افتح PocketBase Admin Panel
2. اذهب إلى Collections → appointments
3. افتح API Rules
4. غيّر القواعد التالية:

**List rule (القديم):**
```javascript
@request.auth.id != '' && (
  host = @request.auth.id || 
  host.isPublic = true || 
  @collection.invitations.appointment.id = id && @collection.invitations.guest.id = @request.auth.id || 
  @collection.follows.follower.id = @request.auth.id && @collection.follows.following.id = host
)
```

**List rule (الجديد):**
```javascript
@request.auth.id != '' && (
  host = @request.auth.id || 
  host.isPublic = true || 
  @collection.invitations.appointment.id = id && @collection.invitations.guest.id = @request.auth.id || 
  @collection.friendship.follower.id = @request.auth.id && @collection.friendship.following.id = host
)
```

**View rule (القديم):**
```javascript
@request.auth.id != '' && (
  host = @request.auth.id || 
  host.isPublic = true || 
  @collection.invitations.appointment.id = id && @collection.invitations.guest.id = @request.auth.id || 
  @collection.follows.follower.id = @request.auth.id && @collection.follows.following.id = host
)
```

**View rule (الجديد):**
```javascript
@request.auth.id != '' && (
  host = @request.auth.id || 
  host.isPublic = true || 
  @collection.invitations.appointment.id = id && @collection.invitations.guest.id = @request.auth.id || 
  @collection.friendship.follower.id = @request.auth.id && @collection.friendship.following.id = host
)
```

### 2. تحديث قواعد جداول أخرى (إذا وجدت)

ابحث في جميع الجداول عن أي إشارة لـ `@collection.follows` وغيّرها إلى `@collection.friendship`.

**الجداول المحتملة:**
- posts
- invitations
- user_appointment_status
- visits

### 3. حذف جدول `follows` القديم (اختياري)

إذا كان جدول `follows` لا يزال موجوداً في PocketBase:
1. اذهب إلى Collections
2. ابحث عن جدول `follows`
3. احذفه (بعد التأكد من نقل جميع البيانات إلى `friendship`)

## التحقق من الإصلاح

بعد تطبيق التغييرات:

1. **أعد تشغيل التطبيق:**
```bash
flutter clean
flutter pub get
flutter run -d chrome
```

2. **تحقق من Console:**
   - يجب ألا تظهر أخطاء 404 عن `follows`
   - يجب ألا تظهر أخطاء 400 عند جلب المواعيد

3. **اختبر الوظائف:**
   - جلب المواعيد
   - جلب قائمة الأصدقاء
   - إرسال طلبات صداقة

## ملاحظات مهمة

1. **Cascade Delete:** تأكد من تفعيل Cascade delete لجميع حقول العلاقات في جدول `friendship`
2. **Backup:** اعمل نسخة احتياطية قبل تعديل القواعد
3. **Testing:** اختبر جميع الوظائف بعد التعديل

## الفرق بين `follows` و `friendship`

- **follows (قديم):** نظام متابعة أحادي الاتجاه (مثل Twitter)
- **friendship (جديد):** نظام صداقة ثنائي الاتجاه (مثل Facebook)

في نظام الصداقة الجديد:
- يجب أن يكون `status = "approved"` لكي تكون صداقة فعلية
- العلاقة متبادلة (bidirectional)
- يمكن أن تكون `status = "pending"` للطلبات المعلقة
