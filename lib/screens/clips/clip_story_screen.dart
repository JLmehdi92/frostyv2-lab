import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart';
import 'package:onset/apis/twitch_vod_service.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/clip.dart';
import 'package:onset/screens/channel/video/overlay_common.dart';
import 'package:onset/screens/clips/stores/clip_player_store.dart';
import 'package:onset/screens/vod/vod_player_controller.dart';
import 'package:onset/screens/vod/widgets/video_back_button.dart';
import 'package:onset/screens/vod/widgets/video_glyph.dart';
import 'package:onset/screens/vod/widgets/vod_error_view.dart';
import 'package:onset/services/playback_focus.dart';
import 'package:onset/stores/mini_player_store.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/context_extensions.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

typedef ClipStoryPlayerFactory =
    VodPlayerController Function(Clip clip, {required bool portrait});

class ClipStoryScreen extends StatefulWidget {
  const ClipStoryScreen({
    super.key,
    required this.clips,
    required this.title,
    this.subtitle,
    this.portrait = false,
    this.actions = const [],
    this.playerFactory,
  });

  static const nextKey = ValueKey('clip-story-next');
  static const previousKey = ValueKey('clip-story-previous');

  final List<Clip> clips;
  final String title;
  final String? subtitle;
  final bool portrait;
  final List<Widget> actions;
  final ClipStoryPlayerFactory? playerFactory;

  static Future<void> open(
    BuildContext context, {
    required List<Clip> clips,
    required String title,
    String? subtitle,
    bool portrait = false,
    List<Widget> actions = const [],
    String routeName = 'ClipStoryScreen',
  }) => Navigator.push(
    context,
    MaterialPageRoute(
      settings: RouteSettings(name: routeName),
      builder: (context) => ClipStoryScreen(
        clips: clips,
        title: title,
        subtitle: subtitle,
        portrait: portrait,
        actions: actions,
      ),
    ),
  );

  @override
  State<ClipStoryScreen> createState() => _ClipStoryScreenState();
}

class _ClipStoryScreenState extends State<ClipStoryScreen> {
  var _index = 0;
  late VodPlayerController _player;
  ReactionDisposer? _endWatcher;

  @override
  void initState() {
    super.initState();
    context.read<MiniPlayerStore?>()?.close();
    PlaybackFocus.shared
      ..register(this, onLost: () => _player.pause(), onRegained: () {})
      ..claim(this);
    unawaited(WakelockPlus.enable().onError((_, _) {}));
    _player = _build(widget.clips.first);
    _watchEnd();
  }

  VodPlayerController _build(Clip clip) {
    final factory = widget.playerFactory;
    if (factory != null) return factory(clip, portrait: widget.portrait);
    return ClipPlayerStore(
      slug: clip.slug,
      clipService: context.twitchClipService,
      settingsStore: context.settingsStore,
      portrait: widget.portrait,
      knownLength: clip.duration,
    );
  }

  void _watchEnd() {
    _endWatcher?.call();
    final player = _player;
    _endWatcher = reaction<bool>((_) => player.ended, (ended) {
      if (ended && identical(player, _player)) _go(_index + 1);
    });
  }

  void _go(int index) {
    if (index < 0 || index >= widget.clips.length || index == _index) return;
    final old = _player;
    setState(() {
      _index = index;
      _player = _build(widget.clips[index]);
    });
    _watchEnd();
    old.dispose();
  }

  void _retry() {
    final old = _player;
    setState(() => _player = _build(widget.clips[_index]));
    _watchEnd();
    old.dispose();
  }

  @override
  void dispose() {
    _endWatcher?.call();
    _player.dispose();
    final wasTop = identical(PlaybackFocus.shared.top, this);
    PlaybackFocus.shared.release(this);
    if (wasTop && PlaybackFocus.shared.top == null) {
      unawaited(WakelockPlus.disable().onError((_, _) {}));
    }
    super.dispose();
  }

  Widget _video() {
    final player = _player;
    final video = player is ClipPlayerStore
        ? player.buildVideo(fill: false)
        : const ColoredBox(color: Colors.black);
    return Center(
      child: AspectRatio(
        aspectRatio: widget.portrait ? 9 / 16 : 16 / 9,
        child: video,
      ),
    );
  }

  Widget _segments() => Row(
    spacing: 4,
    children: [
      for (var i = 0; i < widget.clips.length; i++)
        Expanded(
          child: Container(
            height: 3,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: i <= _index
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.3),
            ),
          ),
        ),
    ],
  );

  Widget _tapZone({
    required Key key,
    required int target,
    required String label,
  }) => Expanded(
    child: Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        key: key,
        behavior: HitTestBehavior.translucent,
        onTap: () => _go(target),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final clip = widget.clips[_index];
    final clipTitle = clip.title.trim().isEmpty
        ? l.clipUntitled
        : clip.title.trim();
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              _video(),
              Observer(
                builder: (context) {
                  final player = _player;
                  final problem = player.problem;
                  if (player.status == VodPlaybackStatus.problem &&
                      problem != null) {
                    return VodErrorView(
                      problem: problem,
                      subject: PlaybackSubject.clip,
                      onRetry: _retry,
                    );
                  }
                  if (player.status == VodPlaybackStatus.failed) {
                    return VodErrorView(
                      problem: VodPlaybackProblem.unknown,
                      subject: PlaybackSubject.clip,
                      onRetry: _retry,
                    );
                  }
                  return Row(
                    children: [
                      _tapZone(
                        key: ClipStoryScreen.previousKey,
                        target: _index - 1,
                        label: l.clipStoryPrevious,
                      ),
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: player.togglePlay,
                          child: Center(
                            child: AnimatedOpacity(
                              opacity: player.paused && !player.ended ? 1 : 0,
                              duration: const Duration(milliseconds: 180),
                              child: const VideoGlyph(
                                VideoGlyphKind.play,
                                color: Colors.white,
                                size: 44,
                                shadow: true,
                              ),
                            ),
                          ),
                        ),
                      ),
                      _tapZone(
                        key: ClipStoryScreen.nextKey,
                        target: _index + 1,
                        label: l.clipStoryNext,
                      ),
                    ],
                  );
                },
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 6,
                    children: [
                      if (widget.clips.length > 1) _segments(),
                      Row(
                        children: [
                          const VideoBackButton(),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: OnsetTokens.bodyFamily,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    shadows: kPlayerChromeShadow,
                                  ),
                                ),
                                Text(
                                  widget.subtitle ?? clipTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: OnsetTokens.bodyFamily,
                                    fontSize: 12.5,
                                    color: Colors.white.withValues(alpha: 0.8),
                                    shadows: kPlayerChromeShadow,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ...widget.actions,
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
