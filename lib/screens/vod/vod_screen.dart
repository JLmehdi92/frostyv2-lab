import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/apis/twitch_vod_service.dart';
import 'package:frosty/models/vod.dart';
import 'package:frosty/screens/channel/chat/stores/chat_assets_store.dart';
import 'package:frosty/screens/channel/video/overlay_common.dart';
import 'package:frosty/screens/channel/video/player_engine_resolver.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/screens/vod/stores/ivs_vod_store.dart';
import 'package:frosty/screens/vod/stores/vod_chat_replay_store.dart';
import 'package:frosty/screens/vod/stores/web_vod_store.dart';
import 'package:frosty/screens/vod/vod_overlay.dart';
import 'package:frosty/screens/vod/vod_player_controller.dart';
import 'package:frosty/screens/vod/vod_resume.dart';
import 'package:frosty/screens/vod/widgets/vod_chat_replay.dart';
import 'package:frosty/screens/vod/widgets/vod_error_view.dart';
import 'package:frosty/screens/vod/widgets/vod_info_strip.dart';
import 'package:frosty/screens/vod/widgets/vod_video.dart';
import 'package:frosty/services/playback_focus.dart';
import 'package:frosty/stores/mini_player_store.dart';
import 'package:frosty/theme.dart';
import 'package:frosty/utils/context_extensions.dart';
import 'package:frosty/utils/pip_callbacks.dart';
import 'package:frosty/widgets/draggable_divider.dart';
import 'package:frosty/widgets/loading_indicator.dart';
import 'package:mobx/mobx.dart';
import 'package:simple_pip_mode/actions/pip_actions_layout.dart';
import 'package:simple_pip_mode/pip_widget.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Builds the player for a VOD (tests pass a fake).
typedef VodPlayerFactory =
    VodPlayerController Function(Vod vod, Duration? startAt);

/// Builds the chat replay for a VOD (tests pass a fake).
typedef VodReplayFactory = VodChatReplayStore Function(Vod vod);

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

  VodPlayerController? _player;
  VodChatReplayStore? _replay;
  var _mutedSegments = const <MutedSegment>[];
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
    // A `?t=` link wins; otherwise resume 30 s before where the viewer left.
    final saved = widget.startAt == null
        ? await _resumeRepository.entry(vod.id)
        : null;
    if (!mounted) return;
    final loaded = vod;
    final startAt = startPositionFor(saved: saved, deepLink: widget.startAt);
    setState(() {
      _loadError = null;
      _vod = loaded;
      _replay = _buildReplay(loaded);
      _player = _buildPlayer(loaded, startAt: startAt);
    });
    _bindReplay();
    _resume = VodResumeController(
      vodId: loaded.id,
      player: () => _player,
      repository: _resumeRepository,
      fallbackLengthSec: loaded.lengthSeconds,
    )..start();
    unawaited(
      _service.getMutedSegments(loaded.id).then((segments) {
        if (mounted) setState(() => _mutedSegments = segments);
      }),
    );
  }

  void _retryMetadata() {
    setState(() => _loadError = null);
    unawaited(_loadMetadata());
  }

  VodChatReplayStore _buildReplay(Vod vod) {
    final factory = widget.replayFactory;
    if (factory != null) return factory(vod);
    final auth = context.authStore;
    return VodChatReplayStore(
      vod: vod,
      vodService: _service,
      assetsStore: ChatAssetsStore(
        twitchApi: context.twitchApi,
        ffzApi: context.ffzApi,
        bttvApi: context.bttvApi,
        sevenTVApi: context.sevenTVApi,
        globalAssetsStore: context.globalAssetsStore,
      ),
      settings: _settings,
      headers: auth.headersTwitch,
      viewerLogin: auth.user.details?.login,
      blockedLogins: () =>
          auth.user.blockedUsers.map((u) => u.userLogin).toList(),
    );
  }

  /// The native IVS player, or the Twitch embed in a WebView when this
  /// platform or setting needs it, or after the native player failed.
  VodPlayerController _buildPlayer(Vod vod, {Duration? startAt}) {
    final player = _createPlayer(vod, startAt: startAt);
    // A player built while another one is on top must stay silent.
    if (!_hasFocus) player.setFocused(false);
    return player;
  }

  VodPlayerController _createPlayer(Vod vod, {Duration? startAt}) {
    final factory = widget.playerFactory;
    if (factory != null) return factory(vod, startAt);
    final engine = resolvePlayerEngine(
      setting: _settings.playerEngine,
      isAndroid: Platform.isAndroid,
      forceWeb: _forceWeb,
    );
    if (engine != PlayerEngine.ivs) {
      return WebVodStore(
        vodId: vod.id,
        startAt: startAt ?? Duration.zero,
        knownLength: Duration(seconds: vod.lengthSeconds),
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
      if (context.isLargeScreen) releaseOrientationLock();
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
  Widget _withBackButton(Widget child) => Stack(
    fit: StackFit.expand,
    children: [
      child,
      Align(
        alignment: Alignment.topLeft,
        child: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.maybePop(context),
          icon: Icon(
            Icons.adaptive.arrow_back_rounded,
            color: Colors.white,
            shadows: kOverlayShadow,
          ),
        ),
      ),
    ],
  );

  Widget _buildPlayerArea({required bool landscape, required bool hasChat}) {
    final player = _player;
    final vod = _vod;
    if (vod == null || player == null) {
      final error = _loadError;
      return _withBackButton(
        error == null
            ? const ColoredBox(
                color: Colors.black,
                child: Center(child: CircularProgressIndicator()),
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
              vod: vod,
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
      ],
    );
  }

  Widget _buildChat({bool header = true}) {
    final replay = _replay;
    if (replay == null) {
      return _loadError == null
          ? const LoadingIndicator(subtitle: 'Loading chat replay')
          : const SizedBox.shrink();
    }
    return VodChatReplay(store: replay, showHeader: header);
  }

  Widget _buildPortrait() {
    final vod = _vod;
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: _buildPlayerArea(landscape: false, hasChat: true),
          ),
          if (vod != null) VodInfoStrip(vod: vod),
          const Divider(height: 1),
          Expanded(child: SafeArea(top: false, child: _buildChat())),
        ],
      ),
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
        if (!hasChat) return ColoredBox(color: Colors.black, child: playerArea);

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

        Widget chatPanel(double totalWidth, {required bool overlay}) =>
            AnimatedContainer(
              curve: Curves.ease,
              duration: _isDividerDragging
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              width: totalWidth * chatWidth,
              color: overlay
                  ? Colors.black.withValues(alpha: overlayOpacity)
                  : context.scaffoldColor,
              child: SafeArea(
                left: leftSide,
                right: !leftSide,
                child: _buildChat(header: !overlay),
              ),
            );

        if (fullScreen) {
          final overlayTheme = FrostyThemes(
            colorSchemeSeed: Color(_settings.accentColor),
          ).dark;
          final onOverlay =
              Theme.of(context).extension<FrostyColors>()?.overlayOnSurface ??
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
                final video = Expanded(child: playerArea);
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

    final page = Scaffold(
      backgroundColor: landscape ? Colors.black : null,
      body: landscape ? _buildLandscape() : _buildPortrait(),
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
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
      SystemChrome.setPreferredOrientations([]);
    } finally {
      // Last: the screen beneath resumes (after this frame) once released.
      final wasTop = _hasFocus;
      PlaybackFocus.shared.release(this);
      if (wasTop && PlaybackFocus.shared.top == null) WakelockPlus.disable();
      super.dispose();
    }
  }
}
