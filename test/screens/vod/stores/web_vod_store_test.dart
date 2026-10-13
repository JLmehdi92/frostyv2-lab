import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/screens/vod/stores/web_vod_store.dart';
import 'package:frosty/screens/vod/vod_player_controller.dart';
import 'package:mocktail/mocktail.dart';
import 'package:webview_flutter/webview_flutter.dart';

class MockWebViewController extends Mock implements WebViewController {}

void main() {
  late MockWebViewController web;
  late WebVodStore store;
  late List<String> scripts;

  setUp(() {
    web = MockWebViewController();
    scripts = [];
    when(() => web.runJavaScript(any())).thenAnswer((inv) async {
      scripts.add(inv.positionalArguments.single as String);
    });
    store = WebVodStore(
      vodId: 'v1000000001',
      startAt: const Duration(minutes: 5),
      knownLength: const Duration(hours: 1),
      controller: web,
    );
  });

  tearDown(() => store.dispose());

  group('embedUrl', () {
    test('plays the video in the embed from the start time', () {
      final uri = Uri.parse(
        webVodEmbedUrl(
          vodId: 'v1000000001',
          startAt: const Duration(hours: 1, minutes: 2, seconds: 3),
        ),
      );

      expect(uri.host, 'player.twitch.tv');
      expect(uri.queryParameters, {
        'video': 'v1000000001',
        'autoplay': 'true',
        'muted': 'false',
        'parent': 'frosty',
        'time': '1h2m3s',
      });
    });

    test('has no time at the start', () {
      final uri = Uri.parse(
        webVodEmbedUrl(vodId: '123', startAt: Duration.zero),
      );

      expect(uri.queryParameters['video'], 'v123');
      expect(uri.queryParameters.containsKey('time'), isFalse);
    });

    test('rejects an id that is not a VOD id', () {
      expect(
        () => webVodEmbedUrl(vodId: '1&x=2', startAt: Duration.zero),
        throwsArgumentError,
      );
    });
  });

  group('state messages', () {
    test('start loading at the requested time', () {
      expect(store.status, VodPlaybackStatus.loading);
      expect(store.position, const Duration(minutes: 5));
      expect(store.duration, const Duration(hours: 1));
      expect(store.qualities, ['Auto']);
    });

    test('update position, duration, rate and state', () {
      store.onStateMessage(
        '{"t":61.5,"d":7200,"p":false,"e":false,"r":1.5,"b":70,"w":false}',
      );

      expect(store.position, const Duration(milliseconds: 61500));
      expect(store.duration, const Duration(hours: 2));
      expect(store.buffered, const Duration(seconds: 70));
      expect(store.playbackRate, 1.5);
      expect(store.status, VodPlaybackStatus.playing);

      store.onStateMessage('{"t":62,"d":7200,"p":true,"e":false,"r":1.5}');
      expect(store.status, VodPlaybackStatus.paused);

      store.onStateMessage('{"t":62,"d":7200,"p":false,"w":true}');
      expect(store.status, VodPlaybackStatus.buffering);

      store.onStateMessage('{"t":7200,"d":7200,"p":true,"e":true}');
      expect(store.status, VodPlaybackStatus.ended);
      expect(store.ended, isTrue);
    });

    test('an unknown duration keeps the known length', () {
      store.onStateMessage('{"t":1,"d":null,"p":false}');

      expect(store.duration, const Duration(hours: 1));
    });

    test('garbage is ignored', () {
      for (final bad in ['', 'nope', '[]', '{"t":"x"}', '{"t":-5}']) {
        store.onStateMessage(bad);
      }

      expect(store.position, const Duration(minutes: 5));
      expect(store.status, VodPlaybackStatus.loading);
    });

    test('a poll right after a seek does not jump back', () {
      store.onStateMessage('{"t":10,"d":3600,"p":false}');
      store.seekTo(const Duration(minutes: 30));

      store.onStateMessage('{"t":11,"d":3600,"p":false}');
      expect(store.position, const Duration(minutes: 30));

      store.onStateMessage('{"t":1800.4,"d":3600,"p":false}');
      expect(store.position, const Duration(milliseconds: 1800400));
    });
  });

  group('commands', () {
    test('seek sends a clamped number of seconds', () {
      store.onStateMessage('{"t":10,"d":3600,"p":false}');

      store.seekTo(const Duration(hours: 9));
      store.seekTo(const Duration(seconds: -4));
      store.seekTo(const Duration(milliseconds: 61500));

      expect(scripts.where((s) => s.contains('currentTime')).toList(), [
        contains('currentTime = 3599.000'),
        contains('currentTime = 0.000'),
        contains('currentTime = 61.500'),
      ]);
    });

    test('rate only accepts the offered speeds', () {
      store.setPlaybackRate(1.25);
      store.setPlaybackRate(9);

      final rates = scripts.where((s) => s.contains('playbackRate')).toList();
      expect(rates, [contains('playbackRate = 1.25')]);
      expect(store.playbackRate, 1.25);
    });

    test('play, pause, mute and volume drive the video element', () {
      store
        ..play()
        ..pause()
        ..toggleMute()
        ..setVolume(0.4);

      expect(scripts, [
        contains('.play()'),
        contains('.pause()'),
        contains('muted = true'),
        contains('volume = 0.40'),
      ]);
      expect(store.muted, isFalse, reason: 'changing the volume unmutes');
    });

    test('play after the end restarts from the beginning', () {
      store.onStateMessage('{"t":3600,"d":3600,"p":true,"e":true}');

      store.play();

      expect(scripts.first, contains('currentTime = 0.000'));
      expect(scripts.last, contains('.play()'));
    });
  });

  test('without focus, playing is paused again', () {
    store.setFocused(false);

    store.onStateMessage('{"t":1,"d":3600,"p":false}');

    expect(scripts.single, contains('.pause()'));
  });

  test('ready completes: the web player is the last resort', () async {
    await expectLater(store.ready, completes);
  });
}
