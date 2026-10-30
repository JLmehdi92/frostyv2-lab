import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/apis/twitch_auth_interceptor.dart';
import 'package:onset/apis/unauthorized_interceptor.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/services/twitch_web_token_service.dart';

import '../../../helpers/fake_twitch_http.dart';

class MockWebTokenService extends Mock implements TwitchWebTokenService {}

/// An update that changes the login application's client id (a new Twitch
/// account for ONSET): what was stored by the previous build was issued to
/// the old application.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const oldApp = 'oldloginappclientid0123456789';
  const publicApp = 'publicappclientid0123456789ab';
  const oldUserToken = 'olduser0123456789abcdefghijkl';
  const oldAppToken = 'oldapptoken0123456789abcdefgh';
  const proxyToken = 'abcdefghijklmnopqrstuvwxyz0123';

  late FakeTwitchHttp twitch;
  late AuthStore store;

  int validations(String token) => twitch.requests
      .where(
        (r) =>
            r.uri.path == '/oauth2/validate' &&
            '${r.headers['Authorization']}'.endsWith(token),
      )
      .length;

  setUp(() {
    twitch = FakeTwitchHttp({proxyToken: (clientId: publicApp, userId: '')})
      ..proxy = (
        status: 200,
        body: {
          'access_token': proxyToken,
          'expires_in': 5000000,
          'client_id': publicApp,
        },
      );
    final dio = Dio()..httpClientAdapter = twitch;
    final cookies = MockWebTokenService();
    when(cookies.readAuthToken).thenAnswer((_) async => null);
    when(cookies.clearCookies).thenAnswer((_) async {});
    store = AuthStore(
      twitchApi: TwitchApi(
        dio,
        tokenProxyUrl: 'https://onset-token.example.workers.dev',
      ),
      webTokenService: cookies,
      isAndroid: false,
    );
    dio.interceptors
      ..add(TwitchAuthInterceptor(store))
      ..add(UnauthorizedInterceptor(store));
  });

  test(
    'the old application deleted: its user token is refused, the viewer '
    'logged out and told to log in again, once, without a retry loop',
    () async {
      FlutterSecureStorage.setMockInitialValues({'user_token': oldUserToken});

      await store.init();

      expect(store.isLoggedIn, isFalse);
      expect(store.error, isNull);
      expect(store.tokenNotice, AuthBase.sessionEndedNotice);
      expect(
        await const FlutterSecureStorage().read(key: 'user_token'),
        isNull,
      );
      // Logged out with the proxy's token, not stuck reconnecting.
      expect(store.token, proxyToken);
      expect(store.isAnonymous, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(validations(oldUserToken), 1);

      // Shown once: the next launch has nothing to say.
      store.clearTokenNotice();
      await store.init();
      expect(store.tokenNotice, isNull);
    },
  );

  test('the old application still there: its user token keeps working with '
      'its own Client-Id, with the other-app notice', () async {
    twitch.tokens[oldUserToken] = (clientId: oldApp, userId: '7');
    FlutterSecureStorage.setMockInitialValues({'user_token': oldUserToken});

    await store.init();

    expect(store.isLoggedIn, isTrue);
    expect(store.headersTwitch['Client-Id'], oldApp);
    expect(store.tokenNotice, AuthBase.foreignTokenNotice);
  });

  test(
    "an app token of the old application is replaced by the proxy's",
    () async {
      // Still valid, but not this build's application.
      twitch.tokens[oldAppToken] = (clientId: oldApp, userId: '');
      FlutterSecureStorage.setMockInitialValues({'default_token': oldAppToken});

      await store.init();

      expect(store.token, proxyToken);
      expect(store.headersTwitch['Client-Id'], publicApp);
      expect(store.tokenNotice, isNull);
    },
  );
}
