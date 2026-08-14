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
        final message = result['message']!;

        // إذا عادت العبارة تحتوي على أحرف عربية في اللغة الإنجليزية يعتبر العنوان غير مغطى بالترجمة
        final hasArabicTitle = RegExp(r'[\u0600-\u06FF]').hasMatch(title);
        if (hasArabicTitle) {
          unhandledTitles.add('${item['title']} -> $title');
        }
      }

      if (unhandledTitles.isNotEmpty) {
        print('❌ الإشعارات التي لم تُترجم للإنجليزية وتظهر بالعربية (${unhandledTitles.length}):');
        for (var t in unhandledTitles) {
          print('   - $t');
        }
      }

      expect(
        unhandledTitles, 
        isEmpty, 
        reason: 'يوجد إشعارات لم يتم تغطية ترجمتها للإنجليزية وتظهر بالعربية!'
      );
    });
  });
}
