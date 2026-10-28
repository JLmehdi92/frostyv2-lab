import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/main.dart' show navigatorKey;
import 'package:frosty/screens/channel/channel.dart';
import 'package:frosty/screens/channel/video/ivs_video.dart';
import 'package:frosty/stores/mini_player_store.dart';
import 'package:frosty/theme.dart';
import 'package:frosty/widgets/motion/motion.dart';
import 'package:frosty/widgets/motion/reduce_motion.dart';
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

  @override
  State<GlobalMiniPlayer> createState() => _GlobalMiniPlayerState();
}

class _GlobalMiniPlayerState extends State<GlobalMiniPlayer>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<Offset?> _offset = ValueNotifier(null);

  /// The corner the window rests in (top-right at first); null while it
  /// is dragged or flying to a corner. Kept as a corner, not a position,
  /// so that it stays in its corner when the area changes.
  MiniCorner? _corner = MiniCorner.topRight;

  late final AnimationController _snapController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
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
    _snapAnim = Tween<Offset>(begin: _offset.value ?? target, end: target)
        .animate(
          CurvedAnimation(parent: _snapController, curve: Curves.easeOutCubic),
        );
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
    _snapController.dispose();
    _offset.dispose();
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
          child: Material(
            // The one place elevation survives. Everything else in the app is
            // flat, but this window floats over arbitrary content and has to
            // read as detached from it; a hairline alone would disappear over a
            // bright thumbnail.
            elevation: 10,
            color: Colors.black,
            borderRadius: BorderRadius.circular(FrostyTokens.radiusCard),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                IvsTextureVideo(videoStore: player),
                // Gesture layer above the video: tap to restore, drag to move.
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
                        // From where it is drawn, whatever the area was.
                        _offset.value = _position(area, _offset.value);
                        _corner = null;
                      },
                      onPanUpdate: (details) {
                        _offset.value = area.clamp(
                          (_offset.value ?? area.initial) + details.delta,
                        );
                      },
                      onPanEnd: (_) {
                        _snapTo(
                          area,
                          area.nearest(_offset.value ?? area.initial),
                        );
                      },
                    ),
                  ),
                ),
                Positioned(
                  top: -4,
                  right: -4,
                  child: IconButton(
                    tooltip: 'Close mini player',
                    iconSize: 18,
                    icon: const Icon(Icons.close, color: Colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                    ),
                    onPressed: store.close,
                  ),
                ),
              ],
            ),
          ),
        );

        final miniWindow = Stack(
          children: [
            ValueListenableBuilder<Offset?>(
              valueListenable: _offset,
              builder: (context, offset, child) {
                // Kept inside when the chrome changes (another section,
                // another page): a corner stays a corner, and the window
                // glides to its new place; a drag moves it directly.
                return MiniWindowPlacement(
                  offset: _position(area, offset),
                  glide: _corner != null,
                  child: child!,
                );
              },
              child: content,
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

  void _restore(MiniPlayerStore store) {
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

  const MiniWindowPlacement({
    super.key,
    required this.offset,
    required this.glide,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<Offset>(
      tween: Tween<Offset>(end: offset),
      duration: glide && !reduceMotionOf(context)
          ? glideDuration
          : Duration.zero,
      curve: FrostyMotion.standard,
      builder: (context, value, child) =>
          Transform.translate(offset: value, child: child),
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
