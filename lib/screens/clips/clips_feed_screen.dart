import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/models/clip.dart';
import 'package:frosty/screens/channel/video/overlay_common.dart';
import 'package:frosty/screens/clips/clip_screen.dart';
import 'package:frosty/screens/clips/stores/clip_player_store.dart';
import 'package:frosty/screens/clips/stores/clips_feed_store.dart';
import 'package:frosty/screens/vod/vod_player_controller.dart';
import 'package:frosty/services/playback_focus.dart';
import 'package:frosty/theme.dart';
import 'package:frosty/utils/context_extensions.dart';
import 'package:intl/intl.dart';
import 'package:mobx/mobx.dart';
import 'package:simple_pip_mode/actions/pip_actions_layout.dart';
import 'package:simple_pip_mode/pip_widget.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Builds the player of a feed clip (tests pass a fake); [focused] is false
/// for the clip preloaded below the one playing.
typedef FeedPlayerFactory =
    VodPlayerController Function(Clip clip, {required bool focused});

/// The official app's vertical clips feed: Twitch's top clips, full screen,
/// one swipe per clip, a double-tap to play or pause. One clip plays at a
/// time; only the next one is preloaded (paused), every other player is let
/// go.
class ClipsFeedScreen extends StatefulWidget {
  static const routeName = 'ClipsFeedScreen';

  const ClipsFeedScreen({
    super.key,
    @visibleForTesting this.store,
    @visibleForTesting this.playerFactory,
  });

  final ClipsFeedStore? store;
  final FeedPlayerFactory? playerFactory;

  static Future<void> open(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(
      settings: const RouteSettings(name: routeName),
      builder: (context) => const ClipsFeedScreen(),
    ),
  );

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

  final _pageController = PageController();
  final _pipKey = GlobalKey<PipWidgetState>();

  /// The players alive: the current clip's and the next one's, by index.
  final _players = <int, VodPlayerController>{};
  var _index = 0;

  /// Whether the clip was playing when another player took focus.
  var _playingBeforeFocusLoss = false;

  ReactionDisposer? _disposeClipsReaction;

