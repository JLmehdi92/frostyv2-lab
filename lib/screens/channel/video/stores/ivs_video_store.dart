import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mobx/mobx.dart';
import 'package:onset/apis/base_api_client.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/apis/twitch_stream_service.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/channel.dart';
import 'package:onset/models/ivs_stats.dart';
import 'package:onset/models/playback_access_token.dart';
import 'package:onset/models/quality_ladder.dart';
import 'package:onset/models/stream.dart';
import 'package:onset/models/stream_push.dart';
import 'package:onset/screens/channel/video/buffer_fallback.dart';
import 'package:onset/screens/channel/video/ivs_player_config.dart';
import 'package:onset/screens/channel/video/ivs_recovery.dart';
import 'package:onset/screens/channel/video/latency_controller.dart';
import 'package:onset/screens/channel/video/latency_stats.dart';
import 'package:onset/screens/channel/video/live_edge_guard.dart';
import 'package:onset/screens/channel/video/live_state_watcher.dart';
import 'package:onset/screens/channel/video/player_controller.dart';
import 'package:onset/screens/channel/video/quality_selection.dart';
import 'package:onset/screens/channel/video/stores/caption_store.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/services/audio_focus.dart';
import 'package:onset/services/background_audio.dart';
import 'package:onset/services/network_metering.dart';
import 'package:onset/services/playback_token_cache.dart';
import 'package:onset/services/realtime/twitch_eventsub_client.dart';
import 'package:onset/services/telemetry.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_pip_mode/simple_pip.dart';

part 'ivs_video_store.g.dart';

class IvsVideoStore = IvsVideoStoreBase with _$IvsVideoStore;

/// Playback lifecycle of the IVS engine, used for the loading spinner, the
/// reconnecting indicator and the fallback decision.
enum IvsPlaybackStatus { loading, playing, reconnecting, offline, failed }

