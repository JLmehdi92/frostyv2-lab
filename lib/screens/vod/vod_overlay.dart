import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/models/vod.dart';
import 'package:onset/screens/channel/channel.dart';
import 'package:onset/screens/channel/video/overlay_common.dart';
import 'package:onset/screens/channel/video/player_glyph.dart';
import 'package:onset/screens/channel/video/stores/caption_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/vod/player_media.dart';
import 'package:onset/screens/vod/stores/ivs_vod_store.dart';
import 'package:onset/screens/vod/vod_player_controller.dart';
import 'package:onset/screens/vod/vod_time.dart';
import 'package:onset/screens/vod/widgets/video_glyph.dart';
import 'package:onset/screens/vod/widgets/vod_seek_bar.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/context_extensions.dart';
import 'package:onset/utils/share_link.dart';
import 'package:onset/widgets/motion/motion.dart';
import 'package:onset/widgets/motion/press_scale.dart';
import 'package:onset/widgets/motion/reduce_motion.dart';
import 'package:onset/widgets/profile_picture.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';
import 'package:onset/widgets/sheet/sheet_glyph.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What is drawn over the video: always light, in either theme.
abstract final class _Over {
  static const text = OnsetTokens.textPrimaryDark;
  static const body = OnsetTokens.textBodyDark;

  /// The play disc: #0A0A0A at 42 %, a 16 % hairline.
  static const disc = Color(0x6B0A0A0A);
  static const discRing = Color(0x29FFFFFF);

  /// The speed and kind pills.
  static const pill = Color(0x990A0A0A);
  static const pillRing = Color(0x24FFFFFF);
}

/// The sizes of the boards: Rediff on a phone, RediffTablette on a tablet's
/// large player, and a smaller set for a player too short for them.
class _OverlayMetrics {
  const _OverlayMetrics({
    required this.topScrim,
    required this.bottomScrim,
    required this.edge,
    required this.disc,
    required this.discGlyph,
    required this.skip,
    required this.skipGlyph,
    required this.centerGap,
    required this.seekSide,
    required this.seekBottom,
    required this.rowSide,
    required this.rowBottom,
    required this.timeSize,
    required this.large,
  });

  static const phone = _OverlayMetrics(
    topScrim: 76,
    bottomScrim: 104,
    edge: 4,
    disc: 56,
    discGlyph: 26,
    skip: 44,
    skipGlyph: 28,
    centerGap: 28,
    seekSide: 14,
    seekBottom: 42,
    rowSide: 14,
    rowBottom: 0,
    timeSize: 12.5,
    large: false,
  );

  static const tablet = _OverlayMetrics(
    topScrim: 120,
    bottomScrim: 150,
    edge: 10,
    disc: 68,
    discGlyph: 30,
    skip: 52,
    skipGlyph: 34,
    centerGap: 40,
    seekSide: 20,
    seekBottom: 50,
    rowSide: 20,
    rowBottom: 6,
    timeSize: 13,
    large: true,
  );

  /// A short player (a small window): the controls still fit around the
  /// centre buttons.
  static const compact = _OverlayMetrics(
    topScrim: 64,
    bottomScrim: 88,
    edge: 2,
    disc: 40,
    discGlyph: 20,
    skip: 36,
    skipGlyph: 22,
    centerGap: 16,
    seekSide: 12,
    seekBottom: 40,
    rowSide: 12,
    rowBottom: 0,
    timeSize: 12,
    large: false,
  );

  final double topScrim;
  final double bottomScrim;
  final double edge;
  final double disc;
  final double discGlyph;
  final double skip;
  final double skipGlyph;
  final double centerGap;
  final double seekSide;
  final double seekBottom;
  final double rowSide;
  final double rowBottom;
  final double timeSize;
  final bool large;
}

