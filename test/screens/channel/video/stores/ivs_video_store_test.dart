import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/apis/twitch_stream_service.dart';
import 'package:frosty/models/stream.dart';
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

  Future<IvsVideoStore> createStore() async {
    final s = IvsVideoStore(
      userLogin: 'streamer',
      userId: '123',
      twitchApi: twitchApi,
      authStore: MockAuthStore(),
      settingsStore: settingsStore,
      streamService: streamService,
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
}
