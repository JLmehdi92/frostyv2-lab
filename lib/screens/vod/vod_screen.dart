import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart';
import 'package:onset/apis/twitch_vod_service.dart';
import 'package:onset/models/vod.dart';
import 'package:onset/screens/channel/chat/stores/chat_assets_store.dart';
import 'package:onset/screens/channel/video/content_warning_gate.dart';
import 'package:onset/screens/channel/video/live_progress.dart';
import 'package:onset/screens/channel/video/player_engine_resolver.dart';
import 'package:onset/screens/channel/video/web_content_gate.dart';
import 'package:onset/screens/home/stream_list/stream_card_parts.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/vod/player_media.dart';
import 'package:onset/screens/vod/stores/ivs_vod_store.dart';
import 'package:onset/screens/vod/stores/up_next_store.dart';
import 'package:onset/screens/vod/stores/vod_chat_replay_store.dart';
import 'package:onset/screens/vod/stores/web_vod_store.dart';
import 'package:onset/screens/vod/vod_overlay.dart';
import 'package:onset/screens/vod/vod_player_controller.dart';
import 'package:onset/screens/vod/vod_resume.dart';
import 'package:onset/screens/vod/widgets/up_next_overlay.dart';
import 'package:onset/screens/vod/widgets/video_back_button.dart';
import 'package:onset/screens/vod/widgets/vod_chat_replay.dart';
import 'package:onset/screens/vod/widgets/vod_details_panel.dart';
import 'package:onset/screens/vod/widgets/vod_error_view.dart';
import 'package:onset/screens/vod/widgets/vod_info_strip.dart';
import 'package:onset/screens/vod/widgets/vod_video.dart';
import 'package:onset/services/network_metering.dart';
import 'package:onset/services/playback_focus.dart';
import 'package:onset/stores/mini_player_store.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/content_labels.dart';
import 'package:onset/utils/context_extensions.dart';
import 'package:onset/utils/pip_callbacks.dart';
import 'package:onset/widgets/draggable_divider.dart';
import 'package:simple_pip_mode/actions/pip_actions_layout.dart';
import 'package:simple_pip_mode/pip_widget.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Builds the player for a VOD (tests pass a fake).
typedef VodPlayerFactory =
    VodPlayerController Function(Vod vod, Duration? startAt);

/// Builds the chat replay for a VOD (tests pass a fake).
typedef VodReplayFactory = VodChatReplayStore Function(Vod vod);

/// The chat replay of [vod], with the channel's emotes and the viewer's
/// blocks (used by the VOD and clip screens).
VodChatReplayStore createVodChatReplay(BuildContext context, Vod vod) {
  final auth = context.authStore;
  return VodChatReplayStore(
    vod: vod,
    vodService: context.twitchVodService,
    assetsStore: ChatAssetsStore(
      twitchApi: context.twitchApi,
      ffzApi: context.ffzApi,
      bttvApi: context.bttvApi,
      sevenTVApi: context.sevenTVApi,
      globalAssetsStore: context.globalAssetsStore,
    ),
    settings: context.settingsStore,
    headers: auth.headersTwitch,
    viewerLogin: auth.user.details?.login,
    blockedLogins: () =>
        auth.user.blockedUsers.map((u) => u.userLogin).toList(),
  );
}

/// Watches a past broadcast, highlight or upload inside the app, like the
/// official app: native player, seek, speed, and the chat replayed in step
/// with the video (with 7TV/BTTV/FFZ emotes).
class VodScreen extends StatefulWidget {
  static const routeName = 'VodScreen';

  const VodScreen({
    super.key,
    required this.vodId,
    this.vod,
    this.startAt,
    @visibleForTesting this.playerFactory,
    @visibleForTesting this.replayFactory,
  });

  /// Numeric id, with or without the `v` prefix.
  final String vodId;

  /// Known metadata (from a list); fetched when null.
  final Vod? vod;

  /// Where to start (a `?t=` link, a resume point).
  final Duration? startAt;

  final VodPlayerFactory? playerFactory;
  final VodReplayFactory? replayFactory;

  static Future<void> open(
    BuildContext context, {
    required String vodId,
    Vod? vod,
    Duration? startAt,
  }) => Navigator.push(
    context,
    MaterialPageRoute(
      settings: const RouteSettings(name: routeName),
      builder: (context) => VodScreen(vodId: vodId, vod: vod, startAt: startAt),
    ),
  );