/// Controls over the VOD (or clip) player (boards Rediff, RediffTablette,
/// Clips): back, title and channel, ±10 s and play/pause, the seek bar with
/// the copyright-muted parts, elapsed time, speed, sound, PiP, fit/fill and
/// rotation. Double-tap the left or right third to skip 10 s. Gradients
/// only: nothing is blurred over the video.
class VodOverlay extends StatefulWidget {
  const VodOverlay({
    super.key,
    required this.controller,
    required this.media,
    required this.settings,
    this.mutedSegments = const [],
    this.fillScreen,
    this.onToggleFillScreen,
    this.showChatOverlayButton = false,
    this.isLandscape = false,
    this.onCycleChatMode,
    this.skipButtons = true,
    this.looping,
    this.onToggleLoop,
  });

  final VodPlayerController controller;
  final PlayerMedia media;
  final SettingsStore settings;
  final List<MutedSegment> mutedSegments;

  /// Fit/fill state, when the engine supports it (IVS only).
  final bool? fillScreen;
  final VoidCallback? onToggleFillScreen;

  /// Landscape full screen: toggles the chat drawn over the video.
  final bool showChatOverlayButton;
  final bool isLandscape;

  /// Double-tap in the middle (landscape with chat): cycles the chat mode
  /// like live. Without it, the middle double-tap plays/pauses.
  final VoidCallback? onCycleChatMode;

  /// ±10 s buttons and side double-taps (off for short clips: a double-tap
  /// anywhere then plays/pauses or cycles the chat).
  final bool skipButtons;

  /// Loop state and toggle; the loop button shows only with [onToggleLoop].
  final bool? looping;
  final VoidCallback? onToggleLoop;

  @override
  State<VodOverlay> createState() => _VodOverlayState();
}

class _VodOverlayState extends State<VodOverlay> {
  static const _skip = Duration(seconds: 10);

  /// How long the "−10 s" / "+10 s" badge stays (board Rediff: 700 ms).
  static const _badgeTime = Duration(milliseconds: 700);

  Offset? _doubleTapAt;

  /// The "−10 s"/"+10 s" badge after a double tap (true = forward).
  bool? _skipBadgeForward;

  /// Restarts the badge's animation on every skip.
  var _skipBadgeCount = 0;
  Timer? _skipBadgeTimer;

  VodPlayerController get _c => widget.controller;

  @override
  void dispose() {
    _skipBadgeTimer?.cancel();
    super.dispose();
  }

  void _onDoubleTap(double width) {
    final x = _doubleTapAt?.dx ?? width / 2;
    if (!widget.skipButtons) {
      (widget.onCycleChatMode ?? _c.togglePlay)();
    } else if (x < width / 3) {
      _skipBy(forward: false);
    } else if (x > width * 2 / 3) {
      _skipBy(forward: true);
    } else {
      (widget.onCycleChatMode ?? _c.togglePlay)();
    }
  }

  void _skipBy({required bool forward}) {
    _c.seekBy(forward ? _skip : -_skip);
    _skipBadgeTimer?.cancel();
    setState(() {
      _skipBadgeForward = forward;
      _skipBadgeCount++;
    });
    _skipBadgeTimer = Timer(_badgeTime, () {
      if (mounted) setState(() => _skipBadgeForward = null);
    });
  }

