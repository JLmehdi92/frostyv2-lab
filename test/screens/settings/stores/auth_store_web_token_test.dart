import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/models/user.dart';
import 'package:frosty/screens/settings/stores/auth_store.dart';
import 'package:frosty/services/twitch_web_token_service.dart';
import 'package:mocktail/mocktail.dart';

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

    test('a signed-out viewer loads no page', () async {
      final store = build();

      expect(await store.refreshTwitchWebSession(), isFalse);

      expect(pageLoads, 0);
    });
  });
}
