import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Clip;
import 'package:flutter/material.dart' as material show Clip;
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/models/clip.dart';
import 'package:frosty/screens/clips/clip_screen.dart';
import 'package:frosty/screens/clips/stores/clip_player_store.dart';
import 'package:frosty/screens/clips/stores/clips_feed_store.dart';
import 'package:frosty/screens/home/stream_list/stream_card_parts.dart';
import 'package:frosty/screens/home/stream_list/streams_list.dart';
import 'package:frosty/screens/vod/vod_player_controller.dart';
import 'package:frosty/screens/vod/vod_time.dart';
import 'package:frosty/screens/vod/widgets/video_glyph.dart';
import 'package:frosty/screens/vod/widgets/video_kit.dart';
import 'package:frosty/services/playback_focus.dart';
import 'package:frosty/theme.dart';
import 'package:frosty/utils/context_extensions.dart';
import 'package:frosty/utils/pip_callbacks.dart';
import 'package:frosty/widgets/frosty_cached_network_image.dart';
import 'package:frosty/widgets/motion/haptics.dart';
import 'package:frosty/widgets/motion/motion.dart';
import 'package:frosty/widgets/motion/press_scale.dart';
import 'package:frosty/widgets/motion/reduce_motion.dart';
import 'package:frosty/widgets/profile_picture.dart';
import 'package:frosty/widgets/skeleton_loader.dart';
import 'package:intl/intl.dart';
import 'package:mobx/mobx.dart';
import 'package:simple_pip_mode/actions/pip_actions_layout.dart';
import 'package:simple_pip_mode/pip_widget.dart';
import 'package:simple_pip_mode/simple_pip.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Builds the player of a feed clip (tests pass a fake); [focused] is false
/// for the clip preloaded below the one playing.
typedef FeedPlayerFactory =
    VodPlayerController Function(Clip clip, {required bool focused});

/// The official app's clips feed (boards Clips, ClipsTablette): Twitch's
/// top clips, one at a time, a double-tap to play or pause. On a phone,
/// one clip per page and a swipe to the next; on a tablet, the clip on a
/// stage beside the queue ("Up next in Clips"), where a tap plays any
/// clip. One clip plays at a time; only the next one is preloaded
/// (paused), every other player is let go.
///
/// Home's Clips tab: the shell builds it while the tab is on screen and
/// lets it go when another tab or section is chosen, which stops the clips.
class ClipsFeedScreen extends StatefulWidget {
  const ClipsFeedScreen({
    super.key,
    this.onPipChanged,
    @visibleForTesting this.store,
    @visibleForTesting this.playerFactory,
    @visibleForTesting this.disableAutoPip,
  });

  /// Told when the feed enters (true) or leaves (false) picture-in-picture:
  /// the shell around it must then show the clip alone.
  final ValueChanged<bool>? onPipChanged;

  /// Builds the picture-in-picture wrapper off Android too (tests).
  @visibleForTesting
  static bool? debugPipSupported;

  final ClipsFeedStore? store;
  final FeedPlayerFactory? playerFactory;

  /// Turns Android's auto-PiP off (tests count the calls).
  final VoidCallback? disableAutoPip;

  @override
  State<ClipsFeedScreen> createState() => _ClipsFeedScreenState();
}

class _ClipsFeedScreenState extends State<ClipsFeedScreen> {
  late final _settings = context.settingsStore;
  late final _miniPlayer = context.miniPlayerStore;
  late final ClipsFeedStore _store =
      widget.store ??
      ClipsFeedStore(
        clipService: context.twitchClipService,
        language: _settings.streamLanguage,
      );

  /// The phone's pages; made where the phone layout is built, at the clip
  /// shown (after a tablet layout, the stage's), and let go with it.
  PageController? _pageController;
  final _pipKey = GlobalKey<PipWidgetState>();

  /// The players alive: the current clip's and the next one's, by index.
  final _players = <int, VodPlayerController>{};
  var _index = 0;

  /// The clip last started as the current one: a later sync (more clips
  /// arriving) must not start it again after the viewer paused it.
  int? _started;

  /// Whether the app is in picture-in-picture from this feed.
  var _inPip = false;

  /// Whether the clip was playing when another player took focus.
  var _playingBeforeFocusLoss = false;

  /// Which way the tablet's stage moved last (1: to a later clip).
  var _stageDirection = 1;

  ReactionDisposer? _disposeClipsReaction;
  ReactionDisposer? _disposeMiniReaction;

  bool get _hasFocus => identical(PlaybackFocus.shared.top, this);

  /// A player only turns auto-PiP off when disposed with focus, and the
  /// feed takes focus from a clip before letting it go: with no clip
  /// playing (the end page, the feed closing) the feed turns it off itself.
  void _disableAutoPip() {
    final disable = widget.disableAutoPip;
    if (disable != null) {
      disable();
    } else if (Platform.isAndroid) {
      SimplePip().setAutoPipMode(autoEnter: false);
    }
  }

