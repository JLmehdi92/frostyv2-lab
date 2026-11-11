import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_tv_auth_service.dart';
import 'package:onset/models/twitch_tv_session.dart';
import 'package:onset/screens/settings/stores/twitch_tv_session_store.dart';

class _MockAuth extends Mock implements TwitchTvAuthService {}

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

void main() {
  late _MockAuth auth;
  late List<Duration> waits;
  late TwitchTvSessionStore store;

  setUpAll(() {
    registerFallbackValue(_code);
  });

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    auth = _MockAuth();
    waits = [];
    when(
      () => auth.validate(any()),
    ).thenAnswer((_) async => const TwitchTvValidation.valid('77'));
    store = TwitchTvSessionStore(
      auth: auth,
      random: Random(1),
      wait: (delay) async => waits.add(delay),
    );
  });

  Future<String?> saved() => _storage.read(key: TwitchTvSessionBase.sessionKey);

  group('attach', () {
    test('adopts the stored session of the same account', () async {
      await _storage.write(
        key: TwitchTvSessionBase.sessionKey,
        value: _stored().encode(),
      );
      await store.attach('77');
      expect(store.status, TwitchTvSessionStatus.connected);
      expect(store.credentials!.session.accessToken, 'tv-access');
      expect(store.credentials!.clientSessionId, hasLength(32));
      verify(() => auth.validate('tv-access')).called(1);
    });

    test('deletes the stored session of another account', () async {
      await _storage.write(
        key: TwitchTvSessionBase.sessionKey,
        value: _stored(user: '99').encode(),
      );
      await store.attach('77');
      expect(store.status, TwitchTvSessionStatus.disconnected);
      expect(store.credentials, isNull);
      expect(await saved(), isNull);
    });

    test('forgets a token Twitch says belongs to someone else', () async {
      await _storage.write(
        key: TwitchTvSessionBase.sessionKey,
        value: _stored().encode(),
      );
      when(
        () => auth.validate(any()),
      ).thenAnswer((_) async => const TwitchTvValidation.valid('99'));
      await store.attach('77');
      expect(store.status, TwitchTvSessionStatus.disconnected);
      expect(await saved(), isNull);
    });

    test('keeps the session when Twitch cannot be reached', () async {
      await _storage.write(
        key: TwitchTvSessionBase.sessionKey,
        value: _stored().encode(),
      );
      when(
        () => auth.validate(any()),
      ).thenAnswer((_) async => const TwitchTvValidation.unknown());
      await store.attach('77');
      expect(store.status, TwitchTvSessionStatus.connected);
    });

    test('refreshes an invalid token when it can', () async {
      await _storage.write(
        key: TwitchTvSessionBase.sessionKey,
        value: _stored().encode(),
      );
      when(
        () => auth.validate('tv-access'),
      ).thenAnswer((_) async => const TwitchTvValidation.invalid());
      when(
        () => auth.validate('fresh'),
      ).thenAnswer((_) async => const TwitchTvValidation.valid('77'));
      when(() => auth.refresh('r1')).thenAnswer(
        (_) async =>
            const TwitchTvGrant(accessToken: 'fresh', refreshToken: 'r2'),
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
      await _storage.write(
        key: TwitchTvSessionBase.sessionKey,
        value: _stored(refresh: null).encode(),
      );
      when(
        () => auth.validate(any()),
      ).thenAnswer((_) async => const TwitchTvValidation.invalid());
      await store.attach('77');
      await pumpEventQueue();
      expect(store.status, TwitchTvSessionStatus.expired);
      expect(store.credentials, isNull);
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
          const TwitchTvPollGranted(
            TwitchTvGrant(accessToken: 'tv-new', refreshToken: 'tv-r'),
          ),
        ];
        when(
          () => auth.pollToken(any()),
        ).thenAnswer((_) async => answers.removeAt(0));
        when(
          () => auth.validate('tv-new'),
        ).thenAnswer((_) async => const TwitchTvValidation.valid('77'));
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

    test('refuses an approval from another Twitch account', () async {
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
    });

    test('a cancel stops polling and stores nothing', () async {
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
    });
  });

  group('clearing', () {
    setUp(() async {
      await _storage.write(
        key: TwitchTvSessionBase.sessionKey,
        value: _stored().encode(),
      );
      await store.attach('77');
    });

    test('forget deletes the session', () async {
      await store.forget();
      expect(store.status, TwitchTvSessionStatus.disconnected);
      expect(store.credentials, isNull);
      expect(await saved(), isNull);
    });

    test(
      'ending the account session clears the session and the prompt',
      () async {
        expect(await store.takePrompt(), isTrue);
        expect(await store.takePrompt(), isFalse);
        await store.endAccountSession();
        expect(await saved(), isNull);
        expect(store.credentials, isNull);
        expect(await store.takePrompt(), isTrue);
      },
    );

    test('switching account drops the previous session', () async {
      await store.attach('99');
      expect(store.credentials, isNull);
      expect(await saved(), isNull);
    });

    test('a rejection marks it expired until a refresh works', () async {
      when(() => auth.refresh('r1')).thenAnswer((_) async => null);
      store.markRejected();
      expect(store.status, TwitchTvSessionStatus.expired);
      expect(store.credentials, isNull);
      await pumpEventQueue();
      expect(store.status, TwitchTvSessionStatus.expired);
    });
  });
}
