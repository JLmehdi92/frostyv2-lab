import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/base_api_client.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/apis/twitch_stream_service.dart';
import 'package:onset/models/hls_variant.dart';
import 'package:onset/models/stream.dart';
import 'package:onset/models/stream_push.dart';
import 'package:onset/screens/channel/video/player_controller.dart';
import 'package:onset/screens/channel/video/stores/native_video_store.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockPlayer extends Mock implements Player {}

class MockPlayerStream extends Mock implements PlayerStream {}

class MockTwitchApi extends Mock implements TwitchApi {}

class MockAuthStore extends Mock implements AuthStore {}

class MockStreamService extends Mock implements TwitchStreamService {}

void main() {
  late MockPlayer player;
  late MockStreamService service;
  late Completer<List<HlsVariant>> variants;
  late StreamController<bool> playing;
  var isPlaying = false;

  setUpAll(() => registerFallbackValue(Media('https://example.com')));

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    isPlaying = false;
    playing = StreamController<bool>.broadcast();
    player = MockPlayer();
    final streams = MockPlayerStream();
    when(() => player.stream).thenReturn(streams);
    when(() => streams.playing).thenAnswer((_) => playing.stream);
    when(
      () => streams.position,
    ).thenAnswer((_) => const Stream<Duration>.empty());
    when(() => player.state).thenAnswer((_) => PlayerState(playing: isPlaying));
    when(() => player.open(any(), play: any(named: 'play'))).thenAnswer((
      invocation,
    ) async {
      isPlaying = invocation.namedArguments[#play] as bool;
    });
    when(player.play).thenAnswer((_) async => isPlaying = true);
    when(player.pause).thenAnswer((_) async => isPlaying = false);
    when(player.playOrPause).thenAnswer((_) async {
      isPlaying = !isPlaying;
      playing.add(isPlaying);
    });
    when(player.dispose).thenAnswer((_) async {});

    service = MockStreamService();
    variants = Completer();
    when(
      () => service.getStreamVariants(
        userLogin: any(named: 'userLogin'),
        authToken: any(named: 'authToken'),
      ),
    ).thenAnswer((_) => variants.future);
  });

  tearDown(() => playing.close());

  NativeVideoStore create({StreamTwitch? live, MockTwitchApi? twitchApi}) {
    final api = twitchApi ?? MockTwitchApi();
    if (live == null) {
      when(
        () => api.getStream(userLogin: any(named: 'userLogin')),
      ).thenThrow(Exception('offline'));
    } else {
      when(
        () => api.getStream(userLogin: any(named: 'userLogin')),
      ).thenAnswer((_) async => live);
    }
    when(
      () => api.getChannel(userId: any(named: 'userId')),
    ).thenThrow(Exception('offline'));
    final auth = MockAuthStore();
    when(() => auth.twitchWebToken).thenReturn(null);
    when(() => auth.renewTwitchWebToken()).thenAnswer((_) async => null);
    return NativeVideoStore(
      userLogin: 'streamer',
      userId: '42',
      twitchApi: api,
      authStore: auth,
      settingsStore: SettingsStore.fromJson({}),
      streamService: service,
      nativePlayer: player,
    );
  }

  const variant = HlsVariant(name: '1080p60', url: 'https://usher/1080.m3u8');

  test('a pushed viewer count and title patch the stream info', () async {
    const live = StreamTwitch(
      '42',
      'streamer',
      'Streamer',
      '1',
      'Chess',
      'Old',
      10,
      '2026-01-01T00:00:00Z',
      'thumb',
    );
    final store = create(live: live);
    await pumpEventQueue();
    expect(store.streamInfo?.viewerCount, 10);

    store
      ..applyStreamPush(const ViewerCountPush(55))
      ..applyStreamPush(const BroadcastSettingsPush(title: 'New'));

    expect(store.streamInfo?.viewerCount, 55);
    expect(store.streamInfo?.title, 'New');
    expect(store.streamInfo?.gameName, 'Chess');
    store.dispose();
  });

  test('covered before it opens: opened paused, started on clear', () async {
    final store = create();
    store.setContentGate(ContentGate.covering);
    variants.complete([variant]);
    await store.ready;

    verify(() => player.open(any(), play: false)).called(1);
    verifyNever(player.play);
    expect(isPlaying, isFalse);

    // Accepted: re-opened, so it starts at the live edge, not where the
    // warning left it.
    store.setContentGate(ContentGate.clear);
    await pumpEventQueue();
    verify(
      () => player.open(
        any(),
        play: any(named: 'play', that: isTrue),
      ),
    ).called(1);
    expect(isPlaying, isTrue);
    store.dispose();
  });

  test('covered while playing: an explicit pause, never a toggle', () async {
    final store = create();
    variants.complete([variant]);
    await store.ready;
    expect(isPlaying, isTrue);
    clearInteractions(player);

    store.setContentGate(ContentGate.covering);
    verify(player.pause).called(1);
    verifyNever(player.playOrPause);

    // A quality change keeps it held.
    store.setStreamQuality('1080p60');
    verify(() => player.open(any(), play: false)).called(1);
    verifyNever(player.play);

    store.setContentGate(ContentGate.clear);
    await pumpEventQueue();
    verify(
      () => player.open(
        any(),
        play: any(named: 'play', that: isTrue),
      ),
    ).called(1);
    expect(isPlaying, isTrue);
    store.dispose();
  });

  test('pending changes nothing in playback', () async {
    final store = create();
    store.setContentGate(ContentGate.pending);
    variants.complete([variant]);
    await store.ready;
    verify(() => player.open(any(), play: any(named: 'play'))).called(1);
    verifyNever(() => player.open(any(), play: false));
    verify(player.play).called(1);
    store.dispose();
  });

  test('a resume while covered stays held, and plays once accepted', () async {
    // Pending, playing; another player pauses it, the labels then cover it.
    final store = create();
    variants.complete([variant]);
    await store.ready;
    store.setContentGate(ContentGate.pending);
    store.handlePausePlay();
    expect(isPlaying, isFalse);
    store.setContentGate(ContentGate.covering);
    clearInteractions(player);

    // The other player closes: its resume must not start the covered stream.
    store.handlePausePlay();
    await pumpEventQueue();
    expect(isPlaying, isFalse);
    verifyNever(player.play);

    store.setContentGate(ContentGate.clear);
    await pumpEventQueue();
    verify(
      () => player.open(
        any(),
        play: any(named: 'play', that: isTrue),
      ),
    ).called(1);
    expect(isPlaying, isTrue);
    store.dispose();
  });

  test('a play reported while covered is paused at once', () async {
    final store = create();
    variants.complete([variant]);
    await store.ready;
    isPlaying = false;
    store.setContentGate(ContentGate.covering);
    clearInteractions(player);

    // Whatever started it (the OS, a toggle, a late open).
    isPlaying = true;
    playing.add(true);
    await pumpEventQueue();
    verify(player.pause).called(1);
    expect(isPlaying, isFalse);

    store.setContentGate(ContentGate.clear);
    await pumpEventQueue();
    verify(
      () => player.open(
        any(),
        play: any(named: 'play', that: isTrue),
      ),
    ).called(1);
    store.dispose();
  });

  test('covered while the load is starting playback: held', () async {
    final started = Completer<void>();
    when(player.play).thenAnswer((_) => started.future);
    final store = create();
    variants.complete([variant]);
    await pumpEventQueue();
    // open(play: true) went out; play() has not returned yet.
    verify(
      () => player.open(
        any(),
        play: any(named: 'play', that: isTrue),
      ),
    ).called(1);
    isPlaying = false;

    store.setContentGate(ContentGate.covering);
    // Playback actually starts now.
    isPlaying = true;
    playing.add(true);
    started.complete();
    await store.ready;
    await pumpEventQueue();

    verify(player.pause).called(1);
    expect(isPlaying, isFalse);
    store.dispose();
  });

  group('overlay tap refresh while playing', () {
    const live = StreamTwitch(
      '42',
      'streamer',
      'Streamer',
      '1',
      'Chess',
      'Title',
      10,
      '2026-01-01T00:00:00Z',
      'thumb',
    );

    Future<(NativeVideoStore, MockTwitchApi)> playingStore() async {
      final api = MockTwitchApi();
      final store = create(live: live, twitchApi: api);
      variants.complete([variant]);
      await store.ready;
      await pumpEventQueue();
      expect(isPlaying, isTrue);
      return (store, api);
    }

    void tap(NativeVideoStore store) {
      if (store.overlayVisible) store.handleVideoTap();
      store.handleVideoTap();
    }

    test('a failed request keeps it playing', () async {
      final (store, api) = await playingStore();
      when(
        () => api.getStream(userLogin: any(named: 'userLogin')),
      ).thenThrow(const NetworkException('timeout'));

      tap(store);
      await pumpEventQueue();

      expect(store.paused, isFalse);
      expect(store.streamInfo, same(live));
      store.dispose();
    });

    test('an offline answer does not pause it', () async {
      final (store, api) = await playingStore();
      when(
        () => api.getStream(userLogin: any(named: 'userLogin')),
      ).thenThrow(const ApiException('streamer is offline', 404));

      tap(store);
      await pumpEventQueue();

      expect(store.paused, isFalse);
      expect(store.streamInfo, isNull);
      store.dispose();
    });

    test('quick taps make one request', () async {
      final (store, api) = await playingStore();
      clearInteractions(api);

      tap(store);
      tap(store);
      await pumpEventQueue();

      verify(
        () => api.getStream(userLogin: any(named: 'userLogin')),
      ).called(1);
      store.dispose();
    });
  });
}
