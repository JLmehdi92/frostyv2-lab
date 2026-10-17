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
}
