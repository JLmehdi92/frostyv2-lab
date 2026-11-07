import 'package:mobx/mobx.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';

/// The landscape chat layouts a double tap on the live video cycles
/// through, the way the Twitch app does: chat overlay → side column →
/// hidden → overlay.
///
/// The side column the double tap reaches is full screen beside the chat:
/// on a tablet the video then takes its whole column, without the channel's
/// info area under it (as it did before that area existed). "Show chat"
/// and every other path keep the tablet's side column with its info area.
/// Phones have one side column either way.
///
/// [plainSide] says which one is on screen:
/// - set when the double tap goes from the overlay to the side column;
/// - cleared as soon as full screen comes back, whatever brings it (the
///   double tap's next step, "Hide chat"): the side column reached from
///   there by "Show chat" is the tablet's;
/// - cleared by [reset] when the screen turns to portrait, which has one
///   layout (the fullscreen button in landscape goes there);
/// - never saved: a channel opened again, or restored from the mini
///   player, starts on the tablet's side column, as it always did.
class LandscapeChatCycle {
  LandscapeChatCycle(this.settings) {
    _endOnFullScreen = reaction((_) => settings.fullScreen, (bool fullScreen) {
      if (fullScreen) _plainSide = false;
    });
  }

  final SettingsStore settings;

  late final ReactionDisposer _endOnFullScreen;

  var _plainSide = false;

  /// Whether the side column on screen is the double tap's: the video
  /// takes its whole column, no info area under it.
  bool get plainSide => _plainSide && !settings.fullScreen;

  /// The next layout.
  void next() => _show(
    nextLandscapeChatMode(current, settings.switchableLandscapeChatModes),
  );

  LandscapeChatMode get current => !settings.fullScreen
      ? LandscapeChatMode.column
      : settings.fullScreenChatOverlay
      ? LandscapeChatMode.overlay
      : LandscapeChatMode.hidden;

  void _show(LandscapeChatMode mode) {
    switch (mode) {
      case LandscapeChatMode.column:
        _plainSide = true;
        settings.fullScreen = false;
      case LandscapeChatMode.hidden:
        settings
          ..fullScreen = true
          ..fullScreenChatOverlay = false;
      case LandscapeChatMode.overlay:
        settings
          ..fullScreen = true
          ..fullScreenChatOverlay = true;
    }
  }

  /// The screen turned to portrait.
  void reset() => _plainSide = false;

  void dispose() => _endOnFullScreen();
}

LandscapeChatMode nextLandscapeChatMode(
  LandscapeChatMode current,
  List<LandscapeChatMode> switchable,
) {
  const order = LandscapeChatMode.values;
  final start = order.indexOf(current);
  for (var step = 1; step <= order.length; step++) {
    final candidate = order[(start + step) % order.length];
    if (switchable.contains(candidate)) return candidate;
  }
  return current;
}
