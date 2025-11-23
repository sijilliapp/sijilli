import 'package:hijri/hijri_calendar.dart';
import 'auth_service.dart';

/// 🏢 CENTRAL HIJRI SERVICE - غرفة العمليات المركزية 🏢
/// 
/// المنطق الجديد البسيط:
/// - التصحيح يطبق مرة واحدة عند التغيير (مثل صبغ الباب)
/// - الصفحات تعرض التواريخ المصححة كما هي (الباب أخضر للجميع)
/// - لا حاجة لتشغيل التصحيح في كل زيارة
class HijriService {
  static final HijriService _instance = HijriService._internal();
  factory HijriService() => _instance;
  HijriService._internal();

  final AuthService _authService = AuthService();
  int? _temporaryAdjustment; // للمعاينة أثناء التعديل فقط
  
  /// الحصول على تصحيح المستخدم الحالي
  int get currentUserAdjustment {
    return _authService.currentUser?.hijriAdjustment ?? 0;
  }
  
  /// الحصول على التصحيح المستخدم (مؤقت أو دائم)
  int get currentAdjustment {
    return _temporaryAdjustment ?? currentUserAdjustment;
  }
  
  /// تعيين تصحيح مؤقت للمعاينة (أثناء التعديل)
  void setTemporaryAdjustment(int adjustment) {
    _temporaryAdjustment = adjustment;
  }
  
  /// إزالة التصحيح المؤقت
  void clearTemporaryAdjustment() {
    _temporaryAdjustment = null;
  }

  /// تحديث تصحيح الهجري من بيانات المستخدم الحالية
  void refreshHijriAdjustment() {
    // إزالة التصحيح المؤقت وإعادة قراءة من المستخدم
    clearTemporaryAdjustment();
  }
  
  /// تحويل من ميلادي إلى هجري مع التصحيح الحالي (مؤقت أو دائم)
  /// هذا هو المحرك الأساسي لجميع التحويلات
  HijriCalendar convertGregorianToHijri(DateTime gregorianDate) {
    final adjustment = currentAdjustment;
    final adjustedDate = gregorianDate.add(Duration(days: adjustment));
    return HijriCalendar.fromDate(adjustedDate);
  }

  /// تحويل من ميلادي إلى هجري مع تصحيح محدد
  HijriCalendar convertGregorianToHijriWithAdjustment(DateTime gregorianDate, int adjustment) {
    final adjustedDate = gregorianDate.add(Duration(days: adjustment));
    return HijriCalendar.fromDate(adjustedDate);
  }

  /// تحويل من هجري إلى ميلادي مع التصحيح العكسي
  DateTime convertHijriToGregorian(int year, int month, int day) {
    final hijriCalendar = HijriCalendar();
    final gregorianDate = hijriCalendar.hijriToGregorian(year, month, day);
    final adjustment = currentAdjustment;
    // التصحيح العكسي للتحويل من هجري لميلادي
    return gregorianDate.subtract(Duration(days: adjustment));
  }

  /// تحويل من هجري إلى ميلادي مع تصحيح محدد
  DateTime convertHijriToGregorianWithAdjustment(int year, int month, int day, int adjustment) {
    final hijriCalendar = HijriCalendar();
    final gregorianDate = hijriCalendar.hijriToGregorian(year, month, day);
    return gregorianDate.subtract(Duration(days: adjustment));
  }
  
  /// تنسيق التاريخ الهجري كنص عربي
  String formatHijriDate(HijriCalendar hijriDate) {
    const months = [
      'محرم', 'صفر', 'ربيع 1', 'ربيع 2',
      'جمادى 1', 'جمادى 2', 'رجب', 'شعبان',
      'رمضان', 'شوال', 'ذو القعدة', 'ذو الحجة'
    ];
    
    final monthName = months[hijriDate.hMonth - 1];
    return '\u200E${hijriDate.hDay} $monthName ${hijriDate.hYear} هـ';
  }
  
  /// الحصول على تاريخ اليوم الهجري مع التصحيح
  HijriCalendar getTodayHijri() {
    return convertGregorianToHijri(DateTime.now());
  }
  
  /// تحويل بسيط بدون تصحيح (للاستخدام الداخلي)
  HijriCalendar convertGregorianToHijriRaw(DateTime gregorianDate) {
    return HijriCalendar.fromDate(gregorianDate);
  }

  /// تحويل بسيط بدون تصحيح (للاستخدام الداخلي)
  DateTime convertHijriToGregorianRaw(int year, int month, int day) {
    final hijriCalendar = HijriCalendar();
    return hijriCalendar.hijriToGregorian(year, month, day);
  }

  /// الحصول على تاريخ اليوم الهجري كنص
  String getTodayHijriString() {
    final today = getTodayHijri();
    return formatHijriDate(today);
  }

  /// الحصول على التاريخ الهجري المصحح (الطريقة الواضحة)
  String getAdjustedHijriDate(DateTime gregorianDate, int adjustment) {
    final adjustedDate = gregorianDate.add(Duration(days: adjustment));
    final hijriDate = HijriCalendar.fromDate(adjustedDate);
    return formatHijriDate(hijriDate);
  }

  /// الحصول على التاريخ الهجري المصحح لليوم
  String getTodayAdjustedHijriDate(int adjustment) {
    return getAdjustedHijriDate(DateTime.now(), adjustment);
  }

  /// الحصول على اسم الشهر الميلادي
  String getGregorianMonthName(int month) {
    const months = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    return months[month - 1];
  }
}
