// 📍 lib/core/constants/app_colors.dart
// 🎨 ألوان تطبيق "سجلي" - مع دعم Dark/Light Themes

import 'package:flutter/material.dart';

class AppColors {
  // ====================== الألوان الأساسية ======================
  // 🔵 الألوان الأساسية
  static const Color primary = Color(0xFF3B82F6);    // أزرق أساسي
  static const Color primaryDark = Color(0xFF1E40AF); // أزرق داكن
  static const Color primaryLight = Color(0xFF93C5FD); // أزرق فاتح
  
  // 🟢 الألوان الثانوية
  static const Color secondary = Color(0xFF10B981);   // أخضر
  static const Color secondaryDark = Color(0xFF047857); // أخضر داكن
  static const Color secondaryLight = Color(0xFFA7F3D0); // أخضر فاتح
  
  // 🔴 ألوان التحذير والحالات
  static const Color warning = Color(0xFFEF4444);     // أحمر (خطأ/رفض)
  static const Color warningDark = Color(0xFFB91C1C); // أحمر داكن
  static const Color warningLight = Color(0xFFFCA5A5); // أحمر فاتح
  
  static const Color success = Color(0xFF10B981);     // أخضر (نجاح)
  static const Color info = Color(0xFF3B82F6);        // أزرق (معلومات)
  
  // 🟡 ألوان التنبيه
  static const Color alert = Color(0xFFF59E0B);       // برتقالي (تنبيه)
  static const Color alertDark = Color(0xFFD97706);   // برتقالي داكن
  static const Color alertLight = Color(0xFFFCD34D);  // برتقالي فاتح
  
  // ====================== ألوان الوضع الفاتح ======================
  static const Color lightBackground = Color(0xFFF9FAFB);    // رمادي فاتح جداً
  static const Color lightCardBackground = Color(0xFFFFFFFF); // أبيض
  static const Color lightSurface = Color(0xFFF3F4F6);       // سطح رمادي فاتح
  
  // نصوص الوضع الفاتح
  static const Color lightTextPrimary = Color(0xFF111827);   // أسود داكن
  static const Color lightTextSecondary = Color(0xFF6B7280); // رمادي داكن
  static const Color lightTextHint = Color(0xFF9CA3AF);      // رمادي متوسط
  static const Color lightTextDisabled = Color(0xFFD1D5DB);  // رمادي فاتح
  
  // عناصر الوضع الفاتح
  static const Color lightDivider = Color(0xFFE5E7EB);       // فاصل
  static const Color lightBorder = Color(0xFFD1D5DB);        // حدود
  static const Color lightShadow = Color(0x1A000000);        // ظل (10% شفافية)
  
  // ====================== ألوان الوضع الداكن ======================
  static const Color darkBackground = Color(0xFF111827);     // أسود مزرق
  static const Color darkCardBackground = Color(0xFF1F2937); // رمادي داكن جداً
  static const Color darkSurface = Color(0xFF374151);        // سطح رمادي داكن
  
  // نصوص الوضع الداكن
  static const Color darkTextPrimary = Color(0xFFF9FAFB);    // أبيض فاتح
  static const Color darkTextSecondary = Color(0xFFD1D5DB);  // رمادي فاتح
  static const Color darkTextHint = Color(0xFF9CA3AF);       // رمادي متوسط
  static const Color darkTextDisabled = Color(0xFF6B7280);   // رمادي داكن
  
  // عناصر الوضع الداكن
  static const Color darkDivider = Color(0xFF374151);        // فاصل داكن
  static const Color darkBorder = Color(0xFF4B5563);         // حدود داكنة
  static const Color darkShadow = Color(0x33000000);         // ظل داكن (20% شفافية)
  
  // ⚫ ألوان النصوص (إذا لم تكن موجودة)
  static const Color background = lightBackground; // Alias for lightBackground
  static const Color text = textPrimary; // Alias for textPrimary
  static const Color textPrimary = Color(0xFF111827);   // أسود داكن
  static const Color textSecondary = Color(0xFF6B7280); // رمادي داكن ← هذا المفقود!
  static const Color textHint = Color(0xFF9CA3AF);      // رمادي متوسط ← هذا المفقود!
  static const Color textDisabled = Color(0xFFD1D5DB);  // رمادي فاتح

  // 🌈 ألوان إضافية (إذا لم تكن موجودة)
  static const Color divider = Color(0xFFE5E7EB);       // فاصل
  static const Color border = Color(0xFFD1D5DB);        // حدود ← هذا المفقود!

  // ====================== ألوان مشتركة ======================
  // 🎨 ألوان المواعيد (الحالات) - تعمل في الوضعين
  static const Color appointmentPending = Color(0xFF9CA3AF);   // رمادي (معلق)
  static const Color appointmentAccepted = Color(0xFF3B82F6);  // أزرق (مقبول)
  static const Color appointmentDeclined = Color(0xFFEF4444);  // أحمر (مرفوض)
  static const Color appointmentDeleted = Color(0xFF6B7280);   // رمادي داكن (محذوف)
  
