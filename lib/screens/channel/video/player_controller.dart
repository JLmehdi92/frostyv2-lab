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
}