  @override
  State<VodScreen> createState() => _VodScreenState();
}

class _VodScreenState extends State<VodScreen> with WidgetsBindingObserver {
  late final SettingsStore _settings = context.settingsStore;
  late final TwitchVodService _service = context.twitchVodService;
  late final MiniPlayerStore _miniPlayer = context.miniPlayerStore;

  final _pipKey = GlobalKey<PipWidgetState>();

  /// One video widget moved between the portrait, landscape and PiP trees,
  /// so its platform view (WebView) is never recreated.
  final _videoKey = GlobalKey();
  final _resumeRepository = VodResumeRepository.shared;
  VodResumeController? _resume;

  Vod? _vod;

  /// The metadata could not be loaded (null while loading or loaded).
  String? _loadError;

  /// The current player, observable: it is replaced (after the content
  /// warning, a fallback to the web engine, a retry) and what follows it,
  /// such as the resume saver, must follow the new one.
  final _currentPlayer = Observable<VodPlayerController?>(null);

  VodPlayerController? get _player => _currentPlayer.value;

  set _player(VodPlayerController? player) =>
      runInAction(() => _currentPlayer.value = player);
  VodChatReplayStore? _replay;

  /// What plays next at the end (null until the video is known, and for a
  /// broadcast still recording: its end is only the live edge).
  UpNextStore? _upNext;

  /// The labels of a mature-content warning waiting for the viewer (null
  /// when none). Like the official app, nothing plays until they accept:
  /// the player is only built then, at [_gatedStart].
  List<String>? _warningLabels;
  Duration? _gatedStart;

  /// The viewer accepted this video's warning.
  var _warningAccepted = false;

  /// How long the labels may take before the video plays without them.
  static const _labelsTimeout = Duration(seconds: 3);

  /// How long the account's watch position may take before the video
  /// starts without it.
  static const _historyTimeout = Duration(seconds: 3);
  var _mutedSegments = const <MutedSegment>[];

  /// A tablet's side chat in the dark theme.
  static const _tabletChatColor = Color(0xFF0D0D0D);
  var _fillScreen = false;
  var _forceWeb = false;
  var _isDividerDragging = false;
  bool? _immersive;

  final _disposers = <ReactionDisposer>[];

  /// Whether the video was playing when another player took focus.
  var _playingBeforeFocusLoss = false;

  bool get _hasFocus => identical(PlaybackFocus.shared.top, this);

