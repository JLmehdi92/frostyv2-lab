import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/models/user.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/services/twitch_web_token_service.dart';
import 'package:webview_flutter/webview_flutter.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

class MockWebTokenService extends Mock implements TwitchWebTokenService {}

/// Tokens of another app (pasted from another tool, or stored by an older
/// version): the app used to accept any token Twitch accepts. Only the login
/// page, where a token could be injected, insists on this app's.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockTwitchApi api;
  late MockWebTokenService cookies;

  setUp(() {
    api = MockTwitchApi();
    cookies = MockWebTokenService();
    FlutterSecureStorage.setMockInitialValues({
      'default_token': 'the_default_token',
    });
    // "foreign" is valid but another app's; everything else is this app's.
    when(() => api.validateToken(token: any(named: 'token'))).thenAnswer(
      (invocation) async => invocation.namedArguments[#token] != 'foreign',
    );
    when(() => api.checkToken(token: any(named: 'token'))).thenAnswer(
      (invocation) async => invocation.namedArguments[#token] == 'foreign'
          ? const TokenCheck.foreign('other_app')
          : TokenCheck.valid,
    );
    when(
      () => api.getUserInfo(token: any(named: 'token')),
    ).thenAnswer((_) async => const UserTwitch('1', 'viewer', 'Viewer', ''));
    when(
      () => api.getUserInfo(),
    ).thenAnswer((_) async => const UserTwitch('1', 'viewer', 'Viewer', ''));
    when(
      () => api.getUserInfo(
        token: any(named: 'token'),
        clientId: any(named: 'clientId'),
      ),
    ).thenAnswer((_) async => const UserTwitch('1', 'viewer', 'Viewer', ''));
    when(
      () => api.getUserBlockedList(id: any(named: 'id')),
    ).thenAnswer((_) async => []);
    when(() => cookies.readAuthToken()).thenAnswer((_) async => null);
    when(() => cookies.clearCookies()).thenAnswer((_) async {});
    when(() => api.tokenUserId(any())).thenAnswer((_) async => '1');
    when(
      () => api.revokeToken(token: any(named: 'token')),
    ).thenAnswer((_) async {});
    when(
      () => api.revokeToken(
        token: any(named: 'token'),
        clientId: any(named: 'clientId'),
      ),
    ).thenAnswer((_) async {});
  });

  AuthStore build() =>
      AuthStore(twitchApi: api, webTokenService: cookies, isAndroid: false);

  test('a stored token of another app survives the launch, with a notice '
      'shown once', () async {
    FlutterSecureStorage.setMockInitialValues({
      'default_token': 'the_default_token',
      'user_token': 'foreign',
    });
    final store = build();
    await store.init();

    expect(store.isLoggedIn, isTrue);
    expect(store.tokenNotice, TokenNotice.foreignToken);
    // Helix takes the token with its own app's Client-Id.
    expect(store.headersTwitch['Client-Id'], 'other_app');
    expect(
      await const FlutterSecureStorage().read(key: 'user_token'),
      'foreign',
    );
    // Kept with the token, for the background go-live check.
    expect(
      await const FlutterSecureStorage().read(
        key: AuthBase.userTokenClientIdKey,
      ),
      'other_app',
    );
    store.clearTokenNotice();
    expect(store.tokenNotice, isNull);

    // The next launch: still logged in, the notice is not shown again.
    final next = build();
    await next.init();
    expect(next.isLoggedIn, isTrue);
    expect(next.tokenNotice, isNull);
  });

  test("this app's stored token: no notice", () async {
    FlutterSecureStorage.setMockInitialValues({
      'default_token': 'the_default_token',
      'user_token': 'ours',
      'user_token_client_id': 'stale_app',
    });
    final store = build();
    await store.init();
    // Nothing of another app's kept for it.
    expect(
      await const FlutterSecureStorage().read(
        key: AuthBase.userTokenClientIdKey,
      ),
      isNull,
    );
    expect(store.isLoggedIn, isTrue);
    expect(store.tokenNotice, isNull);
    expect(store.headersTwitch['Client-Id'], isNot('other_app'));
  });

  test('a pasted token of another app logs in, with the notice', () async {
    final store = build();
    await store.init();

    await store.login(token: 'foreign', acceptAnyApp: true);

    expect(store.isLoggedIn, isTrue);
    expect(store.tokenNotice, TokenNotice.foreignToken);
    // Its user was read, and Helix is then asked, with its app's Client-Id.
    verify(
      () => api.getUserInfo(token: 'foreign', clientId: 'other_app'),
    ).called(1);
    expect(store.headersTwitch['Client-Id'], 'other_app');
    expect(
      await const FlutterSecureStorage().read(key: 'user_token'),
      'foreign',
    );

    expect(
      await const FlutterSecureStorage().read(
        key: AuthBase.userTokenClientIdKey,
      ),
      'other_app',
    );

    // Logging out: revoked with its own app's client id, and the app's own
    // Client-Id again; the stored client id goes with the token.
    await store.logout();
    expect(store.headersTwitch['Client-Id'], isNot('other_app'));
    verify(
      () => api.revokeToken(token: 'foreign', clientId: 'other_app'),
    ).called(1);
    expect(
      await const FlutterSecureStorage().read(
        key: AuthBase.userTokenClientIdKey,
      ),
      isNull,
    );
  });

  test("the login page still refuses another app's token", () async {
    final store = build();
    await store.init();
    final attempt = store.beginLogin();
    final state = store.authorizationUri(attempt).queryParameters['state']!;
    final outcomes = <Future<bool>>[];

    store.handleNavigation(
      request: NavigationRequest(
        url:
            'https://twitch.tv/login#access_token=foreign&scope=chat%3Aread'
            '&state=$state&token_type=bearer',
        isMainFrame: true,
      ),
      onTokenCaptured: outcomes.add,
      attempt: attempt,
    );

    expect(await outcomes.single, isFalse);
    expect(store.isLoggedIn, isFalse);
    expect(store.tokenNotice, isNull);
    verifyNever(() => api.checkToken(token: 'foreign'));
  });
}
