import 'package:flutter_test/flutter_test.dart';
import 'package:sijilli/features/notifications/providers/notification_provider.dart';

void main() {
  group('Notification Localizer Coverage Tests (اختبارات تغطية ترجمة الإشعارات)', () {
    test('يجب أن تترجم جميع عناوين ورسائل الإشعارات إلى اللغة الإنجليزية عند تنشيط الإنجليزية', () {
      final testCases = [
        {'title': 'اعتماد جديد', 'msg': 'حسين قام باعتمادك'},
        {'title': 'طلب اعتماد', 'msg': 'علي يطلب اعتمادك'},
        {'title': 'زيارة جديدة للملف الشخصي', 'msg': 'قام أحمد بتصفح ملفك'},
        {'title': 'دعوة جديدة', 'msg': 'حسين دعاك لحضور موعد'},
        {'title': 'إلغاء موعد', 'msg': 'تم إلغاء الموعد'},
        {'title': 'تذكير موعد', 'msg': 'تذكير بموعد قريب'},
        {'title': 'تحديث موعد', 'msg': 'تم تعديل تفاصيل الموعد'},
        {'title': 'قبول دعوة', 'msg': 'وافق علي على الدعوة'},
        {'title': 'رفض دعوة', 'msg': 'اعتذر علي عن الدعوة'},
        {'title': 'إعجابات', 'msg': 'أعجب علي بمقالك'},
        {'title': 'تعليقات', 'msg': 'علق علي على مقالك'},
      ];

      final List<String> unhandledTitles = [];

      for (var item in testCases) {
        final result = NotificationLocalizer.localize(item['title']!, item['msg']!, 'en');
        final title = result['title']!;

        final hasArabicTitle = RegExp(r'[\u0600-\u06FF]').hasMatch(title);
        if (hasArabicTitle) {
          unhandledTitles.add('${item['title']} -> $title');
        }
      }

      expect(unhandledTitles, isEmpty);
    });

    test('يجب أن تترجم الإشعارات الواردة باللغة الإنجليزية إلى العربية عند تنشيط العربية', () {
      final englishCases = [
        {'title': 'Appointment Cancelled', 'msg': 'The appointment was cancelled by the organizer'},
        {'title': 'New Appointment Invitation', 'msg': 'You have received a new appointment invitation'},
        {'title': 'Appointment Reminder', 'msg': 'Upcoming appointment reminder'},
        {'title': 'Appointment Confirmed', 'msg': 'The appointment has been confirmed'},
      ];

      for (var item in englishCases) {
        final result = NotificationLocalizer.localize(item['title']!, item['msg']!, 'ar');
        final title = result['title']!;
        
        final hasEnglishTitle = RegExp(r'[a-zA-Z]').hasMatch(title);
        expect(hasEnglishTitle, isFalse, reason: 'الإشعار $title لا يزال باللغة الإنجليزية في التنسيق العربي!');
      }
    });
  });
}
