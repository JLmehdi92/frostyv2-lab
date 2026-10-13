import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/base_api_client.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/apis/twitch_stream_service.dart';
import 'package:frosty/models/stream.dart';
import 'package:frosty/screens/channel/video/ivs_recovery.dart';
import 'package:frosty/screens/channel/video/stores/ivs_video_store.dart';
import 'package:frosty/screens/settings/stores/auth_store.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:mobx/mobx.dart' show reaction;
import 'package:mocktail/mocktail.dart';

import '../../../../fixtures/api_responses.dart';
import '../../../../helpers/fake_ivs_native.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

class MockAuthStore extends Mock implements AuthStore {}

class MockTwitchStreamService extends Mock implements TwitchStreamService {}

const _usherUrl = 'https://usher.ttvnw.net/api/channel/hls/streamer.m3u8?x=1';

void main() {
  late FakeIvsNative native;
  late MockTwitchApi twitchApi;
  late MockTwitchStreamService streamService;
  late SettingsStore settingsStore;
  late IvsVideoStore store;
  IvsVideoStore? created;

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  IvsRecoveryPolicy instantPolicy() => IvsRecoveryPolicy(
    backoff: const [Duration.zero, Duration.zero, Duration.zero],
  );

  Future<IvsVideoStore> createStore({IvsRecoveryPolicy? policy}) async {
    final s = IvsVideoStore(
      userLogin: 'streamer',
      userId: '123',
      twitchApi: twitchApi,
      authStore: MockAuthStore(),
      settingsStore: settingsStore,
      streamService: streamService,
      recoveryPolicy: policy ?? instantPolicy(),
    );
    created = s;
    await s.ready;
    for (var i = 0; i < 20 && s.textureId == null; i++) {
      await settle();
    }
    expect(s.textureId, isNotNull, reason: 'texture was never created');
    return s;
  }

  setUp(() {
    native = FakeIvsNative()..install();
    twitchApi = MockTwitchApi();
    streamService = MockTwitchStreamService();
    settingsStore = SettingsStore.fromJson({});

    when(
      () => streamService.getUsherUrl(userLogin: any(named: 'userLogin')),
    ).thenAnswer((_) async => _usherUrl);
    final live = StreamTwitch.fromJson(
      (twitchStreamResponse['data']! as List).first as Map<String, dynamic>,
    );
    when(
      () => twitchApi.getStream(userLogin: any(named: 'userLogin')),
    ).thenAnswer((_) async => live);
    when(
      () => twitchApi.getChannel(userId: any(named: 'userId')),
    ).thenThrow(Exception('offline in tests'));
  });

  tearDown(() {
    created?.dispose();
    created = null;
    native.uninstall();
  });

  test('creates the native texture with the usher url', () async {
    store = await createStore();

    final create = native.managerCalls.singleWhere((c) => c.method == 'create');
    expect((create.arguments as Map)['url'], _usherUrl);
    expect(store.textureId, native.textureId);
  });

  group('latency', () {
    test('shows latency with 0.1 s precision', () async {
      store = await createStore();

      await native.emit({'type': 'latency', 'ms': 2349});
      expect(store.latency, '2.3s');
      expect(store.latencyMs, 2349);

      await native.emit({'type': 'latency', 'ms': 2350});
      expect(store.latency, '2.4s');
    });

    test('ignores negative latency', () async {
      store = await createStore();

      await native.emit({'type': 'latency', 'ms': 1500});
      await native.emit({'type': 'latency', 'ms': -1});

      expect(store.latency, '1.5s');
      expect(store.latencyMs, 1500);
    });

    test('auto-synced chat delay only changes on whole seconds', () async {
      settingsStore.autoSyncChatDelay = true;
      store = await createStore();

      final synced = <double>[];
      final dispose = reaction(
        (_) => settingsStore.syncedChatDelay,
        synced.add,
      );

      for (final ms in [2400, 2600, 2700, 3400, 3600, 70000]) {
        await native.emit({'type': 'latency', 'ms': ms});
      }
      dispose();

      expect(synced, [2.0, 3.0, 4.0, 60.0]);
      expect(settingsStore.syncedChatDelay, 60.0);
    });

    test('does not touch the chat delay when auto-sync is off', () async {
      store = await createStore();

      await native.emit({'type': 'latency', 'ms': 4200});

      expect(settingsStore.syncedChatDelay, 0.0);
    });

    test('samples latency only while playing', () async {
      store = await createStore();
      expect(store.paused, isFalse, reason: 'stream is live in this test');

      await native.emit({'type': 'latency', 'ms': 9000});
      expect(store.latencySampler.count, 0);

      await native.emit({'type': 'state', 'state': 'PLAYING'});
      await native.emit({'type': 'latency', 'ms': 2000});
      await native.emit({'type': 'latency', 'ms': 3000});
      await native.emit({'type': 'state', 'state': 'BUFFERING'});
      await native.emit({'type': 'latency', 'ms': 8000});

      expect(store.latencySampler.count, 2);
      expect(store.latencySampler.max, 3000);
    });

    test('bumps samplesVersion on every sample and reset', () async {
      store = await createStore();
      await native.emit({'type': 'state', 'state': 'PLAYING'});
      final before = store.samplesVersion;

      await native.emit({'type': 'latency', 'ms': 2000});
      expect(store.samplesVersion, greaterThan(before));

      final afterSample = store.samplesVersion;
      store.resetStats();
      expect(store.samplesVersion, greaterThan(afterSample));
    });
  });

  group('stats', () {
    test('toggleStats enables native stats reporting', () async {
      store = await createStore();

      store.toggleStats();
      expect(store.statsVisible, isTrue);
      await settle();
      final call = native.callsNamed('setStatsEnabled').last;
      expect((call.arguments as Map)['enabled'], isTrue);

      store.toggleStats();
      expect(store.statsVisible, isFalse);
      await settle();
      expect(
        (native.callsNamed('setStatsEnabled').last.arguments as Map)['enabled'],
        isFalse,
      );
    });

    test('ignores stats that arrive while the panel is hidden', () async {
      store = await createStore();

      await native.emit({'type': 'stats', 'bitrate': 6000000});

      expect(store.stats, isNull);
    });

    test('stores the latest stats event', () async {
      store = await createStore();
      store.toggleStats();

      await native.emit({
        'type': 'stats',
        'bitrate': 6000000,
        'fps': 60,
        'bufferedMs': 1100,
        'lowLatency': true,
      });

      expect(store.stats?.bitrate, 6000000);
      expect(store.stats?.fps, 60);
      expect(store.stats?.lowLatency, isTrue);
    });

    test('counts rebuffers and records startup time', () async {
      store = await createStore();

      expect(store.startupMs, isNull);
      await native.emit({'type': 'state', 'state': 'PLAYING'});
      expect(store.startupMs, isNotNull);

      await native.emit({'type': 'rebuffering'});
      await native.emit({'type': 'rebuffering'});
      expect(store.rebufferCount, 2);
    });

    test('refresh restarts the startup measurement', () async {
      store = await createStore();
      await native.emit({'type': 'state', 'state': 'PLAYING'});
      expect(store.startupMs, isNotNull);

      await store.handleRefresh();
      expect(store.startupMs, isNull);

      await native.emit({'type': 'state', 'state': 'PLAYING'});
      expect(store.startupMs, isNotNull);
    });

    test('resetStats clears samples and rebuffers', () async {
      store = await createStore();
      await native.emit({'type': 'state', 'state': 'PLAYING'});
      await native.emit({'type': 'latency', 'ms': 2000});
      await native.emit({'type': 'rebuffering'});

      store.resetStats();

      expect(store.latencySampler.count, 0);
      expect(store.rebufferCount, 0);
    });
  });

  group('error recovery', () {
    test(
      'retries recoverable errors on the same texture then falls back',
      () async {
        var fatal = 0;
        var n = 0;
        when(
          () => streamService.getUsherUrl(userLogin: any(named: 'userLogin')),
        ).thenAnswer((_) async => '$_usherUrl&n=${n++}');
        store = await createStore();
        store.onFatalError = () => fatal++;

        for (var i = 0; i < 3; i++) {
          await native.emit({'type': 'error', 'errorType': 'ERROR_NETWORK'});
          expect(store.status, IvsPlaybackStatus.reconnecting);
          await settle();
          await settle();
        }

        final loads = native.callsNamed('load').toList();
        expect(loads, hasLength(3));
        expect(
          loads.map((c) => (c.arguments as Map)['url']).toSet(),
          hasLength(3),
          reason: 'each retry uses a freshly fetched usher url',
        );
        expect(
          native.managerCalls.where((c) => c.method == 'create'),
          hasLength(1),
        );
        expect(fatal, 0);

        await native.emit({'type': 'error', 'errorType': 'ERROR_NETWORK'});
        expect(fatal, 1);
        expect(store.status, IvsPlaybackStatus.failed);
      },
    );

    test('recovers to playing after a successful retry', () async {
      store = await createStore();

      await native.emit({'type': 'error', 'errorType': 'ERROR_TIMEOUT'});
      await settle();
      await settle();
      expect(native.callsNamed('load'), hasLength(1));
      await native.emit({'type': 'state', 'state': 'PLAYING'});

      expect(store.status, IvsPlaybackStatus.playing);
      expect(store.retryAttempt, 1);
    });

    test('a not-available error on an offline channel shows offline', () async {
      var fatal = 0;
      store = await createStore();
      store.onFatalError = () => fatal++;
      when(
        () => twitchApi.getStream(userLogin: any(named: 'userLogin')),
      ).thenThrow(const NotFoundException('offline'));

      await native.emit({'type': 'error', 'errorType': 'ERROR_NOT_AVAILABLE'});
      for (var i = 0; i < 5; i++) {
        await settle();
      }

      expect(store.status, IvsPlaybackStatus.offline);
      expect(store.paused, isTrue);
      expect(fatal, 0);
    });

    test('a not-available error on a live channel is retried', () async {
      store = await createStore();

      await native.emit({'type': 'error', 'errorType': 'ERROR_NOT_AVAILABLE'});
      for (var i = 0; i < 5; i++) {
        await settle();
      }

      expect(native.callsNamed('load'), hasLength(1));
    });

    test('fatal errors fall back immediately', () async {
      var fatal = 0;
      store = await createStore();
      store.onFatalError = () => fatal++;

      await native.emit({'type': 'error', 'errorType': 'ERROR_NOT_SUPPORTED'});

      expect(fatal, 1);
      expect(native.callsNamed('load'), isEmpty);
    });

    test('no reload happens after dispose', () async {
      store = await createStore(
        policy: IvsRecoveryPolicy(backoff: const [Duration(milliseconds: 30)]),
      );

      await native.emit({'type': 'error', 'errorType': 'ERROR_NETWORK'});
      store.dispose();
      created = null;
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(native.callsNamed('load'), isEmpty);
    });

    test('manual refresh resets the retry budget', () async {
      var fatal = 0;
      store = await createStore();
      store.onFatalError = () => fatal++;

      for (var i = 0; i < 3; i++) {
        await native.emit({'type': 'error', 'errorType': 'ERROR_NETWORK'});
        await settle();
      }
      await store.handleRefresh();
      await native.emit({'type': 'error', 'errorType': 'ERROR_NETWORK'});

      expect(fatal, 0);
      expect(store.status, IvsPlaybackStatus.reconnecting);
    });
  });

  group('token fetch', () {
    test(
      'retries transient token failures before creating the player',
      () async {
        var calls = 0;
        when(
          () => streamService.getUsherUrl(userLogin: any(named: 'userLogin')),
        ).thenAnswer((_) async {
          calls++;
          if (calls < 3) throw const NetworkException('flaky');
          return _usherUrl;
        });

        store = await createStore();

        expect(calls, 3);
        expect(store.textureId, native.textureId);
      },
    );

    test('does not retry when the channel has no token (offline)', () async {
      var calls = 0;
      when(
        () => streamService.getUsherUrl(userLogin: any(named: 'userLogin')),
      ).thenAnswer((_) async {
        calls++;
        throw const ApiException('No playback access token');
      });

      final s = IvsVideoStore(
        userLogin: 'streamer',
        userId: '123',
        twitchApi: twitchApi,
        authStore: MockAuthStore(),
        settingsStore: settingsStore,
        streamService: streamService,
        recoveryPolicy: instantPolicy(),
      );
      created = s;

      await expectLater(s.ready, throwsA(isA<ApiException>()));
      expect(calls, 1);
    });
  });

  group('recovery robustness', () {
    test('waits for the backoff delay before reloading', () async {
      store = await createStore(
        policy: IvsRecoveryPolicy(backoff: const [Duration(milliseconds: 200)]),
      );

      await native.emit({'type': 'error', 'errorType': 'ERROR_NETWORK'});
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(native.callsNamed('load'), isEmpty);

      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(native.callsNamed('load'), hasLength(1));
    });

    test('a burst of errors uses a single retry', () async {
      var fatal = 0;
      store = await createStore(
        policy: IvsRecoveryPolicy(
          backoff: const [
            Duration(milliseconds: 30),
            Duration(milliseconds: 30),
            Duration(milliseconds: 30),
          ],
        ),
      );
      store.onFatalError = () => fatal++;

      for (var i = 0; i < 4; i++) {
        await native.emit({'type': 'error', 'errorType': 'ERROR_NETWORK'});
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));

      expect(fatal, 0);
      expect(native.callsNamed('load'), hasLength(1));
      expect(store.retryAttempt, 1);
    });

    test('an error during a reload does not start a second reload', () async {
      store = await createStore();
      final gate = Completer<String>();
      when(
        () => streamService.getUsherUrl(userLogin: any(named: 'userLogin')),
      ).thenAnswer((_) => gate.future);

      await native.emit({'type': 'error', 'errorType': 'ERROR_NETWORK'});
      await settle();
      await native.emit({'type': 'error', 'errorType': 'ERROR_NETWORK'});
      await settle();
      gate.complete(_usherUrl);
      for (var i = 0; i < 4; i++) {
        await settle();
      }

      expect(native.callsNamed('load'), hasLength(1));
      expect(store.retryAttempt, 1);
    });

    test('fatal errors still fall back while a retry is pending', () async {
      var fatal = 0;
      store = await createStore(
        policy: IvsRecoveryPolicy(backoff: const [Duration(milliseconds: 50)]),
      );
      store.onFatalError = () => fatal++;

      await native.emit({'type': 'error', 'errorType': 'ERROR_NETWORK'});
      await native.emit({'type': 'error', 'errorType': 'ERROR_NOT_SUPPORTED'});

      expect(fatal, 1);
      // The pending retry must not reload a failed player (e.g. minimised).
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(native.callsNamed('load'), isEmpty);
    });

    test('stale offline checks are ignored after a manual refresh', () async {
      store = await createStore();
      final helix = Completer<StreamTwitch>();
      final live = StreamTwitch.fromJson(
        (twitchStreamResponse['data']! as List).first as Map<String, dynamic>,
      );
      var helixCalls = 0;
      // Only the offline check started before the refresh is slow; the
      // refresh itself sees the channel live.
      when(
        () => twitchApi.getStream(userLogin: any(named: 'userLogin')),
      ).thenAnswer(
        (_) => helixCalls++ == 0 ? helix.future : Future.value(live),
      );

      await native.emit({'type': 'error', 'errorType': 'ERROR_NOT_AVAILABLE'});
      await settle();
      final refresh = store.handleRefresh();
      await native.emit({'type': 'state', 'state': 'PLAYING'});
      helix.completeError(const NotFoundException('offline'));
      await refresh.catchError((Object _) {});
      for (var i = 0; i < 4; i++) {
        await settle();
      }

      expect(store.status, IvsPlaybackStatus.playing);
      expect(store.paused, isFalse);
    });

    test(
      'a failed reload token fetch on an offline channel shows offline',
      () async {
        store = await createStore();
        when(
          () => twitchApi.getStream(userLogin: any(named: 'userLogin')),
        ).thenThrow(const NotFoundException('offline'));
        when(
          () => streamService.getUsherUrl(userLogin: any(named: 'userLogin')),
        ).thenThrow(const ApiException('No playback access token'));

        await native.emit({'type': 'error', 'errorType': 'ERROR_NETWORK'});
        for (var i = 0; i < 6; i++) {
          await settle();
        }

        expect(store.status, IvsPlaybackStatus.offline);
      },
    );
  });

  group('native player lifecycle', () {
    test('disposing during creation releases the native player', () async {
      native.createGate = Completer<void>();
      final s = IvsVideoStore(
        userLogin: 'streamer',
        userId: '123',
        twitchApi: twitchApi,
        authStore: MockAuthStore(),
        settingsStore: settingsStore,
        streamService: streamService,
        recoveryPolicy: instantPolicy(),
      );
      await s.ready;
      await settle();
      s.dispose();
      native.createGate!.complete();
      for (var i = 0; i < 4; i++) {
        await settle();
      }

      final dispose = native.managerCalls.where((c) => c.method == 'dispose');
      expect(dispose, hasLength(1));
      expect((dispose.single.arguments as Map)['textureId'], native.textureId);
      expect(s.textureId, isNull);
    });

    test('a failed texture creation falls back to the web player', () async {
      native.createThrows = true;
      var fatal = 0;
      final s = IvsVideoStore(
        userLogin: 'streamer',
        userId: '123',
        twitchApi: twitchApi,
        authStore: MockAuthStore(),
        settingsStore: settingsStore,
        streamService: streamService,
        recoveryPolicy: instantPolicy(),
      )..onFatalError = () => fatal++;
      created = s;
      await s.ready;
      for (var i = 0; i < 4; i++) {
        await settle();
      }

      expect(fatal, 1);
      expect(s.status, IvsPlaybackStatus.failed);
    });

    test('a failed initial url lookup leaves a final status', () async {
      when(
        () => streamService.getUsherUrl(userLogin: any(named: 'userLogin')),
      ).thenThrow(const ApiException('No playback access token'));
      final s = IvsVideoStore(
        userLogin: 'streamer',
        userId: '123',
        twitchApi: twitchApi,
        authStore: MockAuthStore(),
        settingsStore: settingsStore,
        streamService: streamService,
        recoveryPolicy: instantPolicy(),
      );
      created = s;
      await s.ready.catchError((Object _) {});
      await settle();

      expect(s.status, IvsPlaybackStatus.offline);
    });
  });
}
