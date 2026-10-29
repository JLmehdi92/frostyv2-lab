import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/apis/twitch_stream_service.dart';
import 'package:frosty/models/hls_variant.dart';
import 'package:frosty/screens/channel/video/player_controller.dart';
import 'package:frosty/screens/channel/video/stores/native_video_store.dart';
import 'package:frosty/screens/settings/stores/auth_store.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:media_kit/media_kit.dart';
import 'package:mocktail/mocktail.dart';
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

  NativeVideoStore create() {
    final api = MockTwitchApi();
    when(
      () => api.getStream(userLogin: any(named: 'userLogin')),
    ).thenThrow(Exception('offline'));
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

  test('covered before it opens: opened paused, started on clear', () async {
    final store = create();
    store.setContentGate(ContentGate.covering);
    variants.complete([variant]);
    await store.ready;

    verify(() => player.open(any(), play: false)).called(1);
    verifyNever(player.play);
    expect(isPlaying, isFalse);

    store.setContentGate(ContentGate.clear);
    verify(player.play).called(1);
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
    verify(player.play).called(1);
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
}
