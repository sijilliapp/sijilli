import 'package:flutter_test/flutter_test.dart';
import 'package:sijilli/utils/arabic_search_utils.dart';

void main() {
  group('Arabic Search Utils Tests', () {
    test('normalizeArabicText should normalize alif variations', () {
      expect(ArabicSearchUtils.normalizeArabicText('أحمد'), equals('احمد'));
      expect(ArabicSearchUtils.normalizeArabicText('إبراهيم'), equals('ابراهيم'));
      expect(ArabicSearchUtils.normalizeArabicText('آدم'), equals('ادم'));
      expect(ArabicSearchUtils.normalizeArabicText('مؤمن'), equals('مومن'));
    });

    test('normalizeArabicText should normalize ya variations', () {
      expect(ArabicSearchUtils.normalizeArabicText('على'), equals('علي'));
      expect(ArabicSearchUtils.normalizeArabicText('يحيى'), equals('يحيي'));
      expect(ArabicSearchUtils.normalizeArabicText('مصطفى'), equals('مصطفي'));
    });

    test('normalizeArabicText should normalize ha and ta marbuta', () {
      expect(ArabicSearchUtils.normalizeArabicText('فاطمة'), equals('فاطمه'));
      expect(ArabicSearchUtils.normalizeArabicText('عائشة'), equals('عايشه'));
    });

    test('normalizeArabicText should normalize titles', () {
      expect(ArabicSearchUtils.normalizeArabicText('الشيخ أحمد'), equals('شيخ احمد'));
      expect(ArabicSearchUtils.normalizeArabicText('السيد محمد'), equals('سيد محمد'));
      expect(ArabicSearchUtils.normalizeArabicText('الدكتور علي'), equals('دكتور علي'));
    });

    test('matchesArabicSearch should find matches with normalization', () {
      expect(ArabicSearchUtils.matchesArabicSearch('أحمد محمد', 'احمد'), isTrue);
      expect(ArabicSearchUtils.matchesArabicSearch('فاطمة علي', 'فاطمه'), isTrue);
      expect(ArabicSearchUtils.matchesArabicSearch('الشيخ يوسف', 'شيخ'), isTrue);
      expect(ArabicSearchUtils.matchesArabicSearch('مصطفى', 'مصطفي'), isTrue);
    });

    test('searchInUserFields should search in multiple fields', () {
      expect(
        ArabicSearchUtils.searchInUserFields('أحمد محمد', 'ahmed_mohamed', 'مطور تطبيقات', 'احمد'),
        isTrue,
      );
      expect(
        ArabicSearchUtils.searchInUserFields('فاطمة علي', 'fatima_ali', 'مصممة جرافيك', 'fatima'),
        isTrue,
      );
      expect(
        ArabicSearchUtils.searchInUserFields('محمد السعيد', 'mohamed_said', 'مهندس برمجيات', 'مهندس'),
        isTrue,
      );
      expect(
        ArabicSearchUtils.searchInUserFields('نور الهدى', 'nour_alhuda', 'طالبة طب', 'طالبه'),
        isTrue,
      );
    });

    test('searchInUserFields should return false for non-matching queries', () {
      expect(
        ArabicSearchUtils.searchInUserFields('أحمد محمد', 'ahmed_mohamed', 'مطور تطبيقات', 'سارة'),
        isFalse,
      );
      expect(
        ArabicSearchUtils.searchInUserFields('فاطمة علي', 'fatima_ali', 'مصممة جرافيك', 'xyz'),
        isFalse,
      );
    });

    test('should handle empty and null inputs gracefully', () {
      expect(ArabicSearchUtils.normalizeArabicText(''), equals(''));
      expect(ArabicSearchUtils.matchesArabicSearch('', 'test'), isFalse);
      expect(ArabicSearchUtils.matchesArabicSearch('test', ''), isTrue);
      expect(
        ArabicSearchUtils.searchInUserFields('أحمد', 'ahmed', null, 'احمد'),
        isTrue,
      );
    });

    test('should handle complex Arabic text with diacritics', () {
      expect(
        ArabicSearchUtils.normalizeArabicText('مُحَمَّدٌ'),
        equals('محمد'),
      );
      expect(
        ArabicSearchUtils.matchesArabicSearch('مُحَمَّدٌ الأَمِينُ', 'محمد الامين'),
        isTrue,
      );
    });
  });
}