  void _openChannel(BuildContext context) {
    final media = widget.media;
    if (media.ownerId.isEmpty || media.ownerLogin.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: VideoChat.routeName),
        builder: (context) => VideoChat(
          userId: media.ownerId,
          userName: media.ownerDisplayName,
          userLogin: media.ownerLogin,
        ),
      ),
    );
  }

  void _openSettings(BuildContext context) {
    _c.showOverlay();
    showVodSettingsSheet(context, controller: _c, media: widget.media);
  }

  _OverlayMetrics _metricsFor(BoxConstraints constraints) {
    if (constraints.maxHeight < 190) return _OverlayMetrics.compact;
    if (context.isLargeScreen &&
        constraints.maxWidth >= 600 &&
        constraints.maxHeight >= 300) {
      return _OverlayMetrics.tablet;
    }
    return _OverlayMetrics.phone;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final m = _metricsFor(constraints);
        final badgeForward = _skipBadgeForward;
        final fade = motionDuration(context, const Duration(milliseconds: 200));
        // The detector sits under the controls (not around them) so buttons
        // answer at once instead of waiting out the double-tap; the bars'
        // gradients ignore pointers, so taps on them reach the detector.
        return Stack(
          fit: StackFit.expand,
          children: [
            Observer(
              builder: (context) => VideoSurfaceSemantics(
                controlsVisible: _c.overlayVisible,
                actions: {
                  if (widget.skipButtons) ...{
                    'Back 10 seconds': () => _skipBy(forward: false),
                    'Forward 10 seconds': () => _skipBy(forward: true),
                  },
                  'Change chat layout': ?widget.onCycleChatMode,
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _c.handleVideoTap,
                  onDoubleTapDown: (d) => _doubleTapAt = d.localPosition,
                  onDoubleTap: () => _onDoubleTap(constraints.maxWidth),
                ),
              ),
            ),
            if (badgeForward != null)
              Positioned(
                left: badgeForward ? null : 34,
                right: badgeForward ? 34 : null,
                top: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: Center(
                    child: _SkipBadge(
                      key: ValueKey(_skipBadgeCount),
                      forward: badgeForward,
                      duration: _badgeTime,
                    ),
                  ),
                ),
              ),
            Observer(
              builder: (context) {
                final visible = _c.overlayVisible;
                return IgnorePointer(
                  ignoring: !visible,
                  child: AnimatedOpacity(
                    opacity: visible ? 1 : 0,
                    duration: fade,
                    child: _controls(context, m, constraints.maxHeight),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _controls(BuildContext context, _OverlayMetrics m, double height) {
    final accent = context.onsetColors.live;
    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: m.topScrim,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xC7000000), Color(0x00000000)],
                    ),
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                height: m.bottomScrim,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Color(0xD1000000), Color(0x00000000)],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Centred on the player, unless a short one would put the centre
        // buttons under the top row or the seek bar's touch band: then
        // centred between them.
        _centerSlot(m, height),
        Positioned(
          left: m.edge,
          right: m.edge,
          top: m.edge,
          child: _topRow(context, m, accent),
        ),
        Positioned(
          left: m.seekSide,
          right: m.seekSide,
          // The 40 dp touch band is centred on the board's 24 dp bar.
          bottom: m.seekBottom - 8,
          child: Observer(
            builder: (context) => VodSeekBar(
              position: _c.position,
              duration: _c.duration,
              buffered: _c.buffered,
              mutedSegments: widget.mutedSegments,
              onSeek: _c.seekTo,
              onScrubbing: (scrubbing) {
                if (scrubbing) _c.showOverlay();
              },
            ),
          ),
        ),
        Positioned(
          left: m.rowSide,
          right: m.edge,
          bottom: m.rowBottom,
          height: 44,
          child: _bottomRow(context, m, accent),
        ),
      ],
    );
  }

  Widget _centerSlot(_OverlayMetrics m, double height) {
    final top = m.edge + 44;
    final bottom = m.seekBottom - 8 + 40;
    final half = math.max(m.disc, m.skip) / 2;
    final clear =
        height / 2 - half >= top && height / 2 + half <= height - bottom;
    return Positioned(
      left: 0,
      right: 0,
      top: clear ? 0 : top,
      bottom: clear ? 0 : bottom,
      child: Center(child: _center(m)),
    );
  }

  Widget _topRow(BuildContext context, _OverlayMetrics m, Color accent) {
    final media = widget.media;
    final kind = media.kindLabel;
    final title = Text(
      media.title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: OnsetTokens.bodyFamily,
        color: _Over.text,
        fontSize: m.large ? 15 : 14,
        fontWeight: m.large ? FontWeight.w700 : FontWeight.w600,
        height: 1.25,
        shadows: kPlayerChromeShadow,
      ),
    );
    final channel = Text(
      media.ownerDisplayName,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontFamily: OnsetTokens.bodyFamily,
        color: _Over.body,
        fontSize: 12,
        height: 1.25,
        shadows: kPlayerChromeShadow,
      ),
    );
    final hasOwner = media.ownerLogin.isNotEmpty;
    final Widget identity;
    if (m.large) {
      identity = Row(
        spacing: 10,
        children: [
          if (hasOwner)
            Container(
              padding: const EdgeInsets.all(1),
              decoration: const ShapeDecoration(
                shape: CircleBorder(side: BorderSide(color: Color(0x4DFFFFFF))),
              ),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
                child: ProfilePicture(userLogin: media.ownerLogin, radius: 14),
              ),
            ),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [title, if (hasOwner) channel],
            ),
          ),
        ],
      );
    } else {
      identity = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        spacing: 2,
        children: [
          title,
          if (hasOwner)
            Row(
              spacing: 6,
              children: [
                ProfilePicture(userLogin: media.ownerLogin, radius: 8),
                Flexible(child: channel),
              ],
            ),
        ],
      );
    }

    return Row(
      spacing: m.large ? 10 : 2,
      children: [
        _OverlayButton(
          tooltip: 'Back',
          glyph: VideoGlyphKind.back,
          glyphSize: 22,
          strokeWidth: 2,
          onPressed: () => Navigator.maybePop(context),
        ),
        // Only the title and the channel open it: a tap beside them (the
        // gradient band) reaches the video like anywhere else.
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Semantics(
              button: true,
              label: 'Open ${media.ownerDisplayName}',
              excludeSemantics: true,
              child: GestureDetector(
                onTap: () => _openChannel(context),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    widthFactor: 1,
                    child: identity,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (m.large && kind != null) _KindPill(label: kind),
        if (widget.showChatOverlayButton)
          Observer(
            builder: (context) {
              final shown = widget.settings.fullScreenChatOverlay;
              return Tooltip(
                message: shown ? 'Hide chat overlay' : 'Show chat overlay',
                child: Semantics(
                  selected: shown,
                  child: _PlainButton(
                    onPressed: () =>
                        widget.settings.fullScreenChatOverlay = !shown,
                    child: PlayerGlyph(
                      PlayerGlyphKind.chatBubble,
                      color: shown ? accent : _Over.text,
                      shadow: true,
                    ),
                  ),
                ),
              );
            },
          ),
        if (widget.onToggleLoop != null)
          _OverlayButton(
            tooltip: widget.looping == true ? 'Stop looping' : 'Loop',
            glyph: VideoGlyphKind.loop,
            strokeWidth: 1.9,
            selected: widget.looping == true,
            color: widget.looping == true ? accent : _Over.text,
            onPressed: widget.onToggleLoop,
          ),
        _OverlayButton(
          tooltip: 'Settings',
          glyph: VideoGlyphKind.settings,
          onPressed: () => _openSettings(context),
        ),
      ],
    );
  }

  Widget _center(_OverlayMetrics m) {
    return Observer(
      builder: (context) {
        final ended = _c.ended;
        final paused = _c.paused;
        final label = ended
            ? 'Replay'
            : paused
            ? 'Play'
            : 'Pause';
        return Row(
          mainAxisSize: MainAxisSize.min,
          spacing: m.centerGap,
          children: [
            if (widget.skipButtons)
              _OverlayButton(
                tooltip: 'Back 10 seconds',
                glyph: VideoGlyphKind.replay10,
                size: m.skip,
                glyphSize: m.skipGlyph,
                strokeWidth: m.large ? 1.7 : 1.8,
                below: false,
                onPressed: () => _c.seekBy(-_skip),
              ),
            _PlayDisc(
              label: label,
              size: m.disc,
              glyph: ended
                  ? VideoGlyphKind.replay
                  : paused
                  ? VideoGlyphKind.play
                  : VideoGlyphKind.pause,
              glyphSize: m.discGlyph,
              onPressed: _c.togglePlay,
            ),
            if (widget.skipButtons)
              _OverlayButton(
                tooltip: 'Forward 10 seconds',
                glyph: VideoGlyphKind.forward10,
                size: m.skip,
                glyphSize: m.skipGlyph,
                strokeWidth: m.large ? 1.7 : 1.8,
                below: false,
                onPressed: () => _c.seekBy(_skip),
              ),
          ],
        );
      },
    );
  }

  Widget _bottomRow(BuildContext context, _OverlayMetrics m, Color accent) {
    return Observer(
      builder: (context) {
        final rate = _c.playbackRate;
        final silent = _c.muted || _c.volume == 0;
        final elapsed = formatVodTime(_c.position);
        final total = formatVodTime(_c.duration);
        return Row(
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  '$elapsed / $total',
                  semanticsLabel: 'Elapsed time $elapsed of $total',
                  style: TextStyle(
                    fontFamily: OnsetTokens.bodyFamily,
                    color: _Over.text,
                    fontSize: m.timeSize,
                    fontWeight: FontWeight.w600,
                    shadows: kPlayerChromeShadow,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
            if (rate != 1.0)
              Padding(
                padding: EdgeInsetsDirectional.only(start: m.large ? 10 : 8),
                child: _SpeedPill(
                  rate: rate,
                  large: m.large,
                  onTap: () => _openSettings(context),
                ),
              ),
            const Spacer(),
            _OverlayButton(
              tooltip: _c.muted ? 'Unmute' : 'Mute',
              glyph: silent ? VideoGlyphKind.muted : VideoGlyphKind.volume,
              below: false,
              onPressed: _c.toggleMute,
            ),
            if (Platform.isAndroid)
              _OverlayButton(
                tooltip: 'Picture-in-picture',
                glyph: VideoGlyphKind.pip,
                below: false,
                onPressed: _c.requestPictureInPicture,
              ),
            // Fit/fill only matters in landscape, as on live.
            if (widget.onToggleFillScreen != null && widget.isLandscape)
              _OverlayButton(
                tooltip: widget.fillScreen == true
                    ? 'Fit to screen'
                    : 'Fill screen',
                glyph: VideoGlyphKind.fillScreen,
                selected: widget.fillScreen == true,
                color: widget.fillScreen == true ? accent : _Over.text,
                below: false,
                onPressed: widget.onToggleFillScreen,
              ),
            _OverlayButton(
              tooltip: widget.isLandscape ? 'Exit full screen' : 'Full screen',
              glyph: widget.isLandscape
                  ? VideoGlyphKind.exitFullscreen
                  : VideoGlyphKind.fullscreen,
              below: false,
              onPressed: () async {
                if (widget.isLandscape) {
                  exitToPortrait();
                } else {
                  await enterLandscape();
                }
              },
            ),
          ],
        );
      },
    );
  }
}

