import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:mobx/mobx.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/apis/twitch_stream_service.dart';
import 'package:onset/models/channel.dart';
import 'package:onset/models/hls_variant.dart';
import 'package:onset/models/stream.dart';
import 'package:onset/models/stream_push.dart';
import 'package:onset/screens/channel/video/player_controller.dart';
import 'package:onset/screens/channel/video/quality_selection.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'native_video_store.g.dart';

class NativeVideoStore = NativeVideoStoreBase with _$NativeVideoStore;

/// Plays a Twitch stream with a native low-latency HLS player (media_kit /
/// libmpv) instead of the Twitch web embed, while exposing the same
/// [PlayerController] surface the overlay/channel expect.
abstract class NativeVideoStoreBase
    with Store
    implements PlayerController, StreamInfoStatus, StreamPushTarget {
  final String userLogin;
  final String userId;
  final TwitchApi twitchApi;
  final AuthStore authStore;

  @override
  final SettingsStore settingsStore;

  final TwitchStreamService _streamService;

  /// Whether this store created [_streamService] (and therefore owns its HTTP
  /// client and must close it on dispose).
  final bool _ownsStreamService;

  /// The native player. `bufferSize` is kept small to stay near the live edge.
  final Player player;

  late final VideoController videoController = VideoController(player);

  /// Ordered quality variants resolved from the HLS master playlist.
  List<HlsVariant> _variants = [];

  /// Completes once the stream is loaded (or throws if it could not be), so the
  /// channel screen can fall back to the WebView engine. Assigned in the
  /// constructor body so loading always starts.
  late final Future<void> ready;

  final List<StreamSubscription> _subscriptions = [];
  Timer? _overlayTimer;

  /// Last whole-second latency reported, to throttle badge/chat-sync updates.
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

  @override
  bool get isInPipMode => false; // OS handles PiP; no tracked state needed.

  @override
  String get streamQuality =>
      _availableStreamQualities.elementAtOrNull(_streamQualityIndex) ?? 'Auto';

  NativeVideoStoreBase({
    required this.userLogin,
    required this.userId,
    required this.twitchApi,
    required this.authStore,
    required this.settingsStore,
    TwitchStreamService? streamService,
    @visibleForTesting Player? nativePlayer,
  }) : player =
           nativePlayer ??
           Player(
             configuration: const PlayerConfiguration(
               bufferSize: 8 * 1024 * 1024,
             ),
           ),
       _ownsStreamService = streamService == null,
       _streamService = streamService ?? TwitchStreamService(Dio()) {
    // Same renewal hook as the IVS engine: a refused web token should mint a
    // replacement instead of silently downgrading playback.
    _streamService.onWebTokenRejected = authStore.renewTwitchWebToken;

    if (settingsStore.autoSyncChatDelay) settingsStore.syncedChatDelay = 0.0;

    _subscriptions.add(
      player.stream.playing.listen((playing) {
        runInAction(() => _paused = !playing);
        // Whatever started it (a resume after another player, the OS, a load
        // that was already starting), a covered stream does not play: held,
        // and started again only once the warning is accepted.
        if (playing && _covered) {
          _heldForContentGate = true;
          unawaited(player.pause());
        }
      }),
    );

    // Estimate distance-from-live (live edge minus current position) to drive
    // the latency badge and optional chat-delay sync. This is approximate;
    // updates are throttled to whole-second changes to avoid churn.
    _subscriptions.add(
      player.stream.position.listen((position) {
        final liveEdge = player.state.duration.inMilliseconds;
        final behindMs = liveEdge - position.inMilliseconds;
        if (liveEdge <= 0 || behindMs <= 0) return;

        final seconds = (behindMs / 1000).clamp(0, 60).round();
        if (seconds == _lastLatencySecond) return;
        _lastLatencySecond = seconds;

        runInAction(() {
          _latency = '${seconds}s';
          if (settingsStore.autoSyncChatDelay) {
            settingsStore.syncedChatDelay = seconds.toDouble();
          }
        });
      }),
    );

    // Start loading. Assigning here (not as a lazy field initializer) ensures
    // playback begins even if nobody reads [ready].
    ready = _init();

    unawaited(updateStreamInfo());
    _scheduleOverlayHide();
  }

  /// Applies low-latency tuning, then loads the stream — in that order so the
  /// first `player.open()` already has the low-latency properties applied.
  Future<void> _init() async {
    await _configureLowLatency();
    await _load();
  }

  Future<void> _configureLowLatency() async {
    final native = player.platform;
    if (native is NativePlayer) {
      // libmpv low-latency live tuning (see mpv property docs). Favours
      // minimal delay over rebuffering resilience, per the project goal.
      await native.setProperty('cache', 'no');
      await native.setProperty('demuxer-readahead-secs', '0');
      await native.setProperty('demuxer-lavf-o', 'live=1');
      await native.setProperty('video-sync', 'display-resample');
      if (Platform.isAndroid) {
        await native.setProperty('hwdec', 'mediacodec-copy');
      }
    }
  }

  @action
  Future<void> _load() async {
    _variants = await _streamService.getStreamVariants(
      userLogin: userLogin,
      // Only the twitch.tv web token: GQL refuses the app's own login token.
      authToken: authStore.twitchWebToken,
    );
    _availableStreamQualities = _variants.map((v) => v.name).toList();
    if (_variants.isEmpty) {
      throw StateError('No stream variants for $userLogin');
    }

    final prefs = await SharedPreferences.getInstance();
    _streamQualityIndex = _initialQualityIndex(
      prefs.getString('last_stream_quality'),
    );

    // A covered stream opens paused: the content warning holds it.
    await player.open(
      Media(_variants[_streamQualityIndex].url),
      play: !_covered,
    );
    if (_covered) {
      // Covered while it opened: held all the same.
      _heldForContentGate = true;
      await player.pause();
    } else {
      await player.play();
    }
  }

  /// Picks the starting variant, honouring the same preferences the WebView
  /// engine uses: highest quality, or the last-used quality. Index 0 is the
  /// Twitch source (highest) variant.
  int _initialQualityIndex(String? lastQuality) {
    // Same rules as IVS (a saved audio only is not restored); index 0 when
    // nothing matches.
    if (settingsStore.defaultToHighestQuality) return 0;
    final name = pickInitialQuality(
      available: [for (final variant in _variants) variant.name],
      defaultToHighest: false,
      lastQuality: lastQuality,
    );
    final index = name == null
        ? -1
        : _variants.indexWhere((v) => v.name == name);
    return index == -1 ? 0 : index;
  }

  @override
  @action
  void setStreamQuality(String quality) {
    final index = _availableStreamQualities.indexOf(quality);
    if (index == -1) return;
    _streamQualityIndex = index;
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setString('last_stream_quality', quality),
    );
    player.open(Media(_variants[index].url), play: !_covered);
    if (_covered) {
      _heldForContentGate = true;
    } else {
      player.play();
    }
  }

  @override
  Future<void> updateStreamQualities() async {
    // Variants are resolved once at load; nothing to refresh on demand.
  }

  @override
  void handlePausePlay() {
    // A resume while covered is remembered, not played (the warning is up).
    if (_covered && !player.state.playing) {
      _heldForContentGate = true;
      return;
    }
    unawaited(player.playOrPause());
  }

  @override
  @action
  Future<void> handleRefresh() async {
    _latency = null;
    _lastLatencySecond = null;
    try {
      await _load();
      await updateStreamInfo(forceUpdate: true);
    } catch (e) {
      debugPrint('NativeVideoStore refresh failed: $e');
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
  void handleToggleOverlay() {
    // Native engine always uses the custom overlay; nothing to toggle.
  }

  @override
  void handleAppResume() {
    if (!settingsStore.showVideo) unawaited(updateStreamInfo(forceUpdate: true));
  }

  @override
  void requestPictureInPicture() {
    // OS-level PiP for the native surface is a later iteration.
  }

  @override
  void togglePictureInPicture() => requestPictureInPicture();

  /// Where the mature-content warning stands (this engine has no
  /// picture-in-picture: only playback is held).
  var _contentGate = ContentGate.clear;

  /// True when the warning paused the stream (or opened it paused), so
  /// clearing it resumes only that.
  var _heldForContentGate = false;

  bool get _covered => _contentGate == ContentGate.covering;

  @override
  ContentGate get contentGate => _contentGate;

  @override
  void setContentGate(ContentGate gate) {
    if (gate == _contentGate) return;
    _contentGate = gate;
    if (gate == ContentGate.covering) {
      // An explicit pause: a toggle would start a stream not playing yet.
      if (player.state.playing) {
        _heldForContentGate = true;
        unawaited(player.pause());
      }
    } else if (gate == ContentGate.clear && _heldForContentGate) {
      _heldForContentGate = false;
      unawaited(_reopenAtLiveEdge());
    }
  }

  /// Re-opens the stream rather than resuming it: a stream held while the
  /// warning was up would otherwise start as far behind live as the time
  /// spent reading it.
  Future<void> _reopenAtLiveEdge() async {
    runInAction(() => _latency = null);
    _lastLatencySecond = null;
    try {
      await _load();
    } catch (e) {
      debugPrint('NativeVideoStore re-open after the warning failed: $e');
      // Behind live beats not playing at all.
      if (!_covered) unawaited(player.play());
    }
  }

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
      case StreamUpPush() || StreamDownPush():
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
      // Stream is offline (or the request failed): reflect a non-playing state
      // so gestures gated on `paused` behave like the WebView engine.
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
    _overlayTimer?.cancel();
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    player.dispose();
    if (_ownsStreamService) _streamService.close();
  }
}
