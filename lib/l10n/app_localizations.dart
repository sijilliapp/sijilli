import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en')
  ];

  /// اسم التطبيق
  ///
  /// In ar, this message translates to:
  /// **'سجلي'**
  String get appName;

  /// No description provided for @appSlogan.
  ///
  /// In ar, this message translates to:
  /// **'تنظيم المواعيد وإدارة الدعوات'**
  String get appSlogan;

  /// No description provided for @login.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول'**
  String get login;

  /// No description provided for @register.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء حساب'**
  String get register;

  /// No description provided for @settings.
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In ar, this message translates to:
  /// **'اللغة'**
  String get language;

  /// No description provided for @welcomeBack.
  ///
  /// In ar, this message translates to:
  /// **'مرحباً بعودتك!'**
  String get welcomeBack;

  /// No description provided for @loginToContinue.
  ///
  /// In ar, this message translates to:
  /// **'سجل دخولك للمتابعة إلى سجلي'**
  String get loginToContinue;

  /// No description provided for @emailOrUsername.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني أو اسم المستخدم'**
  String get emailOrUsername;

  /// No description provided for @enterPassword.
  ///
  /// In ar, this message translates to:
  /// **'أدخل كلمة المرور'**
  String get enterPassword;

  /// No description provided for @noAccount.
  ///
  /// In ar, this message translates to:
  /// **'ليس لديك حساب؟ '**
  String get noAccount;

  /// No description provided for @createNewAccount.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء حساب جديد'**
  String get createNewAccount;

  /// No description provided for @fullName.
  ///
  /// In ar, this message translates to:
  /// **'الاسم الظاهر'**
  String get fullName;

  /// No description provided for @email.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني'**
  String get email;

  /// No description provided for @username.
  ///
  /// In ar, this message translates to:
  /// **'اسم المستخدم'**
  String get username;

  /// No description provided for @password.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور'**
  String get password;

  /// No description provided for @confirmPassword.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد كلمة المرور'**
  String get confirmPassword;

  /// No description provided for @agreeToTerms.
  ///
  /// In ar, this message translates to:
  /// **'أوافق على الشروط والأحكام وسياسة الخصوصية'**
  String get agreeToTerms;

  /// No description provided for @iAgreeToThe.
  ///
  /// In ar, this message translates to:
  /// **'أوافق على '**
  String get iAgreeToThe;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In ar, this message translates to:
  /// **'لديك حساب بالفعل؟ '**
  String get alreadyHaveAccount;

  /// No description provided for @registerAction.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء الحساب'**
  String get registerAction;

  /// No description provided for @or.
  ///
  /// In ar, this message translates to:
  /// **'أو'**
  String get or;

  /// No description provided for @forgotPassword.
  ///
  /// In ar, this message translates to:
  /// **'نسيت كلمة المرور؟'**
  String get forgotPassword;

  /// No description provided for @fieldRequired.
  ///
  /// In ar, this message translates to:
  /// **'هذا الحقل مطلوب'**
  String get fieldRequired;

  /// No description provided for @invalidEmail.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني غير صحيح'**
  String get invalidEmail;

  /// No description provided for @invalidPhone.
  ///
  /// In ar, this message translates to:
  /// **'رقم الهاتف غير صحيح (8-12 رقماً)'**
  String get invalidPhone;

  /// No description provided for @passwordsNotMatch.
  ///
  /// In ar, this message translates to:
  /// **'كلمات المرور غير متطابقة'**
  String get passwordsNotMatch;

  /// No description provided for @passwordMinLength.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور يجب أن تكون 8 أحرف على الأقل'**
  String get passwordMinLength;

  /// No description provided for @usernameTaken.
  ///
  /// In ar, this message translates to:
  /// **'اسم المستخدم غير متوفر'**
  String get usernameTaken;

  /// No description provided for @emailTaken.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني مستخدم بالفعل'**
  String get emailTaken;

  /// No description provided for @invalidPassword.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور قصيرة جداً'**
  String get invalidPassword;

  /// No description provided for @dataError.
  ///
  /// In ar, this message translates to:
  /// **'خطأ في البيانات'**
  String get dataError;

  /// No description provided for @passwordStrengthVeryWeak.
  ///
  /// In ar, this message translates to:
  /// **'ضعيفة جداً'**
  String get passwordStrengthVeryWeak;

  /// No description provided for @passwordStrengthWeak.
  ///
  /// In ar, this message translates to:
  /// **'ضعيفة'**
  String get passwordStrengthWeak;

  /// No description provided for @passwordStrengthMedium.
  ///
  /// In ar, this message translates to:
  /// **'متوسطة'**
  String get passwordStrengthMedium;

  /// No description provided for @passwordStrengthStrong.
  ///
  /// In ar, this message translates to:
  /// **'قوية'**
  String get passwordStrengthStrong;

  /// No description provided for @passwordStrengthVeryStrong.
  ///
  /// In ar, this message translates to:
  /// **'قوية جداً'**
  String get passwordStrengthVeryStrong;

  /// No description provided for @passwordTipVeryWeak.
  ///
  /// In ar, this message translates to:
  /// **'نصيحة: أضف أحرف كبيرة وأرقام'**
  String get passwordTipVeryWeak;

  /// No description provided for @passwordTipWeak.
  ///
  /// In ar, this message translates to:
  /// **'نصيحة: أضف رموز خاصة لمزيد من الأمان'**
  String get passwordTipWeak;

  /// No description provided for @passwordTipMedium.
  ///
  /// In ar, this message translates to:
  /// **'جيد! يمكن تحسينها بإضافة رموز'**
  String get passwordTipMedium;

  /// No description provided for @passwordTipStrong.
  ///
  /// In ar, this message translates to:
  /// **'ممتاز! كلمة مرور آمنة'**
  String get passwordTipStrong;

  /// No description provided for @passwordTipVeryStrong.
  ///
  /// In ar, this message translates to:
  /// **'مثالي! أقصى درجات الأمان'**
  String get passwordTipVeryStrong;

  /// No description provided for @editProfile.
  ///
  /// In ar, this message translates to:
  /// **'تعديل البروفايل'**
  String get editProfile;

  /// No description provided for @editProfileSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'تحديث الصورة والمعلومات الشخصية'**
  String get editProfileSubtitle;

  /// No description provided for @appAppearance.
  ///
  /// In ar, this message translates to:
  /// **'مظهر التطبيق'**
  String get appAppearance;

  /// No description provided for @fontStyle.
  ///
  /// In ar, this message translates to:
  /// **'نوع الخط (Font Style)'**
  String get fontStyle;

  /// No description provided for @archive.
  ///
  /// In ar, this message translates to:
  /// **'الأرشيف'**
  String get archive;

  /// No description provided for @trash.
  ///
  /// In ar, this message translates to:
  /// **'المحذوفات'**
  String get trash;

  /// No description provided for @manageArchiveTrash.
  ///
  /// In ar, this message translates to:
  /// **'إدارة المواعيد المؤرشفة والمحذوفة'**
  String get manageArchiveTrash;

  /// No description provided for @notificationSettings.
  ///
  /// In ar, this message translates to:
  /// **'إعدادات الإشعارات'**
  String get notificationSettings;

  /// No description provided for @privacyAndSecurity.
  ///
  /// In ar, this message translates to:
  /// **'الخصوصية والأمان'**
  String get privacyAndSecurity;

  /// No description provided for @blockedUsers.
  ///
  /// In ar, this message translates to:
  /// **'قائمة الحظر'**
  String get blockedUsers;

  /// No description provided for @aboutApp.
  ///
  /// In ar, this message translates to:
  /// **'حول التطبيق'**
  String get aboutApp;

  /// No description provided for @termsAndConditions.
  ///
  /// In ar, this message translates to:
  /// **'الشروط والأحكام'**
  String get termsAndConditions;

  /// No description provided for @logout.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج'**
  String get logout;

  /// No description provided for @cancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get cancel;

  /// No description provided for @confirmLogout.
  ///
  /// In ar, this message translates to:
  /// **'هل أنت متأكد من تسجيل الخروج؟'**
  String get confirmLogout;

  /// No description provided for @appLanguage.
  ///
  /// In ar, this message translates to:
  /// **'لغة التطبيق'**
  String get appLanguage;

  /// No description provided for @selectLanguage.
  ///
  /// In ar, this message translates to:
  /// **'اختر اللغة'**
  String get selectLanguage;

  /// No description provided for @arabic.
  ///
  /// In ar, this message translates to:
  /// **'العربية'**
  String get arabic;

  /// No description provided for @english.
  ///
  /// In ar, this message translates to:
  /// **'الإنجليزية'**
  String get english;

  /// No description provided for @search.
  ///
  /// In ar, this message translates to:
  /// **'البحث'**
  String get search;

  /// No description provided for @add.
  ///
  /// In ar, this message translates to:
  /// **'إضافة'**
  String get add;

  /// No description provided for @notifications.
  ///
  /// In ar, this message translates to:
  /// **'الإشعارات'**
  String get notifications;

  /// No description provided for @home.
  ///
  /// In ar, this message translates to:
  /// **'الرئيسية'**
  String get home;

  /// No description provided for @myAppointments.
  ///
  /// In ar, this message translates to:
  /// **'مواعيدي'**
  String get myAppointments;

  /// No description provided for @upcomingAppointments.
  ///
  /// In ar, this message translates to:
  /// **'المواعيد القادمة'**
  String get upcomingAppointments;

  /// No description provided for @pastAppointments.
  ///
  /// In ar, this message translates to:
  /// **'المواعيد الفائتة'**
  String get pastAppointments;

  /// No description provided for @noAppointments.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد مواعيد'**
  String get noAppointments;

  /// No description provided for @createFirstAppointment.
  ///
  /// In ar, this message translates to:
  /// **'أنشئ موعدك الأول'**
  String get createFirstAppointment;

  /// No description provided for @inviteFriendsFirst.
  ///
  /// In ar, this message translates to:
  /// **'ادعُ أصدقاءك أولاً'**
  String get inviteFriendsFirst;

  /// No description provided for @tapToAdd.
  ///
  /// In ar, this message translates to:
  /// **'انقر لإضافة'**
  String get tapToAdd;

  /// No description provided for @swipeToDelete.
  ///
  /// In ar, this message translates to:
  /// **'اسحب للحذف'**
  String get swipeToDelete;

  /// No description provided for @pullToRefresh.
  ///
  /// In ar, this message translates to:
  /// **'اسحب للتحديث'**
  String get pullToRefresh;

  /// No description provided for @tapForDetails.
  ///
  /// In ar, this message translates to:
  /// **'انقر للتفاصيل'**
  String get tapForDetails;

  /// No description provided for @region.
  ///
  /// In ar, this message translates to:
  /// **'المنطقة'**
  String get region;

  /// No description provided for @building.
  ///
  /// In ar, this message translates to:
  /// **'المبنى'**
  String get building;

  /// No description provided for @now.
  ///
  /// In ar, this message translates to:
  /// **'الآن'**
  String get now;

  /// No description provided for @today.
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get today;

  /// No description provided for @tomorrow.
  ///
  /// In ar, this message translates to:
  /// **'غداً'**
  String get tomorrow;

  /// No description provided for @yesterday.
  ///
  /// In ar, this message translates to:
  /// **'أمس'**
  String get yesterday;

  /// No description provided for @save.
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In ar, this message translates to:
  /// **'تعديل'**
  String get edit;

  /// No description provided for @confirm.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد'**
  String get confirm;

  /// No description provided for @retry.
  ///
  /// In ar, this message translates to:
  /// **'إعادة المحاولة'**
  String get retry;

  /// No description provided for @loading.
  ///
  /// In ar, this message translates to:
  /// **'جاري التحميل...'**
  String get loading;

  /// No description provided for @noData.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد بيانات'**
  String get noData;

  /// No description provided for @profile.
  ///
  /// In ar, this message translates to:
  /// **'الملف الشخصي'**
  String get profile;

  /// No description provided for @followers.
  ///
  /// In ar, this message translates to:
  /// **'المعتمدون'**
  String get followers;

  /// No description provided for @following.
  ///
  /// In ar, this message translates to:
  /// **'جهات اعتمدتُها'**
  String get following;

  /// No description provided for @articles.
  ///
  /// In ar, this message translates to:
  /// **'المقالات'**
  String get articles;

  /// No description provided for @contactTeam.
  ///
  /// In ar, this message translates to:
  /// **'مراسلة فريق \"سجلي\"'**
  String get contactTeam;

  /// No description provided for @noArticlesYet.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد مقالات بعد'**
  String get noArticlesYet;

  /// No description provided for @location.
  ///
  /// In ar, this message translates to:
  /// **'الموقع'**
  String get location;

  /// No description provided for @time.
  ///
  /// In ar, this message translates to:
  /// **'الوقت'**
  String get time;

  /// No description provided for @close.
  ///
  /// In ar, this message translates to:
  /// **'إغلاق'**
  String get close;

  /// No description provided for @errorOccurred.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ'**
  String get errorOccurred;

  /// No description provided for @welcomeToSijilli.
  ///
  /// In ar, this message translates to:
  /// **'أهلاً بك في سجلّي!'**
  String get welcomeToSijilli;

  /// No description provided for @emptyAppointmentsDesc.
  ///
  /// In ar, this message translates to:
  /// **'سجلك فارغ حالياً..\nابدأ بإضافة مواعيدك ومناسباتك المهمة'**
  String get emptyAppointmentsDesc;

  /// No description provided for @reportAppointment.
  ///
  /// In ar, this message translates to:
  /// **'تبليغ عن موعد'**
  String get reportAppointment;

  /// No description provided for @reportReason.
  ///
  /// In ar, this message translates to:
  /// **'سبب التبليغ...'**
  String get reportReason;

  /// No description provided for @send.
  ///
  /// In ar, this message translates to:
  /// **'إرسال'**
  String get send;

  /// No description provided for @reportSent.
  ///
  /// In ar, this message translates to:
  /// **'تم إرسال التبليغ'**
  String get reportSent;

  /// No description provided for @report.
  ///
  /// In ar, this message translates to:
  /// **'تبليغ'**
  String get report;

  /// No description provided for @reportAndBlock.
  ///
  /// In ar, this message translates to:
  /// **'تبليغ وحظر'**
  String get reportAndBlock;

  /// No description provided for @guest.
  ///
  /// In ar, this message translates to:
  /// **'ضيف'**
  String get guest;

  /// No description provided for @linkCopied.
  ///
  /// In ar, this message translates to:
  /// **'تم نسخ الرابط'**
  String get linkCopied;

  /// No description provided for @accreditations.
  ///
  /// In ar, this message translates to:
  /// **'الاعتمادات'**
  String get accreditations;

  /// No description provided for @recentSearches.
  ///
  /// In ar, this message translates to:
  /// **'البحوث الأخيرة'**
  String get recentSearches;

  /// No description provided for @searchUsers.
  ///
  /// In ar, this message translates to:
  /// **'البحث عن حسابات...'**
  String get searchUsers;

  /// No description provided for @explore.
  ///
  /// In ar, this message translates to:
  /// **'استكشف'**
  String get explore;

  /// No description provided for @news.
  ///
  /// In ar, this message translates to:
  /// **'الأخبار'**
  String get news;

  /// No description provided for @follows.
  ///
  /// In ar, this message translates to:
  /// **'المتابعات'**
  String get follows;

  /// No description provided for @searchHint.
  ///
  /// In ar, this message translates to:
  /// **'ابحث عن حسابات أو مواعيد...'**
  String get searchHint;

  /// No description provided for @noResults.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد نتائج'**
  String get noResults;

  /// No description provided for @noAppointmentsCurrently.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد مواعيد حالياً'**
  String get noAppointmentsCurrently;

  /// No description provided for @showAll.
  ///
  /// In ar, this message translates to:
  /// **'إظهار الكل'**
  String get showAll;

  /// No description provided for @hideAnswered.
  ///
  /// In ar, this message translates to:
  /// **'إخفاء الذي تم الرد عليه والفائت'**
  String get hideAnswered;

  /// No description provided for @noNotificationsCurrently.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد إشعارات حالياً'**
  String get noNotificationsCurrently;

  /// No description provided for @newInvitesDesc.
  ///
  /// In ar, this message translates to:
  /// **'ستظهر لك الدعوات الجديدة هنا فور وصولها'**
  String get newInvitesDesc;

  /// No description provided for @conflictWarning.
  ///
  /// In ar, this message translates to:
  /// **'تنبيه تعارض'**
  String get conflictWarning;

  /// No description provided for @conflictDesc.
  ///
  /// In ar, this message translates to:
  /// **'هذا الموعد يتعارض مع {count} مواعيد أخرى في جدولك.\nهل أنت متأكد من قبول الدعوة؟'**
  String conflictDesc(int count);

  /// No description provided for @acceptAndContinue.
  ///
  /// In ar, this message translates to:
  /// **'قبول ومتابعة'**
  String get acceptAndContinue;

  /// No description provided for @inviteAccepted.
  ///
  /// In ar, this message translates to:
  /// **'تم قبول الدعوة بنجاح'**
  String get inviteAccepted;

  /// No description provided for @inviteRejected.
  ///
  /// In ar, this message translates to:
  /// **'تم رفض الدعوة'**
  String get inviteRejected;

  /// No description provided for @failedToUpdateStatus.
  ///
  /// In ar, this message translates to:
  /// **'فشل تحديث الحالة: {error}'**
  String failedToUpdateStatus(String error);

  /// No description provided for @user.
  ///
  /// In ar, this message translates to:
  /// **'مستخدم'**
  String get user;

  /// No description provided for @invitesYouTo.
  ///
  /// In ar, this message translates to:
  /// **'يدعوك لـ '**
  String get invitesYouTo;

  /// No description provided for @days.
  ///
  /// In ar, this message translates to:
  /// **'أيام'**
  String get days;

  /// No description provided for @accepted.
  ///
  /// In ar, this message translates to:
  /// **'تمت الموافقة'**
  String get accepted;

  /// No description provided for @declined.
  ///
  /// In ar, this message translates to:
  /// **'تم الرفض'**
  String get declined;

  /// No description provided for @appointmentCancelled.
  ///
  /// In ar, this message translates to:
  /// **'تم إلغاء الموعد'**
  String get appointmentCancelled;

  /// No description provided for @pastStatus.
  ///
  /// In ar, this message translates to:
  /// **'فائت'**
  String get pastStatus;

  /// No description provided for @accreditEntity.
  ///
  /// In ar, this message translates to:
  /// **'اعتماد جهة'**
  String get accreditEntity;

  /// No description provided for @accreditDesc.
  ///
  /// In ar, this message translates to:
  /// **'أنت على وشك قبول اعتماد هذه الجهة، ومعنى ذلك: تبادل الصلاحية في الاطلاع على المواعيد المتاحة لدائرة المعتمدين.'**
  String get accreditDesc;

  /// No description provided for @withdrawRequest.
  ///
  /// In ar, this message translates to:
  /// **'التراجع عن الطلب'**
  String get withdrawRequest;

  /// No description provided for @withdrawDesc.
  ///
  /// In ar, this message translates to:
  /// **'هل حقا تود التراجع عن طلب الاعتماد؟'**
  String get withdrawDesc;

  /// No description provided for @keepRequest.
  ///
  /// In ar, this message translates to:
  /// **'الإبقاء على الطلب'**
  String get keepRequest;

  /// No description provided for @yes.
  ///
  /// In ar, this message translates to:
  /// **'نعم'**
  String get yes;

  /// No description provided for @errorProcessingRequest.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ أثناء معالجة الطلب'**
  String get errorProcessingRequest;

  /// No description provided for @waitingYourAccreditation.
  ///
  /// In ar, this message translates to:
  /// **'طلبات بانتظار اعتمادك'**
  String get waitingYourAccreditation;

  /// No description provided for @waitingTheirAccreditation.
  ///
  /// In ar, this message translates to:
  /// **'بانتظار اعتمادهم'**
  String get waitingTheirAccreditation;

  /// No description provided for @accreditedEntities.
  ///
  /// In ar, this message translates to:
  /// **'جهات معتمدة'**
  String get accreditedEntities;

  /// No description provided for @noContactsYet.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد جهات اتصال بعد'**
  String get noContactsYet;

  /// No description provided for @inviteFromContacts.
  ///
  /// In ar, this message translates to:
  /// **'دعوة من جهات الاتصال'**
  String get inviteFromContacts;

  /// No description provided for @accreditAction.
  ///
  /// In ar, this message translates to:
  /// **'اعتماد..'**
  String get accreditAction;

  /// No description provided for @waitingAction.
  ///
  /// In ar, this message translates to:
  /// **'انتظار..'**
  String get waitingAction;

  /// No description provided for @verifyUsernameOrNetwork.
  ///
  /// In ar, this message translates to:
  /// **'تأكد من صحة اسم المستخدم أو الاتصال بالشبكة'**
  String get verifyUsernameOrNetwork;

  /// No description provided for @blockUser.
  ///
  /// In ar, this message translates to:
  /// **'حظر المستخدم'**
  String get blockUser;

  /// No description provided for @blockConfirmDesc.
  ///
  /// In ar, this message translates to:
  /// **'هل أنت متأكد من حظر هذا المستخدم؟ لن تظهر مواعيده لك ولن يتمكن من التواصل معك.'**
  String get blockConfirmDesc;

  /// No description provided for @unblock.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الحظر'**
  String get unblock;

  /// No description provided for @reportAccount.
  ///
  /// In ar, this message translates to:
  /// **'تبليغ عن حساب'**
  String get reportAccount;

  /// No description provided for @reportThanks.
  ///
  /// In ar, this message translates to:
  /// **'تم إرسال التبليغ، شكراً لمساهمتك'**
  String get reportThanks;

  /// No description provided for @pleaseSelectDate.
  ///
  /// In ar, this message translates to:
  /// **'يرجى اختيار التاريخ'**
  String get pleaseSelectDate;

  /// No description provided for @pleaseSelectTime.
  ///
  /// In ar, this message translates to:
  /// **'يرجى اختيار الوقت'**
  String get pleaseSelectTime;

  /// No description provided for @userAlreadyAdded.
  ///
  /// In ar, this message translates to:
  /// **'المستخدم مضاف مسبقاً'**
  String get userAlreadyAdded;

  /// No description provided for @recurrenceDaily.
  ///
  /// In ar, this message translates to:
  /// **'يومياً'**
  String get recurrenceDaily;

  /// No description provided for @recurrenceWeekly.
  ///
  /// In ar, this message translates to:
  /// **'أسبوعياً'**
  String get recurrenceWeekly;

  /// No description provided for @recurrenceMonthly.
  ///
  /// In ar, this message translates to:
  /// **'شهرياً'**
  String get recurrenceMonthly;

  /// No description provided for @recurrenceAnnual.
  ///
  /// In ar, this message translates to:
  /// **'سنوياً'**
  String get recurrenceAnnual;

  /// No description provided for @you.
  ///
  /// In ar, this message translates to:
  /// **'أنت'**
  String get you;

  /// No description provided for @subject.
  ///
  /// In ar, this message translates to:
  /// **'الموضوع'**
  String get subject;

  /// No description provided for @subjectHint.
  ///
  /// In ar, this message translates to:
  /// **'اكتب موضوع الموعد...'**
  String get subjectHint;

  /// No description provided for @regionHint.
  ///
  /// In ar, this message translates to:
  /// **'اختر المنطقة...'**
  String get regionHint;

  /// No description provided for @buildingHint.
  ///
  /// In ar, this message translates to:
  /// **'الاسم/الرقم'**
  String get buildingHint;

  /// No description provided for @streamLink.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل الموعد أو رابط الإعلان أو البث'**
  String get streamLink;

  /// No description provided for @streamLinkHint.
  ///
  /// In ar, this message translates to:
  /// **'اكتب التفاصيل أو ضع الرابط هنا...'**
  String get streamLinkHint;

  /// No description provided for @appointmentPrivacy.
  ///
  /// In ar, this message translates to:
  /// **'خصوصية الموعد'**
  String get appointmentPrivacy;

  /// No description provided for @privacyPublic.
  ///
  /// In ar, this message translates to:
  /// **'عام'**
  String get privacyPublic;

  /// No description provided for @privacyFollowers.
  ///
  /// In ar, this message translates to:
  /// **'معتمَدون'**
  String get privacyFollowers;

  /// No description provided for @privacyPrivate.
  ///
  /// In ar, this message translates to:
  /// **'خاص'**
  String get privacyPrivate;

  /// No description provided for @duration15m.
  ///
  /// In ar, this message translates to:
  /// **'15 دقيقة'**
  String get duration15m;

  /// No description provided for @duration30m.
  ///
  /// In ar, this message translates to:
  /// **'30 دقيقة'**
  String get duration30m;

  /// No description provided for @duration45m.
  ///
  /// In ar, this message translates to:
  /// **'45 دقيقة'**
  String get duration45m;

  /// No description provided for @duration1h.
  ///
  /// In ar, this message translates to:
  /// **'ساعة'**
  String get duration1h;

  /// No description provided for @duration2h.
  ///
  /// In ar, this message translates to:
  /// **'ساعتان'**
  String get duration2h;

  /// No description provided for @duration3h.
  ///
  /// In ar, this message translates to:
  /// **'3 ساعات'**
  String get duration3h;

  /// No description provided for @duration6h.
  ///
  /// In ar, this message translates to:
  /// **'6 ساعات'**
  String get duration6h;

  /// No description provided for @duration12h.
  ///
  /// In ar, this message translates to:
  /// **'12 ساعة'**
  String get duration12h;

  /// No description provided for @durationAllDay.
  ///
  /// In ar, this message translates to:
  /// **'اليوم كله'**
  String get durationAllDay;

  /// No description provided for @sunriseTime.
  ///
  /// In ar, this message translates to:
  /// **'شروقًا'**
  String get sunriseTime;

  /// No description provided for @dhuhrTime.
  ///
  /// In ar, this message translates to:
  /// **'ظهرًا'**
  String get dhuhrTime;

  /// No description provided for @sunsetTime.
  ///
  /// In ar, this message translates to:
  /// **'غروبًا'**
  String get sunsetTime;

  /// No description provided for @createAppointment.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء موعد'**
  String get createAppointment;

  /// No description provided for @editAppointment.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الموعد'**
  String get editAppointment;

  /// No description provided for @clear.
  ///
  /// In ar, this message translates to:
  /// **'مسح'**
  String get clear;

  /// No description provided for @appointmentCreated.
  ///
  /// In ar, this message translates to:
  /// **'تم إنشاء الموعد بنجاح'**
  String get appointmentCreated;

  /// No description provided for @appointmentUpdated.
  ///
  /// In ar, this message translates to:
  /// **'تم تحديث الموعد بنجاح'**
  String get appointmentUpdated;

  /// No description provided for @addAnother.
  ///
  /// In ar, this message translates to:
  /// **'إضافة آخر'**
  String get addAnother;

  /// No description provided for @clearFormTitle.
  ///
  /// In ar, this message translates to:
  /// **'مسح النموذج'**
  String get clearFormTitle;

  /// No description provided for @clearFormConfirmation.
  ///
  /// In ar, this message translates to:
  /// **'هل أنت متأكد من مسح جميع البيانات؟'**
  String get clearFormConfirmation;

  /// No description provided for @formClearedSuccessfully.
  ///
  /// In ar, this message translates to:
  /// **'تم مسح النموذج'**
  String get formClearedSuccessfully;

  /// No description provided for @selectTime.
  ///
  /// In ar, this message translates to:
  /// **'اختر الوقت'**
  String get selectTime;

  /// No description provided for @durationLabel.
  ///
  /// In ar, this message translates to:
  /// **'المدة'**
  String get durationLabel;

  /// No description provided for @hijri.
  ///
  /// In ar, this message translates to:
  /// **'هجري'**
  String get hijri;

  /// No description provided for @gregorian.
  ///
  /// In ar, this message translates to:
  /// **'ميلادي'**
  String get gregorian;

  /// No description provided for @endsAt.
  ///
  /// In ar, this message translates to:
  /// **'ينتهي في'**
  String get endsAt;

  /// No description provided for @endTime.
  ///
  /// In ar, this message translates to:
  /// **'وقت الانتهاء'**
  String get endTime;

  /// No description provided for @eventRecurrence.
  ///
  /// In ar, this message translates to:
  /// **'تكرار الموعد'**
  String get eventRecurrence;

  /// No description provided for @recurrenceType.
  ///
  /// In ar, this message translates to:
  /// **'نوع التكرار'**
  String get recurrenceType;

  /// No description provided for @recurrenceCount.
  ///
  /// In ar, this message translates to:
  /// **'عدد مرات التكرار'**
  String get recurrenceCount;

  /// No description provided for @selectHijriDate.
  ///
  /// In ar, this message translates to:
  /// **'اختر التاريخ الهجري'**
  String get selectHijriDate;

  /// No description provided for @inviteesLabel.
  ///
  /// In ar, this message translates to:
  /// **'المدعوين'**
  String get inviteesLabel;

  /// No description provided for @priorityFeature.
  ///
  /// In ar, this message translates to:
  /// **'خاصية الأسبقية'**
  String get priorityFeature;

  /// No description provided for @priorityFeatureDesc.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء باقي الضيوف فور موافقة الأسبق'**
  String get priorityFeatureDesc;

  /// No description provided for @maxInviteesWarning.
  ///
  /// In ar, this message translates to:
  /// **'الحد الأقصى للمدعوين هو 5 أشخاص'**
  String get maxInviteesWarning;

  /// No description provided for @addInviteesHint.
  ///
  /// In ar, this message translates to:
  /// **'إضافة مدعوين...'**
  String get addInviteesHint;

  /// No description provided for @selectGregorianDate.
  ///
  /// In ar, this message translates to:
  /// **'اختر التاريخ الميلادي'**
  String get selectGregorianDate;

  /// No description provided for @date.
  ///
  /// In ar, this message translates to:
  /// **'التاريخ'**
  String get date;

  /// No description provided for @someone.
  ///
  /// In ar, this message translates to:
  /// **'أحد المدعوين'**
  String get someone;

  /// No description provided for @appointmentBookedBy.
  ///
  /// In ar, this message translates to:
  /// **'تم حجز الموعد من قبل {name}'**
  String appointmentBookedBy(Object name);

  /// No description provided for @fcfsAutoDecline.
  ///
  /// In ar, this message translates to:
  /// **'تم إلغاء الدعوة تلقائياً بسبب اكتمال الموعد (الأسبقية للأسرع)'**
  String get fcfsAutoDecline;

  /// No description provided for @inviteAcceptedTitle.
  ///
  /// In ar, this message translates to:
  /// **'تم قبول الدعوة'**
  String get inviteAcceptedTitle;

  /// No description provided for @inviteAcceptedMsg.
  ///
  /// In ar, this message translates to:
  /// **'وافق {name} على الانضمام لموعد: {title}'**
  String inviteAcceptedMsg(Object name, Object title);

  /// No description provided for @newInviteTitle.
  ///
  /// In ar, this message translates to:
  /// **'دعوة جديدة'**
  String get newInviteTitle;

  /// No description provided for @newInvitation.
  ///
  /// In ar, this message translates to:
  /// **'دعوة جديدة'**
  String get newInvitation;

  /// No description provided for @newInviteMsg.
  ///
  /// In ar, this message translates to:
  /// **'قام {name} بدعوتك لموعد'**
  String newInviteMsg(Object name);

  /// No description provided for @invitedYouTo.
  ///
  /// In ar, this message translates to:
  /// **'قام {name} بدعوتك لموعد: {title}'**
  String invitedYouTo(String name, String title);

  /// No description provided for @joinRequestTitle.
  ///
  /// In ar, this message translates to:
  /// **'طلب انضمام'**
  String get joinRequestTitle;

  /// No description provided for @joinRequestMsg.
  ///
  /// In ar, this message translates to:
  /// **'يرغب {name} بالانضمام لموعدك: {title}'**
  String joinRequestMsg(Object name, Object title);

  /// No description provided for @invalidCredentials.
  ///
  /// In ar, this message translates to:
  /// **'بيانات الدخول غير صحيحة، يرجى التأكد من البريد الإلكتروني أو اسم المستخدم، وكلمة المرور.'**
  String get invalidCredentials;

  /// No description provided for @accountDisabled.
  ///
  /// In ar, this message translates to:
  /// **'عذراً، هذا الحساب معطل حالياً. يرجى التواصل مع الإدارة.'**
  String get accountDisabled;

  /// No description provided for @emailNotVerified.
  ///
  /// In ar, this message translates to:
  /// **'يرجى تأكيد بريدك الإلكتروني أولاً لتتمكن من تسجيل الدخول.'**
  String get emailNotVerified;

  /// No description provided for @tooManyRequests.
  ///
  /// In ar, this message translates to:
  /// **'محاولات كثيرة خاطئة! يرجى الانتظار قليلاً قبل المحاولة مجدداً.'**
  String get tooManyRequests;

  /// No description provided for @authConnectionError.
  ///
  /// In ar, this message translates to:
  /// **'تعذر الاتصال بخادم المصادقة، يرجى التحقق من جودة الإنترنت.'**
  String get authConnectionError;

  /// No description provided for @unknownError.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ غير معروف، يرجى المحاولة لاحقاً.'**
  String get unknownError;

  /// No description provided for @themeModeDark.
  ///
  /// In ar, this message translates to:
  /// **'داكن'**
  String get themeModeDark;

  /// No description provided for @themeModeLight.
  ///
  /// In ar, this message translates to:
  /// **'فاتح'**
  String get themeModeLight;

  /// No description provided for @themeModeSystem.
  ///
  /// In ar, this message translates to:
  /// **'تلقائي'**
  String get themeModeSystem;

  /// No description provided for @defaultFontStyle.
  ///
  /// In ar, this message translates to:
  /// **'الافتراضي'**
  String get defaultFontStyle;

  /// No description provided for @daysLeft.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, one{يوم واحد متبقي} two{يومان متبقيان} few{{count} أيام متبقية} many{{count} يوماً متبقياً} other{{count} يوم متبقي}}'**
  String daysLeft(int count);

  /// No description provided for @hostAFriend.
  ///
  /// In ar, this message translates to:
  /// **'ادعُ صديقاً'**
  String get hostAFriend;

  /// No description provided for @hostAndConnect.
  ///
  /// In ar, this message translates to:
  /// **'استضافة وتواصل'**
  String get hostAndConnect;

  /// No description provided for @searchUserHint.
  ///
  /// In ar, this message translates to:
  /// **'البحث بالاسم أو اسم المستخدم...'**
  String get searchUserHint;

  /// No description provided for @invitationSentSuccessfully.
  ///
  /// In ar, this message translates to:
  /// **'تم إرسال الدعوة بنجاح'**
  String get invitationSentSuccessfully;

  /// No description provided for @noResultsFound.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد نتائج'**
  String get noResultsFound;

  /// No description provided for @morning.
  ///
  /// In ar, this message translates to:
  /// **'صباحًا'**
  String get morning;

  /// No description provided for @noon.
  ///
  /// In ar, this message translates to:
  /// **'ظهرًا'**
  String get noon;

  /// No description provided for @afternoon.
  ///
  /// In ar, this message translates to:
  /// **'عصرًا'**
  String get afternoon;

  /// No description provided for @evening.
  ///
  /// In ar, this message translates to:
  /// **'مساءً'**
  String get evening;

  /// No description provided for @night.
  ///
  /// In ar, this message translates to:
  /// **'ليلاً'**
  String get night;

  /// No description provided for @afterTomorrow.
  ///
  /// In ar, this message translates to:
  /// **'بعد غد'**
  String get afterTomorrow;

  /// No description provided for @afterDays.
  ///
  /// In ar, this message translates to:
  /// **'{count} أيام متبقية'**
  String afterDays(int count);

  /// No description provided for @sinceDays.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, one{منذ يوم} two{منذ يومين} few{منذ {count} أيام} many{منذ {count} يوماً} other{منذ {count} يوم}}'**
  String sinceDays(int count);

  /// No description provided for @aboutToCreate.
  ///
  /// In ar, this message translates to:
  /// **'أنت على وشك إنشاء موعد جديد'**
  String get aboutToCreate;

  /// No description provided for @aboutToCreateWith.
  ///
  /// In ar, this message translates to:
  /// **'أنت على وشك إضافة موعد مع:'**
  String get aboutToCreateWith;

  /// No description provided for @participantsCount.
  ///
  /// In ar, this message translates to:
  /// **'مع {count} من المعتمدين'**
  String participantsCount(int count);

  /// No description provided for @conflictAlert.
  ///
  /// In ar, this message translates to:
  /// **'تنبيه تعارض!'**
  String get conflictAlert;

  /// No description provided for @conflictMessage.
  ///
  /// In ar, this message translates to:
  /// **'هذا الموعد قد يتعارض مع مواعيد أخرى لديك.'**
  String get conflictMessage;

  /// No description provided for @review.
  ///
  /// In ar, this message translates to:
  /// **'مراجعة'**
  String get review;

  /// No description provided for @pleaseLoginFirst.
  ///
  /// In ar, this message translates to:
  /// **'يرجى تسجيل الدخول أولاً'**
  String get pleaseLoginFirst;

  /// No description provided for @recurrenceOf.
  ///
  /// In ar, this message translates to:
  /// **'من'**
  String get recurrenceOf;

  /// No description provided for @watchLive.
  ///
  /// In ar, this message translates to:
  /// **'مشاهدة البث المباشر'**
  String get watchLive;

  /// No description provided for @saveImage.
  ///
  /// In ar, this message translates to:
  /// **'حفظ الصورة'**
  String get saveImage;

  /// No description provided for @savingImage.
  ///
  /// In ar, this message translates to:
  /// **'جاري حفظ الصورة...'**
  String get savingImage;

  /// No description provided for @imageSaved.
  ///
  /// In ar, this message translates to:
  /// **'تم حفظ الصورة في الألبوم'**
  String get imageSaved;

  /// No description provided for @imageSaveFailed.
  ///
  /// In ar, this message translates to:
  /// **'فشل حفظ الصورة'**
  String get imageSaveFailed;

  /// No description provided for @noContactMethods.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد وسائل تواصل'**
  String get noContactMethods;

  /// No description provided for @contactMethods.
  ///
  /// In ar, this message translates to:
  /// **'وسائل التواصل'**
  String get contactMethods;

  /// No description provided for @directCall.
  ///
  /// In ar, this message translates to:
  /// **'اتصال مباشر'**
  String get directCall;

  /// No description provided for @visitLink.
  ///
  /// In ar, this message translates to:
  /// **'زيارة الرابط'**
  String get visitLink;

  /// No description provided for @appointments.
  ///
  /// In ar, this message translates to:
  /// **'المواعيد'**
  String get appointments;

  /// No description provided for @inYear.
  ///
  /// In ar, this message translates to:
  /// **'بعد سنة'**
  String get inYear;

  /// No description provided for @inMonths.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, one{بعد شهر} two{بعد شهرين} few{بعد {count} أشهر} many{بعد {count} شهراً} other{بعد {count} شهر}}'**
  String inMonths(num count);

  /// No description provided for @inDays.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, one{بعد يوم} two{بعد يومين} few{بعد {count} أيام} many{بعد {count} يوماً} other{بعد {count} يوم}}'**
  String inDays(num count);

  /// No description provided for @withinHours.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, one{خلال ساعة} two{خلال ساعتين} few{خلال {count} ساعات} many{خلال {count} ساعة} other{خلال {count} ساعة}}'**
  String withinHours(num count);

  /// No description provided for @withinMinutes.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, one{خلال دقيقة} two{خلال دقيقتين} few{خلال {count} دقائق} many{خلال {count} دقيقة} other{خلال {count} دقيقة}}'**
  String withinMinutes(num count);

  /// No description provided for @momentsLeft.
  ///
  /// In ar, this message translates to:
  /// **'خلال لحظات'**
  String get momentsLeft;

  /// No description provided for @statusPast.
  ///
  /// In ar, this message translates to:
  /// **'فائت'**
  String get statusPast;

  /// No description provided for @statusDeleted.
  ///
  /// In ar, this message translates to:
  /// **'محذوف'**
  String get statusDeleted;

  /// No description provided for @statusArchived.
  ///
  /// In ar, this message translates to:
  /// **'مؤرشف'**
  String get statusArchived;

  /// No description provided for @statusActiveNow.
  ///
  /// In ar, this message translates to:
  /// **'جاري الآن'**
  String get statusActiveNow;

  /// No description provided for @statusUpcoming.
  ///
  /// In ar, this message translates to:
  /// **'قريباً'**
  String get statusUpcoming;

  /// No description provided for @statusFuture.
  ///
  /// In ar, this message translates to:
  /// **'مستقبلي'**
  String get statusFuture;

  /// No description provided for @hostNameDefault.
  ///
  /// In ar, this message translates to:
  /// **'اسم المنشئ'**
  String get hostNameDefault;

  /// No description provided for @accreditEntityAction.
  ///
  /// In ar, this message translates to:
  /// **'اعتماد'**
  String get accreditEntityAction;

  /// No description provided for @hostAction.
  ///
  /// In ar, this message translates to:
  /// **'استضافة'**
  String get hostAction;

  /// No description provided for @statusUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'غير متاح'**
  String get statusUnavailable;

  /// No description provided for @noPublicAppointments.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد مواعيد عامة'**
  String get noPublicAppointments;

  /// No description provided for @noPublicAppointmentsDesc.
  ///
  /// In ar, this message translates to:
  /// **'هذا المستخدم لم يقم بنشر أي مواعيد عامة بعد.'**
  String get noPublicAppointmentsDesc;

  /// No description provided for @detailsMinutes.
  ///
  /// In ar, this message translates to:
  /// **'دقيقة'**
  String get detailsMinutes;

  /// No description provided for @detailsHostGuests.
  ///
  /// In ar, this message translates to:
  /// **'استضافة ضيوف..'**
  String get detailsHostGuests;

  /// No description provided for @detailsAppointmentCancelled.
  ///
  /// In ar, this message translates to:
  /// **'الموعد ملغي'**
  String get detailsAppointmentCancelled;

  /// No description provided for @detailsDeleteTitleHost.
  ///
  /// In ar, this message translates to:
  /// **'حذف نهائي'**
  String get detailsDeleteTitleHost;

  /// No description provided for @detailsDeleteTitleGuest.
  ///
  /// In ar, this message translates to:
  /// **'حذف الموعد'**
  String get detailsDeleteTitleGuest;

  /// No description provided for @detailsDeleteConfirmHost.
  ///
  /// In ar, this message translates to:
  /// **'تنبيه: بصفتك المضيف، حذف الموعد سيؤدي إلى إلغائه لجميع المدعوين ونقله إلى سلة المحذوفات للجميع.\n\nهل أنت متأكد؟'**
  String get detailsDeleteConfirmHost;

  /// No description provided for @detailsDeleteConfirmGuest.
  ///
  /// In ar, this message translates to:
  /// **'هل أنت متأكد من حذف نسختك الشخصية من هذا الموعد؟'**
  String get detailsDeleteConfirmGuest;

  /// No description provided for @detailsUndo.
  ///
  /// In ar, this message translates to:
  /// **'تراجع'**
  String get detailsUndo;

  /// No description provided for @detailsCancelAppointment.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الموعد'**
  String get detailsCancelAppointment;

  /// No description provided for @detailsNewCategory.
  ///
  /// In ar, this message translates to:
  /// **'تصنيف جديد'**
  String get detailsNewCategory;

  /// No description provided for @detailsCategoryHint.
  ///
  /// In ar, this message translates to:
  /// **'مثلاً: أنف، حنجرة، مراجعة...'**
  String get detailsCategoryHint;

  /// No description provided for @detailsGeneralNote.
  ///
  /// In ar, this message translates to:
  /// **'الملاحظة العامة'**
  String get detailsGeneralNote;

  /// No description provided for @detailsPersonalNote.
  ///
  /// In ar, this message translates to:
  /// **'الملاحظة الخاصة'**
  String get detailsPersonalNote;

  /// No description provided for @detailsLink.
  ///
  /// In ar, this message translates to:
  /// **'الرابط'**
  String get detailsLink;

  /// No description provided for @detailsEnterHere.
  ///
  /// In ar, this message translates to:
  /// **'أدخل {label} هنا...'**
  String detailsEnterHere(Object label);

  /// No description provided for @detailsUpdateFailed.
  ///
  /// In ar, this message translates to:
  /// **'فشل التحديث: {error}'**
  String detailsUpdateFailed(Object error);

  /// No description provided for @detailsInviteSent.
  ///
  /// In ar, this message translates to:
  /// **'تم إرسال الدعوة لـ {name}'**
  String detailsInviteSent(Object name);

  /// No description provided for @detailsInviteFailed.
  ///
  /// In ar, this message translates to:
  /// **'فشل إرسال الدعوة: {error}'**
  String detailsInviteFailed(Object error);

  /// No description provided for @privacyProfileTitle.
  ///
  /// In ar, this message translates to:
  /// **'الخصوصية في ملفك الشخصي'**
  String get privacyProfileTitle;

  /// No description provided for @privacyPrivateLabel.
  ///
  /// In ar, this message translates to:
  /// **'خاص (أنا فقط)'**
  String get privacyPrivateLabel;

  /// No description provided for @privacyFollowersLabel.
  ///
  /// In ar, this message translates to:
  /// **'للمعتمدين'**
  String get privacyFollowersLabel;

  /// No description provided for @privacyPublicLabel.
  ///
  /// In ar, this message translates to:
  /// **'عام للجميع'**
  String get privacyPublicLabel;

  /// No description provided for @detailsFrom.
  ///
  /// In ar, this message translates to:
  /// **'من:'**
  String get detailsFrom;

  /// No description provided for @detailsTo.
  ///
  /// In ar, this message translates to:
  /// **'إلى:'**
  String get detailsTo;

  /// No description provided for @detailsSunset.
  ///
  /// In ar, this message translates to:
  /// **'الغروب:'**
  String get detailsSunset;

  /// No description provided for @detailsDuration.
  ///
  /// In ar, this message translates to:
  /// **'المدة:'**
  String get detailsDuration;

  /// No description provided for @detailsGeneralNoteLabel.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظة عامة:'**
  String get detailsGeneralNoteLabel;

  /// No description provided for @detailsGeneralNoteAdd.
  ///
  /// In ar, this message translates to:
  /// **'إضافة ملاحظة عامة...'**
  String get detailsGeneralNoteAdd;

  /// No description provided for @detailsGeneralNoteNone.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد ملاحظات'**
  String get detailsGeneralNoteNone;

  /// No description provided for @detailsPersonalNoteLabel.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظة خاصة:'**
  String get detailsPersonalNoteLabel;

  /// No description provided for @detailsPersonalNoteAdd.
  ///
  /// In ar, this message translates to:
  /// **'إضافة ملاحظة خاصة...'**
  String get detailsPersonalNoteAdd;

  /// No description provided for @detailsLinkLabel.
  ///
  /// In ar, this message translates to:
  /// **'رابط:'**
  String get detailsLinkLabel;

  /// No description provided for @detailsLinkAdd.
  ///
  /// In ar, this message translates to:
  /// **'إضافة رابط...'**
  String get detailsLinkAdd;

  /// No description provided for @detailsLinkNone.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد رابط'**
  String get detailsLinkNone;

  /// No description provided for @detailsParticipantsLabel.
  ///
  /// In ar, this message translates to:
  /// **'المشاركون:'**
  String get detailsParticipantsLabel;

  /// No description provided for @detailsHost.
  ///
  /// In ar, this message translates to:
  /// **'المضيف'**
  String get detailsHost;

  /// No description provided for @detailsOrganizer.
  ///
  /// In ar, this message translates to:
  /// **'منظم'**
  String get detailsOrganizer;

  /// No description provided for @detailsGuest.
  ///
  /// In ar, this message translates to:
  /// **'ضيف'**
  String get detailsGuest;

  /// No description provided for @detailsPending.
  ///
  /// In ar, this message translates to:
  /// **'معلق..'**
  String get detailsPending;

  /// No description provided for @detailsAcceptedAt.
  ///
  /// In ar, this message translates to:
  /// **'وافق: {date}'**
  String detailsAcceptedAt(Object date);

  /// No description provided for @detailsDeletedAt.
  ///
  /// In ar, this message translates to:
  /// **'حذف: {date}'**
  String detailsDeletedAt(Object date);

  /// No description provided for @detailsStayDuration.
  ///
  /// In ar, this message translates to:
  /// **'مكث: {duration}'**
  String detailsStayDuration(Object duration);

  /// No description provided for @detailsDone.
  ///
  /// In ar, this message translates to:
  /// **'أنجز'**
  String get detailsDone;

  /// No description provided for @detailsCreatedBy.
  ///
  /// In ar, this message translates to:
  /// **'أنشأ الموعد: {date}'**
  String detailsCreatedBy(Object date);

  /// No description provided for @detailsPersonalCategory.
  ///
  /// In ar, this message translates to:
  /// **'التصنيف الشخصي'**
  String get detailsPersonalCategory;

  /// No description provided for @detailsNoCategory.
  ///
  /// In ar, this message translates to:
  /// **'بدون تصنيف'**
  String get detailsNoCategory;

  /// No description provided for @detailsAddNew.
  ///
  /// In ar, this message translates to:
  /// **'إضافة جديد'**
  String get detailsAddNew;

  /// No description provided for @detailsQuickActions.
  ///
  /// In ar, this message translates to:
  /// **'إجراءات سريعة'**
  String get detailsQuickActions;

  /// No description provided for @detailsClone.
  ///
  /// In ar, this message translates to:
  /// **'استنساخ'**
  String get detailsClone;

  /// No description provided for @detailsArchive.
  ///
  /// In ar, this message translates to:
  /// **'أرشفة'**
  String get detailsArchive;

  /// No description provided for @detailsUnarchive.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الأرشفة'**
  String get detailsUnarchive;

  /// No description provided for @detailsPersonalSettings.
  ///
  /// In ar, this message translates to:
  /// **'إعدادات النسخة الشخصية'**
  String get detailsPersonalSettings;

  /// No description provided for @detailsTrashWarning.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن استرجاع المواعيد من سلة المحذوفات.'**
  String get detailsTrashWarning;

  /// No description provided for @detailsSavePersonalSettings.
  ///
  /// In ar, this message translates to:
  /// **'حفظ الإعدادات الشخصية'**
  String get detailsSavePersonalSettings;

  /// No description provided for @detailsAddToCalendar.
  ///
  /// In ar, this message translates to:
  /// **'أضف للتقويم'**
  String get detailsAddToCalendar;

  /// No description provided for @batchSyncTitle.
  ///
  /// In ar, this message translates to:
  /// **'مزامنة المواعيد العامة'**
  String get batchSyncTitle;

  /// No description provided for @batchSyncSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم حفظ {count} مواعيد جديدة (تم)'**
  String batchSyncSuccess(int count);

  /// No description provided for @batchSyncNoNew.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد مواعيد جديدة لحفظها'**
  String get batchSyncNoNew;

  /// No description provided for @am.
  ///
  /// In ar, this message translates to:
  /// **'ص'**
  String get am;

  /// No description provided for @pm.
  ///
  /// In ar, this message translates to:
  /// **'م'**
  String get pm;

  /// No description provided for @timeAgoJustNow.
  ///
  /// In ar, this message translates to:
  /// **'الآن'**
  String get timeAgoJustNow;

  /// No description provided for @timeAgoMinutes.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, one{منذ دقيقة} two{منذ دقيقتين} few{منذ {count} دقائق} many{منذ {count} دقيقة} other{منذ {count} دقيقة}}'**
  String timeAgoMinutes(num count);

  /// No description provided for @timeAgoHours.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, one{منذ ساعة} two{منذ ساعتين} few{منذ {count} ساعات} many{منذ {count} ساعة} other{منذ {count} ساعة}}'**
  String timeAgoHours(num count);

  /// No description provided for @timeAgoDays.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, one{منذ يوم} two{منذ يومين} few{منذ {count} أيام} many{منذ {count} يوماً} other{منذ {count} يوم}}'**
  String timeAgoDays(num count);

  /// No description provided for @durationDays.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, one{يوم واحد} two{يومين} few{{count} أيام} many{{count} يوماً} other{{count} يوم}}'**
  String durationDays(num count);

  /// No description provided for @durationHours.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, one{ساعة واحدة} two{ساعتين} few{{count} ساعات} many{{count} ساعة} other{{count} ساعة}}'**
  String durationHours(num count);

  /// No description provided for @durationLessThanHour.
  ///
  /// In ar, this message translates to:
  /// **'أقل من ساعة'**
  String get durationLessThanHour;

  /// No description provided for @extraGuestsCount.
  ///
  /// In ar, this message translates to:
  /// **'+{count}'**
  String extraGuestsCount(Object count);

  /// No description provided for @contactInquiry.
  ///
  /// In ar, this message translates to:
  /// **'استفسار عام'**
  String get contactInquiry;

  /// No description provided for @contactComplaint.
  ///
  /// In ar, this message translates to:
  /// **'شكوى / مشكلة'**
  String get contactComplaint;

  /// No description provided for @contactSuggestion.
  ///
  /// In ar, this message translates to:
  /// **'اقتراح'**
  String get contactSuggestion;

  /// No description provided for @contactOther.
  ///
  /// In ar, this message translates to:
  /// **'أخرى'**
  String get contactOther;

  /// No description provided for @messageSentSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم إرسال رسالتك بنجاح. شكراً لتواصلك معنا!'**
  String get messageSentSuccess;

  /// No description provided for @contactIntro.
  ///
  /// In ar, this message translates to:
  /// **'نسعد بتواصلك معنا. يرجى اختيار نوع الرسالة وكتابة التفاصيل بوضوح.'**
  String get contactIntro;

  /// No description provided for @contactMsgType.
  ///
  /// In ar, this message translates to:
  /// **'نوع الرسالة'**
  String get contactMsgType;

  /// No description provided for @contactMsgTitle.
  ///
  /// In ar, this message translates to:
  /// **'عنوان الرسالة'**
  String get contactMsgTitle;

  /// No description provided for @requiredField.
  ///
  /// In ar, this message translates to:
  /// **'هذا الحقل مطلوب'**
  String get requiredField;

  /// No description provided for @contactMsgDetails.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل الرسالة'**
  String get contactMsgDetails;

  /// No description provided for @noBlockedUsers.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد مستخدمون محظورون'**
  String get noBlockedUsers;

  /// No description provided for @unblockTitle.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الحظر'**
  String get unblockTitle;

  /// No description provided for @unblockConfirm.
  ///
  /// In ar, this message translates to:
  /// **'هل تريد إلغاء حظر {name}؟'**
  String unblockConfirm(String name);

  /// No description provided for @unblockConfirmAction.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الحظر'**
  String get unblockConfirmAction;

  /// No description provided for @enableNotifications.
  ///
  /// In ar, this message translates to:
  /// **'تفعيل الإشعارات'**
  String get enableNotifications;

  /// No description provided for @enableNotificationsDesc.
  ///
  /// In ar, this message translates to:
  /// **'استقبال جميع الإشعارات والتنبيهات'**
  String get enableNotificationsDesc;

  /// No description provided for @customizeNotifications.
  ///
  /// In ar, this message translates to:
  /// **'تخصيص الإشعارات'**
  String get customizeNotifications;

  /// No description provided for @newFollowersDesc.
  ///
  /// In ar, this message translates to:
  /// **'متابعات جديدة'**
  String get newFollowersDesc;

  /// No description provided for @notifyFollowsDesc.
  ///
  /// In ar, this message translates to:
  /// **'إشعارات عند قيام شخص بمتابعتك'**
  String get notifyFollowsDesc;

  /// No description provided for @invitesAndUpdatesDesc.
  ///
  /// In ar, this message translates to:
  /// **'الدعوات والتحديثات'**
  String get invitesAndUpdatesDesc;

  /// No description provided for @notifyInvitesDesc.
  ///
  /// In ar, this message translates to:
  /// **'دعوات المواعيد، القبول، أو الإلغاء'**
  String get notifyInvitesDesc;

  /// No description provided for @appointmentAlertsDesc.
  ///
  /// In ar, this message translates to:
  /// **'تنبيهات المواعيد'**
  String get appointmentAlertsDesc;

  /// No description provided for @notifyActiveDesc.
  ///
  /// In ar, this message translates to:
  /// **'التنبيه عند حلول وقت الموعد'**
  String get notifyActiveDesc;

  /// No description provided for @reminderOneDayBefore.
  ///
  /// In ar, this message translates to:
  /// **'تذكير قبل يوم'**
  String get reminderOneDayBefore;

  /// No description provided for @notifyOneDayBeforeDesc.
  ///
  /// In ar, this message translates to:
  /// **'إرسال تنبيه قبل الموعد بـ 24 ساعة'**
  String get notifyOneDayBeforeDesc;

  /// No description provided for @readerInflux.
  ///
  /// In ar, this message translates to:
  /// **'توافد القراء'**
  String get readerInflux;

  /// No description provided for @notifyReaderInfluxDesc.
  ///
  /// In ar, this message translates to:
  /// **'إشعارات عند قراءة أو زيارة مقالاتك'**
  String get notifyReaderInfluxDesc;

  /// No description provided for @notifyBookmarks.
  ///
  /// In ar, this message translates to:
  /// **'تنبيهات المواعيد المحفوظة'**
  String get notifyBookmarks;

  /// No description provided for @notifyBookmarksDesc.
  ///
  /// In ar, this message translates to:
  /// **'تلقي تنبيهات للمواعيد المضافة في المحفوظات'**
  String get notifyBookmarksDesc;

  /// No description provided for @notifyBeforeOffset.
  ///
  /// In ar, this message translates to:
  /// **'تذكير قبل الموعد بمدة'**
  String get notifyBeforeOffset;

  /// No description provided for @notifyBeforeOffsetDesc.
  ///
  /// In ar, this message translates to:
  /// **'تحديد وقت مسبق للتذكير بالمواعيد'**
  String get notifyBeforeOffsetDesc;

  /// No description provided for @notifySalutes.
  ///
  /// In ar, this message translates to:
  /// **'إشعارات التحية'**
  String get notifySalutes;

  /// No description provided for @notifySalutesDesc.
  ///
  /// In ar, this message translates to:
  /// **'تلقي تنبيهات عندما يلقي شخص ما التحية عليك'**
  String get notifySalutesDesc;

  /// No description provided for @notifySystem.
  ///
  /// In ar, this message translates to:
  /// **'التنبيهات العامة'**
  String get notifySystem;

  /// No description provided for @notifySystemDesc.
  ///
  /// In ar, this message translates to:
  /// **'تلقي الإعلانات والإشعارات العامة من النظام'**
  String get notifySystemDesc;

  /// No description provided for @notifyReminders.
  ///
  /// In ar, this message translates to:
  /// **'تذكيرات المواعيد'**
  String get notifyReminders;

  /// No description provided for @notifyRemindersDesc.
  ///
  /// In ar, this message translates to:
  /// **'تلقي تذكيرات وتنبيهات مواعيد اللقاءات'**
  String get notifyRemindersDesc;

  /// No description provided for @minutes10.
  ///
  /// In ar, this message translates to:
  /// **'10 دقائق قبل الموعد'**
  String get minutes10;

  /// No description provided for @minutes15.
  ///
  /// In ar, this message translates to:
  /// **'15 دقيقة قبل الموعد'**
  String get minutes15;

  /// No description provided for @minutes30.
  ///
  /// In ar, this message translates to:
  /// **'30 دقيقة قبل الموعد'**
  String get minutes30;

  /// No description provided for @hour1.
  ///
  /// In ar, this message translates to:
  /// **'ساعة واحدة قبل الموعد'**
  String get hour1;

  /// No description provided for @hours2.
  ///
  /// In ar, this message translates to:
  /// **'ساعتان قبل الموعد'**
  String get hours2;

  /// No description provided for @addCategory.
  ///
  /// In ar, this message translates to:
  /// **'إضافة تصنيف'**
  String get addCategory;

  /// No description provided for @editCategory.
  ///
  /// In ar, this message translates to:
  /// **'تعديل'**
  String get editCategory;

  /// No description provided for @privacyIntroTitle.
  ///
  /// In ar, this message translates to:
  /// **'1. مقدمة (Introduction)'**
  String get privacyIntroTitle;

  /// No description provided for @privacyIntroContent.
  ///
  /// In ar, this message translates to:
  /// **'نحن في تطبيق \"سجلي\" نلتزم بحماية بياناتك الشخصية وتوضيح كيفية جمعها واستخدامها. هذا التطبيق مخصص للتواصل الاجتماعي وتنظيم المواعيد، وخصوصيتك هي أولويتنا القصوى.\n\nAt \"Sijilli\" app, we are committed to protecting your personal data and clarifying how it is collected and used. This app is dedicated to social networking and appointment organization, and your privacy is our top priority.'**
  String get privacyIntroContent;

  /// No description provided for @privacyDataTitle.
  ///
  /// In ar, this message translates to:
  /// **'2. البيانات التي نجمعها (Information We Collect)'**
  String get privacyDataTitle;

  /// No description provided for @privacyDataContent.
  ///
  /// In ar, this message translates to:
  /// **'• معلومات الحساب: مثل الاسم، البريد الإلكتروني، وصورة الملف الشخصي لتعريف هويتك.\n• جهات الاتصال: نطلب الوصول لقائمة الاتصال للسماح لك بدعوة أصدقائك ومزامنة المواعيد معهم بسهولة.\n• المحتوى الذي تنشئه (UGC): المواعيد، التعليقات، والصور التي ترفعها لغرض المشاركة.\n• البيانات التقنية: نوع الجهاز، نظام التصديق، وعنوان الـ IP لضمان استقرار التطبيق.\n\n• Account Information: Name, email, and profile picture.\n• Contacts: We access your contacts to allow you to invite friends and sync appointments.\n• User-Generated Content (UGC): Appointments, comments, and photos.\n• Technical Data: Device info and IP address.'**
  String get privacyDataContent;

  /// No description provided for @privacySecurityTitle.
  ///
  /// In ar, this message translates to:
  /// **'3. أمان وحماية البيانات (Data Security)'**
  String get privacySecurityTitle;

  /// No description provided for @privacySecurityContent.
  ///
  /// In ar, this message translates to:
  /// **'نحن نستخدم بروتوكولات تشفير متطورة (مثل SSL/TLS) لنقل البيانات بشكل آمن بين هاتفك وخوادمنا، لضمان عدم وصول أي طرف غير مصرح له إلى معلوماتك.\n\nWe use advanced encryption protocols (such as SSL/TLS) لنقل البيانات بشكل آمن بين هاتفك وخوادمنا، لضمان عدم وصول أي طرف غير مصرح له إلى معلوماتك.'**
  String get privacySecurityContent;

  /// No description provided for @privacyUsageTitle.
  ///
  /// In ar, this message translates to:
  /// **'4. كيفية استخدام البيانات (How We Use Your Information)'**
  String get privacyUsageTitle;

  /// No description provided for @privacyUsageContent.
  ///
  /// In ar, this message translates to:
  /// **'• توفير ميزات التواصل الاجتماعي ومتابعة المستخدمين الآخرين وتنظيم المواعيد.\n• تحسين تجربة المستخدم ومنع أي عمليات احتيال أو إساءة استخدام.\n• إرسال التنبيهات الضرورية المتعلقة بمواعيدك وتفاعلات الآخرين معك.\n\n• Providing social networking, following features, and appointment organization.\n• Enhancing user experience and preventing fraud or misuse.\n• Sending necessary notifications regarding appointments and user interactions.'**
  String get privacyUsageContent;

  /// No description provided for @privacyUGCTitle.
  ///
  /// In ar, this message translates to:
  /// **'5. سياسة المحتوى (User-Generated Content - UGC Policy)'**
  String get privacyUGCTitle;

  /// No description provided for @privacyUGCContent.
  ///
  /// In ar, this message translates to:
  /// **'• أنت المسؤول الأول عن المحتوى الذي تنشره عبر التطبيق.\n• يمنع منعاً باتاً نشر محتوى مسيء، غير قانوني، أو ينتهك حقوق الآخرين.\n• يوفر التطبيق أدوات للإبلاغ (Report) والحظر (Block) للتعامل مع أي مخالفة.\n• نحتفظ بالحق في إزالة المحتوى المخالف وحظر الحسابات التي تنتهك شروطنا خلال 24 ساعة من التبليغ.\n\n• You are primarily responsible for the content you post.\n• Offensive, illegal, or infringing content is strictly forbidden.\n• The app provides Reporting and Blocking tools for any violations.\n• We reserve the right to remove non-compliant content and block violating accounts within 24 hours of reporting.'**
  String get privacyUGCContent;

  /// No description provided for @privacyChildrenTitle.
  ///
  /// In ar, this message translates to:
  /// **'6. خصوصية الأطفال (Childrens Privacy)'**
  String get privacyChildrenTitle;

  /// No description provided for @privacyChildrenContent.
  ///
  /// In ar, this message translates to:
  /// **'هذا التطبيق غير موجه للأطفال دون سن 13 عاماً، ونحن لا نجمع بياناتهم عن عمد. في حال اكتشافنا لجمع بيانات طفل دون هذا السن، سنقوم بحذفها فوراً.\n\nThis app is not intended for children under 13, and we do not knowingly collect their data. If we discover such data collection, it will be deleted immediately.'**
  String get privacyChildrenContent;

  /// No description provided for @privacyDeletionTitle.
  ///
  /// In ar, this message translates to:
  /// **'7. حذف البيانات والحساب (Data Retention & Deletion)'**
  String get privacyDeletionTitle;

  /// No description provided for @privacyDeletionContent.
  ///
  /// In ar, this message translates to:
  /// **'نمنحك التحكم الكامل في بياناتك؛ يمكنك حذف حسابك وكل البيانات المرتبطة به في أي وقت من خلال إعدادات التطبيق. كما يمكنك مراسلتنا لطلب حذف البيانات عبر البريد الإلكتروني: sijilliapp@gmail.com.\n\nYou have full control over your data; you can delete your account and all associated data at any time via app settings. You can also request data deletion by emailing us at: sijilliapp@gmail.com.'**
  String get privacyDeletionContent;

  /// No description provided for @privacySharingTitle.
  ///
  /// In ar, this message translates to:
  /// **'8. مشاركة البيانات (Third-Party Sharing)'**
  String get privacySharingTitle;

  /// No description provided for @privacySharingContent.
  ///
  /// In ar, this message translates to:
  /// **'نحن لا نبيع بياناتك الشخصية لأي جهة. قد نستخدم خدمات تقنية موثوقة (مثل خدمات الإشعارات) مع الالتزام التام بمعايير الخصوصية العالمية.\n\nWe do not sell your personal data. We may use trusted technical services (e.g., notification services) in full compliance with global privacy standards.'**
  String get privacySharingContent;

  /// No description provided for @privacyContact.
  ///
  /// In ar, this message translates to:
  /// **'للتواصل: sijilliapp@gmail.com'**
  String get privacyContact;

  /// No description provided for @privacyLastUpdate.
  ///
  /// In ar, this message translates to:
  /// **'آخر تحديث: يناير 2026'**
  String get privacyLastUpdate;

  /// No description provided for @noArchivedAppointments.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد مواعيد مؤرشفة'**
  String get noArchivedAppointments;

  /// No description provided for @searchArchive.
  ///
  /// In ar, this message translates to:
  /// **'بحث في الأرشيف...'**
  String get searchArchive;

  /// No description provided for @trashEmpty.
  ///
  /// In ar, this message translates to:
  /// **'سلة المحذوفات فارغة'**
  String get trashEmpty;

  /// No description provided for @newFollowerTitle.
  ///
  /// In ar, this message translates to:
  /// **'اعتماد جديد'**
  String get newFollowerTitle;

  /// No description provided for @followRequestTitle.
  ///
  /// In ar, this message translates to:
  /// **'طلب اعتماد'**
  String get followRequestTitle;

  /// No description provided for @startedFollowingYou.
  ///
  /// In ar, this message translates to:
  /// **'بدأ {name} باعتمادك'**
  String startedFollowingYou(String name);

  /// No description provided for @wantsToFollowYou.
  ///
  /// In ar, this message translates to:
  /// **'يرغب {name} باعتمادك'**
  String wantsToFollowYou(String name);

  /// No description provided for @hijriDatePickerTitle.
  ///
  /// In ar, this message translates to:
  /// **'اختر التاريخ الهجري'**
  String get hijriDatePickerTitle;

  /// No description provided for @removeAccreditation.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الاعتماد'**
  String get removeAccreditation;

  /// No description provided for @removeAccreditationDesc.
  ///
  /// In ar, this message translates to:
  /// **'تنبيه: إنهاء الاعتماد سيتطلب موافقة الطرف الآخر مرة أخرى لتبادل المواعيد مستقبلاً.'**
  String get removeAccreditationDesc;

  /// No description provided for @newAppointmentAction.
  ///
  /// In ar, this message translates to:
  /// **'موعد جديد'**
  String get newAppointmentAction;

  /// No description provided for @yesRemoveAccreditation.
  ///
  /// In ar, this message translates to:
  /// **'نعم، إزالة'**
  String get yesRemoveAccreditation;

  /// No description provided for @accreditedBadge.
  ///
  /// In ar, this message translates to:
  /// **'معتمَد'**
  String get accreditedBadge;

  /// No description provided for @magneticHome.
  ///
  /// In ar, this message translates to:
  /// **'الرئيسية المغناطيسية'**
  String get magneticHome;

  /// No description provided for @magneticHomeDesc.
  ///
  /// In ar, this message translates to:
  /// **'التركيز التلقائي على المواعيد عند الدخول'**
  String get magneticHomeDesc;

  /// No description provided for @connectAction.
  ///
  /// In ar, this message translates to:
  /// **'طلب اعتماد'**
  String get connectAction;

  /// No description provided for @ghostMode.
  ///
  /// In ar, this message translates to:
  /// **'وضع التخفي (Ghost Mode)'**
  String get ghostMode;

  /// No description provided for @ghostModeDesc.
  ///
  /// In ar, this message translates to:
  /// **'منع ظهور ملفك الشخصي في نتائج البحث العامة'**
  String get ghostModeDesc;

  /// No description provided for @publicAccount.
  ///
  /// In ar, this message translates to:
  /// **'حساب عام'**
  String get publicAccount;

  /// No description provided for @publicAccountDesc.
  ///
  /// In ar, this message translates to:
  /// **'السماح للآخرين بالعثور عليك ومتابعتك'**
  String get publicAccountDesc;

  /// No description provided for @downloadFullImageConfirm.
  ///
  /// In ar, this message translates to:
  /// **'تنزيل الصورة بكامل دقتها فقط بين المعتمدين'**
  String get downloadFullImageConfirm;

  /// No description provided for @download.
  ///
  /// In ar, this message translates to:
  /// **'تنزيل'**
  String get download;

  /// No description provided for @operationFailed.
  ///
  /// In ar, this message translates to:
  /// **'فشلت العملية: {error}'**
  String operationFailed(String error);

  /// No description provided for @registrationClosedTitle.
  ///
  /// In ar, this message translates to:
  /// **'عذراً، التسجيل مغلق حالياً'**
  String get registrationClosedTitle;

  /// No description provided for @registrationClosedMessage.
  ///
  /// In ar, this message translates to:
  /// **'لقد اكتمل النصاب الحالي للمستخدمين، أو أننا نجري بعض التحسينات لضمان أفضل تجربة لك.'**
  String get registrationClosedMessage;

  /// No description provided for @contactUsForInvite.
  ///
  /// In ar, this message translates to:
  /// **'يمكنك التواصل معنا للاستفسار أو طلب دعوة خاصة:'**
  String get contactUsForInvite;

  /// No description provided for @backToLogin.
  ///
  /// In ar, this message translates to:
  /// **'العودة لتسجيل الدخول'**
  String get backToLogin;

  /// No description provided for @whatsapp.
  ///
  /// In ar, this message translates to:
  /// **'واتساب'**
  String get whatsapp;

  /// No description provided for @ourEmail.
  ///
  /// In ar, this message translates to:
  /// **'بريدنا'**
  String get ourEmail;

  /// No description provided for @bio.
  ///
  /// In ar, this message translates to:
  /// **'النبذة التعريفية'**
  String get bio;

  /// No description provided for @phone.
  ///
  /// In ar, this message translates to:
  /// **'رقم الهاتف'**
  String get phone;

  /// No description provided for @socialLink.
  ///
  /// In ar, this message translates to:
  /// **'رابط خارجي'**
  String get socialLink;

  /// No description provided for @changePassword.
  ///
  /// In ar, this message translates to:
  /// **'تغيير كلمة المرور'**
  String get changePassword;

  /// No description provided for @oldPassword.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور الحالية'**
  String get oldPassword;

  /// No description provided for @newPassword.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور الجديدة'**
  String get newPassword;

  /// No description provided for @confirmNewPassword.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد كلمة المرور الجديدة'**
  String get confirmNewPassword;

  /// No description provided for @passwordChangedSuccessfully.
  ///
  /// In ar, this message translates to:
  /// **'تم تغيير كلمة المرور بنجاح'**
  String get passwordChangedSuccessfully;

  /// No description provided for @oldPasswordIncorrect.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور الحالية غير صحيحة'**
  String get oldPasswordIncorrect;

  /// No description provided for @forgotPasswordDesc.
  ///
  /// In ar, this message translates to:
  /// **'أدخل بريدك الإلكتروني لاستعادة الوصول إلى حسابك'**
  String get forgotPasswordDesc;

  /// No description provided for @emailSentSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم الإرسال بنجاح'**
  String get emailSentSuccess;

  /// No description provided for @passwordResetInstructions.
  ///
  /// In ar, this message translates to:
  /// **'تم إرسال تعليمات إعادة تعيين كلمة المرور إلى {email}'**
  String passwordResetInstructions(String email);

  /// No description provided for @orContactByEmail.
  ///
  /// In ar, this message translates to:
  /// **'أو راسلنا على البريد الإلكتروني'**
  String get orContactByEmail;

  /// No description provided for @articleCopied.
  ///
  /// In ar, this message translates to:
  /// **'تم نسخ \"{title}\" إلى الحافظة'**
  String articleCopied(String title);

  /// No description provided for @confirmDeleteArticle.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد الحذف'**
  String get confirmDeleteArticle;

  /// No description provided for @confirmDeleteArticleMsg.
  ///
  /// In ar, this message translates to:
  /// **'هل أنت متأكد أنك تريد حذف \"{title}\" نهائياً؟'**
  String confirmDeleteArticleMsg(String title);

  /// No description provided for @copy.
  ///
  /// In ar, this message translates to:
  /// **'نسخ'**
  String get copy;

  /// No description provided for @readTimeFormat.
  ///
  /// In ar, this message translates to:
  /// **'مدة القراءة: {minutes} دقيقة {words} كلمة'**
  String readTimeFormat(int minutes, int words);

  /// No description provided for @readTimeMins.
  ///
  /// In ar, this message translates to:
  /// **'مدة القراءة: {minutes} دقيقة'**
  String readTimeMins(int minutes);

  /// No description provided for @articleDraftRestored.
  ///
  /// In ar, this message translates to:
  /// **'تم استرجاع مسودة المقال'**
  String get articleDraftRestored;

  /// No description provided for @publishArticle.
  ///
  /// In ar, this message translates to:
  /// **'نشر المقال'**
  String get publishArticle;

  /// No description provided for @wordsCount.
  ///
  /// In ar, this message translates to:
  /// **'عدد الكلمات: {count}'**
  String wordsCount(int count);

  /// No description provided for @lastEdited.
  ///
  /// In ar, this message translates to:
  /// **'آخر تحرير: {date}'**
  String lastEdited(String date);

  /// No description provided for @boldTextFirst.
  ///
  /// In ar, this message translates to:
  /// **'الرجاء تحديد النص المراد تغميقه أولاً'**
  String get boldTextFirst;

  /// No description provided for @selectVersesFirst.
  ///
  /// In ar, this message translates to:
  /// **'الرجاء تظليل الأبيات أولاً'**
  String get selectVersesFirst;

  /// No description provided for @centerTextFirst.
  ///
  /// In ar, this message translates to:
  /// **'الرجاء تحديد النص المراد توسيطه أولاً'**
  String get centerTextFirst;

  /// No description provided for @justifyTextFirst.
  ///
  /// In ar, this message translates to:
  /// **'الرجاء تحديد النص المراد ضبطه أولاً'**
  String get justifyTextFirst;

  /// No description provided for @closePreview.
  ///
  /// In ar, this message translates to:
  /// **'إغلاق المعاينة'**
  String get closePreview;

  /// No description provided for @livePreview.
  ///
  /// In ar, this message translates to:
  /// **'معاينة حية'**
  String get livePreview;

  /// No description provided for @addArticleCoverOptional.
  ///
  /// In ar, this message translates to:
  /// **'إضافة غلاف المقال (اختياري)'**
  String get addArticleCoverOptional;

  /// No description provided for @writeArticleHint.
  ///
  /// In ar, this message translates to:
  /// **'اكتب مقالك أو قصيدتك هنا...'**
  String get writeArticleHint;

  /// No description provided for @boldTooltip.
  ///
  /// In ar, this message translates to:
  /// **'تغميق النص (عريض)'**
  String get boldTooltip;

  /// No description provided for @poemTooltip.
  ///
  /// In ar, this message translates to:
  /// **'تنسيق الشعر'**
  String get poemTooltip;

  /// No description provided for @centerTooltip.
  ///
  /// In ar, this message translates to:
  /// **'توسيط النص'**
  String get centerTooltip;

  /// No description provided for @justifyTooltip.
  ///
  /// In ar, this message translates to:
  /// **'ضبط النص'**
  String get justifyTooltip;

  /// No description provided for @editArticleCover.
  ///
  /// In ar, this message translates to:
  /// **'تعديل غلاف المقال'**
  String get editArticleCover;

  /// No description provided for @expandImage.
  ///
  /// In ar, this message translates to:
  /// **'توسيع الصورة'**
  String get expandImage;

  /// No description provided for @copiedToClipboard.
  ///
  /// In ar, this message translates to:
  /// **'تم نسخ {url} للحافظة'**
  String copiedToClipboard(String url);

  /// No description provided for @errorFetchingArticle.
  ///
  /// In ar, this message translates to:
  /// **'تعذر جلب بيانات المقال. الرجاء التحقق من الرابط.'**
  String get errorFetchingArticle;

  /// No description provided for @article.
  ///
  /// In ar, this message translates to:
  /// **'المقال'**
  String get article;

  /// No description provided for @adminPanelTitle.
  ///
  /// In ar, this message translates to:
  /// **'لوحة تحكم المشرف العام'**
  String get adminPanelTitle;

  /// No description provided for @systemSettingsSection.
  ///
  /// In ar, this message translates to:
  /// **'إعدادات النظام العامة'**
  String get systemSettingsSection;

  /// No description provided for @registrationSettings.
  ///
  /// In ar, this message translates to:
  /// **'إعدادات التسجيل والتواصل'**
  String get registrationSettings;

  /// No description provided for @registrationSettingsDesc.
  ///
  /// In ar, this message translates to:
  /// **'التحكم في حالة التسجيل للجدد ورقم الواتساب والبريد الإلكتروني للقرّاء'**
  String get registrationSettingsDesc;

  /// No description provided for @userManagement.
  ///
  /// In ar, this message translates to:
  /// **'إدارة حسابات المستخدمين'**
  String get userManagement;

  /// No description provided for @userManagementDesc.
  ///
  /// In ar, this message translates to:
  /// **'البحث عن المشتركين وتعديل الصلاحيات والأدوار الفعالة'**
  String get userManagementDesc;

  /// No description provided for @articlesManagement.
  ///
  /// In ar, this message translates to:
  /// **'إدارة المقالات والمحتوى'**
  String get articlesManagement;

  /// No description provided for @articlePrefs.
  ///
  /// In ar, this message translates to:
  /// **'تفضيلات المقالات الإدارية'**
  String get articlePrefs;

  /// No description provided for @articlePrefsDesc.
  ///
  /// In ar, this message translates to:
  /// **'الحد الأقصى لحروف المقالات وإدارة قاموس الأخطاء الشائعة المخصص'**
  String get articlePrefsDesc;

  /// No description provided for @userMessages.
  ///
  /// In ar, this message translates to:
  /// **'مراسلات المشتركين'**
  String get userMessages;

  /// No description provided for @incomingMessages.
  ///
  /// In ar, this message translates to:
  /// **'الرسائل الواردة من القراء'**
  String get incomingMessages;

  /// No description provided for @incomingMessagesDesc.
  ///
  /// In ar, this message translates to:
  /// **'عرض الاستفسارات والشكاوى الواردة من صفحة التواصل والرد عليها'**
  String get incomingMessagesDesc;

  /// No description provided for @reportsAndTickets.
  ///
  /// In ar, this message translates to:
  /// **'البلاغات والتقارير'**
  String get reportsAndTickets;

  /// No description provided for @reportsAndTicketsDesc.
  ///
  /// In ar, this message translates to:
  /// **'متابعة البلاغات وحل المشكلات المتعلقة بالمواعيد أو المقالات المسيئة'**
  String get reportsAndTicketsDesc;

  /// No description provided for @searchSubscribers.
  ///
  /// In ar, this message translates to:
  /// **'البحث عن المشتركين...'**
  String get searchSubscribers;

  /// No description provided for @recentlyRegistered.
  ///
  /// In ar, this message translates to:
  /// **'المسجلون حديثاً'**
  String get recentlyRegistered;

  /// No description provided for @allAdmins.
  ///
  /// In ar, this message translates to:
  /// **'المشرفون'**
  String get allAdmins;

  /// No description provided for @searchResult.
  ///
  /// In ar, this message translates to:
  /// **'نتائج البحث'**
  String get searchResult;

  /// No description provided for @clearSearch.
  ///
  /// In ar, this message translates to:
  /// **'مسح البحث'**
  String get clearSearch;

  /// No description provided for @noRecentSearches.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد عمليات بحث أخيرة'**
  String get noRecentSearches;

  /// No description provided for @editUserAccount.
  ///
  /// In ar, this message translates to:
  /// **'تعديل حساب المشترك'**
  String get editUserAccount;

  /// No description provided for @simulateLogin.
  ///
  /// In ar, this message translates to:
  /// **'محاكاة الدخول للحساب'**
  String get simulateLogin;

  /// No description provided for @simulateConfirm.
  ///
  /// In ar, this message translates to:
  /// **'هل تريد تصفح التطبيق بصفتك المشترك {name}؟\n\nسيقوم التطبيق بنقلك للواجهة الرئيسية كأنك المشترك، مع إمكانية العودة لحسابك كمشرف في أي وقت.'**
  String simulateConfirm(String name);

  /// No description provided for @loginSimulated.
  ///
  /// In ar, this message translates to:
  /// **'تم الدخول بصفتك {name} 👥'**
  String loginSimulated(String name);

  /// No description provided for @permissionsAndControl.
  ///
  /// In ar, this message translates to:
  /// **'الصلاحيات والتحكم'**
  String get permissionsAndControl;

  /// No description provided for @accountOptions.
  ///
  /// In ar, this message translates to:
  /// **'إعدادات وخصائص الحساب الفعالة'**
  String get accountOptions;

  /// No description provided for @verifiedEmailLabel.
  ///
  /// In ar, this message translates to:
  /// **'توثيق البريد الإلكتروني (Verified Email)'**
  String get verifiedEmailLabel;

  /// No description provided for @verifiedEmailDesc.
  ///
  /// In ar, this message translates to:
  /// **'تحديد حالة التحقق والتوثيق للبريد الإلكتروني للقروبات.'**
  String get verifiedEmailDesc;

  /// No description provided for @verifiedPhoneLabel.
  ///
  /// In ar, this message translates to:
  /// **'توثيق رقم الهاتف (Verified Phone)'**
  String get verifiedPhoneLabel;

  /// No description provided for @verifiedPhoneDesc.
  ///
  /// In ar, this message translates to:
  /// **'تحديد ما إذا كان رقم هاتف المشترك موثق ومؤكد.'**
  String get verifiedPhoneDesc;

  /// No description provided for @publicProfileLabel.
  ///
  /// In ar, this message translates to:
  /// **'ملف شخصي عام (Public Profile)'**
  String get publicProfileLabel;

  /// No description provided for @publicProfileDesc.
  ///
  /// In ar, this message translates to:
  /// **'السماح للجميع برؤية ومتابعة هذا الملف الشخصي.'**
  String get publicProfileDesc;

  /// No description provided for @hideFromSearchLabel.
  ///
  /// In ar, this message translates to:
  /// **'إخفاء الحساب من محرك البحث'**
  String get hideFromSearchLabel;

  /// No description provided for @hideFromSearchDesc.
  ///
  /// In ar, this message translates to:
  /// **'منع ظهور حساب المشترك في نتائج البحث العامة داخل التطبيق.'**
  String get hideFromSearchDesc;

  /// No description provided for @suggestedAccountLabel.
  ///
  /// In ar, this message translates to:
  /// **'حساب مقترح (Suggested Account)'**
  String get suggestedAccountLabel;

  /// No description provided for @suggestedAccountDesc.
  ///
  /// In ar, this message translates to:
  /// **'إظهار حساب هذا المشترك في قائمة الحسابات المقترحة للاعتماد.'**
  String get suggestedAccountDesc;

  /// No description provided for @superAdminLabel.
  ///
  /// In ar, this message translates to:
  /// **'ترقية لمشرف عام (Super Admin)'**
  String get superAdminLabel;

  /// No description provided for @superAdminDesc.
  ///
  /// In ar, this message translates to:
  /// **'منح صلاحيات كاملة لإدارة الأدوار وتعديل صلاحيات المشرفين الآخرين.'**
  String get superAdminDesc;

  /// No description provided for @saveChangesBtn.
  ///
  /// In ar, this message translates to:
  /// **'حفظ التغييرات'**
  String get saveChangesBtn;

  /// No description provided for @userRoleLabel.
  ///
  /// In ar, this message translates to:
  /// **'الدور الوظيفي / الصلاحية (Role)'**
  String get userRoleLabel;

  /// No description provided for @roleUserOption.
  ///
  /// In ar, this message translates to:
  /// **'مستخدم عادي (user)'**
  String get roleUserOption;

  /// No description provided for @roleApprovedOption.
  ///
  /// In ar, this message translates to:
  /// **'مستخدم معتمد (approved)'**
  String get roleApprovedOption;

  /// No description provided for @roleAdminOption.
  ///
  /// In ar, this message translates to:
  /// **'مشرف عام (admin)'**
  String get roleAdminOption;

  /// No description provided for @saveChangesSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم تحديث إعدادات حساب المشترك بنجاح 🛡️'**
  String get saveChangesSuccess;

  /// No description provided for @saveChangesFailed.
  ///
  /// In ar, this message translates to:
  /// **'فشل حفظ التغييرات، يرجى مراجعة الصلاحيات'**
  String get saveChangesFailed;

  /// No description provided for @registrationGate.
  ///
  /// In ar, this message translates to:
  /// **'حالة التسجيل للجدد'**
  String get registrationGate;

  /// No description provided for @allowNewRegistrations.
  ///
  /// In ar, this message translates to:
  /// **'السماح بتسجيل حسابات جديدة'**
  String get allowNewRegistrations;

  /// No description provided for @registrationEnabledDesc.
  ///
  /// In ar, this message translates to:
  /// **'التسجيل متاح حالياً للجميع'**
  String get registrationEnabledDesc;

  /// No description provided for @registrationDisabledDesc.
  ///
  /// In ar, this message translates to:
  /// **'التسجيل معطل حالياً (تظهر شاشة مغلق)'**
  String get registrationDisabledDesc;

  /// No description provided for @registrationOpenedSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم فتح التسجيل بنجاح 🎉'**
  String get registrationOpenedSuccess;

  /// No description provided for @registrationClosedSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم إغلاق التسجيل 🔒'**
  String get registrationClosedSuccess;

  /// No description provided for @contactSupportChannels.
  ///
  /// In ar, this message translates to:
  /// **'بيانات التواصل والدعم الفني'**
  String get contactSupportChannels;

  /// No description provided for @whatsappSupportNumber.
  ///
  /// In ar, this message translates to:
  /// **'رقم الواتساب للتواصل'**
  String get whatsappSupportNumber;

  /// No description provided for @whatsappHelperText.
  ///
  /// In ar, this message translates to:
  /// **'يرجى كتابة الرمز الدولي (مثال: 97339477742+)'**
  String get whatsappHelperText;

  /// No description provided for @whatsappRequired.
  ///
  /// In ar, this message translates to:
  /// **'حقل الرقم مطلوب'**
  String get whatsappRequired;

  /// No description provided for @saveWhatsappBtn.
  ///
  /// In ar, this message translates to:
  /// **'حفظ رقم الواتساب'**
  String get saveWhatsappBtn;

  /// No description provided for @whatsappUpdatedSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم تحديث رقم الواتساب بنجاح 🎉'**
  String get whatsappUpdatedSuccess;

  /// No description provided for @emailSupportLabel.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني للتواصل'**
  String get emailSupportLabel;

  /// No description provided for @emailRequired.
  ///
  /// In ar, this message translates to:
  /// **'حقل البريد الإلكتروني مطلوب'**
  String get emailRequired;

  /// No description provided for @emailInvalid.
  ///
  /// In ar, this message translates to:
  /// **'الرجاء إدخال بريد إلكتروني صحيح'**
  String get emailInvalid;

  /// No description provided for @saveEmailBtn.
  ///
  /// In ar, this message translates to:
  /// **'حفظ البريد الإلكتروني'**
  String get saveEmailBtn;

  /// No description provided for @emailUpdatedSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم تحديث البريد الإلكتروني بنجاح 🎉'**
  String get emailUpdatedSuccess;

  /// No description provided for @articleMaxCharacters.
  ///
  /// In ar, this message translates to:
  /// **'الحد الأقصى لحروف المقال'**
  String get articleMaxCharacters;

  /// No description provided for @articleMaxCharactersDesc.
  ///
  /// In ar, this message translates to:
  /// **'عدد الحروف الأقصى المسموح بكتابته في المقال الواحد'**
  String get articleMaxCharactersDesc;

  /// No description provided for @charactersCountLabel.
  ///
  /// In ar, this message translates to:
  /// **'عدد الحروف: {count}'**
  String charactersCountLabel(int count);

  /// No description provided for @saveLimitBtn.
  ///
  /// In ar, this message translates to:
  /// **'حفظ الحد الأقصى'**
  String get saveLimitBtn;

  /// No description provided for @articleLimitUpdated.
  ///
  /// In ar, this message translates to:
  /// **'تم تحديث الحد الأقصى لحروف المقال بنجاح 📝'**
  String get articleLimitUpdated;

  /// No description provided for @typoDictionary.
  ///
  /// In ar, this message translates to:
  /// **'قاموس الأخطاء الإملائية الشائعة'**
  String get typoDictionary;

  /// No description provided for @typoWordHint.
  ///
  /// In ar, this message translates to:
  /// **'الكلمة الخاطئة (مثال: هاذا)'**
  String get typoWordHint;

  /// No description provided for @correctedWordHint.
  ///
  /// In ar, this message translates to:
  /// **'التصحيح (مثال: هذا)'**
  String get correctedWordHint;

  /// No description provided for @addWordBtn.
  ///
  /// In ar, this message translates to:
  /// **'إضافة للقاموس'**
  String get addWordBtn;

  /// No description provided for @deleteWordConfirm.
  ///
  /// In ar, this message translates to:
  /// **'هل تريد حذف هذه الكلمة من القاموس الإملائي؟'**
  String get deleteWordConfirm;

  /// No description provided for @wordAddedSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم إضافة الكلمة بنجاح 🎉'**
  String get wordAddedSuccess;

  /// No description provided for @wordDeletedSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم حذف الكلمة بنجاح 🗑️'**
  String get wordDeletedSuccess;

  /// No description provided for @emptyDictionary.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد كلمات مضافة في القاموس بعد'**
  String get emptyDictionary;

  /// No description provided for @supportMessagesTitle.
  ///
  /// In ar, this message translates to:
  /// **'الرسائل الواردة'**
  String get supportMessagesTitle;

  /// No description provided for @noSupportMessages.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد رسائل واردة حالياً'**
  String get noSupportMessages;

  /// No description provided for @allMessagesTab.
  ///
  /// In ar, this message translates to:
  /// **'الكل'**
  String get allMessagesTab;

  /// No description provided for @unreadMessagesTab.
  ///
  /// In ar, this message translates to:
  /// **'غير المقروءة'**
  String get unreadMessagesTab;

  /// No description provided for @readMessagesTab.
  ///
  /// In ar, this message translates to:
  /// **'المقروءة'**
  String get readMessagesTab;

  /// No description provided for @messageFrom.
  ///
  /// In ar, this message translates to:
  /// **'من: {name}'**
  String messageFrom(String name);

  /// No description provided for @deleteMessageConfirm.
  ///
  /// In ar, this message translates to:
  /// **'هل تريد حذف رسالة {title} نهائياً؟'**
  String deleteMessageConfirm(String title);

  /// No description provided for @messageDeletedSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم حذف الرسالة بنجاح 🗑️'**
  String get messageDeletedSuccess;

  /// No description provided for @messageMarkedRead.
  ///
  /// In ar, this message translates to:
  /// **'تم تمييز الرسالة كمقروءة'**
  String get messageMarkedRead;

  /// No description provided for @messageMarkedUnread.
  ///
  /// In ar, this message translates to:
  /// **'تم تمييز الرسالة كغير مقروءة'**
  String get messageMarkedUnread;

  /// No description provided for @reportsScreenTitle.
  ///
  /// In ar, this message translates to:
  /// **'البلاغات والتقارير'**
  String get reportsScreenTitle;

  /// No description provided for @noReportsFound.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد بلاغات معلقة حالياً'**
  String get noReportsFound;

  /// No description provided for @reporterLabel.
  ///
  /// In ar, this message translates to:
  /// **'المُبلِّغ: {name}'**
  String reporterLabel(String name);

  /// No description provided for @reportTypeLabel.
  ///
  /// In ar, this message translates to:
  /// **'نوع البلاغ: {type}'**
  String reportTypeLabel(String type);

  /// No description provided for @reportReasonLabel.
  ///
  /// In ar, this message translates to:
  /// **'السبب: {reason}'**
  String reportReasonLabel(String reason);

  /// No description provided for @statusLabel.
  ///
  /// In ar, this message translates to:
  /// **'الحالة: {status}'**
  String statusLabel(String status);

  /// No description provided for @subjectDetailsTitle.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل المحتوى المُبلغ عنه'**
  String get subjectDetailsTitle;

  /// No description provided for @reportActionIgnore.
  ///
  /// In ar, this message translates to:
  /// **'تجاهل البلاغ'**
  String get reportActionIgnore;

  /// No description provided for @reportActionDelete.
  ///
  /// In ar, this message translates to:
  /// **'حذف المحتوى'**
  String get reportActionDelete;

  /// No description provided for @reportActionIgnoreConfirm.
  ///
  /// In ar, this message translates to:
  /// **'تجاهل بلاغ {reporter}'**
  String reportActionIgnoreConfirm(String reporter);

  /// No description provided for @reportActionIgnoreDesc.
  ///
  /// In ar, this message translates to:
  /// **'سيتم أرشفة البلاغ وحفظه دون تعديل المحتوى الأصلي.\nسيتم تسجيل تدوين اسم المشرف الحالي في حقل البلاغ.'**
  String get reportActionIgnoreDesc;

  /// No description provided for @reportActionDeleteConfirm.
  ///
  /// In ar, this message translates to:
  /// **'حذف نهائي للمحتوى'**
  String get reportActionDeleteConfirm;

  /// No description provided for @reportActionDeleteDesc.
  ///
  /// In ar, this message translates to:
  /// **'انتبه: هذا الإجراء نهائي ولا يمكن التراجع عنه!\nسيتم حذف هذا المحتوى بالكامل من السيرفر وتسجيل اسم المشرف الحالي كحاذف للمحتوى.'**
  String get reportActionDeleteDesc;

  /// No description provided for @reportResolvedSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم معالجة البلاغ بنجاح'**
  String get reportResolvedSuccess;

  /// No description provided for @reportDeleteSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم حذف المحتوى وحل البلاغ بنجاح'**
  String get reportDeleteSuccess;

  /// No description provided for @joinedSince.
  ///
  /// In ar, this message translates to:
  /// **'انضم منذ: {date}'**
  String joinedSince(String date);

  /// No description provided for @reportTypeUser.
  ///
  /// In ar, this message translates to:
  /// **'حساب مستخدم'**
  String get reportTypeUser;

  /// No description provided for @reportTypeAppointment.
  ///
  /// In ar, this message translates to:
  /// **'موعد جديد'**
  String get reportTypeAppointment;

  /// No description provided for @reportTypeArticle.
  ///
  /// In ar, this message translates to:
  /// **'مقال منشورة'**
  String get reportTypeArticle;

  /// No description provided for @allSafeAndClean.
  ///
  /// In ar, this message translates to:
  /// **'كل شيء يبدو آمناً ونظيفاً!'**
  String get allSafeAndClean;

  /// No description provided for @loadingReportedDetails.
  ///
  /// In ar, this message translates to:
  /// **'جاري تحميل تفاصيل المحتوى المُبلّغ عنه...'**
  String get loadingReportedDetails;

  /// No description provided for @reportedContentUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'⚠️ هذا المحتوى لم يعد متاحاً أو تم حذفه مسبقاً.'**
  String get reportedContentUnavailable;

  /// No description provided for @byModerator.
  ///
  /// In ar, this message translates to:
  /// **' بواسطة {name}'**
  String byModerator(String name);

  /// No description provided for @reportStatusResolved.
  ///
  /// In ar, this message translates to:
  /// **'✅ تم حسم هذا البلاغ وحذف المحتوى{byModerator}'**
  String reportStatusResolved(String byModerator);

  /// No description provided for @reportStatusIgnored.
  ///
  /// In ar, this message translates to:
  /// **'ℹ️ تم تجاهل هذا البلاغ وأرشفته{byModerator}'**
  String reportStatusIgnored(String byModerator);

  /// No description provided for @reportSubjectAppointmentDetails.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل الموعد المُبلّغ عنه:'**
  String get reportSubjectAppointmentDetails;

  /// No description provided for @reportSubjectArticleDetails.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل المقال المُبلّغ عنه:'**
  String get reportSubjectArticleDetails;

  /// No description provided for @reportDeleteFailed.
  ///
  /// In ar, this message translates to:
  /// **'⚠️ فشل في حذف المحتوى. قد يكون تم حذفه مسبقاً.'**
  String get reportDeleteFailed;

  /// No description provided for @appointmentNoTitle.
  ///
  /// In ar, this message translates to:
  /// **'موعد بدون عنوان'**
  String get appointmentNoTitle;

  /// No description provided for @articleNoTitle.
  ///
  /// In ar, this message translates to:
  /// **'مقال بدون عنوان'**
  String get articleNoTitle;

  /// No description provided for @anonymous.
  ///
  /// In ar, this message translates to:
  /// **'مجهول'**
  String get anonymous;

  /// No description provided for @limitsAndControls.
  ///
  /// In ar, this message translates to:
  /// **'الحدود والضوابط'**
  String get limitsAndControls;

  /// No description provided for @enterNewValue.
  ///
  /// In ar, this message translates to:
  /// **'أدخل القيمة الجديدة...'**
  String get enterNewValue;

  /// No description provided for @searchDictionaryHint.
  ///
  /// In ar, this message translates to:
  /// **'البحث في القاموس المخصص...'**
  String get searchDictionaryHint;

  /// No description provided for @typoWordHeader.
  ///
  /// In ar, this message translates to:
  /// **'الخطأ الشائع'**
  String get typoWordHeader;

  /// No description provided for @correctedWordHeader.
  ///
  /// In ar, this message translates to:
  /// **'التصحيح المعتمد'**
  String get correctedWordHeader;

  /// No description provided for @actionHeader.
  ///
  /// In ar, this message translates to:
  /// **'إجراء'**
  String get actionHeader;

  /// No description provided for @messageTypeInquiry.
  ///
  /// In ar, this message translates to:
  /// **'استفسار'**
  String get messageTypeInquiry;

  /// No description provided for @messageTypeSuggestion.
  ///
  /// In ar, this message translates to:
  /// **'اقتراح'**
  String get messageTypeSuggestion;

  /// No description provided for @messageTypeComplaint.
  ///
  /// In ar, this message translates to:
  /// **'شكوى'**
  String get messageTypeComplaint;

  /// No description provided for @messageTypeOther.
  ///
  /// In ar, this message translates to:
  /// **'أخرى'**
  String get messageTypeOther;

  /// No description provided for @messageStatusNew.
  ///
  /// In ar, this message translates to:
  /// **'جديدة'**
  String get messageStatusNew;

  /// No description provided for @messageStatusRead.
  ///
  /// In ar, this message translates to:
  /// **'مقروءة'**
  String get messageStatusRead;

  /// No description provided for @messageStatusReplied.
  ///
  /// In ar, this message translates to:
  /// **'تم الرد عليها'**
  String get messageStatusReplied;

  /// No description provided for @messageStatusClosed.
  ///
  /// In ar, this message translates to:
  /// **'مغلقة'**
  String get messageStatusClosed;

  /// No description provided for @unregisteredVisitor.
  ///
  /// In ar, this message translates to:
  /// **'زائر غير مسجل'**
  String get unregisteredVisitor;

  /// No description provided for @inboxCleanTitle.
  ///
  /// In ar, this message translates to:
  /// **'صندوق الوارد نظيف تماماً!'**
  String get inboxCleanTitle;

  /// No description provided for @inboxCleanDesc.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد رسائل واردة تطابق الفلاتر المحددة حالياً.'**
  String get inboxCleanDesc;

  /// No description provided for @unknown.
  ///
  /// In ar, this message translates to:
  /// **'غير معروف'**
  String get unknown;

  /// No description provided for @messageSenderHeader.
  ///
  /// In ar, this message translates to:
  /// **'مرسل الرسالة'**
  String get messageSenderHeader;

  /// No description provided for @updateMessageStatusTitle.
  ///
  /// In ar, this message translates to:
  /// **'تحديث حالة المراسلة'**
  String get updateMessageStatusTitle;

  /// No description provided for @messageStatusUpdateSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم تحديث حالة الرسالة بنجاح'**
  String get messageStatusUpdateSuccess;

  /// No description provided for @messageStatusUpdateFailed.
  ///
  /// In ar, this message translates to:
  /// **'فشل تحديث حالة الرسالة'**
  String get messageStatusUpdateFailed;

  /// No description provided for @errorArticleNotPublished.
  ///
  /// In ar, this message translates to:
  /// **'هذا المقال غير منشور حالياً.'**
  String get errorArticleNotPublished;

  /// No description provided for @adminPanelDesc.
  ///
  /// In ar, this message translates to:
  /// **'إدارة وتخصيص إعدادات النظام والتسجيل'**
  String get adminPanelDesc;

  /// No description provided for @all.
  ///
  /// In ar, this message translates to:
  /// **'الكل'**
  String get all;

  /// No description provided for @published.
  ///
  /// In ar, this message translates to:
  /// **'منشور'**
  String get published;

  /// No description provided for @draft.
  ///
  /// In ar, this message translates to:
  /// **'مسودة'**
  String get draft;

  /// No description provided for @archived.
  ///
  /// In ar, this message translates to:
  /// **'مؤرشف'**
  String get archived;

  /// No description provided for @deleted.
  ///
  /// In ar, this message translates to:
  /// **'محذوف'**
  String get deleted;

  /// No description provided for @no.
  ///
  /// In ar, this message translates to:
  /// **'لا'**
  String get no;

  /// No description provided for @leaveAppDialogTitle.
  ///
  /// In ar, this message translates to:
  /// **'مغادرة التطبيق'**
  String get leaveAppDialogTitle;

  /// No description provided for @leaveAppDialogMessage.
  ///
  /// In ar, this message translates to:
  /// **'هل تود مغادرة التطبيق للانتقال للرابط؟'**
  String get leaveAppDialogMessage;

  /// No description provided for @articleCategoriesHint.
  ///
  /// In ar, this message translates to:
  /// **'تصنيفات المقال... (اضغط للاختيار)'**
  String get articleCategoriesHint;

  /// No description provided for @articleCategoryTooltip.
  ///
  /// In ar, this message translates to:
  /// **'تصنيف المقال'**
  String get articleCategoryTooltip;

  /// No description provided for @articleCategoryLabel.
  ///
  /// In ar, this message translates to:
  /// **'تصنيف'**
  String get articleCategoryLabel;

  /// No description provided for @readingFont.
  ///
  /// In ar, this message translates to:
  /// **'خط القراءة: {font}'**
  String readingFont(String font);

  /// No description provided for @readingFontTooltip.
  ///
  /// In ar, this message translates to:
  /// **'تغيير خط القراءة'**
  String get readingFontTooltip;

  /// No description provided for @fullArticle.
  ///
  /// In ar, this message translates to:
  /// **'المقال كاملاً...'**
  String get fullArticle;

  /// No description provided for @noCategoryAddedYet.
  ///
  /// In ar, this message translates to:
  /// **'لم يتم إضافة تصنيف للمقال بعد'**
  String get noCategoryAddedYet;

  /// No description provided for @duplicate.
  ///
  /// In ar, this message translates to:
  /// **'مكرر'**
  String get duplicate;

  /// No description provided for @saved.
  ///
  /// In ar, this message translates to:
  /// **'المحفوظات'**
  String get saved;

  /// No description provided for @hideLocation.
  ///
  /// In ar, this message translates to:
  /// **'إخفاء معلومات المكان'**
  String get hideLocation;

  /// No description provided for @showLocation.
  ///
  /// In ar, this message translates to:
  /// **'إظهار معلومات المكان'**
  String get showLocation;

  /// No description provided for @upgradeAccountAndPermissions.
  ///
  /// In ar, this message translates to:
  /// **'ترقية الحساب والصلاحيات'**
  String get upgradeAccountAndPermissions;

  /// No description provided for @upgradeAccountSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'طلب الانضمام ككاتب معتمد أو مؤسسة وتفعيل ميزات الذكاء الاصطناعي'**
  String get upgradeAccountSubtitle;

  /// No description provided for @articlesSettingsTitle.
  ///
  /// In ar, this message translates to:
  /// **'المقالات'**
  String get articlesSettingsTitle;

  /// No description provided for @articlesSettingsSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'حماية مقالاتك وتعطيل نسخ المحتوى'**
  String get articlesSettingsSubtitle;

  /// No description provided for @membershipUpgradeRequests.
  ///
  /// In ar, this message translates to:
  /// **'طلبات ترقية العضوية'**
  String get membershipUpgradeRequests;

  /// No description provided for @reviewUpgradeRequestsSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'مراجعة طلبات الانضمام ككُتّاب معتمدين أو جهات رسمية'**
  String get reviewUpgradeRequestsSubtitle;

  /// No description provided for @sendSystemNotification.
  ///
  /// In ar, this message translates to:
  /// **'إرسال إشعار للنظام'**
  String get sendSystemNotification;

  /// No description provided for @broadcastNotificationSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'بث إشعار جماعي لجميع المستخدمين المسجلين في التطبيق'**
  String get broadcastNotificationSubtitle;

  /// No description provided for @newBadgeCount.
  ///
  /// In ar, this message translates to:
  /// **'{count} جديد'**
  String newBadgeCount(int count);

  /// No description provided for @noPendingUpgradeRequests.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد طلبات ترقية معلقة حالياً'**
  String get noPendingUpgradeRequests;

  /// No description provided for @allUpgradeRequestsReviewed.
  ///
  /// In ar, this message translates to:
  /// **'جميع طلبات الأعضاء تمت مراجعتها بالكامل.'**
  String get allUpgradeRequestsReviewed;

  /// No description provided for @leftAlignTooltip.
  ///
  /// In ar, this message translates to:
  /// **'محاذاة لليسار (تغيير الاتجاه)'**
  String get leftAlignTooltip;

  /// No description provided for @highlightTooltip.
  ///
  /// In ar, this message translates to:
  /// **'قلم التظليل'**
  String get highlightTooltip;

  /// No description provided for @quranVerseTooltip.
  ///
  /// In ar, this message translates to:
  /// **'تنسيق آية قرآنية'**
  String get quranVerseTooltip;

  /// No description provided for @spellCheckTooltip.
  ///
  /// In ar, this message translates to:
  /// **'تصحيح إملائي'**
  String get spellCheckTooltip;

  /// No description provided for @clearFormattingTooltip.
  ///
  /// In ar, this message translates to:
  /// **'مسح التنسيقات'**
  String get clearFormattingTooltip;

  /// No description provided for @searchReplaceTooltip.
  ///
  /// In ar, this message translates to:
  /// **'بحث واستبدال'**
  String get searchReplaceTooltip;

  /// No description provided for @removeCoverImageTooltip.
  ///
  /// In ar, this message translates to:
  /// **'إزالة الصورة'**
  String get removeCoverImageTooltip;

  /// No description provided for @addCoverImageTooltip.
  ///
  /// In ar, this message translates to:
  /// **'إضافة صورة غلاف'**
  String get addCoverImageTooltip;

  /// No description provided for @addAudioTooltip.
  ///
  /// In ar, this message translates to:
  /// **'إضافة ملف صوتي/واتساب 🎙️'**
  String get addAudioTooltip;

  /// No description provided for @insertImageTooltip.
  ///
  /// In ar, this message translates to:
  /// **'إدراج صورة في المقال 🖼️'**
  String get insertImageTooltip;

  /// No description provided for @undoTooltip.
  ///
  /// In ar, this message translates to:
  /// **'تراجع (Undo)'**
  String get undoTooltip;

  /// No description provided for @redoTooltip.
  ///
  /// In ar, this message translates to:
  /// **'إعادة/تقدم (Redo)'**
  String get redoTooltip;

  /// No description provided for @pasteFromClipboardTooltip.
  ///
  /// In ar, this message translates to:
  /// **'لصق من الحافظة'**
  String get pasteFromClipboardTooltip;

  /// No description provided for @commentsCount.
  ///
  /// In ar, this message translates to:
  /// **'عدد التعليقات: {count}'**
  String commentsCount(int count);

  /// No description provided for @browseApp.
  ///
  /// In ar, this message translates to:
  /// **'تصفح تطبيق سجلي'**
  String get browseApp;

  /// No description provided for @publishedDate.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ النشر: {date}'**
  String publishedDate(String date);

  /// No description provided for @accountUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'هذا الحساب غير متاح حالياً'**
  String get accountUnavailable;

  /// No description provided for @newProfileVisitTitle.
  ///
  /// In ar, this message translates to:
  /// **'زيارة جديدة'**
  String get newProfileVisitTitle;

  /// No description provided for @newProfileVisitMessage.
  ///
  /// In ar, this message translates to:
  /// **'قام أحد الأعضاء بزيارة ملفك الشخصي'**
  String get newProfileVisitMessage;

  /// No description provided for @newArticleVisitTitle.
  ///
  /// In ar, this message translates to:
  /// **'زيارة جديدة لمقالك'**
  String get newArticleVisitTitle;

  /// No description provided for @newArticleVisitMessage.
  ///
  /// In ar, this message translates to:
  /// **'قام أحد القراء بزيارة وقراءة مقالك'**
  String get newArticleVisitMessage;

  /// No description provided for @unfollowedTitle.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الاعتماد'**
  String get unfollowedTitle;

  /// No description provided for @unfollowedMessage.
  ///
  /// In ar, this message translates to:
  /// **'{name} قام بإلغاء اعتمادك'**
  String unfollowedMessage(String name);

  /// No description provided for @acceptAndUpgrade.
  ///
  /// In ar, this message translates to:
  /// **'قبول وترقية'**
  String get acceptAndUpgrade;

  /// No description provided for @rejectRequest.
  ///
  /// In ar, this message translates to:
  /// **'رفض الطلب'**
  String get rejectRequest;

  /// No description provided for @acceptUpgradeConfirm.
  ///
  /// In ar, this message translates to:
  /// **'هل أنت متأكد من رغبتك في قبول هذا الطلب؟'**
  String get acceptUpgradeConfirm;

  /// No description provided for @rejectUpgradeConfirm.
  ///
  /// In ar, this message translates to:
  /// **'هل أنت متأكد من رغبتك في رفض هذا الطلب؟'**
  String get rejectUpgradeConfirm;

  /// No description provided for @upgradeSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم ترقية الطلب بنجاح وتحديث الرول'**
  String get upgradeSuccess;

  /// No description provided for @rejectSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم رفض الطلب بنجاح'**
  String get rejectSuccess;

  /// No description provided for @upgradeError.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ أثناء معالجة الطلب'**
  String get upgradeError;

  /// No description provided for @writeRejectReason.
  ///
  /// In ar, this message translates to:
  /// **'الرجاء كتابة سبب رفض الطلب'**
  String get writeRejectReason;

  /// No description provided for @rejectReasonHint.
  ///
  /// In ar, this message translates to:
  /// **'سبب الرفض وتوجيه العضو (مطلوب)...'**
  String get rejectReasonHint;

  /// No description provided for @acceptNoteHint.
  ///
  /// In ar, this message translates to:
  /// **'تعليق الإدارة أو الترحيب بالعضو (اختياري)...'**
  String get acceptNoteHint;

  /// No description provided for @systemArticlesTitle.
  ///
  /// In ar, this message translates to:
  /// **'مقالات ونشرات النظام'**
  String get systemArticlesTitle;

  /// No description provided for @noSystemArticles.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد نشرات أو مقالات عامة حالياً.'**
  String get noSystemArticles;

  /// No description provided for @closeButton.
  ///
  /// In ar, this message translates to:
  /// **'إغلاق'**
  String get closeButton;

  /// No description provided for @cancelButton.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get cancelButton;

  /// No description provided for @roleWriter.
  ///
  /// In ar, this message translates to:
  /// **'كاتب معتمد'**
  String get roleWriter;

  /// No description provided for @roleOrganization.
  ///
  /// In ar, this message translates to:
  /// **'مؤسسة / جهة'**
  String get roleOrganization;

  /// No description provided for @upgradeTo.
  ///
  /// In ar, this message translates to:
  /// **'ترقية لـ: {role}'**
  String upgradeTo(String role);

  /// No description provided for @applyReasonLabel.
  ///
  /// In ar, this message translates to:
  /// **'رسالة ومبررات التقديم:'**
  String get applyReasonLabel;

  /// No description provided for @requestDate.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ الطلب: {date} | الساعة: {time}'**
  String requestDate(String date, String time);

  /// No description provided for @unknownMember.
  ///
  /// In ar, this message translates to:
  /// **'عضو غير معروف'**
  String get unknownMember;

  /// No description provided for @likesTitle.
  ///
  /// In ar, this message translates to:
  /// **'إعجابات'**
  String get likesTitle;

  /// No description provided for @commentsTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعليقات'**
  String get commentsTitle;

  /// No description provided for @likedYourArticle.
  ///
  /// In ar, this message translates to:
  /// **'أعجب {name} بمقالك'**
  String likedYourArticle(String name);

  /// No description provided for @commentedOnYourArticle.
  ///
  /// In ar, this message translates to:
  /// **'علق {name} على مقالك'**
  String commentedOnYourArticle(String name);

  /// No description provided for @visitedYourProfile.
  ///
  /// In ar, this message translates to:
  /// **'زار {name} ملفك الشخصي'**
  String visitedYourProfile(String name);

  /// No description provided for @invitationsAwaitingResponse.
  ///
  /// In ar, this message translates to:
  /// **'دعوات بانتظار ردك 📥'**
  String get invitationsAwaitingResponse;

  /// No description provided for @notificationsAndActivity.
  ///
  /// In ar, this message translates to:
  /// **'صندوق الإشعارات والأنشطة 🔔'**
  String get notificationsAndActivity;

  /// No description provided for @mutualAccreditationTitle.
  ///
  /// In ar, this message translates to:
  /// **'اعتماد متبادل'**
  String get mutualAccreditationTitle;

  /// No description provided for @mutualAccreditedYou.
  ///
  /// In ar, this message translates to:
  /// **'قام {name} باعتمادك المتبادل'**
  String mutualAccreditedYou(String name);

  /// No description provided for @readerReadYourArticle.
  ///
  /// In ar, this message translates to:
  /// **'قام {name} بقراءة مقالك'**
  String readerReadYourArticle(String name);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
