import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_vod_service.dart';
import 'package:frosty/screens/channel/video/ivs_recovery.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/screens/vod/stores/ivs_vod_store.dart';
import 'package:frosty/screens/vod/vod_player_controller.dart';
import 'package:mobx/mobx.dart' show reaction;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/fake_ivs_native.dart';

class MockTwitchVodService extends Mock implements TwitchVodService {}

const _url = 'https://usher.ttvnw.net/vod/123.m3u8?x=1';

void main() {
  late FakeIvsNative native;
  late MockTwitchVodService service;
  late SettingsStore settingsStore;
  late IvsVodStore store;
  IvsVodStore? created;

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  IvsRecoveryPolicy instantPolicy() => IvsRecoveryPolicy(
    backoff: const [Duration.zero, Duration.zero, Duration.zero],
  );

  IvsVodStore build({
    Duration startAt = Duration.zero,
    Duration? knownLength = const Duration(hours: 2),
    IvsRecoveryPolicy? policy,
  }) {
    final s = IvsVodStore(
      vodId: '123',
      vodService: service,
      settingsStore: settingsStore,
      startAt: startAt,
      knownLength: knownLength,
      recoveryPolicy: policy ?? instantPolicy(),
    );
    created = s;
    return s;
  }

  Future<IvsVodStore> createStore({
    Duration startAt = Duration.zero,
    Duration? knownLength = const Duration(hours: 2),
    IvsRecoveryPolicy? policy,
  }) async {
    final s = build(startAt: startAt, knownLength: knownLength, policy: policy);
    await s.ready;
    for (var i = 0; i < 20 && native.callsNamed('load').isEmpty; i++) {
      await settle();
    }
    expect(native.callsNamed('load'), hasLength(1), reason: 'initial load');
    return s;
  }

  void stubUrl({bool fresh = false}) => when(
    () => service.getVodUsherUrl(
      vodId: any(named: 'vodId'),
      forceFreshToken: any(named: 'forceFreshToken'),
    ),
  ).thenAnswer((_) async => _url);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    native = FakeIvsNative()..install();
    service = MockTwitchVodService();
    settingsStore = SettingsStore.fromJson({});
    stubUrl();
  });

  tearDown(() {
    created?.dispose();
    created = null;
    native.uninstall();
  });

  group('loading', () {
    test(
      'creates a vod player and loads the usher url from the start',
      () async {
        store = await createStore();

        final create = native.managerCalls.singleWhere(
          (c) => c.method == 'create',
        );
        expect((create.arguments as Map)['config'], {'vod': true});
        final load = native.callsNamed('load').single.arguments as Map;
        expect(load['url'], _url);
        expect(load['startMs'], 0);
        expect(store.status, VodPlaybackStatus.loading);
      },
    );

    test('starts at the requested position', () async {
      store = await createStore(startAt: const Duration(milliseconds: 1234000));

      expect(
        (native.callsNamed('load').single.arguments as Map)['startMs'],
        1234000,
      );
      expect(store.position, const Duration(milliseconds: 1234000));
    });

    test('a forbidden vod is a problem, not a fallback', () async {
      when(
        () => service.getVodUsherUrl(
          vodId: any(named: 'vodId'),
          forceFreshToken: any(named: 'forceFreshToken'),
        ),
      ).thenThrow(const VodForbiddenException('geoblocked'));
      var fatal = 0;
      final s = build()..onFatalError = () => fatal++;
      await s.ready.catchError((Object _) {});
      for (var i = 0; i < 4; i++) {
        await settle();
      }

      expect(s.status, VodPlaybackStatus.problem);
      expect(s.problem, VodPlaybackProblem.geoBlocked);
      expect(fatal, 0);
      expect(native.callsNamed('load'), isEmpty);
    });
  });

  group('progress', () {
    test('updates position, duration and buffer', () async {
      store = await createStore();

      await native.emitProgress(61500, durationMs: 7200000, bufferedMs: 70000);

      expect(store.position, const Duration(milliseconds: 61500));
      expect(store.duration, const Duration(hours: 2));
      expect(store.buffered, const Duration(milliseconds: 70000));
      expect(store.positionSeconds, 61);
    });

    test('positionSeconds only changes on whole seconds', () async {
      store = await createStore();
      await native.emitProgress(1000);
      final seconds = <int>[];
      final dispose = reaction((_) => store.positionSeconds, seconds.add);

      for (final ms in [1250, 1500, 1750, 2000, 2250, 3100]) {
        await native.emitProgress(ms);
      }
      dispose();

      expect(seconds, [2, 3]);
    });

    test('an unknown duration falls back to the known length', () async {
      store = await createStore(knownLength: const Duration(minutes: 90));

      await native.emitProgress(1000, durationMs: -1);
      expect(store.duration, const Duration(minutes: 90));

      await native.emitProgress(1000, durationMs: 1 << 62);
      expect(store.duration, const Duration(minutes: 90));
    });
  });

  group('seeking', () {
    test('seekTo clamps and updates the position optimistically', () async {
      store = await createStore();
      await native.emitProgress(1000, durationMs: 100000);

      store.seekTo(const Duration(seconds: 30));
      expect(store.position, const Duration(seconds: 30));
      await settle();
      expect((native.callsNamed('seekTo').last.arguments as Map)['ms'], 30000);

      store.seekTo(const Duration(seconds: -5));
      await settle();
      expect((native.callsNamed('seekTo').last.arguments as Map)['ms'], 0);

      store.seekTo(const Duration(hours: 9));
      await settle();
      expect(
        (native.callsNamed('seekTo').last.arguments as Map)['ms'],
        99000,
        reason: 'clamped to one second before the end',
      );
    });

    test('seekBy is relative and clamped', () async {
      store = await createStore();
      await native.emitProgress(5000, durationMs: 100000);

      store.seekBy(const Duration(seconds: -10));
      await settle();
      expect((native.callsNamed('seekTo').last.arguments as Map)['ms'], 0);
      await native.emit({'type': 'seeked', 'ms': 0});

      await native.emitProgress(90000, durationMs: 100000);
      store.seekBy(const Duration(seconds: 30));
      await settle();
      expect((native.callsNamed('seekTo').last.arguments as Map)['ms'], 99000);
    });

    test('progress does not jump back while a seek is pending', () async {
      store = await createStore();
      await native.emitProgress(5000, durationMs: 100000);

      store.seekTo(const Duration(seconds: 60));
      await native.emitProgress(5250, durationMs: 100000);
      expect(store.position, const Duration(seconds: 60));

      await native.emit({'type': 'seeked', 'ms': 60000});
      await native.emitProgress(60250, durationMs: 100000);
      expect(store.position, const Duration(milliseconds: 60250));
    });

    test('a progress tick at the seek target ends the seek', () async {
      store = await createStore();
      await native.emitProgress(5000, durationMs: 100000);

      store.seekTo(const Duration(seconds: 60));
      await native.emitProgress(60400, durationMs: 100000);
      await native.emitProgress(61000, durationMs: 100000);

      expect(store.position, const Duration(seconds: 61));
    });
  });

  group('rate', () {
    test('sends allowed rates and ignores others', () async {
      store = await createStore();

      store.setPlaybackRate(1.25);
      await settle();
      expect(store.playbackRate, 1.25);
      expect(
        (native.callsNamed('setPlaybackRate').single.arguments as Map)['rate'],
        1.25,
      );

      store.setPlaybackRate(3);
      await settle();
      expect(store.playbackRate, 1.25);
      expect(native.callsNamed('setPlaybackRate'), hasLength(1));
    });

    test('rate is re-sent after a reload', () async {
      store = await createStore();
      store.setPlaybackRate(1.5);
      await settle();
      native.playerCalls.clear();

      await native.emit({
        'type': 'qualities',
        'list': ['1080p60', '720p60'],
      });
      await settle();

      expect(
        (native.callsNamed('setPlaybackRate').single.arguments as Map)['rate'],
        1.5,
      );
    });
  });

  group('state', () {
    test('maps native states', () async {
      store = await createStore();

      await native.emit({'type': 'state', 'state': 'PLAYING'});
      expect(store.status, VodPlaybackStatus.playing);
      expect(store.paused, isFalse);

      await native.emit({'type': 'state', 'state': 'BUFFERING'});
      expect(store.status, VodPlaybackStatus.buffering);

      await native.emit({'type': 'state', 'state': 'READY'});
      expect(store.status, VodPlaybackStatus.paused);
      expect(store.paused, isTrue);
    });

    test('play after the end restarts from the beginning', () async {
      store = await createStore();
      await native.emit({'type': 'state', 'state': 'ENDED'});
      expect(store.ended, isTrue);

      store.play();
      await settle();

      expect((native.callsNamed('seekTo').single.arguments as Map)['ms'], 0);
      expect(native.callsNamed('play'), hasLength(1));
      expect(store.ended, isFalse);
    });

    test('togglePlay pauses and resumes', () async {
      store = await createStore();
      await native.emit({'type': 'state', 'state': 'PLAYING'});

      store.togglePlay();
      await settle();
      expect(native.callsNamed('pause'), hasLength(1));

      await native.emit({'type': 'state', 'state': 'READY'});
      store.togglePlay();
      await settle();
      expect(native.callsNamed('play'), hasLength(1));
    });
  });

  group('quality and sound', () {
    test('restores the saved quality', () async {
      SharedPreferences.setMockInitialValues({'last_stream_quality': '720p60'});
      store = await createStore();

      await native.emit({
        'type': 'qualities',
        'list': ['1080p60', '720p60'],
      });
      await settle();

      expect(
        (native.callsNamed('setQuality').single.arguments as Map)['name'],
        '720p60',
      );
      expect(store.quality, '720p60');
      expect(store.qualities, ['Auto', '1080p60', '720p60']);
    });

    test('mute and volume are re-sent after a load', () async {
      store = await createStore();
      store
        ..setVolume(0.4)
        ..toggleMute();
      await settle();
      native.playerCalls.clear();

      await native.emit({
        'type': 'qualities',
        'list': ['1080p60'],
      });
      await settle();

      expect(
        (native.callsNamed('setMuted').single.arguments as Map)['muted'],
        isTrue,
      );
      expect(
        (native.callsNamed('setVolume').single.arguments as Map)['volume'],
        0.4,
      );
    });
  });

  group('errors', () {
    test('a recoverable error reloads at the current position', () async {
      store = await createStore();
      await native.emitProgress(42000, durationMs: 100000);
      native.playerCalls.clear();

      await native.emit({'type': 'error', 'errorType': 'ERROR_NETWORK'});
      await settle();
      await settle();

      final load = native.callsNamed('load').single.arguments as Map;
      expect(load['startMs'], 42000);
      expect(store.status, VodPlaybackStatus.loading);
    });

    test('an authorization error forces a fresh token', () async {
      store = await createStore();

      await native.emit({'type': 'error', 'errorType': 'ERROR_AUTHORIZATION'});
      await settle();
      await settle();

      verify(
        () => service.getVodUsherUrl(vodId: '123', forceFreshToken: true),
      ).called(1);
    });

    test('not available is diagnosed as a playback problem', () async {
      when(
        () => service.diagnoseVodPlaylist(any()),
      ).thenAnswer((_) async => VodPlaybackProblem.subscriberOnly);
      var fatal = 0;
      store = await createStore();
      store.onFatalError = () => fatal++;

      await native.emit({'type': 'error', 'errorType': 'ERROR_NOT_AVAILABLE'});
      for (var i = 0; i < 4; i++) {
        await settle();
      }

      expect(store.status, VodPlaybackStatus.problem);
      expect(store.problem, VodPlaybackProblem.subscriberOnly);
      expect(fatal, 0);
    });

    test('a fatal error falls back once', () async {
      var fatal = 0;
      store = await createStore();
      store.onFatalError = () => fatal++;

      await native.emit({'type': 'error', 'errorType': 'ERROR_NOT_SUPPORTED'});
      await native.emit({'type': 'error', 'errorType': 'ERROR_NOT_SUPPORTED'});

      expect(fatal, 1);
      expect(store.status, VodPlaybackStatus.failed);
    });

    test('a burst of errors uses a single retry', () async {
      store = await createStore(
        policy: IvsRecoveryPolicy(
          backoff: const [
            Duration(milliseconds: 30),
            Duration(milliseconds: 30),
            Duration(milliseconds: 30),
          ],
        ),
      );
      native.playerCalls.clear();

      for (var i = 0; i < 4; i++) {
        await native.emit({'type': 'error', 'errorType': 'ERROR_NETWORK'});
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(native.callsNamed('load'), hasLength(1));
    });
  });

  group('lifecycle', () {
    test('dispose during creation releases the native player', () async {
      native.createGate = Completer<void>();
      final s = build();
      await s.ready;
      await settle();
      s.dispose();
      created = null;
      native.createGate!.complete();
      for (var i = 0; i < 4; i++) {
        await settle();
      }

      expect(
        native.managerCalls.where((c) => c.method == 'dispose'),
        hasLength(1),
      );
      expect(native.callsNamed('load'), isEmpty);
    });

    test('dispose before the url resolves never loads', () async {
      final url = Completer<String>();
      when(
        () => service.getVodUsherUrl(
          vodId: any(named: 'vodId'),
          forceFreshToken: any(named: 'forceFreshToken'),
        ),
      ).thenAnswer((_) => url.future);
      final s = build();
      for (var i = 0; i < 4; i++) {
        await settle();
      }
      s.dispose();
      created = null;
      url.complete(_url);
      for (var i = 0; i < 4; i++) {
        await settle();
      }

      expect(native.callsNamed('load'), isEmpty);
    });

    test('currentPositionForSave asks the native player', () async {
      store = await createStore();
      native.nativePosition = 777000;

      expect(
        await store.currentPositionForSave(),
        const Duration(milliseconds: 777000),
      );
    });

    test('currentPositionForSave falls back to the last progress', () async {
      store = await createStore();
      await native.emitProgress(5000);

      expect(await store.currentPositionForSave(), const Duration(seconds: 5));
    });
  });
}
