# ترحيل من نظام follows إلى نظام friendship

## التغييرات المطبقة

### 1. تحديث ملف الثوابت (`lib/config/constants.dart`)

**قبل:**
```dart
static const String followsCollection = 'follows'; // قديم
static const String friendshipCollection = 'friendship'; // جديد
```

**بعد:**
```dart
static const String friendshipCollection = 'friendship';
// تم إزالة followsCollection
```

### 2. تحديث صفحة الأصدقاء (`lib/screens/friends_screen.dart`)

**التغييرات:**
- ✅ استخدام `AppConstants.friendshipCollection` بدلاً من `followsCollection`
- ✅ جلب الأصدقاء بفلتر: `(follower = "$userId" || following = "$userId") && status = "approved"`
- ✅ إزالة شرط `isPublic = true` من الفلتر
- ✅ فلترة الأصدقاء في الكود (Dart) بدلاً من PocketBase
- ✅ إضافة قسم الطلبات المرسلة (pending_sent)
- ✅ إضافة قسم الطلبات الواردة (pending_received)

### 3. تحديث صفحة إضافة الموعد (`lib/screens/main_screen.dart`)

**قبل:**
```dart
// جلب المتابعات (من أتابعهم)
final followingRecords = await _authService.pb
    .collection(AppConstants.followsCollection)
    .getFullList(filter: 'follower = "$currentUserId"');

// جلب المتبوعين (من يتابعونني)
final followersRecords = await _authService.pb
    .collection(AppConstants.followsCollection)
    .getFullList(filter: 'following = "$currentUserId"');

// جمع معرفات المستخدمين
Set<String> friendIds = {};

// إضافة المتابعات
for (var record in followingRecords) {
  friendIds.add(record.data['following']);
}

// إضافة المتبوعين
for (var record in followersRecords) {
  friendIds.add(record.data['follower']);
}
```

**بعد:**
```dart
// جلب الأصدقاء (علاقة متبادلة مقبولة من جدول friendship)
final friendshipRecords = await _authService.pb
    .collection(AppConstants.friendshipCollection)
    .getFullList(
      filter: '(follower = "$currentUserId" || following = "$currentUserId") && status = "approved"',
    );

print('📊 عدد سجلات الأصدقاء: ${friendshipRecords.length}');

// جمع معرفات الأصدقاء (الطرف الآخر من العلاقة)
Set<String> friendIds = {};

for (var record in friendshipRecords) {
  final followerId = record.data['follower'] as String;
  final followingId = record.data['following'] as String;
  // إضافة الطرف الآخر من العلاقة
  final friendId = followerId == currentUserId ? followingId : followerId;
  friendIds.add(friendId);
}
```

**التحسينات:**
- ✅ طلب واحد بدلاً من طلبين (أسرع)
- ✅ جلب الأصدقاء المقبولين فقط (`status = "approved"`)
- ✅ إزالة شرط `isPublic = true` (الأصدقاء يظهرون دائماً)
- ✅ إضافة رسائل تشخيص

## الفرق بين النظامين

### نظام follows (القديم):
- علاقة أحادية الاتجاه (مثل Twitter)
- المستخدم A يتابع المستخدم B
- لا يشترط أن يتابع B المستخدم A
- جدولين منفصلين: following و followers

### نظام friendship (الجديد):
- علاقة ثنائية الاتجاه (مثل Facebook)
- المستخدم A يرسل طلب صداقة للمستخدم B
- يجب أن يقبل B الطلب (`status = "approved"`)
- جدول واحد فقط: friendship
- حالات الطلب: `pending`, `approved`, `block`

## قواعد الرؤية الجديدة

### في صفحة إضافة الموعد:
- يظهر فقط الأصدقاء المقبولين (`status = "approved"`)
- لا يظهر الطلبات المعلقة
- لا يشترط `isPublic = true`

### في صفحة الأصدقاء:
- **تبويب "عاديين":** الأصدقاء الذين `role != "approved" && role != "admin"`
- **تبويب "معتمدين":** الأصدقاء الذين `role = "approved"`
- **قسم الطلبات الواردة:** الطلبات التي `following = currentUserId && status = "pending"`
- **قسم الطلبات المرسلة:** الطلبات التي `follower = currentUserId && status = "pending"`

## خطوات ما بعد الترحيل

### 1. تحديث قواعد الوصول في PocketBase

افتح PocketBase Admin Panel وحدّث القواعد في جدول `appointments`:

**List rule و View rule:**
```javascript
@request.auth.id != '' && (
  host = @request.auth.id || 
  host.isPublic = true || 
  @collection.invitations.appointment.id = id && @collection.invitations.guest.id = @request.auth.id || 
  @collection.friendship.follower.id = @request.auth.id && @collection.friendship.following.id = host
)
```

### 2. حذف جدول follows القديم (اختياري)

إذا كان جدول `follows` لا يزال موجوداً:
1. تأكد من نقل جميع البيانات إلى `friendship`
2. احذف الجدول من PocketBase Admin Panel

### 3. تنظيف البيانات اليتيمة

راجع ملف `cleanup_orphaned_data.md` لتنظيف أي بيانات يتيمة.

### 4. اختبار الوظائف

اختبر جميع الوظائف:
- ✅ إضافة موعد جديد
- ✅ إضافة ضيوف للموعد
- ✅ عرض قائمة الأصدقاء
- ✅ إرسال طلبات صداقة
- ✅ قبول/رفض طلبات الصداقة
- ✅ إلغاء طلبات مرسلة
- ✅ إنهاء صداقة

## الأداء

### قبل الترحيل:
- طلبين لجلب الأصدقاء (following + followers)
- فلترة في الكود
- بطء في التحميل

### بعد الترحيل:
- طلب واحد فقط لجلب الأصدقاء
- فلترة في قاعدة البيانات (`status = "approved"`)
- أسرع بكثير ⚡

## ملاحظات مهمة

1. **Cascade Delete:** تأكد من تفعيل Cascade delete في جدول `friendship`
2. **Backup:** اعمل نسخة احتياطية قبل الترحيل
3. **Testing:** اختبر جميع الوظائف بعد الترحيل
4. **Cache:** امسح cache المتصفح بعد الترحيل

## الأخطاء المحتملة وحلولها

### خطأ 404: Missing collection context
**السبب:** الكود يحاول الوصول لجدول `follows` غير موجود
**الحل:** تأكد من تحديث جميع الملفات لاستخدام `friendshipCollection`

### خطأ 400: Something went wrong
**السبب:** قواعد الوصول في PocketBase لا تزال تستخدم `@collection.follows`
**الحل:** حدّث قواعد الوصول في PocketBase Admin Panel

### لا تظهر الأصدقاء في قائمة الضيوف
**السبب:** الأصدقاء ليسوا مقبولين (`status != "approved"`)
**الحل:** تأكد من قبول طلبات الصداقة أولاً
