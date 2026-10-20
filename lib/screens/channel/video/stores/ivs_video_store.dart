import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:dio/dio.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:frosty/apis/base_api_client.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/apis/twitch_stream_service.dart';
import 'package:frosty/models/channel.dart';
import 'package:frosty/models/ivs_stats.dart';
import 'package:frosty/models/playback_access_token.dart';
import 'package:frosty/models/stream.dart';
import 'package:frosty/screens/channel/video/ivs_player_config.dart';
import 'package:frosty/screens/channel/video/ivs_recovery.dart';
import 'package:frosty/screens/channel/video/latency_stats.dart';
import 'package:frosty/screens/channel/video/live_edge_guard.dart';
import 'package:frosty/screens/channel/video/live_state_watcher.dart';
import 'package:frosty/screens/channel/video/player_controller.dart';
import 'package:frosty/screens/channel/video/quality_selection.dart';
import 'package:frosty/screens/channel/video/stores/caption_store.dart';
import 'package:frosty/screens/settings/stores/auth_store.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/services/audio_focus.dart';
import 'package:frosty/services/background_audio.dart';
import 'package:frosty/services/playback_token_cache.dart';
import 'package:frosty/services/realtime/twitch_eventsub_client.dart';
import 'package:mobx/mobx.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_pip_mode/simple_pip.dart';

part 'ivs_video_store.g.dart';

class IvsVideoStore = IvsVideoStoreBase with _$IvsVideoStore;

/// Playback lifecycle of the IVS engine, used for the loading spinner, the
/// reconnecting indicator and the fallback decision.
enum IvsPlaybackStatus { loading, playing, reconnecting, offline, failed }

/// Drives the native Amazon IVS player (the same engine the official Twitch
/// app uses) over a MethodChannel, exposing the shared [PlayerController]
/// surface so the existing overlay/channel can use it unchanged.
abstract class IvsVideoStoreBase with Store implements PlayerController {
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

  static const _textureManager = MethodChannel('frosty/ivs-texture-manager');

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
  /// that reason (the channel shows it on falling back); null otherwise.
  @readonly
  String? _refusalNotice;

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