  // ✨ ألوان خاصة
  static const Color shimmerBase = Color(0xFFE5E7EB);   // أساس الـ Shimmer (فاتح)
  static const Color shimmerDarkBase = Color(0xFF374151); // أساس الـ Shimmer (داكن)
  static const Color shimmerHighlight = Color(0xFFF9FAFB); // توهج الـ Shimmer
  
  // 🔵 حالة المستخدم (الطوق حول الصورة)
  static const Color userRingNormal = Color(0xFF9CA3AF);      // رمادي (عادي)
  static const Color userRingToday = Color(0xFF3B82F6);       // أزرق (عنده موعد اليوم)
  static const Color userRingActive = Color(0xFF3B82F6);      // أزرق (موعد نشط الآن)
  static const Color userRingActiveGlow = Color(0x663B82F6);  // أزرق مشع (40% شفافية)
  
  // 🎯 ألوان الأزرار (تعمل في الوضعين)
  static const Color buttonPrimary = Color(0xFF3B82F6);
  static const Color buttonPrimaryText = Color(0xFFFFFFFF);
  static const Color buttonSecondary = Color(0xFFF3F4F6);      // فاتح في Light
  static const Color buttonSecondaryDark = Color(0xFF374151);  // داكن في Dark
  static const Color buttonSecondaryText = Color(0xFF111827);  // داكن في Light
  static const Color buttonSecondaryTextDark = Color(0xFFF9FAFB); // فاتح في Dark
  static const Color buttonDisabled = Color(0xFFD1D5DB);
  static const Color buttonDisabledText = Color(0xFF9CA3AF);
  
  // 💎 ألوان الهوية البصرية (ثابتة)
  static const Color sijilliBlue = Color(0xFF3B82F6);    // الأزرق الرسمي
  static const Color sijilliGreen = Color(0xFF10B981);   // الأخضر الرسمي
  static const Color sijilliRed = Color(0xFFEF4444);     // الأحمر الرسمي
  
  // أضف هذه الثوابت في قسم "ألوان مشتركة":
  static const Color surface = Color(0xFFFFFFFF);
  static const Color onSurface = Color(0xFF000000);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color card = Color(0xFFFFFFFF);
  static const Color outline = Color(0xFFE5E7EB);
  static const Color shadow = Color(0x1A000000);

  // ألوان الحالات
  static const Color error = Color(0xFFEF4444);

  // ألوان المواعيد
  static const Color appointmentActive = Color(0xFF10B981);
  static const Color appointmentCancelled = Color(0xFFEF4444);

  // ألوان التواريخ
  static const Color hijriGreen = Color(0xFF059669);
  static const Color gregorianBlue = Color(0xFF3B82F6);
  
  // ====================== بطاقة المواعيد (Appointment Card States) ======================
  static const Color appointmentCardBorderNow = primary;         // أزرق بارز
  static const Color appointmentCardBorderUpcoming = primary;    // أزرق أساسي كامل (بدون شفافية)
  static const Color appointmentCardBorderPast = Color(0x4D9CA3AF);     // رمادي باهت (30% شفافية)
  static const Color appointmentCardBorderError = Color(0x80EF4444);    // أحمر تنبيهي (50% شفافية)
  
  static const Color appointmentCardBackground = Color(0xFFF3F9FF);     // أزرق فاتح جداً للبطاقات
  
  // ====================== دوال مساعدة ======================
  /// الحصول على لون الخلفية بناءً على الثيم
  static Color getBackground(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkBackground
        : lightBackground;
  }
  
  /// الحصول على لون النص الأساسي بناءً على الثيم
  static Color getTextPrimary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkTextPrimary
        : lightTextPrimary;
  }

  /// الحصول على لون النص الثانوي بناءً على الثيم
  static Color getTextSecondary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkTextSecondary
        : lightTextSecondary;
  }
  
  /// الحصول على لون البطاقة بناءً على الثيم
  static Color getCardBackground(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkCardBackground
        : lightCardBackground;
  }
  
  /// الحصول على لون الثانوي للزر بناءً على الثيم
  static Color getButtonSecondary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? buttonSecondaryDark
        : buttonSecondary;
  }
  
  /// الحصول على لون نص الزر الثانوي بناءً على الثيم
  static Color getButtonSecondaryText(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? buttonSecondaryTextDark
        : buttonSecondaryText;
  }

  /// الحصول على لون الحدود بناءً على الثيم
  static Color getBorder(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkBorder
        : lightBorder;
  }
  
  /// الحصول على لون التلميح بناءً على الثيم
  static Color getHintColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkTextHint
        : lightTextHint;
  }

  // 📌 ملاحظة مهمة: لا تستخدم ألوان Hardcoded في أي مكان!
  // ❌ خطأ: Container(color: Colors.blue)
  // ❌ خطأ: Container(color: Color(0xFF000000))
  
  // ✅ صح: Container(color: AppColors.primary)
  // ✅ أفضل: Container(color: AppColors.getBackground(context))
  // ✅ ممتاز: Container(color: Theme.of(context).colorScheme.background)
}