/// Drives the native Amazon IVS player (the video technology Twitch is built
/// on) over a MethodChannel, exposing the shared [PlayerController]
/// surface so the existing overlay/channel can use it unchanged.
abstract class IvsVideoStoreBase
    with Store
    implements PlayerController, StreamInfoStatus, StreamPushTarget {
  final String userLogin;
  final String userId;
  final TwitchApi twitchApi;
  final AuthStore authStore;

  @override
  final SettingsStore settingsStore;

  final TwitchStreamService _streamService;
  final bool _ownsStreamService;

  /// Android picture-in-picture controller.
  final pip = SimplePip();
  ReactionDisposer? _disposeAutoPipReaction;
  ReactionDisposer? _disposeBackgroundAudioReaction;

  /// The media notification that keeps the sound going outside the app.
  final BackgroundAudio _backgroundAudio;

  /// The app's hold on the sound, taken while the stream plays.
  final AudioFocus _audioFocus;
  ReactionDisposer? _disposeAudioFocusReaction;

  /// A call (or a short sound from another app) paused the stream: it
  /// plays again once the sound comes back.
  var _pausedForFocus = false;

  /// The viewer stopped the stream from its notification: it stays hidden
  /// until the stream plays again.
  @observable
  var _audioNotificationStopped = false;

  /// The stream's closed captions: the line on screen, its tracks.
  late final captions = CaptionStore(
    settings: settingsStore,
    invoke: (method, [args]) => _invoke(method, args ?? const {}),
  );

  /// The closed-caption line on screen, when captions are on and the stream
  /// sends them.
  String? get caption => captions.caption;

  static const _textureManager = MethodChannel('onset/ivs-texture-manager');

  /// The Flutter texture this store's IVS stream renders into (null until
  /// created). Owned by the store — not the widget — so the live player can
  /// move between the channel screen and the mini player without reloading.
  @readonly
  int? _textureId;

  /// Per-texture MethodChannel, set by [attachTextureChannel] once the native
  /// texture player exists.
  MethodChannel? _channel;

  /// Called when the IVS player hits a fatal error (or exhausted its retry
  /// budget) so the channel screen can fall back to the WebView engine.
  void Function()? onFatalError;

  final IvsRecoveryPolicy _recovery;

  @readonly
  var _status = IvsPlaybackStatus.loading;

  /// Retries used in the current recovery window (for "Reconnecting n/3").
  @readonly
  var _retryAttempt = 0;

  int get maxRetryAttempts => _recovery.maxAttempts;

  /// Tuning the native player is created with, captured when the stream is
  /// opened (fixed for its lifetime; new settings apply to the next stream).
  final IvsPlayerConfig playerConfig;

  Timer? _retryTimer;
  var _disposed = false;

  /// True while a retry is scheduled or a reload / offline check is running.
  /// Further recoverable errors in that window belong to the same incident
  /// and must not burn the retry budget or start a parallel reload.
  var _recovering = false;

  /// Bumped by [handleRefresh] and [dispose] so async recovery work started
  /// before can tell it is stale and must not touch state anymore.
  var _recoveryEpoch = 0;

  /// The usher URL to hand to the native IVS player (null until resolved).
  @readonly
  String? _url;

  /// Why Twitch refused the stream, set when the player gives up on it for
  /// that reason (the channel says it on falling back); null otherwise.
  @readonly
  StreamRefusalNotice? _refusalNotice;

  /// Whether the last player error was a rejected token (401 or 403); each
  /// new load attempt clears it, so a failure of its own (no network, a
  /// token fetch) is not taken for a refusal.
  var _lastErrorRefused = false;

  /// Completes when the usher URL is resolved, or throws so the channel can
  /// fall back to the WebView engine.
  late final Future<void> ready;

  Timer? _overlayTimer;
  int? _lastLatencySecond;

  @readonly
  List<String> _availableStreamQualities = [];

  @readonly
  int _streamQualityIndex = 0;

  @readonly
  var _paused = false;

  @readonly
  var _overlayVisible = true;

  @readonly
  StreamTwitch? _streamInfo;

  @readonly
  Channel? _offlineChannelInfo;

  @observable
  @override
  var infoUnavailable = false;

  @readonly
  String? _latency;

  /// Last raw latency reported by IVS, in milliseconds.
  @readonly
  int? _latencyMs;

  /// Rolling latency samples (taken only while playing) for the stats panel.
  final latencySampler = LatencySampler();

  /// Bumped whenever [latencySampler] changes so observers of the (plain,
  /// non-observable) sampler rebuild, including after a reset.
  @readonly
  var _samplesVersion = 0;

  /// True only while the native player reports PLAYING (not buffering/idle).
  var _isPlaying = false;

  /// True once the current source played its first frame.
  var _hasPlayed = false;

  /// Whether the video stats panel is shown (native stats are only sent while
  /// it is open).
  @readonly
  var _statsVisible = false;

  /// Latest native player statistics (null until the panel is opened).
  @readonly
  IvsStats? _stats;

  /// Rebuffer events since the stream was opened or the stats were reset.
  @readonly
  var _rebufferCount = 0;

  /// Jumps back to the live edge (drift or a resumed pause) since the stream
  /// was opened or the stats were reset.
  @readonly
  var _liveJumps = 0;

  /// Watches the latency for a drift the speed-up catch-up does not undo.
  final LiveEdgeGuard _liveEdge;

  /// Brings a drifted stream back near live by playing it slightly faster,
  /// with auto latency on (see [LatencyController]). It is the first line;
  /// [_liveEdge]'s reload stays the last resort far behind.
  late final _autoLatency = LatencyController.forProfile(
    playerConfig.buffer,
    enabled: playerConfig.autoLatency,
    now: _now,
  );

  /// What auto latency is doing, for the stats panel (null when it is off
  /// for this stream).
  @readonly
  AutoLatencyStatus? _autoLatencyStatus;

  /// The rate last sent to the native player (it starts at 1.0x); NaN when
  /// unknown: a 1.0x call failed, so the player may still play fast.
  var _sentRate = 1.0;

  /// 1.0x sent again (the player still reported it fast, or the last 1.0x
  /// failed) since the last load or fast rate. The first [_quickResends] go
  /// on the next ticks; after that auto latency stops, saying so, and 1.0x
  /// goes again every [_slowResend] only, so nothing is fought every second.
  var _normalResends = 0;
  DateTime? _lastNormalSend;
  static const _quickResends = 2;
  static const _slowResend = Duration(seconds: 10);

  /// The native player refused a rate above 1.0x: no fast rate is sent
  /// again for the stream (1.0x still is).
  var _rateRefused = false;

  /// A rate failure was reported to telemetry for this stream (once).
  var _rateTroubleReported = false;

  /// Ends a rate above 1.0x whose latency ticks stopped coming.
  Timer? _rateWatchdog;

  /// How often [_rateWatchdog] looks.
  final Duration autoLatencyWatchdog;

  final Duration backgroundPauseDelay;

  /// Last time the viewer or the app did something that rebuffers by
  /// itself (pause, resume, picture-in-picture, the mini player, the content
  /// warning, coming back to the app): stalls around it are not the
  /// network's, so they never count towards the Ultra fallback.
  DateTime? _disturbedAt;
  static const _fallbackGrace = Duration(seconds: 10);

  /// The quality the player last reported, and when the store last asked
  /// for one: only an unrequested down-switch is a strike.
  String? _playingQuality;
  DateTime? _qualityRequestedAt;
  static const _qualityRequestWindow = Duration(seconds: 5);

  /// Turns Ultra into Standard for the next streams after repeated stalls.
  final BufferFallback _bufferFallback;

  /// Until when new streams open with Standard instead of the chosen Ultra
  /// (null when they do not, or auto latency is off).
  DateTime? get bufferFallbackUntil =>
      playerConfig.autoLatency ? _bufferFallback.until : null;

  /// A paused live stream played again after this long resumes at the live
  /// edge (like a fresh start) instead of where it stopped: picking up a
  /// call-length pause where it left off would keep the picture that far
  /// behind the chat until the speed-up caught up, if ever. A quick pause
  /// tap stays below it: the speed-up absorbs a few seconds, a reload would
  /// cost a visible rebuffer.
  static const resumeAtLiveAfter = Duration(seconds: 10);

  final DateTime Function() _now;

  /// When the stream last stopped playing because it was paused.
  DateTime? _pausedAt;

  /// A jump to the live edge is under way (one at a time).
  var _jumping = false;

  /// Time from opening the stream to the first PLAYING state.
  @readonly
  int? _startupMs;

  final _startupStopwatch = Stopwatch();

  @readonly
  var _isInPipMode = false;

  /// When true the video fills the screen (cropping a little off the edges)
  /// instead of fitting inside it with letterbox bars. Never distorts the
  /// image — both modes keep the 16:9 aspect ratio. Toggled by the tablet
  /// button so the picture fits the device screen (e.g. a 3:2 tablet).
  @readonly
  var _fillScreen = false;

  @action
  void toggleFillScreen() => _fillScreen = !_fillScreen;

  /// Fills the screen ([fill]) or fits the video in it (pinch).
  @action
  void setFillScreen(bool fill) => _fillScreen = fill;

  @override
  String get streamQuality =>
      _availableStreamQualities.elementAtOrNull(_streamQualityIndex) ?? 'Auto';

  IvsVideoStoreBase({
    required this.userLogin,
    required this.userId,
    required this.twitchApi,
    required this.authStore,
    required this.settingsStore,
    TwitchStreamService? streamService,
    @visibleForTesting IvsRecoveryPolicy? recoveryPolicy,
    EventSubHandle Function(EventSubTopic topic)? listenEvents,
    @visibleForTesting this.liveStartDelay = const Duration(seconds: 3),
    @visibleForTesting this.offlinePollInterval = const Duration(seconds: 60),
    @visibleForTesting this.autoLatencyWatchdog = const Duration(seconds: 1),
    @visibleForTesting this.backgroundPauseDelay = const Duration(seconds: 1),
    BackgroundAudio? backgroundAudio,
    AudioFocus? audioFocus,
    @visibleForTesting DateTime Function()? now,
    @visibleForTesting BufferFallback? bufferFallback,
    @visibleForTesting Future<bool?> Function()? isMetered,
  }) : _ownsStreamService = streamService == null,
       _isMetered = isMetered ?? NetworkMetering.shared.isMetered,
       _now = now ?? clock.now,
       _liveEdge = LiveEdgeGuard(now: now),
       _backgroundAudio = backgroundAudio ?? BackgroundAudio.shared,
       _audioFocus = audioFocus ?? AudioFocus.shared,
       _recovery = recoveryPolicy ?? IvsRecoveryPolicy(),
       _bufferFallback = bufferFallback ?? BufferFallback.shared,
       playerConfig = IvsPlayerConfig.fromSettings(
         settingsStore,
         fallback: bufferFallback ?? BufferFallback.shared,
       ),
       // Timeouts so a hung GQL/usher request becomes a retry instead of an
       // endless spinner.
       _streamService =
           streamService ??
           TwitchStreamService(
             tokenCache: PlaybackTokenCache.shared,
             Dio(
               BaseOptions(
                 connectTimeout: const Duration(seconds: 5),
                 receiveTimeout: const Duration(seconds: 8),
               ),
             ),
           ) {
    // Let a refused web token renew itself rather than costing the viewer the
    // 2K rendition for the rest of the session.
    _streamService.onWebTokenRejected = authStore.renewTwitchWebToken;
    _startupStopwatch.start();
    if (playerConfig.autoLatency) _autoLatencyStatus = _autoLatency.status;
    if (settingsStore.autoSyncChatDelay) settingsStore.syncedChatDelay = 0.0;
    // Create the native player while the token/usher URL is resolving (they
    // used to run one after the other), then load as soon as both are ready.
    ready = _resolveUrl();
    final startEpoch = _recoveryEpoch;
    _textureReady = _createTexture().then(
      (_) => true,
      onError: (Object e) {
        debugPrint('IvsVideoStore texture creation failed: $e');
        _fail();
        return false;
      },
    );
    unawaited(
      ready
          .then((_) async {
            await _loadInitial(startEpoch);
          })
          // Only URL resolution failures land here (load errors are handled in
          // [_loadInitial]). An offline channel keeps the player; anything
          // else falls back to the WebView ([offlineAtStart]). Either way
          // the status is final, so a minimised player does not spin.
          .catchError((Object e) {
            unawaited(_settleFailedStart(e));
          }),
    );
    unawaited(updateStreamInfo());
    _scheduleOverlayHide();

    // Offline: look for the channel coming back now and then.
    _disposeOfflinePoll = reaction((_) => _status, (status) {
      // Nothing left to sync chat with.
      if ((status == IvsPlaybackStatus.offline ||
              status == IvsPlaybackStatus.failed) &&
          settingsStore.autoSyncChatDelay) {
        settingsStore.syncedChatDelay = 0.0;
      }
      if (status == IvsPlaybackStatus.offline) {
        _offlinePoll ??= Timer.periodic(
          offlinePollInterval,
          (_) => unawaited(_restartIfLive()),
        );
      } else {
        _offlinePoll?.cancel();
        _offlinePoll = null;
      }
    });

    // Logged in: the channel going live restarts the player at once.
    if (listenEvents != null) {
      try {
        _liveWatcher = LiveStateWatcher(
          listen: listenEvents,
          broadcasterId: userId,
          onChange: _onLiveChange,
        );
      } on ArgumentError catch (e) {
        debugPrint('IvsVideoStore live watcher: $e');
      }
    }

    // Enable auto picture-in-picture so the stream keeps playing in a floating
    // window when the user leaves the app.
    if (Platform.isAndroid) {
      _disposeAutoPipReaction = autorun((_) => _applyAutoPip());
    }

    // The media notification shows the stream while it plays or reconnects
    // (paused too), when the viewer asked for background audio.
    _disposeBackgroundAudioReaction = reaction(
      (_) => (
        show:
            settingsStore.backgroundAudio &&
            !_audioNotificationStopped &&
            (_status == IvsPlaybackStatus.playing ||
                _status == IvsPlaybackStatus.reconnecting),
        playing: !_paused,
        title: _streamInfo?.userName,
        subtitle: _streamInfo?.title,
      ),
      (notification) {
        if (!notification.show) {
          unawaited(_backgroundAudio.hide(this));
          return;
        }
        final name = notification.title;
        unawaited(
          _backgroundAudio.show(
            owner: this,
            title: name == null || name.isEmpty ? userLogin : name,
            subtitle: notification.subtitle?.trim() ?? '',
            playing: notification.playing,
            onCommand: _onMediaCommand,
          ),
        );
      },
    );

    // The sound is held while the stream plays; a pause lets it go, unless
    // a call caused it (its end gives the sound, and the stream, back).
    _disposeAudioFocusReaction = reaction(
      (_) =>
          (_status == IvsPlaybackStatus.playing ||
              _status == IvsPlaybackStatus.reconnecting) &&
          !_paused,
      (bool playing) {
        if (playing) {
          // Played again while a call had paused it: the viewer's choice.
          final chosen = _pausedForFocus;
          _pausedForFocus = false;
          unawaited(_takeAudioFocus(viewerChose: chosen));
        } else if (!_pausedForFocus) {
          unawaited(_audioFocus.abandon(this));
        }
      },
    );

    // Captions follow their setting at once (also sent with each load).
    captions.start();
  }

  final _offlineAtStart = Completer<bool>();

  /// Completes once a failed start is understood: true when Helix confirms
  /// the channel is offline (the player stays, showing it, and restarts
  /// when it goes live), false otherwise (fall back to the WebView). Never
  /// completes when the start worked.
  Future<bool> get offlineAtStart => _offlineAtStart.future;

  /// The URL could not be had. Only an offline channel (confirmed by
  /// Helix) keeps the native player: anything else, maybe a Twitch change,
  /// leaves it to the WebView.
  Future<void> _settleFailedStart(Object error) async {
    var offline = false;
    if (!_disposed && !isRetryableTokenError(error)) {
      try {
        await twitchApi.getStream(userLogin: userLogin);
      } on ApiException catch (e) {
        offline = e.statusCode == 404;
      } catch (e, stack) {
        _reportUnexpected(e, stack, 'offline check at start');
      }
    }
    if (!_disposed) {
      runInAction(() {
        _status = offline
            ? IvsPlaybackStatus.offline
            : IvsPlaybackStatus.failed;
        if (offline) {
          _streamInfo = null;
          _paused = true;
        }
      });
      if (offline) unawaited(updateStreamInfo(forceUpdate: true));
    }
    _offlineAtStart.complete(offline && !_disposed);
  }

  /// How long after the live event the playlist is expected to be ready
  /// (and how often it is looked for again within [_trustLivePush]).
  final Duration liveStartDelay;

  /// How often an offline player checks whether its channel is back (the
  /// only way without the EventSub push: logged out).
  final Duration offlinePollInterval;

  Timer? _offlinePoll;
  ReactionDisposer? _disposeOfflinePoll;

  LiveStateWatcher? _liveWatcher;
  Timer? _liveStartTimer;

  /// When EventSub last said the channel went live.
  DateTime? _wentLiveAt;

  /// How long a "went live" push outweighs Helix (which lags it) and an
  /// unready playlist: an offline answer then is retried, not shown.
  static const _trustLivePush = Duration(seconds: 90);

  bool get _justWentLive {
    final at = _wentLiveAt;
    return at != null && clock.now().difference(at) < _trustLivePush;
  }

  void _onLiveChange(LiveChange change) {
    if (_disposed) return;
    switch (change) {
      case LiveChange.online:
        // Remembered even while recovering: the recovery then retries
        // instead of settling offline.
        _wentLiveAt = clock.now();
        _liveStartTimer?.cancel();
        _liveStartTimer = Timer(liveStartDelay, () {
          if (!_disposed && _status == IvsPlaybackStatus.offline) {
            unawaited(handleRefresh());
          }
        });
      case LiveChange.maybeMissed:
        if (_status == IvsPlaybackStatus.offline) unawaited(_restartIfLive());
    }
  }

  /// A failure that is not an API answer: a bug, or Twitch changed.
  static void _reportUnexpected(Object error, StackTrace stack, String what) {
    debugPrint('IvsVideoStore $what: $error');
    Telemetry.recordError(error, stack, reason: 'ivs $what');
  }

  /// Restarts an offline player when the channel turns out to be live.
  Future<void> _restartIfLive() async {
    try {
      await twitchApi.getStream(userLogin: userLogin);
    } on ApiException catch (e) {
      // 404: still offline. Anything else: unknown; the next poll retries.
      if (e.statusCode != 404) debugPrint('IvsVideoStore live check: $e');
      return;
    } catch (e, stack) {
      _reportUnexpected(e, stack, 'live check');
      return;
    }
    if (!_disposed && _status == IvsPlaybackStatus.offline) {
      unawaited(handleRefresh());
    }
  }

  Future<void> _applyAutoPip() async {
    // Read first: the autorun follows it (a covered stream never goes to
    // picture-in-picture on its own).
    if (_contentGate.value.allowsLeaving &&
        settingsStore.showVideo &&
        settingsStore.autoPictureInPicture &&
        await SimplePip.isAutoPipAvailable) {
      _autoPipArmed = true;
      pip.setAutoPipMode();
    } else {
      _autoPipArmed = false;
      pip.setAutoPipMode(autoEnter: false);
    }
  }

  var _autoPipArmed = false;

  @visibleForTesting
  void debugMarkAutoPipArmed() => _autoPipArmed = true;

  var _backgroundTrip = 0;

  /// Takes the sound; refused (a call going on), an automatic start waits
  /// for it to be given, but a play the viewer chose goes on.
  Future<void> _takeAudioFocus({required bool viewerChose}) async {
    final granted = await _audioFocus.request(this, _onAudioFocus);
    if (granted || viewerChose || _disposed || _paused) return;
    _pausedForFocus = true;
    handlePausePlay();
  }

  void _onAudioFocus(AudioFocusChange change) {
    if (_disposed) return;
    switch (change) {
      case AudioFocusChange.lossTransient:
        if (!_paused) {
          _pausedForFocus = true;
          handlePausePlay();
        }
      case AudioFocusChange.loss:
      case AudioFocusChange.noisy:
        _pausedForFocus = false;
        if (_paused) {
          // Already paused (by a call): nothing else lets the focus go.
          unawaited(_audioFocus.abandon(this));
        } else {
          handlePausePlay();
        }
      case AudioFocusChange.gain:
        if (_pausedForFocus) {
          _pausedForFocus = false;
          // A VOD on top has the sound now.
          if (_paused && !_holdsPlayback) handlePausePlay();
        }
    }
  }

  /// The viewer paused or stopped from the notification or headphones:
  /// the end of a call must not play the stream again.
  void _keepPausedAfterCall() {
    if (!_pausedForFocus) return;
    _pausedForFocus = false;
    unawaited(_audioFocus.abandon(this));
  }

  void _onMediaCommand(MediaCommand command) {
    if (_disposed) return;
    switch (command) {
      case MediaCommand.play:
        // A VOD on top has the sound: it would pause this again at once.
        if (_paused && !_holdsPlayback) handlePausePlay();
      case MediaCommand.pause:
        _keepPausedAfterCall();
        if (!_paused) handlePausePlay();
      case MediaCommand.stop:
        _keepPausedAfterCall();
        if (!_paused) handlePausePlay();
        runInAction(() => _audioNotificationStopped = true);
    }
  }

  /// True while another player (a VOD on top) has playback focus.
  var _focusSuppressed = false;

  /// Where the mature-content warning stands (observable without codegen:
  /// the auto-PiP autorun follows it).
  final _contentGate = Observable(ContentGate.clear);

  /// True when the warning paused the stream (or kept it from starting),
  /// so clearing it resumes only that.
  var _heldForContentGate = false;

  @override
  ContentGate get contentGate => _contentGate.value;

  @override
  void setContentGate(ContentGate gate) {
    if (gate == _contentGate.value) return;
    runInAction(() => _contentGate.value = gate);
    if (gate == ContentGate.covering) {
      _holdAutoLatency(AutoLatencyReason.paused);
      // An explicit pause, only of a stream that plays: a toggle would
      // start one still loading (that one is held when it starts).
      if (_isPlaying) {
        _heldForContentGate = true;
        _channel?.invokeMethod('pause');
      }
    } else if (gate == ContentGate.clear && _heldForContentGate) {
      _markDisturbed();
      _heldForContentGate = false;
      if (_paused && !_focusSuppressed) handlePausePlay();
    }
  }

  bool get _covered => _contentGate.value == ContentGate.covering;

  /// Nothing may start the sound on its own: a VOD on top has it, or the
  /// content warning was not accepted.
  bool get _holdsPlayback => _focusSuppressed || _covered;

  /// Keeps this stream silent while another player has focus: automatic
  /// playback after a load or a reconnect is paused again.
  void setFocusSuppressed(bool suppressed) => _focusSuppressed = suppressed;

  /// Applies the auto-PiP choice again, e.g. after a VOD screen on top of
  /// this stream turned auto-PiP off when it closed.
  void reassertAutoPip() {
    if (Platform.isAndroid) unawaited(_applyAutoPip());
  }

  /// Updates the picture-in-picture state when the OS enters/exits PiP.
  ///
  /// Auto latency keeps correcting in picture-in-picture and the mini
  /// player: the rate is as invisible there, and the SDK speed-up it
  /// replaces kept running too.
  @action
  void onPipEntered() {
    _isInPipMode = true;
    _markDisturbed();
  }

  /// The player moved into (or out of) the in-app mini player.
  void setMinimized(bool minimized) => _markDisturbed();

  void _markDisturbed() => _disturbedAt = _now();

  @action
  void onPipExited() {
    _isInPipMode = false;
    _markDisturbed();
    _liveEdge.expedite();
  }

  /// Resolves the usher URL, retrying transient network failures with the
  /// recovery backoff. A missing token (channel offline) throws at once.
  @action
  Future<void> _resolveUrl() async {
    for (var attempt = 0; ; attempt++) {
      try {
        _url = await _streamService.getUsherUrl(
          userLogin: userLogin,
          authToken: _userAuthToken,
        );
        return;
      } catch (e) {
        final delay = _recovery.tokenRetryDelay(attempt);
        if (_disposed || delay == null || !isRetryableTokenError(e)) rethrow;
        await Future<void>.delayed(delay);
        if (_disposed) rethrow;
      }
    }
  }

  /// The token sent with the playback access token request.
  ///
  /// Some streams only expose the enhanced-broadcast renditions (1440p HEVC /
  /// AV1) to an authenticated viewer. Only the twitch.tv web token is sent:
  /// GQL always refuses the app's own login token (minted for another
  /// client-id), so trying it would only delay every start. The service
  /// falls back to an anonymous request whenever the token is refused.
  String? get _userAuthToken => authStore.twitchWebToken;

  /// Wires the per-texture MethodChannel for the texture-backed mini player.
  void attachTextureChannel(int textureId) =>
      _attachChannel('onset/ivs-texture/$textureId');

  void _attachChannel(String name) {
    final channel = MethodChannel(name);
    _channel = channel;
    channel.setMethodCallHandler((call) async {
      if (call.method == 'onEvent') {
        _onEvent(Map<String, dynamic>.from(call.arguments as Map));
      }
    });
  }

  /// Creates the native texture-backed IVS player (without a source; the URL
  /// is loaded once resolved), then wires its control/event channel. The
  /// texture lives for as long as this store does.
  Future<void> _createTexture() async {
    if (_disposed || _textureId != null) return;
    final id = await _textureManager.invokeMethod<int>('create', {
      'config': playerConfig.toCreateArgs(),
    });
    if (id == null) return;
    if (_disposed) {
      // The screen closed while the native player was being created: release
      // it now, otherwise it would keep playing audio with no owner.
      await _textureManager.invokeMethod('dispose', {'textureId': id});
      return;
    }
    attachTextureChannel(id);
    runInAction(() => _textureId = id);
    if (_statsVisible) unawaited(_sendStatsEnabled());
  }

  /// Completes with true once the native player exists (false if creating it
  /// failed), so loads never race the `create` call.
  late final Future<bool> _textureReady;

  /// First load of the stream once both the player and the URL are ready.
  ///
  /// Skipped when a refresh (or dispose) happened meanwhile: the refresh
  /// loads its own, newer URL once the player exists. A native failure here
  /// falls back to the WebView engine.
  Future<void> _loadInitial(int startEpoch) async {
    final url = _url;
    if (startEpoch != _recoveryEpoch || url == null) return;
    try {
      await _loadSource(url, startEpoch);
    } catch (e) {
      debugPrint('IvsVideoStore initial load failed: $e');
      _fail();
    }
  }

  /// Sends [url] to the native player once it exists. Latency is hidden again
  /// until the new source plays its first frame. Returns without loading if
  /// [epoch] went stale (refresh/dispose) while waiting for the player.
  Future<void> _loadSource(String url, int epoch) async {
    if (!await _textureReady) {
      // No native player to load into: make sure the fallback happens.
      _fail();
      return;
    }
    if (epoch != _recoveryEpoch) return;
    _hasPlayed = false;
    _lastLatencySecond = null;
    // Every load starts at the live edge, at 1.0x.
    _liveEdge.onLoad();
    if (playerConfig.autoLatency) {
      _normalResends = 0;
      _lastNormalSend = null;
      _playingQuality = null;
      _autoLatency.onLoad();
      _applyAutoRate();
    }
    await _channel?.invokeMethod('load', {'url': url});
  }

  @action
  void _onEvent(Map<String, dynamic> e) {
    switch (e['type']) {
      case 'state':
        final state = e['state'] as String?;
        _isPlaying = state == 'PLAYING';
        if (_isPlaying) _hasPlayed = true;
        if (state == 'PLAYING') {
          _pausedAt = null;
          _lastErrorRefused = false;
          _audioNotificationStopped = false;
          // Native auto-play after a (re)load while a VOD on top has focus
          // or the content warning is up.
          if (_holdsPlayback) {
            if (_covered) _heldForContentGate = true;
            _channel?.invokeMethod('pause');
          }
          _paused = false;
          _status = IvsPlaybackStatus.playing;
          if (_startupMs == null) {
            _startupStopwatch.stop();
            _startupMs = _startupStopwatch.elapsedMilliseconds;
          }
        }
        if (state == 'IDLE' || state == 'ENDED') {
          _paused = true;
          _pausedAt ??= _now();
        }
        if (Platform.isAndroid) pip.setIsPlaying(!_paused);
        break;
      case 'qualities':
        final list = (e['list'] as List).map((q) => q.toString()).toList();
        _availableStreamQualities = ['Auto', ...list];
        // Sent once per load: restore the quality and the sound state.
        unawaited(_restoreQuality(list));
        _resendSound();
        captions.onLoad();
        break;
      case 'caption' || 'textTracks':
        captions.handleEvent(e);
        break;
      case 'qualitiesChanged':
        // The ladder grew or shrank while playing (Twitch negotiates the
        // 1440p HEVC/AV1 renditions later): refresh the menu, keeping the
        // current pick on the same entry.
        final list = (e['list'] as List).map((q) => q.toString()).toList();
        final selected = streamQuality;
        _availableStreamQualities = ['Auto', ...list];
        final restored = _availableStreamQualities.indexOf(selected);
        _streamQualityIndex = restored == -1 ? 0 : restored;
        // Without a pick this session, the saved quality or "highest" may
        // only now be on offer (a saved 1440p60, or 2K for "highest").
        if (_sessionQuality == null) unawaited(_restoreQuality(list));
        break;
      case 'quality':
        final name = e['name'] as String?;
        final index = _availableStreamQualities.indexOf(name ?? '');
        if (index != -1) _streamQualityIndex = index;
        if (playerConfig.autoLatency && name != null) {
          final previous = _playingQuality;
          _playingQuality = name;
          final requestedAt = _qualityRequestedAt;
          final requested =
              requestedAt != null &&
              _now().difference(requestedAt) <= _qualityRequestWindow;
          if (!requested &&
              previous != null &&
              isQualityDownSwitch(previous, name)) {
            _autoLatency.onQualityChanged();
            _applyAutoRate();
          }
        }
        break;
      case 'ad':
        if (playerConfig.autoLatency) {
          final ms = (e['durationMs'] as num?)?.toInt() ?? 0;
          _autoLatency.onAd(Duration(milliseconds: ms));
          _applyAutoRate();
        }
        break;
      case 'latency':
        final ms = (e['ms'] as num?)?.toInt() ?? -1;
        // Before the first frame IVS has no live position, so the value is
        // meaningless (often 0): never show it nor feed it to the chat delay.
        if (ms < 0 || !_hasPlayed) {
          // A tick that played without a latency: nothing to judge a
          // catch-up on, so it stops.
          if (ms < 0 && _hasPlayed && playerConfig.autoLatency) {
            _autoLatency.onMissingLatency();
            _applyAutoRate(nativeRate: (e['rate'] as num?)?.toDouble());
          }
          break;
        }
        _latencyMs = ms;
        _latency = formatLatency(ms);
        if (_isPlaying) {
          latencySampler.add(ms);
          _samplesVersion++;
        }
        // Only a stream that plays undisturbed is judged (a pause or a
        // recovery is not drift).
        final judged =
            _isPlaying &&
            !_recovering &&
            !_jumping &&
            _status == IvsPlaybackStatus.playing;
        if (_liveEdge.onSample(ms, playing: judged)) {
          unawaited(_jumpToLive());
        }
        if (playerConfig.autoLatency) {
          final nativeRate = (e['rate'] as num?)?.toDouble();
          _autoLatency.onSample(
            latencyMs: ms,
            bufferMs: (e['bufferMs'] as num?)?.toInt(),
            lowLatency: e['lowLatency'] as bool?,
            nativeRate: nativeRate,
            hold: _autoLatencyHold,
          );
          if (_paused || _covered) _markDisturbed();
          _applyAutoRate(nativeRate: nativeRate);
        }
        // Paused, the latency grows a second a second while the picture
        // stands still: chat keeps the delay of the last moment played.
        if (!_isPlaying) break;
        // The chat delay keeps moving in whole seconds only, exactly as before,
        // so the delayed chat queue is not rebuilt on every tick. With auto
        // latency holding the stream near a half second, it also waits for
        // the latency to be clearly nearer another second.
        final seconds = playerConfig.autoLatency
            ? chatDelaySecondsWithHysteresis(ms, _lastLatencySecond)
            : chatDelaySecondsFromLatency(ms);
        if (seconds == _lastLatencySecond) break;
        _lastLatencySecond = seconds;
        if (settingsStore.autoSyncChatDelay) {
          settingsStore.syncedChatDelay = seconds.toDouble();
        }
        break;
      case 'rebuffering':
        _rebufferCount++;
        // A stall of the stream that played (not of a load under way).
        if (playerConfig.autoLatency && _hasPlayed && !_recovering) {
          _autoLatency.onStall();
          _applyAutoRate();
          if (playerConfig.buffer == BufferProfile.ultra && !_viewerStall) {
            _bufferFallback.onUltraRebuffer();
          }
        }
        break;
      case 'stats':
        // A tick can race a toggle-off; never resurrect hidden stats.
        if (_statsVisible) _stats = IvsStats.fromEvent(e);
        break;
      case 'error':
        final kind = classifyIvsError(
          errorType: e['errorType'] as String?,
          code: (e['code'] as num?)?.toInt(),
          source: e['source'] as String?,
        );
        debugPrint(
          'IVS error: ${e['errorType']} ${e['code']} ${e['source']} -> $kind',
        );
        if (_recovering && kind != IvsErrorKind.fatal) break;
        _lastErrorRefused = kind == IvsErrorKind.refreshToken;
        if (_lastErrorRefused && _streamService.refusalFor(userLogin) != null) {
          // Twitch said so with the token: a new one changes nothing.
          unawaited(_failExplained());
          break;
        }
        _applyRecovery(_recovery.onError(kind));
        break;
    }
  }

  /// Why auto latency must not correct now, if it must not.
  AutoLatencyReason? get _autoLatencyHold {
    if (_paused || _covered) return AutoLatencyReason.paused;
    if (_recovering || _jumping || _status != IvsPlaybackStatus.playing) {
      return AutoLatencyReason.reconnecting;
    }
    if (!_isPlaying) return AutoLatencyReason.buffering;
    return null;
  }

  /// A stall the viewer or the app caused (paused, or just disturbed), not
  /// the network.
  bool get _viewerStall {
    if (_paused || _covered) return true;
    final at = _disturbedAt;
    return at != null && _now().difference(at) < _fallbackGrace;
  }

  /// Back to 1.0x now, without waiting for the next tick.
  void _holdAutoLatency(AutoLatencyReason reason) {
    _markDisturbed();
    if (!playerConfig.autoLatency) return;
    _autoLatency.hold(reason);
    _applyAutoRate();
  }

  /// Makes the player play the controller's rate, and keeps the stats panel
  /// status current. [nativeRate] is the rate the player last reported.
  void _applyAutoRate({double? nativeRate}) {
    if (!_disposed) _sendWantedRate(nativeRate);
    _publishAutoLatencyStatus();
  }

  void _publishAutoLatencyStatus() {
    final status = _autoLatency.status;
    if (status != _autoLatencyStatus) {
      runInAction(() => _autoLatencyStatus = status);
    }
  }

  void _sendWantedRate(double? nativeRate) {
    final channel = _channel;
    if (channel == null) return;
    final rate = _autoLatency.rate;
    if (rate > 1) {
      if (_rateRefused || rate == _sentRate) return;
      _normalResends = 0;
      _send(channel, rate);
      _watchTicks();
      return;
    }
    final fast = nativeRate != null && nativeRate > 1.005;
    if (_sentRate == 1.0 && !fast) {
      if (nativeRate != null) _normalResends = 0;
      return;
    }
    if (_sentRate.isNaN && nativeRate != null && !fast) {
      // The failed 1.0x went through after all.
      _sentRate = 1.0;
      return;
    }
    if (_sentRate == 1.0 || _sentRate.isNaN) {
      // Already asked for: a resend, quick at first, then slow.
      if (_normalResends >= _quickResends) {
        if (fast && _autoLatency.status.phase != AutoLatencyPhase.stopped) {
          _autoLatency.stop(AutoLatencyReason.stuckFast, rate: nativeRate);
          _reportRateTrouble(
            StateError('live rate stayed at $nativeRate after 1.0x'),
            StackTrace.current,
          );
        }
        final last = _lastNormalSend;
        if (last != null && _now().difference(last) < _slowResend) return;
      }
      _normalResends++;
    }
    _lastNormalSend = _now();
    _send(channel, 1.0);
  }

  void _send(MethodChannel channel, double rate) {
    _sentRate = rate;
    unawaited(_sendRate(channel, rate));
  }

  Future<void> _sendRate(MethodChannel channel, double rate) async {
    try {
      await channel.invokeMethod('setPlaybackRate', {'rate': rate});
    } on PlatformException catch (e, stack) {
      _onRateFailed(rate, e, stack);
    } on MissingPluginException catch (e, stack) {
      _onRateFailed(rate, e, stack);
    }
  }

  /// The player refused [rate]. A refused fast rate never applied: no fast
  /// rate is asked for again. A refused 1.0x may leave the stream fast: the
  /// rate becomes unknown, 1.0x is tried again while the player reports it
  /// fast, and auto latency stops, saying so.
  void _onRateFailed(double rate, Object error, StackTrace stack) {
    debugPrint('IvsVideoStore setPlaybackRate $rate refused: $error');
    if (_disposed) return;
    _reportRateTrouble(error, stack);
    if (rate > 1) {
      _rateRefused = true;
      if (_sentRate == rate) _sentRate = 1.0;
      _autoLatency.onRateRejected();
    } else {
      _sentRate = double.nan;
      _autoLatency.stop(AutoLatencyReason.notBackToNormal);
    }
    // Retried on the next tick, not in a loop here.
    _publishAutoLatencyStatus();
  }

  void _reportRateTrouble(Object error, StackTrace stack) {
    if (_rateTroubleReported) return;
    _rateTroubleReported = true;
    Telemetry.recordError(error, stack, reason: 'ivs auto latency rate');
  }

  /// Watches a rate above 1.0x: if its latency ticks stop, it ends.
  void _watchTicks() {
    _rateWatchdog ??= Timer.periodic(autoLatencyWatchdog, (timer) {
      if (_disposed) {
        timer.cancel();
        return;
      }
      if (_autoLatency.checkTicks()) _applyAutoRate();
      if (_autoLatency.rate <= 1) {
        timer.cancel();
        _rateWatchdog = null;
      }
    });
  }

  void _applyRecovery(IvsRecoveryAction action) {
    if (_disposed) return;
    switch (action) {
      case IvsRetry(:final delay) && final action:
        _recovering = true;
        runInAction(() {
          _status = IvsPlaybackStatus.reconnecting;
          _retryAttempt = _recovery.attemptsInWindow;
        });
        _retryTimer?.cancel();
        final epoch = _recoveryEpoch;
        final fresh = action.freshToken;
        _retryTimer = Timer(
          delay,
          () => unawaited(_reload(epoch, freshToken: fresh)),
        );
      case IvsOffline():
        _recovering = true;
        unawaited(_confirmOffline(_recoveryEpoch));
      case IvsFallback():
        _recovering = false;
        _lastErrorRefused ? unawaited(_failExplained()) : _fail();
    }
  }

  /// Gives up on a stream Twitch refuses, saying why: the reason the token
  /// carried, else the one usher gives for the playlist.
  Future<void> _failExplained() async {
    _retryTimer?.cancel();
    final epoch = _recoveryEpoch;
    final name = _streamInfo?.userName ?? _offlineChannelInfo?.broadcasterName;
    final shownName = name == null || name.isEmpty ? userLogin : name;
    var notice = switch (_streamService.refusalFor(userLogin)) {
      final refusal? => StreamRefusalNotice(refusal: refusal, name: shownName),
      null => null,
    };
    final url = _url;
    if (notice == null && url != null) {
      UsherRefusal? details;
      try {
        details = await _streamService
            .usherRefusalDetails(url)
            .timeout(const Duration(seconds: 4));
      } on TimeoutException catch (e) {
        // Only the explanation is lost: the player still gives up below.
        debugPrint('IvsVideoStore usher reason: $e');
      } catch (e, stack) {
        _reportUnexpected(e, stack, 'usher reason');
      }
      final reason = details?.reason;
      if (details?.refusal case final refusal?) {
        notice = StreamRefusalNotice(refusal: refusal, name: shownName);
      } else if (reason != null) {
        // Twitch's English words: shown on English screens only, so always
        // logged.
        debugPrint('IvsVideoStore usher refused the stream: $reason');
        notice = StreamRefusalNotice(name: shownName, usherReason: reason);
      }
    }
    if (_disposed || epoch != _recoveryEpoch) return;
    runInAction(() => _refusalNotice = notice);
    _fail();
  }

  /// Reloads the same native player with a freshly resolved usher URL.
  Future<void> _reload(int epoch, {bool freshToken = false}) async {
    if (epoch != _recoveryEpoch) return;
    _lastErrorRefused = false;
    try {
      final url = await _streamService.getUsherUrl(
        userLogin: userLogin,
        authToken: _userAuthToken,
        forceFreshToken: freshToken,
      );
      if (epoch != _recoveryEpoch) return;
      runInAction(() => _url = url);
      await _loadSource(url, epoch);
      if (epoch == _recoveryEpoch) _recovering = false;
    } catch (e) {
      debugPrint('IvsVideoStore reload failed: $e');
      if (epoch != _recoveryEpoch) return;
      _recovering = false;
      _applyRecovery(
        _recovery.onError(
          isRetryableTokenError(e)
              ? IvsErrorKind.recoverable
              : IvsErrorKind.offline,
        ),
      );
    }
  }

  /// IVS says the stream is unavailable: confirm with Helix. Offline shows the
  /// offline state (no WebView fallback); still live means a transient error.
  Future<void> _confirmOffline(int epoch) async {
    _lastErrorRefused = false;
    StreamTwitch? info;
    // Only a 404 means offline; a failed check proves nothing.
    var unknown = false;
    try {
      info = await twitchApi.getStream(userLogin: userLogin);
    } on ApiException catch (e) {
      unknown = e.statusCode != 404;
      if (unknown) debugPrint('IvsVideoStore offline check: $e');
    } catch (e, stack) {
      unknown = true;
      _reportUnexpected(e, stack, 'offline check');
    }
    if (epoch != _recoveryEpoch) return;
    _recovering = false;
    if (unknown) {
      _applyRecovery(_recovery.onError(IvsErrorKind.recoverable));
      return;
    }
    if (info == null && _justWentLive) {
      // Helix lags a fresh push and the playlist may not be up yet: look
      // again shortly, outside the retry budget, until the window ends.
      _recovering = true;
      runInAction(() => _status = IvsPlaybackStatus.reconnecting);
      _retryTimer?.cancel();
      _retryTimer = Timer(liveStartDelay, () => unawaited(_reload(epoch)));
      return;
    }
    if (info != null) {
      runInAction(() => _streamInfo = info);
      _applyRecovery(_recovery.onError(IvsErrorKind.recoverable));
      return;
    }
    runInAction(() {
      _streamInfo = null;
      _status = IvsPlaybackStatus.offline;
      _paused = true;
    });
    try {
      final channel = await twitchApi.getChannel(userId: userId);
      if (epoch == _recoveryEpoch) {
        runInAction(() => _offlineChannelInfo = channel);
      }
    } catch (_) {}
  }

  void _fail() {
    if (_disposed) return;
    // Stop any pending retry: a failed player (e.g. minimised, where nothing
    // falls back) must not be reloaded behind the user's back.
    _retryTimer?.cancel();
    _recoveryEpoch++;
    _recovering = false;
    runInAction(() => _status = IvsPlaybackStatus.failed);
    onFatalError?.call();
  }

  @readonly
  var _muted = false;

  @readonly
  var _volume = 1.0;

  @action
  void toggleMute() {
    _muted = !_muted;
    unawaited(_invoke('setMuted', {'muted': _muted}));
  }

  /// Sets the player volume (0..1). Changing the volume unmutes, like most
  /// players.
  @action
  void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
    unawaited(_invoke('setVolume', {'volume': _volume}));
    if (_muted) {
      _muted = false;
      unawaited(_invoke('setMuted', {'muted': false}));
    }
  }

  /// Re-applies the sound choice after every load (the native player should
  /// keep it, but this guards against a reset).
  void _resendSound() {
    if (!_muted && _volume == 1.0) return;
    unawaited(_invoke('setMuted', {'muted': _muted}));
    unawaited(_invoke('setVolume', {'volume': _volume}));
  }

  Future<void> _invoke(String method, Map<String, Object?> args) async {
    try {
      await _channel?.invokeMethod(method, args);
    } catch (e) {
      debugPrint('IvsVideoStore $method failed: $e');
    }
  }

  /// Shows or hides the video stats panel and turns native stats on/off.
  @action
  void toggleStats() {
    _statsVisible = !_statsVisible;
    if (!_statsVisible) _stats = null;
    unawaited(_sendStatsEnabled());
  }

  /// Clears the latency samples and rebuffer count to start a new measurement.
  @action
  void resetStats() {
    latencySampler.reset();
    _samplesVersion++;
    _rebufferCount = 0;
    _liveJumps = 0;
  }

  Future<void> _sendStatsEnabled() async {
    try {
      await _channel?.invokeMethod('setStatsEnabled', {
        'enabled': _statsVisible,
      });
    } catch (e) {
      debugPrint('IvsVideoStore setStatsEnabled failed: $e');
    }
  }

  @override
  void handlePausePlay() {
    if (_paused) {
      _markDisturbed();
    } else {
      _holdAutoLatency(AutoLatencyReason.paused);
    }
    if (_paused && _resumesAtLive) {
      unawaited(_jumpToLive(resume: true));
      return;
    }
    _channel?.invokeMethod(_paused ? 'play' : 'pause');
  }

  /// Whether playing again should start at the live edge: the stream was
  /// playing fine and has been paused for a while.
  bool get _resumesAtLive {
    final pausedAt = _pausedAt;
    return pausedAt != null &&
        _hasPlayed &&
        !_recovering &&
        _status == IvsPlaybackStatus.playing &&
        _now().difference(pausedAt) >= resumeAtLiveAfter;
  }

  /// Reloads the stream, which starts at the live edge.
  ///
  /// The playback token is reused while valid, so this costs one playlist
  /// request and a short rebuffer. When the URL cannot be had, nothing is
  /// lost: a drifting stream keeps playing where it is, and a resumed one
  /// simply plays on ([resume]).
  Future<void> _jumpToLive({bool resume = false}) async {
    // One jump at a time: a second tap on play waits for the first.
    if (_disposed || _jumping) return;
    if (_recovering) {
      if (resume) _channel?.invokeMethod('play');
      return;
    }
    _jumping = true;
    final epoch = _recoveryEpoch;
    String url;
    try {
      url = await _streamService.getUsherUrl(
        userLogin: userLogin,
        authToken: _userAuthToken,
      );
    } catch (e) {
      _jumping = false;
      debugPrint('IvsVideoStore jump to live failed: ${e.runtimeType}');
      if (resume && !_disposed && epoch == _recoveryEpoch) {
        _channel?.invokeMethod('play');
      }
      return;
    }
    // A newer load or a pause made meanwhile wins: the live player plays
    // as soon as a load is ready, so loading now would undo the pause.
    if (_disposed ||
        epoch != _recoveryEpoch ||
        _recovering ||
        (!resume && _pausedAt != null)) {
      _jumping = false;
      return;
    }
    runInAction(() {
      _url = url;
      _liveJumps++;
    });
    try {
      await _loadSource(url, epoch);
    } catch (e) {
      // Like a failed recovery reload: the player may have dropped the old
      // source, so it is recovered (and falls back to the WebView if that
      // keeps failing) rather than left frozen.
      debugPrint('IvsVideoStore jump to live load failed: ${e.runtimeType}');
      if (!_disposed && epoch == _recoveryEpoch) {
        _applyRecovery(_recovery.onError(IvsErrorKind.recoverable));
      }
    } finally {
      _jumping = false;
    }
  }

  final Future<bool?> Function() _isMetered;

  /// Quality the user picked during this session; re-applied after reloads.
  String? _sessionQuality;

  /// Quality saved by the overlay picker (any engine), read once.
  late final Future<String?> _savedQuality = SharedPreferences.getInstance()
      .then((prefs) => prefs.getString('last_stream_quality'))
      .catchError((Object _) => null);

  /// Bumped by every qualities event and user pick so an older pending
  /// restore never applies after a newer one (or over the user's choice).
  var _qualityGeneration = 0;

  Future<void> _restoreQuality(List<String> available) async {
    final generation = ++_qualityGeneration;
    final saved = await _savedQuality;
    if (_disposed || generation != _qualityGeneration) return;
    // Read after the await so a pick made meanwhile is never overridden. The
    // session pick wins while the stream still offers it; otherwise fall back
    // to the saved quality / highest setting.
    final session = _sessionQuality;
    if (session == 'Auto') {
      // An explicit Auto pick this session wins over saved/highest.
      _applyQuality('Auto');
      return;
    }
    final sessionPick = pickInitialQuality(
      available: available,
      defaultToHighest: false,
      lastQuality: session,
      keepAudioOnly: true,
    );
    if (sessionPick == null && settingsStore.dataSaver) {
      final metered = await _isMetered().catchError((Object _) => null);
      if (_disposed || generation != _qualityGeneration) return;
      final capped = metered == true ? dataSaverQuality(available) : null;
      if (capped != null) {
        _applyQuality(capped);
        return;
      }
    }
    final quality =
        sessionPick ??
        pickInitialQuality(
          available: available,
          defaultToHighest: settingsStore.defaultToHighestQuality,
          lastQuality: saved,
        );
    // Applied even if the overlay already shows it: a reload resets the
    // native player to Auto.
    if (quality == null) return;
    _applyQuality(quality);
  }

  @override
  void setStreamQuality(String quality) {
    _qualityGeneration++;
    _sessionQuality = quality;
    _applyQuality(quality);
  }

  @action
  void _applyQuality(String quality) {
    _qualityRequestedAt = _now();
    final index = _availableStreamQualities.indexOf(quality);
    if (index == -1) return;
    _streamQualityIndex = index;
    if (quality == 'Auto') {
      _channel?.invokeMethod('setAutoQuality');
    } else {
      _channel?.invokeMethod('setQuality', {'name': quality});
    }
  }

  final _qualityLadder = Observable(QualityLadder.empty);
  String? _qualityLadderUrl;

  QualityLadder get qualityLadder => _qualityLadder.value;

  @override
  Future<void> updateStreamQualities() async {
    final url = _url;
    if (url == null || url == _qualityLadderUrl) return;
    _qualityLadderUrl = url;
    QualityLadder? ladder;
    try {
      ladder = await _streamService.qualityLadder(url);
    } catch (e) {
      debugPrint('IvsVideoStore quality details: ${e.runtimeType}');
    }
    if (_disposed || url != _url) return;
    if (ladder == null) {
      _qualityLadderUrl = null;
      return;
    }
    final loaded = ladder;
    runInAction(() => _qualityLadder.value = loaded);
  }

  @override
  @action
  Future<void> handleRefresh() async {
    // The viewer's own way out: the guard may try jumping again, and auto
    // latency may try again after giving up. It plays the old source at
    // 1.0x while the new one is fetched (blind until it plays).
    _liveEdge.reset();
    if (playerConfig.autoLatency && !_rateRefused) _autoLatency.reset();
    _holdAutoLatency(AutoLatencyReason.reconnecting);
    _latency = null;
    _latencyMs = null;
    _lastLatencySecond = null;
    _isPlaying = false;
    _hasPlayed = false;
    _retryTimer?.cancel();
    _recoveryEpoch++;
    _recovering = false;
    _lastErrorRefused = false;
    _recovery.reset();
    _retryAttempt = 0;
    _status = IvsPlaybackStatus.loading;
    resetStats();
    _startupMs = null;
    _startupStopwatch
      ..reset()
      ..start();
    final epoch = _recoveryEpoch;
    try {
      // A manual refresh is the user's way out of a bad cached token.
      final url = await _streamService.getUsherUrl(
        userLogin: userLogin,
        authToken: _userAuthToken,
        forceFreshToken: true,
      );
      if (epoch != _recoveryEpoch) return;
      _url = url;
      await _loadSource(url, epoch);
      await updateStreamInfo(forceUpdate: true);
    } catch (e) {
      debugPrint('IvsVideoStore refresh failed: $e');
      // A newer refresh (or dispose) owns recovery now.
      if (epoch != _recoveryEpoch) return;
      _applyRecovery(
        _recovery.onError(
          isRetryableTokenError(e)
              ? IvsErrorKind.recoverable
              : IvsErrorKind.offline,
        ),
      );
    }
  }

  @override
  @action
  void handleVideoTap() {
    _overlayTimer?.cancel();
    if (_overlayVisible) {
      _overlayVisible = false;
    } else {
      _overlayVisible = true;
      unawaited(updateStreamInfo(forceUpdate: true));
      _scheduleOverlayHide();
    }
  }

  @override
  void handleToggleOverlay() {}

  Future<void> handleAppBackground() async {
    final trip = ++_backgroundTrip;
    bool stillAway() =>
        trip == _backgroundTrip && _wantsHeadphonesForBackground;
    if (!stillAway()) return;
    await Future<void>.delayed(backgroundPauseDelay);
    if (!stillAway()) return;
    final connected = await _audioFocus.headphonesConnected();
    if (connected == false && stillAway()) {
      handlePausePlay();
    }
  }

  bool get _wantsHeadphonesForBackground =>
      !_disposed &&
      !_paused &&
      !_isInPipMode &&
      !_autoPipArmed &&
      settingsStore.backgroundAudio &&
      settingsStore.backgroundAudioHeadphonesOnly;

  @override
  void handleAppResume() {
    _backgroundTrip++;
    // Playback may have stalled or been throttled in the background.
    _markDisturbed();
    _liveEdge.expedite();
    if (!settingsStore.showVideo) {
      unawaited(updateStreamInfo(forceUpdate: true));
    }
  }

  @override
  void requestPictureInPicture() {
    if (!_contentGate.value.allowsLeaving) return;
    if (Platform.isAndroid) pip.enterPipMode(autoEnter: true);
  }

  @override
  void togglePictureInPicture() => requestPictureInPicture();

  void _scheduleOverlayHide([Duration delay = const Duration(seconds: 5)]) {
    _overlayTimer?.cancel();
    _overlayTimer = Timer(
      delay,
      () => runInAction(() => _overlayVisible = false),
    );
  }

  @override
  void applyStreamPush(StreamPush push) {
    switch (push) {
      case ViewerCountPush() || BroadcastSettingsPush():
        runInAction(() => _streamInfo = patchStream(_streamInfo, push));
      case StreamUpPush():
        _onLiveChange(LiveChange.online);
      case StreamDownPush():
        unawaited(updateStreamInfo(forceUpdate: true));
    }
  }

  @action
  Future<void> updateStreamInfo({bool forceUpdate = false}) async {
    try {
      _streamInfo = await twitchApi.getStream(userLogin: userLogin);
      infoUnavailable = false;
      _offlineChannelInfo = null;
    } catch (e) {
      _streamInfo = null;
      _paused = true;
      try {
        _offlineChannelInfo = await twitchApi.getChannel(userId: userId);
        infoUnavailable = false;
      } catch (_) {
        _offlineChannelInfo = null;
        infoUnavailable = true;
      }
    }
  }

  @override
  @action
  void dispose() {
    _disposed = true;
    _rateWatchdog?.cancel();
    _recoveryEpoch++;
    _retryTimer?.cancel();
    _liveStartTimer?.cancel();
    _liveWatcher?.dispose();
    _disposeOfflinePoll?.call();
    _offlinePoll?.cancel();
    _overlayTimer?.cancel();
    _disposeAutoPipReaction?.call();
    captions.dispose();
    _disposeBackgroundAudioReaction?.call();
    unawaited(_backgroundAudio.hide(this));
    _disposeAudioFocusReaction?.call();
    unawaited(_audioFocus.abandon(this));
    if (Platform.isAndroid) pip.setAutoPipMode(autoEnter: false);
    final textureId = _textureId;
    if (textureId != null) {
      _textureManager.invokeMethod('dispose', {'textureId': textureId});
      _textureId = null;
    }
    _channel?.setMethodCallHandler(null);
    if (_ownsStreamService) _streamService.close();
  }
}

