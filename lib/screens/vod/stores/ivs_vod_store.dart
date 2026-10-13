import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:frosty/apis/twitch_vod_service.dart';
import 'package:frosty/screens/channel/video/ivs_player_config.dart';
import 'package:frosty/screens/channel/video/ivs_recovery.dart';
import 'package:frosty/screens/channel/video/quality_selection.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/screens/vod/vod_player_controller.dart';
import 'package:mobx/mobx.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_pip_mode/simple_pip.dart';

part 'ivs_vod_store.g.dart';

class IvsVodStore = IvsVodStoreBase with _$IvsVodStore;

/// Drives a past broadcast on the native Amazon IVS texture player (VOD mode:
/// seek, playback rate, progress events) over the same MethodChannels as the
/// live player. The live [IvsVideoStore] is deliberately left untouched.
abstract class IvsVodStoreBase with Store implements VodPlayerController {
  IvsVodStoreBase({
    required this.vodId,
    required this.vodService,
    required this.settingsStore,
    Duration startAt = Duration.zero,
    Duration? knownLength,
    @visibleForTesting IvsRecoveryPolicy? recoveryPolicy,
    @visibleForTesting Duration overlayHideDelay = const Duration(seconds: 5),
    @visibleForTesting Duration seekTimeout = const Duration(seconds: 3),
  }) : _knownLength = knownLength,
       _recovery = recoveryPolicy ?? IvsRecoveryPolicy(),
       _overlayHideDelay = overlayHideDelay,
       _seekTimeoutDelay = seekTimeout,
       _position = startAt,
       _wantedStart = startAt {
    _textureReady = _createTexture().then(
      (_) => true,
      onError: (Object e) {
        debugPrint('IvsVodStore texture creation failed: $e');
        _fail();
        return false;
      },
    );
    ready = _start();
    _scheduleOverlayHide();
    if (Platform.isAndroid) {
      _disposeAutoPip = autorun((_) async {
        // Another player on top owns auto-PiP.
        if (!_focused) return;
        // Buffering counts as playing: a rebuffer must not flip auto-PiP.
        final playing = !paused;
        final available = playing && await SimplePip.isAutoPipAvailable;
        if (_disposed) return;
        if (available) {
          pip.setAutoPipMode();
        } else {
          pip.setAutoPipMode(autoEnter: false);
        }
      });
    }
  }

  final String vodId;
  final TwitchVodService vodService;
  final SettingsStore settingsStore;

  static const _textureManager = MethodChannel('frosty/ivs-texture-manager');

  final Duration? _knownLength;
  final IvsRecoveryPolicy _recovery;
  final Duration _overlayHideDelay;
  final Duration _seekTimeoutDelay;

  /// Android picture-in-picture controller.
  final pip = SimplePip();
  ReactionDisposer? _disposeAutoPip;

  @override
  late final Future<void> ready;

  @override
  void Function()? onFatalError;

  late final Future<bool> _textureReady;
  MethodChannel? _channel;
  String? _url;
  Timer? _retryTimer;
  Timer? _overlayTimer;
  var _disposed = false;
  var _recovering = false;

  /// Bumped by dispose so stale async work never touches state.
  var _epoch = 0;

  /// True until the native start seek of the current source is confirmed:
  /// before the URL resolves, during a reload, and between a `load` and its
  /// first READY, IVS reports 0 or a stale position, which must not replace
  /// the resume point.
  var _awaitingStart = true;

  /// Where the next `load` starts: the requested start, then the playback
  /// position when a reload is scheduled, then any seek made meanwhile.
  Duration _wantedStart;

  /// Backup for a lost start confirmation, armed on READY.
  Timer? _startTimeout;

  /// The current source's `load` was sent. Before that (URL pending, retry
  /// delay, diagnose) Kotlin passes seeks straight to the player, so their
  /// confirmations are not the start seek.
  var _loadSent = false;

  /// Bumped by every `load`, so a READY timer of an older source is inert.
  var _loadGeneration = 0;

  /// True between a seek request and the native confirmation, so late
  /// progress ticks do not jump the seek bar back.
  var _seeking = false;
  Duration _seekTarget = Duration.zero;
  Timer? _seekTimeout;

