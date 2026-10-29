import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/main.dart' show navigatorKey;
import 'package:onset/screens/channel/channel.dart';
import 'package:onset/screens/channel/video/ivs_video.dart';
import 'package:onset/screens/channel/video/player_glyph.dart';
import 'package:onset/stores/mini_player_store.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/context_extensions.dart';
import 'package:onset/widgets/motion/motion.dart';
import 'package:onset/widgets/motion/reduce_motion.dart';
import 'package:provider/provider.dart';
import 'package:simple_pip_mode/actions/pip_actions_layout.dart';
import 'package:simple_pip_mode/pip_widget.dart';

/// A floating, draggable in-app mini player rendered above the whole app
/// (installed in `MaterialApp.builder`). Stays visible while the user navigates
/// so they can pick another stream; tap to restore, drag to any corner.
///
/// Dragging is driven by a [ValueNotifier] + a paint-time [Transform] so the
/// IVS platform view is never rebuilt or re-laid-out mid-drag — that keeps the
/// motion smooth instead of stuttering.
class GlobalMiniPlayer extends StatefulWidget {
  const GlobalMiniPlayer({super.key});

  /// The window's corners (board MiniLecteur).
  static const radius = 16.0;

  /// Opens the mini window's channel again (a tap on the window, a mention
  /// notice of its chat).
  static void restore(MiniPlayerStore store) {
    final login = store.userLogin;
    final userId = store.userId;
    final name = store.displayName;
    if (login == null || userId == null || name == null) return;
    // Don't close — opening the channel adopts this live player back so the
    // stream keeps playing without a reload.
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        settings: const RouteSettings(name: VideoChat.routeName),
        builder: (_) =>
            VideoChat(userId: userId, userName: name, userLogin: login),
      ),
    );
  }

  @override
  State<GlobalMiniPlayer> createState() => _GlobalMiniPlayerState();
}

