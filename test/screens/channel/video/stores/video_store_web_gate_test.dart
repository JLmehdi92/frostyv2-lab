import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onset/screens/channel/video/stores/video_store.dart';
import 'package:onset/screens/channel/video/web_content_gate.dart';
import 'package:onset/screens/vod/stores/web_vod_store.dart';

void main() {
  group("the live web player and twitch's own warning", () {
    test('the page reports the warning, only when it changes', () {
      const script = VideoStoreBase.contentGatePollScript;
      expect(script, contains('content-classification-gate'));
      expect(script, contains('ContentGate.postMessage'));
      // Installed once per page, and silent while nothing changes.
      expect(script, contains('window._onsetGatePoll'));
      expect(script, contains('!== window._onsetGateShown'));
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
      expect(script, contains('window._onsetHold = true'));
      expect(script, contains('v.pause()'));
      expect(script, contains("addEventListener('play'"));
      // Every video of the page, including one that appears or replaces
      // the first later: watched until released, never given up on a timer.
      expect(script, contains("getElementsByTagName('video')"));
      expect(script, contains('new MutationObserver('));
      expect(script, contains('subtree: true'));
      expect(script, isNot(contains('setTimeout')));
      expect(script, isNot(contains('setInterval')));
      // Installed once per page.
      expect(script, contains('if (!window._onsetHoldObserver)'));
      // Only the video: Twitch's own warning is the viewer's to accept.
      expect(script, isNot(contains('.click()')));
      expect(script, isNot(contains('.play()')));
    });

    test('lets it play again only if the hold stopped it', () {
      const script = VideoStoreBase.releaseScript;
      expect(script, contains('window._onsetHold = false'));
      // Stops watching the page.
      expect(script, contains('window._onsetHoldObserver.disconnect()'));
      expect(script, contains('window._onsetHoldObserver = null'));
      expect(script, contains('if (window._onsetHeld)'));
      expect(script, contains('.play()'));
      expect(script, isNot(contains('.click()')));
    });

    test('held again on every page the web view loads', () {
      final code = File(
        'lib/screens/channel/video/stores/video_store.dart',
      ).readAsStringSync().replaceAll(RegExp(r'\s+'), '');
      expect(code, contains('everyPage:_holdIfCovered,'));
      expect(code, contains('onPageStarted:_pageInit.onPageStarted,'));
      expect(code, contains('onPageFinished:_pageInit.onPageFinished,'));
    });
  });
}