  @readonly
  int? _textureId;

  @readonly
  var _status = VodPlaybackStatus.loading;

  @readonly
  VodPlaybackProblem? _problem;

  @readonly
  Duration _position;

  @readonly
  Duration? _nativeDuration;

  @readonly
  var _buffered = Duration.zero;

  @readonly
  var _ended = false;

  @readonly
  var _playbackRate = 1.0;

  @readonly
  var _qualities = <String>[];

  @readonly
  var _quality = 'Auto';

  @readonly
  var _muted = false;

  @readonly
  var _volume = 1.0;

  @readonly
  var _overlayVisible = true;

  @readonly
  var _isInPipMode = false;

  @observable
  var _focused = true;

  @override
  @action
  void setFocused(bool focused) => _focused = focused;

  @override
  @computed
  Duration get duration => _nativeDuration ?? _knownLength ?? Duration.zero;

  @override
  @computed
  int get positionSeconds => _position.inSeconds;

  /// Failed (fallback requested) and problem (usher refused) are final.
  bool get _terminal =>
      _status == VodPlaybackStatus.failed ||
      _status == VodPlaybackStatus.problem;

  @override
  bool get paused =>
      _status != VodPlaybackStatus.playing &&
      _status != VodPlaybackStatus.buffering;

  // --- Loading -------------------------------------------------------------

  /// Resolves the playlist, then starts loading it in the background.
  /// Completes normally when the VOD is forbidden (a problem state, not a
  /// reason to fall back to the web player); rejects only when no playlist
  /// can be had.
  Future<void> _start() async {
    final epoch = _epoch;
    try {
      await _resolveUrl();
    } on VodForbiddenException catch (e) {
      if (!_disposed && !_terminal) _setProblem(_forbiddenProblem(e));
      return;
    } catch (e) {
      if (!_disposed && !_terminal) {
        runInAction(() => _status = VodPlaybackStatus.failed);
      }
      rethrow;
    }
    final url = _url;
    if (url == null || epoch != _epoch) return;
    unawaited(
      _loadSource(url, epoch).catchError((Object e) {
        debugPrint('IvsVodStore initial load failed: $e');
        _fail();
      }),
    );
  }

  static VodPlaybackProblem _forbiddenProblem(VodForbiddenException e) =>
      switch (e.reason) {
        'geoblocked' => VodPlaybackProblem.geoBlocked,
        _ => VodPlaybackProblem.subscriberOnly,
      };

  void _setProblem(VodPlaybackProblem problem) {
    _retryTimer?.cancel();
    _recovering = false;
    runInAction(() {
      _status = VodPlaybackStatus.problem;
      _problem = problem;
      _overlayVisible = true;
    });
  }

  Future<void> _resolveUrl() async {
    for (var attempt = 0; ; attempt++) {
      try {
        _url = await vodService.getVodUsherUrl(vodId: vodId);
        return;
      } catch (e) {
        final delay = _recovery.tokenRetryDelay(attempt);
        if (_disposed || delay == null || !isRetryableTokenError(e)) rethrow;
        await Future<void>.delayed(delay);
        if (_disposed) rethrow;
      }
    }
  }

  Future<void> _createTexture() async {
    if (_disposed) return;
    final id = await _textureManager.invokeMethod<int>('create', {
      'config': IvsPlayerConfig.vodCreateArgs,
    });
    if (id == null) return;
    if (_disposed) {
      // Closed while the native player was being created: release it.
      await _textureManager.invokeMethod('dispose', {'textureId': id});
      return;
    }
    final channel = MethodChannel('frosty/ivs-texture/$id');
    _channel = channel;
    channel.setMethodCallHandler((call) async {
      if (call.method == 'onEvent') {
        _onEvent(Map<String, dynamic>.from(call.arguments as Map));
      }
    });
    runInAction(() => _textureId = id);
  }

  Future<void> _loadSource(String url, int epoch) async {
    if (!await _textureReady) {
      _fail();
      return;
    }
    if (epoch != _epoch) return;
    final startAt = _wantedStart;
    _startTimeout?.cancel();
    _loadGeneration++;
    _loadSent = true;
    runInAction(() {
      _awaitingStart = true;
      _position = startAt;
    });
    await _channel?.invokeMethod('load', {
      'url': url,
      'startMs': startAt.inMilliseconds,
    });
  }

