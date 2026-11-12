import 'package:dio/io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_stream_service.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/services/playback_preloader.dart';

class MockTwitchStreamService extends Mock implements TwitchStreamService {}

void main() {
  late MockTwitchStreamService service;
  late PlaybackPreloader preloader;

  setUp(() {
    service = MockTwitchStreamService();
    when(
      () => service.preload(any(), authToken: any(named: 'authToken')),
    ).thenAnswer((_) async {});
    preloader = PlaybackPreloader(service, isAndroid: true);
  });

  test('preloads for the native IVS player only', () {
    preloader
      ..preload(login: 'streamer', engine: PlayerEngine.ivs)
      ..preload(login: 'streamer', engine: PlayerEngine.twitchWeb)
      ..preload(login: '', engine: PlayerEngine.ivs);
    PlaybackPreloader(
      service,
      isAndroid: false,
    ).preload(login: 'other', engine: PlayerEngine.ivs);

    verify(() => service.preload('streamer')).called(1);
  });

  test('asks with the token the player will send', () {
    preloader.preload(
      login: 'streamer',
      engine: PlayerEngine.ivs,
      authToken: 'web-token',
    );

    verify(() => service.preload('streamer', authToken: 'web-token')).called(1);
  });

  test(
    'playback requests share one client that keeps idle sockets a minute',
    () {
      expect(
        PlaybackPreloader.http.httpClientAdapter,
        isA<IOHttpClientAdapter>(),
      );
      final adapter =
          PlaybackPreloader.http.httpClientAdapter as IOHttpClientAdapter;
      expect(
        adapter.createHttpClient!().idleTimeout,
        const Duration(seconds: 60),
      );
      expect(identical(PlaybackPreloader.http, PlaybackPreloader.http), isTrue);
    },
  );
}
