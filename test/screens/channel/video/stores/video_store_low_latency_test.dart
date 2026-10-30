import 'package:flutter_test/flutter_test.dart';
import 'package:onset/screens/channel/video/stores/video_store.dart';

void main() {
  group('the live web player low-latency mode', () {
    test("turns Twitch's own low-latency setting back on", () {
      const script = VideoStoreBase.lowLatencyModeScript;
      // The key the web player keeps the setting under (Twilight
      // `LOW_LATENCY_MODE`); it is on unless saved as false.
      expect(script, contains("getItem('lowLatencyModeEnabled') === 'false'"));
      expect(script, contains("setItem('lowLatencyModeEnabled', 'true')"));
      // The player reads it when it starts, so the page loads again.
      expect(script, contains('location.reload()'));
      expect(script, contains('return true;'));
    });

    test('reads whether the page is reloading strictly', () {
      expect(VideoStoreBase.reloadRequested(true), isTrue);
      expect(VideoStoreBase.reloadRequested('true'), isTrue);
      expect(VideoStoreBase.reloadRequested(false), isFalse);
      expect(VideoStoreBase.reloadRequested('false'), isFalse);
      expect(VideoStoreBase.reloadRequested(null), isFalse);
      expect(VideoStoreBase.reloadRequested('1'), isFalse);
    });
  });
}