  // --- Native events -------------------------------------------------------

  @action
  void _onEvent(Map<String, dynamic> e) {
    switch (e['type']) {
      case 'state':
        if (!_terminal) _onState(e['state'] as String?);
      case 'progress':
        final duration = _validDuration(e['durationMs']);
        if (duration != null) _nativeDuration = duration;
        final buffered = (e['bufferedMs'] as num?)?.toInt();
        if (buffered != null && buffered >= 0) {
          _buffered = Duration(milliseconds: buffered);
        }
        final position = (e['positionMs'] as num?)?.toInt();
        if (position != null && position >= 0) {
          final at = Duration(milliseconds: position);
          // A tick at the target means the seek is done even if the native
          // confirmation got lost.
          if (_seeking && _nearSeekTarget(at)) _endSeek();
          if (!_seeking && !_awaitingStart) _position = at;
        }
      case 'duration':
        final duration = _validDuration(e['ms']);
        if (duration != null) _nativeDuration = duration;
      case 'seeked':
        final ms = (e['ms'] as num?)?.toInt();
        final at = ms == null ? null : Duration(milliseconds: ms);
        if (_loadSent &&
            (at == null || (at - _wantedStart).abs() < _seekTolerance)) {
          // The native start seek of the current source.
          _awaitingStart = false;
          _startTimeout?.cancel();
        }
        if (at == null || _nearSeekTarget(at)) _endSeek();
      case 'qualities':
        final list = (e['list'] as List).map((q) => q.toString()).toList();
        _qualities = ['Auto', ...list];
        unawaited(_restoreQuality(list));
        _resendPlaybackSettings();
      case 'quality':
        final name = e['name'] as String?;
        if (name != null && _qualities.contains(name)) _quality = name;
      case 'error':
        final kind = classifyIvsError(
          errorType: e['errorType'] as String?,
          code: (e['code'] as num?)?.toInt(),
          source: e['source'] as String?,
        );
        debugPrint('IVS vod error: ${e['errorType']} ${e['code']} -> $kind');
        if (_terminal) break;
        if (_recovering && kind != IvsErrorKind.fatal) break;
        _applyRecovery(_recovery.onError(kind));
    }
  }

  void _onState(String? state) {
    switch (state) {
      case 'PLAYING':
        // Native auto-play after a (re)load while another player has focus.
        if (!_focused) unawaited(_invoke('pause'));
        final resumed = paused;
        _status = VodPlaybackStatus.playing;
        _ended = false;
        // Controls shown while paused hide again once playback resumes.
        if (resumed && _overlayVisible) _scheduleOverlayHide();
      case 'BUFFERING':
        _status = VodPlaybackStatus.buffering;
      case 'ENDED':
        _ended = true;
        _status = VodPlaybackStatus.ended;
        _overlayVisible = true;
      case 'READY' || 'IDLE':
        _status = VodPlaybackStatus.paused;
        if (state == 'READY' && _awaitingStart) {
          // Kotlin seeks to the start on READY; if that confirmation gets
          // lost, trust the ticks again after a while.
          _startTimeout?.cancel();
          final generation = _loadGeneration;
          _startTimeout = Timer(_seekTimeoutDelay, () {
            if (generation == _loadGeneration && _loadSent && !_recovering) {
              _awaitingStart = false;
            }
          });
        }
    }
    if (Platform.isAndroid) pip.setIsPlaying(!paused);
  }

  /// IVS reports -1 or a huge value while the duration is unknown (e.g. a VOD
  /// still being recorded); keep the known length then.
  static Duration? _validDuration(Object? raw) {
    if (raw is! num) return null;
    final ms = raw.toInt();
    if (ms <= 0 || ms >= (1 << 53)) return null;
    return Duration(milliseconds: ms);
  }

  static const _seekTolerance = Duration(milliseconds: 1500);

  bool _nearSeekTarget(Duration at) =>
      (at - _seekTarget).abs() < _seekTolerance;

  void _endSeek() {
    _seeking = false;
    _seekTimeout?.cancel();
  }

