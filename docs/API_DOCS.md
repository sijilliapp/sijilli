🚀 تم إنشاء docs/API_DOCS.md:

markdown
# 🔌 واجهات API - تطبيق "سجلي"

## 📋 نظرة عامة
جميع واجهات API تستخدم **PocketBase** كـ Backend. قاعدة البيانات: SQLite.

---

## 🔐 المصادقة

### تسجيل الدخول
```http
POST /api/collections/users/auth-with-password
Body:

json
{
  "identity": "email@example.com",
  "password": "password123"
}
تسجيل حساب جديد
http
POST /api/collections/users/records
Body:

json
{
  "username": "falah",
  "email": "falah@example.com",
  "password": "password123",
  "passwordConfirm": "password123",
  "name": "فلاح العازمي"
}
تحديث token
http
POST /api/collections/users/auth-refresh
Headers: Authorization: USER_TOKEN

👤 المستخدمون
الحصول على بيانات المستخدم
http
GET /api/collections/users/records/[user_id]
تحديث الملف الشخصي
http
PATCH /api/collections/users/records/[user_id]
Body:

json
{
  "avatar": "avatar.jpg",
  "bio": "نبذة شخصية",
  "social_link": "https://instagram.com/username"
}
البحث عن المستخدمين
http
GET /api/collections/users/records
Query Parameters:

text
?filter=(name~'فلاح' || username~'فلاح')
&perPage=20
&page=1
الحصول على متابعين
http
GET /api/collections/user_follows/records
text
?filter=(followed_id='[user_id]')
&expand=follower_id
الحصول على المتابَعين
http
GET /api/collections/user_follows/records
text
?filter=(follower_id='[user_id]')
&expand=followed_id
متابعة مستخدم
http
POST /api/collections/user_follows/records
Body:

json
{
  "follower_id": "[my_id]",
  "followed_id": "[target_id]"
}
إلغاء المتابعة
http
DELETE /api/collections/user_follows/records/[record_id]
🗓️ المواعيد
إنشاء موعد جديد
http
POST /api/collections/appointments/records
Body:

json
{
  "title": "اجتماع فريق العمل",
  "host": "[user_id]",
  "date": "2024-01-15",
  "time": "14:30",
  "region": "الرياض",
  "building": "المبنى أ",
  "privacy": "private",
  "description": "مناقشة خطة المشروع الجديد"
}
الحصول على مواعيد المستخدم
http
GET /api/collections/appointments/records
Query Parameters:

text
?filter=(host='[user_id]')
&sort=-date,-created
&expand=participants(event_id)
الحصول على موعد محدد
http
GET /api/collections/appointments/records/[appointment_id]
text
?expand=participants(event_id).user_id
تحديث موعد
http
PATCH /api/collections/appointments/records/[appointment_id]
ملاحظة: يحتاج صلاحية المالك فقط.

حذف موعد
http
DELETE /api/collections/appointments/records/[appointment_id]
أرشفة موعد
http
PATCH /api/collections/appointments/records/[appointment_id]
Body:

json
{
  "is_archived": true
}
البحث عن مواعيد عامة
http
GET /api/collections/appointments/records
text
?filter=(privacy='public' && date>='2024-01-01')
&sort=date,time
👥 المشاركون والدعوات
دعوة مستخدم لموعد
http
POST /api/collections/event_participants/records
Body:

json
{
  "event_id": "[appointment_id]",
  "user_id": "[invited_user_id]",
  "status": "pending",
  "is_host": false
}
الحصول على مشاركي موعد
http
GET /api/collections/event_participants/records
text
?filter=(event_id='[appointment_id]')
&expand=user_id
تحديث حالة المشاركة
http
PATCH /api/collections/event_participants/records/[participation_id]
الحالات: pending, accepted, declined, deleted

Body لقبول الدعوة:

json
{
  "status": "accepted",
  "responded_at": "2024-01-15 10:30:00"
}
Body لرفض الدعوة:

json
{
  "status": "declined",
  "responded_at": "2024-01-15 10:30:00"
}
الحصول على دعواتي المعلقة
http
GET /api/collections/event_participants/records
text
?filter=(user_id='[my_id]' && status='pending')
&expand=event_id.host
حذف مشاركة (لمستخدم قبل)
http
PATCH /api/collections/event_participants/records/[participation_id]
json
{
  "status": "deleted",
  "deleted_at": "2024-01-15 10:30:00"
}
📝 الملاحظات الخاصة
إضافة ملاحظة خاصة لموعد
http
POST /api/collections/event_private_notes/records
Body:

json
{
  "event_id": "[appointment_id]",
  "user_id": "[my_id]",
  "note": "تذكر إحضار الوثائق"
}
الحصول على ملاحظاتي لموعد
http
GET /api/collections/event_private_notes/records
text
?filter=(event_id='[appointment_id]' && user_id='[my_id]')
تحديث ملاحظة
http
PATCH /api/collections/event_private_notes/records/[note_id]
حذف ملاحظة
http
DELETE /api/collections/event_private_notes/records/[note_id]
🔔 الإشعارات
الحصول على إشعاراتي
http
GET /api/collections/notifications/records
text
?filter=(user_id='[my_id]')
&sort=-created
&perPage=50
تحديث حالة الإشعار (مقروء)
http
PATCH /api/collections/notifications/records/[notification_id]
json
{
  "is_read": true,
  "read_at": "2024-01-15 10:30:00"
}
تحديد كل الإشعارات كمقروءة
http
POST /api/collections/notifications/update-all
json
{
  "user_id": "[my_id]",
  "is_read": true
}
أنواع الإشعارات:
invitation_new ← دعوة جديدة

invitation_accepted ← قبول الدعوة

invitation_declined ← رفض الدعوة

appointment_updated ← تحديث موعد

appointment_cancelled ← إلغاء موعد

new_follower ← متابع جديد

🎨 النماذج الجاهزة
الحصول على النماذج
http
GET /api/collections/appointment_templates/records
text
?filter=(user_id='[my_id]' || is_public=true)
إنشاء نموذج جديد
http
POST /api/collections/appointment_templates/records
json
{
  "title": "اجتماع عمل",
  "user_id": "[my_id]",
  "is_public": false,
  "template_data": {
    "region": "الرياض",
    "building": "المكتب الرئيسي",
    "duration": 60
  }
}
🔍 الاستعلامات المتقدمة
مواعيدي القادمة (مضيف أو مشارك)
http
GET /api/collections/appointments/records
text
?filter=((host='[my_id]' || id in (
  select event_id from event_participants 
  where user_id='[my_id]' && status='accepted'
)) && date>='2024-01-15' && is_cancelled=false)
&expand=participants(event_id).user_id
&sort=date,time
إحصائيات المستخدم
http
GET /api/collections/users/records/[user_id]
text
?fields=id,appointments_count,followers_count,following_count
البحث المتقدم بالمواعيد
http
GET /api/collections/appointments/records
text
?filter=(title~'اجتماع' && region='الرياض' && date>='2024-01-01')
&sort=-date
&perPage=20
⚠️ معالجة الأخطاء
رموز الحالة الشائعة:
200 ← نجاح

201 ← تم الإنشاء

400 ← طلب غير صحيح

401 ← غير مصرح

403 ← ممنوع

404 ← غير موجود

500 ← خطأ داخلي

هيكل الخطأ:
json
{
  "code": 400,
  "message": "البيانات غير صالحة",
  "data": {
    "title": {
      "code": "validation_required",
      "message": "العنوان مطلوب"
    }
  }
}
🔒 الصلاحيات
قواعد الوصول:
المواعيد العامة: يراها جميع المستخدمين المصادقين

المواعيد الخاصة: يراها المالك والمشاركون المقبولون فقط

الملفات الشخصية: جميع البيانات ظاهرة إلا:

البريد الإلكتروني (للصاحب فقط)

رقم الهاتف (للصاحب فقط)

المتابعات: العلاقات ظاهرة للجميع

التحقق من الصلاحية:
dart
// مثال: التحقق إذا كان المستخدم يستطيع رؤية موعد
bool canViewAppointment = 
    appointment.privacy == 'public' ||
    appointment.host == currentUserId ||
    isParticipantAccepted(appointment.id, currentUserId);
🚀 أمثلة عملية
مثال 1: إنشاء موعد مع دعوة مستخدمين
http
# 1. إنشاء الموعد
POST /api/collections/appointments/records
{
  "title": "حفلة عيد ميلاد",
  "host": "user_123",
  "date": "2024-02-20",
  "time": "19:00",
  "privacy": "private"
}

# 2. دعوة الأصدقاء
POST /api/collections/event_participants/records
{
  "event_id": "appointment_456",
  "user_id": "user_789",
  "status": "pending"
}
مثال 2: البحث عن مواعيد في منطقة معينة
http
GET /api/collections/appointments/records?filter=(region='جدة' && date>='2024-01-15')
📚 موارد إضافية
PocketBase Documentation

REST API Best Practices

Flutter HTTP Package

آخر تحديث: أبريل 2025
الإصدار: 1.0