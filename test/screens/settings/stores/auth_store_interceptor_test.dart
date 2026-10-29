import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/apis/twitch_auth_interceptor.dart';
import 'package:frosty/constants.dart';
import 'package:frosty/screens/settings/stores/auth_store.dart';
import 'package:frosty/services/twitch_web_token_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fake_twitch_http.dart';

class MockWebTokenService extends Mock implements TwitchWebTokenService {}

/// The session's headers go through the real [TwitchAuthInterceptor] to a
/// Twitch that refuses a token sent with another app's Client-Id.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeTwitchHttp twitch;
  late AuthStore store;

  setUp(() {
    twitch = FakeTwitchHttp({
      'foreign': (clientId: 'other_app', userId: '1'),
      'ours': (clientId: clientId, userId: '2'),
      'the_default_token': (clientId: clientId, userId: '0'),
    });
    FlutterSecureStorage.setMockInitialValues({
      'default_token': 'the_default_token',
      'user_token': 'foreign',
    });
    final cookies = MockWebTokenService();
    when(cookies.readAuthToken).thenAnswer((_) async => null);
    when(cookies.clearCookies).thenAnswer((_) async {});
    final dio = Dio()..httpClientAdapter = twitch;
    store = AuthStore(
      twitchApi: TwitchApi(dio),
      webTokenService: cookies,
      isAndroid: false,
    );
    dio.interceptors.add(TwitchAuthInterceptor(store));
  });

  test("a stored token of another app reads its user with that app's "
      'Client-Id', () async {
    await store.init();
    expect(store.isLoggedIn, isTrue);
    expect(store.user.details?.id, '1');
    expect(store.headersTwitch['Client-Id'], 'other_app');
  });

  test(
    "from another app's session, logging in with this app's token works",
    () async {
      await store.init();
      expect(store.user.details?.id, '1');

      await store.login(token: 'ours');

      expect(store.isLoggedIn, isTrue);
      expect(store.token, 'ours');
      expect(store.user.details?.id, '2');
      expect(store.headersTwitch['Client-Id'], clientId);
      final users = twitch.requests.lastWhere(
        (request) =>
            request.uri.path == '/helix/users' &&
            request.headers['Authorization'] == 'Bearer ours',
      );
      expect(users.headers['Client-Id'], clientId);
    },
  );

  test("from another app's session, pasting a third app's token uses that "
      "app's Client-Id", () async {
    twitch.tokens['third'] = (clientId: 'third_app', userId: '3');
    await store.init();

    await store.login(token: 'third', acceptAnyApp: true);

    expect(store.user.details?.id, '3');
    expect(store.headersTwitch['Client-Id'], 'third_app');
  });
}