  // --- Recovery -------------------------------------------------------------

  void _applyRecovery(IvsRecoveryAction action) {
    if (_disposed || _terminal) return;
    switch (action) {
      case IvsRetry(:final delay) && final retry:
        _recovering = true;
        runInAction(() => _status = VodPlaybackStatus.loading);
        _retryTimer?.cancel();
        final epoch = _epoch;
        _holdStartForReload();
        _retryTimer = Timer(
          delay,
          () => unawaited(_reload(epoch, freshToken: retry.freshToken)),
        );
      case IvsOffline():
        _recovering = true;
        _holdStartForReload();
        unawaited(_diagnose(_epoch));
      case IvsFallback():
        _recovering = false;
        _fail();
    }
  }

  /// The broken source's ticks are not playback: keep the position to
  /// reload at (a seek made meanwhile updates it) until the next source
  /// confirms its start.
  void _holdStartForReload() {
    _startTimeout?.cancel();
    _loadSent = false;
    if (_awaitingStart) return;
    _wantedStart = _seeking ? _seekTarget : _position;
    _awaitingStart = true;
  }

  Future<void> _reload(int epoch, {bool freshToken = false}) async {
    if (epoch != _epoch) return;
    final String url;
    try {
      url = await vodService.getVodUsherUrl(
        vodId: vodId,
        forceFreshToken: freshToken,
      );
    } on VodForbiddenException catch (e) {
      if (epoch == _epoch) _setProblem(_forbiddenProblem(e));
      return;
    } catch (e) {
      if (epoch != _epoch) return;
      _recovering = false;
      if (isRetryableTokenError(e)) {
        _applyRecovery(_recovery.onError(IvsErrorKind.recoverable));
      } else {
        // No token at all (e.g. the VOD was deleted): usher knows why; the
        // web player would not do better.
        _recovering = true;
        unawaited(_diagnose(epoch));
      }
      return;
    }
    if (epoch != _epoch) return;
    _url = url;
    try {
      await _loadSource(url, epoch);
    } catch (e) {
      debugPrint('IvsVodStore reload failed: $e');
      if (epoch == _epoch) {
        _recovering = false;
        _fail();
      }
      return;
    }
    if (epoch == _epoch) _recovering = false;
  }

  /// IVS says the video is unavailable: ask usher why. A refusal (sub-only,
  /// geoblock, gone) is a problem state, since the web player would fail the
  /// same way; a playable playlist or a rejected token is retried.
  Future<void> _diagnose(int epoch) async {
    final url = _url;
    VodPlaybackProblem? problem;
    try {
      problem = url == null
          ? VodPlaybackProblem.unknown
          : await vodService.diagnoseVodPlaylist(url);
    } catch (_) {
      problem = VodPlaybackProblem.unknown;
    }
    if (epoch != _epoch) return;
    _recovering = false;
    switch (problem) {
      case null:
        _applyRecovery(_recovery.onError(IvsErrorKind.recoverable));
      case VodPlaybackProblem.tokenRejected:
        _applyRecovery(_recovery.onError(IvsErrorKind.refreshToken));
      case final problem:
        _setProblem(problem);
    }
  }

  void _fail() {
    if (_disposed || _terminal) return;
    _retryTimer?.cancel();
    _epoch++;
    _recovering = false;
    runInAction(() => _status = VodPlaybackStatus.failed);
    onFatalError?.call();
  }

  // --- Controls -------------------------------------------------------------

  @override
  @action
  void play() {
    // Asked for by the viewer: this player takes focus back.
    _focused = true;
    if (_ended) seekTo(Duration.zero);
    unawaited(_invoke('play'));
  }

  @override
  void pause() => unawaited(_invoke('pause'));

  @override
  void togglePlay() => paused ? play() : pause();

  @override
  @action
  void seekTo(Duration target) {
    final end = duration - const Duration(seconds: 1);
    var clamped = target < Duration.zero ? Duration.zero : target;
    if (end > Duration.zero && clamped > end) clamped = end;
    _position = clamped;
    if (_awaitingStart) _wantedStart = clamped;
    _seeking = true;
    _seekTarget = clamped;
    _seekTimeout?.cancel();
    _seekTimeout = Timer(_seekTimeoutDelay, _endSeek);
    if (_ended) {
      _ended = false;
      _status = VodPlaybackStatus.paused;
    }
    unawaited(_invoke('seekTo', {'ms': clamped.inMilliseconds}));
    showOverlay();
  }

