import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_tv_auth_service.dart';
import 'package:onset/models/twitch_tv_session.dart';
import 'package:onset/screens/settings/stores/twitch_tv_session_store.dart';

class _MockAuth extends Mock implements TwitchTvAuthService {}

class _MockStorage extends Mock implements FlutterSecureStorage {}

const _storage = FlutterSecureStorage();

TwitchTvSession _stored({String user = '77', String? refresh = 'r1'}) =>
    TwitchTvSession(
      accessToken: 'tv-access',
      refreshToken: refresh,
      userId: user,
      deviceId: 'device00device00',
    );

final _code = TwitchTvDeviceCode(
  deviceCode: 'dev',
  userCode: 'ABCDEFGH',
  interval: const Duration(seconds: 5),
  expiresAt: DateTime.utc(2030),
);

const _granted = TwitchTvPollGranted(
  TwitchTvGrant(accessToken: 'tv-new', refreshToken: 'tv-r'),
);

void main() {
  late _MockAuth auth;
  late List<Duration> waits;
  late String? viewer;
  late TwitchTvSessionStore store;

  setUpAll(() {
    registerFallbackValue(_code);
  });

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    auth = _MockAuth();
    waits = [];
    viewer = '77';
    when(
      () => auth.validate(any()),
    ).thenAnswer((_) async => const TwitchTvValidation.valid('77'));
    when(() => auth.revoke(any())).thenAnswer((_) async {});
    store = TwitchTvSessionStore(
      auth: auth,
      viewerId: () => viewer,
      random: Random(1),
      wait: (delay) async => waits.add(delay),
    );
  });

  Future<String?> saved() => _storage.read(key: TwitchTvSessionBase.sessionKey);

  Future<void> storeSession([TwitchTvSession? session]) => _storage.write(
    key: TwitchTvSessionBase.sessionKey,
    value: (session ?? _stored()).encode(),
  );

  group('attach', () {
    test('adopts the stored session of the same account', () async {
      await storeSession();
      await store.attach('77');
      expect(store.status, TwitchTvSessionStatus.connected);
      expect(store.credentials!.session.accessToken, 'tv-access');
      expect(store.credentials!.clientSessionId, hasLength(32));
      verify(() => auth.validate('tv-access')).called(1);
    });

    test('deletes and revokes the stored session of another account', () async {
      await storeSession(_stored(user: '99'));
      await store.attach('77');
      expect(store.status, TwitchTvSessionStatus.disconnected);
      expect(store.credentials, isNull);
      expect(await saved(), isNull);
      verify(() => auth.revoke('tv-access')).called(1);
    });

    test('forgets and revokes a token Twitch says is someone else’s', () async {
      await storeSession();
      when(
        () => auth.validate(any()),
      ).thenAnswer((_) async => const TwitchTvValidation.valid('99'));
      await store.attach('77');
      expect(store.status, TwitchTvSessionStatus.disconnected);
      expect(await saved(), isNull);
      verify(() => auth.revoke('tv-access')).called(1);
    });

    test('keeps the session when Twitch cannot be reached', () async {
      await storeSession();
      when(
        () => auth.validate(any()),
      ).thenAnswer((_) async => const TwitchTvValidation.unknown());
      await store.attach('77');
      expect(store.status, TwitchTvSessionStatus.connected);
    });

    test('refreshes an invalid token when it can', () async {
      await storeSession();
      when(
        () => auth.validate('tv-access'),
      ).thenAnswer((_) async => const TwitchTvValidation.invalid());
      when(() => auth.refresh('r1')).thenAnswer(
        (_) async => const TwitchTvRefresh.granted(
          TwitchTvGrant(accessToken: 'fresh', refreshToken: 'r2'),
        ),
      );
      await store.attach('77');
      await pumpEventQueue();
      expect(store.status, TwitchTvSessionStatus.connected);
      expect(store.accessToken, 'fresh');
      final back = TwitchTvSession.decode(await saved())!;
      expect(back.accessToken, 'fresh');
      expect(back.refreshToken, 'r2');
      expect(back.deviceId, 'device00device00');
    });

    test('is expired when the token is invalid and cannot refresh', () async {
      await storeSession(_stored(refresh: null));
      when(
        () => auth.validate(any()),
      ).thenAnswer((_) async => const TwitchTvValidation.invalid());
      await store.attach('77');
      await pumpEventQueue();
      expect(store.status, TwitchTvSessionStatus.expired);
      expect(store.credentials, isNull);
    });
  });

  group('the live viewer', () {
    setUp(() async {
      await storeSession();
      await store.attach('77');
    });

    test('credentials go only to the viewer they belong to', () {
      expect(store.credentials, isNotNull);
      viewer = '99';
      expect(store.credentials, isNull);
      expect(store.accessToken, isNull);
      viewer = null;
      expect(store.credentials, isNull);
    });

    test('detaching drops the session in memory, not on disk', () async {
      store.detach();
      viewer = '77';
      expect(store.credentials, isNull);
      expect(await saved(), isNotNull);
      await store.attach('77');
      expect(store.credentials, isNotNull);
    });
  });

  group('refresh', () {
    setUp(() async {
      await storeSession();
      await store.attach('77');
    });

    test('a rejection by Twitch marks the session expired', () async {
      when(
        () => auth.refresh('r1'),
      ).thenAnswer((_) async => const TwitchTvRefresh.rejected());
      store.markRejected('tv-access');
      await pumpEventQueue();
      expect(store.status, TwitchTvSessionStatus.expired);
      expect(store.credentials, isNull);
    });

    test(
      'Twitch out of reach keeps the session and tries again later',
      () async {
        final answers = [
          const TwitchTvRefresh.unreachable(),
          const TwitchTvRefresh.granted(TwitchTvGrant(accessToken: 'later')),
        ];
        when(
          () => auth.refresh('r1'),
        ).thenAnswer((_) async => answers.removeAt(0));
        store.markRejected('tv-access');
        await pumpEventQueue();
        expect(store.status, TwitchTvSessionStatus.connected);
        expect(waits, contains(TwitchTvSessionBase.refreshRetry));
        expect(store.accessToken, 'later');
      },
    );

    test('a rejection of an older token is ignored', () async {
      store.markRejected('older-token');
      await pumpEventQueue();
      expect(store.status, TwitchTvSessionStatus.connected);
      verifyNever(() => auth.refresh(any()));
    });
  });

  group('device flow', () {
    setUp(() async {
      await store.attach('77');
    });

    test(
      'waits through pending and slow_down, then stores the grant',
      () async {
        final answers = <TwitchTvPoll>[
          const TwitchTvPollPending(),
          const TwitchTvPollSlowDown(),
          _granted,
        ];
        when(
          () => auth.pollToken(any()),
        ).thenAnswer((_) async => answers.removeAt(0));
        final outcome = await store.approve(_code, isCancelled: () => false);
        expect(outcome, TwitchTvConnectOutcome.connected);
        expect(waits, const [
          Duration(seconds: 5),
          Duration(seconds: 5),
          Duration(seconds: 10),
        ]);
        expect(store.status, TwitchTvSessionStatus.connected);
        final back = TwitchTvSession.decode(await saved())!;
        expect(back.accessToken, 'tv-new');
        expect(back.userId, '77');
        expect(back.deviceId, hasLength(32));
      },
    );

    test('slow_down clears the failure count', () async {
      final answers = <TwitchTvPoll>[
        const TwitchTvPollFailed(),
        const TwitchTvPollFailed(),
        const TwitchTvPollSlowDown(),
        const TwitchTvPollFailed(),
        const TwitchTvPollFailed(),
        _granted,
      ];
      when(
        () => auth.pollToken(any()),
      ).thenAnswer((_) async => answers.removeAt(0));
      expect(
        await store.approve(_code, isCancelled: () => false),
        TwitchTvConnectOutcome.connected,
      );
    });

    test('a check Twitch cannot answer is asked again', () async {
      final checks = [
        const TwitchTvValidation.unknown(),
        const TwitchTvValidation.valid('77'),
      ];
      when(() => auth.pollToken(any())).thenAnswer((_) async => _granted);
      when(
        () => auth.validate('tv-new'),
      ).thenAnswer((_) async => checks.removeAt(0));
      expect(
        await store.approve(_code, isCancelled: () => false),
        TwitchTvConnectOutcome.connected,
      );
      verifyNever(() => auth.revoke('tv-new'));
    });

    test('stops on an expired code', () async {
      when(
        () => auth.pollToken(any()),
      ).thenAnswer((_) async => const TwitchTvPollExpired());
      expect(
        await store.approve(_code, isCancelled: () => false),
        TwitchTvConnectOutcome.expired,
      );
      expect(store.status, TwitchTvSessionStatus.disconnected);
    });

    test('stops on a denial', () async {
      when(
        () => auth.pollToken(any()),
      ).thenAnswer((_) async => const TwitchTvPollDenied());
      expect(
        await store.approve(_code, isCancelled: () => false),
        TwitchTvConnectOutcome.denied,
      );
    });

    test('stops after three failures in a row', () async {
      when(
        () => auth.pollToken(any()),
      ).thenAnswer((_) async => const TwitchTvPollFailed());
      expect(
        await store.approve(_code, isCancelled: () => false),
        TwitchTvConnectOutcome.failed,
      );
      verify(() => auth.pollToken(any())).called(3);
    });

    test('refuses and revokes an approval from another account', () async {
      when(() => auth.pollToken(any())).thenAnswer(
        (_) async =>
            const TwitchTvPollGranted(TwitchTvGrant(accessToken: 'other')),
      );
      when(
        () => auth.validate('other'),
      ).thenAnswer((_) async => const TwitchTvValidation.valid('99'));
      expect(
        await store.approve(_code, isCancelled: () => false),
        TwitchTvConnectOutcome.wrongAccount,
      );
      expect(store.credentials, isNull);
      expect(await saved(), isNull);
      verify(() => auth.revoke('other')).called(1);
    });

    test('a grant after a cancel is revoked and not stored', () async {
      var cancelled = false;
      when(() => auth.pollToken(any())).thenAnswer((_) async {
        cancelled = true;
        return const TwitchTvPollGranted(TwitchTvGrant(accessToken: 'late'));
      });
      expect(
        await store.approve(_code, isCancelled: () => cancelled),
        TwitchTvConnectOutcome.cancelled,
      );
      expect(await saved(), isNull);
      verifyNever(() => auth.validate('late'));
      verify(() => auth.revoke('late')).called(1);
    });
  });

  group('clearing', () {
    setUp(() async {
      await storeSession();
      await store.attach('77');
    });

    test('forget deletes and revokes the session', () async {
      await store.forget();
      expect(store.status, TwitchTvSessionStatus.disconnected);
      expect(store.credentials, isNull);
      expect(await saved(), isNull);
      verify(() => auth.revoke('tv-access')).called(1);
    });

    test(
      'ending the account session clears the session and the prompt',
      () async {
        expect(await store.shouldPrompt(), isTrue);
        await store.markPrompted();
        expect(await store.shouldPrompt(), isFalse);
        await store.endAccountSession();
        expect(await saved(), isNull);
        expect(store.credentials, isNull);
        expect(await store.shouldPrompt(), isTrue);
        verify(() => auth.revoke('tv-access')).called(1);
      },
    );

    test('switching account drops the previous session', () async {
      viewer = '99';
      await store.attach('99');
      expect(store.credentials, isNull);
      expect(await saved(), isNull);
    });
  });

  test('a delete that fails at logout never brings the session back', () async {
    final storage = _MockStorage();
    when(
      () => storage.read(key: TwitchTvSessionBase.sessionKey),
    ).thenAnswer((_) async => _stored().encode());
    when(
      () => storage.read(key: TwitchTvSessionBase.promptedKey),
    ).thenAnswer((_) async => null);
    when(
      () => storage.delete(key: any(named: 'key')),
    ).thenThrow(Exception('keystore'));
    final failing = TwitchTvSessionStore(
      auth: auth,
      storage: storage,
      viewerId: () => viewer,
      wait: (_) async {},
    );
    await failing.attach('77');
    expect(failing.credentials, isNotNull);
    await failing.endAccountSession();
    await failing.attach('77');
    expect(failing.credentials, isNull);
    expect(failing.status, TwitchTvSessionStatus.disconnected);
  });
}