/// A 44 dp target with nothing drawn behind its child.
class _PlainButton extends StatelessWidget {
  const _PlainButton({
    required this.child,
    required this.onPressed,
    this.size = 44,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      enabled: onPressed != null,
      child: IconButton(
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        constraints: BoxConstraints.tightFor(width: size, height: size),
        style: IconButton.styleFrom(
          foregroundColor: _Over.text,
          highlightColor: const Color(0x1FFFFFFF),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: child,
      ),
    );
  }
}

/// A control over the video: a board glyph with its soft shadow in a 44 dp
/// (or [size]) target.
class _OverlayButton extends StatelessWidget {
  const _OverlayButton({
    required this.tooltip,
    required this.glyph,
    required this.onPressed,
    this.color = _Over.text,
    this.size = 44,
    this.glyphSize = 20,
    this.strokeWidth = 1.8,
    this.below = true,
    this.selected,
  });

  final String tooltip;
  final VideoGlyphKind glyph;
  final VoidCallback? onPressed;
  final Color color;
  final double size;
  final double glyphSize;
  final double strokeWidth;

  /// Top-row tips open below the button, the others above it.
  final bool below;

  /// A toggle's state, for screen readers.
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      preferBelow: below,
      child: Semantics(
        selected: selected,
        child: _PlainButton(
          size: size,
          onPressed: onPressed,
          child: VideoGlyph(
            glyph,
            color: color,
            size: glyphSize,
            strokeWidth: strokeWidth,
            shadow: true,
          ),
        ),
      ),
    );
  }
}

