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
  }) : _knownLength = knownLength,
       _recovery = recoveryPolicy ?? IvsRecoveryPolicy(),
       _position = startAt,
       _startAt = startAt {
    _textureReady = _createTexture().then(
      (_) => true,
      onError: (Object e) {
        debugPrint('IvsVodStore texture creation failed: $e');
        _fail();
        return false;
      },
    );
    ready = _resolveUrl();
    final startEpoch = _epoch;
    unawaited(
      ready
          .then((_) async {
            final url = _url;
            if (url == null || startEpoch != _epoch) return;
            try {
              await _loadSource(url, _startAt, startEpoch);
            } catch (e) {
              debugPrint('IvsVodStore initial load failed: $e');
              _fail();
            }
          })
          .catchError((Object e) {
            if (_disposed) return;
            if (e is VodForbiddenException) {
              runInAction(() {
                _status = VodPlaybackStatus.problem;
                _problem = switch (e.reason) {
                  'geoblocked' => VodPlaybackProblem.geoBlocked,
                  _ => VodPlaybackProblem.subscriberOnly,
                };
              });
            } else {
              runInAction(() => _status = VodPlaybackStatus.failed);
            }
          }),
    );
    _scheduleOverlayHide();
    if (Platform.isAndroid) {
      _disposeAutoPip = autorun((_) async {
        final playing = _status == VodPlaybackStatus.playing;
        if (playing && await SimplePip.isAutoPipAvailable) {
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
  final Duration _startAt;

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

  @override
  @computed
  Duration get duration => _nativeDuration ?? _knownLength ?? Duration.zero;

  @override
  @computed
  int get positionSeconds => _position.inSeconds;

  @override
  bool get paused =>
      _status != VodPlaybackStatus.playing &&
      _status != VodPlaybackStatus.buffering;

  // --- Loading -------------------------------------------------------------

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

  Future<void> _loadSource(String url, Duration startAt, int epoch) async {
    if (!await _textureReady) {
      _fail();
      return;
    }
    if (epoch != _epoch) return;
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
        _onState(e['state'] as String?);
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
          if (_seeking && (at - _seekTarget).abs() < _seekTolerance) {
            _endSeek();
          }
          if (!_seeking) _position = at;
        }
      case 'duration':
        final duration = _validDuration(e['ms']);
        if (duration != null) _nativeDuration = duration;
      case 'seeked':
        _endSeek();
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
        if (_recovering && kind != IvsErrorKind.fatal) break;
        _applyRecovery(_recovery.onError(kind));
    }
  }

  void _onState(String? state) {
    switch (state) {
      case 'PLAYING':
        _status = VodPlaybackStatus.playing;
        _ended = false;
      case 'BUFFERING':
        _status = VodPlaybackStatus.buffering;
      case 'ENDED':
        _ended = true;
        _status = VodPlaybackStatus.ended;
        _overlayVisible = true;
      case 'READY' || 'IDLE':
        _status = VodPlaybackStatus.paused;
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

  void _endSeek() {
    _seeking = false;
    _seekTimeout?.cancel();
  }

  // --- Recovery -------------------------------------------------------------

  void _applyRecovery(IvsRecoveryAction action) {
    if (_disposed) return;
    switch (action) {
      case IvsRetry(:final delay) && final retry:
        _recovering = true;
        runInAction(() => _status = VodPlaybackStatus.loading);
        _retryTimer?.cancel();
        final epoch = _epoch;
        _retryTimer = Timer(
          delay,
          () => unawaited(_reload(epoch, freshToken: retry.freshToken)),
        );
      case IvsOffline():
        _recovering = true;
        unawaited(_diagnose(_epoch));
      case IvsFallback():
        _recovering = false;
        _fail();
    }
  }

  Future<void> _reload(int epoch, {bool freshToken = false}) async {
    if (epoch != _epoch) return;
    try {
      final url = await vodService.getVodUsherUrl(
        vodId: vodId,
        forceFreshToken: freshToken,
      );
      if (epoch != _epoch) return;
      _url = url;
      await _loadSource(url, _position, epoch);
      if (epoch == _epoch) _recovering = false;
    } catch (e) {
      if (epoch != _epoch) return;
      _recovering = false;
      if (e is VodForbiddenException) {
        runInAction(() {
          _status = VodPlaybackStatus.problem;
          _problem = VodPlaybackProblem.subscriberOnly;
        });
        return;
      }
      _applyRecovery(
        _recovery.onError(
          isRetryableTokenError(e)
              ? IvsErrorKind.recoverable
              : IvsErrorKind.fatal,
        ),
      );
    }
  }

  /// IVS says the video is unavailable: ask usher why. The web player would
  /// fail the same way, so this ends in a problem state, not a fallback.
  Future<void> _diagnose(int epoch) async {
    final url = _url;
    final problem = url == null
        ? VodPlaybackProblem.unknown
        : await vodService.diagnoseVodPlaylist(url) ??
              VodPlaybackProblem.unknown;
    if (epoch != _epoch) return;
    _recovering = false;
    runInAction(() {
      _status = VodPlaybackStatus.problem;
      _problem = problem;
    });
  }

  void _fail() {
    if (_disposed || _status == VodPlaybackStatus.failed) return;
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
    if (_ended) {
      _ended = false;
      _position = Duration.zero;
      unawaited(_invoke('seekTo', {'ms': 0}));
    }
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
    _seeking = true;
    _seekTarget = clamped;
    _seekTimeout?.cancel();
    _seekTimeout = Timer(const Duration(seconds: 3), _endSeek);
    _ended = false;
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
    _overlayTimer = Timer(const Duration(seconds: 5), () {
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
