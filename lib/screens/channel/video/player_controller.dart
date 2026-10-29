import 'package:frosty/models/channel.dart';
import 'package:frosty/models/stream.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';

/// The contract the video overlay and channel screen depend on, so they can
/// drive either the WebView engine ([VideoStore]) or the native low-latency
/// engine ([NativeVideoStore]) interchangeably.
///
/// Only members actually consumed by `channel.dart` and `video_overlay.dart`
/// belong here — keep it minimal.
abstract class PlayerController {
  SettingsStore get settingsStore;

  // Playback / overlay state
  bool get paused;
  bool get overlayVisible;
  bool get isInPipMode;

  // Stream info
  StreamTwitch? get streamInfo;
  Channel? get offlineChannelInfo;

  // Quality
  List<String> get availableStreamQualities;
  String get streamQuality;
  void setStreamQuality(String quality);
  Future<void> updateStreamQualities();

  // Latency (null when unknown)
  String? get latency;

  // Actions
  void handleVideoTap();
  void handleToggleOverlay();
  void handlePausePlay();
  Future<void> handleRefresh();
  void requestPictureInPicture();
  void togglePictureInPicture();
  void handleAppResume();
  void dispose();

  /// Where the mature-content warning stands. [ContentGate.covering]: the
  /// player pauses itself (an explicit pause, never a toggle), nothing
  /// starts it again and no picture-in-picture shows it until it is
  /// [ContentGate.clear], when it resumes what it held. While the labels
  /// are still being read ([ContentGate.pending]) playback goes on, but the
  /// stream may not leave for picture-in-picture or the mini player.
  ContentGate get contentGate;
  void setContentGate(ContentGate gate);
}

/// The mature-content warning of the channel screen, as the player sees it.
enum ContentGate {
  /// Its labels are being read: playback goes on, PiP and the mini player
  /// wait.
  pending,

  /// It covers the stream: held paused, no PiP.
  covering,

  /// Nothing to warn about, or accepted.
  clear;

  /// Whether the stream may leave the screen (PiP, the mini player).
  bool get allowsLeaving => this == clear;
}

/// The picture-in-picture window's play / pause: nothing unless the content
/// warning is clear (it was never accepted).
void pipPlayPause(PlayerController player) {
  if (!player.contentGate.allowsLeaving) return;
  player.handlePausePlay();
}
