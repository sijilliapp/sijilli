import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Localization Coverage Tests (اختبار التغطية التلقائية لترجمة العبارات)', () {
    test('يجب أن تحتوي جميع المفاتيح العربية في app_ar.arb على ترجمة مقابلة في app_en.arb', () {
      final arFile = File('lib/l10n/app_ar.arb');
      final enFile = File('lib/l10n/app_en.arb');

      expect(arFile.existsSync(), isTrue, reason: 'ملف الترجمة العربي app_ar.arb غير موجود');
      expect(enFile.existsSync(), isTrue, reason: 'ملف الترجمة الإنجليزي app_en.arb غير موجود');

      final Map<String, dynamic> arJson = jsonDecode(arFile.readAsStringSync());
      final Map<String, dynamic> enJson = jsonDecode(enFile.readAsStringSync());

      final List<String> missingKeys = [];
      final List<String> emptyKeys = [];

      arJson.forEach((key, value) {
        // تجاهل مفاتيح التوصيف والـ Metadata في ARB التي تبدأ بـ @
        if (key.startsWith('@')) return;

        if (!enJson.containsKey(key)) {
          missingKeys.add(key);
        } else {
          final enValue = enJson[key]?.toString().trim() ?? '';
          if (enValue.isEmpty) {
            emptyKeys.add(key);
          }
        }
      });

      if (missingKeys.isNotEmpty) {
        print('❌ المفاتيح الموجودة في العربية وغير المترجمة إلى الإنجليزية (${missingKeys.length}):');
        for (var k in missingKeys) {
          print('   - $k: "${arJson[k]}"');
        }
      }

      if (emptyKeys.isNotEmpty) {
        print('⚠️ المفاتيح الموجودة في الإنجليزية ولكن ترجمتها فارغة (${emptyKeys.length}):');
        for (var k in emptyKeys) {
          print('   - $k');
        }
      }

      expect(
        missingKeys, 
        isEmpty, 
        reason: 'يوجد ${missingKeys.length} عبارة باللغة العربية تفتقد للترجمة الإنجليزية!'
      );

      expect(
        emptyKeys, 
        isEmpty, 
        reason: 'يوجد ${emptyKeys.length} عبارة مترجمة بقيمة فارغة في الإنجليزية!'
      );
    });
  });
}
