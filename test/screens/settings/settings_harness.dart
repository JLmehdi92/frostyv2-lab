import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart' show Observable, ObservableList, runInAction;
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/models/user.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/stores/user_store.dart';
import 'package:onset/theme.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

class MockUserStore extends Mock implements UserStore {}

/// The viewer of the settings tests.
final testViewer = UserTwitch(
  '7',
  'jltomy',
  'JLTomy',
  '',
  createdAt: DateTime(2019, 3, 14, 12),
);

/// An [AuthStore] whose state the test sets: logged in or not, a
/// connection problem, the blocked users.
class FakeAuthStore extends Mock implements AuthStore {
  FakeAuthStore({bool loggedIn = false, String? error})
    : _loggedIn = Observable(loggedIn),
      _error = Observable(error) {
    when(() => _user.details).thenAnswer((_) => _details.value);
    when(() => _user.blockedUsers).thenReturn(blocked);
    when(() => _user.refreshBlockedUsers()).thenAnswer((_) async {});
    when(() => _user.unblock(targetId: any(named: 'targetId'))).thenAnswer((
      invocation,
    ) async {
      final id = invocation.namedArguments[#targetId] as String;
      runInAction(() => blocked.removeWhere((user) => user.userId == id));
    });
    when(() => logout()).thenAnswer((_) async => setLoggedIn(false));
    when(() => init()).thenAnswer((_) async {});
    when(() => login(token: any(named: 'token'))).thenAnswer((_) async {});
    when(
      () => login(
        token: any(named: 'token'),
        acceptAnyApp: any(named: 'acceptAnyApp'),
      ),
    ).thenAnswer((_) async {});
  }

  final Observable<bool> _loggedIn;
  final Observable<String?> _error;
  late final _details = Observable<UserTwitch?>(testViewer);
  final _user = MockUserStore();
  final blocked = ObservableList<UserBlockedTwitch>();

  @override
  bool get isLoggedIn => _loggedIn.value;

  @override
  String? get error => _error.value;

  @override
  UserStore get user => _user;

  @override
  String? get twitchWebToken => null;

  @override
  bool get webSessionExpired => false;

  void setLoggedIn(bool value) => runInAction(() => _loggedIn.value = value);

  void setError(String? value) => runInAction(() => _error.value = value);
}

/// Mocks what the settings read from the platform: preferences, the
/// app's version.
void mockSettingsPlatform() {
  SharedPreferences.setMockInitialValues({});
  PackageInfo.setMockInitialValues(
    appName: 'ONSET',
    packageName: 'onset',
    version: '5.0.5',
    buildNumber: '68',
    buildSignature: '',
  );
}

/// Sizes the test window like [size] (dp at 1×) for the test.
void useWindow(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Pumps [child] in an app with the settings' providers and theme.
Future<void> pumpSettings(
  WidgetTester tester,
  Widget child, {
  required SettingsStore settings,
  required AuthStore auth,
  Size size = const Size(390, 844),
  ThemeMode mode = ThemeMode.dark,
  bool reduceMotion = false,
  List<NavigatorObserver> observers = const [],
}) async {
  useWindow(tester, size);
  final themes = OnsetThemes(colorSchemeSeed: OnsetTokens.accent);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<AuthStore>.value(value: auth),
        Provider<SettingsStore>.value(value: settings),
      ],
      child: MaterialApp(
        theme: themes.light,
        darkTheme: themes.dark,
        themeMode: mode,
        navigatorObservers: observers,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: reduceMotion),
          child: child!,
        ),
        home: Scaffold(body: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Scrolls [finder] into view (built yet or not: lists build lazily, in
/// [scrollable], the first one by default) and taps it.
Future<void> tapVisible(
  WidgetTester tester,
  Finder finder, {
  Finder? scrollable,
}) async {
  if (finder.evaluate().isEmpty) {
    final view = scrollable ?? find.byType(Scrollable).first;
    try {
      await tester.scrollUntilVisible(finder, 200, scrollable: view);
    } on StateError {
      // Above, then.
      await tester.scrollUntilVisible(finder, -200, scrollable: view);
    }
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}
