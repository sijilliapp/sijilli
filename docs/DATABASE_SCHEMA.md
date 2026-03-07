# 🗄️ مخطط قاعدة بيانات "سجلي"

## 📊 نظرة عامة
نستخدم **PocketBase** مع **SQLite**. الجداول الرئيسية:
👥 users ← المستخدمون
🗓️ appointments ← المواعيد
👥 event_participants ← المشاركون (علاقة Many-to-Many)
📝 event_private_notes ← الملاحظات الخاصة
🎨 appointment_templates ← النماذج الجاهزة
🔔 notifications ← الإشعارات الداخلية
🤝 user_follows ← المتابعات

text

---

## 👥 جدول `users`
```sql
CREATE TABLE users (
    -- المعرف
    id TEXT PRIMARY KEY,
    
    -- معلومات الحساب
    username TEXT UNIQUE NOT NULL,
    email TEXT UNIQUE,
    password TEXT NOT NULL,
    email_visibility BOOLEAN DEFAULT FALSE,
    
    -- المعلومات الشخصية
    name TEXT NOT NULL,
    avatar TEXT,
    bio TEXT,
    phone TEXT,
    social_link TEXT,
    
    -- التفضيلات
    hijri_adjustment INTEGER DEFAULT 0,
    language TEXT DEFAULT 'ar',
    theme TEXT DEFAULT 'system',
    
    -- الصلاحيات
    role TEXT DEFAULT 'user',
    verified BOOLEAN DEFAULT FALSE,
    
    -- الإحصائيات
    followers_count INTEGER DEFAULT 0,
    following_count INTEGER DEFAULT 0,
    appointments_count INTEGER DEFAULT 0,
    
    -- الطوابع الزمنية
    created TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
الفهارس:

sql
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_email ON users(email);
🗓️ جدول appointments
sql
CREATE TABLE appointments (
    -- المعرف
    id TEXT PRIMARY KEY,
    
    -- المعلومات الأساسية
    title TEXT NOT NULL,
    description TEXT,
    
    -- المالك
    host TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- الوقت والتاريخ
    date DATE NOT NULL,
    time TEXT NOT NULL,
    duration_minutes INTEGER DEFAULT 60,
    
    -- الموقع
    region TEXT,
    building TEXT,
    latitude REAL,
    longitude REAL,
    
    -- الخصوصية
    privacy TEXT DEFAULT 'private',
    
    -- الحالة
    is_cancelled BOOLEAN DEFAULT FALSE,
    is_archived BOOLEAN DEFAULT FALSE,
    is_deleted BOOLEAN DEFAULT FALSE,
    
    -- الإحصائيات
    participants_count INTEGER DEFAULT 0,
    invited_count INTEGER DEFAULT 0,
    
    -- البيانات الإضافية
    metadata JSON DEFAULT '{}',
    
    -- الطوابع الزمنية
    created TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
الفهارس:

sql
CREATE INDEX idx_appointments_host ON appointments(host);
CREATE INDEX idx_appointments_date ON appointments(date);
CREATE INDEX idx_appointments_privacy ON appointments(privacy);
CREATE INDEX idx_appointments_region ON appointments(region);
👥 جدول event_participants (Many-to-Many)
sql
CREATE TABLE event_participants (
    -- المعرف
    id TEXT PRIMARY KEY,
    
    -- العلاقات
    event_id TEXT NOT NULL REFERENCES appointments(id) ON DELETE CASCADE,
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- الحالة
    status TEXT DEFAULT 'pending',
    is_host BOOLEAN DEFAULT FALSE,
    
    -- خصوصية النسخة
    privacy TEXT DEFAULT 'private',
    
    -- الأوقات
    invited_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    responded_at TIMESTAMP,
    deleted_at TIMESTAMP,
    
    -- بيانات إضافية
    notes TEXT,
    
    -- فريد لمنع التكرار
    UNIQUE(event_id, user_id)
);
الفهارس:

sql
CREATE INDEX idx_participants_user ON event_participants(user_id, status);
CREATE INDEX idx_participants_event ON event_participants(event_id, status);
CREATE INDEX idx_participants_invited ON event_participants(invited_at);
📝 جدول event_private_notes
sql
CREATE TABLE event_private_notes (
    -- المعرف
    id TEXT PRIMARY KEY,
    
    -- العلاقات
    event_id TEXT NOT NULL REFERENCES appointments(id) ON DELETE CASCADE,
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- المحتوى
    note TEXT NOT NULL,
    
    -- الطوابع الزمنية
    created TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- ملاحظة واحدة لكل مستخدم لكل موعد
    UNIQUE(event_id, user_id)
);
🤝 جدول user_follows
sql
CREATE TABLE user_follows (
    -- العلاقات
    follower_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    followed_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- الطوابع الزمنية
    created TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- مفتاح رئيسي مركب
    PRIMARY KEY (follower_id, followed_id),
    
    -- لا يمكن متابعة النفس
    CHECK (follower_id != followed_id)
);
الفهارس:

sql
CREATE INDEX idx_followers ON user_follows(follower_id);
CREATE INDEX idx_followed ON user_follows(followed_id);
🔔 جدول notifications
sql
CREATE TABLE notifications (
    -- المعرف
    id TEXT PRIMARY KEY,
    
    -- المستهدف
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- النوع والمحتوى
    type TEXT NOT NULL,
    title TEXT NOT NULL,
    body TEXT,
    
    -- البيانات المرتبطة
    related_type TEXT,
    related_id TEXT,
    
    -- الحالة
    is_read BOOLEAN DEFAULT FALSE,
    is_archived BOOLEAN DEFAULT FALSE,
    
    -- الطوابع الزمنية
    created TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    read_at TIMESTAMP,
    
    -- البيانات الإضافية
    data JSON DEFAULT '{}'
);
الفهارس:

sql
CREATE INDEX idx_notifications_user ON notifications(user_id, is_read);
CREATE INDEX idx_notifications_created ON notifications(created);
🎨 جدول appointment_templates
sql
CREATE TABLE appointment_templates (
    -- المعرف
    id TEXT PRIMARY KEY,
    
    -- المالك
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- المعلومات
    title TEXT NOT NULL,
    description TEXT,
    
    -- القالب
    template_data JSON NOT NULL,
    
    -- الخصوصية
    is_public BOOLEAN DEFAULT FALSE,
    
    -- الإحصائيات
    usage_count INTEGER DEFAULT 0,
    
    -- الطوابع الزمنية
    created TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
🔗 العلاقات الرئيسية
1. المستخدم ←→ المواعيد
text
users (1) → appointments (many)
مستخدم واحد يمكنه إنشاء عدة مواعيد.

2. المواعيد ←→ المشاركون (Many-to-Many)
text
appointments (1) → event_participants (many)
users (1) → event_participants (many)
موعد واحد له عدة مشاركين، ومستخدم واحد مشارك في عدة مواعيد.

3. المستخدم ←→ المستخدم (المتابعات)
text
users (many) → user_follows (many) → users (many)
علاقة متابعة متبادلة بين المستخدمين.

4. المواعيد ←→ الملاحظات
text
appointments (1) → event_private_notes (many)
users (1) → event_private_notes (many)
ملاحظات خاصة لكل مستخدم في كل موعد.

🔍 استعلامات شائعة
1. مواعيد المستخدم (كمضيف)
sql
SELECT * FROM appointments 
WHERE host = '[user_id]'
  AND is_deleted = FALSE
  AND is_cancelled = FALSE
ORDER BY date DESC, time DESC;
2. مواعيد المستخدم (كمشارك مقبول)
sql
SELECT a.* FROM appointments a
JOIN event_participants ep ON a.id = ep.event_id
WHERE ep.user_id = '[user_id]'
  AND ep.status = 'accepted'
  AND a.is_deleted = FALSE
  AND a.is_cancelled = FALSE
ORDER BY a.date, a.time;
3. المشاركون في موعد مع حالتهم
sql
SELECT 
    u.id, u.name, u.avatar, u.username,
    ep.status, ep.is_host, ep.responded_at
FROM event_participants ep
JOIN users u ON ep.user_id = u.id
WHERE ep.event_id = '[appointment_id]'
ORDER BY ep.is_host DESC, ep.status, u.name;
4. مواعيد قادمة (اليوم والغد)
sql
SELECT * FROM appointments 
WHERE date >= DATE('now')
  AND date <= DATE('now', '+1 day')
  AND is_cancelled = FALSE
  AND is_deleted = FALSE
ORDER BY date, time;
5. إحصائيات المستخدم
sql
SELECT 
    (SELECT COUNT(*) FROM appointments WHERE host = '[user_id]') as hosted_count,
    (SELECT COUNT(*) FROM event_participants WHERE user_id = '[user_id]' AND status = 'accepted') as participating_count,
    (SELECT COUNT(*) FROM user_follows WHERE followed_id = '[user_id]') as followers_count,
    (SELECT COUNT(*) FROM user_follows WHERE follower_id = '[user_id]') as following_count;
6. البحث عن مواعيد في منطقة
sql
SELECT * FROM appointments 
WHERE region LIKE '%الرياض%'
  AND privacy = 'public'
  AND date >= DATE('now')
  AND is_cancelled = FALSE
ORDER BY date, time
LIMIT 20;
🔐 سياسات الوصول
المواعيد:
العامة: جميع المستخدمين المصادقين

الخاصة: المالك + المشاركون المقبولون فقط

الملفات الشخصية:
عامة للجميع: الاسم، الصورة، النبذة، الإحصائيات

خاصة للصاحب فقط: البريد، الهاتف

المتابعات:
ظاهرة للجميع: قائمة المتابعين والمتابَعين

الملاحظات الخاصة:
خاصة للصاحب فقط: لا يراها أحد غيره

📈 تحسينات الأداء
الفهارس الموصى بها:
الفهارس الأساسية: مفاتيح أساسية وفريدة

فهارس البحث: على الحقول المستخدمة في WHERE

فهارس الترتيب: على الحقول المستخدمة في ORDER BY

فهارس التجميع: على الحقول المستخدمة في GROUP BY

استراتيجيات التخزين المؤقت:
Redis: للتخزين المؤقت للاستعلامات المتكررة

CDN: للصور والملفات الثابتة

ذاكرة التطبيق: للبيانات الصغيرة المتكررة

تقسيم البيانات:
تجزئة المواعيد: حسب السنة/الشهر للبيانات الكبيرة

أرشفة القديمة: نقل المواعيد الأقدم من سنة

فصل الجداول: للبيانات النشطة مقابل الأرشيف

🛠️ صيانة قاعدة البيانات
التنظيف الدوري:
sql
-- حذف المواعيد المحذوفة لأكثر من 30 يوم
DELETE FROM appointments 
WHERE is_deleted = TRUE 
  AND updated < DATE('now', '-30 days');

-- أرشفة الإشعارات القديمة
UPDATE notifications 
SET is_archived = TRUE 
WHERE created < DATE('now', '-90 days');

-- تحديث الإحصائيات
UPDATE users 
SET appointments_count = (
  SELECT COUNT(*) FROM appointments 
  WHERE host = users.id AND is_deleted = FALSE
);
النسخ الاحتياطي:
bash
# نسخ قاعدة SQLite
sqlite3 data.db ".backup 'backup-$(date +%Y%m%d).db'"

# تصدير البيانات المهمة
sqlite3 data.db ".dump users appointments" > backup.sql
⚠️ ملاحظات مهمة
1. سلامة البيانات:
جميع الحذف يكون ON DELETE CASCADE

استخدام TRANSACTIONS للعمليات المتعددة

النسخ الاحتياطي اليومي

2. التوافق مع PocketBase:
اتبع تسمية الحقول القياسية

استخدم JSON للحقول الديناميكية

احترم قيود PocketBase

3. التوسع المستقبلي:
تصميم يدعم إضافة حقول جديدة

فهارس قابلة للتعديل

هيكل مرن للتغييرات

آخر تحديث: أبريل 2025
الإصدار: 1.0
قاعدة البيانات: SQLite via PocketBase