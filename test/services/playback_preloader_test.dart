import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_stream_service.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/services/playback_preloader.dart';
import 'package:mocktail/mocktail.dart';

class MockTwitchStreamService extends Mock implements TwitchStreamService {}

void main() {
  late MockTwitchStreamService service;
  late PlaybackPreloader preloader;

  setUp(() {
    service = MockTwitchStreamService();
    when(() => service.preload(any())).thenAnswer((_) async {});
    preloader = PlaybackPreloader(service);
  });

  test('preloads for the native IVS player only', () {
    preloader
      ..preload(login: 'streamer', engine: PlayerEngine.ivs)
      ..preload(login: 'streamer', engine: PlayerEngine.twitchWeb)
      ..preload(login: '', engine: PlayerEngine.ivs);

    verify(() => service.preload('streamer')).called(1);
  });
}