  @override
  void seekBy(Duration delta) => seekTo(_position + delta);

  @override
  @action
  void setPlaybackRate(double rate) {
    if (!kVodPlaybackRates.contains(rate)) return;
    _playbackRate = rate;
    unawaited(_invoke('setPlaybackRate', {'rate': rate}));
  }

  /// Quality picked during this session; re-applied after reloads.
  String? _sessionQuality;
  var _qualityGeneration = 0;

  late final Future<String?> _savedQuality = SharedPreferences.getInstance()
      .then((prefs) => prefs.getString('last_stream_quality'))
      .catchError((Object _) => null);

  Future<void> _restoreQuality(List<String> available) async {
    final generation = ++_qualityGeneration;
    final saved = await _savedQuality;
    if (_disposed || generation != _qualityGeneration) return;
    final session = _sessionQuality;
    if (session == 'Auto') {
      _applyQuality('Auto');
      return;
    }
    final quality =
        pickInitialQuality(
          available: available,
          defaultToHighest: false,
          lastQuality: session,
        ) ??
        pickInitialQuality(
          available: available,
          defaultToHighest: settingsStore.defaultToHighestQuality,
          lastQuality: saved,
        );
    if (quality != null) _applyQuality(quality);
  }

  @override
  void setQuality(String quality) {
    _qualityGeneration++;
    _sessionQuality = quality;
    _applyQuality(quality);
  }

  @action
  void _applyQuality(String quality) {
    if (!_qualities.contains(quality)) return;
    _quality = quality;
    if (quality == 'Auto') {
      unawaited(_invoke('setAutoQuality'));
    } else {
      unawaited(_invoke('setQuality', {'name': quality}));
    }
  }

  @override
  @action
  void toggleMute() {
    _muted = !_muted;
    unawaited(_invoke('setMuted', {'muted': _muted}));
  }

  @override
  @action
  void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
    unawaited(_invoke('setVolume', {'volume': _volume}));
    if (_muted) {
      _muted = false;
      unawaited(_invoke('setMuted', {'muted': false}));
    }
  }

  /// A reload starts a fresh native source; restore rate and sound.
  void _resendPlaybackSettings() {
    if (_playbackRate != 1.0) {
      unawaited(_invoke('setPlaybackRate', {'rate': _playbackRate}));
    }
    if (_muted || _volume != 1.0) {
      unawaited(_invoke('setMuted', {'muted': _muted}));
      unawaited(_invoke('setVolume', {'volume': _volume}));
    }
  }

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
      // Stays visible while paused or ended so the controls are reachable.
      if (!paused) runInAction(() => _overlayVisible = false);
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
  Future<Duration?> currentPositionForSave() async {
    // Before the start seek, during a reload or a seek, or after a failure,
    // the native position is 0 or stale: the store's position is the truth.
    if (_awaitingStart) return _wantedStart;
    if (_seeking || _terminal || _status == VodPlaybackStatus.loading) {
      return _position;
    }
    try {
      final ms = await _channel?.invokeMethod<int>('getPosition');
      if (ms != null && ms >= 0) return Duration(milliseconds: ms);
    } catch (_) {}
    return _position;
  }

  Future<void> _invoke(String method, [Map<String, Object?>? args]) async {
    try {
      await _channel?.invokeMethod(method, args);
    } catch (e) {
      debugPrint('IvsVodStore $method failed: $e');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    _retryTimer?.cancel();
    _overlayTimer?.cancel();
    _seekTimeout?.cancel();
    _startTimeout?.cancel();
    _disposeAutoPip?.call();
    if (Platform.isAndroid) pip.setAutoPipMode(autoEnter: false);
    final id = _textureId;
    if (id != null) {
      unawaited(_textureManager.invokeMethod('dispose', {'textureId': id}));
      _textureId = null;
    }
    _channel?.setMethodCallHandler(null);
  }
}