  bool get _hasFocus => identical(PlaybackFocus.shared.top, this);

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
    unawaited(_store.load());
  }

  VodPlayerController _createPlayer(Clip clip, {required bool focused}) {
    final factory = widget.playerFactory;
    if (factory != null) return factory(clip, focused: focused);
    return ClipPlayerStore(
      slug: clip.slug,
      clipService: context.twitchClipService,
      settingsStore: _settings,
      knownLength: clip.duration,
      focused: focused,
    );
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
      if (existing == null) {
        _players[index] = _createPlayer(
          clips[index],
          focused: current && _hasFocus,
        );
      } else if (current && _hasFocus) {
        existing
          ..setFocused(true)
          ..play();
      }
    }
    setState(() {});
  }

  void _onPageChanged(int index) {
    final previous = _players[_index];
    if (previous != null) {
      previous
        ..setFocused(false)
        ..pause();
    }
    _index = index;
    _syncPlayers();
    if (index >= _store.clips.length - 3) unawaited(_store.loadMore());
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
      _playingBeforeFocusLoss = false;
      if (_settings.keepScreenAwake) WakelockPlus.enable();
    });
  }

  Widget _video(int index) {
    final player = _players[index];
    if (player is ClipPlayerStore) return player.buildVideo(fill: false);
    return const SizedBox.expand();
  }

  Widget _buildClipPage(BuildContext context, int index) {
    final clip = _store.clips[index];
    final player = _players[index];
    final thumbnail = clip.thumbnailUrl;
    final padding = MediaQuery.paddingOf(context);
    final channel = clip.broadcasterDisplayName.isNotEmpty
        ? clip.broadcasterDisplayName
        : clip.broadcasterLogin;
    final game = clip.gameName;
    final details = [
      if (game != null && game.isNotEmpty) game,
      '${NumberFormat.compact().format(clip.viewCount)} views',
    ].join(' · ');

    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.black),
        if (thumbnail != null && player is! ClipPlayerStore)
          Image.network(
            thumbnail,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stack) => const SizedBox.shrink(),
          ),
        Semantics(
          label: 'Clip player. Double-tap to toggle play/pause',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onDoubleTap: player?.togglePlay,
            child: _video(index),
          ),
        ),
        if (player != null)
          Observer(
            builder: (context) {
              final status = player.status;
              if (status == VodPlaybackStatus.loading ||
                  status == VodPlaybackStatus.buffering) {
                return const Center(child: CircularProgressIndicator());
              }
              if (status == VodPlaybackStatus.failed ||
                  status == VodPlaybackStatus.problem) {
                return const Center(
                  child: Text(
                    "This clip can't be played here",
                    style: TextStyle(color: Colors.white),
                  ),
                );
              }
              if (player.paused && status != VodPlaybackStatus.ended) {
                return IgnorePointer(
                  child: Center(
                    child: Icon(
                      Icons.play_arrow_rounded,
                      size: 64,
                      color: Colors.white70,
                      shadows: kOverlayShadow,
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        Align(
          alignment: Alignment.bottomLeft,
          child: DecoratedBox(
            decoration: overlayGradient(fromTop: false),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16 + padding.left,
                48,
                8 + padding.right,
                16 + padding.bottom,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      spacing: 4,
                      children: [
                        Text(
                          clip.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          channel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          details,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        if (index == 0 && _store.clips.length > 1)
                          const Text(
                            'You can swipe to the next clip',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Open clip',
                    color: Colors.white,
                    icon: const Icon(Icons.open_in_full_rounded),
                    onPressed: () =>
                        ClipScreen.open(context, slug: clip.slug, clip: clip),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEndPage(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Observer(
            builder: (context) => _store.loadingMore
                ? const Column(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 16,
                    children: [
                      CircularProgressIndicator(),
                      Text(
                        'Loading more clips for you',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  )
                : const Text(
                    'That’s all for now! Check out more clips from previous '
                    'streams',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeed(BuildContext context) {
    return Observer(
      builder: (context) {
        final clips = _store.clips;
        final error = _store.error;
        if (clips.isEmpty) {
          if (_store.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 16,
              children: [
                Text(
                  error ?? 'No clips right now',
                  style: const TextStyle(color: Colors.white),
                ),
                if (error != null)
                  OutlinedButton(
                    onPressed: _store.load,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Try again'),
                  ),
              ],
            ),
          );
        }
        return PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          onPageChanged: _onPageChanged,
          // The end (or the next page loading) gets a page of its own.
          itemCount: clips.length + 1,
          itemBuilder: (context, index) => index < clips.length
              ? _buildClipPage(context, index)
              : _buildEndPage(context),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final page = AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(child: _buildFeed(context)),
            Positioned(
              top: padding.top,
              left: padding.left,
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
        ),
      ),
    );

    if (!Platform.isAndroid) return page;
    return PipWidget(
      key: _pipKey,
      pipLayout: PipActionsLayout.mediaOnlyPause,
      onPipAction: (_) => _players[_index]?.togglePlay(),
      onPipEntered: () => _players[_index]?.onPipEntered(),
      onPipExited: () => _players[_index]?.onPipExited(),
      pipChild: ColoredBox(color: Colors.black, child: _video(_index)),
      child: page,
    );
  }

  @override
  void dispose() {
    try {
      _disposeClipsReaction?.call();
      _pageController.dispose();
      // The current clip keeps its focus to the end, so disposing it also
      // turns its auto-PiP off.
      for (final player in _players.values) {
        player.dispose();
      }
      _players.clear();
    } finally {
      final wasTop = _hasFocus;
      PlaybackFocus.shared.release(this);
      if (wasTop && PlaybackFocus.shared.top == null) WakelockPlus.disable();
      super.dispose();
    }
  }
}

/// Opens the clips feed (next to the Top tabs).
class ClipsFeedButton extends StatelessWidget {
  const ClipsFeedButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Clips',
      // Fits the tab bar's height.
      visualDensity: VisualDensity.compact,
      icon: const Icon(Icons.smart_display_outlined),
      onPressed: () => ClipsFeedScreen.open(context),
    );
  }
}