  @override
  void initState() {
    super.initState();
    // One player at a time: the mini player closes and a stream or VOD
    // beneath pauses until the feed closes.
    _miniPlayer.close();
    PlaybackFocus.shared
      ..register(this, onLost: _onFocusLost, onRegained: _onFocusRegained)
      ..claim(this);
    if (_settings.keepScreenAwake) WakelockPlus.enable();
    _disposeClipsReaction = reaction(
      (_) => _store.clips.length,
      (_) => _syncPlayers(),
    );
    // The mini window's PipWidget took the PiP events; once it closes they
    // come back here.
    _disposeMiniReaction = reaction((_) => _miniPlayer.visible, (bool visible) {
      if (visible) return;
      WidgetsBinding.instance
        ..addPostFrameCallback((_) {
          // Only while the feed is the player on top: the mini window also
          // hides when it is restored into its channel, or when a VOD or
          // clip opens, and the PiP events are then that screen's.
          if (mounted && !_miniPlayer.visible && _hasFocus) {
            reclaimPipCallbacks(_pipKey);
          }
        })
        ..ensureVisualUpdate();
    });
    unawaited(_store.load());
  }

  VodPlayerController _createPlayer(Clip clip, {required bool focused}) {
    final factory = widget.playerFactory;
    final player =
        factory?.call(clip, focused: focused) ??
        ClipPlayerStore(
          slug: clip.slug,
          clipService: context.twitchClipService,
          settingsStore: _settings,
          knownLength: clip.duration,
          focused: focused,
        );
    // No playback at all leaves the player failed, which the page says;
    // "Open clip" offers the web fallback.
    unawaited(player.ready.catchError((Object _) {}));
    return player;
  }

  /// Keeps exactly the current clip's player (focused, playing) and the
  /// next one's (preloaded, paused).
  void _syncPlayers() {
    if (!mounted) return;
    final clips = _store.clips;
    final wanted = {
      if (_index < clips.length) _index,
      if (_index + 1 < clips.length) _index + 1,
    };
    for (final index in _players.keys.toList()) {
      if (wanted.contains(index)) continue;
      _players.remove(index)!
        ..setFocused(false)
        ..pause()
        ..dispose();
    }
    for (final index in wanted) {
      final current = index == _index;
      final existing = _players[index];
      final start = current && _hasFocus && _started != index;
      if (existing == null) {
        _players[index] = _createPlayer(clips[index], focused: start);
      } else if (start) {
        existing
          ..setFocused(true)
          ..play();
      }
      if (start) _started = index;
    }
    if (!wanted.contains(_index) && _hasFocus) _disableAutoPip();
    setState(() {});
  }

  void _onPageChanged(int index) {
    // The same clip again (the phone's pages made at the stage's clip).
    if (index == _index) return;
    final previous = _players[_index];
    if (previous != null) {
      previous
        ..setFocused(false)
        ..pause();
    }
    _stageDirection = index > _index ? 1 : -1;
    _index = index;
    _syncPlayers();
    if (index >= _store.clips.length - 3) unawaited(_store.loadMore());
  }

  /// Shows clip [index]: the phone's pages slide there, the tablet's stage
  /// changes at once (the end page is one past the last clip).
  void _goTo(int index) {
    final last = _store.clips.length;
    final target = index.clamp(0, last);
    if (target == _index) return;
    final pages = _pageController;
    if (pages != null && pages.hasClients) {
      unawaited(
        pages.animateToPage(
          target,
          duration: motionDuration(context, const Duration(milliseconds: 360)),
          curve: FrostyMotion.standard,
        ),
      );
    } else {
      Haptics.selection();
      _onPageChanged(target);
    }
  }

  void _onFocusLost() {
    final player = _players[_index];
    if (player == null) return;
    player.setFocused(false);
    // A player still loading would start on its own: treat it as playing.
    _playingBeforeFocusLoss =
        !player.paused || player.status == VodPlaybackStatus.loading;
    if (!player.paused) player.pause();
  }

