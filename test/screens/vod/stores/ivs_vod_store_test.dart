import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/base_api_client.dart';
import 'package:frosty/apis/twitch_vod_service.dart';
import 'package:frosty/screens/channel/video/ivs_recovery.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/screens/vod/stores/ivs_vod_store.dart';
import 'package:frosty/screens/vod/vod_player_controller.dart';
import 'package:mobx/mobx.dart' show reaction;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../fixtures/vod_responses.dart';
import '../../../helpers/fake_ivs_native.dart';

class MockTwitchVodService extends Mock implements TwitchVodService {}

const _url = 'https://usher.ttvnw.net/vod/123.m3u8?x=1';

/// A playlist whose token was asked as the viewer (it names them).
final _viewerUrl =
    'https://usher.ttvnw.net/vod/123.m3u8?sig=s&token='
    '${Uri.encodeQueryComponent(vodTokenAuthValue)}';

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
    Duration overlayHideDelay = const Duration(seconds: 5),
    Duration seekTimeout = const Duration(seconds: 3),
  }) {
    final s = IvsVodStore(
      vodId: '123',
      vodService: service,
      settingsStore: settingsStore,
      startAt: startAt,
      knownLength: knownLength,
      recoveryPolicy: policy ?? instantPolicy(),
      overlayHideDelay: overlayHideDelay,
      seekTimeout: seekTimeout,
    );
    created = s;
    return s;
  }

  Future<IvsVodStore> createStore({
    Duration startAt = Duration.zero,
    Duration? knownLength = const Duration(hours: 2),
    IvsRecoveryPolicy? policy,
    Duration overlayHideDelay = const Duration(seconds: 5),
    Duration seekTimeout = const Duration(seconds: 3),
  }) async {
    final s = build(
      startAt: startAt,
      knownLength: knownLength,
      policy: policy,
      overlayHideDelay: overlayHideDelay,
      seekTimeout: seekTimeout,
    );
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

  Future<void> settleMany([int n = 6]) async {
    for (var i = 0; i < n; i++) {
      await settle();
    }
  }

  void stubUrlSequence(List<Object> answers) {
    var i = 0;
    when(
      () => service.getVodUsherUrl(
        vodId: any(named: 'vodId'),
        forceFreshToken: any(named: 'forceFreshToken'),
      ),
    ).thenAnswer((_) async {
      final answer = answers[i < answers.length ? i : answers.length - 1];
      i++;
      if (answer is String) return answer;
      throw answer;
    });
  }

  List<int> loadStarts() => [
    for (final c in native.callsNamed('load'))
      (c.arguments as Map)['startMs'] as int,
  ];

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
      await native.emit({'type': 'seeked', 'ms': 0});

      await native.emitProgress(61500, durationMs: 7200000, bufferedMs: 70000);

      expect(store.position, const Duration(milliseconds: 61500));
      expect(store.duration, const Duration(hours: 2));
      expect(store.buffered, const Duration(milliseconds: 70000));
      expect(store.positionSeconds, 61);
    });

    test('positionSeconds only changes on whole seconds', () async {
      store = await createStore();
      await native.emit({'type': 'seeked', 'ms': 0});
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
      await native.emit({'type': 'seeked', 'ms': 0});
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
      await native.emit({'type': 'seeked', 'ms': 0});
      await native.emit({'type': 'state', 'state': 'PLAYING'});
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

  group('start position', () {
    test('ticks before the start seek do not move the position', () async {
      store = await createStore(startAt: const Duration(hours: 1));

      await native.emitProgress(0, durationMs: 7200000);
      expect(store.position, const Duration(hours: 1));
      expect(store.positionSeconds, 3600);

      await native.emit({'type': 'seeked', 'ms': 3600000});
      await native.emitProgress(3600250, durationMs: 7200000);
      expect(store.position, const Duration(milliseconds: 3600250));
    });

    test('a second error during a reload keeps the resume point', () async {
      store = await createStore(startAt: const Duration(hours: 1));
      await native.emit({'type': 'seeked', 'ms': 3600000});
      await native.emitProgress(3700000, durationMs: 7200000);

      await native.emit({'type': 'error', 'errorType': 'ERROR_NETWORK'});
      await settleMany();
      await native.emitProgress(0, durationMs: 7200000);
      await native.emit({'type': 'error', 'errorType': 'ERROR_NETWORK'});
      await settleMany();

      expect(loadStarts(), [3600000, 3700000, 3700000]);
    });

    test('a user seek before the start seek replaces it', () async {
      store = await createStore(startAt: const Duration(hours: 1));
      await native.emitProgress(0, durationMs: 7200000);

      store.seekTo(const Duration(minutes: 10));
      await native.emit({'type': 'seeked', 'ms': 600000});
      await native.emitProgress(600250, durationMs: 7200000);

      expect(store.position, const Duration(milliseconds: 600250));
    });

    test('a forbidden vod still completes ready', () async {
      when(
        () => service.getVodUsherUrl(
          vodId: any(named: 'vodId'),
          forceFreshToken: any(named: 'forceFreshToken'),
        ),
      ).thenThrow(const VodForbiddenException('vod_manifest_restricted'));
      final s = build();

      await expectLater(s.ready, completes);
      expect(s.status, VodPlaybackStatus.problem);
      expect(s.problem, VodPlaybackProblem.subscriberOnly);
    });

    test('another url failure still rejects ready', () async {
      when(
        () => service.getVodUsherUrl(
          vodId: any(named: 'vodId'),
          forceFreshToken: any(named: 'forceFreshToken'),
        ),
      ).thenThrow(const ApiException('No playback access token'));
      final s = build();

      await expectLater(s.ready, throwsA(isA<ApiException>()));
      await settleMany();
      expect(s.status, VodPlaybackStatus.failed);
    });

    test('a texture that cannot be created falls back', () async {
      native.createThrows = true;
      var fatal = 0;
      build().onFatalError = () => fatal++;
      await settleMany(10);

      expect(fatal, 1);
      expect(created!.status, VodPlaybackStatus.failed);
    });

    test('a native load failure falls back', () async {
      native.loadThrows = true;
      var fatal = 0;
      build().onFatalError = () => fatal++;
      await settleMany(10);

      expect(fatal, 1);
    });

    test('a duration event sets the duration', () async {
      store = await createStore(knownLength: null);

      await native.emit({'type': 'duration', 'ms': 5000000});

      expect(store.duration, const Duration(milliseconds: 5000000));
    });
  });

  group('a refusal of the viewer\'s own token', () {
    void stubViewerUrl() => when(
      () => service.getVodUsherUrl(
        vodId: any(named: 'vodId'),
        forceFreshToken: any(named: 'forceFreshToken'),
      ),
    ).thenAnswer((_) async => _viewerUrl);

    test('a vod for subscribers says so instead of falling back', () async {
      stubViewerUrl();
      when(
        () => service.diagnoseVodPlaylist(any()),
      ).thenAnswer((_) async => VodPlaybackProblem.subscriberOnly);
      var fatal = 0;
      store = await createStore();
      store.onFatalError = () => fatal++;

      await native.emit({'type': 'error', 'errorType': 'ERROR_AUTHORIZATION'});
      await settleMany();

      expect(store.status, VodPlaybackStatus.problem);
      expect(store.problem, VodPlaybackProblem.subscriberOnly);
      expect(fatal, 0, reason: 'the web player would hit the same wall');
      // A refresh (after subscribing) must ask Twitch again.
      verify(() => service.invalidateToken('123')).called(1);
      verify(() => service.diagnoseVodPlaylist(_viewerUrl)).called(1);
      verifyNever(
        () => service.getVodUsherUrl(vodId: '123', forceFreshToken: true),
      );
      expect(native.callsNamed('load'), hasLength(1));
    });

    test('a 403 with a geoblock is a geoblock problem', () async {
      stubViewerUrl();
      when(
        () => service.diagnoseVodPlaylist(any()),
      ).thenAnswer((_) async => VodPlaybackProblem.geoBlocked);
      store = await createStore();

      await native.emit({
        'type': 'error',
        'errorType': 'ERROR_UNKNOWN',
        'code': 403,
      });
      await settleMany();

      expect(store.problem, VodPlaybackProblem.geoBlocked);
    });

    test('an expired token is refreshed as before', () async {
      stubViewerUrl();
      when(
        () => service.diagnoseVodPlaylist(any()),
      ).thenAnswer((_) async => VodPlaybackProblem.tokenRejected);
      store = await createStore();

      await native.emit({'type': 'error', 'errorType': 'ERROR_AUTHORIZATION'});
      await settleMany();

      verify(
        () => service.getVodUsherUrl(vodId: '123', forceFreshToken: true),
      ).called(1);
      expect(native.callsNamed('load'), hasLength(2));
      expect(store.status, isNot(VodPlaybackStatus.problem));
    });

    test('an anonymous token keeps the old path to the web player', () async {
      var fatal = 0;
      store = await createStore();
      store.onFatalError = () => fatal++;

      for (var i = 0; i < 4; i++) {
        await native.emit({
          'type': 'error',
          'errorType': 'ERROR_AUTHORIZATION',
        });
        await settleMany();
      }

      verifyNever(() => service.diagnoseVodPlaylist(any()));
      expect(fatal, 1, reason: 'the web player has the twitch.tv cookies');
      expect(store.status, VodPlaybackStatus.failed);
    });
  });

  group('review: recovery', () {
    test('not available with a playable playlist retries', () async {
      when(
        () => service.diagnoseVodPlaylist(any()),
      ).thenAnswer((_) async => null);
      store = await createStore();

      await native.emit({'type': 'error', 'errorType': 'ERROR_NOT_AVAILABLE'});
      await settleMany();

      expect(native.callsNamed('load'), hasLength(2));
      expect(store.status, isNot(VodPlaybackStatus.problem));
    });

    test(
      'not available with a rejected token retries with a fresh token',
      () async {
        when(
          () => service.diagnoseVodPlaylist(any()),
        ).thenAnswer((_) async => VodPlaybackProblem.tokenRejected);
        store = await createStore();

        await native.emit({
          'type': 'error',
          'errorType': 'ERROR_NOT_AVAILABLE',
        });
        await settleMany();

        verify(
          () => service.getVodUsherUrl(vodId: '123', forceFreshToken: true),
        ).called(1);
        expect(native.callsNamed('load'), hasLength(2));
      },
    );

    test('a geoblock found during a reload is a geoblock problem', () async {
      stubUrlSequence([_url, const VodForbiddenException('geoblocked')]);
      store = await createStore();

      await native.emit({'type': 'error', 'errorType': 'ERROR_NETWORK'});
      await settleMany();

      expect(store.status, VodPlaybackStatus.problem);
      expect(store.problem, VodPlaybackProblem.geoBlocked);
    });

    test('a vod deleted while watching is diagnosed, not a fallback', () async {
      stubUrlSequence([_url, const ApiException('No playback access token')]);
      when(
        () => service.diagnoseVodPlaylist(any()),
      ).thenAnswer((_) async => VodPlaybackProblem.notFound);
      var fatal = 0;
      store = await createStore();
      store.onFatalError = () => fatal++;

      await native.emit({'type': 'error', 'errorType': 'ERROR_NETWORK'});
      await settleMany();

      expect(store.status, VodPlaybackStatus.problem);
      expect(store.problem, VodPlaybackProblem.notFound);
      expect(fatal, 0);
    });

    test('failed is terminal: later states and errors are ignored', () async {
      var fatal = 0;
      store = await createStore();
      store.onFatalError = () => fatal++;

      await native.emit({'type': 'error', 'errorType': 'ERROR_NOT_SUPPORTED'});
      await native.emit({'type': 'state', 'state': 'IDLE'});
      await native.emit({'type': 'error', 'errorType': 'ERROR_NOT_SUPPORTED'});
      await native.emit({'type': 'error', 'errorType': 'ERROR_NETWORK'});
      await settleMany();

      expect(fatal, 1);
      expect(store.status, VodPlaybackStatus.failed);
      expect(native.callsNamed('load'), hasLength(1));
    });

    test('a problem is terminal too', () async {
      when(
        () => service.diagnoseVodPlaylist(any()),
      ).thenAnswer((_) async => VodPlaybackProblem.subscriberOnly);
      store = await createStore();

      await native.emit({'type': 'error', 'errorType': 'ERROR_NOT_AVAILABLE'});
      await settleMany();
      await native.emit({'type': 'state', 'state': 'IDLE'});

      expect(store.status, VodPlaybackStatus.problem);
    });

    test('no reload after dispose', () async {
      store = await createStore(
        policy: IvsRecoveryPolicy(
          backoff: const [
            Duration(milliseconds: 30),
            Duration(milliseconds: 30),
            Duration(milliseconds: 30),
          ],
        ),
      );

      await native.emit({'type': 'error', 'errorType': 'ERROR_NETWORK'});
      store.dispose();
      created = null;
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(native.callsNamed('load'), hasLength(1));
    });

    test('rate is re-sent after an actual reload', () async {
      store = await createStore();
      store.setPlaybackRate(1.5);
      await settle();
      native.playerCalls.clear();

      await native.emit({'type': 'error', 'errorType': 'ERROR_NETWORK'});
      await settleMany();
      expect(native.callsNamed('load'), hasLength(1));
      await native.emit({
        'type': 'qualities',
        'list': ['1080p60'],
      });
      await settle();

      expect(
        (native.callsNamed('setPlaybackRate').single.arguments as Map)['rate'],
        1.5,
      );
    });
  });

  group('review: seeking', () {
    test('a confirmation for an older seek does not end a newer one', () async {
      store = await createStore();
      await native.emit({'type': 'seeked', 'ms': 0});
      await native.emitProgress(5000, durationMs: 100000);

      store.seekBy(const Duration(seconds: 10));
      store.seekBy(const Duration(seconds: 10));
      await native.emit({'type': 'seeked', 'ms': 15000});
      await native.emitProgress(15250, durationMs: 100000);
      expect(store.position, const Duration(seconds: 25));

      await native.emit({'type': 'seeked', 'ms': 25000});
      await native.emitProgress(25250, durationMs: 100000);
      expect(store.position, const Duration(milliseconds: 25250));
    });

    test('a lost confirmation times out', () async {
      store = await createStore(seekTimeout: const Duration(milliseconds: 20));
      await native.emit({'type': 'seeked', 'ms': 0});
      await native.emitProgress(5000, durationMs: 100000);

      store.seekTo(const Duration(seconds: 60));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await native.emitProgress(5250, durationMs: 100000);

      expect(store.position, const Duration(milliseconds: 5250));
    });

    test('replay from the end ignores a stale end tick', () async {
      store = await createStore();
      await native.emit({'type': 'seeked', 'ms': 0});
      await native.emitProgress(99000, durationMs: 100000);
      await native.emit({'type': 'state', 'state': 'ENDED'});

      store.play();
      await native.emitProgress(99000, durationMs: 100000);

      expect(store.position, Duration.zero);
      expect(store.status, isNot(VodPlaybackStatus.ended));
    });

    test('seeking after the end leaves the ended state', () async {
      store = await createStore();
      await native.emitProgress(1000, durationMs: 100000);
      await native.emit({'type': 'state', 'state': 'ENDED'});

      store.seekTo(const Duration(seconds: 10));

      expect(store.ended, isFalse);
      expect(store.status, VodPlaybackStatus.paused);
    });

    test('the save position ignores native 0 before the start seek', () async {
      store = await createStore(startAt: const Duration(hours: 1));
      native.nativePosition = 0;

      expect(await store.currentPositionForSave(), const Duration(hours: 1));
    });

    test('the save position uses the seek target while seeking', () async {
      store = await createStore();
      await native.emit({'type': 'seeked', 'ms': 0});
      await native.emitProgress(5000, durationMs: 100000);
      native.nativePosition = 5000;

      store.seekTo(const Duration(seconds: 50));

      expect(await store.currentPositionForSave(), const Duration(seconds: 50));
    });
  });

  group('review: overlay', () {
    test('hides after the delay while playing, stays while paused, and '
        'hides again after resuming', () async {
      store = await createStore(
        overlayHideDelay: const Duration(milliseconds: 20),
      );
      await native.emit({'type': 'state', 'state': 'PLAYING'});
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(store.overlayVisible, isFalse);

      await native.emit({'type': 'state', 'state': 'READY'});
      store.showOverlay();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(store.overlayVisible, isTrue);

      await native.emit({'type': 'state', 'state': 'PLAYING'});
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(store.overlayVisible, isFalse);
    });
  });

  group('review: quality', () {
    test('defaults to Auto without a saved quality', () async {
      store = await createStore();

      await native.emit({
        'type': 'qualities',
        'list': ['1080p60', '720p60'],
      });
      await settle();

      expect(native.callsNamed('setQuality'), isEmpty);
      expect(store.quality, 'Auto');
    });

    test('picks the highest when the setting is on', () async {
      settingsStore.defaultToHighestQuality = true;
      store = await createStore();

      await native.emit({
        'type': 'qualities',
        'list': ['1080p60', '720p60'],
      });
      await settle();

      expect(store.quality, '1080p60');
    });
  });

  group('review 2: wanted start position', () {
    test(
      'a stale tick at the old position does not end the reload start',
      () async {
        store = await createStore(startAt: const Duration(hours: 1));
        await native.emit({'type': 'seeked', 'ms': 3600000});
        await native.emit({'type': 'state', 'state': 'PLAYING'});
        await native.emitProgress(3700000, durationMs: 7200000);

        await native.emit({'type': 'error', 'errorType': 'ERROR_NETWORK'});
        await settleMany();
        await native.emitProgress(3700000, durationMs: 7200000);
        await native.emitProgress(0, durationMs: 7200000);

        expect(store.position, const Duration(milliseconds: 3700000));
        expect(
          await store.currentPositionForSave(),
          const Duration(milliseconds: 3700000),
        );

        await native.emit({'type': 'error', 'errorType': 'ERROR_NETWORK'});
        await settleMany();
        expect(loadStarts(), [3600000, 3700000, 3700000]);
      },
    );

    test(
      'ticks before the url resolves do not replace the resume point',
      () async {
        final url = Completer<String>();
        when(
          () => service.getVodUsherUrl(
            vodId: any(named: 'vodId'),
            forceFreshToken: any(named: 'forceFreshToken'),
          ),
        ).thenAnswer((_) => url.future);
        final s = build(startAt: const Duration(hours: 1));
        await settleMany();

        await native.emitProgress(0);

        expect(s.position, const Duration(hours: 1));
        expect(await s.currentPositionForSave(), const Duration(hours: 1));
        url.complete(_url);
        await settleMany();
      },
    );

    test('a seek before the url resolves becomes the start', () async {
      final url = Completer<String>();
      when(
        () => service.getVodUsherUrl(
          vodId: any(named: 'vodId'),
          forceFreshToken: any(named: 'forceFreshToken'),
        ),
      ).thenAnswer((_) => url.future);
      final s = build();
      await settleMany();

      s.seekTo(const Duration(minutes: 10));
      url.complete(_url);
      await settleMany();

      expect(loadStarts(), [600000]);
      expect(s.position, const Duration(minutes: 10));
    });

    test('a seek during the retry delay is where the reload starts', () async {
      store = await createStore(
        policy: IvsRecoveryPolicy(
          backoff: const [
            Duration(milliseconds: 40),
            Duration(milliseconds: 40),
            Duration(milliseconds: 40),
          ],
        ),
      );
      await native.emit({'type': 'seeked', 'ms': 0});
      await native.emitProgress(42000, durationMs: 7200000);

      await native.emit({'type': 'error', 'errorType': 'ERROR_NETWORK'});
      store.seekTo(const Duration(minutes: 10));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await settleMany();

      expect(loadStarts(), [0, 600000]);
      expect(store.position, const Duration(minutes: 10));
    });

    test('PLAYING before the start seek confirms does not show 0', () async {
      store = await createStore(startAt: const Duration(hours: 1));

      await native.emit({'type': 'state', 'state': 'READY'});
      await native.emit({'type': 'state', 'state': 'PLAYING'});
      await native.emitProgress(0, durationMs: 7200000);

      expect(store.position, const Duration(hours: 1));
    });

    test('a lost start confirmation times out after READY', () async {
      store = await createStore(
        startAt: const Duration(hours: 1),
        seekTimeout: const Duration(milliseconds: 20),
      );

      await native.emit({'type': 'state', 'state': 'READY'});
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await native.emitProgress(3600500, durationMs: 7200000);

      expect(store.position, const Duration(milliseconds: 3600500));
    });

    test('an old READY timer does not end the start during a retry', () async {
      store = await createStore(
        startAt: const Duration(hours: 1),
        seekTimeout: const Duration(milliseconds: 50),
        policy: IvsRecoveryPolicy(
          backoff: const [
            Duration(milliseconds: 300),
            Duration(milliseconds: 300),
            Duration(milliseconds: 300),
          ],
        ),
      );
      await native.emit({'type': 'state', 'state': 'READY'});
      await native.emit({'type': 'error', 'errorType': 'ERROR_NETWORK'});
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await native.emitProgress(0, durationMs: 7200000);

      expect(store.position, const Duration(hours: 1));
      expect(await store.currentPositionForSave(), const Duration(hours: 1));
    });

    test(
      'an old READY timer does not end the start during a diagnose',
      () async {
        final diagnosis = Completer<VodPlaybackProblem?>();
        when(
          () => service.diagnoseVodPlaylist(any()),
        ).thenAnswer((_) => diagnosis.future);
        store = await createStore(
          startAt: const Duration(hours: 1),
          seekTimeout: const Duration(milliseconds: 50),
        );
        await native.emit({'type': 'state', 'state': 'READY'});
        await native.emit({
          'type': 'error',
          'errorType': 'ERROR_NOT_AVAILABLE',
        });
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await native.emitProgress(0, durationMs: 7200000);
        diagnosis.complete(null);
        await settleMany(10);

        expect(loadStarts(), [3600000, 3600000]);
      },
    );

    test('a seek confirmed before the source loads is not the start', () async {
      final url = Completer<String>();
      when(
        () => service.getVodUsherUrl(
          vodId: any(named: 'vodId'),
          forceFreshToken: any(named: 'forceFreshToken'),
        ),
      ).thenAnswer((_) => url.future);
      final s = build(startAt: const Duration(hours: 1));
      await settleMany();

      s.seekTo(const Duration(minutes: 10));
      await native.emit({'type': 'seeked', 'ms': 600000});
      await native.emitProgress(0);

      expect(await s.currentPositionForSave(), const Duration(minutes: 10));
      s.seekTo(const Duration(minutes: 20));
      url.complete(_url);
      await settleMany();
      expect(loadStarts(), [1200000]);
    });

    test('a refusal after the native player failed stays failed', () async {
      native.createThrows = true;
      final url = Completer<String>();
      when(
        () => service.getVodUsherUrl(
          vodId: any(named: 'vodId'),
          forceFreshToken: any(named: 'forceFreshToken'),
        ),
      ).thenAnswer((_) => url.future);
      var fatal = 0;
      final s = build()..onFatalError = () => fatal++;
      await settleMany(10);

      url.completeError(const VodForbiddenException('geoblocked'));
      await s.ready.catchError((Object _) {});
      await settleMany();

      expect(fatal, 1);
      expect(s.status, VodPlaybackStatus.failed);
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
      await native.emit({'type': 'seeked', 'ms': 0});
      await native.emit({'type': 'state', 'state': 'PLAYING'});
      native.nativePosition = 777000;

      expect(
        await store.currentPositionForSave(),
        const Duration(milliseconds: 777000),
      );
    });

    test('currentPositionForSave falls back to the last progress', () async {
      store = await createStore();
      await native.emit({'type': 'seeked', 'ms': 0});
      await native.emit({'type': 'state', 'state': 'PLAYING'});
      await native.emitProgress(5000);

      expect(await store.currentPositionForSave(), const Duration(seconds: 5));
    });
  });

  group('playback focus', () {
    test('without focus, playing is paused again', () async {
      store = await createStore();
      store.setFocused(false);

      await native.emit({'type': 'state', 'state': 'PLAYING'});
      await settle();

      expect(native.callsNamed('pause'), hasLength(1));
    });

    test('an explicit play takes focus back', () async {
      store = await createStore();
      store.setFocused(false);

      store.play();
      await native.emit({'type': 'state', 'state': 'PLAYING'});
      await settle();

      expect(native.callsNamed('pause'), isEmpty);
    });

    test('with focus back, playing is left alone', () async {
      store = await createStore();
      store
        ..setFocused(false)
        ..setFocused(true);

      await native.emit({'type': 'state', 'state': 'PLAYING'});
      await settle();

      expect(native.callsNamed('pause'), isEmpty);
    });
  });
}
