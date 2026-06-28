import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sijilli/features/auth/providers/auth_provider.dart';
import 'package:sijilli/features/appointments/providers/appointment_provider.dart';
import 'package:sijilli/features/articles/providers/article_provider.dart';
import 'package:sijilli/features/home/screens/home_screen.dart';
import 'package:sijilli/features/search/providers/search_provider.dart';
import 'package:sijilli/core/providers/settings_provider.dart';
import 'package:sijilli/core/providers/theme_provider.dart';
import 'package:sijilli/models/user.dart';
import 'package:sijilli/models/appointment.dart';
import 'package:sijilli/models/article.dart';
import 'package:sijilli/l10n/app_localizations.dart';
import 'package:sijilli/features/notifications/providers/notification_provider.dart';
import 'package:sijilli/core/local/local_db_service.dart';

import 'package:pocketbase/pocketbase.dart';
import '../lib/core/services/pocketbase_client.dart';
import 'package:sijilli/core/services/pocketbase_client.dart' as pkg;

class MockAuthProvider extends AuthProvider {
  @override
  UserModel? get user => UserModel(
    id: '1', 
    name: 'كاتب', 
    username: 'writer', 
    email: 'writer@example.com',
    created: DateTime.now(),
    updated: DateTime.now(),
    joiningDate: DateTime.now(),
  );

  @override
  bool get isAuthenticated => true;

  @override
  Future<void> init() async {}
}

class MockAppointmentProvider extends AppointmentProvider {
  final List<Appointment> _mockAppts;
  MockAppointmentProvider(this._mockAppts);

  @override
  List<Appointment> get appointments => _mockAppts;

  @override
  Future<void> fetchAppointments() async {}
}

class MockArticleProvider extends ArticleProvider {
  final List<Article> _mockArticles;
  MockArticleProvider(this._mockArticles);

  @override
  List<Article> get articles => _mockArticles;

  @override
  List<Article> getUserArticles(String userId) => _mockArticles;

  @override
  Future<void> refreshArticles() async {}
}

class MockSearchProvider extends SearchProvider {
  @override
  Future<void> init() async {}
}

class MockSettingsProvider extends SettingsProvider {
  @override
  bool get isMagneticScrollEnabled => false;
}

class MockThemeProvider extends ThemeProvider {
  @override
  bool get isDark => false;
}

class MockNotificationProvider extends NotificationProvider {
  @override
  int get pendingFollowsCount => 0;
  @override
  int get unreadNotificationsCount => 0;
  @override
  Future<void> fetchNotifications(String userId) async {}
}

class MockLocalDbService extends LocalDbService {
  final List<Article> mockArticles;
  final List<Appointment> mockAppointments;

  MockLocalDbService(this.mockArticles, this.mockAppointments) : super.empty();

  @override
  Future<List<Article>> getArticles() async => mockArticles;

  @override
  Future<List<Appointment>> getAppointments() async => mockAppointments;
}

void main() {
  testWidgets('HomeScreen defaults to Articles tab when no upcoming appointments and articles present', (WidgetTester tester) async {
    PocketBaseClient.instance.pb = PocketBase('http://localhost');
    pkg.PocketBaseClient.instance.pb = PocketBase('http://localhost');

    final mockArticlesList = [
      Article(
        id: 'a1',
        authorId: '1',
        text: 'مقال تجريبي',
        postStatus: PostStatus.published,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];
    final mockAppointmentsList = <Appointment>[];
    LocalDbService.instance = MockLocalDbService(mockArticlesList, mockAppointmentsList);

    final mockAuth = MockAuthProvider();
    final mockAppt = MockAppointmentProvider([]);
    final mockArticle = MockArticleProvider([
      Article(
        id: 'a1',
        authorId: '1',
        text: 'مقال تجريبي',
        postStatus: PostStatus.published,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ]);
    final mockSearch = MockSearchProvider();
    final mockSettings = MockSettingsProvider();
    final mockTheme = MockThemeProvider();
    final mockNotif = MockNotificationProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
          ChangeNotifierProvider<AppointmentProvider>.value(value: mockAppt),
          ChangeNotifierProvider<ArticleProvider>.value(value: mockArticle),
          ChangeNotifierProvider<SearchProvider>.value(value: mockSearch),
          ChangeNotifierProvider<SettingsProvider>.value(value: mockSettings),
          ChangeNotifierProvider<ThemeProvider>.value(value: mockTheme),
          ChangeNotifierProvider<NotificationProvider>.value(value: mockNotif),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('ar'),
          home: HomeScreen(),
        ),
      ),
    );

    // Wait for the post frame callback delayed check
    await tester.pump(const Duration(milliseconds: 150));

    final tabControllerFinder = find.byType(TabBarView);
    expect(tabControllerFinder, findsOneWidget);
    final TabBarView tabBarView = tester.widget(tabControllerFinder);
    expect(tabBarView.controller?.index, 1); // Articles tab (index 1) selected

    // Clean up remaining timers and dispose providers
    await tester.pump(const Duration(seconds: 1));
    mockAppt.dispose();
  });
}