  void _onFocusRegained() {
    // After the frame: the screen above may be closing with this one.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final player = _players[_index];
      if (!_miniPlayer.visible && player != null) {
        player.setFocused(true);
        if (_playingBeforeFocusLoss) player.play();
      }
      // The screen above had its own PipWidget, which took the plugin's
      // single handler: the PiP events must come here again.
      if (!_miniPlayer.visible && _hasFocus) reclaimPipCallbacks(_pipKey);
      _playingBeforeFocusLoss = false;
      if (_settings.keepScreenAwake) WakelockPlus.enable();
    });
    // A release with nothing to redraw must still reach that frame.
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Widget _video(int index) {
    final player = _players[index];
    if (player is ClipPlayerStore) return player.buildVideo(fill: false);
    return const SizedBox.expand();
  }

  /// The clip's video in its black box: the picture until the player draws
  /// (a player that never does keeps it), the play mark when paused, the
  /// spinner, or why it cannot play. A double tap plays or pauses.
  Widget _videoBox(int index, {required bool large}) {
    final clip = _store.clips[index];
    final player = _players[index];
    final thumbnail = clip.thumbnailUrl;
    final accent = context.frostyColors.live;
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.black),
        if (thumbnail != null && player is! ClipPlayerStore)
          FrostyCachedNetworkImage(
            imageUrl: thumbnail,
            fit: BoxFit.contain,
            errorWidget: (context, url, error) => const SizedBox.shrink(),
          ),
        Semantics(
          container: true,
          label: 'Clip player. Double-tap to toggle play/pause',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onDoubleTap: player?.togglePlay,
            child: RepaintBoundary(child: _video(index)),
          ),
        ),
        if (player != null)
          Observer(
            builder: (context) {
              final status = player.status;
              if (status == VodPlaybackStatus.loading ||
                  status == VodPlaybackStatus.buffering) {
                return Center(child: CircularProgressIndicator(color: accent));
              }
              if (status == VodPlaybackStatus.failed ||
                  status == VodPlaybackStatus.problem) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      "This clip can't be played here",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: FrostyTokens.bodyFamily,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: FrostyTokens.textPrimaryDark,
                      ),
                    ),
                  ),
                );
              }
              if (player.paused && status != VodPlaybackStatus.ended) {
                return IgnorePointer(
                  child: Center(child: _PausedMark(size: large ? 76 : 64)),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        Positioned(
          right: large ? 14 : 8,
          top: large ? 14 : 8,
          child: IgnorePointer(
            child: OverlayPill(
              height: large ? 26 : 22,
              radius: large ? 7 : 6,
              padding: large ? 9 : 7,
              color: const Color(0x99000000),
              child: Text(
                formatVodTime(clip.duration),
                style: FrostyType.tabular(
                  TextStyle(
                    fontFamily: FrostyTokens.bodyFamily,
                    fontSize: large ? 13 : 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// The played part of the clip: a thin signal line under (phone) or in
  /// (tablet) the video box.
  Widget _progress(int index, {required double height, required Color track}) {
    final player = _players[index];
    return RepaintBoundary(
      child: SizedBox(
        height: height,
        child: ColoredBox(
          color: track,
          child: player == null
              ? const SizedBox.expand()
              : Observer(
                  builder: (context) {
                    final total = player.duration.inMilliseconds;
                    final played = total <= 0
                        ? 0.0
                        : (player.position.inMilliseconds / total).clamp(
                            0.0,
                            1.0,
                          );
                    return FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: played,
                      child: ColoredBox(color: context.frostyColors.live),
                    );
                  },
                ),
        ),
      ),
    );
  }

  void _openClip(Clip clip) =>
      unawaited(ClipScreen.open(context, slug: clip.slug, clip: clip));

  // --- Phone (board Clips) ---------------------------------------------------

  Widget _buildClipPage(BuildContext context, int index) {
    final clips = _store.clips;
    final clip = clips[index];
    final next = index + 1 < clips.length ? clips[index + 1] : null;
    final padding = MediaQuery.paddingOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // A phone held sideways: the clip fills the page, its details over
        // the bottom (a gradient, never a blur).
        if (constraints.maxWidth > constraints.maxHeight) {
          return _buildWidePage(context, index, padding);
        }
        final width = constraints.maxWidth;
        final videoTop = padding.top + 24;
        final videoHeight = width * 9 / 16;
        final room = constraints.maxHeight - padding.bottom;
        // Under the details, the next clip and the hint when there is room.
        final showNext =
            next != null && room - (videoTop + videoHeight + 210) >= 110;
        return Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: FrostyTokens.backgroundDark),
            if (clip.thumbnailUrl case final url?)
              Positioned(
                left: -60,
                right: -60,
                top: videoTop - 110,
                height: videoHeight + 260,
                child: _Ambient(url: url, opacity: 0.38),
              ),
            const Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xB30A0A0A),
                        Color(0x260A0A0A),
                        Color(0x8C0A0A0A),
                        FrostyTokens.backgroundDark,
                      ],
                      stops: [0, 0.22, 0.52, 0.74],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: videoTop,
              height: videoHeight,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x8C000000),
                      blurRadius: 50,
                      offset: Offset(0, 18),
                    ),
                  ],
                ),
                child: _videoBox(index, large: false),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: videoTop + videoHeight,
              child: _progress(
                index,
                height: 2,
                track: const Color(0x1FFFFFFF),
              ),
            ),
            Positioned(
              left: 16 + padding.left,
              right: 16 + padding.right,
              top: videoTop + videoHeight + 23,
              child: _ClipDetails(clip: clip, onOpen: () => _openClip(clip)),
            ),
            if (showNext)
              Positioned(
                left: 16 + padding.left,
                right: 16 + padding.right,
                bottom: padding.bottom + (index == 0 ? 52 : 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 14,
                  children: [
                    _NextCard(clip: next, onTap: () => _goTo(index + 1)),
                    if (index == 0) const _SwipeHint(),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildWidePage(BuildContext context, int index, EdgeInsets padding) {
    final clip = _store.clips[index];
    final title = clip.title.trim().isEmpty
        ? 'Untitled clip'
        : clip.title.trim();
    final game = clip.gameName;
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.black),
        Positioned(
          left: padding.left,
          right: padding.right,
          top: padding.top,
          bottom: padding.bottom,
          child: _videoBox(index, large: false),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0xD1000000), Color(0x00000000)],
              ),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16 + padding.left,
                40,
                16 + padding.right,
                12 + padding.bottom,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                spacing: 16,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      spacing: 2,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: FrostyTokens.bodyFamily,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: FrostyTokens.textPrimaryDark,
                          ),
                        ),
                        Text(
                          [
                            _channelOf(clip),
                            if (game != null && game.isNotEmpty) game,
                            _views(clip),
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: FrostyType.tabular(
                            const TextStyle(
                              fontFamily: FrostyTokens.bodyFamily,
                              fontSize: 13,
                              color: FrostyTokens.textSecondaryDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _OpenClipButton(onPressed: () => _openClip(clip), pill: true),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _progress(index, height: 2, track: const Color(0x1FFFFFFF)),
        ),
      ],
    );
  }

  Widget _buildEndPage(BuildContext context) {
    final accent = context.frostyColors.live;
    return ColoredBox(
      color: FrostyTokens.backgroundDark,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Observer(
            builder: (context) => _store.loadingMore
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 16,
                    children: [
                      CircularProgressIndicator(color: accent),
                      const Text(
                        'Loading more clips for you',
                        style: TextStyle(
                          fontFamily: FrostyTokens.bodyFamily,
                          fontSize: 14,
                          color: FrostyTokens.textSecondaryDark,
                        ),
                      ),
                    ],
                  )
                : const _FeedEnd(),
          ),
        ),
      ),
    );
  }

  Widget _buildPhone(BuildContext context) {
    final clips = _store.clips;
    final pages = _pageController ??= PageController(initialPage: _index);
    return PageView.builder(
      controller: pages,
      scrollDirection: Axis.vertical,
      onPageChanged: _onPageChanged,
      // The end (or the next page loading) gets a page of its own.
      itemCount: clips.length + 1,
      itemBuilder: (context, index) => index < clips.length
          ? _buildClipPage(context, index)
          : _buildEndPage(context),
    );
  }

  // --- Tablet (board ClipsTablette) -----------------------------------------

  Widget _buildTablet(BuildContext context) {
    final clips = _store.clips;
    final padding = MediaQuery.paddingOf(context);
    final atEnd = _index >= clips.length;
    final current = atEnd ? null : clips[_index];
    return LayoutBuilder(
      builder: (context, constraints) {
        const gutter = FrostySpacing.gutterTablet;
        final width = constraints.maxWidth - padding.left - padding.right;
        // Landscape: the stage beside the queue; portrait: the queue
        // under the stage.
        final height =
            constraints.maxHeight - padding.top - 20 - padding.bottom - 24;
        final side = width >= 1100;
        // The stage keeps room under it for its details (and, in portrait,
        // for a few rows of the queue).
        final byHeight = (height - 150 - (side ? 0 : 24 + 180)) * 16 / 9;
        final stageWidth = math.max(
          240.0,
          math.min(
            byHeight,
            side
                ? math.min(800.0, width - gutter * 3 - 340)
                : width - gutter * 2,
          ),
        );
        final stage = _Stage(
          key: const ValueKey('stage'),
          width: stageWidth,
          index: _index,
          direction: _stageDirection,
          end: atEnd
              ? Observer(
                  builder: (context) => _store.loadingMore
                      ? const _StageLoading()
                      : const _FeedEnd(large: true),
                )
              : null,
          video: atEnd ? null : _videoBox(_index, large: true),
          progress: atEnd
              ? null
              : _progress(_index, height: 3, track: const Color(0x24FFFFFF)),
          details: current == null
              ? null
              : _ClipDetails(
                  clip: current,
                  large: true,
                  onOpen: () => _openClip(current),
                ),
          onSwipe: (forward) => _goTo(_index + (forward ? 1 : -1)),
        );
        final queue = _Queue(
          store: _store,
          current: _index,
          playing: () {
            final player = _players[_index];
            return player != null && !player.paused;
          },
          onPick: _goTo,
        );
        return Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: FrostyTokens.backgroundDark),
            Positioned(
              left: -80,
              top: padding.top - 76,
              width: stageWidth + 200,
              height: stageWidth * 0.95,
              child: AnimatedSwitcher(
                duration: motionDuration(
                  context,
                  const Duration(milliseconds: 500),
                ),
                child: current?.thumbnailUrl == null
                    ? const SizedBox.shrink()
                    : _Ambient(
                        key: ValueKey(current!.slug),
                        url: current.thumbnailUrl!,
                        opacity: 0.42,
                      ),
              ),
            ),
            const Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0x400A0A0A),
                        Color(0x990A0A0A),
                        FrostyTokens.backgroundDark,
                      ],
                      stops: [0, 0.6, 0.72],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  gutter + padding.left,
                  padding.top + 20,
                  gutter + padding.right,
                  padding.bottom + 24,
                ),
                child: side
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          stage,
                          const SizedBox(width: 32),
                          Expanded(child: queue),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: 24,
                        children: [
                          stage,
                          Expanded(child: queue),
                        ],
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFeed(BuildContext context) {
    return Observer(
      builder: (context) {
        final clips = _store.clips;
        final error = _store.error;
        final tablet = context.isLargeScreen;
        if (clips.isEmpty) {
          if (_store.loading) return _FeedSkeleton(large: tablet);
          return error != null
              ? FeedStatusView.error(message: error, onRetry: _store.load)
              : const FeedStatusView.empty(message: 'No clips right now');
        }
        if (tablet) {
          // The phone's pages are gone with their layout.
          final pages = _pageController;
          if (pages != null) {
            _pageController = null;
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => pages.dispose(),
            );
          }
          return _buildTablet(context);
        }
        return _buildPhone(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Always dark, as the boards draw it: the shell sets the system bars
    // over the feed (light icons, dark bar).
    final page = Theme(
      data: FrostyThemes(colorSchemeSeed: Color(_settings.accentColor)).dark,
      child: Material(
        color: FrostyTokens.backgroundDark,
        child: _buildFeed(context),
      ),
    );

    if (!(ClipsFeedScreen.debugPipSupported ?? Platform.isAndroid)) {
      return page;
    }
    return PipWidget(
      key: _pipKey,
      pipLayout: PipActionsLayout.mediaOnlyPause,
      onPipAction: (_) => _players[_index]?.togglePlay(),
      onPipEntered: () {
        _inPip = true;
        widget.onPipChanged?.call(true);
        _players[_index]?.onPipEntered();
      },
      onPipExited: () {
        _inPip = false;
        widget.onPipChanged?.call(false);
        _players[_index]?.onPipExited();
      },
      pipChild: ColoredBox(color: Colors.black, child: _video(_index)),
      child: page,
    );
  }

  @override
  void dispose() {
    try {
      if (_inPip) widget.onPipChanged?.call(false);
      _disposeClipsReaction?.call();
      _disposeMiniReaction?.call();
      _pageController?.dispose();
      // The current clip keeps its focus to the end, so disposing it also
      // turns its auto-PiP off.
      for (final player in _players.values) {
        player.dispose();
      }
      _players.clear();
      if (_hasFocus) _disableAutoPip();
    } finally {
      final wasTop = _hasFocus;
      PlaybackFocus.shared.release(this);
      if (wasTop && PlaybackFocus.shared.top == null) WakelockPlus.disable();
      super.dispose();
    }
  }
}

/// "248K views", or "1 view".
String _views(Clip clip) =>
    '${NumberFormat.compact().format(clip.viewCount)} '
    '${clip.viewCount == 1 ? 'view' : 'views'}';

String _channelOf(Clip clip) => clip.broadcasterDisplayName.isNotEmpty
    ? clip.broadcasterDisplayName
    : clip.broadcasterLogin;

/// The clip's picture behind the page, very soft: decoded tiny and drawn
/// large (a blur for free, nothing filtered while the video plays).
class _Ambient extends StatelessWidget {
  const _Ambient({super.key, required this.url, required this.opacity});

  final String url;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: Opacity(
          opacity: opacity,
          child: FrostyCachedNetworkImage(
            imageUrl: url,
            memCacheWidth: 24,
            fit: BoxFit.cover,
            errorWidget: (context, url, error) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

/// The paused mark in its disc.
class _PausedMark extends StatelessWidget {
  const _PausedMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: motionDuration(context, const Duration(milliseconds: 220)),
      curve: FrostyMotion.standard,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.scale(
          scale: reduceMotionOf(context) ? 1 : 0.8 + 0.2 * t,
          child: child,
        ),
      ),
      child: Container(
        width: size,
        height: size,
        decoration: const ShapeDecoration(
          color: Color(0x800A0A0A),
          shape: CircleBorder(
            side: BorderSide(
              color: Color(0x29FFFFFF),
              width: FrostyTokens.hairlineWidth,
            ),
          ),
        ),
        child: Center(
          child: VideoGlyph(
            VideoGlyphKind.play,
            color: FrostyTokens.textPrimaryDark,
            size: size * 0.44,
          ),
        ),
      ),
    );
  }
}

/// The channel, the category and views, the title and "Open clip".
class _ClipDetails extends StatelessWidget {
  const _ClipDetails({
    required this.clip,
    required this.onOpen,
    this.large = false,
  });

  final Clip clip;
  final VoidCallback onOpen;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final game = clip.gameName;
    final details = [
      if (game != null && game.isNotEmpty) game,
      _views(clip),
    ].join(' · ');
    final title = clip.title.trim().isEmpty
        ? 'Untitled clip'
        : clip.title.trim();
    final channel = Row(
      spacing: large ? 12 : 10,
      children: [
        if (clip.broadcasterLogin.isNotEmpty)
          DecoratedBox(
            decoration: const ShapeDecoration(
              shape: CircleBorder(
                side: BorderSide(
                  color: Color(0x33FFFFFF),
                  width: FrostyTokens.hairlineWidth,
                ),
              ),
            ),
            child: ProfilePicture(
              userLogin: clip.broadcasterLogin,
              radius: large ? 22 : 21,
            ),
          ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            spacing: 2,
            children: [
              Text(
                _channelOf(clip),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: FrostyTokens.bodyFamily,
                  fontSize: large ? 17 : 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.16,
                  color: FrostyTokens.textPrimaryDark,
                ),
              ),
              Text(
                details,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: FrostyType.tabular(
                  const TextStyle(
                    fontFamily: FrostyTokens.bodyFamily,
                    fontSize: 13,
                    color: FrostyTokens.textSecondaryDark,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
    final titleText = Text(
      title,
      maxLines: large ? 2 : 3,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: FrostyTokens.displayFamily,
        fontSize: large ? 22 : 18,
        fontWeight: large ? FontWeight.w800 : FontWeight.w700,
        height: large ? 1.25 : 1.35,
        letterSpacing: large ? -0.44 : -0.27,
        color: FrostyTokens.textPrimaryDark,
      ),
    );
    final open = _OpenClipButton(onPressed: onOpen, pill: large);
    if (large) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 20,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 12,
              children: [channel, titleText],
            ),
          ),
          Padding(padding: const EdgeInsets.only(top: 4), child: open),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14,
      children: [channel, titleText, open],
    );
  }
}

/// "Open clip": the one signal action of the page (the clip screen, with
/// its details, chat replay and the web fallback).
class _OpenClipButton extends StatelessWidget {
  const _OpenClipButton({required this.onPressed, required this.pill});

  final VoidCallback onPressed;

  /// The tablet's pill (the phone's is full width, 14 dp corners).
  final bool pill;

  @override
  Widget build(BuildContext context) {
    final accent = context.frostyColors.live;
    return Tooltip(
      message: 'Open clip',
      excludeFromSemantics: true,
      child: PressScale(
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: FrostyTokens.backgroundDark,
            minimumSize: const Size(0, 48),
            padding: EdgeInsets.symmetric(horizontal: pill ? 22 : 16),
            shape: pill
                ? const StadiumBorder()
                : RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
            textStyle: const TextStyle(
              fontFamily: FrostyTokens.bodyFamily,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
            elevation: 0,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              VideoGlyph(
                VideoGlyphKind.expand,
                color: FrostyTokens.backgroundDark,
                size: 17,
                strokeWidth: 2.2,
              ),
              Text('Open clip'),
            ],
          ),
        ),
      ),
    );
  }
}