class _GlobalMiniPlayerState extends State<GlobalMiniPlayer>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<Offset?> _offset = ValueNotifier(null);

  /// True while a finger moves the window: it lifts (1.04) and the four
  /// corners it can land in show (board MiniLecteur).
  final ValueNotifier<bool> _dragging = ValueNotifier(false);

  /// The corner the window rests in (top-right at first); null while it
  /// is dragged or flying to a corner. Kept as a corner, not a position,
  /// so that it stays in its corner when the area changes.
  MiniCorner? _corner = MiniCorner.topRight;

  /// Where the window was last drawn.
  Offset? _drawn;

  late final AnimationController _snapController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );

  /// The snap's curve, made once (one per release would pile listeners up
  /// on the controller).
  late final _snapCurve = CurvedAnimation(
    parent: _snapController,
    curve: Curves.easeOutCubic,
  );
  Animation<Offset>? _snapAnim;

  @override
  void initState() {
    super.initState();
    _snapController.addListener(() {
      final anim = _snapAnim;
      if (anim != null) _offset.value = anim.value;
    });
  }

  /// Smoothly animates the window to [target] (used for the release snap).
  void _snapTo(MiniWindowArea area, MiniCorner corner) {
    final target = area.at(corner);
    _snapAnim = Tween<Offset>(
      begin: _offset.value ?? target,
      end: target,
    ).animate(_snapCurve);
    _snapController
      ..reset()
      ..forward().whenCompleteOrCancel(() {
        if (mounted && _snapAnim?.value == target) _corner = corner;
      });
  }

  /// Where the window is drawn in [area].
  Offset _position(MiniWindowArea area, Offset? offset) {
    final corner = _corner;
    if (corner != null) return area.at(corner);
    return area.clamp(offset ?? area.initial);
  }

  @override
  void dispose() {
    _snapCurve.dispose();
    _snapController.dispose();
    _offset.dispose();
    _dragging.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<MiniPlayerStore>();
    return Observer(
      builder: (_) {
        final player = store.player;
        if (!store.visible || player == null) return const SizedBox.shrink();

        final area = MiniWindowArea.of(
          MediaQuery.of(context),
          chrome: store.shellChrome,
        );
        final width = area.window.width;
        final height = area.window.height;

        // Built once per Observer build — NOT rebuilt while dragging.
        final content = SizedBox(
          width: width,
          height: height,
          // The one window that floats over arbitrary content: it needs a
          // shadow as well as its hairline to read as detached from a
          // bright thumbnail (board MiniLecteur).
          child: DecoratedBox(
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.all(
                Radius.circular(GlobalMiniPlayer.radius),
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x99000000),
                  offset: Offset(0, 18),
                  blurRadius: 40,
                ),
                BoxShadow(
                  color: Color(0x80000000),
                  offset: Offset(0, 2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.all(
                Radius.circular(GlobalMiniPlayer.radius),
              ),
              child: ColoredBox(
                color: Colors.black,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    IvsTextureVideo(videoStore: player),
                    // The hairline, drawn inside the edge.
                    const IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.all(
                            Radius.circular(GlobalMiniPlayer.radius),
                          ),
                          border: Border.fromBorderSide(
                            BorderSide(
                              color: Color(0x29FFFFFF),
                              width: OnsetTokens.hairlineWidth,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Gesture layer above the video: tap to restore, drag to
                    // move.
                    Positioned.fill(
                      child: Semantics(
                        // Its own node, the size of the window: nothing above
                        // it starts one, so it would cover the whole screen.
                        container: true,
                        button: true,
                        label: 'Return to stream',
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _restore(store),
                          onPanDown: (_) {
                            _snapController.stop();
                            // From where it is drawn (mid-glide too),
                            // whatever the area was.
                            _offset.value =
                                _drawn ?? _position(area, _offset.value);
                            _corner = null;
                          },
                          onPanStart: (_) => _dragging.value = true,
                          onPanUpdate: (details) {
                            _offset.value = area.clamp(
                              (_offset.value ?? area.initial) + details.delta,
                            );
                          },
                          onPanEnd: (_) {
                            _dragging.value = false;
                            _snapTo(
                              area,
                              area.nearest(_offset.value ?? area.initial),
                            );
                          },
                          onPanCancel: () => _dragging.value = false,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: _CloseButton(onPressed: store.close),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        final reduceMotion = reduceMotionOf(context);
        final miniWindow = Stack(
          children: [
            // Where it can land, while it is dragged.
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: _CornerTargets(
                    area: area,
                    dragging: _dragging,
                    offset: _offset,
                  ),
                ),
              ),
            ),
            ValueListenableBuilder<Offset?>(
              valueListenable: _offset,
              builder: (context, offset, child) {
                // Kept inside when the chrome changes (another section,
                // another page): a corner stays a corner, and the window
                // glides to its new place; a drag moves it directly.
                return MiniWindowPlacement(
                  offset: _position(area, offset),
                  glide: _corner != null,
                  onDrawn: (drawn) => _drawn = drawn,
                  child: child!,
                );
              },
              child: ValueListenableBuilder<bool>(
                valueListenable: _dragging,
                builder: (context, dragging, child) => AnimatedScale(
                  scale: dragging && !reduceMotion ? 1.04 : 1,
                  duration: const Duration(milliseconds: 90),
                  curve: OnsetMotion.standard,
                  child: child,
                ),
                child: content,
              ),
            ),
          ],
        );

        // When the OS enters picture-in-picture while the mini player is up,
        // expand to fill the PiP surface so only the video shows (not the whole
        // app behind it). This PipWidget is only mounted while the mini is
        // visible, so it never competes with the channel screen's PipWidget.
        return PipWidget(
          pipLayout: PipActionsLayout.mediaOnlyPause,
          onPipAction: (_) => player.handlePausePlay(),
          pipChild: ColoredBox(
            color: Colors.black,
            child: IvsTextureVideo(videoStore: player),
          ),
          child: miniWindow,
        );
      },
    );
  }

  void _restore(MiniPlayerStore store) => GlobalMiniPlayer.restore(store);
}

/// Puts the mini window at [offset]. While it rests in a corner ([glide])
/// a new offset (the header or the bar changed height) is reached on the
/// standard curve instead of a jump; a drag or a snap ([glide] false)
/// moves it directly. Nothing glides under reduce motion.
class MiniWindowPlacement extends StatelessWidget {
  static const glideDuration = Duration(milliseconds: 320);

  final Offset offset;
  final bool glide;
  final Widget child;

  /// Told where the window is drawn, each frame (mid-glide included).
  final ValueChanged<Offset>? onDrawn;

  const MiniWindowPlacement({
    super.key,
    required this.offset,
    required this.glide,
    required this.child,
    this.onDrawn,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<Offset>(
      tween: Tween<Offset>(end: offset),
      duration: glide && !reduceMotionOf(context)
          ? glideDuration
          : Duration.zero,
      curve: OnsetMotion.standard,
      builder: (context, value, child) {
        onDrawn?.call(value);
        return Transform.translate(offset: value, child: child);
      },
      child: child,
    );
  }
}

/// Where the mini window may sit: [margin] from the screen's sides, under
/// the header and above the bottom bar ([chrome], from the navigation
/// shell), or under a standard app bar on any other page.
@immutable
class MiniWindowArea {
  static const margin = 12.0;
  static const widthFraction = 0.42;

  final Size screen;
  final Size window;

  /// The range of the window's top edge.
  final double top;
  final double bottom;

  const MiniWindowArea._({
    required this.screen,
    required this.window,
    required this.top,
    required this.bottom,
  });

  factory MiniWindowArea.of(MediaQueryData media, {EdgeInsets? chrome}) {
    final screen = media.size;
    final width = screen.width * widthFraction;
    final window = Size(width, width * 9 / 16);
    final cover =
        chrome ??
        EdgeInsets.only(
          top: media.padding.top + kToolbarHeight,
          bottom: media.padding.bottom,
        );
    final top = cover.top + margin;
    // A screen too short for both: the header wins, the window may then
    // touch the bar.
    final bottom = math.max(
      top,
      screen.height - window.height - cover.bottom - margin,
    );
    return MiniWindowArea._(
      screen: screen,
      window: window,
      top: top,
      bottom: bottom,
    );
  }

  double get _left => margin;
  double get _right => math.max(margin, screen.width - window.width - margin);

  /// The top-right corner, where the window first shows.
  Offset get initial => at(MiniCorner.topRight);

  Offset clamp(Offset offset) =>
      Offset(offset.dx.clamp(_left, _right), offset.dy.clamp(top, bottom));

  /// Where [corner] is in this area.
  Offset at(MiniCorner corner) =>
      Offset(corner.left ? _left : _right, corner.top ? top : bottom);

  /// The corner nearest to [offset].
  MiniCorner nearest(Offset offset) {
    final left = offset.dx + window.width / 2 < screen.width / 2;
    final up = offset.dy + window.height / 2 < screen.height / 2;
    return MiniCorner.values.firstWhere((c) => c.left == left && c.top == up);
  }

  /// The corner nearest to [offset], as a position.
  Offset snap(Offset offset) => at(nearest(offset));
}

/// A corner of [MiniWindowArea].
enum MiniCorner {
  topLeft(left: true, top: true),
  topRight(left: false, top: true),
  bottomLeft(left: true, top: false),
  bottomRight(left: false, top: false);

  const MiniCorner({required this.left, required this.top});

  final bool left;
  final bool top;
}

/// "Close mini player": a 26 dp disc of black 62 % in the top-right corner,
/// inside a 44 dp target (board MiniLecteur).
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Close mini player',
      child: Semantics(
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: SizedBox.square(
            dimension: 44,
            child: Align(
              alignment: Alignment.topRight,
              child: Container(
                width: 26,
                height: 26,
                margin: const EdgeInsets.only(top: 6, right: 6),
                decoration: const BoxDecoration(
                  color: Color(0x9E000000),
                  shape: BoxShape.circle,
                  border: Border.fromBorderSide(
                    BorderSide(
                      color: Color(0x2EFFFFFF),
                      width: OnsetTokens.hairlineWidth,
                    ),
                  ),
                ),
                child: const Center(
                  child: PlayerGlyph(
                    PlayerGlyphKind.close,
                    color: Colors.white,
                    size: 14,
                    strokeWidth: 2.4,
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

/// The four corners the dragged window can land in, dashed, the nearest
/// in the signal colour (board MiniLecteur).
class _CornerTargets extends StatelessWidget {
  const _CornerTargets({
    required this.area,
    required this.dragging,
    required this.offset,
  });

  final MiniWindowArea area;
  final ValueListenable<bool> dragging;
  final ValueListenable<Offset?> offset;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: dragging,
      builder: (context, dragging, _) {
        if (!dragging) return const SizedBox.shrink();
        return ValueListenableBuilder<Offset?>(
          valueListenable: offset,
          builder: (context, offset, _) => CustomPaint(
            painter: _CornerTargetsPainter(
              area: area,
              nearest: area.nearest(offset ?? area.initial),
              accent: context.onsetColors.live,
            ),
          ),
        );
      },
    );
  }
}

/// How a landing corner's dashes are stroked, bottom first: a dark halo,
/// then the light line (the signal for the nearest corner), so the corners
/// read over a dark stream and a light page alike.
List<(Color, double)> cornerTargetStrokes({
  required bool nearest,
  required Color accent,
}) => [
  (const Color(0x73000000), 3.5),
  (nearest ? accent.withValues(alpha: 0.9) : const Color(0xB3FFFFFF), 1.5),
];

class _CornerTargetsPainter extends CustomPainter {
  const _CornerTargetsPainter({
    required this.area,
    required this.nearest,
    required this.accent,
  });

  final MiniWindowArea area;
  final MiniCorner nearest;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    for (final corner in MiniCorner.values) {
      final rect = area.at(corner) & area.window;
      final path = Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            rect.deflate(0.75),
            const Radius.circular(GlobalMiniPlayer.radius),
          ),
        );
      final paints = [
        for (final (color, width) in cornerTargetStrokes(
          nearest: corner == nearest,
          accent: accent,
        ))
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = width
            ..color = color,
      ];
      for (final metric in path.computeMetrics()) {
        for (var d = 0.0; d < metric.length; d += 10) {
          final dash = metric.extractPath(d, d + 6);
          for (final paint in paints) {
            canvas.drawPath(dash, paint);
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(_CornerTargetsPainter old) =>
      old.area != area || old.nearest != nearest || old.accent != accent;
}