  @override
  void initState() {
    super.initState();
    // One player at a time: the mini player closes and a live stream
    // beneath pauses until this screen closes.
    _miniPlayer.close();
    PlaybackFocus.shared
      ..register(this, onLost: _onFocusLost, onRegained: _onFocusRegained)
      ..claim(this);
    if (_settings.keepScreenAwake) WakelockPlus.enable();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadMetadata());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) unawaited(_resume?.save());
  }

  Future<void> _loadMetadata() async {
    var vod = widget.vod;
    if (vod == null) {
      try {
        vod = await _service.getVideo(widget.vodId);
      } catch (e) {
        debugPrint('VodScreen metadata failed: $e');
        if (mounted) setState(() => _loadError = "Couldn't load this video");
        return;
      }
      if (vod == null) {
        if (mounted) {
          setState(() => _loadError = 'This video is no longer available');
        }
        return;
      }
    }
    // The native player's token is asked meanwhile (cached for it), so
    // waiting for the labels does not delay the start.
    if (widget.playerFactory == null && _engine == PlayerEngine.ivs) {
      unawaited(_service.preloadToken(vod.id));
    }
    final warning = _contentWarningLabels(vod);
    // A `?t=` link wins; otherwise resume where the viewer left the video
    // (here, on their account) or the live broadcast it recorded.
    final viewer = _service.viewerId?.call();
    final resume = widget.startAt == null;
    final server = resume ? _accountPosition(vod) : null;
    final live = resume
        ? LiveProgressRepository.shared.forVod(vod, viewer: viewer).catchError((
            Object e,
          ) {
            debugPrint('VodScreen live position failed: ${e.runtimeType}');
            return null;
          })
        : null;
    final saved = resume
        ? await _resumeRepository.entry(vod.id, viewer: viewer)
        : null;
    final labels = await warning;
    final startAt = startPositionFor(
      saved: saved,
      deepLink: widget.startAt,
      server: await server,
      live: await live,
      lengthSec: vod.lengthSeconds,
      // A recording keeps growing: its end is not where the viewer stops.
      nearEndRestarts: !vod.isRecording,
    );
    if (!mounted) return;
    final loaded = vod;
    setState(() {
      _loadError = null;
      _vod = loaded;
      _replay = _buildReplay(loaded);
      _upNext = loaded.isRecording ? null : _buildUpNext(loaded);
      if (labels.isEmpty) {
        _player = _buildPlayer(loaded, startAt: startAt);
      } else {
        _warningLabels = labels;
        _gatedStart = startAt;
      }
    });
    _bindReplay();
    _resume = VodResumeController(
      vodId: loaded.id,
      player: () => _player,
      repository: _resumeRepository,
      viewer: () => _service.viewerId?.call(),
      recording: loaded.isRecording,
      report: (positionSec) => _service.updateViewedVideo(
        videoId: loaded.id,
        type: WatchedVideoType.vod,
        positionSec: positionSec,
      ),
      fallbackLengthSec: loaded.lengthSeconds,
    )..start();
    unawaited(
      _service.getMutedSegments(loaded.id).then((segments) {
        if (mounted) setState(() => _mutedSegments = segments);
      }),
    );
  }

  /// Where the viewer's Twitch account left [vod] (null when logged out,
  /// unknown, or too slow to wait for).
  Future<ViewingHistory?> _accountPosition(Vod vod) async {
    try {
      return await _service
          .getViewingHistory(vod.id)
          .timeout(_historyTimeout, onTimeout: () => null);
    } catch (e) {
      debugPrint('VodScreen watch position failed: ${e.runtimeType}');
      return null;
    }
  }

  /// The video's own labels to warn about, like the official app (not the
  /// channel's current ones); empty when the setting is off, the viewer
  /// already accepted this channel's warning, or the labels cannot be had
  /// in time (fail open).
  Future<List<String>> _contentWarningLabels(Vod vod) async {
    if (!_settings.warnMatureContent ||
        (vod.ownerId.isNotEmpty && AcceptedContentWarnings.has(vod.ownerId))) {
      return const [];
    }
    try {
      final ids = await _service
          .getContentLabels(vod.id)
          .timeout(_labelsTimeout);
      return contentLabelNames(ids);
    } catch (e) {
      debugPrint('VodScreen content labels failed: ${e.runtimeType}');
      return const [];
    }
  }

  /// Whether Twitch's own warning in the web player may be clicked for the
  /// viewer: only when they accepted ours (now or earlier for this channel)
  /// or turned warnings off. Otherwise they tap it themselves.
  bool _webGateConsent(Vod vod) =>
      !_settings.warnMatureContent ||
      _warningAccepted ||
      (vod.ownerId.isNotEmpty && AcceptedContentWarnings.has(vod.ownerId));

  void _acceptContentWarning() {
    final vod = _vod;
    if (vod == null || _warningLabels == null) return;
    _warningAccepted = true;
    if (vod.ownerId.isNotEmpty) AcceptedContentWarnings.add(vod.ownerId);
    setState(() {
      _warningLabels = null;
      _player = _buildPlayer(vod, startAt: _gatedStart);
    });
    _bindReplay();
  }

  UpNextStore _buildUpNext(Vod vod) => UpNextStore(
    current: vod,
    channelVideos: () async => vod.ownerLogin.isEmpty
        ? const <Vod>[]
        : (await _service.getChannelVideos(login: vod.ownerLogin)).items,
    similarVideos: (gameId) async =>
        (await _service.getCategoryVideos(gameId)).items,
    savedPositions: () =>
        _resumeRepository.snapshot(viewer: _service.viewerId?.call()),
    autoplay: () => _settings.vodAutoplay,
    isMetered: NetworkMetering.shared.isMetered,
    onPlay: _playNext,
    isVisible: _isCurrentRoute,
  );

  /// Nothing (a category page, a sheet, a channel) covers this screen.
  bool _isCurrentRoute() =>
      mounted && (ModalRoute.of(context)?.isCurrent ?? true);

  /// Replaces this video with [next], so videos never pile up on the stack
  /// (the closing save marks this one watched).
  void _playNext(Vod next) {
    // Only this screen is ever replaced, never one covering it.
    if (!_isCurrentRoute()) {
      _upNext?.reset();
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: VodScreen.routeName),
        builder: (context) => VodScreen(
          vodId: next.id,
          vod: next,
          playerFactory: widget.playerFactory,
          replayFactory: widget.replayFactory,
        ),
      ),
    );
  }

  void _retryMetadata() {
    setState(() => _loadError = null);
    unawaited(_loadMetadata());
  }

  VodChatReplayStore _buildReplay(Vod vod) {
    final factory = widget.replayFactory;
    if (factory != null) return factory(vod);
    return createVodChatReplay(context, vod);
  }

  /// The native IVS player, or the Twitch embed in a WebView when this
  /// platform or setting needs it, or after the native player failed.
  VodPlayerController _buildPlayer(Vod vod, {Duration? startAt}) {
    final player = _createPlayer(vod, startAt: startAt);
    // A player built while another one is on top must stay silent.
    if (!_hasFocus) player.setFocused(false);
    return player;
  }

  PlayerEngine get _engine => resolvePlayerEngine(
    setting: _settings.playerEngine,
    isAndroid: Platform.isAndroid,
    forceWeb: _forceWeb,
  );

  VodPlayerController _createPlayer(Vod vod, {Duration? startAt}) {
    final factory = widget.playerFactory;
    if (factory != null) return factory(vod, startAt);
    if (_engine != PlayerEngine.ivs) {
      return WebVodStore(
        vodId: vod.id,
        startAt: startAt ?? Duration.zero,
        knownLength: Duration(seconds: vod.lengthSeconds),
        acceptContentGate: _webGateConsent(vod),
      );
    }
    final store = IvsVodStore(
      vodId: vod.id,
      vodService: _service,
      settingsStore: _settings,
      startAt: startAt ?? Duration.zero,
      knownLength: Duration(seconds: vod.lengthSeconds),
    );
    void fallback() {
      if (!mounted || !identical(_player, store)) return;
      unawaited(_switchPlayer(forceWeb: true));
    }

    store.onFatalError = fallback;
    store.ready.catchError((Object _) => fallback());
    return store;
  }

  /// Keeps the chat replay in step with the player.
  void _bindReplay() {
    for (final dispose in _disposers) {
      dispose();
    }
    _disposers.clear();
    final player = _player;
    final replay = _replay;
    if (player == null || replay == null) return;
    _disposers
      ..add(
        reaction(
          (_) => player.positionSeconds,
          replay.onPositionSecond,
          fireImmediately: true,
        ),
      )
      ..add(
        reaction(
          (_) => player.playbackRate,
          (double rate) => replay.playbackRate = rate,
          fireImmediately: true,
        ),
      )
      ..add(
        // The viewer pressed play while a channel plays in the mini
        // player: one player at a time, so the mini player closes and PiP
        // comes back to this screen.
        reaction((_) => player.paused, (bool paused) {
          if (paused || !_miniPlayer.visible) return;
          _miniPlayer.close();
          reclaimPipCallbacks(_pipKey);
        }),
      );
    final upNext = _upNext;
    if (upNext == null) return;
    _disposers
      ..add(
        // The end offers what comes next; playing again (a replay, a
        // seek back) takes the offer away until the next end.
        reaction((_) => player.ended, (bool ended) {
          if (ended) {
            unawaited(upNext.onEnded());
          } else {
            upNext.reset();
          }
        }, fireImmediately: true),
      )
      ..add(
        // In picture-in-picture the card cannot be seen: no countdown.
        reaction((_) => player.isInPipMode, upNext.hold, fireImmediately: true),
      );
  }

  /// Rebuilds the player where the old one was (a retry, or the web engine
  /// after the native one failed).
  Future<void> _switchPlayer({bool forceWeb = false}) async {
    final vod = _vod;
    final old = _player;
    if (vod == null) return;
    final at = await old?.currentPositionForSave() ?? widget.startAt;
    if (!mounted || !identical(old, _player)) return;
    setState(() {
      _forceWeb = _forceWeb || forceWeb;
      old?.dispose();
      _player = _buildPlayer(vod, startAt: at);
    });
    _bindReplay();
  }

  void _onFocusLost() {
    _upNext?.hold(true, reason: UpNextHold.focus);
    final player = _player;
    if (player == null) return;
    player.setFocused(false);
    // A player still loading would start on its own: treat it as playing.
    _playingBeforeFocusLoss =
        !player.paused || player.status == VodPlaybackStatus.loading;
    if (!player.paused) player.pause();
  }

  void _onFocusRegained() {
    // Runs after the frame: the screen above may be closing together with
    // this one (popUntil), and must finish disposing first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _upNext?.hold(false, reason: UpNextHold.focus);
      final player = _player;
      // A channel handed to the mini player keeps playing and keeps PiP:
      // stay paused and unfocused until the viewer presses play.
      if (!_miniPlayer.visible) {
        player?.setFocused(true);
        if (_playingBeforeFocusLoss) player?.play();
        reclaimPipCallbacks(_pipKey);
      }
      _playingBeforeFocusLoss = false;
      if (_settings.keepScreenAwake) WakelockPlus.enable();
      // The screen that closed reset the system bars.
      setState(() => _immersive = null);
    });
  }

  /// Double-tap in landscape, like live: overlay → side column → hidden.
  void _cycleLandscapeChatMode() {
    HapticFeedback.lightImpact();
    if (!_settings.fullScreen) {
      _settings
        ..fullScreen = true
        ..fullScreenChatOverlay = false;
    } else if (_settings.fullScreenChatOverlay) {
      _settings.fullScreen = false;
    } else {
      _settings.fullScreenChatOverlay = true;
    }
  }

  void _syncSystemUi({required bool immersive}) {
    if (_immersive == immersive) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _immersive == immersive) return;
      _immersive = immersive;
      if (immersive) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.manual,
          overlays: SystemUiOverlay.values,
        );
      }
    });
  }

  Widget _buildVideo() {
    final player = _player;
    final Widget video;
    if (player is IvsVodStore) {
      video = VodVideo(store: player, fillScreen: _fillScreen);
    } else if (player is WebVodStore) {
      video = ColoredBox(
        color: Colors.black,
        child: WebViewWidget(controller: player.webViewController),
      );
    } else {
      video = const ColoredBox(color: Colors.black);
    }
    return KeyedSubtree(key: _videoKey, child: video);
  }

  /// Black area with a back button, for when there is no player yet.
  Widget _withBackButton(Widget child) => VideoBackButtonLayer(child: child);

  Widget _buildPlayerArea({required bool landscape, required bool hasChat}) {
    final player = _player;
    final vod = _vod;
    final warning = _warningLabels;
    if (vod != null && warning != null) {
      return ContentWarningCover(
        displayName: vod.ownerDisplayName.isNotEmpty
            ? vod.ownerDisplayName
            : vod.ownerLogin,
        labels: warning,
        onAccept: _acceptContentWarning,
      );
    }
    if (vod == null || player == null) {
      final error = _loadError;
      return _withBackButton(
        error == null
            ? ColoredBox(
                color: Colors.black,
                child: Center(
                  child: CircularProgressIndicator(
                    color: context.onsetColors.live,
                  ),
                ),
              )
            : VodErrorView(
                problem: error == 'This video is no longer available'
                    ? VodPlaybackProblem.notFound
                    : VodPlaybackProblem.unknown,
                onRetry: _retryMetadata,
              ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildVideo(),
        Observer(
          builder: (context) {
            final problem = player.problem;
            if (player case WebPagePlayer(webGateVisible: true)) {
              // Twitch's own warning is up in the page: only a back button
              // of ours, so its buttons get the taps.
              return _withBackButton(const SizedBox.shrink());
            }
            if (player.status == VodPlaybackStatus.problem && problem != null) {
              return _withBackButton(
                VodErrorView(
                  problem: problem,
                  onRetry: () => unawaited(_switchPlayer()),
                ),
              );
            }
            return VodOverlay(
              controller: player,
              media: PlayerMedia.vod(vod),
              settings: _settings,
              mutedSegments: _mutedSegments,
              fillScreen: player is IvsVodStore ? _fillScreen : null,
              onToggleFillScreen: player is IvsVodStore
                  ? () => setState(() => _fillScreen = !_fillScreen)
                  : null,
              showChatOverlayButton:
                  landscape && hasChat && _settings.fullScreen,
              onCycleChatMode: landscape && hasChat
                  ? _cycleLandscapeChatMode
                  : null,
              isLandscape: landscape,
            );
          },
        ),
        if (_upNext case final upNext?) UpNextOverlay(store: upNext),
      ],
    );
  }

  Widget _buildChat({bool header = true, bool large = false}) {
    final replay = _replay;
    if (replay == null) {
      return _loadError == null
          ? const ReplayLoading()
          : const SizedBox.shrink();
    }
    return VodChatReplay(store: replay, showHeader: header, large: large);
  }

  /// A tablet's details: under a portrait video
  /// above the chat, or under a landscape video beside it.
  Widget _details(Vod vod, {required bool legend}) => Observer(
    builder: (context) => VodDetailsPanel(
      vod: vod,
      // Followed so the pills follow the player after a fallback.
      player: _currentPlayer.value,
      settings: _settings,
      mutedSegments: _mutedSegments,
      upNext: _upNext != null,
      legend: legend,
    ),
  );

  Widget _buildPortrait() {
    final vod = _vod;
    final tablet = context.isLargeScreen;
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: _buildPlayerArea(landscape: false, hasChat: true),
          ),
          if (vod != null)
            tablet
                // At most a third of the room (it scrolls): the chat keeps
                // its place with large text.
                ? Flexible(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: FeedColors.of(context).hairline,
                            width: OnsetTokens.hairlineWidth,
                          ),
                        ),
                      ),
                      child: _details(vod, legend: false),
                    ),
                  )
                : VodInfoStrip(vod: vod),
          Expanded(
            flex: 2,
            child: SafeArea(top: false, child: _buildChat(large: tablet)),
          ),
        ],
      ),
    );
  }

  /// Below a tablet's video beside its chat, the details keep at least
  /// this much room.
  static const _minTabletDetailsHeight = 120.0;

  /// A tablet beside its chat: the 16:9 video at the
  /// top, the details under it.
  Widget _buildTabletVideoColumn(Widget video) {
    final vod = _vod;
    return LayoutBuilder(
      builder: (context, constraints) {
        final videoHeight = math.min(
          constraints.maxWidth * 9 / 16,
          math.max(0.0, constraints.maxHeight - _minTabletDetailsHeight),
        );
        return ColoredBox(
          color: context.scaffoldColor,
          child: Column(
            children: [
              SizedBox(
                height: videoHeight,
                width: double.infinity,
                child: ColoredBox(color: Colors.black, child: video),
              ),
              Expanded(
                child: vod == null
                    ? const SizedBox.shrink()
                    : _details(vod, legend: true),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLandscape() {
    return Observer(
      builder: (context) {
        // Every observable the layout depends on is read here, not inside
        // the LayoutBuilders below (they build during layout, untracked).
        final replay = _replay;
        final hasChat =
            replay != null &&
            replay.status != ReplayStatus.unavailable &&
            replay.status != ReplayStatus.notApplicable;
        final fullScreen = _settings.fullScreen;
        final overlayChatShown = _settings.fullScreenChatOverlay;
        final overlayOpacity = _settings.fullScreenChatOverlayOpacity;
        final chatWidth = _settings.chatWidth;
        final leftSide = _settings.landscapeChatLeftSide;
        final cutout = _settings.landscapeCutout;

        final playerArea = _buildPlayerArea(landscape: true, hasChat: hasChat);
        final tablet = context.isLargeScreen;
        if (!hasChat) {
          // An upload (no chat) on a tablet keeps its details under it.
          if (tablet && !fullScreen) {
            return SafeArea(
              bottom: false,
              child: _buildTabletVideoColumn(playerArea),
            );
          }
          return ColoredBox(color: Colors.black, child: playerArea);
        }

        Widget divider(double totalWidth) => Positioned(
          top: 0,
          bottom: 0,
          left: leftSide ? totalWidth * chatWidth - 12 : null,
          right: leftSide ? null : totalWidth * chatWidth - 12,
          child: Observer(
            builder: (context) => DraggableDivider(
              currentWidth: chatWidth,
              maxWidth: 0.6,
              isResizableOnLeft: leftSide,
              showHandle: _player?.overlayVisible ?? true,
              onDragStart: () => setState(() => _isDividerDragging = true),
              onDrag: (width) => _settings.chatWidth = width,
              onDragEnd: () => setState(() => _isDividerDragging = false),
            ),
          ),
        );

        // A tablet puts the details under the video and a header on its chat.
        final dark = Theme.of(context).brightness == Brightness.dark;
        final hairline = BorderSide(
          color: FeedColors.of(context).hairline,
          width: OnsetTokens.hairlineWidth,
        );

        Widget chatPanel(double totalWidth, {required bool overlay}) =>
            AnimatedContainer(
              curve: Curves.ease,
              duration: _isDividerDragging
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              width: totalWidth * chatWidth,
              decoration: BoxDecoration(
                color: overlay
                    ? Colors.black.withValues(alpha: overlayOpacity)
                    : tablet && dark
                    ? _tabletChatColor
                    : context.scaffoldColor,
                border: overlay || !tablet
                    ? null
                    : Border(
                        left: leftSide ? BorderSide.none : hairline,
                        right: leftSide ? hairline : BorderSide.none,
                      ),
              ),
              child: SafeArea(
                left: leftSide,
                right: !leftSide,
                child: _buildChat(header: !overlay, large: tablet && !overlay),
              ),
            );

        if (fullScreen) {
          final overlayTheme = OnsetThemes(
            colorSchemeSeed: Color(_settings.accentColor),
          ).dark;
          final onOverlay =
              Theme.of(context).extension<OnsetColors>()?.overlayOnSurface ??
              Colors.white;
          return ColoredBox(
            color: Colors.black,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                return Stack(
                  children: [
                    Positioned.fill(child: playerArea),
                    Align(
                      alignment: leftSide
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      child: Visibility(
                        visible: overlayChatShown,
                        maintainState: true,
                        child: Theme(
                          data: overlayTheme,
                          child: DefaultTextStyle(
                            style: context.defaultTextStyle.copyWith(
                              color: onOverlay,
                            ),
                            child: chatPanel(width, overlay: true),
                          ),
                        ),
                      ),
                    ),
                    if (overlayChatShown) divider(width),
                  ],
                );
              },
            ),
          );
        }

        return ColoredBox(
          color: Colors.black,
          child: SafeArea(
            bottom: false,
            left:
                cutout != LandscapeCutoutType.left &&
                cutout != LandscapeCutoutType.both,
            right:
                cutout != LandscapeCutoutType.right &&
                cutout != LandscapeCutoutType.both,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final video = Expanded(
                  child: tablet
                      ? _buildTabletVideoColumn(playerArea)
                      : playerArea,
                );
                final chat = chatPanel(width, overlay: false);
                return Stack(
                  children: [
                    Row(children: leftSide ? [chat, video] : [video, chat]),
                    divider(width),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final landscape =
        context.isLandscape && !_settings.landscapeForceVerticalChat;
    _syncSystemUi(immersive: landscape);

    final theme = Theme.of(context);
    // No app bar to set the system bars: the theme's in portrait, light
    // icons over the black of landscape.
    final page = AnnotatedRegion<SystemUiOverlayStyle>(
      value: landscape
          ? SystemUiOverlayStyle.light
          : theme.appBarTheme.systemOverlayStyle ??
                (theme.brightness == Brightness.dark
                    ? SystemUiOverlayStyle.light
                    : SystemUiOverlayStyle.dark),
      child: Scaffold(
        backgroundColor: landscape ? Colors.black : null,
        body: landscape ? _buildLandscape() : _buildPortrait(),
      ),
    );

    if (!Platform.isAndroid) return page;
    // Always present (keyed) so the page never remounts when the player
    // appears, and so PiP events can be pointed back at it.
    return PipWidget(
      key: _pipKey,
      pipLayout: PipActionsLayout.mediaOnlyPause,
      onPipAction: (_) => _player?.togglePlay(),
      onPipEntered: () => _player?.onPipEntered(),
      onPipExited: () => _player?.onPipExited(),
      pipChild: _buildVideo(),
      child: page,
    );
  }

  @override
  void dispose() {
    try {
      WidgetsBinding.instance.removeObserver(this);
      // Reads the position before the player below is disposed.
      unawaited(_resume?.close());
      for (final dispose in _disposers) {
        dispose();
      }
      _player?.dispose();
      _replay?.dispose();
      _upNext?.dispose();
      // A video replaced by the next one leaves the system bars and the
      // rotation to the screen now on top.
      if (_hasFocus) {
        SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.manual,
          overlays: SystemUiOverlay.values,
        );
        SystemChrome.setPreferredOrientations([]);
      }
    } finally {
      // Last: the screen beneath resumes (after this frame) once released.
      final wasTop = _hasFocus;
      PlaybackFocus.shared.release(this);
      if (wasTop && PlaybackFocus.shared.top == null) WakelockPlus.disable();
      super.dispose();
    }
  }
}