/// The next clip under the current one (60 dp): a tap slides to it.
class _NextCard extends StatelessWidget {
  const _NextCard({required this.clip, required this.onTap});

  final Clip clip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final thumbnail = clip.thumbnailUrl;
    final title = clip.title.trim();
    return Semantics(
      button: true,
      label: 'Next clip, ${_channelOf(clip)}, $title',
      excludeSemantics: true,
      child: PressScale(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            height: 60,
            padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 12, 0),
            decoration: BoxDecoration(
              color: const Color(0xCC141414),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0x1AFFFFFF),
                width: FrostyTokens.hairlineWidth,
              ),
            ),
            child: Row(
              spacing: 12,
              children: [
                SizedBox(
                  width: 78,
                  height: 44,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: thumbnail == null
                        ? const ColoredBox(color: FrostyTokens.raisedDark)
                        : FrostyCachedNetworkImage(
                            imageUrl: thumbnail,
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      const Text(
                        'NEXT',
                        style: TextStyle(
                          fontFamily: FrostyTokens.bodyFamily,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.32,
                          color: FrostyTokens.textTertiaryDark,
                        ),
                      ),
                      Text(
                        title.isEmpty
                            ? _channelOf(clip)
                            : '${_channelOf(clip)} · $title',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: FrostyTokens.bodyFamily,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: FrostyTokens.textPrimaryDark,
                        ),
                      ),
                    ],
                  ),
                ),
                const VideoGlyph(
                  VideoGlyphKind.chevronUp,
                  color: FrostyTokens.textSecondaryDark,
                  size: 18,
                  strokeWidth: 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "You can swipe to the next clip", rising a little every 2.4 s (still
/// under reduce motion, stopped off screen).
class _SwipeHint extends StatefulWidget {
  const _SwipeHint();

  @override
  State<_SwipeHint> createState() => _SwipeHintState();
}

class _SwipeHintState extends State<_SwipeHint>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotionOf(context)) {
      _controller
        ..stop()
        ..value = 0;
    } else if (!_controller.isAnimating) {
      unawaited(_controller.repeat());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const text = Text(
      'You can swipe to the next clip',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: FrostyTokens.bodyFamily,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: FrostyTokens.textSecondaryDark,
      ),
    );
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          // Up 5 dp and back (board Clips' "peek").
          final t = FrostyMotion.standard.transform(
            1 - (2 * _controller.value - 1).abs(),
          );
          return Transform.translate(offset: Offset(0, -5 * t), child: child);
        },
        child: text,
      ),
    );
  }
}

