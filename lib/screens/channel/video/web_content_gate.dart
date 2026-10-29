import 'package:flutter/foundation.dart';

/// A player that is a Twitch web page (the live or VOD web engine), where
/// Twitch can put its own interstitial, the mature-content warning, over the
/// video.
abstract interface class WebPagePlayer {
  /// Such an interstitial is on screen: controls drawn over the page must
  /// step aside so its buttons can be tapped.
  bool get webGateVisible;
}

/// Page JavaScript declaring `onsetGateShown()`: whether Twitch's content
/// warning (or its older mature interstitial) is visible in the page. A node
/// left hidden in the page does not count, so our controls never stay away
/// over a warning nobody sees.
const kTwitchWebGateShownJs = '''
      const onsetGateShown = () => Array.from(document.querySelectorAll(
        '[data-a-target*="content-classification-gate"],' +
        '[data-a-target="player-overlay-mature-accept"]'
      )).some((e) => e.getClientRects().length > 0 &&
        getComputedStyle(e).visibility !== 'hidden');
''';

/// Twitch's own content warning in a live web player page: watched on every
/// page load, and clicked only with the viewer's consent (warnings off, this
/// channel already accepted, or "Start watching" on our warning), never on
/// their behalf otherwise.
class WebContentGateClicker {
  WebContentGateClicker({
    required bool consent,
    required this.pollScript,
    required this.clickScript,
    required this.runJavaScript,
  }) : _consent = consent;

  /// Reports the warning to the app (never clicks).
  final String pollScript;

  /// Clicks the warning's button.
  final String clickScript;
  final Future<void> Function(String script) runJavaScript;

  bool _consent;
  var _pageReady = false;

  bool get consent => _consent;

  /// The page (re)loaded and its helpers are installed.
  Future<void> onPageReady() async {
    _pageReady = true;
    await _run(pollScript);
    if (_consent) await _run(clickScript);
  }

  /// The viewer accepted our warning: click Twitch's too, now if the page
  /// is there, otherwise when it is.
  Future<void> accept() async {
    _consent = true;
    if (_pageReady) await _run(clickScript);
  }

  Future<void> _run(String script) async {
    try {
      await runJavaScript(script);
    } catch (e) {
      debugPrint('Content gate script failed: ${e.runtimeType}');
    }
  }
}
