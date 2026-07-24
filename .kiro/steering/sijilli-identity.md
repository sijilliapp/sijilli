# هوية سجلي — الثوابت المقدسة

هذا الملف مرجع أبدي لا يُتجاوز إلا بإذن **صريح وواضح** من المالك.
أي تعديل على الكود يجب أن يُراجَع أمام هذه الثوابت قبل التنفيذ.

---

## 1. قانون الطوق — البنية البصرية للنشرات

### الطوق الأزرق
- يظهر حول صورة كل مشارك **يحتفظ بسجله** في الموعد
- الشرط: `invitation.postStatus == PostStatus.published && invitation.status == InvitationStatus.accepted`

### الطوق الأحمر
- يظهر حول صورة كل مشارك **حذف سجله** من الموعد
- الشرط: `invitation.status == InvitationStatus.deletedAfterAccept` أو `invitation.postStatus == PostStatus.trash`

### القاعدة المطلقة
> أصحاب السجلات المحذوفة = طوق أحمر
> أصحاب السجلات المحتفظ بها = طوق أزرق
> لا استثناء. لا حياد. لا تغيير إلا بإذن صريح.

---

## 2. قانون الحذف — حجر الأساس الميكانيكي

> **أيٌّ كان دوره (مستضيف أو ضيف)، إذا حذف سجله فإن حذفه لا يؤثر على سجلات الآخرين.**

### التفصيل:
- الحذف **شخصي دائماً**: فقط `invitation.post_status = trash` لصاحب الحذف
- سجلات الآخرين **لا تُمس أبداً**
- التغيير الوحيد المسموح عند الآخرين: **طوق أحمر** حول صورة من حذف

### حالات المستضيف عند حذفه:
| الحالة | السجل المركزي | نسخة المستضيف | نسخ الضيوف |
|--------|-------------|-------------|-----------|
| الكل معلق (لا أحد قبل) | `is_cancelled = true` | تُحذف (trash) | تبقى ظاهرة، زر "ملغى" رمادي |
| بعضهم قبل | `is_deleted = true` | تُحذف (trash) | تبقى ظاهرة، زر "محذوف" أحمر |

---

## 3. قانون النسخ الشخصية

- كل مستخدم يملك **نسخته الشخصية** (`invitation`) من الموعد
- هذه النسخة هي ملكيته الحصرية — لا يملك أحد حق حذفها أو تعديلها إلا هو
- الفلتر يجب أن يعرض المواعيد بناءً على `invitation.post_status` وليس `appointment.is_cancelled/is_deleted`
- حقول `appointments.is_cancelled` و `appointments.is_deleted` **لا تُستخدم شرطاً للمنع** من رؤية الدعوات

---

## 4. حالات الأزرار عند الضيوف بعد حذف المستضيف

| حالة السجل المركزي | شكل الزر عند الضيوف | لون الطوق |
|-------------------|-------------------|----------|
| `is_cancelled = true` | زر واحد طويل "ملغى" — لا يستجيب | رمادي حول المستضيف |
| `is_deleted = true` | زر واحد طويل "محذوف" — لا يستجيب | أحمر حول المستضيف |

---

## 5. قانون الخصوصية — مصدر الحقيقة

> **جدول `appointments` مصدر معلومات فقط — لا يحتوي على حقل `privacy` ولا يؤثر في منطق العرض.**
> **جدول `invitations` هو البوابة الوحيدة للخصوصية والعرض.**

### التفصيل:
- `invitations.privacy` هو المصدر الوحيد لخصوصية الموعد
- `effectivePrivacy` تقرأ من `currentUserInvitation?.privacy` فقط — لا fallback لـ `appointment.privacy`
- عند إنشاء دعوة جديدة لضيف: `privacy = 'private'` افتراضياً
- صاحب الموعد يتحكم بخصوصية نسخته الشخصية بشكل مستقل

### قواعد قاعدة البيانات (PocketBase):

**جدول `appointments`:**
- listRule / viewRule: `true` — عام لجميع الزوار (التحكم يكون في invitations)
- createRule: `@request.auth.id != ""`
- updateRule: `host = @request.auth.id || @request.auth.role = "admin"`
- deleteRule: `host = @request.auth.id || @request.auth.role = "admin"`

