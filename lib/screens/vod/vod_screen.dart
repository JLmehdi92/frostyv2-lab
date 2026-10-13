import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/apis/twitch_vod_service.dart';
import 'package:frosty/models/vod.dart';
import 'package:frosty/screens/channel/chat/stores/chat_assets_store.dart';
import 'package:frosty/screens/channel/video/player_engine_resolver.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/screens/vod/stores/ivs_vod_store.dart';
import 'package:frosty/screens/vod/stores/vod_chat_replay_store.dart';
import 'package:frosty/screens/vod/stores/web_vod_store.dart';
import 'package:frosty/screens/vod/vod_overlay.dart';
import 'package:frosty/screens/vod/vod_player_controller.dart';
import 'package:frosty/screens/vod/widgets/vod_chat_replay.dart';
import 'package:frosty/screens/vod/widgets/vod_error_view.dart';
import 'package:frosty/screens/vod/widgets/vod_info_strip.dart';
import 'package:frosty/screens/vod/widgets/vod_video.dart';
import 'package:frosty/services/playback_focus.dart';
import 'package:frosty/theme.dart';
import 'package:frosty/utils/context_extensions.dart';
import 'package:frosty/widgets/alert_message.dart';
import 'package:frosty/widgets/draggable_divider.dart';
import 'package:frosty/widgets/loading_indicator.dart';
import 'package:mobx/mobx.dart';
import 'package:simple_pip_mode/actions/pip_actions_layout.dart';
import 'package:simple_pip_mode/pip_widget.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Watches a past broadcast, highlight or upload inside the app, like the
/// official app: native player, seek, speed, and the chat replayed in step
/// with the video (with 7TV/BTTV/FFZ emotes).
class VodScreen extends StatefulWidget {
  static const routeName = 'VodScreen';

  const VodScreen({super.key, required this.vodId, this.vod, this.startAt});

  /// Numeric id, with or without the `v` prefix.
  final String vodId;

  /// Known metadata (from a list); fetched when null.
  final Vod? vod;

  /// Where to start (a `?t=` link, a resume point).
  final Duration? startAt;

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

  @override
  void initState() {
    super.initState();
    // One player at a time: the mini player closes and a live stream
    // beneath pauses until this screen closes.
    context.miniPlayerStore.close();
    PlaybackFocus.shared
      ..register(this, onLost: _onFocusLost, onRegained: _onFocusRegained)
      ..claim(this);
    if (_settings.keepScreenAwake) WakelockPlus.enable();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadMetadata());
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
    if (!mounted) return;
    final loaded = vod;
    setState(() {
      _vod = loaded;
      _replay = _buildReplay(loaded);
      _player = _buildPlayer(loaded, startAt: widget.startAt);
    });
    _bindReplay();
    unawaited(
      _service.getMutedSegments(loaded.id).then((segments) {
        if (mounted) setState(() => _mutedSegments = segments);
      }),
    );
  }

  VodChatReplayStore _buildReplay(Vod vod) {
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
      _switchPlayer(forceWeb: true);
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
    _playingBeforeFocusLoss = player != null && !player.paused;
    if (_playingBeforeFocusLoss) player!.pause();
  }

  void _onFocusRegained() {
    if (!mounted) return;
    if (_playingBeforeFocusLoss) _player?.play();
    _playingBeforeFocusLoss = false;
    if (_settings.keepScreenAwake) WakelockPlus.enable();
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
    if (player is IvsVodStore) {
      return VodVideo(store: player, fillScreen: _fillScreen);
    }
    if (player is WebVodStore) {
      return ColoredBox(
        color: Colors.black,
        child: WebViewWidget(controller: player.webViewController),
      );
    }
    return const ColoredBox(color: Colors.black);
  }

  Widget _buildPlayerArea({required bool landscape}) {
    final player = _player;
    final vod = _vod;
    if (vod == null) {
      return ColoredBox(
        color: Colors.black,
        child: _loadError == null
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: AlertMessage(message: _loadError!, color: Colors.white),
              ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildVideo(),
        if (player != null)
          Observer(
            builder: (context) {
              final problem = player.problem;
              if (player.status == VodPlaybackStatus.problem &&
                  problem != null) {
                return VodErrorView(
                  problem: problem,
                  onRetry: () => unawaited(_switchPlayer()),
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
                showChatOverlayButton: landscape && _settings.fullScreen,
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
            child: _buildPlayerArea(landscape: false),
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
        final replay = _replay;
        final noChat =
            replay == null ||
            replay.status == ReplayStatus.unavailable ||
            replay.status == ReplayStatus.notApplicable;
        final playerArea = _buildPlayerArea(landscape: true);
        if (noChat) return ColoredBox(color: Colors.black, child: playerArea);

        final chatWidth = _settings.chatWidth;
        final leftSide = _settings.landscapeChatLeftSide;
        final overlayVisible = _player?.overlayVisible ?? true;

        Widget divider(double totalWidth) => Positioned(
          top: 0,
          bottom: 0,
          left: leftSide ? totalWidth * chatWidth - 12 : null,
          right: leftSide ? null : totalWidth * chatWidth - 12,
          child: DraggableDivider(
            currentWidth: chatWidth,
            maxWidth: 0.6,
            isResizableOnLeft: leftSide,
            showHandle: overlayVisible,
            onDragStart: () => setState(() => _isDividerDragging = true),
            onDrag: (width) => _settings.chatWidth = width,
            onDragEnd: () => setState(() => _isDividerDragging = false),
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
                  ? Colors.black.withValues(
                      alpha: _settings.fullScreenChatOverlayOpacity,
                    )
                  : context.scaffoldColor,
              child: SafeArea(
                left: leftSide,
                right: !leftSide,
                child: _buildChat(header: !overlay),
              ),
            );

        if (_settings.fullScreen) {
          return ColoredBox(
            color: Colors.black,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final overlayChat = Visibility(
                  visible: _settings.fullScreenChatOverlay,
                  maintainState: true,
                  child: Theme(
                    data: FrostyThemes(
                      colorSchemeSeed: Color(_settings.accentColor),
                    ).dark,
                    child: DefaultTextStyle(
                      style: context.defaultTextStyle.copyWith(
                        color:
                            Theme.of(
                              context,
                            ).extension<FrostyColors>()?.overlayOnSurface ??
                            Colors.white,
                      ),
                      child: chatPanel(width, overlay: true),
                    ),
                  ),
                );
                return Stack(
                  children: [
                    Positioned.fill(child: playerArea),
                    Align(
                      alignment: leftSide
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      child: overlayChat,
                    ),
                    if (_settings.fullScreenChatOverlay) divider(width),
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
                _settings.landscapeCutout != LandscapeCutoutType.left &&
                _settings.landscapeCutout != LandscapeCutoutType.both,
            right:
                _settings.landscapeCutout != LandscapeCutoutType.right &&
                _settings.landscapeCutout != LandscapeCutoutType.both,
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

    final player = _player;
    if (Platform.isAndroid && player != null) {
      return PipWidget(
        pipLayout: PipActionsLayout.mediaOnlyPause,
        onPipAction: (_) => player.togglePlay(),
        onPipEntered: player.onPipEntered,
        onPipExited: player.onPipExited,
        pipChild: _buildVideo(),
        child: page,
      );
    }
    return page;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final dispose in _disposers) {
      dispose();
    }
    _player?.dispose();
    _replay?.dispose();
    PlaybackFocus.shared.release(this);
    // The screen beneath re-enables it when it plays on.
    if (PlaybackFocus.shared.top == null) WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    SystemChrome.setPreferredOrientations([]);
    super.dispose();
  }
}