  /// A paused live stream played again after this long resumes at the live
  /// edge (like a fresh start) instead of where it stopped: picking up a
  /// call-length pause where it left off would keep the picture that far
  /// behind the chat until the speed-up caught up, if ever.
  static const resumeAtLiveAfter = Duration(seconds: 3);

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
    BackgroundAudio? backgroundAudio,
    AudioFocus? audioFocus,
    @visibleForTesting DateTime Function()? now,
  }) : _ownsStreamService = streamService == null,
       _now = now ?? clock.now,
       _liveEdge = LiveEdgeGuard(now: now),
       _backgroundAudio = backgroundAudio ?? BackgroundAudio.shared,
       _audioFocus = audioFocus ?? AudioFocus.shared,
       _recovery = recoveryPolicy ?? IvsRecoveryPolicy(),
       playerConfig = IvsPlayerConfig.fromSettings(settingsStore),
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
    try {
      FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        reason: 'ivs $what',
      );
    } catch (_) {
      // Firebase may not be initialized (e.g., in tests).
    }
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
    if (settingsStore.showVideo && await SimplePip.isAutoPipAvailable) {
      pip.setAutoPipMode();
    } else {
      pip.setAutoPipMode(autoEnter: false);
    }
  }

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
          if (_paused && !_focusSuppressed) handlePausePlay();
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
        if (_paused && !_focusSuppressed) handlePausePlay();
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

  /// Keeps this stream silent while another player has focus: automatic
  /// playback after a load or a reconnect is paused again.
  void setFocusSuppressed(bool suppressed) => _focusSuppressed = suppressed;

  /// Applies the auto-PiP choice again, e.g. after a VOD screen on top of
  /// this stream turned auto-PiP off when it closed.
  void reassertAutoPip() {
    if (Platform.isAndroid) unawaited(_applyAutoPip());
  }

  /// Updates the picture-in-picture state when the OS enters/exits PiP.
  @action
  void onPipEntered() => _isInPipMode = true;

  @action
  void onPipExited() {
    _isInPipMode = false;
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
      _attachChannel('frosty/ivs-texture/$textureId');

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
    // Every load starts at the live edge.
    _liveEdge.onLoad();
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
          // Native auto-play after a (re)load while a VOD on top has focus.
          if (_focusSuppressed) _channel?.invokeMethod('pause');
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
        break;
      case 'latency':
        final ms = (e['ms'] as num?)?.toInt() ?? -1;
        // Before the first frame IVS has no live position, so the value is
        // meaningless (often 0): never show it nor feed it to the chat delay.
        if (ms < 0 || !_hasPlayed) break;
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
        // Paused, the latency grows a second a second while the picture
        // stands still: chat keeps the delay of the last moment played.
        if (!_isPlaying) break;
        // The chat delay keeps moving in whole seconds only, exactly as before,
        // so the delayed chat queue is not rebuilt on every tick.
        final seconds = chatDelaySecondsFromLatency(ms);
        if (seconds == _lastLatencySecond) break;
        _lastLatencySecond = seconds;
        if (settingsStore.autoSyncChatDelay) {
          settingsStore.syncedChatDelay = seconds.toDouble();
        }
        break;
      case 'rebuffering':
        _rebufferCount++;
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
    var notice = switch (_streamService.refusalFor(userLogin)) {
      final refusal? => playbackRefusalNotice(
        refusal,
        name == null || name.isEmpty ? userLogin : name,
      ),
      null => null,
    };
    final url = _url;
    if (notice == null && url != null) {
      String? reason;
      try {
        reason = await _streamService
            .usherRefusal(url)
            .timeout(const Duration(seconds: 4));
      } on TimeoutException catch (e) {
        // Only the explanation is lost: the player still gives up below.
        debugPrint('IvsVideoStore usher reason: $e');
      } catch (e, stack) {
        _reportUnexpected(e, stack, 'usher reason');
      }
      if (reason != null) {
        notice =
            'Twitch refused this stream: $reason'
            '${reason.endsWith('.') ? '' : '.'}';
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
      debugPrint('IvsVideoStore jump to live failed: $e');
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
      debugPrint('IvsVideoStore jump to live load failed: $e');
      if (!_disposed && epoch == _recoveryEpoch) {
        _applyRecovery(_recovery.onError(IvsErrorKind.recoverable));
      }
    } finally {
      _jumping = false;
    }
  }

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
    final quality =
        pickInitialQuality(
          available: available,
          defaultToHighest: false,
          lastQuality: session,
          keepAudioOnly: true,
        ) ??
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
    final index = _availableStreamQualities.indexOf(quality);
    if (index == -1) return;
    _streamQualityIndex = index;
    if (quality == 'Auto') {
      _channel?.invokeMethod('setAutoQuality');
    } else {
      _channel?.invokeMethod('setQuality', {'name': quality});
    }
  }

  @override
  Future<void> updateStreamQualities() async {
    // Qualities arrive via the 'qualities' event; nothing to refresh on demand.
  }

  @override
  @action
  Future<void> handleRefresh() async {
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

  @override
  void handleAppResume() {
    // Playback may have stalled or been throttled in the background.
    _liveEdge.expedite();
    if (!settingsStore.showVideo) {
      unawaited(updateStreamInfo(forceUpdate: true));
    }
  }

  @override
  void requestPictureInPicture() {
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

  @action
  Future<void> updateStreamInfo({bool forceUpdate = false}) async {
    try {
      _streamInfo = await twitchApi.getStream(userLogin: userLogin);
      _offlineChannelInfo = null;
    } catch (e) {
      _streamInfo = null;
      _paused = true;
      try {
        _offlineChannelInfo = await twitchApi.getChannel(userId: userId);
      } catch (_) {
        _offlineChannelInfo = null;
      }
    }
  }

  @override
  @action
  void dispose() {
    _disposed = true;
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

/// What the viewer is told when Twitch refuses [name]'s stream.
String playbackRefusalNotice(
  PlaybackRefusal refusal,
  String name,
) => switch (refusal) {
  PlaybackRefusal.subscribersOnly => '$name is streaming for subscribers only.',
  PlaybackRefusal.geoblocked => 'This stream is not available in your region.',
  PlaybackRefusal.bannedFromChannel => "You are banned from $name's channel.",
  PlaybackRefusal.unauthorized =>
    'Twitch refused this stream to the app player.',
};
