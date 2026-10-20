/// When the live web player page gets set up (`initVideo`).
///
/// Before the first setup the page's own low-latency mode is checked once:
/// when it was saved off the page turns it on and reloads itself, and the
/// setup waits for the reloaded page. The setup flag is taken before the
/// check is awaited, so a second page-finished event meanwhile never sets
/// the page up twice.
class WebPageInit {
  WebPageInit({
    required this.isPlayerPage,
    required this.ensureLowLatency,
    required this.init,
  });

  /// Whether a finished URL is the live player page.
  final bool Function(String url) isPlayerPage;

  /// Turns the player's low-latency mode on; true when the page reloads.
  final Future<bool> Function() ensureLowLatency;

  /// Sets the loaded player page up.
  final Future<void> Function() init;

  /// Set again by a refresh, which loads the page anew.
  var needsInit = true;

  var _lowLatencyChecked = false;

  Future<void> onPageFinished(String url) async {
    if (!isPlayerPage(url) || !needsInit) return;
    needsInit = false;
    if (!_lowLatencyChecked) {
      // Once per player: a page that would not keep the setting must not
      // reload forever.
      _lowLatencyChecked = true;
      if (await ensureLowLatency()) {
        // Set up the reloaded page instead.
        needsInit = true;
        return;
      }
    }
    await init();
  }
}
