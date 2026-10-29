import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:mobx/mobx.dart';
import 'package:onset/apis/base_api_client.dart';
import 'package:onset/apis/twitch_clip_service.dart';
import 'package:onset/apis/twitch_vod_service.dart';
import 'package:onset/models/clip.dart';
import 'package:onset/screens/channel/video/quality_selection.dart';
import 'package:onset/screens/clips/clip_media_backend.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/vod/vod_player_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_pip_mode/simple_pip.dart';

part 'clip_player_store.g.dart';

/// SharedPreferences key of the clip loop toggle.
const kClipLoopKey = 'clip_loop';

class ClipPlayerStore = ClipPlayerStoreBase with _$ClipPlayerStore;

/// Plays a clip's MP4 renditions on a [ClipMediaBackend] (media_kit), behind
/// the same [VodPlayerController] contract as the VOD players so the VOD
/// overlay, seek bar and settings sheet drive it unchanged.
abstract class ClipPlayerStoreBase
    with Store
    implements VodPlayerController, LoopingPlayer, VideoSurfacePlayer {
  ClipPlayerStoreBase({
    required this.slug,
    required this.clipService,
    required this.settingsStore,
    Duration? knownLength,
    ClipMediaBackend? backend,
    bool focused = true,
    @visibleForTesting Duration overlayHideDelay = const Duration(seconds: 5),
  }) : backend = backend ?? MediaKitClipBackend(),
       _knownLength = knownLength,
       _overlayHideDelay = overlayHideDelay {
    // Before anything reads it: a player preloaded behind the one playing
    // (the clips feed) must neither start nor touch auto-PiP.
    _focused = focused;
    _subscriptions = [
      this.backend.playing.listen(_onPlaying),
      this.backend.position.listen(_onPosition),
      this.backend.duration.listen(_onDuration),
      this.backend.buffer.listen(_onBuffer),
      this.backend.buffering.listen(_onBuffering),
      this.backend.completed.listen(_onCompleted),
      this.backend.error.listen(_onError),
    ];
    ready = _start();
    _scheduleOverlayHide();
    if (Platform.isAndroid) {
      _disposeAutoPip = autorun((_) async {
        // Another player on top owns auto-PiP.
        if (!_focused) return;
        final available = !paused && await SimplePip.isAutoPipAvailable;
        // Focus may have gone while the plugin answered (the feed covered
        // by a page turns auto-PiP off itself): never arm it after that.
        if (_disposed || !_focused) return;
        if (available) {
          pip.setAutoPipMode();
        } else {
          pip.setAutoPipMode(autoEnter: false);
        }
      });
    }
  }

  final String slug;
  final TwitchClipService clipService;
  final SettingsStore settingsStore;
  final ClipMediaBackend backend;
  final Duration? _knownLength;
  final Duration _overlayHideDelay;

  /// Android picture-in-picture controller.
  final pip = SimplePip();
  ReactionDisposer? _disposeAutoPip;

  late final List<StreamSubscription<Object?>> _subscriptions;
  ClipPlayback? _playback;
  Timer? _overlayTimer;
  var _disposed = false;

  /// One fresh token and reopen per store; the next error is fatal.
  var _recovered = false;
  var _failedOnce = false;

  /// mpv reports one failure as a burst of errors (one per log line), and
  /// the old file may still report a few after the reopen: errors before
  /// this instant belong to the failure being recovered.
  DateTime? _ignoreErrorsUntil;

  /// Between the first error and the reopen with a fresh token.
  var _reopening = false;

  /// Last play state given to the PiP window, to tell it only of changes.
  bool? _pipPlaying;

  @override
  late final Future<void> ready;

  @override
  void Function()? onFatalError;

  @readonly
  var _status = VodPlaybackStatus.loading;

  @readonly
  VodPlaybackProblem? _problem;

  @readonly
  var _position = Duration.zero;

  @readonly
  Duration? _reportedDuration;

  @readonly
  var _buffered = Duration.zero;

  @readonly
  var _playbackRate = 1.0;

  @readonly
  var _muted = false;

  @readonly
  var _volume = 1.0;

  @readonly
  var _overlayVisible = true;

  @readonly
  var _isInPipMode = false;

  @readonly
  var _looping = false;

  @readonly
  List<String> _qualities = const [];

  @readonly
  var _quality = '';

  @observable
  var _focused = true;

  @override
  @computed
  Duration get duration => _reportedDuration ?? _knownLength ?? Duration.zero;

  @override
  @computed
  int get positionSeconds => _position.inSeconds;

  @override
  bool get paused =>
      _status != VodPlaybackStatus.playing &&
      _status != VodPlaybackStatus.buffering;

  @override
  bool get ended => _status == VodPlaybackStatus.ended;

  @override
  @action
  void setFocused(bool focused) => _focused = focused;

  // --- Loading --------------------------------------------------------------

  Future<void> _start() async {
    final prefs = await SharedPreferences.getInstance();
    final looping = prefs.getBool(kClipLoopKey) ?? false;
    runInAction(() => _looping = looping);
    final ClipPlayback playback;
    try {
      playback = await clipService.getClipPlayback(slug);
    } on ClipForbiddenException catch (e) {
      _setProblem(
        e.reason?.toLowerCase().contains('geo') == true
            ? VodPlaybackProblem.geoBlocked
            : VodPlaybackProblem.unknown,
      );
      return;
    } on NotFoundException {
      _setProblem(VodPlaybackProblem.notFound);
      return;
    } catch (e) {
      runInAction(() => _status = VodPlaybackStatus.failed);
      rethrow;
    }
    if (_disposed) return;
    _playback = playback;
    final labels = [for (final r in playback.renditions) r.label];
    final quality =
        pickInitialQuality(
          available: labels,
          defaultToHighest: settingsStore.defaultToHighestQuality,
          lastQuality: prefs.getString('last_stream_quality'),
        ) ??
        labels.first;
    runInAction(() {
      _qualities = labels;
      _quality = quality;
    });
    // The viewer may have toggled loop while the token was coming.
    await backend.setLooping(_looping);
    await _open(Duration.zero);
  }

  @action
  void _setProblem(VodPlaybackProblem problem) {
    _problem = problem;
    _status = VodPlaybackStatus.problem;
  }

  Future<void> _open(Duration start, {bool? play}) async {
    final playback = _playback;
    if (_disposed || playback == null) return;
    final rendition = playback.renditions.firstWhere(
      (r) => r.label == _quality,
      orElse: () => playback.renditions.first,
    );
    runInAction(() => _status = VodPlaybackStatus.loading);
    // Never log this URL: it carries the access token.
    await backend.open(
      playback.signedUrl(rendition),
      start: start,
      play: play ?? _focused,
    );
  }

  // --- Backend events -------------------------------------------------------

  @action
  void _onPlaying(bool playing) {
    if (_status == VodPlaybackStatus.problem ||
        _status == VodPlaybackStatus.failed) {
      return;
    }
    if (playing) {
      // The reopened file plays: errors count again.
      if (!_reopening) _ignoreErrorsUntil = null;
      _status = VodPlaybackStatus.playing;
      _scheduleOverlayHide();
      // A load started before another player took focus must not be heard.
      if (!_focused) unawaited(backend.pause());
    } else if (_status != VodPlaybackStatus.ended) {
      _status = VodPlaybackStatus.paused;
      _overlayTimer?.cancel();
      _overlayVisible = true;
    }
    _syncPip();
  }

  /// Keeps the PiP play/pause button in step.
  void _syncPip() {
    if (!Platform.isAndroid || _disposed || _pipPlaying == !paused) return;
    _pipPlaying = !paused;
    pip.setIsPlaying(!paused);
  }

  @action
  void _onPosition(Duration position) => _position = position;

  @action
  void _onDuration(Duration duration) {
    if (duration > Duration.zero) _reportedDuration = duration;
  }

  @action
  void _onBuffer(Duration buffer) => _buffered = buffer;

  @action
  void _onBuffering(bool buffering) {
    if (buffering && _status == VodPlaybackStatus.playing) {
      _status = VodPlaybackStatus.buffering;
    } else if (!buffering && _status == VodPlaybackStatus.buffering) {
      _status = VodPlaybackStatus.playing;
    }
  }

  @action
  void _onCompleted(bool completed) {
    if (!completed || _looping) return;
    _status = VodPlaybackStatus.ended;
    _overlayTimer?.cancel();
    _overlayVisible = true;
    _syncPip();
  }

  void _onError(String error) {
    if (_disposed || _failedOnce) return;
    // Until the reopen is sent (then for a short grace), the rest of the
    // burst is the same failure.
    final ignoreUntil = _ignoreErrorsUntil;
    if (_reopening ||
        (ignoreUntil != null && clock.now().isBefore(ignoreUntil))) {
      return;
    }
    // Never the message itself: it may quote the signed URL.
    debugPrint('ClipPlayerStore playback error');
    if (_recovered) {
      _fail();
      return;
    }
    _recovered = true;
    _reopening = true;
    unawaited(_recover());
  }

  /// Expired or rejected token: a fresh one, reopened where playback was,
  /// playing only if it was.
  Future<void> _recover() async {
    final at = _position;
    final play = _focused && !paused;
    runInAction(() => _status = VodPlaybackStatus.loading);
    try {
      final playback = await clipService.getClipPlayback(slug);
      if (_disposed || _failedOnce) return;
      _playback = playback;
      _ignoreErrorsUntil = clock.now().add(const Duration(seconds: 2));
      _reopening = false;
      await _open(at, play: play);
    } catch (_) {
      _reopening = false;
      _fail();
    }
  }

  void _fail() {
    if (_failedOnce || _disposed) return;
    _failedOnce = true;
    runInAction(() => _status = VodPlaybackStatus.failed);
    _syncPip();
    onFatalError?.call();
  }

  // --- Controls -------------------------------------------------------------

  @override
  @action
  void play() {
    // Asked for by the viewer: this player takes focus back.
    _focused = true;
    if (ended) {
      _status = VodPlaybackStatus.paused;
      seekTo(Duration.zero);
    }
    unawaited(backend.play());
  }

  @override
  void pause() => unawaited(backend.pause());

  @override
  void togglePlay() => paused ? play() : pause();

  @override
  @action
  void seekTo(Duration target) {
    var clamped = target < Duration.zero ? Duration.zero : target;
    if (duration > Duration.zero && clamped > duration) clamped = duration;
    _position = clamped;
    if (_status == VodPlaybackStatus.ended &&
        (duration == Duration.zero || clamped < duration)) {
      _status = VodPlaybackStatus.paused;
    }
    unawaited(backend.seek(clamped));
    showOverlay();
  }

  @override
  void seekBy(Duration delta) => seekTo(_position + delta);

  @override
  @action
  void setPlaybackRate(double rate) {
    if (!kVodPlaybackRates.contains(rate)) return;
    _playbackRate = rate;
    unawaited(backend.setRate(rate));
  }

  @override
  @action
  void setQuality(String quality) {
    if (!_qualities.contains(quality) || quality == _quality) return;
    _quality = quality;
    // The reopen with a fresh token applies it.
    if (_reopening) return;
    // Keeps playing only if it was playing.
    unawaited(_open(_position, play: _focused && !paused));
  }

  /// Plays the clip over and over (remembered across clips).
  @override
  @action
  void toggleLoop() {
    _looping = !_looping;
    final looping = _looping;
    unawaited(backend.setLooping(looping));
    unawaited(
      SharedPreferences.getInstance().then(
        (prefs) => prefs.setBool(kClipLoopKey, looping),
      ),
    );
  }

  @override
  @action
  void toggleMute() {
    _muted = !_muted;
    unawaited(backend.setVolume(_muted ? 0 : _volume));
  }

  @override
  @action
  void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
    _muted = false;
    unawaited(backend.setVolume(_volume));
  }

  /// The video surface (letterboxed, or cropped with [fill]).
  @override
  Widget buildVideo({required bool fill}) => backend.buildVideo(fill: fill);

  // --- Overlay & PiP ---------------------------------------------------------

  @override
  @action
  void handleVideoTap() {
    _overlayTimer?.cancel();
    if (_overlayVisible && !paused) {
      _overlayVisible = false;
    } else {
      showOverlay();
    }
  }

  @override
  @action
  void showOverlay() {
    _overlayVisible = true;
    _scheduleOverlayHide();
  }

  void _scheduleOverlayHide() {
    _overlayTimer?.cancel();
    _overlayTimer = Timer(_overlayHideDelay, () {
      if (!_disposed && !paused) runInAction(() => _overlayVisible = false);
    });
  }

  @override
  void requestPictureInPicture() {
    if (Platform.isAndroid) pip.enterPipMode(autoEnter: true);
  }

  @override
  @action
  void onPipEntered() => _isInPipMode = true;

  @override
  @action
  void onPipExited() => _isInPipMode = false;

  @override
  Future<Duration?> currentPositionForSave() async => _position;

  @override
  void dispose() {
    _disposed = true;
    _overlayTimer?.cancel();
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _disposeAutoPip?.call();
    // A clip replaced by another one (More clips) has already lost focus:
    // auto-PiP now belongs to the new one.
    if (Platform.isAndroid && _focused) pip.setAutoPipMode(autoEnter: false);
    unawaited(backend.dispose());
  }
}