**جدول `invitations`:**
- listRule / viewRule:
```
appointment.host = @request.auth.id
|| user = @request.auth.id
|| (privacy = "public" && appointment.host.isPublic = true)
|| (
  privacy = "followers"
  && appointment.host.isPublic = true
  && (
    (@collection.friendship.user_a ?= @request.auth.id && @collection.friendship.user_b ?= appointment.host && @collection.friendship.a_status = "accepted" && @collection.friendship.b_status = "accepted")
    || (@collection.friendship.user_b ?= @request.auth.id && @collection.friendship.user_a ?= appointment.host && @collection.friendship.a_status = "accepted" && @collection.friendship.b_status = "accepted")
  )
)
```
- createRule: `appointment.host = @request.auth.id || user = @request.auth.id`
- updateRule: `user = @request.auth.id || @request.auth.role = "admin"`
- deleteRule: `user = @request.auth.id || appointment.host = @request.auth.id`

---

## 6. قانون الصفحة العامة — شروط عرض المواعيد

### شروط ظهور تبويب المواعيد للزائر:
```
canView = user.isPublic || isFollowing || isMe
```

### شروط عرض موعد بعينه للزائر:
| نوع الخصوصية | الزائر غير المسجل | مسجل غير معتمد | معتمد متبادل | مدعو للموعد | صاحب الحساب |
|-------------|------------------|---------------|-------------|------------|------------|
| `public` (وصاحبه `isPublic`) | ✅ | ✅ | ✅ | ✅ | ✅ |
| `followers` | ❌ | ❌ | ✅ | ✅ | ✅ |
| `private` | ❌ | ❌ | ❌ | ✅ | ✅ |

### قواعد ثابتة:
- الموعد **الفائت** يخسر الصدارة في القائمة فقط — لا يُحجب
- المالك يرى **كل** مواعيده المنشورة بغض النظر عن وقتها
- حقول `is_cancelled` و `is_deleted` في `appointments` **لا تمنع** رؤية الدعوة — تؤثر على العرض البصري فقط (الطوق والأزرار)

---

## 7. قانون سلطة التعديل على السجلات

- **لا أحد يملك سلطة على سجلات الآخرين** — أياً كان دوره
- الحذف والتعديل حصريان على النسخة الشخصية لصاحبها
- **استثناء طارئ:** المشرف (admin) يملك صلاحية حذف أي سجل من لوحة التحكم — لا من واجهة التطبيق
- في الصفحات العامة (`PublicPolicy`): زر الحذف معطّل تماماً (`canDelete = false`, `canDeleteFromLongPress = false`)

---

## 8. قانون الاعتمادات (المتابعات)

- الاعتماد **دائماً ينتظر** — لا قبول فوري إلا للحسابات المقترحة (`is_suggested = true`)
- عند إلغاء الاعتماد: كلا الطرفين يعودان لـ `none` — القبول التالي يتطلب طلباً جديداً
- `accreditUser()` تضع `accepted` على الطرف الطالب فقط — حالة الطرف الآخر لا تتغير إلا إذا كان طلبه `pending` أو كان الحساب `is_suggested`

---

## تنبيه للمساعد

**قبل أي تعديل يمس:**
- منطق الطوق (اللون — الأزرق/الأحمر)
- منطق الحذف (`cancelAppointment` / `deleteInvitation`)
- فلاتر جلب المواعيد (`getAppointments` / `getPublicAppointments`)
- حقول `is_cancelled` أو `is_deleted` أو `post_status` في الدعوات
- حقل `privacy` في أي جدول
- قواعد قاعدة البيانات (listRule / viewRule / createRule)
- منطق الاعتمادات (`followUser` / `accreditUser` / `unfollowUser`)

**يجب أن:**
1. تُعرض هذه الثوابت على المالك أولاً
2. تُطلب موافقة صريحة قبل أي تغيير
3. لا يُفترض أن أي تعديل "تحسيني" يبرر المساس بهذه القواعد
