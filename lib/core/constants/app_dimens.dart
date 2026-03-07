// 📍 lib/core/constants/app_dimens.dart
// 📏 قياسات تطبيق "سجلي" - القيم العددية فقط

class AppDimens {
  // ====================== المسافات (Spacing) ======================
  static const double spaceXXS = 2.0;
  static const double spaceXS = 4.0;
  static const double spaceTiny = 6.0;
  static const double spaceS = 8.0;
  static const double spaceCompact = 10.0;
  static const double spaceM = 12.0;
  static const double spaceSubtitle = 18.0; // Added for subtitle spacing
  static const double space = 16.0;      // المسافة القياسية
  static const double spaceL = 20.0;
  static const double spaceXL = 24.0;
  static const double spaceXXL = 32.0;
  static const double spaceXXXL = 48.0;
  static const double spaceHuge = 64.0;
  static const double spaceGiant = 80.0;
  
  // ====================== أنصاف الأقطار (Border Radius) ======================
  static const double radiusXS = 4.0;
  static const double radiusS = 6.0;
  static const double radius = 8.0;      // نصف القطر القياسي
  static const double radiusM = 12.0;
  static const double radiusL = 16.0;
  static const double radiusXL = 20.0;
  static const double radiusXXL = 24.0;
  static const double radiusRound = 999.0; // للعناصر الدائرية
  static const double radiusCircle = 22.0; // Fixed circle radius for compact buttons
  
  // ====================== أحجام الأزرار ======================
  static const double buttonHeightXS = 32.0;
  static const double buttonHeightS = 40.0;
  static const double buttonHeightCompact = 44.0; // Added for compact action buttons
  static const double buttonHeight = 48.0;  // الارتفاع القياسي
  static const double buttonHeightL = 56.0;
  static const double buttonHeightXL = 64.0;
  static const double buttonMinWidth = 88.0;
  static const double buttonMaxWidth = 200.0;
  static const double buttonPaddingHorizontal = space;
  static const double buttonPaddingVertical = spaceS;
  
  // ====================== أحجام النصوص ======================
  static const double textSizeXXS = 10.0;
  static const double textSizeXS = 12.0;
  static const double textSizeS = 14.0;
  static const double textSize = 16.0;      // الحجم القياسي
  static const double textSizeM = 18.0;
  static const double textSizeL = 20.0;
  static const double textSizeXL = 24.0;
  static const double textSizeXXL = 28.0;
  static const double textSizeHuge = 32.0;
  static const double textSizeGiant = 40.0;
  
  // ====================== أحجام الصور والأيقونات ======================
  static const double iconSizeXS = 16.0;
  static const double iconSizeS = 20.0;
  static const double iconSize = 24.0;      // الحجم القياسي
  static const double iconSizeL = 28.0;
  static const double iconSizeXL = 32.0;
  static const double iconSizeXXL = 40.0;
  
  static const double avatarSizeXS = 32.0;
  static const double avatarSizeS = 40.0;
  static const double avatarSize = 48.0;    // الحجم القياسي
  static const double avatarSizeL = 56.0;
  static const double avatarSizeXL = 64.0;
  static const double avatarSizeXXL = 80.0;
  static const double avatarSizeProfile = 140.0;
  
  // Avatar Ring Configuration (used by PulseAvatar)
  static const double avatarRingWidthRatio = 0.035;  // Ring width as ratio of avatar size
  static const double avatarRingGapRatio = 0.035;    // Gap between ring and image (same as ring width)
  
  // ====================== أحجام البطاقات ======================
  static const double cardHeightXS = 80.0;
  static const double cardHeightS = 100.0;
  static const double cardHeight = 120.0;   // الارتفاع القياسي
  static const double cardHeightL = 140.0;
  static const double cardHeightXL = 160.0;
  static const double cardPaddingXS = spaceS;
  static const double cardPaddingS = spaceM;
  static const double cardPadding = space;  // Padding القياسي
  static const double cardPaddingL = spaceL;
  static const double cardPaddingXL = spaceXL;

  // ====================== بطاقة المواعيد (Appointment Card) ======================
  static const double appointmentCardBorderWidth = 1.5;
  static const double appointmentCardElevation = 2.0;
  static const double appointmentCardElevationNow = 6.0;
  static const double appointmentCardRadius = radiusM;
  
  // ====================== أحجام العناصر الخاصة ======================
  static const double bottomNavBarHeight = 56.0;
  static const double bottomNavBarIconSize = 24.0;
  static const double tabBarHeight = 48.0;
  static const double tabIndicatorHeight = 2.0;
  static const double appBarHeight = 56.0;
  static const double appBarElevation = 0.0;
  static const double textFieldHeight = 56.0;
  static const double textFieldBorderWidth = 1.0;
  static const double listTileHeight = 56.0;
  static const double fabSize = 56.0;
  static const double fabMiniSize = 40.0;
  static const double dividerThickness = 1.0;
  
  // ====================== أحجام الظلال ======================
  static const double elevationNone = 0.0;
  static const double elevationXS = 1.0;
  static const double elevationS = 2.0;
  static const double elevation = 4.0;      // الارتفاع القياسي
  static const double elevationL = 8.0;
  static const double elevationXL = 16.0;
  
  // أضف في قسم "المسافات":
  static const double padding = 16.0;
  static const double paddingSmall = 8.0;
  static const double paddingLarge = 24.0;
  static const double inputPadding = 12.0;

  // أضف في قسم "أحجام النصوص":
  static const double fontSizeDisplay = 32.0;
  static const double fontSizeHeadline = 24.0;
  static const double fontSizeTitle = 20.0;
  static const double fontSizeSubtitle = 18.0;
  static const double fontSizeBody = 16.0;
  static const double fontSizeCaption = 14.0;

  // أضف في قسم "القياسات العامة":
  static const double lineHeight = 1.2;
  static const double lineHeightLoose = 1.5;

// أضف في قسم "الظلال":
static const double cardElevation = 4.0;
static const double cardElevationHigh = 8.0;
  
  // 📌 ملاحظة مهمة: لا تستخدم قياسات Hardcoded في أي مكان!
  // ❌ خطأ: SizedBox(width: 16)
  // ✅ صح: SizedBox(width: AppDimens.space)
  // ✅ أفضل: const SizedBox(width: AppDimens.space)
}