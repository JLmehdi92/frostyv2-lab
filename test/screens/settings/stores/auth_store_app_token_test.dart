import 'package:clock/clock.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/base_api_client.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/apis/twitch_auth_interceptor.dart';
import 'package:onset/apis/unauthorized_interceptor.dart';
import 'package:onset/main.dart';
import 'package:onset/models/user.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/services/twitch_web_token_service.dart';
import 'package:onset/widgets/onset_alert_dialog.dart';

class MockWebTokenService extends Mock implements TwitchWebTokenService {}

class MockTwitchApi extends Mock implements TwitchApi {}

/// A logged-out viewer's app token comes from the token proxy. When the
/// proxy (or the network) is down the app still starts, logging in still
/// works, and the Helix calls that need the token fail without ever asking
/// the viewer to log in.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const proxy = 'https://onset-token.example.workers.dev';
  const endpoint = '$proxy/app-token';
  const appToken = 'abcdefghijklmnopqrstuvwxyz0123';
  const validate = 'https://id.twitch.tv/oauth2/validate';
  const emotes = 'https://api.twitch.tv/helix/chat/emotes/global';

  late Dio dio;
  late DioAdapter adapter;
  late List<RequestOptions> sent;
  late MockWebTokenService cookies;
  late AuthStore store;

  int proxyCalls() => sent.where((r) => r.uri.toString() == endpoint).length;

  void proxyAnswers(int status, [Object? body]) => adapter.onGet(
    endpoint,
    (server) => server.reply(status, body ?? {'error': 'unavailable'}),
  );

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    dio = Dio(BaseOptions());
    adapter = DioAdapter(dio: dio);
    sent = [];
    cookies = MockWebTokenService();
    when(() => cookies.readAuthToken()).thenAnswer((_) async => null);
    when(() => cookies.clearCookies()).thenAnswer((_) async {});
    store = AuthStore(
      twitchApi: TwitchApi(dio, appClientId: 'app', tokenProxyUrl: proxy),
      webTokenService: cookies,
      isAndroid: false,
    );
    dio.interceptors
      ..add(TwitchAuthInterceptor(store))
      ..add(UnauthorizedInterceptor(store))
      ..add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            sent.add(options);
            handler.next(options);
          },
        ),
      );
    adapter.onGet(
      emotes,
      (server) => server.reply(401, {'message': 'Invalid OAuth token'}),
    );
  });

  test('the proxy down at launch: logged out, no error, no token', () async {
    proxyAnswers(502);

    await store.init();

    expect(store.isLoggedIn, isFalse);
    expect(store.error, isNull, reason: 'the login button must stay');
    expect(store.token, isNull);
    expect(proxyCalls(), 1);
  });

  test('no token: no "Bearer null" is sent', () async {
    proxyAnswers(502);
    await store.init();

    expect(store.headersTwitch.containsKey('Authorization'), isFalse);
    expect(store.headersTwitch.containsKey('Client-Id'), isTrue);
  });

  test(
    'a stored token Twitch refuses is dropped when the proxy is down',
    () async {
      FlutterSecureStorage.setMockInitialValues({'default_token': 'stale'});
      adapter.onGet(validate, (server) => server.reply(401, {'status': 401}));
      proxyAnswers(502);

      await store.init();

      expect(store.token, isNull);
      expect(store.error, isNull);
    },
  );

  test('a stored token Twitch takes is kept, the proxy not asked', () async {
    FlutterSecureStorage.setMockInitialValues({'default_token': appToken});
    adapter.onGet(
      validate,
      (server) => server.reply(200, {'client_id': 'app', 'expires_in': 9000}),
    );

    await store.init();

    expect(store.token, appToken);
    expect(proxyCalls(), 0);
  });

  test('a token from the proxy is used and kept for the next launch', () async {
    proxyAnswers(200, {'access_token': appToken, 'expires_in': 5000000});

    await store.init();

    expect(store.token, appToken);
    expect(store.headersTwitch['Authorization'], 'Bearer $appToken');
    expect(
      await const FlutterSecureStorage().read(key: 'default_token'),
      appToken,
    );
  });

  testWidgets('Helix while logged out without a token: no dialog, and the '
      'token is asked for again at most once a minute', (tester) async {
    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigatorKey, home: const SizedBox()),
    );
    var now = DateTime(2026, 10, 30, 12);

    await tester.runAsync(
      () => withClock(Clock(() => now), () async {
        proxyAnswers(502);
        await store.init();
        expect(proxyCalls(), 1);

        // Within the minute: failing quietly, nothing asked again.
        now = now.add(const Duration(seconds: 5));
        for (var i = 0; i < 3; i++) {
          await expectLater(
            store.twitchApi.getEmotesGlobal(),
            throwsA(isA<UnauthorizedException>()),
          );
        }
        await pumpEventQueue();
        expect(proxyCalls(), 1);

        // A minute later the proxy is back: the next 401 brings a token.
        now = now.add(const Duration(minutes: 1));
        proxyAnswers(200, {'access_token': appToken, 'expires_in': 5000000});
        await expectLater(
          store.twitchApi.getEmotesGlobal(),
          throwsA(isA<UnauthorizedException>()),
        );
        for (var i = 0; i < 50 && store.token == null; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        expect(proxyCalls(), 2);
        expect(store.token, appToken);
        expect(store.isLoggedIn, isFalse);
      }),
    );
    await tester.pump();

    expect(find.byType(OnsetAlertDialog), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('a 401 with a session token still asks to log in', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigatorKey, home: const SizedBox()),
    );

    await tester.runAsync(() async {
      proxyAnswers(200, {'access_token': appToken, 'expires_in': 5000000});
      await store.init();
      await expectLater(
        store.twitchApi.getEmotesGlobal(),
        throwsA(isA<UnauthorizedException>()),
      );
    });
    await tester.pump();

    expect(find.byType(OnsetAlertDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  test('logging out with the proxy down still logs out', () async {
    final api = MockTwitchApi();
    FlutterSecureStorage.setMockInitialValues({'user_token': 'user'});
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
    final loggedIn = AuthStore(
      twitchApi: api,
      webTokenService: cookies,
      isAndroid: false,
    );
    await loggedIn.init();
    expect(loggedIn.isLoggedIn, isTrue);

    await loggedIn.logout();

    expect(loggedIn.isLoggedIn, isFalse);
    expect(loggedIn.token, isNull);
  });
}
