/// A player that is a Twitch web page (the live or VOD web engine), where
/// Twitch can put its own interstitial, the mature-content warning, over the
/// video.
abstract interface class WebPagePlayer {
  /// Such an interstitial is on screen: controls drawn over the page must
  /// step aside so its buttons can be tapped.
  bool get webGateVisible;
}

/// Page JavaScript declaring `frostyGateShown()`: whether Twitch's content
/// warning (or its older mature interstitial) is visible in the page. A node
/// left hidden in the page does not count, so our controls never stay away
/// over a warning nobody sees.
const kTwitchWebGateShownJs = '''
      const frostyGateShown = () => Array.from(document.querySelectorAll(
        '[data-a-target*="content-classification-gate"],' +
        '[data-a-target="player-overlay-mature-accept"]'
      )).some((e) => e.getClientRects().length > 0 &&
        getComputedStyle(e).visibility !== 'hidden');
''';
