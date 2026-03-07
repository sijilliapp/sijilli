# 🚀 دليل نشر تطبيق "سجلي"

## 📋 نظرة عامة
هذا الدليل يشرح خطوات نشر تطبيق "سجلي" في بيئة الإنتاج.

---

## 🎯 متطلبات ما قبل النشر

### 1. المتطلبات الفنية:
- ✅ Flutter SDK 3.10+
- ✅ Dart 3.0+
- ✅ PocketBase 0.10+
- ✅ Git

### 2. حسابات مطلوبة:
- [ ] Google Play Console (لأندرويد)
- [ ] Apple Developer Account (لأيفون)
- [ ] خادم VPS أو استضافة
- [ ] نطاق (Domain)

### 3. التحضيرات:
```bash
# تأكد من إصدار Flutter
flutter --version

# تشغيل جميع الاختبارات
flutter test

# التحقق من التحليلات
flutter analyze

# اختبار على أجهزة مختلفة
flutter run --release
🖥️ نشر Backend (PocketBase)
الخيار 1: خادم VPS (مُوصى به)
bash
# 1. الاتصال بالخادم
ssh user@server_ip

# 2. إنشاء مجلد التطبيق
mkdir -p /opt/sijilli
cd /opt/sijilli

# 3. تنزيل PocketBase
wget https://github.com/pocketbase/pocketbase/releases/download/v0.10.0/pocketbase_0.10.0_linux_amd64.zip
unzip pocketbase_0.10.0_linux_amd64.zip
chmod +x pocketbase

# 4. إنشاء دليل البيانات
mkdir data

# 5. تشغيل كخدمة systemd
sudo nano /etc/systemd/system/sijilli.service
ملف الخدمة: /etc/systemd/system/sijilli.service

ini
[Unit]
Description=Sijilli PocketBase Backend
After=network.target

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/opt/sijilli
ExecStart=/opt/sijilli/pocketbase serve --http=0.0.0.0:8090
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
تشغيل الخدمة:

bash
sudo systemctl daemon-reload
sudo systemctl enable sijilli
sudo systemctl start sijilli
sudo systemctl status sijilli
الخيار 2: Railway.app (أسهل)
سجّل في Railway.app

أنشئ مشروعاً جديداً

اختر "Deploy from GitHub"

اختر PocketBase template

اضبط المتغيرات البيئية

انقر Deploy

الخيار 3: Docker (للمتقدمين)
dockerfile
# Dockerfile
FROM alpine:latest

RUN apk add --no-cache \
    ca-certificates \
    unzip \
    wget

WORKDIR /app

RUN wget https://github.com/pocketbase/pocketbase/releases/download/v0.10.0/pocketbase_0.10.0_linux_amd64.zip \
    && unzip pocketbase_0.10.0_linux_amd64.zip \
    && chmod +x /app/pocketbase \
    && rm pocketbase_0.10.0_linux_amd64.zip

EXPOSE 8090

CMD ["/app/pocketbase", "serve", "--http=0.0.0.0:8090"]
bash
# بناء وتشغيل
docker build -t sijilli-backend .
docker run -d -p 8090:8090 -v ./pb_data:/app/data sijilli-backend
🔧 إعداد Nginx كـ Reverse Proxy
1. تثبيت Nginx:
bash
sudo apt update
sudo apt install nginx -y
2. إعداد Virtual Host:
bash
sudo nano /etc/nginx/sites-available/sijilli
إعدادات Nginx:

nginx
server {
    listen 80;
    server_name sijilli.com www.sijilli.com;
    
    # إعادة التوجيه إلى HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name sijilli.com www.sijilli.com;
    
    # شهادات SSL (Let's Encrypt)
    ssl_certificate /etc/letsencrypt/live/sijilli.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/sijilli.com/privkey.pem;
    
    # إعدادات SSL
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    
    # Reverse Proxy إلى PocketBase
    location / {
        proxy_pass http://localhost:8090;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # زيادة المهلات للمراسلة المباشرة
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
    }
    
    # الحد الأقصى لحجم الملفات المرفوعة
    client_max_body_size 10M;
    
    # تسريع الثابتة
    location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
3. تفعيل وتشغيل:
bash
sudo ln -s /etc/nginx/sites-available/sijilli /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
4. شهادات SSL (Let's Encrypt):
bash
sudo apt install certbot python3-certbot-nginx -y
sudo certbot --nginx -d sijilli.com -d www.sijilli.com
# سيتم التجديد تلقائياً
📱 بناء تطبيق Flutter
1. إعداد المفاتيح والتوقيع:
أندرويد (Android):

bash
# إنشاء keystore
keytool -genkey -v -keystore sijilli.jks -keyalg RSA -keysize 2048 -validity 10000 -alias sijilli

# إعداد key.properties
echo "storePassword=your_password
keyPassword=your_password
keyAlias=sijilli
storeFile=../android/sijilli.jks" > android/key.properties
أيفون (iOS):

افتح Xcode → ios/Runner.xcworkspace

اضبط Bundle Identifier

أضف فريق التطوير

أنشئ Certificates في Apple Developer Portal

2. تحديث الإعدادات:
lib/core/constants/pocketbase_config.dart:

dart
class PocketBaseConfig {
  static const String baseUrl = 'https://api.sijilli.com';
  static const bool isProduction = true;
}
android/app/build.gradle:

gradle
android {
    defaultConfig {
        applicationId "com.sijilli.app"
        versionCode 1
        versionName "1.0.0"
    }
    
    signingConfigs {
        release {
            storeFile file("sijilli.jks")
            storePassword System.getenv("KEYSTORE_PASSWORD")
            keyAlias "sijilli"
            keyPassword System.getenv("KEY_PASSWORD")
        }
    }
    
    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
}
3. بناء التطبيق:
أندرويد (APK):

bash
flutter build apk --release --split-per-abi
# الناتج: build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk
# الناتج: build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
# الناتج: build/app/outputs/flutter-apk/app-x86_64-release.apk
أندرويد (App Bundle - للتسليم):

bash
flutter build appbundle --release
# الناتج: build/app/outputs/bundle/release/app-release.aab
أيفون (IPA):

bash
flutter build ipa --release --export-options-plist=ExportOptions.plist
# الناتج: build/ios/ipa/sijilli.ipa
ويب (Web):

bash
flutter build web --release
# الناتج: build/web
🚀 رفع التطبيق للمتاجر
Google Play Store:
سجّل في Play Console

أنشئ تطبيقاً جديداً

ارفع ملف .aab

املأ معلومات المتجر

أضف لقطات شاشة

أرسل للمراجعة

انتظر الموافقة (24-48 ساعة)

Apple App Store:
سجّل في App Store Connect

أنشئ New App

ارفع ملف .ipa عبر Xcode أو Transporter

املأ معلومات التطبيق

أضف الصور والفيديوهات

أرسل للمراجعة

انتظر الموافقة (1-7 أيام)

🌐 نشر موقع الويب (اختياري)
بناء وإعداد:
bash
# بناء نسخة الويب
flutter build web --release --base-href /web/

# رفع للمضيف
scp -r build/web/* user@server:/var/www/sijilli/

# أو استخدام Firebase Hosting
firebase init hosting
firebase deploy --only hosting
إعدادات Nginx للويب:
nginx
server {
    listen 80;
    server_name app.sijilli.com;
    
    root /var/www/sijilli;
    index index.html;
    
    location / {
        try_files $uri $uri/ /index.html;
    }
    
    # Cache static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
🔧 إعداد قاعدة البيانات
1. النسخ الاحتياطي الأولي:
bash
# من بيئة التطوير
sqlite3 data.db ".backup 'production-backup.db'"

# نسخ للخادم
scp production-backup.db user@server:/opt/sijilli/data/
2. استعادة البيانات:
bash
# في الخادم
cd /opt/sijilli
cp data/production-backup.db data/data.db
sudo systemctl restart sijilli
3. تهيئة المدير الأول:
bash
# الوصول لوحة إدارة PocketBase
https://api.sijilli.com/_/

# إنشاء حساب مدير
Email: admin@sijilli.com
Password: تغيير_هذه_كلمة_المرور

# إنشاء المجموعات والقواعد
🛡️ إعدادات الأمان
1. جدار الحماية:
bash
# إعداد UFW
sudo ufw allow ssh
sudo ufw allow http
sudo ufw allow https
sudo ufw enable
2. تحديث النظام:
bash
sudo apt update && sudo apt upgrade -y
sudo apt autoremove -y
3. إعدادات PocketBase الآمنة:
bash
# تشغيل مع HTTPS داخلي
./pocketbase serve --https=/path/to/cert

# تقييد IPs المسموح بها
# في إعدادات Nginx
allow 192.168.1.0/24;
deny all;
4. مراقبة السجلات:
bash
# مراقبة سجلات PocketBase
sudo journalctl -u sijilli -f

# مراقبة سجلات Nginx
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
📊 المراقبة والصيانة
1. مراقبة الأداء:
bash
# استخدام الـ CPU والذاكرة
htop

# مراقبة الشبكة
iftop

# مساحة التخزين
df -h
2. النسخ الاحتياطي التلقائي:
bash
# إنشاء script نسخ احتياطي
sudo nano /opt/sijilli/backup.sh
محتوى backup.sh:

bash
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/opt/sijilli/backups"
DB_PATH="/opt/sijilli/data/data.db"

mkdir -p $BACKUP_DIR
sqlite3 $DB_PATH ".backup '$BACKUP_DIR/backup_$DATE.db'"

# حذف النسخ القديمة (أقدم من 30 يوم)
find $BACKUP_DIR -name "*.db" -mtime +30 -delete
إضافة لـ crontab:

bash
sudo crontab -e
# نسخ احتياطي يومي الساعة 2 صباحاً
0 2 * * * /bin/bash /opt/sijilli/backup.sh
3. تحديث التطبيق:
bash
# إيقاف الخدمة
sudo systemctl stop sijilli

# النسخ الاحتياطي
cp /opt/sijilli/data/data.db /opt/sijilli/backups/data_$(date +%Y%m%d).db

# تحديث PocketBase
cd /opt/sijilli
wget [أحدث إصدار]
unzip [الملف الجديد]

# إعادة التشغيل
sudo systemctl start sijilli
🐛 استكشاف الأخطاء
مشاكل شائعة وحلولها:
1. PocketBase لا يعمل:

bash
# التحقق من السجلات
sudo journalctl -u sijilli --no-pager -n 50

# التحقق من الصلاحيات
ls -la /opt/sijilli/data/
sudo chown -R www-data:www-data /opt/sijilli
2. مشاكل في SSL:

bash
# تجديد الشهادة
sudo certbot renew --dry-run

# اختبار SSL
sslshopper.com/ssl-checker.html
3. مشاكل في الاتصال:

bash
# اختبار الوصول
curl https://api.sijilli.com/api/health

# اختبار المنافذ
telnet sijilli.com 443
4. مشاكل في الذاكرة:

bash
# زيادة swap memory
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
📈 قياس الأداء
مقاييس مهمة:
وقت استجابة API ← يجب أن يكون < 200ms

وقت تحميل التطبيق ← يجب أن يكون < 3 ثواني

معدل الأخطاء ← يجب أن يكون < 1%

وقت التشغيل ← يجب أن يكون > 99.5%

أدوات المراقبة:
UptimeRobot ← مراقبة وقت التشغيل

Google Analytics ← تحليلات المستخدمين

Sentry ← تتبع الأخطاء

Custom Dashboard ← باستخدام PocketBase APIs

🔄 تحديث التطبيق
1. تحديث Flutter App:
bash
# جلب التحديثات
git pull origin main

# تحديث الاعتماديات
flutter pub get

# إعادة البناء
flutter build appbundle --release
flutter build ipa --release

# رفع للمتاجر
2. تحديث Backend:
bash
# إيقاف مؤقت
sudo systemctl stop sijilli

# نسخ احتياطي
cp -r /opt/sijilli/data /opt/sijilli/data_backup_$(date +%Y%m%d)

# تحديث PocketBase
cd /opt/sijilli
wget [الإصدار الجديد]
unzip [ملف الإصدار]

# إعادة التشغيل
sudo systemctl start sijilli

# اختبار
curl https://api.sijilli.com/api/health
3. التواصل مع المستخدمين:
إشعارات داخل التطبيق

تحديث سجلات التغيير

دعم التحديثات الإلزامية عند الحاجة

📞 الدعم والصيانة
قنوات الدعم:
البريد الإلكتروني ← support@sijilli.com

تويتر ← @SijilliApp

داخل التطبيق ← صفحة المساعدة

سياسة الصيانة:
تحديثات أمنية: خلال 24 ساعة

إصلاح الأخطاء الحرجة: خلال 48 ساعة

إضافة ميزات: حسب الجدول الزمني

دعم المستخدمين: خلال 24 ساعة عمل

🎯 الخلاصة
✅ التحقق النهائي قبل الإطلاق:
جميع الاختبارات تعمل

SSL يعمل بشكل صحيح

النسخ الاحتياطي يعمل

المراقبة مفعلة

الدعم جاهز

التوثيق محدث

اختبار الحمل تم تنفيذه

📊 معايير النجاح:
⏱️ وقت استجابة < 200ms

📱 وقت تحميل < 3 ثواني

🚀 وقت تشغيل > 99.5%

😊 رضا المستخدمين > 4.5/5

آخر تحديث: أبريل 2025
إصدار الدليل: 1.0
حالة: جاهز للإنتاج ✅