/// Play / pause / replay in its disc (#0A0A0A at 42 %, a 16 % hairline).
class _PlayDisc extends StatelessWidget {
  const _PlayDisc({
    required this.label,
    required this.size,
    required this.glyph,
    required this.glyphSize,
    required this.onPressed,
  });

  final String label;
  final double size;
  final VideoGlyphKind glyph;
  final double glyphSize;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final replay = glyph == VideoGlyphKind.replay;
    return Tooltip(
      message: label,
      preferBelow: false,
      child: PressScale(
        child: Material(
          color: _Over.disc,
          shape: const CircleBorder(
            side: BorderSide(
              color: _Over.discRing,
              width: OnsetTokens.hairlineWidth,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            highlightColor: const Color(0x1FFFFFFF),
            child: SizedBox.square(
              dimension: size,
              child: Center(
                child: VideoGlyph(
                  glyph,
                  color: _Over.text,
                  size: glyphSize,
                  strokeWidth: replay ? 2 : 1.8,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Past broadcast" in the tablet's top row.
class _KindPill extends StatelessWidget {
  const _KindPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const ShapeDecoration(
        color: Color(0x8C000000),
        shape: StadiumBorder(
          side: BorderSide(
            color: Color(0x29FFFFFF),
            width: OnsetTokens.hairlineWidth,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          const VideoGlyph(
            VideoGlyphKind.broadcast,
            color: _Over.body,
            size: 13,
            strokeWidth: 2,
          ),
          Text(
            label,
            style: const TextStyle(
              fontFamily: OnsetTokens.bodyFamily,
              color: _Over.body,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// The playback speed next to the time when it is not 1×; a tap opens the
/// settings.
class _SpeedPill extends StatelessWidget {
  const _SpeedPill({
    required this.rate,
    required this.onTap,
    this.large = false,
  });

  final double rate;
  final VoidCallback onTap;
  final bool large;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Playback speed',
    child: PressScale(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Center(
            child: Container(
              height: large ? 26 : 20,
              padding: EdgeInsets.symmetric(horizontal: large ? 8 : 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _Over.pill,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _Over.pillRing,
                  width: OnsetTokens.hairlineWidth,
                ),
              ),
              child: Text(
                formatPlaybackRate(rate),
                style: TextStyle(
                  fontFamily: OnsetTokens.bodyFamily,
                  color: _Over.text,
                  fontSize: large ? 12 : 11,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// "−10 s" / "+10 s" in a 72 dp disc after a side double tap: it pops in,
/// holds, then fades (board Rediff, 700 ms); a plain fade under reduce
/// motion.
class _SkipBadge extends StatelessWidget {
  const _SkipBadge({super.key, required this.forward, required this.duration});

  final bool forward;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final reduce = reduceMotionOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      builder: (context, t, child) {
        final double opacity;
        final double scale;
        if (t < 0.25) {
          final p = OnsetMotion.standard.transform(t / 0.25);
          opacity = p;
          scale = reduce ? 1 : 0.6 + 0.4 * p;
        } else if (t < 0.75) {
          opacity = 1;
          scale = 1;
        } else {
          opacity = 1 - (t - 0.75) / 0.25;
          scale = 1;
        }
        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: Container(
        width: 72,
        height: 72,
        decoration: const BoxDecoration(
          color: Color(0x8C000000),
          shape: BoxShape.circle,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 2,
          children: [
            VideoGlyph(
              forward ? VideoGlyphKind.skipForward : VideoGlyphKind.skipBack,
              color: _Over.text,
            ),
            Text(
              forward ? '+10 s' : '−10 s',
              style: const TextStyle(
                fontFamily: OnsetTokens.bodyFamily,
                color: _Over.text,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens [VodSettingsSheet] in the frame of the channel sheets.
Future<void> showVodSettingsSheet(
  BuildContext context, {
  required VodPlayerController controller,
  required PlayerMedia media,
}) => showOnsetSheet<void>(
  context: context,
  builder: (context) => VodSettingsSheet(controller: controller, media: media),
);

/// Quality, volume, captions, playback speed and share-at-time for a VOD or
/// a clip (board Rediff's sheet): quality pills, the volume slider, the
/// Closed Captions switch, a grid of speeds, then the link rows.
class VodSettingsSheet extends StatelessWidget {
  const VodSettingsSheet({
    super.key,
    required this.controller,
    required this.media,
  });

  final VodPlayerController controller;
  final PlayerMedia media;

  void _pickQuality(BuildContext context, String quality) {
    controller.setQuality(quality);
    unawaited(
      SharedPreferences.getInstance().then(
        (prefs) => prefs.setString('last_stream_quality', quality),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Observer(builder: _build);

  Widget _build(BuildContext context) {
    final colors = SheetColors.of(context);
    final qualities = controller.qualities;
    final currentQuality = controller.quality;
    final rate = controller.playbackRate;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: 16,
        children: [
          if (qualities.length > 1)
            _SheetGroup(
              label: 'Quality',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final quality in qualities)
                    SheetChoicePill(
                      label: quality,
                      large: true,
                      selected: currentQuality == quality,
                      onSelected: () => _pickQuality(context, quality),
                    ),
                ],
              ),
            ),
          _SheetGroup(
            label: 'Volume',
            gap: 6,
            child: Observer(
              builder: (context) => _VolumeSlider(
                muted: controller.muted,
                volume: controller.volume,
                onToggleMute: controller.toggleMute,
                onChanged: controller.setVolume,
              ),
            ),
          ),
          if (controller case final IvsVodStore ivs)
            _CaptionsCard(captions: ivs.captions),
          _SheetGroup(
            label: 'Playback speed',
            child: _SpeedGrid(
              current: rate,
              onSelected: (rate) {
                controller.setPlaybackRate(rate);
                Navigator.pop(context);
              },
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: colors.hairline,
                  width: OnsetTokens.hairlineWidth,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _LinkRow(
                    glyph: VideoGlyphKind.link,
                    label: media.shareLabel,
                    detail: Observer(
                      builder: (context) {
                        final link = media.shareLink(controller.position);
                        final at = Uri.tryParse(link)?.queryParameters['t'];
                        if (at == null) return const SizedBox.shrink();
                        return Text(
                          '?t=$at',
                          style: SheetText.tabular(
                            SheetText.rowDetail.copyWith(
                              fontSize: 12,
                              color: colors.tertiary,
                            ),
                          ),
                        );
                      },
                    ),
                    onTap: () async {
                      final link = media.shareLink(controller.position);
                      Navigator.pop(context);
                      await Clipboard.setData(ClipboardData(text: link));
                    },
                  ),
                  _LinkRow(
                    glyph: VideoGlyphKind.share,
                    label: 'Share',
                    onTap: () async {
                      await shareLink(
                        context,
                        media.shareLink(controller.position),
                        subject: media.title,
                      );
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A labelled group of the settings sheet ("QUALITY").
class _SheetGroup extends StatelessWidget {
  const _SheetGroup({required this.label, required this.child, this.gap = 10});

  final String label;
  final Widget child;
  final double gap;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: gap,
    children: [
      SheetSectionLabel(label, padding: EdgeInsets.zero),
      child,
    ],
  );
}

/// Mute, the volume track and its percentage.
class _VolumeSlider extends StatelessWidget {
  const _VolumeSlider({
    required this.muted,
    required this.volume,
    required this.onToggleMute,
    required this.onChanged,
  });

  final bool muted;
  final double volume;
  final VoidCallback onToggleMute;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    final shown = muted ? 0.0 : volume.clamp(0.0, 1.0);
    final percent = '${(shown * 100).round()}%';
    return Row(
      spacing: 8,
      children: [
        Transform.translate(
          offset: const Offset(-10, 0),
          child: Tooltip(
            message: muted ? 'Unmute' : 'Mute',
            child: IconButton(
              onPressed: onToggleMute,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 44, height: 44),
              style: IconButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: VideoGlyph(
                muted || volume == 0
                    ? VideoGlyphKind.muted
                    : VideoGlyphKind.volume,
                color: colors.text,
              ),
            ),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              activeTrackColor: colors.text,
              inactiveTrackColor: colors.ring,
              thumbColor: colors.text,
              overlayShape: SliderComponentShape.noOverlay,
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 8,
                elevation: 2,
              ),
              tickMarkShape: SliderTickMarkShape.noTickMark,
              showValueIndicator: ShowValueIndicator.never,
            ),
            child: Slider(
              value: volume.clamp(0.0, 1.0),
              divisions: 20,
              semanticFormatterCallback: (value) => '${(value * 100).round()}%',
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            percent,
            textAlign: TextAlign.right,
            style: SheetText.tabular(
              SheetText.rowDetail.copyWith(
                fontSize: 12,
                color: colors.secondary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Twitch's "Closed Captions" switch in a card (the whole card toggles),
/// then the tracks when there are several.
class _CaptionsCard extends StatelessWidget {
  const _CaptionsCard({required this.captions});

  final CaptionStore captions;

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    final accent = SheetColors.accentOf(context);
    return Observer(
      builder: (context) {
        final on = captions.enabled;
        void toggle() {
          HapticFeedback.selectionClick();
          captions.setEnabled(!on);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              toggled: on,
              button: true,
              label: 'Closed Captions, When the stream has them',
              excludeSemantics: true,
              onTap: toggle,
              child: PressScale(
                child: Material(
                  color: colors.well,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: colors.hairline,
                      width: OnsetTokens.hairlineWidth,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: toggle,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 52),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
                        child: Row(
                          spacing: 12,
                          children: [
                            VideoGlyph(
                              VideoGlyphKind.captions,
                              color: colors.text,
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                spacing: 1,
                                children: [
                                  Text(
                                    'Closed Captions',
                                    style: SheetText.row.copyWith(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: colors.text,
                                    ),
                                  ),
                                  Text(
                                    'When the stream has them',
                                    style: SheetText.rowDetail.copyWith(
                                      fontSize: 12,
                                      color: colors.secondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IgnorePointer(
                              child: OnsetSwitch(value: on, onChanged: (_) {}),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            for (final track in captions.choices)
              Semantics(
                selected: captions.isSelected(track),
                inMutuallyExclusiveGroup: true,
                child: SheetRow(
                  label: track.name,
                  minHeight: 46,
                  trailing: captions.isSelected(track)
                      ? SheetGlyph(
                          SheetGlyphKind.check,
                          strokeWidth: 2.4,
                          color: accent,
                        )
                      : null,
                  onTap: () => captions.selectTrack(track),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// The seven speeds in a grid of four (Normal at 1×).
class _SpeedGrid extends StatelessWidget {
  const _SpeedGrid({required this.current, required this.onSelected});

  final double current;
  final ValueChanged<double> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 6.0;
        final width = ((constraints.maxWidth - gap * 3) / 4).floorToDouble();
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final rate in kVodPlaybackRates)
              SizedBox(
                width: width,
                child: _GridChip(
                  label: rate == 1.0 ? 'Normal' : formatPlaybackRate(rate),
                  selected: current == rate,
                  onTap: () => onSelected(rate),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// A 40 dp choice of the speed grid (12 dp corners).
class _GridChip extends StatelessWidget {
  const _GridChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    final accent = SheetColors.accentOf(context);
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      child: PressScale(
        child: Material(
          color: selected ? SheetColors.accentTintOf(context) : colors.raised,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: selected ? accent : colors.ring,
              width: OnsetTokens.hairlineWidth,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            child: SizedBox(
              height: 40,
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: SheetText.tabular(
                      SheetText.pill.copyWith(
                        color: selected ? accent : colors.body,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Copy link at current time" and "Share": a 48 dp row with its glyph.
class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.glyph,
    required this.label,
    required this.onTap,
    this.detail,
  });

  final VideoGlyphKind glyph;
  final String label;
  final VoidCallback onTap;
  final Widget? detail;

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          spacing: 14,
          children: [
            VideoGlyph(glyph, color: colors.text),
            Expanded(
              child: Text(
                label,
                style: SheetText.row.copyWith(fontSize: 14, color: colors.text),
              ),
            ),
            ?detail,
          ],
        ),
      ),
    );
  }
}

/// `1.25×` (trailing zeros dropped: `1.5×`, `2×`).
String formatPlaybackRate(double rate) {
  final text = rate
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
  return '$text×';
}
