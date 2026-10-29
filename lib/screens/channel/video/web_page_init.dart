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
    this.everyPage,
  });

  /// Whether a finished URL is the live player page.
  final bool Function(String url) isPlayerPage;

  /// Turns the player's low-latency mode on; true when the page reloads.
  final Future<bool> Function() ensureLowLatency;

  /// Sets the loaded player page up.
  final Future<void> Function() init;

  /// Runs on every page start and finish, whatever the page and whether or
  /// not it is set up (a reload the page does on its own included), before
  /// the setup: what each new document must be told again at once.
  final void Function()? everyPage;

  /// Set again by a refresh, which loads the page anew.
  var needsInit = true;

  var _lowLatencyChecked = false;

  void onPageStarted(String url) => everyPage?.call();

  Future<void> onPageFinished(String url) async {
    everyPage?.call();
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
