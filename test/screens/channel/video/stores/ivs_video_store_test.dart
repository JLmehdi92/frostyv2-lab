import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart' show reaction;
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/base_api_client.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/apis/twitch_stream_service.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/playback_access_token.dart';
import 'package:onset/models/stream.dart';
import 'package:onset/screens/channel/video/buffer_fallback.dart';
import 'package:onset/screens/channel/video/ivs_player_config.dart';
import 'package:onset/screens/channel/video/ivs_recovery.dart';
import 'package:onset/screens/channel/video/ivs_video.dart';
import 'package:onset/screens/channel/video/latency_controller.dart';
import 'package:onset/screens/channel/video/player_controller.dart';
import 'package:onset/screens/channel/video/stores/ivs_video_store.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/services/audio_focus.dart';
import 'package:onset/services/background_audio.dart';
import 'package:onset/services/realtime/twitch_eventsub_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../fixtures/api_responses.dart';
import '../../../../helpers/fake_ivs_native.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

class MockAuthStore extends Mock implements AuthStore {}

/// A viewer without a web token nor a login: playback asks anonymously.
MockAuthStore anonymousAuthStore() {
  final auth = MockAuthStore();
  when(() => auth.twitchWebToken).thenReturn(null);
  when(() => auth.isLoggedIn).thenReturn(false);
  return auth;
}

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

  Future<IvsVideoStore> createStore({
    IvsRecoveryPolicy? policy,
    EventSubHandle Function(EventSubTopic topic)? listenEvents,
    Duration offlinePollInterval = const Duration(minutes: 1),
    BackgroundAudio? backgroundAudio,
    AudioFocus? audioFocus,
    DateTime Function()? now,
    BufferFallback? bufferFallback,
    Duration autoLatencyWatchdog = const Duration(seconds: 1),
  }) async {
    final s = IvsVideoStore(
      userLogin: 'streamer',
      userId: '123',
      twitchApi: twitchApi,
      authStore: anonymousAuthStore(),
      settingsStore: settingsStore,
      streamService: streamService,
      recoveryPolicy: policy ?? instantPolicy(),
      listenEvents: listenEvents,
      liveStartDelay: Duration.zero,
      offlinePollInterval: offlinePollInterval,
      backgroundAudio: backgroundAudio,
      audioFocus: audioFocus,
      now: now,
      bufferFallback: bufferFallback ?? BufferFallback(),
      autoLatencyWatchdog: autoLatencyWatchdog,
    );
    created = s;
    await s.ready;
    for (var i = 0; i < 20 && s.textureId == null; i++) {
      await settle();
    }
    expect(s.textureId, isNotNull, reason: 'texture was never created');
    for (var i = 0; i < 20 && native.callsNamed('load').isEmpty; i++) {
      await settle();
    }
    expect(native.callsNamed('load'), hasLength(1), reason: 'initial load');
    // Tests below count only the calls they cause themselves.
    native.playerCalls.clear();
    return s;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    native = FakeIvsNative()..install();
    twitchApi = MockTwitchApi();
    streamService = MockTwitchStreamService();
    settingsStore = SettingsStore.fromJson({});

    when(
      () => streamService.getUsherUrl(
        userLogin: any(named: 'userLogin'),
        forceFreshToken: any(named: 'forceFreshToken'),
      ),
    ).thenAnswer((_) async => _usherUrl);
    when(() => streamService.refusalFor(any())).thenReturn(null);
    when(() => streamService.usherRefusal(any())).thenAnswer((_) async => null);
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

  test('creates the native player then loads the usher url', () async {
    settingsStore
      ..autoLatency = false
      ..bufferProfile = BufferProfile.standard;
    store = await createStore();

    final create = native.managerCalls.singleWhere((c) => c.method == 'create');
    expect((create.arguments as Map).containsKey('url'), isFalse);
    expect((create.arguments as Map)['config'], {
      'speedUpCatchUp': true,
      'rebufferToLive': false,
      'initialBufferMs': 100,
    });
    expect(store.textureId, native.textureId);
  });

  test('by default opens on ultra with auto latency owning the rate', () async {
    store = await createStore();

    final create = native.managerCalls.singleWhere((c) => c.method == 'create');
    expect((create.arguments as Map)['config'], {
      'speedUpCatchUp': false,
      'rebufferToLive': false,
      'initialBufferMs': 100,
      'llMinBufferSec': 0.5,
      'llMinBufferCeilingSec': 3.0,
    });
  });

  test(
    'passes the chosen catch-up and buffer settings to the player',
    () async {
      settingsStore
        ..liveCatchUpMode = LiveCatchUpMode.jumpToLive
        ..bufferProfile = BufferProfile.ultra;
      store = await createStore();

      final create = native.managerCalls.singleWhere(
        (c) => c.method == 'create',
      );
      final config = (create.arguments as Map)['config'] as Map;
      expect(config['rebufferToLive'], isTrue);
      expect(config['speedUpCatchUp'], isFalse);
      expect(config['llMinBufferSec'], 0.5);
    },
  );

  test('keeps the player config fixed for the stream lifetime', () async {
    store = await createStore();
    final before = store.playerConfig;

    settingsStore
      ..liveCatchUpMode = LiveCatchUpMode.jumpToLive
      ..bufferProfile = BufferProfile.ultra;
    await store.handleRefresh();

    expect(store.playerConfig.catchUp, before.catchUp);
    expect(store.playerConfig.buffer, before.buffer);
    expect(
      native.managerCalls.where((c) => c.method == 'create'),
      hasLength(1),
    );
  });

  test('captures the player config when the stream is opened', () async {
    settingsStore.bufferProfile = BufferProfile.standard;
    final s = IvsVideoStore(
      userLogin: 'streamer',
      userId: '123',
      twitchApi: twitchApi,
      authStore: anonymousAuthStore(),
      settingsStore: settingsStore,
      streamService: streamService,
      recoveryPolicy: instantPolicy(),
    );
    created = s;
    // Changed while the usher URL is still resolving: too late for this one.
    settingsStore.bufferProfile = BufferProfile.ultra;
    await s.ready;
    for (var i = 0; i < 20 && s.textureId == null; i++) {
      await settle();
    }

    final create = native.managerCalls.singleWhere((c) => c.method == 'create');
    final config = (create.arguments as Map)['config'] as Map;
    expect(config.containsKey('llMinBufferSec'), isFalse);
    expect(s.playerConfig.buffer, BufferProfile.standard);
  });

  testWidgets('audio only shows a badge over the picture', (tester) async {
    await tester.runAsync(() async {
      store = await createStore();
      await native.emit({
        'type': 'qualities',
        'list': ['1080p60', 'audio_only'],
      });
      await native.emit({'type': 'quality', 'name': 'audio_only'});
    });
    await tester.pumpWidget(
      MaterialApp(home: IvsTextureVideo(videoStore: store)),
    );

    expect(store.streamQuality, 'audio_only');
    expect(find.text('Audio only'), findsOneWidget);
  });

  group('captions', () {
    test('off by default: cues are ignored and nothing is asked', () async {
      store = await createStore();
      await native.emit({'type': 'caption', 'text': 'hello'});

      expect(store.caption, isNull);
      expect(native.callsNamed('setCaptions'), isEmpty);
    });

    test('turned on: asked for, shown, then cleared at the cue end', () async {
      store = await createStore();
      settingsStore.showCaptions = true;
      await settle();
      expect(native.callsNamed('setCaptions').last.arguments, {
        'enabled': true,
      });

      await native.emit({
        'type': 'caption',
        'text': '  hello\nthere ',
        'startMs': 0,
        'endMs': 1000,
      });
      expect(store.caption, 'hello there');

      await Future<void>.delayed(const Duration(milliseconds: 1100));
      expect(store.caption, isNull);
    });

    test('turning them off clears the line and tells the player', () async {
      settingsStore.showCaptions = true;
      store = await createStore();
      await native.emit({'type': 'caption', 'text': 'hello'});
      expect(store.caption, 'hello');

      settingsStore.showCaptions = false;
      await settle();

      expect(store.caption, isNull);
      expect(native.callsNamed('setCaptions').last.arguments, {
        'enabled': false,
      });
    });

    test("the stream's caption tracks reach the menu", () async {
      store = await createStore();
      await native.emit({
        'type': 'textTracks',
        'list': [
          {'id': 'a', 'label': 'English', 'language': 'en'},
          {'id': 'b', 'label': 'Deutsch', 'language': 'de'},
        ],
        'selected': 'a',
      });

      expect(store.captions.tracks.map((t) => t.name), ['English', 'Deutsch']);
      store.captions.selectTrack(store.captions.tracks.last);
      await settle();
      expect(native.callsNamed('setTextTrack').last.arguments, {'id': 'b'});
    });

    test('each load asks for them again', () async {
      settingsStore.showCaptions = true;
      store = await createStore();
      await native.emit({
        'type': 'qualities',
        'list': ['1080p60'],
      });

      expect(native.callsNamed('setCaptions'), isNotEmpty);
    });
  });

  group('latency', () {
    test('shows latency with 0.1 s precision', () async {
      store = await createStore();
      await native.emit({'type': 'state', 'state': 'PLAYING'});

      await native.emit({'type': 'latency', 'ms': 2349});
      expect(store.latency, '2.3s');
      expect(store.latencyMs, 2349);

      await native.emit({'type': 'latency', 'ms': 2350});
      expect(store.latency, '2.4s');
    });

    test('ignores negative latency', () async {
      store = await createStore();
      await native.emit({'type': 'state', 'state': 'PLAYING'});

      await native.emit({'type': 'latency', 'ms': 1500});
      await native.emit({'type': 'latency', 'ms': -1});

      expect(store.latency, '1.5s');
      expect(store.latencyMs, 1500);
    });

    test('auto-synced chat delay only changes on whole seconds', () async {
      settingsStore
        ..autoSyncChatDelay = true
        ..autoLatency = false;
      store = await createStore();
      await native.emit({'type': 'state', 'state': 'PLAYING'});

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

    test('the chat delay stays put while the stream is paused', () async {
      settingsStore.autoSyncChatDelay = true;
      store = await createStore();
      await native.emit({'type': 'state', 'state': 'PLAYING'});
      await native.emit({'type': 'latency', 'ms': 2400});
      expect(settingsStore.syncedChatDelay, 2.0);

      // Paused, the native latency keeps growing by a second a second.
      await native.emit({'type': 'state', 'state': 'IDLE'});
      await native.emit({'type': 'latency', 'ms': 30000});

      expect(settingsStore.syncedChatDelay, 2.0);
      expect(store.latencyMs, 30000, reason: 'still shown on the badge');
    });

    test('an offline stream stops delaying chat', () async {
      settingsStore.autoSyncChatDelay = true;
      store = await createStore();
      await native.emit({'type': 'state', 'state': 'PLAYING'});
      await native.emit({'type': 'latency', 'ms': 3200});
      expect(settingsStore.syncedChatDelay, 3.0);
      when(
        () => twitchApi.getStream(userLogin: any(named: 'userLogin')),
      ).thenThrow(const NotFoundException('offline'));

      await native.emit({'type': 'error', 'errorType': 'ERROR_NOT_AVAILABLE'});
      for (var i = 0; i < 5; i++) {
        await settle();
      }

      expect(store.status, IvsPlaybackStatus.offline);
      expect(settingsStore.syncedChatDelay, 0.0);
    });

    test('does not touch the chat delay when auto-sync is off', () async {
      settingsStore.autoSyncChatDelay = false;
      store = await createStore();
      await native.emit({'type': 'state', 'state': 'PLAYING'});

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

  group('auto latency', () {
    late DateTime now;
    late BufferFallback fallback;

    setUp(() {
      now = DateTime(2026, 10, 30, 20);
      fallback = BufferFallback(now: () => now);
    });

    /// One native latency tick per second, like `IvsPlayerCore`.
    Future<void> tick(
      int ms,
      int seconds, {
      int? bufferMs = 1800,
      double? rate,
      bool? lowLatency = true,
    }) async {
      for (var i = 0; i < seconds; i++) {
        now = now.add(const Duration(seconds: 1));
        await native.emit({
          'type': 'latency',
          'ms': ms,
          'bufferMs': bufferMs,
          'rate': rate,
          'lowLatency': lowLatency,
        });
      }
      for (var i = 0; i < 5; i++) {
        await settle();
      }
    }

    List<double> rates() => [
      for (final c in native.callsNamed('setPlaybackRate'))
        ((c.arguments as Map)['rate'] as num).toDouble(),
    ];

    Future<IvsVideoStore> playing() async {
      final s = await createStore(now: () => now, bufferFallback: fallback);
      await native.emit({'type': 'state', 'state': 'PLAYING'});
      return s;
    }

    test('catches a drifted stream up without reloading it', () async {
      store = await playing();

      await tick(2200, 8);
      expect(rates(), [LatencyController.catchUpRate]);
      expect(store.autoLatencyStatus?.phase, AutoLatencyPhase.catchingUp);

      await tick(1300, 8);
      expect(rates(), [LatencyController.catchUpRate, 1.0]);
      expect(store.autoLatencyStatus?.phase, AutoLatencyPhase.steady);
      expect(native.callsNamed('load'), isEmpty, reason: 'never a reload');
      expect(store.liveJumps, 0);
    });

    test('off, the rate is never touched', () async {
      settingsStore.autoLatency = false;
      store = await playing();

      await tick(4000, 60, bufferMs: 3000);

      expect(native.callsNamed('setPlaybackRate'), isEmpty);
      expect(store.autoLatencyStatus, isNull);
      final create = native.managerCalls.singleWhere(
        (c) => c.method == 'create',
      );
      expect(
        ((create.arguments as Map)['config'] as Map)['speedUpCatchUp'],
        isTrue,
      );
    });

    test('a stream at its target is left at 1.0x', () async {
      store = await playing();

      await tick(1250, 120);

      expect(native.callsNamed('setPlaybackRate'), isEmpty);
    });

    test('a rebuffer drops back to 1.0x at once', () async {
      store = await playing();
      await tick(2200, 8);

      await native.emit({'type': 'rebuffering'});
      await settle();

      expect(rates().last, 1.0);
      expect(store.autoLatencyStatus?.phase, AutoLatencyPhase.settling);
    });

    test('pausing drops back to 1.0x and holds', () async {
      store = await playing();
      await tick(2200, 8);

      store.handlePausePlay();
      await settle();
      expect(rates().last, 1.0);

      await native.emit({'type': 'state', 'state': 'IDLE'});
      await tick(9000, 30);
      expect(rates().last, 1.0);
      expect(store.autoLatencyStatus?.reason, AutoLatencyReason.paused);
    });

    // A 1.05× rate is invisible and inaudible: picture-in-picture and the
    // mini player keep correcting (the SDK speed-up it replaces did too).
    test('picture-in-picture keeps correcting', () async {
      store = await playing();
      await tick(2200, 8);

      store.onPipEntered();
      await tick(2200, 3);

      expect(rates(), [LatencyController.catchUpRate]);
      expect(store.autoLatencyStatus?.phase, AutoLatencyPhase.catchingUp);
    });

    test('the mini player keeps correcting', () async {
      store = await playing();
      await tick(2200, 8);

      store.setMinimized(true);
      await tick(2200, 3);

      expect(rates(), [LatencyController.catchUpRate]);
      expect(store.autoLatencyStatus?.phase, AutoLatencyPhase.catchingUp);
    });

    test('an ad holds it', () async {
      store = await playing();
      await tick(1300, 10);

      await native.emit({'type': 'ad', 'durationMs': 30000});
      await tick(3000, 30);

      expect(native.callsNamed('setPlaybackRate'), isEmpty);
      expect(store.autoLatencyStatus?.reason, AutoLatencyReason.ad);
    });

    test('a refused rate stops it for the stream', () async {
      native.rateThrows = true;
      store = await playing();

      await tick(2200, 8);
      expect(rates(), [LatencyController.catchUpRate]);
      expect(store.autoLatencyStatus?.phase, AutoLatencyPhase.stopped);

      await tick(4000, 60);
      expect(rates(), hasLength(1), reason: 'never asked again');
    });

    test('a failed return to 1.0x is retried and never latches', () async {
      store = await playing();
      await tick(2200, 8);
      expect(rates(), [LatencyController.catchUpRate]);

      // 1.05× was accepted; the way back fails (a reload under way...).
      native.rejectRate = (rate) => rate == 1.0;
      store.handlePausePlay();
      await settle();
      expect(rates().last, 1.0);
      expect(store.autoLatencyStatus?.phase, AutoLatencyPhase.stopped);
      expect(
        store.autoLatencyStatus?.reason,
        AutoLatencyReason.notBackToNormal,
      );

      // Retried on the next tick while the player still plays fast...
      final before = rates().length;
      await tick(2200, 1, rate: 1.05);
      expect(rates().length, before + 1);
      expect(rates().last, 1.0);

      // ...until it goes through.
      native.rejectRate = null;
      await tick(2200, 1, rate: 1.05);
      final settled = rates().length;
      await tick(2200, 5, rate: 1.0);
      expect(rates().length, settled, reason: 'back at 1.0x: nothing more');

      // Never latched: a refresh lets it catch up again.
      await store.handleRefresh();
      await native.emit({'type': 'state', 'state': 'PLAYING'});
      await tick(2200, 8);
      expect(rates().last, LatencyController.catchUpRate);
    });

    test('a player that stays fast is stopped visibly and nudged', () async {
      store = await playing();
      await tick(2200, 8);
      await tick(1300, 6);
      expect(rates(), [LatencyController.catchUpRate, 1.0]);

      // The player keeps reporting 1.05×.
      await tick(1300, 2, rate: 1.05);
      expect(rates(), hasLength(4), reason: 'two quick resends');
      await tick(1300, 1, rate: 1.05);
      expect(store.autoLatencyStatus?.phase, AutoLatencyPhase.stopped);
      expect(store.autoLatencyStatus?.reason, AutoLatencyReason.stuckFast);
      expect(store.autoLatencyStatus?.reasonRate, 1.05);

      // Then every 10 s, never every second.
      final before = rates().length;
      await tick(1300, 20, rate: 1.05);
      expect(rates().length - before, inInclusiveRange(1, 2));
      expect(rates().every((r) => r == 1.0 || r > 1), isTrue);

      // A new load gets its quick resends back.
      await store.handleRefresh();
      await native.emit({'type': 'state', 'state': 'PLAYING'});
      final afterLoad = rates().length;
      await tick(1300, 1, rate: 1.05);
      expect(rates().length, afterLoad + 1);
    });

    test('a refresh drops a catch-up to 1.0x before fetching', () async {
      store = await playing();
      await tick(2200, 8);
      final url = Completer<String>();
      when(
        () => streamService.getUsherUrl(
          userLogin: any(named: 'userLogin'),
          forceFreshToken: any(named: 'forceFreshToken'),
        ),
      ).thenAnswer((_) => url.future);

      final refresh = store.handleRefresh();
      await settle();

      expect(rates().last, 1.0);
      expect(store.autoLatencyStatus?.phase, AutoLatencyPhase.held);
      expect(store.autoLatencyStatus?.reason, AutoLatencyReason.reconnecting);
      url.complete(_usherUrl);
      await refresh;
    });

    test('a tick without a latency drops back to 1.0x', () async {
      store = await playing();
      await tick(2200, 8);

      now = now.add(const Duration(seconds: 1));
      await native.emit({'type': 'latency', 'ms': null, 'bufferMs': 1800});
      await settle();

      expect(rates().last, 1.0);
      expect(
        store.autoLatencyStatus?.reason,
        AutoLatencyReason.noLatencyReading,
      );
    });

    test('a catch-up whose ticks stop is ended by the watchdog', () async {
      store = await createStore(
        now: () => now,
        bufferFallback: fallback,
        autoLatencyWatchdog: const Duration(milliseconds: 10),
      );
      await native.emit({'type': 'state', 'state': 'PLAYING'});
      await tick(2200, 8);
      expect(rates().last, LatencyController.catchUpRate);

      now = now.add(const Duration(seconds: 4));
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(rates().last, 1.0);
      expect(store.autoLatencyStatus?.reason, AutoLatencyReason.noLatencyTicks);
    });

    group('a quality switch', () {
      Future<void> quality(String name) async {
        await native.emit({'type': 'quality', 'name': name});
        await settle();
      }

      Future<IvsVideoStore> catchingUpAt(String name) async {
        final s = await playing();
        await native.emit({
          'type': 'qualities',
          'list': ['1080p60', '720p60', '480p'],
        });
        for (var i = 0; i < 5; i++) {
          await settle();
        }
        now = now.add(const Duration(seconds: 10));
        await quality(name);
        await tick(2200, 8);
        expect(s.autoLatencyStatus?.phase, AutoLatencyPhase.catchingUp);
        return s;
      }

      test('down during a catch-up is a strike', () async {
        store = await catchingUpAt('1080p60');
        await quality('720p60');

        expect(rates().last, 1.0);
        expect(
          store.autoLatencyStatus?.targetMs,
          1300 + LatencyController.strikeBackoffMs,
        );
      });

      test('up during a catch-up is not', () async {
        store = await catchingUpAt('480p');
        await quality('720p60');

        expect(store.autoLatencyStatus?.targetMs, 1300);
      });

      test('asked for by the viewer is not', () async {
        store = await catchingUpAt('1080p60');
        store.setStreamQuality('480p');
        await quality('480p');

        expect(store.autoLatencyStatus?.targetMs, 1300);
        expect(store.autoLatencyStatus?.phase, AutoLatencyPhase.catchingUp);
      });
    });

    group('the ultra fallback ignores stalls the viewer caused', () {
      Future<void> twoStalls() async {
        await native.emit({'type': 'rebuffering'});
        now = now.add(const Duration(seconds: 2));
        await native.emit({'type': 'rebuffering'});
        await settle();
      }

      test('around a pause and resume', () async {
        store = await playing();
        await tick(1300, 10);
        store.handlePausePlay();
        await native.emit({'type': 'state', 'state': 'IDLE'});
        await twoStalls();
        now = now.add(const Duration(seconds: 3));
        store.handlePausePlay();
        await native.emit({'type': 'state', 'state': 'PLAYING'});
        await twoStalls();

        expect(fallback.active, isFalse);
      });

      test('right after picture-in-picture or the mini player', () async {
        store = await playing();
        await tick(1300, 10);
        store
          ..onPipEntered()
          ..onPipExited();
        await twoStalls();
        store
          ..setMinimized(true)
          ..setMinimized(false);
        await twoStalls();

        expect(fallback.active, isFalse);
      });

      test('right after coming back to the app', () async {
        store = await playing();
        await tick(1300, 10);
        store.handleAppResume();
        await twoStalls();

        expect(fallback.active, isFalse);
      });

      test('but counts them once the grace is over', () async {
        store = await playing();
        await tick(1300, 10);
        store.handleAppResume();
        now = now.add(const Duration(seconds: 11));
        await twoStalls();

        expect(fallback.active, isTrue);
      });
    });

    test('a rate left fast by the player is put back to 1.0x', () async {
      store = await playing();
      await tick(1300, 10);
      expect(native.callsNamed('setPlaybackRate'), isEmpty);

      await tick(1300, 1, rate: 1.05);
      expect(rates(), [1.0]);

      // Never fought every second: two quick resends, then it gives up
      // visibly and only nudges every 10 s.
      await tick(1300, 10, rate: 1.03);
      expect(rates(), [1.0, 1.0]);
      expect(store.autoLatencyStatus?.reason, AutoLatencyReason.stuckFast);
      expect(store.autoLatencyStatus?.reasonRate, 1.03);
    });

    test('each load starts back at 1.0x', () async {
      store = await playing();
      await tick(2200, 8);

      await store.handleRefresh();
      await settle();

      expect(rates().last, 1.0);
      final loadIndex = native.playerCalls.indexWhere(
        (c) => c.method == 'load',
      );
      final rateIndex = native.playerCalls.lastIndexWhere(
        (c) => c.method == 'setPlaybackRate',
      );
      expect(rateIndex, lessThan(loadIndex), reason: 'before the new source');
    });

    test('ultra stalls make the next stream standard, not this one', () async {
      store = await playing();
      expect(store.playerConfig.buffer, BufferProfile.ultra);
      await tick(1300, 10);

      await native.emit({'type': 'rebuffering'});
      now = now.add(const Duration(seconds: 20));
      await native.emit({'type': 'rebuffering'});
      await settle();

      expect(fallback.active, isTrue);
      expect(store.bufferFallbackUntil, isNotNull);
      expect(native.callsNamed('load'), isEmpty, reason: 'no reload now');
      expect(store.playerConfig.buffer, BufferProfile.ultra);
      expect(settingsStore.bufferProfile, BufferProfile.ultra);
      expect(
        IvsPlayerConfig.fromSettings(settingsStore, fallback: fallback).buffer,
        BufferProfile.standard,
      );
    });

    test('standard stalls never trip the ultra fallback', () async {
      settingsStore.bufferProfile = BufferProfile.standard;
      store = await playing();
      await tick(2000, 10);

      for (var i = 0; i < 3; i++) {
        await native.emit({'type': 'rebuffering'});
      }

      expect(fallback.active, isFalse);
    });

    test('the chat delay does not flap around half a second', () async {
      settingsStore.autoSyncChatDelay = true;
      store = await playing();

      final synced = <double>[];
      final dispose = reaction(
        (_) => settingsStore.syncedChatDelay,
        synced.add,
      );
      for (final ms in [1400, 1600, 1450, 1620, 1480, 1600, 2200, 1300]) {
        now = now.add(const Duration(seconds: 1));
        await native.emit({'type': 'latency', 'ms': ms, 'bufferMs': 900});
      }
      dispose();

      // 1 s until the latency is clearly nearer 2 s, then 1 s again.
      expect(synced, [1.0, 2.0, 1.0]);
    });
  });

  group('live edge', () {
    late DateTime now;

    setUp(() => now = DateTime(2026, 10, 20, 12));

    /// One native latency tick per second, like `IvsPlayerCore`.
    Future<void> tick(int ms, int seconds) async {
      for (var i = 0; i < seconds; i++) {
        now = now.add(const Duration(seconds: 1));
        await native.emit({'type': 'latency', 'ms': ms});
      }
      for (var i = 0; i < 5; i++) {
        await settle();
      }
    }

    test('jumps back to the live edge when the latency drifts', () async {
      store = await createStore(now: () => now);
      await native.emit({'type': 'state', 'state': 'PLAYING'});

      await tick(2300, 20);
      expect(native.callsNamed('load'), isEmpty);

      // Stalls left the player 7 s behind and it stays there.
      await tick(7000, 11);

      expect(native.callsNamed('load'), hasLength(1));
      expect(
        (native.callsNamed('load').single.arguments as Map)['url'],
        _usherUrl,
      );
      expect(store.liveJumps, 1);
      // The cached token is reused: no forced refresh for a jump.
      verifyNever(
        () => streamService.getUsherUrl(
          userLogin: any(named: 'userLogin'),
          forceFreshToken: true,
        ),
      );
    });

    test('leaves a stream at the live edge alone', () async {
      store = await createStore(now: () => now);
      await native.emit({'type': 'state', 'state': 'PLAYING'});

      await tick(2300, 20);
      await tick(3400, 60);

      expect(native.callsNamed('load'), isEmpty);
      expect(store.liveJumps, 0);
    });

    test('a drift while paused is not a reason to jump', () async {
      store = await createStore(now: () => now);
      await native.emit({'type': 'state', 'state': 'PLAYING'});
      await tick(2300, 20);
      await native.emit({'type': 'state', 'state': 'IDLE'});

      await tick(30000, 30);

      expect(native.callsNamed('load'), isEmpty);
    });

    test('a long-paused stream resumes at the live edge', () async {
      store = await createStore(now: () => now);
      await native.emit({'type': 'state', 'state': 'PLAYING'});
      await tick(2300, 5);

      store.handlePausePlay();
      expect(native.callsNamed('pause'), hasLength(1));
      await native.emit({'type': 'state', 'state': 'IDLE'});
      now = now.add(IvsVideoStoreBase.resumeAtLiveAfter);

      store.handlePausePlay();
      await tick(0, 0);

      expect(native.callsNamed('play'), isEmpty);
      expect(native.callsNamed('load'), hasLength(1));
      expect(store.liveJumps, 1);
    });

    test('a short pause plays on where it stopped', () async {
      store = await createStore(now: () => now);
      await native.emit({'type': 'state', 'state': 'PLAYING'});
      await tick(2300, 5);

      store.handlePausePlay();
      await native.emit({'type': 'state', 'state': 'IDLE'});
      // A quick pause tap (under ten seconds) must not cost a reload.
      now = now.add(const Duration(seconds: 9));

      store.handlePausePlay();
      await tick(0, 0);

      expect(native.callsNamed('play'), hasLength(1));
      expect(native.callsNamed('load'), isEmpty);
    });

    test('a resume whose jump fails still plays', () async {
      store = await createStore(now: () => now);
      await native.emit({'type': 'state', 'state': 'PLAYING'});
      await tick(2300, 5);
      store.handlePausePlay();
      await native.emit({'type': 'state', 'state': 'IDLE'});
      now = now.add(const Duration(minutes: 2));
      when(
        () => streamService.getUsherUrl(
          userLogin: any(named: 'userLogin'),
          forceFreshToken: any(named: 'forceFreshToken'),
        ),
      ).thenThrow(const NetworkException('offline'));

      store.handlePausePlay();
      await tick(0, 0);

      expect(native.callsNamed('play'), hasLength(1));
      expect(native.callsNamed('load'), isEmpty);
      expect(store.liveJumps, 0);
    });

    test('coming back to the app jumps at once when far behind', () async {
      store = await createStore(now: () => now);
      await native.emit({'type': 'state', 'state': 'PLAYING'});
      await tick(2300, 20);

      store.handleAppResume();
      await tick(12000, 1);

      expect(native.callsNamed('load'), hasLength(1));
    });

    test('a drift jump is dropped when the viewer paused meanwhile', () async {
      store = await createStore(now: () => now);
      await native.emit({'type': 'state', 'state': 'PLAYING'});
      await tick(2300, 20);
      final url = Completer<String>();
      when(
        () => streamService.getUsherUrl(
          userLogin: any(named: 'userLogin'),
          forceFreshToken: any(named: 'forceFreshToken'),
        ),
      ).thenAnswer((_) => url.future);

      await tick(7000, 11);
      // The playlist request is slow; the viewer pauses before it is back.
      store.handlePausePlay();
      await native.emit({'type': 'state', 'state': 'IDLE'});
      url.complete(_usherUrl);
      await tick(0, 0);

      expect(native.callsNamed('load'), isEmpty);
      expect(store.liveJumps, 0);
    });

    test('a jump whose load fails goes to recovery', () async {
      store = await createStore(now: () => now);
      await native.emit({'type': 'state', 'state': 'PLAYING'});
      await tick(2300, 20);
      native.loadThrows = true;

      await tick(7000, 11);

      expect(native.callsNamed('load').length, greaterThan(1));
      expect(store.status, isNot(IvsPlaybackStatus.playing));
    });

    test('a second tap while resuming waits for the jump', () async {
      store = await createStore(now: () => now);
      await native.emit({'type': 'state', 'state': 'PLAYING'});
      await tick(2300, 5);
      store.handlePausePlay();
      await native.emit({'type': 'state', 'state': 'IDLE'});
      now = now.add(const Duration(minutes: 1));

      store
        ..handlePausePlay()
        ..handlePausePlay();
      await tick(0, 0);

      expect(native.callsNamed('play'), isEmpty);
      expect(native.callsNamed('load'), hasLength(1));
    });

    test('resetStats clears the jump count', () async {
      store = await createStore(now: () => now);
      await native.emit({'type': 'state', 'state': 'PLAYING'});
      await tick(2300, 20);
      await tick(7000, 11);
      expect(store.liveJumps, 1);

      store.resetStats();

      expect(store.liveJumps, 0);
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
          () => streamService.getUsherUrl(
            userLogin: any(named: 'userLogin'),
            forceFreshToken: any(named: 'forceFreshToken'),
          ),
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

    test('a failed offline check is retried, not taken for offline', () async {
      store = await createStore();
      when(
        () => twitchApi.getStream(userLogin: any(named: 'userLogin')),
      ).thenThrow(const NetworkException('no network'));

      await native.emit({'type': 'error', 'errorType': 'ERROR_NOT_AVAILABLE'});
      for (var i = 0; i < 5; i++) {
        await settle();
      }

      expect(store.status, isNot(IvsPlaybackStatus.offline));
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

  group('content warning', () {
    test('covered before it plays: held, then started on clear', () async {
      store = await createStore();
      store.setContentGate(ContentGate.covering);
      // Not playing yet: nothing to pause, and above all no toggle (it
      // would start the stream behind the cover).
      expect(native.callsNamed('play'), isEmpty);

      await native.emit({'type': 'state', 'state': 'PLAYING'});
      expect(native.callsNamed('pause'), hasLength(1));
      await native.emit({'type': 'state', 'state': 'IDLE'});

      store.setContentGate(ContentGate.clear);
      expect(native.callsNamed('play'), hasLength(1));

      // Clear: the native auto-play is left alone again.
      native.playerCalls.clear();
      await native.emit({'type': 'state', 'state': 'PLAYING'});
      expect(native.callsNamed('pause'), isEmpty);
    });

    test('covered while playing: an explicit pause, resumed once', () async {
      store = await createStore();
      await native.emit({'type': 'state', 'state': 'PLAYING'});
      native.playerCalls.clear();

      store.setContentGate(ContentGate.covering);
      store.setContentGate(ContentGate.covering);
      expect(native.callsNamed('pause'), hasLength(1));
      expect(native.callsNamed('play'), isEmpty);
      await native.emit({'type': 'state', 'state': 'IDLE'});

      store.setContentGate(ContentGate.clear);
      store.setContentGate(ContentGate.clear);
      expect(native.callsNamed('play'), hasLength(1));
    });

    test('pending: playback goes on, nothing is held', () async {
      store = await createStore();
      store.setContentGate(ContentGate.pending);
      await native.emit({'type': 'state', 'state': 'PLAYING'});
      expect(native.callsNamed('pause'), isEmpty);
      expect(store.contentGate, ContentGate.pending);

      // Cleared without ever covering: nothing to resume.
      store.setContentGate(ContentGate.clear);
      expect(native.callsNamed('play'), isEmpty);
    });

    test('a stream the viewer paused is not started by a clear', () async {
      store = await createStore();
      await native.emit({'type': 'state', 'state': 'PLAYING'});
      store.handlePausePlay();
      await native.emit({'type': 'state', 'state': 'IDLE'});
      native.playerCalls.clear();

      store.setContentGate(ContentGate.covering);
      store.setContentGate(ContentGate.clear);
      expect(native.playerCalls, isEmpty);
    });
  });

  group('audio focus', () {
    const focusChannel = MethodChannel('onset/audio-focus-ivs-test');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    late List<String> focusCalls;
    late AudioFocus focus;
    var granted = true;

    setUp(() {
      focusCalls = [];
      granted = true;
      messenger.setMockMethodCallHandler(focusChannel, (call) async {
        focusCalls.add(call.method);
        return call.method == 'request' ? granted : null;
      });
      focus = AudioFocus(channel: focusChannel, supported: true);
    });

    tearDown(() => messenger.setMockMethodCallHandler(focusChannel, null));

    Future<void> change(String state) => messenger.handlePlatformMessage(
      focusChannel.name,
      focusChannel.codec.encodeMethodCall(
        MethodCall('change', {'state': state}),
      ),
      (_) {},
    );

    test('held while playing, let go on a pause', () async {
      store = await createStore(audioFocus: focus);
      expect(focusCalls, isEmpty);

      await native.emit({'type': 'state', 'state': 'PLAYING'});
      await settle();
      expect(focusCalls, ['request']);

      await native.emit({'type': 'state', 'state': 'IDLE'});
      await settle();
      expect(focusCalls, ['request', 'abandon']);
    });

    test('a call pauses the stream and its end resumes it', () async {
      store = await createStore(audioFocus: focus);
      await native.emit({'type': 'state', 'state': 'PLAYING'});
      await settle();

      await change('lossTransient');
      expect(native.callsNamed('pause'), hasLength(1));
      await native.emit({'type': 'state', 'state': 'IDLE'});
      await settle();
      expect(focusCalls.last, 'request', reason: 'kept to hear the gain');

      await change('gain');
      expect(native.callsNamed('play'), hasLength(1));
    });

    test('another app or unplugged headphones pause for good', () async {
      store = await createStore(audioFocus: focus);
      await native.emit({'type': 'state', 'state': 'PLAYING'});
      await settle();

      await change('noisy');
      expect(native.callsNamed('pause'), hasLength(1));
      await native.emit({'type': 'state', 'state': 'IDLE'});
      await settle();
      await change('gain');
      expect(native.callsNamed('play'), isEmpty);

      await native.emit({'type': 'state', 'state': 'PLAYING'});
      await settle();
      await change('loss');
      expect(native.callsNamed('pause'), hasLength(2));
    });

    test('a lasting loss during a call lets the focus go', () async {
      store = await createStore(audioFocus: focus);
      await native.emit({'type': 'state', 'state': 'PLAYING'});
      await settle();
      await change('lossTransient');
      await native.emit({'type': 'state', 'state': 'IDLE'});
      await settle();

      await change('loss');
      await settle();
      expect(focusCalls.last, 'abandon');

      await native.emit({'type': 'state', 'state': 'PLAYING'});
      await settle();
      expect(focusCalls.last, 'request', reason: 'asked for again');
    });

    test('a pause asked for during a call is kept after it', () async {
      final audioChannel = const MethodChannel('onset/bg-focus-test');
      messenger.setMockMethodCallHandler(audioChannel, (_) async => null);
      final audio = BackgroundAudio(channel: audioChannel, supported: true);
      settingsStore.backgroundAudio = true;
      store = await createStore(audioFocus: focus, backgroundAudio: audio);
      await native.emit({'type': 'state', 'state': 'PLAYING'});
      await settle();
      await change('lossTransient');
      await native.emit({'type': 'state', 'state': 'IDLE'});
      await settle();

      await messenger.handlePlatformMessage(
        audioChannel.name,
        audioChannel.codec.encodeMethodCall(
          const MethodCall('command', {'action': 'stop'}),
        ),
        (_) {},
      );
      await settle();
      await change('gain');

      expect(native.callsNamed('play'), isEmpty);
      expect(focusCalls.last, 'abandon');
      messenger.setMockMethodCallHandler(audioChannel, null);
    });

    test('a refused focus pauses an automatic start until given', () async {
      granted = false;
      store = await createStore(audioFocus: focus);
      await native.emit({'type': 'state', 'state': 'PLAYING'});
      await settle();
      expect(native.callsNamed('pause'), hasLength(1));
      await native.emit({'type': 'state', 'state': 'IDLE'});
      await settle();

      await change('gain');
      expect(native.callsNamed('play'), hasLength(1));
    });

    test('playing again during a call is the viewer\'s choice', () async {
      store = await createStore(audioFocus: focus);
      await native.emit({'type': 'state', 'state': 'PLAYING'});
      await settle();
      await change('lossTransient');
      await native.emit({'type': 'state', 'state': 'IDLE'});
      await settle();

      granted = false;
      store.handlePausePlay();
      await native.emit({'type': 'state', 'state': 'PLAYING'});
      await settle();

      expect(native.callsNamed('pause'), hasLength(1));
    });

    test('the end of a call does not play under a VOD', () async {
      store = await createStore(audioFocus: focus);
      await native.emit({'type': 'state', 'state': 'PLAYING'});
      await settle();
      await change('lossTransient');
      await native.emit({'type': 'state', 'state': 'IDLE'});
      await settle();

      store.setFocusSuppressed(true);
      await change('gain');

      expect(native.callsNamed('play'), isEmpty);
    });

    test('closing the player lets the focus go', () async {
      store = await createStore(audioFocus: focus);
      await native.emit({'type': 'state', 'state': 'PLAYING'});
      await settle();

      store.dispose();
      created = null;
      await settle();
      expect(focusCalls.last, 'abandon');
    });
  });

  group('background audio', () {
    const audioChannel = MethodChannel('onset/background-audio-ivs-test');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    late List<MethodCall> audioCalls;
    late BackgroundAudio audio;

    setUp(() {
      audioCalls = [];
      messenger.setMockMethodCallHandler(audioChannel, (call) async {
        audioCalls.add(call);
        return null;
      });
      audio = BackgroundAudio(channel: audioChannel, supported: true);
    });

    tearDown(() => messenger.setMockMethodCallHandler(audioChannel, null));

    Future<void> press(String action) => messenger.handlePlatformMessage(
      audioChannel.name,
      audioChannel.codec.encodeMethodCall(
        MethodCall('command', {'action': action}),
      ),
      (_) {},
    );

    test('off by default: no notification', () async {
      store = await createStore(backgroundAudio: audio);
      await native.emit({'type': 'state', 'state': 'PLAYING'});
      await settle();

      expect(audioCalls, isEmpty);
    });

    test('shows the playing stream and follows pauses', () async {
      settingsStore.backgroundAudio = true;
      store = await createStore(backgroundAudio: audio);
      expect(audioCalls, isEmpty, reason: 'nothing plays yet');

      await native.emit({'type': 'state', 'state': 'PLAYING'});
      await settle();
      expect(audioCalls.last.method, 'show');
      expect((audioCalls.last.arguments as Map)['playing'], isTrue);
      expect((audioCalls.last.arguments as Map)['title'], isNotEmpty);

      await native.emit({'type': 'state', 'state': 'IDLE'});
      await settle();
      expect(audioCalls.last.method, 'show');
      expect((audioCalls.last.arguments as Map)['playing'], isFalse);
    });

    test('media buttons play, pause and stop the stream', () async {
      settingsStore.backgroundAudio = true;
      store = await createStore(backgroundAudio: audio);
      await native.emit({'type': 'state', 'state': 'PLAYING'});
      await settle();

      await press('pause');
      expect(native.callsNamed('pause'), hasLength(1));
      await native.emit({'type': 'state', 'state': 'IDLE'});
      await press('play');
      expect(native.callsNamed('play'), hasLength(1));
      await native.emit({'type': 'state', 'state': 'PLAYING'});
      await settle();

      audioCalls.clear();
      await press('stop');
      await settle();
      expect(native.callsNamed('pause'), hasLength(2));
      expect(audioCalls.map((c) => c.method), contains('hide'));

      // Stopped: pausing does not bring it back...
      await native.emit({'type': 'state', 'state': 'IDLE'});
      await settle();
      expect(audioCalls.last.method, 'hide');
      // ...playing again does.
      await native.emit({'type': 'state', 'state': 'PLAYING'});
      await settle();
      expect(audioCalls.last.method, 'show');
    });

    test('turning it off or closing the player hides it', () async {
      settingsStore.backgroundAudio = true;
      store = await createStore(backgroundAudio: audio);
      await native.emit({'type': 'state', 'state': 'PLAYING'});
      await settle();

      settingsStore.backgroundAudio = false;
      await settle();
      expect(audioCalls.last.method, 'hide');

      settingsStore.backgroundAudio = true;
      await settle();
      expect(audioCalls.last.method, 'show');

      store.dispose();
      created = null;
      await settle();
      expect(audioCalls.last.method, 'hide');
    });
  });

  group('refused streams', () {
    test('a refusal twitch announced falls back at once, explained', () async {
      when(
        () => streamService.refusalFor('streamer'),
      ).thenReturn(PlaybackRefusal.subscribersOnly);
      var fatal = 0;
      store = await createStore();
      store.onFatalError = () => fatal++;

      await native.emit({'type': 'error', 'errorType': 'ERROR_AUTHORIZATION'});
      await settle();
      await settle();

      expect(fatal, 1);
      expect(store.status, IvsPlaybackStatus.failed);
      expect(store.refusalNotice?.text(L10n.english), contains('subscribers'));
      verifyNever(
        () => streamService.getUsherUrl(
          userLogin: 'streamer',
          forceFreshToken: true,
        ),
      );
    });

    test('rejected tokens end with the reason usher gives', () async {
      when(
        () => streamService.usherRefusal(_usherUrl),
      ).thenAnswer((_) async => 'Content Restricted In Region');
      var fatal = 0;
      final logged = <String>[];
      final print = debugPrint;
      debugPrint = (message, {wrapWidth}) {
        if (message != null) logged.add(message);
      };
      addTearDown(() => debugPrint = print);
      store = await createStore();
      store.onFatalError = () => fatal++;

      for (var i = 0; i < 4; i++) {
        await native.emit({'type': 'error', 'code': 403});
        await settle();
        await settle();
      }
      for (var i = 0; i < 4; i++) {
        await settle();
      }

      expect(fatal, 1);
      expect(
        store.refusalNotice?.text(L10n.english),
        contains('Content Restricted In Region'),
      );
      // Usher's English words are logged whatever the language on screen.
      expect(logged, contains(contains('Content Restricted In Region')));
      // French only says Twitch refused.
      expect(
        store.refusalNotice?.text(lookupAppLocalizations(const Locale('fr'))),
        'Twitch refuse ce live.',
      );
    });

    test('the player still gives up when usher cannot be asked', () async {
      when(
        () => streamService.usherRefusal(any()),
      ).thenAnswer((_) async => throw Exception('network down'));
      var fatal = 0;
      store = await createStore();
      store.onFatalError = () => fatal++;

      for (var i = 0; i < 4; i++) {
        await native.emit({'type': 'error', 'code': 403});
        await settle();
        await settle();
      }
      for (var i = 0; i < 4; i++) {
        await settle();
      }

      expect(fatal, 1);
      expect(store.refusalNotice, isNull);
    });

    test('a reload failing on its own is not taken for a refusal', () async {
      var fatal = 0;
      store = await createStore();
      store.onFatalError = () => fatal++;
      when(
        () => streamService.getUsherUrl(
          userLogin: any(named: 'userLogin'),
          forceFreshToken: any(named: 'forceFreshToken'),
        ),
      ).thenThrow(const NetworkException('offline'));

      await native.emit({'type': 'error', 'code': 403});
      for (var i = 0; i < 12; i++) {
        await settle();
      }

      expect(fatal, 1);
      expect(store.refusalNotice, isNull);
      verifyNever(() => streamService.usherRefusal(any()));
    });

    test('other failures fall back without asking usher', () async {
      var fatal = 0;
      store = await createStore();
      store.onFatalError = () => fatal++;

      await native.emit({'type': 'error', 'errorType': 'ERROR_NOT_SUPPORTED'});
      await settle();

      expect(fatal, 1);
      expect(store.refusalNotice, isNull);
      verifyNever(() => streamService.usherRefusal(any()));
    });

    test('a refusal message names each reason', () {
      expect(
        playbackRefusalNotice(
          PlaybackRefusal.subscribersOnly,
          'Streamer',
          L10n.english,
        ),
        'Streamer is streaming for subscribers only.',
      );
      expect(
        playbackRefusalNotice(
          PlaybackRefusal.geoblocked,
          'Streamer',
          L10n.english,
        ),
        'This stream is not available in your region.',
      );
      expect(
        playbackRefusalNotice(
          PlaybackRefusal.bannedFromChannel,
          'Streamer',
          L10n.english,
        ),
        'You’re banned from Streamer’s channel.',
      );
      expect(
        playbackRefusalNotice(
          PlaybackRefusal.unauthorized,
          'Streamer',
          L10n.english,
        ),
        'Twitch won’t play this stream in the low-latency player.',
      );
    });
  });

  group('token fetch', () {
    test(
      'retries transient token failures before creating the player',
      () async {
        var calls = 0;
        when(
          () => streamService.getUsherUrl(
            userLogin: any(named: 'userLogin'),
            forceFreshToken: any(named: 'forceFreshToken'),
          ),
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
        () => streamService.getUsherUrl(
          userLogin: any(named: 'userLogin'),
          forceFreshToken: any(named: 'forceFreshToken'),
        ),
      ).thenAnswer((_) async {
        calls++;
        throw const ApiException('No playback access token');
      });

      final s = IvsVideoStore(
        userLogin: 'streamer',
        userId: '123',
        twitchApi: twitchApi,
        authStore: anonymousAuthStore(),
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
        () => streamService.getUsherUrl(
          userLogin: any(named: 'userLogin'),
          forceFreshToken: any(named: 'forceFreshToken'),
        ),
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
          () => streamService.getUsherUrl(
            userLogin: any(named: 'userLogin'),
            forceFreshToken: any(named: 'forceFreshToken'),
          ),
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
        authStore: anonymousAuthStore(),
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
        authStore: anonymousAuthStore(),
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
        () => streamService.getUsherUrl(
          userLogin: any(named: 'userLogin'),
          forceFreshToken: any(named: 'forceFreshToken'),
        ),
      ).thenThrow(const ApiException('No playback access token'));
      final s = IvsVideoStore(
        userLogin: 'streamer',
        userId: '123',
        twitchApi: twitchApi,
        authStore: anonymousAuthStore(),
        settingsStore: settingsStore,
        streamService: streamService,
        recoveryPolicy: instantPolicy(),
      );
      created = s;
      await s.ready.catchError((Object _) {});

      // Helix still sees it live: not offline, so the WebView takes over.
      expect(await s.offlineAtStart, isFalse);
      expect(s.status, IvsPlaybackStatus.failed);
    });

    test('a channel offline at start keeps the native player', () async {
      when(
        () => streamService.getUsherUrl(
          userLogin: any(named: 'userLogin'),
          forceFreshToken: any(named: 'forceFreshToken'),
        ),
      ).thenThrow(const ApiException('No playback access token'));
      when(
        () => twitchApi.getStream(userLogin: any(named: 'userLogin')),
      ).thenThrow(const ApiException('streamer is offline', 404));
      final s = IvsVideoStore(
        userLogin: 'streamer',
        userId: '123',
        twitchApi: twitchApi,
        authStore: anonymousAuthStore(),
        settingsStore: settingsStore,
        streamService: streamService,
        recoveryPolicy: instantPolicy(),
      );
      created = s;
      await s.ready.catchError((Object _) {});

      expect(await s.offlineAtStart, isTrue);
      expect(s.status, IvsPlaybackStatus.offline);
      expect(s.paused, isTrue);
    });

    test('a failed check at start is not taken for offline', () async {
      when(
        () => streamService.getUsherUrl(
          userLogin: any(named: 'userLogin'),
          forceFreshToken: any(named: 'forceFreshToken'),
        ),
      ).thenThrow(const ApiException('No playback access token'));
      when(
        () => twitchApi.getStream(userLogin: any(named: 'userLogin')),
      ).thenThrow(const NetworkException('offline phone'));
      final s = IvsVideoStore(
        userLogin: 'streamer',
        userId: '123',
        twitchApi: twitchApi,
        authStore: anonymousAuthStore(),
        settingsStore: settingsStore,
        streamService: streamService,
        recoveryPolicy: instantPolicy(),
      );
      created = s;
      await s.ready.catchError((Object _) {});

      expect(await s.offlineAtStart, isFalse);
    });
  });

  group('faster start', () {
    test(
      'creates the native player while the url is still resolving',
      () async {
        final url = Completer<String>();
        when(
          () => streamService.getUsherUrl(
            userLogin: any(named: 'userLogin'),
            forceFreshToken: any(named: 'forceFreshToken'),
          ),
        ).thenAnswer((_) => url.future);
        final s = IvsVideoStore(
          userLogin: 'streamer',
          userId: '123',
          twitchApi: twitchApi,
          authStore: anonymousAuthStore(),
          settingsStore: settingsStore,
          streamService: streamService,
          recoveryPolicy: instantPolicy(),
        );
        created = s;
        for (var i = 0; i < 5; i++) {
          await settle();
        }

        expect(
          native.managerCalls.where((c) => c.method == 'create'),
          hasLength(1),
        );
        expect(s.textureId, native.textureId);
        expect(native.callsNamed('load'), isEmpty);

        url.complete(_usherUrl);
        for (var i = 0; i < 5; i++) {
          await settle();
        }

        final loads = native.callsNamed('load').toList();
        expect(loads, hasLength(1));
        expect((loads.single.arguments as Map)['url'], _usherUrl);
      },
    );

    test('disposing before the url resolves never loads', () async {
      final url = Completer<String>();
      when(
        () => streamService.getUsherUrl(
          userLogin: any(named: 'userLogin'),
          forceFreshToken: any(named: 'forceFreshToken'),
        ),
      ).thenAnswer((_) => url.future);
      final s = IvsVideoStore(
        userLogin: 'streamer',
        userId: '123',
        twitchApi: twitchApi,
        authStore: anonymousAuthStore(),
        settingsStore: settingsStore,
        streamService: streamService,
        recoveryPolicy: instantPolicy(),
      );
      for (var i = 0; i < 5; i++) {
        await settle();
      }
      s.dispose();
      url.complete(_usherUrl);
      for (var i = 0; i < 5; i++) {
        await settle();
      }

      expect(native.callsNamed('load'), isEmpty);
      expect(
        native.managerCalls.where((c) => c.method == 'dispose'),
        hasLength(1),
      );
    });

    test('ignores latency until the first frame plays', () async {
      store = await createStore();

      await native.emit({'type': 'latency', 'ms': 0});
      expect(store.latency, isNull);

      await native.emit({'type': 'state', 'state': 'PLAYING'});
      await native.emit({'type': 'latency', 'ms': 2100});
      expect(store.latency, '2.1s');
    });

    test('a rejected token reloads with a fresh one', () async {
      store = await createStore();

      await native.emit({'type': 'error', 'errorType': 'ERROR_AUTHORIZATION'});
      await settle();
      await settle();

      verify(
        () => streamService.getUsherUrl(
          userLogin: 'streamer',
          forceFreshToken: true,
        ),
      ).called(1);
    });
  });

  group('faster start robustness', () {
    IvsVideoStore build() {
      final s = IvsVideoStore(
        userLogin: 'streamer',
        userId: '123',
        twitchApi: twitchApi,
        authStore: anonymousAuthStore(),
        settingsStore: settingsStore,
        streamService: streamService,
        recoveryPolicy: instantPolicy(),
      );
      created = s;
      return s;
    }

    test('a refresh before the native player exists still loads', () async {
      native.createGate = Completer<void>();
      final s = build();
      await s.ready;
      final refresh = s.handleRefresh();
      await settle();
      native.createGate!.complete();
      await refresh;
      for (var i = 0; i < 6; i++) {
        await settle();
      }

      expect(native.callsNamed('load'), hasLength(1));
      expect(s.textureId, native.textureId);
    });

    test('a failed first load falls back to the web player', () async {
      native.loadThrows = true;
      var fatal = 0;
      final s = build()..onFatalError = () => fatal++;
      await s.ready;
      for (var i = 0; i < 6; i++) {
        await settle();
      }

      expect(fatal, 1);
      expect(s.status, IvsPlaybackStatus.failed);
    });

    test(
      'player creation failing while the url is pending falls back',
      () async {
        final url = Completer<String>();
        when(
          () => streamService.getUsherUrl(
            userLogin: any(named: 'userLogin'),
            forceFreshToken: any(named: 'forceFreshToken'),
          ),
        ).thenAnswer((_) => url.future);
        native.createThrows = true;
        var fatal = 0;
        final s = build()..onFatalError = () => fatal++;
        for (var i = 0; i < 4; i++) {
          await settle();
        }
        expect(fatal, 1);

        url.complete(_usherUrl);
        for (var i = 0; i < 4; i++) {
          await settle();
        }
        expect(fatal, 1);
        expect(native.callsNamed('load'), isEmpty);
        expect(s.status, IvsPlaybackStatus.failed);
      },
    );

    test(
      'a failed url lookup still releases the player exactly once',
      () async {
        when(
          () => streamService.getUsherUrl(
            userLogin: any(named: 'userLogin'),
            forceFreshToken: any(named: 'forceFreshToken'),
          ),
        ).thenThrow(const ApiException('No playback access token'));
        final s = build();
        await s.ready.catchError((Object _) {});
        for (var i = 0; i < 4; i++) {
          await settle();
        }
        s.dispose();
        created = null;
        await settle();

        expect(native.callsNamed('load'), isEmpty);
        expect(
          native.managerCalls.where((c) => c.method == 'dispose'),
          hasLength(1),
        );
      },
    );

    test('a manual refresh asks for a fresh token', () async {
      store = await createStore();

      await store.handleRefresh();

      verify(
        () => streamService.getUsherUrl(
          userLogin: 'streamer',
          forceFreshToken: true,
        ),
      ).called(1);
    });

    test('latency is hidden again until the reloaded stream plays', () async {
      store = await createStore();
      await native.emit({'type': 'state', 'state': 'PLAYING'});
      await native.emit({'type': 'latency', 'ms': 2500});

      await native.emit({'type': 'error', 'errorType': 'ERROR_NETWORK'});
      await settle();
      await settle();
      expect(native.callsNamed('load'), hasLength(1));

      await native.emit({'type': 'latency', 'ms': 0});
      expect(store.latencyMs, 2500, reason: 'pre-frame value ignored');

      await native.emit({'type': 'state', 'state': 'PLAYING'});
      await native.emit({'type': 'latency', 'ms': 1800});
      expect(store.latencyMs, 1800);
    });
  });

  group('quality and sound', () {
    test('restores the last chosen quality when qualities arrive', () async {
      SharedPreferences.setMockInitialValues({'last_stream_quality': '720p60'});
      store = await createStore();

      await native.emit({
        'type': 'qualities',
        'list': ['1080p60', '720p60', '480p'],
      });
      await settle();

      final call = native.callsNamed('setQuality').single;
      expect((call.arguments as Map)['name'], '720p60');
      expect(store.streamQuality, '720p60');
    });

    test('picks the highest quality when that setting is on', () async {
      SharedPreferences.setMockInitialValues({});
      settingsStore.defaultToHighestQuality = true;
      store = await createStore();

      await native.emit({
        'type': 'qualities',
        'list': ['1440p60', '1080p60'],
      });
      await settle();

      expect(
        (native.callsNamed('setQuality').single.arguments as Map)['name'],
        '1440p60',
      );
    });

    test('moves to 2K when it shows up after playback starts', () async {
      SharedPreferences.setMockInitialValues({});
      settingsStore.defaultToHighestQuality = true;
      store = await createStore();
      await native.emit({
        'type': 'qualities',
        'list': ['1080p60', '720p60'],
      });
      await settle();
      native.playerCalls.clear();

      await native.emit({
        'type': 'qualitiesChanged',
        'list': ['1440p60', '1080p60', '720p60'],
      });
      await settle();

      expect(
        (native.callsNamed('setQuality').single.arguments as Map)['name'],
        '1440p60',
      );
      expect(store.availableStreamQualities.first, 'Auto');
      expect(store.availableStreamQualities[1], '1440p60');
    });

    test('a quality picked this session stays when the ladder grows', () async {
      SharedPreferences.setMockInitialValues({});
      settingsStore.defaultToHighestQuality = true;
      store = await createStore();
      await native.emit({
        'type': 'qualities',
        'list': ['1080p60', '720p60'],
      });
      await settle();
      store.setStreamQuality('720p60');
      native.playerCalls.clear();

      await native.emit({
        'type': 'qualitiesChanged',
        'list': ['1440p60', '1080p60', '720p60'],
      });
      await settle();

      expect(native.callsNamed('setQuality'), isEmpty);
      expect(store.streamQuality, '720p60');
    });

    test('stays on Auto with no saved quality', () async {
      SharedPreferences.setMockInitialValues({});
      store = await createStore();

      await native.emit({
        'type': 'qualities',
        'list': ['1080p60', '720p60'],
      });
      await settle();

      expect(native.callsNamed('setQuality'), isEmpty);
      expect(store.streamQuality, 'Auto');
    });

    test('re-applies a quality chosen this session after a reload', () async {
      SharedPreferences.setMockInitialValues({});
      store = await createStore();
      await native.emit({
        'type': 'qualities',
        'list': ['1080p60', '720p60'],
      });
      store.setStreamQuality('720p60');
      native.playerCalls.clear();

      await native.emit({
        'type': 'qualities',
        'list': ['1080p60', '720p60'],
      });
      await settle();

      expect(
        (native.callsNamed('setQuality').single.arguments as Map)['name'],
        '720p60',
      );
    });

    test('a quality chosen this session beats the saved one', () async {
      SharedPreferences.setMockInitialValues({'last_stream_quality': '720p60'});
      settingsStore.defaultToHighestQuality = true;
      store = await createStore();
      await native.emit({
        'type': 'qualities',
        'list': ['1080p60', '720p60', '480p'],
      });
      await settle();
      store.setStreamQuality('480p');
      native.playerCalls.clear();

      await native.emit({
        'type': 'qualities',
        'list': ['1080p60', '720p60', '480p'],
      });
      await settle();

      expect(
        native
            .callsNamed('setQuality')
            .map((c) => (c.arguments as Map)['name']),
        ['480p'],
      );
    });

    test('a session audio only pick survives a reload', () async {
      settingsStore.defaultToHighestQuality = true;
      store = await createStore();
      await native.emit({
        'type': 'qualities',
        'list': ['1080p60', 'audio_only'],
      });
      await settle();
      store.setStreamQuality('audio_only');
      native.playerCalls.clear();

      await native.emit({
        'type': 'qualities',
        'list': ['1080p60', 'audio_only'],
      });
      await settle();

      expect(
        native
            .callsNamed('setQuality')
            .map((c) => (c.arguments as Map)['name']),
        ['audio_only'],
      );
    });

    test('a session Auto pick stays Auto after a reload', () async {
      SharedPreferences.setMockInitialValues({'last_stream_quality': 'Auto'});
      settingsStore.defaultToHighestQuality = true;
      store = await createStore();
      await native.emit({
        'type': 'qualities',
        'list': ['1440p60', '1080p60'],
      });
      await settle();
      store.setStreamQuality('Auto');
      native.playerCalls.clear();

      await native.emit({
        'type': 'qualities',
        'list': ['1440p60', '1080p60'],
      });
      await settle();

      expect(native.callsNamed('setQuality'), isEmpty);
      expect(native.callsNamed('setAutoQuality'), hasLength(1));
      expect(store.streamQuality, 'Auto');
    });

    test('a user pick during the restore is not overridden', () async {
      SharedPreferences.setMockInitialValues({'last_stream_quality': '720p60'});
      store = await createStore();

      await native.emit({
        'type': 'qualities',
        'list': ['1080p60', '720p60', '480p'],
      });
      store.setStreamQuality('480p');
      await settle();
      await settle();

      expect(store.streamQuality, '480p');
    });

    test(
      'a session quality missing after reload falls back to the saved one',
      () async {
        SharedPreferences.setMockInitialValues({
          'last_stream_quality': '720p60',
        });
        store = await createStore();
        await native.emit({
          'type': 'qualities',
          'list': ['1440p60', '720p60'],
        });
        await settle();
        store.setStreamQuality('1440p60');
        native.playerCalls.clear();

        await native.emit({
          'type': 'qualities',
          'list': ['1080p60', '720p60'],
        });
        await settle();

        expect(
          native
              .callsNamed('setQuality')
              .map((c) => (c.arguments as Map)['name']),
          ['720p60'],
        );
      },
    );

    test('a restore pending at dispose does nothing', () async {
      SharedPreferences.setMockInitialValues({'last_stream_quality': '720p60'});
      store = await createStore();

      await native.emit({
        'type': 'qualities',
        'list': ['1080p60', '720p60'],
      });
      store.dispose();
      created = null;
      await settle();
      await settle();

      expect(native.callsNamed('setQuality'), isEmpty);
    });

    test('changing the volume unmutes', () async {
      store = await createStore();
      store.toggleMute();

      store.setVolume(0.5);

      expect(store.muted, isFalse);
      await settle();
      expect(
        (native.callsNamed('setMuted').last.arguments as Map)['muted'],
        isFalse,
      );
    });

    test('mute and volume are sent to the player', () async {
      store = await createStore();

      store.setVolume(1.5);
      store.toggleMute();
      await settle();

      expect(store.muted, isTrue);
      expect(store.volume, 1.0);
      expect(
        (native.callsNamed('setMuted').last.arguments as Map)['muted'],
        isTrue,
      );
      expect(
        (native.callsNamed('setVolume').last.arguments as Map)['volume'],
        1.0,
      );

      store.setVolume(-1);
      expect(store.volume, 0.0);
    });

    test('mute and volume survive a reload', () async {
      store = await createStore();
      store.setVolume(0.4);
      store.toggleMute();
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

  group('playback focus', () {
    test('while another player has focus, playing is paused again', () async {
      final store = await createStore();
      store.setFocusSuppressed(true);

      await native.emit({'type': 'state', 'state': 'PLAYING'});
      await settle();

      expect(native.callsNamed('pause'), hasLength(1));
    });

    test('with focus back, playing is left alone', () async {
      final store = await createStore();
      store
        ..setFocusSuppressed(true)
        ..setFocusSuppressed(false);

      await native.emit({'type': 'state', 'state': 'PLAYING'});
      await settle();

      expect(native.callsNamed('pause'), isEmpty);
    });
  });

  group('live state over EventSub', () {
    late Map<String, StreamController<EventSubTopicEvent>> topics;

    EventSubHandle listen(EventSubTopic topic) {
      final events = StreamController<EventSubTopicEvent>.broadcast();
      topics[topic.type] = events;
      return EventSubHandle.forTesting(topic, events.stream, () {});
    }

    Future<void> goOffline(IvsVideoStore store) async {
      when(
        () => twitchApi.getStream(userLogin: any(named: 'userLogin')),
      ).thenThrow(const NotFoundException('offline'));
      await native.emit({'type': 'error', 'errorType': 'ERROR_NOT_AVAILABLE'});
      for (var i = 0; i < 5; i++) {
        await settle();
      }
      expect(store.status, IvsPlaybackStatus.offline);
      native.playerCalls.clear();
    }

    void backLive() {
      final live = StreamTwitch.fromJson(
        (twitchStreamResponse['data']! as List).first as Map<String, dynamic>,
      );
      when(
        () => twitchApi.getStream(userLogin: any(named: 'userLogin')),
      ).thenAnswer((_) async => live);
    }

    setUp(() => topics = {});

    test('listens to the channel only when it can', () async {
      store = await createStore();
      expect(topics, isEmpty);
      store.dispose();
      created = null;

      store = await createStore(listenEvents: listen);
      expect(topics.keys, ['stream.online']);
    });

    test('the channel going live restarts an offline player', () async {
      store = await createStore(listenEvents: listen);
      await goOffline(store);
      backLive();

      topics['stream.online']!.add(const EventSubData({}));
      for (var i = 0; i < 10; i++) {
        await settle();
      }

      expect(native.callsNamed('load'), hasLength(1));
      expect(store.status, isNot(IvsPlaybackStatus.offline));
    });

    test('a playing player ignores a late online event', () async {
      store = await createStore(listenEvents: listen);
      topics['stream.online']!.add(const EventSubData({}));
      for (var i = 0; i < 10; i++) {
        await settle();
      }
      expect(native.callsNamed('load'), isEmpty);
    });

    test('after a gap, an offline player checks whether it is live', () async {
      store = await createStore(listenEvents: listen);
      await goOffline(store);

      // Still offline: nothing happens.
      topics['stream.online']!.add(const EventSubListening(afterGap: true));
      for (var i = 0; i < 10; i++) {
        await settle();
      }
      expect(native.callsNamed('load'), isEmpty);

      backLive();
      topics['stream.online']!.add(const EventSubListening(afterGap: true));
      for (var i = 0; i < 10; i++) {
        await settle();
      }
      expect(native.callsNamed('load'), hasLength(1));
    });

    test('a fresh push keeps retrying past the retry budget', () async {
      var fatal = 0;
      store = await createStore(listenEvents: listen);
      store.onFatalError = () => fatal++;
      when(
        () => twitchApi.getStream(userLogin: any(named: 'userLogin')),
      ).thenThrow(const ApiException('streamer is offline', 404));

      topics['stream.online']!.add(const EventSubData({}));
      await settle();
      for (var i = 0; i < 6; i++) {
        await native.emit({
          'type': 'error',
          'errorType': 'ERROR_NOT_AVAILABLE',
        });
        for (var j = 0; j < 5; j++) {
          await settle();
        }
      }

      expect(fatal, 0);
      expect(store.status, IvsPlaybackStatus.reconnecting);
    });

    test('going live while the player still recovers is not lost', () async {
      store = await createStore(listenEvents: listen);
      // Helix does not list the stream yet (it lags the push).
      when(
        () => twitchApi.getStream(userLogin: any(named: 'userLogin')),
      ).thenThrow(const ApiException('streamer is offline', 404));

      topics['stream.online']!.add(const EventSubData({}));
      await settle();
      await native.emit({'type': 'error', 'errorType': 'ERROR_NOT_AVAILABLE'});
      for (var i = 0; i < 10; i++) {
        await settle();
      }

      // Retried instead of settling offline.
      expect(store.status, isNot(IvsPlaybackStatus.offline));
      expect(native.callsNamed('load'), isNotEmpty);
    });
  });

  test('an offline player looks for its channel now and then', () async {
    store = await createStore(
      offlinePollInterval: const Duration(milliseconds: 20),
    );
    when(
      () => twitchApi.getStream(userLogin: any(named: 'userLogin')),
    ).thenThrow(const ApiException('streamer is offline', 404));
    await native.emit({'type': 'error', 'errorType': 'ERROR_NOT_AVAILABLE'});
    for (var i = 0; i < 5; i++) {
      await settle();
    }
    expect(store.status, IvsPlaybackStatus.offline);
    native.playerCalls.clear();

    // Still offline: nothing reloads.
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(native.callsNamed('load'), isEmpty);

    final live = StreamTwitch.fromJson(
      (twitchStreamResponse['data']! as List).first as Map<String, dynamic>,
    );
    when(
      () => twitchApi.getStream(userLogin: any(named: 'userLogin')),
    ).thenAnswer((_) async => live);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(native.callsNamed('load'), hasLength(1));
  });
}
