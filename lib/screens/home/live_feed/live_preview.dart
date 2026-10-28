import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:frosty/models/hls_variant.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// The decoder of a live preview, so the preview logic is testable without
/// libmpv.
abstract class LivePreviewBackend {
  /// Starts [url], muted.
  Future<void> open(String url);

  /// 0 (muted) to 1.
  Future<void> setVolume(double volume);

  /// True once the first frame is on screen (the thumbnail can go).
  ValueListenable<bool> get showing;

  /// The video, letterboxed (never stretched).
  Widget buildVideo();

  Future<void> dispose();
}

/// A preview on media_kit (libmpv): a player of its own, started muted,
/// with a small buffer and none of the live player's low-latency tuning.
class MediaKitPreviewBackend implements LivePreviewBackend {
  MediaKitPreviewBackend()
    : _player = Player(
        configuration: const PlayerConfiguration(
          muted: true,
          bufferSize: 4 * 1024 * 1024,
          title: 'ONSET preview',
        ),
      ) {
    _video = VideoController(_player);
  }

  final Player _player;
  late final VideoController _video;
  final _showing = ValueNotifier(false);

  @override
  ValueListenable<bool> get showing => _showing;

  @override
  Future<void> open(String url) async {
    await _player.setVolume(0);
    await _player.open(Media(url));
    unawaited(
      _video.waitUntilFirstFrameRendered.then((_) => _showing.value = true),
    );
  }

  @override
  Future<void> setVolume(double volume) =>
      _player.setVolume((volume * 100).clamp(0, 100).toDouble());

  @override
  Widget buildVideo() => Video(
    controller: _video,
    controls: NoVideoControls,
    // Letterboxed: a stream is never stretched.
    fill: const Color(0x00000000),
  );

  @override
  Future<void> dispose() async {
    _showing.value = false;
    await _player.dispose();
    _showing.dispose();
  }
}

/// The rendition a preview plays: the smallest video at least
/// [targetHeight] tall, else the tallest below it (never audio only).
/// Null when the playlist has no video.
HlsVariant? pickPreviewVariant(
  List<HlsVariant> variants, {
  int targetHeight = 480,
}) {
  int? heightOf(HlsVariant variant) =>
      int.tryParse(RegExp(r'^(\d+)p').firstMatch(variant.name)?.group(1) ?? '');
  HlsVariant? above;
  HlsVariant? below;
  for (final variant in variants) {
    final height = heightOf(variant);
    if (height == null) continue;
    if (height >= targetHeight) {
      if (above == null || height < heightOf(above)!) above = variant;
    } else if (below == null || height > heightOf(below)!) {
      below = variant;
    }
  }
  return above ?? below;
}

/// Where a channel's preview plays from (its usher rendition URL).
typedef PreviewUrlResolver = Future<String> Function(String login);

/// Plays the preview of one live channel at a time, muted.
///
/// - One decoder, ever: a new preview starts only once the previous one is
///   disposed.
/// - A preview starts after [settle], so a fast swipe through the feed
///   never starts a decoder for each channel it passes.
/// - [setActive] false (off screen, covered, in the background, the mini
///   player playing, autoplay off) stops it at once.
/// - Every preview starts muted; [toggleMute] only changes the current one.
class LivePreviewController extends ChangeNotifier {
  LivePreviewController({
    required this.resolveUrl,
    LivePreviewBackend Function()? createBackend,
    this.settle = const Duration(milliseconds: 350),
  }) : _createBackend = createBackend ?? MediaKitPreviewBackend.new;

  final PreviewUrlResolver resolveUrl;
  final LivePreviewBackend Function() _createBackend;
  final Duration settle;

  String? _target;
  var _active = false;
  Timer? _timer;

  /// Bumped by every change: a start that finishes late is dropped.
  var _generation = 0;

  LivePreviewBackend? _backend;
  String? _playing;

  /// The previous decoder, while it is being let go.
  Future<void> _released = Future.value();
  var _disposed = false;

  var _muted = true;
  var _failed = false;

  /// The decoder playing [playingLogin], if any.
  LivePreviewBackend? get backend => _backend;

  /// The channel whose preview plays (or is starting).
  String? get playingLogin => _playing;

  bool get muted => _muted;

  /// The current channel's preview could not start (it shows its picture).
  bool get failed => _failed;

  /// Plays [login]'s preview (null: none).
  void show(String? login) {
    if (login == _target) return;
    _target = login;
    _restart();
  }

  void setActive(bool active) {
    if (active == _active) return;
    _active = active;
    _restart();
  }

  /// Unmutes or mutes the current preview (a tap on its sound button).
  Future<void> toggleMute() async {
    final backend = _backend;
    if (backend == null) return;
    _muted = !_muted;
    notifyListeners();
    try {
      await backend.setVolume(_muted ? 0 : 1);
    } catch (e) {
      debugPrint('Preview volume failed: ${e.runtimeType}');
    }
  }

  /// Lets the decoder go now (a channel opens: its player must not share
  /// the device with a preview).
  void stop() {
    _active = false;
    _restart();
  }

  void _restart() {
    _timer?.cancel();
    final generation = ++_generation;
    _release();
    _failed = false;
    _muted = true;
    if (!_disposed) notifyListeners();
    final login = _target;
    if (!_active || login == null || _disposed) return;
    _timer = Timer(settle, () => unawaited(_start(login, generation)));
  }

  void _release() {
    final backend = _backend;
    _backend = null;
    _playing = null;
    if (backend == null) return;
    final previous = _released;
    _released = previous.then((_) async {
      try {
        await backend.dispose();
      } catch (e) {
        debugPrint('Preview release failed: ${e.runtimeType}');
      }
    });
  }

  Future<void> _start(String login, int generation) async {
    // The decoder before must be gone first: one at a time.
    await _released;
    if (generation != _generation || _disposed) return;
    String url;
    try {
      url = await resolveUrl(login);
    } catch (e) {
      debugPrint('Preview unavailable: ${e.runtimeType}');
      if (generation == _generation && !_disposed) {
        _failed = true;
        notifyListeners();
      }
      return;
    }
    if (generation != _generation || _disposed) return;
    final backend = _createBackend();
    _backend = backend;
    _playing = login;
    notifyListeners();
    try {
      await backend.open(url);
    } catch (e) {
      debugPrint('Preview failed to play: ${e.runtimeType}');
      if (generation == _generation && !_disposed) {
        _release();
        _failed = true;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _generation++;
    _release();
    super.dispose();
  }
}