/// The end of the feed: a check in its tile and Twitch's words.
class _FeedEnd extends StatelessWidget {
  const _FeedEnd({this.large = false});

  final bool large;

  @override
  Widget build(BuildContext context) {
    final accent = context.frostyColors.live;
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 14,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: large ? FrostyTokens.raisedDark : FrostyTokens.surfaceDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0x1AFFFFFF),
              width: FrostyTokens.hairlineWidth,
            ),
          ),
          child: Center(
            child: VideoGlyph(
              VideoGlyphKind.check,
              color: accent,
              size: 24,
              strokeWidth: 2,
            ),
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Text(
            'That’s all for now! Check out more clips from previous streams',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: FrostyTokens.bodyFamily,
              fontSize: large ? 18 : 16,
              fontWeight: FontWeight.w700,
              height: 1.4,
              color: FrostyTokens.textPrimaryDark,
            ),
          ),
        ),
      ],
    );
  }
}

/// The tablet's stage while the next page loads.
class _StageLoading extends StatelessWidget {
  const _StageLoading();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 16,
      children: [
        CircularProgressIndicator(color: context.frostyColors.live),
        const Text(
          'Loading more clips for you',
          style: TextStyle(
            fontFamily: FrostyTokens.bodyFamily,
            fontSize: 14,
            color: FrostyTokens.textSecondaryDark,
          ),
        ),
      ],
    );
  }
}

