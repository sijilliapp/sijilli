import 'package:flutter_test/flutter_test.dart';
import 'package:sijilli/models/user.dart';

void main() {
  group('User Permissions & Social Links Tests (اختبارات الروابط الاجتماعية والصلاحيات)', () {
    final now = DateTime.now();

    test('تفكيك الروابط الاجتماعية المتعددة المفصولة بعلامة Pipe | بشكل صحيح', () {
      final user = UserModel(
        id: 'u_100',
        name: 'مستخدم تجريبي',
        username: 'sijilli_user',
        email: 'test@sijilli.com',
        created: now,
        updated: now,
        joiningDate: now,
        socialLink: 'https://youtube.com/@channel | https://instagram.com/user | https://wa.me/966500000000',
      );

      final links = user.socialLinks;

      expect(links.length, equals(3));
      expect(links[0], equals('https://youtube.com/@channel'));
      expect(links[1], equals('https://instagram.com/user'));
      expect(links[2], equals('https://wa.me/966500000000'));
    });

    test('المستخدم بدون روابط يجب أن يعيد قائمة فارغة', () {
      final user = UserModel(
        id: 'u_101',
        name: 'بدون روابط',
        username: 'empty_social',
        email: 'empty@sijilli.com',
        created: now,
        updated: now,
        joiningDate: now,
        socialLink: '',
      );

      expect(user.socialLinks, isEmpty);
    });

    test('فحص رتب المستخدم والأدوار الهيكلية', () {
      final adminUser = UserModel(
        id: 'admin_1',
        name: 'مشرف',
        username: 'admin',
        email: 'admin@sijilli.com',
        created: now,
        updated: now,
        joiningDate: now,
        role: 'admin',
      );

      final regularUser = UserModel(
        id: 'user_1',
        name: 'مستخدم عادي',
        username: 'regular',
        email: 'user@sijilli.com',
        created: now,
        updated: now,
        joiningDate: now,
        role: 'user',
      );

      expect(adminUser.isAdmin, isTrue);
      expect(regularUser.isAdmin, isFalse);
    });
  });
}
