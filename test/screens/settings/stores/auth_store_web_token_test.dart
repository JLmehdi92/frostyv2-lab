import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/base_api_client.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/models/user.dart';
import 'package:frosty/screens/settings/stores/auth_store.dart';
import 'package:frosty/services/twitch_web_token_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:webview_flutter/webview_flutter.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

class MockWebTokenService extends Mock implements TwitchWebTokenService {}

const _storage = FlutterSecureStorage();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockTwitchApi api;
  late MockWebTokenService cookies;

  /// What the cookie jar holds; the page loader may change it.
  String? jar;
  late int pageLoads;

  setUp(() {
    api = MockTwitchApi();
    cookies = MockWebTokenService();
    jar = null;
    pageLoads = 0;
    FlutterSecureStorage.setMockInitialValues({
      'default_token': 'the_default_token',
    });
    when(
      () => api.validateToken(token: any(named: 'token')),
    ).thenAnswer((_) async => true);
    when(
      () => api.revokeToken(token: any(named: 'token')),
    ).thenAnswer((_) async {});
    when(
      () => api.getUserInfo(),
    ).thenAnswer((_) async => const UserTwitch('1', 'viewer', 'Viewer', ''));
    when(
      () => api.getUserBlockedList(id: any(named: 'id')),
    ).thenAnswer((_) async => []);
    when(() => cookies.readAuthToken()).thenAnswer((_) async => jar);
    when(() => cookies.clearCookies()).thenAnswer((_) async {});
  });

  AuthStore build({
    bool isAndroid = true,
    Future<void> Function()? loadTwitchPage,
  }) => AuthStore(
    twitchApi: api,
    webTokenService: cookies,
    isAndroid: isAndroid,
    loadTwitchPage:
        loadTwitchPage ??
        () async {
          pageLoads++;
        },
  );

  Future<AuthStore> withStoredToken(
    String token, {
    bool isAndroid = true,
    Future<void> Function()? loadTwitchPage,
  }) async {
    FlutterSecureStorage.setMockInitialValues({
      'default_token': 'the_default_token',
      'twitch_web_token': token,
    });
    final store = build(isAndroid: isAndroid, loadTwitchPage: loadTwitchPage);
    await store.init();
    await store.login(token: 'user');
    return store;
  }

  /// A signed-in store with nothing stored yet.
  Future<AuthStore> signedIn({Future<void> Function()? loadTwitchPage}) async {
    final store = build(loadTwitchPage: loadTwitchPage);
    await store.login(token: 'user');
    return store;
  }

  group('setTwitchWebToken', () {
    test('trims and stores the token', () async {
      final store = build();

      await store.setTwitchWebToken('  abc  ');

      expect(store.twitchWebToken, 'abc');
      expect(await _storage.read(key: 'twitch_web_token'), 'abc');
    });

    test('a blank or null token deletes it', () async {
      final store = await withStoredToken('old');

      await store.setTwitchWebToken('   ');
      expect(store.twitchWebToken, isNull);
      expect(await _storage.read(key: 'twitch_web_token'), isNull);

      await store.setTwitchWebToken('again');
      await store.setTwitchWebToken(null);
      expect(store.twitchWebToken, isNull);
      expect(await _storage.read(key: 'twitch_web_token'), isNull);
    });
  });

  test('init restores the stored token', () async {
    final store = await withStoredToken('stored');

    expect(store.twitchWebToken, 'stored');
    expect(store.webSessionExpired, isFalse);
  });

  group('a login page login that fails leaves account A as it was', () {
    /// The redirect of a login page for [token], then Twitch's own.
    Future<bool> loginPage(AuthStore store, String token) async {
      final attempt = store.beginLogin();
      final state = store.authorizationUri(attempt).queryParameters['state'];
      Future<bool>? outcome;
      store.handleNavigation(
        request: NavigationRequest(
          url: 'https://twitch.tv/login#access_token=$token&state=$state',
          isMainFrame: true,
        ),
        attempt: attempt,
        onTokenCaptured: (login) => outcome = login,
      );
      store.handleNavigation(
        request: const NavigationRequest(
          url: 'https://www.twitch.tv/?no-reload=true',
          isMainFrame: true,
        ),
        attempt: attempt,
        onSignedIn: () {},
      );
      final worked = await outcome!;
      await pumpEventQueue();
      return worked;
    }

    test("B's details cannot be read: token, stored token, web token and "
        "user stay A's, and B's cookie is not harvested", () async {
      final store = await withStoredToken('web_of_viewer_1');
      expect(store.user.details?.id, '1');
      jar = 'web_of_viewer_2';
      clearInteractions(cookies);
      when(() => api.getUserInfo()).thenThrow(Exception('offline'));

      expect(await loginPage(store, 'user_2'), isFalse);

      expect(store.headersTwitch['Authorization'], 'Bearer user');
      expect(await _storage.read(key: 'user_token'), 'user');
      expect(store.twitchWebToken, 'web_of_viewer_1');
      expect(await _storage.read(key: 'twitch_web_token'), 'web_of_viewer_1');
      expect(store.user.details?.id, '1');
      expect(store.isLoggedIn, isTrue);
      verifyNever(() => cookies.readAuthToken());
    });

    test(
      'B refused by Twitch: nothing of A changes, nothing harvested',
      () async {
        final store = await withStoredToken('web_of_viewer_1');
        jar = 'web_of_viewer_2';
        clearInteractions(cookies);
        when(
          () => api.validateToken(token: 'user_2'),
        ).thenAnswer((_) async => false);

        expect(await loginPage(store, 'user_2'), isFalse);

        expect(store.headersTwitch['Authorization'], 'Bearer user');
        expect(await _storage.read(key: 'user_token'), 'user');
        expect(store.twitchWebToken, 'web_of_viewer_1');
        verifyNever(() => cookies.readAuthToken());
      },
    );

    test("a real switch to B still harvests B's cookie", () async {
      final store = await withStoredToken('web_of_viewer_1');
      jar = 'web_of_viewer_2';
      when(
        () => api.getUserInfo(),
      ).thenAnswer((_) async => const UserTwitch('2', 'other', 'Other', ''));

      expect(await loginPage(store, 'user_2'), isTrue);

      expect(store.headersTwitch['Authorization'], 'Bearer user_2');
      expect(await _storage.read(key: 'user_token'), 'user_2');
      expect(store.user.details?.id, '2');
      expect(store.twitchWebToken, 'web_of_viewer_2');
      expect(await _storage.read(key: 'twitch_web_token'), 'web_of_viewer_2');
    });
  });

  group('a login as another account', () {
    test("drops the previous account's web token", () async {
      final store = await withStoredToken('web_of_viewer_1');
      expect(store.twitchWebToken, 'web_of_viewer_1');

      when(
        () => api.getUserInfo(),
      ).thenAnswer((_) async => const UserTwitch('2', 'other', 'Other', ''));
      await store.login(token: 'user_2');

      expect(store.twitchWebToken, isNull);
      expect(await _storage.read(key: 'twitch_web_token'), isNull);
    });

    // The login page's order: the redirect with the user token starts the
    // login (validation and the user's details: two requests), then the
    // next redirect harvests the twitch.tv cookie, which the login page has
    // just made the new account's.
    for (final harvestFirst in [true, false]) {
      test(
        "from the login page, the new account's web token stays "
        '(harvest ${harvestFirst ? 'before' : 'after'} the account check)',
        () async {
          final store = await withStoredToken('web_of_viewer_1');
          jar = 'web_of_viewer_2';
          final validated = Completer<bool>();
          final read = Completer<String?>();
          var reads = 0;
          when(
            () => api.validateToken(token: any(named: 'token')),
          ).thenAnswer((_) => validated.future);
          when(() => api.getUserInfo()).thenAnswer(
            (_) async => const UserTwitch('2', 'other', 'Other', ''),
          );
          when(() => cookies.readAuthToken()).thenAnswer((_) {
            reads++;
            // The redirect's own read is the first one.
            return reads == 1 ? read.future : Future.value(jar);
          });

          final state = store.startAuthorization().queryParameters['state']!;
          store.handleNavigation(
            request: NavigationRequest(
              url:
                  'https://twitch.tv/login#access_token=user_2&scope=x'
                  '&state=$state',
              isMainFrame: true,
            ),
          );
          store.handleNavigation(
            request: const NavigationRequest(
              url: 'https://www.twitch.tv/?no-reload=true',
              isMainFrame: true,
            ),
          );
          if (harvestFirst) {
            read.complete('web_of_viewer_2');
            await pumpEventQueue();
            validated.complete(true);
          } else {
            validated.complete(true);
            await pumpEventQueue();
            read.complete('web_of_viewer_2');
          }
          await pumpEventQueue();

          expect(store.twitchWebToken, 'web_of_viewer_2');
          expect(
            await _storage.read(key: 'twitch_web_token'),
            'web_of_viewer_2',
          );
        },
      );
    }

    test('logged in as another account while the launch reconnects: the '
        "old account's web token still goes", () async {
      // Account 1 logged in on a previous launch.
      await withStoredToken('web_of_viewer_1');
      // This launch cannot validate its token yet: the reconnect loop, no
      // details loaded.
      when(
        () => api.validateToken(token: any(named: 'token')),
      ).thenThrow(const ApiException('offline'));
      final store = build();
      await store.init();
      expect(store.isLoggedIn, isFalse);
      expect(store.twitchWebToken, 'web_of_viewer_1');

      when(
        () => api.validateToken(token: any(named: 'token')),
      ).thenAnswer((_) async => true);
      when(
        () => api.getUserInfo(),
      ).thenAnswer((_) async => const UserTwitch('2', 'other', 'Other', ''));
      await store.login(token: 'user_2');
      await pumpEventQueue();

      expect(store.twitchWebToken, isNot('web_of_viewer_1'));
      await store.logout();
    });

    test('the same account logging in again keeps it', () async {
      final store = await withStoredToken('web_of_viewer_1');

      await store.login(token: 'user_again');

      expect(store.twitchWebToken, 'web_of_viewer_1');
    });
  });

  group('the account id is kept best-effort', () {
    test(
      'a keystore refusing it changes neither the launch nor a login',
      () async {
        // A session from a previous launch, with a cookie to harvest.
        FlutterSecureStorage.setMockInitialValues({
          'default_token': 'the_default_token',
          'user_token': 'user',
        });
        jar = 'web_of_viewer_1';
        final store = AuthStore(
          twitchApi: api,
          webTokenService: cookies,
          isAndroid: true,
          storage: const _RefusingIdStorage(),
          loadTwitchPage: () async => pageLoads++,
        );

        await store.init();
        await pumpEventQueue();
        expect(store.isLoggedIn, isTrue);
        // The launch still keeps the web session fresh.
        expect(store.twitchWebToken, 'web_of_viewer_1');

        await store.login(token: 'user_again');
        expect(store.isLoggedIn, isTrue);
      },
    );

    test('the reconnect loop restoring the session keeps it', () {
      fakeAsync((async) {
        FlutterSecureStorage.setMockInitialValues({
          'default_token': 'the_default_token',
          'user_token': 'user',
        });
        when(
          () => api.validateToken(token: any(named: 'token')),
        ).thenThrow(const ApiException('offline'));
        final store = build();
        unawaited(store.init());
        async.flushMicrotasks();
        expect(store.isLoggedIn, isFalse);

        when(
          () => api.validateToken(token: any(named: 'token')),
        ).thenAnswer((_) async => true);
        async.elapse(const Duration(seconds: 11));

        expect(store.isLoggedIn, isTrue);
        String? id;
        unawaited(_storage.read(key: 'user_id').then((value) => id = value));
        async.flushMicrotasks();
        expect(id, '1');
      });
    });
  });

  test('logout clears the token and the cookie jar', () async {
    final store = await withStoredToken('stored');

    await store.logout();

    expect(store.twitchWebToken, isNull);
    expect(store.webSessionExpired, isFalse);
    expect(await _storage.read(key: 'twitch_web_token'), isNull);
    verify(() => cookies.clearCookies()).called(1);
  });

  group('harvest on Android', () {
    test('a new cookie is stored', () async {
      final store = await withStoredToken('old');
      jar = 'new';

      expect(await store.harvestTwitchWebToken(), isTrue);

      expect(store.twitchWebToken, 'new');
      expect(await _storage.read(key: 'twitch_web_token'), 'new');
      expect(store.webSessionExpired, isFalse);
    });

    test('the same cookie changes nothing', () async {
      final store = await withStoredToken('same');
      jar = 'same';

      expect(await store.harvestTwitchWebToken(), isTrue);

      expect(store.twitchWebToken, 'same');
      expect(store.webSessionExpired, isFalse);
    });

    test(
      'an empty jar with a stored token means the session expired',
      () async {
        final store = await withStoredToken('old');

        expect(await store.harvestTwitchWebToken(), isFalse);

        // Kept: a transient read failure must not throw a working token away.
        expect(store.twitchWebToken, 'old');
        expect(store.webSessionExpired, isTrue);
      },
    );

    test(
      'an empty jar without a token is the normal signed-out state',
      () async {
        final store = build();
        await store.init();

        expect(await store.harvestTwitchWebToken(), isFalse);

        expect(store.webSessionExpired, isFalse);
      },
    );

    test('a fresh cookie clears the expired flag', () async {
      final store = await withStoredToken('old');
      await store.harvestTwitchWebToken();
      expect(store.webSessionExpired, isTrue);

      jar = 'fresh';
      await store.harvestTwitchWebToken();

      expect(store.webSessionExpired, isFalse);
    });
  });

  group('off Android, where there is no cookie jar to judge from', () {
    test('a harvest miss keeps a pasted token and never expires it', () async {
      final store = await withStoredToken('pasted', isAndroid: false);

      expect(await store.harvestTwitchWebToken(), isFalse);

      expect(store.twitchWebToken, 'pasted');
      expect(store.webSessionExpired, isFalse);
    });

    test('ensure never expires it nor loads a page', () async {
      final store = await withStoredToken('pasted', isAndroid: false);

      expect(await store.ensureTwitchWebToken(), isFalse);

      expect(store.webSessionExpired, isFalse);
      expect(pageLoads, 0);
    });

    test('a renewal returns nothing and never expires it', () async {
      final store = await withStoredToken('pasted', isAndroid: false);

      expect(await store.renewTwitchWebToken(), isNull);

      expect(store.twitchWebToken, 'pasted');
      expect(store.webSessionExpired, isFalse);
      expect(pageLoads, 0);
    });

    test('the real platform default is not Android here', () async {
      FlutterSecureStorage.setMockInitialValues({
        'default_token': 'the_default_token',
        'twitch_web_token': 'pasted',
      });
      final store = AuthStore(twitchApi: api);
      await store.init();

      expect(await store.harvestTwitchWebToken(), isFalse);
      expect(await store.renewTwitchWebToken(), isNull);

      expect(store.webSessionExpired, isFalse);
    });
  });

  group('ensureTwitchWebToken', () {
    test('a cookie already in the jar loads no page', () async {
      final store = await signedIn();
      jar = 'in-jar';

      expect(await store.ensureTwitchWebToken(), isTrue);

      expect(pageLoads, 0);
      expect(store.twitchWebToken, 'in-jar');
    });

    test('an empty jar loads twitch.tv once and harvests', () async {
      final store = await signedIn(
        loadTwitchPage: () async {
          pageLoads++;
          jar = 'reissued';
        },
      );

      expect(await store.ensureTwitchWebToken(), isTrue);

      expect(pageLoads, 1);
      expect(store.twitchWebToken, 'reissued');
    });

    test('a page that fails to load is reported as no token', () async {
      final store = await signedIn(
        loadTwitchPage: () async => throw StateError('x'),
      );

      expect(await store.ensureTwitchWebToken(), isFalse);
    });
  });

  group('renewTwitchWebToken', () {
    test('a token that changed is returned', () async {
      final store = await withStoredToken(
        'refused',
        loadTwitchPage: () async {
          pageLoads++;
          jar = 'renewed';
        },
      );

      expect(await store.renewTwitchWebToken(), 'renewed');

      expect(store.twitchWebToken, 'renewed');
      expect(store.webSessionExpired, isFalse);
    });

    test('the same token back means the session is gone', () async {
      final store = await withStoredToken(
        'refused',
        loadTwitchPage: () async => jar = 'refused',
      );

      expect(await store.renewTwitchWebToken(), isNull);

      expect(store.webSessionExpired, isTrue);
    });

    test('no token back means the session is gone', () async {
      final store = await withStoredToken('refused');

      expect(await store.renewTwitchWebToken(), isNull);

      expect(pageLoads, 1);
      expect(store.webSessionExpired, isTrue);
    });

    test('runs at most once every five minutes', () {
      fakeAsync((async) {
        late AuthStore store;
        unawaited(withStoredToken('refused').then((s) => store = s));
        async.flushMicrotasks();

        unawaited(store.renewTwitchWebToken());
        async.flushMicrotasks();
        expect(pageLoads, 1);

        async.elapse(const Duration(minutes: 4, seconds: 59));
        unawaited(store.renewTwitchWebToken());
        async.flushMicrotasks();
        expect(pageLoads, 1);

        async.elapse(const Duration(seconds: 2));
        unawaited(store.renewTwitchWebToken());
        async.flushMicrotasks();
        expect(pageLoads, 2);
      });
    });

    test('during the launch refresh it waits instead of judging', () async {
      final page = Completer<void>();
      final store = await withStoredToken(
        'old',
        loadTwitchPage: () {
          pageLoads++;
          return page.future;
        },
      );

      // The launch-time ensure finds nothing in the jar and loads the page.
      final ensure = store.ensureTwitchWebToken();
      await pumpEventQueue();
      expect(pageLoads, 1);

      final renew = store.renewTwitchWebToken();
      await pumpEventQueue();
      jar = 'reissued';
      page.complete();

      expect(await ensure, isTrue);
      expect(await renew, 'reissued');
      expect(store.webSessionExpired, isFalse);
      expect(pageLoads, 1);

      // The cooldown was not consumed: a real refusal can still renew.
      jar = null;
      expect(await store.renewTwitchWebToken(), isNull);
      expect(pageLoads, 2);
    });

    test(
      'a refresh that finds nothing does not expire through renew',
      () async {
        final page = Completer<void>();
        final store = await withStoredToken(
          'old',
          loadTwitchPage: () {
            pageLoads++;
            return page.future;
          },
        );

        final ensure = store.ensureTwitchWebToken();
        await pumpEventQueue();
        final renew = store.renewTwitchWebToken();
        page.complete();

        await ensure;
        expect(await renew, isNull);
        expect(pageLoads, 1);
      },
    );
  });

  group('a logout while the web session is being read', () {
    test('drops a harvest that was reading the jar', () async {
      final store = await signedIn();
      final read = Completer<String?>();
      when(() => cookies.readAuthToken()).thenAnswer((_) => read.future);

      final harvest = store.harvestTwitchWebToken();
      await store.logout();
      read.complete('previous-account');

      expect(await harvest, isFalse);
      expect(store.twitchWebToken, isNull);
      expect(await _storage.read(key: 'twitch_web_token'), isNull);
    });

    test('drops a refresh whose page was still loading', () async {
      final page = Completer<void>();
      final store = await signedIn(
        loadTwitchPage: () {
          pageLoads++;
          return page.future;
        },
      );

      final refresh = store.refreshTwitchWebSession();
      await pumpEventQueue();
      await store.logout();
      jar = 'previous-account';
      page.complete();

      expect(await refresh, isFalse);
      expect(store.twitchWebToken, isNull);
      verifyNever(() => cookies.readAuthToken());
    });

    test(
      'a renewal cut by a logout does not call the session expired',
      () async {
        final page = Completer<void>();
        final store = await signedIn(
          loadTwitchPage: () {
            pageLoads++;
            return page.future;
          },
        );

        final renewal = store.renewTwitchWebToken();
        await pumpEventQueue();
        await store.logout();
        page.complete();

        expect(await renewal, isNull);
        expect(store.webSessionExpired, isFalse);
      },
    );

    test('a signed-out viewer loads no page', () async {
      final store = build();

      expect(await store.refreshTwitchWebSession(), isFalse);

      expect(pageLoads, 0);
    });
  });

  test('the hidden WebView may only navigate within twitch.tv', () {
    const allowed = [
      'https://www.twitch.tv/',
      'https://twitch.tv',
      'https://id.twitch.tv/oauth2/authorize',
      'https://passport.twitch.tv/x?y=1',
      'about:blank',
    ];
    const refused = [
      'http://www.twitch.tv/',
      'https://twitch.tv.evil.example/',
      'https://eviltwitch.tv/',
      'https://evil.example/twitch.tv',
      'https://evil.example/?u=https://www.twitch.tv',
      'javascript:alert(1)',
      'intent://scan/#Intent;scheme=zxing;end',
      'file:///data/data/app/cookies',
      'not a url',
      '',
    ];
    for (final url in allowed) {
      expect(TwitchWebTokenService.isTwitchPageUrl(url), isTrue, reason: url);
    }
    for (final url in refused) {
      expect(TwitchWebTokenService.isTwitchPageUrl(url), isFalse, reason: url);
    }
  });
}

/// A keystore that refuses the account id (reads and writes), and keeps the
/// rest.
class _RefusingIdStorage extends FlutterSecureStorage {
  const _RefusingIdStorage();

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) {
    if (key == 'user_id') throw Exception('keystore refused');
    return super.write(key: key, value: value);
  }

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) {
    if (key == 'user_id') throw Exception('keystore refused');
    return super.read(key: key);
  }
}