/// What the viewer is told when Twitch refuses [name]'s stream, in [l]'s
/// language.
String playbackRefusalNotice(
  PlaybackRefusal refusal,
  String name,
  AppLocalizations l,
) => switch (refusal) {
  PlaybackRefusal.subscribersOnly => l.liveRefusedSubscribersOnly(name: name),
  PlaybackRefusal.geoblocked => l.liveRefusedGeoblocked,
  PlaybackRefusal.bannedFromChannel => l.liveRefusedBanned(name: name),
  PlaybackRefusal.unauthorized => l.liveRefusedUnauthorized,
  PlaybackRefusal.proxyDetected => l.liveRefusedProxy,
  PlaybackRefusal.wifiRequired => l.liveRefusedWifiRequired,
  PlaybackRefusal.unsupportedDevice => l.liveRefusedUnsupportedDevice,
};

/// Why Twitch refused [name]'s stream: the [refusal] its token carried, or
/// else usher's own explanation ([usherReason], Twitch's English words).
@immutable
class StreamRefusalNotice {
  const StreamRefusalNotice({
    this.refusal,
    required this.name,
    this.usherReason,
  });

  final PlaybackRefusal? refusal;
  final String name;
  final String? usherReason;

  /// What the viewer is told, in [l]'s language. Usher's English words are
  /// shown on an English screen only; other languages say Twitch refused.
  String text(AppLocalizations l) {
    if (refusal case final refusal?) {
      return playbackRefusalNotice(refusal, name, l);
    }
    final reason = usherReason;
    if (reason == null || reason.trim().isEmpty || l.localeName != 'en') {
      return l.liveRefused;
    }
    return '${l.liveRefusedBecause(reason: reason)}'
        '${reason.endsWith('.') ? '' : '.'}';
  }

  @override
  bool operator ==(Object other) =>
      other is StreamRefusalNotice &&
      other.refusal == refusal &&
      other.name == name &&
      other.usherReason == usherReason;

  @override
  int get hashCode => Object.hash(refusal, name, usherReason);
}
