import 'package:clock/clock.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/base_api_client.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/apis/twitch_auth_interceptor.dart';
import 'package:onset/apis/unauthorized_interceptor.dart';
import 'package:onset/constants.dart';
import 'package:onset/main.dart';
import 'package:onset/models/user.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/services/twitch_web_token_service.dart';
import 'package:onset/widgets/onset_alert_dialog.dart';

import '../../../helpers/fake_twitch_http.dart';

class MockWebTokenService extends Mock implements TwitchWebTokenService {}

class MockTwitchApi extends Mock implements TwitchApi {}

/// A logged-out viewer's app token comes from the token proxy, minted for a
/// second Twitch application that no user ever authorizes, and is used with
/// that application's Client-Id. When the proxy (or the network) is down,
/// or the token is revoked, the app still starts, logging in still works,
/// and a logged-out viewer is never asked to log in by a Helix 401.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The login app's client id: the build's (empty in tests).
  const app = clientId;
  const publicApp = 'publicappclientid0123456789ab';
  const appToken = 'abcdefghijklmnopqrstuvwxyz0123';
  const appToken2 = 'zyxwvutsrqponmlkjihgfedcba9876';
  const userToken = 'usertoken0123456789abcdefghij';
  const proxy = 'https://onset-token.example.workers.dev';

  late FakeTwitchHttp twitch;
  late Dio dio;
  late AuthStore store;
  late MockWebTokenService cookies;

  int proxyCalls() =>
      twitch.requests.where((r) => r.uri.host.endsWith('workers.dev')).length;

  int validations(String token) => twitch.requests
      .where(
        (r) =>
            r.uri.path == '/oauth2/validate' &&
            '${r.headers['Authorization']}'.endsWith(token),
      )
      .length;

  void proxyDown() =>
      twitch.proxy = (status: 502, body: {'error': 'unavailable'});

  void proxyHands(String token, [String client = publicApp]) => twitch.proxy = (
    status: 200,
    body: {'access_token': token, 'expires_in': 5000000, 'client_id': client},
  );

  Future<Object?> helix(String path) async {
    try {
      await dio.get<Object?>('https://api.twitch.tv/helix$path');
    } on DioException catch (e) {
      return e.response?.statusCode;
    }
    return 200;
  }

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    twitch = FakeTwitchHttp({
      appToken: (clientId: publicApp, userId: ''),
      appToken2: (clientId: publicApp, userId: ''),
      userToken: (clientId: app, userId: '7'),
    });
    dio = Dio()..httpClientAdapter = twitch;
    cookies = MockWebTokenService();
    when(() => cookies.readAuthToken()).thenAnswer((_) async => null);
    when(() => cookies.clearCookies()).thenAnswer((_) async {});
    store = AuthStore(
      twitchApi: TwitchApi(dio, tokenProxyUrl: proxy),
      webTokenService: cookies,
      isAndroid: false,
    );
    dio.interceptors
      ..add(TwitchAuthInterceptor(store))
      ..add(UnauthorizedInterceptor(store));
  });

  group('launch', () {
    test('the proxy down: logged out, no error, no token', () async {
      proxyDown();

      await store.init();

      expect(store.isLoggedIn, isFalse);
      expect(store.error, isNull, reason: 'the login button must stay');
      expect(store.token, isNull);
      expect(proxyCalls(), 1);
    });

    test('no token: no "Bearer null" is sent', () async {
      proxyDown();
      await store.init();

      expect(store.headersTwitch.containsKey('Authorization'), isFalse);
      expect(store.headersTwitch.containsKey('Client-Id'), isTrue);
    });

    test("the proxy's token is checked with Twitch and used with its own "
        "app's Client-Id", () async {
      proxyHands(appToken);

      await store.init();

      expect(validations(appToken), 1);
      expect(store.token, appToken);
      expect(store.headersTwitch['Client-Id'], publicApp);
      expect(await helix('/chat/emotes/global'), 200);
      const storage = FlutterSecureStorage();
      expect(await storage.read(key: 'default_token'), appToken);
      expect(await storage.read(key: 'default_token_client_id'), publicApp);
    });

    test('a token from the proxy that Twitch refuses is not used', () async {
      proxyHands('revokedtoken0123456789abcdefg');

      await store.init();

      expect(store.token, isNull);
      expect(store.error, isNull);
    });

    test('a token of the login application is refused: the Worker was '
        'set up with the wrong credentials', () async {
      twitch.tokens['loginapptoken0123456789abcdef'] = (
        clientId: app,
        userId: '',
      );
      proxyHands('loginapptoken0123456789abcdef');

      await store.init();

      expect(store.token, isNull);
      expect(
        await const FlutterSecureStorage().read(key: 'default_token'),
        isNull,
      );
    });

    test("a user's token from the proxy is refused", () async {
      twitch.tokens['someusertoken0123456789abcdef'] = (
        clientId: publicApp,
        userId: '42',
      );
      proxyHands('someusertoken0123456789abcdef');

      await store.init();

      expect(store.token, isNull);
    });

    test('a token of another app than the proxy says is not used', () async {
      proxyHands(appToken, 'someotherappid0123456789abcd');

      await store.init();

      expect(store.token, isNull);
    });

    test('a stored token and its app are used, the proxy not asked', () async {
      FlutterSecureStorage.setMockInitialValues({
        'default_token': appToken,
        'default_token_client_id': publicApp,
      });

      await store.init();

      expect(store.token, appToken);
      expect(store.headersTwitch['Client-Id'], publicApp);
      expect(proxyCalls(), 0);
    });

    test('a stored token Twitch refuses is replaced', () async {
      FlutterSecureStorage.setMockInitialValues({
        'default_token': 'revokedtoken0123456789abcdefg',
        'default_token_client_id': publicApp,
      });
      proxyHands(appToken2);

      await store.init();

      expect(store.token, appToken2);
    });

    test('a stored token Twitch refuses is dropped when the proxy is '
        'down', () async {
      FlutterSecureStorage.setMockInitialValues({
        'default_token': 'revokedtoken0123456789abcdefg',
        'default_token_client_id': publicApp,
      });
      proxyDown();

      await store.init();

      expect(store.token, isNull);
      expect(store.error, isNull);
    });

    test('nothing sent anywhere names a client secret', () async {
      proxyHands(appToken);
      await store.init();

      for (final request in twitch.requests) {
        expect(
          '${request.uri} ${request.headers} ${request.data}',
          isNot(contains('secret')),
        );
      }
    });
  });

  testWidgets('Helix while logged out without a token: no dialog, and the '
      'token is asked for again at most once a minute', (tester) async {
    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigatorKey, home: const SizedBox()),
    );
    var now = DateTime(2026, 10, 30, 12);

    await tester.runAsync(
      () => withClock(Clock(() => now), () async {
        proxyDown();
        await store.init();
        expect(proxyCalls(), 1);

        // Within the minute: failing quietly, nothing asked again.
        now = now.add(const Duration(seconds: 5));
        for (var i = 0; i < 3; i++) {
          expect(await helix('/chat/emotes/global'), 401);
        }
        await pumpEventQueue();
        expect(proxyCalls(), 1);

        // A minute later the proxy is back: the next 401 brings a token.
        now = now.add(const Duration(minutes: 1));
        proxyHands(appToken);
        expect(await helix('/chat/emotes/global'), 401);
        for (var i = 0; i < 50 && store.token == null; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        expect(proxyCalls(), 2);
        expect(store.token, appToken);
        expect(store.isLoggedIn, isFalse);
        expect(await helix('/chat/emotes/global'), 200);
      }),
    );
    await tester.pump();

    expect(find.byType(OnsetAlertDialog), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('a revoked app token is dropped and replaced, without a '
      'dialog', (tester) async {
    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigatorKey, home: const SizedBox()),
    );
    var now = DateTime(2026, 10, 30, 12);

    await tester.runAsync(
      () => withClock(Clock(() => now), () async {
        proxyHands(appToken);
        await store.init();
        expect(store.token, appToken);

        // Someone revokes the shared token; the proxy has a new one.
        twitch.tokens.remove(appToken);
        proxyHands(appToken2);
        now = now.add(const Duration(minutes: 2));
        expect(await helix('/chat/emotes/global'), 401);
        for (var i = 0; i < 50 && store.token != appToken2; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }

        expect(store.token, appToken2);
        expect(store.isLoggedIn, isFalse);
        expect(
          await const FlutterSecureStorage().read(key: 'default_token'),
          appToken2,
        );
        expect(await helix('/chat/emotes/global'), 200);
      }),
    );
    await tester.pump();

    expect(find.byType(OnsetAlertDialog), findsNothing);
  });

  testWidgets('a logged-out 401 that the token is not to blame for keeps '
      'the token, without a dialog', (tester) async {
    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigatorKey, home: const SizedBox()),
    );
    var now = DateTime(2026, 10, 30, 12);

    await tester.runAsync(
      () => withClock(Clock(() => now), () async {
        proxyHands(appToken);
        await store.init();

        now = now.add(const Duration(minutes: 2));
        expect(await helix('/whispers'), 401);
        await pumpEventQueue();
        for (var i = 0; i < 10; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }

        expect(validations(appToken), 2, reason: 'checked once more');
        expect(store.token, appToken);
        expect(proxyCalls(), 1);
      }),
    );
    await tester.pump();

    expect(find.byType(OnsetAlertDialog), findsNothing);
  });

  testWidgets('logged in, a Helix 401 still asks to log in', (tester) async {
    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigatorKey, home: const SizedBox()),
    );

    await tester.runAsync(() async {
      proxyHands(appToken);
      await store.init();
      await store.login(token: userToken);
      expect(store.isLoggedIn, isTrue);
      expect(store.headersTwitch['Client-Id'], app);

      expect(await helix('/whispers'), 401);
    });
    await tester.pump();

    expect(find.byType(OnsetAlertDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  test('a token the proxy hands out while a login is under way never '
      "replaces the user's", () async {
    var now = DateTime(2026, 10, 30, 12);
    await withClock(Clock(() => now), () async {
      proxyDown();
      await store.init();
      expect(store.token, isNull);

      now = now.add(const Duration(minutes: 2));
      proxyHands(appToken);
      twitch.proxyDelay = const Duration(milliseconds: 200);
      final retry = store.retryAppToken();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await store.login(token: userToken);
      await retry;

      expect(store.isLoggedIn, isTrue);
      expect(store.token, userToken);
      expect(store.headersTwitch['Client-Id'], app);
    });
  });

  test('a login that commits while the proxy is asked wins too', () async {
    var now = DateTime(2026, 10, 30, 12);
    await withClock(Clock(() => now), () async {
      proxyDown();
      await store.init();

      now = now.add(const Duration(minutes: 2));
      proxyHands(appToken);
      twitch.proxyDelay = const Duration(milliseconds: 100);
      final login = store.login(token: userToken);
      final retry = store.retryAppToken();
      await Future.wait([login, retry]);

      expect(store.isLoggedIn, isTrue);
      expect(store.token, userToken);
    });
  });

  test('the token never shows in the store as text', () async {
    proxyHands(appToken);
    await store.init();

    expect(store.toString(), isNot(contains(appToken)));
  });

  group('logout', () {
    late MockTwitchApi api;
    late AuthStore loggedIn;

    setUp(() async {
      api = MockTwitchApi();
      FlutterSecureStorage.setMockInitialValues({
        'user_token': 'user',
        'default_token': 'stored_default',
      });
      when(
        () => api.checkToken(token: any(named: 'token')),
      ).thenAnswer((_) async => TokenCheck.valid);
      when(
        () => api.validateToken(token: any(named: 'token')),
      ).thenAnswer((_) async => true);
      when(
        () => api.getUserInfo(),
      ).thenAnswer((_) async => const UserTwitch('1', 'viewer', 'Viewer', ''));
      when(
        () => api.getUserBlockedList(id: any(named: 'id')),
      ).thenAnswer((_) async => []);
      when(() => api.tokenUserId(any())).thenAnswer((_) async => '1');
      when(
        () => api.revokeToken(
          token: any(named: 'token'),
          clientId: any(named: 'clientId'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => api.getDefaultToken(),
      ).thenThrow(const ApiException('Service temporarily unavailable', 502));
      loggedIn = AuthStore(
        twitchApi: api,
        webTokenService: cookies,
        isAndroid: false,
      );
      await loggedIn.init();
      expect(loggedIn.isLoggedIn, isTrue);
    });

    test('with the proxy down it still logs out', () async {
      when(
        () => api.validateToken(token: any(named: 'token')),
      ).thenAnswer((_) async => false);

      await loggedIn.logout();

      expect(loggedIn.isLoggedIn, isFalse);
      expect(loggedIn.token, isNull);
    });

    test('offline, it still logs out and keeps the stored app token', () async {
      when(
        () => api.validateToken(token: any(named: 'token')),
      ).thenThrow(const NetworkException('offline'));

      await loggedIn.logout();

      expect(loggedIn.isLoggedIn, isFalse);
      expect(loggedIn.token, 'stored_default');
      expect(loggedIn.isAnonymous, isTrue);
    });
  });
}
