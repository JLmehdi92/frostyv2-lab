import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/screens/channel/video/video_store.dart';
import 'package:frosty/screens/channel/video/web_content_gate.dart';
import 'package:frosty/screens/vod/stores/web_vod_store.dart';

void main() {
  group("the live web player and twitch's own warning", () {
    test('the page reports the warning, only when it changes', () {
      const script = VideoStoreBase.contentGatePollScript;
      expect(script, contains('content-classification-gate'));
      expect(script, contains('ContentGate.postMessage'));
      // Installed once per page, and silent while nothing changes.
      expect(script, contains('window._frostyGatePoll'));
      expect(script, contains('!== window._frostyGateShown'));
      // It only looks: clicking stays with the existing accept step.
      expect(script, isNot(contains('.click()')));
    });

    test('both web players look for the same, visible, warning', () {
      expect(kTwitchWebGateShownJs, contains('getClientRects'));
      expect(kTwitchWebGateShownJs, contains("visibility !== 'hidden'"));
      expect(
        VideoStoreBase.contentGatePollScript,
        contains(kTwitchWebGateShownJs),
      );
      expect(WebVodStoreBase.bridgeScript, contains(kTwitchWebGateShownJs));
    });

    test('reads the report strictly', () {
      expect(VideoStoreBase.gateVisibleFromMessage('true'), isTrue);
      expect(VideoStoreBase.gateVisibleFromMessage('false'), isFalse);
      expect(VideoStoreBase.gateVisibleFromMessage('yes'), isFalse);
      expect(VideoStoreBase.gateVisibleFromMessage(''), isFalse);
    });
  });

  group('our warning over the web player', () {
    test('holds the video paused, now and whenever it starts', () {
      const script = VideoStoreBase.holdScript;
      expect(script, contains('window._frostyHold = true'));
      expect(script, contains('v.pause()'));
      expect(script, contains("addEventListener('play'"));
      // The video may not exist yet: it waits for it.
      expect(script, contains('setInterval'));
      // Only the video: Twitch's own warning is the viewer's to accept.
      expect(script, isNot(contains('.click()')));
      expect(script, isNot(contains('.play()')));
    });

    test('lets it play again only if the hold stopped it', () {
      const script = VideoStoreBase.releaseScript;
      expect(script, contains('window._frostyHold = false'));
      expect(script, contains('if (window._frostyHeld)'));
      expect(script, contains('.play()'));
      expect(script, isNot(contains('.click()')));
    });
  });
}