/// The tablet's stage: the clip's 16:9 box (20 dp corners) and its details
/// under it. Another clip slides in from the way the feed went (a fade
/// under reduce motion); a vertical swipe on it changes the clip.
class _Stage extends StatelessWidget {
  const _Stage({
    super.key,
    required this.width,
    required this.index,
    required this.direction,
    required this.video,
    required this.progress,
    required this.details,
    required this.end,
    required this.onSwipe,
  });

  final double width;
  final int index;
  final int direction;
  final Widget? video;
  final Widget? progress;
  final Widget? details;

  /// The end of the feed, in place of the video.
  final Widget? end;

  /// true: the next clip.
  final ValueChanged<bool> onSwipe;

  @override
  Widget build(BuildContext context) {
    final reduce = reduceMotionOf(context);
    final height = width * 9 / 16;
    final radius = BorderRadius.circular(20);
    final box = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: end != null ? FrostyTokens.surfaceDark : Colors.black,
        borderRadius: radius,
        boxShadow: const [
          BoxShadow(
            color: Color(0x8C000000),
            blurRadius: 60,
            offset: Offset(0, 24),
          ),
        ],
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: const Color(0x1AFFFFFF),
          width: FrostyTokens.hairlineWidth,
        ),
      ),
      clipBehavior: material.Clip.antiAlias,
      child: end != null
          ? Center(child: end)
          : Stack(
              fit: StackFit.expand,
              children: [
                ?video,
                if (progress case final progress?)
                  Positioned(left: 0, right: 0, bottom: 0, child: progress),
              ],
            ),
    );
    final details = this.details;
    return GestureDetector(
      onVerticalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v.abs() < 300) return;
        onSwipe(v < 0);
      },
      child: SizedBox(
        width: width,
        child: AnimatedSwitcher(
          duration: motionDuration(context, const Duration(milliseconds: 460)),
          switchInCurve: FrostyMotion.standard,
          switchOutCurve: FrostyMotion.standard,
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topCenter,
            children: [...previous, ?current],
          ),
          transitionBuilder: (child, animation) {
            final incoming = child.key == ValueKey(index);
            final offset = Tween<Offset>(
              begin: Offset(
                0,
                (incoming ? 56 : -56) * direction / (height + 120),
              ),
              end: Offset.zero,
            ).animate(animation);
            return FadeTransition(
              opacity: animation,
              child: reduce
                  ? child
                  : SlideTransition(position: offset, child: child),
            );
          },
          child: Column(
            key: ValueKey(index),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              box,
              if (details != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 20, 4, 0),
                  child: details,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The tablet's queue (board ClipsTablette, "Up next in Clips"): every clip
/// of the feed, the one playing tinted with its signal bars; a tap plays a
/// clip (an approved addition), the next page loads as the end shows.
class _Queue extends StatelessWidget {
  const _Queue({
    required this.store,
    required this.current,
    required this.playing,
    required this.onPick,
  });

  final ClipsFeedStore store;
  final int current;

  /// Whether the clip playing is playing (its bars move).
  final bool Function() playing;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Expanded(
                child: VideoSectionLabel(
                  'Up next in Clips',
                  padding: EdgeInsets.zero,
                ),
              ),
              Text(
                'Swipe the video or pick one',
                style: TextStyle(
                  fontFamily: FrostyTokens.bodyFamily,
                  fontSize: 12,
                  color: FeedColors.dark.tertiary,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Observer(
            builder: (context) {
              final clips = store.clips;
              final more = store.hasMore || store.loadingMore;
              return ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: clips.length + (more ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= clips.length) {
                    if (!store.loadingMore) {
                      // After the frame: never change the store mid-build.
                      WidgetsBinding.instance.addPostFrameCallback(
                        (_) => unawaited(store.loadMore()),
                      );
                    }
                    return const _QueueLoading();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _QueueItem(
                      clip: clips[index],
                      current: index == current,
                      past: index < current,
                      playing: playing,
                      onTap: () => onPick(index),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _QueueItem extends StatelessWidget {
  const _QueueItem({
    required this.clip,
    required this.current,
    required this.past,
    required this.playing,
    required this.onTap,
  });

  final Clip clip;
  final bool current;
  final bool past;
  final bool Function() playing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = context.frostyColors.live;
    final thumbnail = clip.thumbnailUrl;
    final title = clip.title.trim().isEmpty
        ? 'Untitled clip'
        : clip.title.trim();
    return Semantics(
      button: true,
      selected: current,
      label: '$title, ${_channelOf(clip)}, ${_views(clip)}',
      excludeSemantics: true,
      child: PressScale(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AnimatedContainer(
            duration: motionDuration(
              context,
              const Duration(milliseconds: 200),
            ),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: current
                  ? accent.withValues(alpha: 0.07)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: current
                    ? accent.withValues(alpha: 0.35)
                    : Colors.transparent,
                width: FrostyTokens.hairlineWidth,
              ),
            ),
            child: Row(
              spacing: 12,
              children: [
                SizedBox(
                  width: 136,
                  height: 76,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        const ColoredBox(color: Colors.black),
                        if (thumbnail != null)
                          Opacity(
                            opacity: past ? 0.5 : 1,
                            child: FrostyCachedNetworkImage(
                              imageUrl: thumbnail,
                              fit: BoxFit.cover,
                            ),
                          ),
                        Positioned(
                          right: 5,
                          bottom: 5,
                          child: OverlayPill(
                            height: 18,
                            radius: 5,
                            padding: 5,
                            color: const Color(0xA6000000),
                            child: Text(
                              formatVodTime(clip.duration),
                              style: FrostyType.tabular(
                                const TextStyle(
                                  fontFamily: FrostyTokens.bodyFamily,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (current)
                          Positioned(
                            left: 6,
                            bottom: 6,
                            child: _PlayingBars(playing: playing),
                          ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 3,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: FrostyTokens.bodyFamily,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                          color: FrostyTokens.textPrimaryDark,
                        ),
                      ),
                      Text(
                        '${_channelOf(clip)} · ${_views(clip)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: FrostyType.tabular(
                          const TextStyle(
                            fontFamily: FrostyTokens.bodyFamily,
                            fontSize: 12,
                            color: FrostyTokens.textSecondaryDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Three signal bars on the clip playing (still when it is paused, under
/// reduce motion, or off screen).
class _PlayingBars extends StatefulWidget {
  const _PlayingBars({required this.playing});

  final bool Function() playing;

  @override
  State<_PlayingBars> createState() => _PlayingBarsState();
}

class _PlayingBarsState extends State<_PlayingBars>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.frostyColors.live;
    return Observer(
      builder: (context) {
        final moving = widget.playing() && !reduceMotionOf(context);
        if (moving && !_controller.isAnimating) {
          unawaited(_controller.repeat());
        } else if (!moving && _controller.isAnimating) {
          _controller.stop();
        }
        return RepaintBoundary(
          child: Container(
            height: 18,
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(5),
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                spacing: 2,
                children: [
                  for (final delay in const [0.0, 1 / 3, 2 / 3])
                    Container(
                      width: 2,
                      height:
                          10 *
                          (0.35 +
                              0.65 *
                                  (1 -
                                      (2 * ((_controller.value + delay) % 1) -
                                              1)
                                          .abs())),
                      decoration: BoxDecoration(
                        color: FrostyTokens.backgroundDark,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The queue's last row while more clips load.
class _QueueLoading extends StatelessWidget {
  const _QueueLoading();

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.7,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          spacing: 12,
          children: [
            SkeletonLoader(
              width: 136,
              height: 76,
              borderRadius: BorderRadius.circular(10),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 6,
                children: [
                  FractionallySizedBox(
                    widthFactor: 0.8,
                    child: SkeletonLoader(
                      height: 10,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  const Text(
                    'Loading more clips for you',
                    style: TextStyle(
                      fontFamily: FrostyTokens.bodyFamily,
                      fontSize: 12,
                      color: FrostyTokens.textTertiaryDark,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The feed loading: the video's box and the details' lines, under the
/// global sheen.
class _FeedSkeleton extends StatelessWidget {
  const _FeedSkeleton({required this.large});

  final bool large;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final radius = BorderRadius.circular(6);
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = large ? FrostySpacing.gutterTablet : 0.0;
        final width = large
            ? math.min(800.0, constraints.maxWidth - side * 2)
            : constraints.maxWidth;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            side + padding.left,
            padding.top + (large ? 20 : 24),
            side + padding.right,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 14,
            children: [
              SkeletonLoader(
                width: width,
                height: width * 9 / 16,
                borderRadius: BorderRadius.circular(large ? 20 : 0),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: large ? 4 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 10,
                  children: [
                    const SizedBox(height: 8),
                    Row(
                      spacing: 10,
                      children: [
                        const SkeletonLoader(
                          width: 42,
                          height: 42,
                          borderRadius: BorderRadius.all(Radius.circular(21)),
                        ),
                        SkeletonLoader(
                          width: 140,
                          height: 12,
                          borderRadius: radius,
                        ),
                      ],
                    ),
                    SkeletonLoader(
                      width: math.min(300.0, width - 32),
                      height: 16,
                      borderRadius: radius,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
