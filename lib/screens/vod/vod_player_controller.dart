import 'package:frosty/apis/twitch_vod_service.dart';

/// Playback lifecycle of a VOD player.
enum VodPlaybackStatus {
  loading,
  playing,
  paused,
  buffering,
  ended,
  failed,
  problem,
}

/// Speeds offered for VODs, like the official app (0.5× to 2× by 0.25).
const kVodPlaybackRates = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

/// What the VOD screen depends on, so the native (IVS) and WebView engines
/// are interchangeable.
abstract class VodPlayerController {
  VodPlaybackStatus get status;

  /// Why playback is refused (sub-only, geo-blocked…) when [status] is
  /// [VodPlaybackStatus.problem].
  VodPlaybackProblem? get problem;

  Duration get position;
  Duration get duration;
  Duration get buffered;

  /// [position] in whole seconds, for observers that only need 1 Hz.
  int get positionSeconds;
  bool get paused;
  bool get ended;

  double get playbackRate;
  List<String> get qualities;
  String get quality;
  bool get muted;
  double get volume;
  bool get overlayVisible;
  bool get isInPipMode;

  /// Completes once the playback URL resolved, or once the VOD turned out to
  /// be refused (then [status] is [VodPlaybackStatus.problem]: show it, do not
  /// fall back). Throws only when no playlist can be had at all.
  Future<void> get ready;

  /// Called when this engine cannot play at all (switch to the web player).
  void Function()? onFatalError;

  void play();
  void pause();
  void togglePlay();
  void seekTo(Duration target);
  void seekBy(Duration delta);
  void setPlaybackRate(double rate);
  void setQuality(String quality);
  void toggleMute();
  void setVolume(double volume);
  void handleVideoTap();
  void showOverlay();
  void requestPictureInPicture();
  void onPipEntered();
  void onPipExited();

  /// Current position for a resume save (asks the native player when it can).
  Future<Duration?> currentPositionForSave();

  void dispose();
}
