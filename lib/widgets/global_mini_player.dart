import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/main.dart' show navigatorKey;
import 'package:frosty/screens/channel/channel.dart';
import 'package:frosty/screens/channel/video/ivs_video.dart';
import 'package:frosty/stores/mini_player_store.dart';
import 'package:frosty/utils/context_extensions.dart';
import 'package:provider/provider.dart';
import 'package:simple_pip_mode/actions/pip_actions_layout.dart';
import 'package:simple_pip_mode/pip_widget.dart';

/// The mini player's width: 42% of the screen, and at most 400 dp on a large
/// screen so it does not cover half of a tablet's home.
double miniPlayerWidth(double screenWidth, {required bool largeScreen}) {
  final width = screenWidth * 0.42;
  return largeScreen ? math.min(width, 400) : width;
}

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
  static const _margin = 12.0;

  final ValueNotifier<Offset?> _offset = ValueNotifier(null);

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
  void _animateTo(Offset target) {
    _snapAnim = Tween<Offset>(begin: _offset.value ?? target, end: target)
        .animate(
          CurvedAnimation(parent: _snapController, curve: Curves.easeOutCubic),
        );
    _snapController
      ..reset()
      ..forward();
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

        final media = MediaQuery.of(context);
        final screen = media.size;
        final width = miniPlayerWidth(
          screen.width,
          largeScreen: isLargeScreenSize(screen),
        );
        final height = width * 9 / 16;
        final topBound = media.padding.top + _margin;
        final defaultOffset = Offset(screen.width - width - _margin, topBound);

        Offset clampToScreen(Offset o) => Offset(
          o.dx.clamp(_margin, screen.width - width - _margin),
          o.dy.clamp(topBound, screen.height - height - _margin),
        );

        // Built once per Observer build — NOT rebuilt while dragging.
        final content = SizedBox(
          width: width,
          height: height,
          child: Material(
            elevation: 10,
            color: Colors.black,
            borderRadius: BorderRadius.circular(10),
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
                      onPanDown: (_) => _snapController.stop(),
                      onPanUpdate: (details) {
                        _offset.value = clampToScreen(
                          (_offset.value ?? defaultOffset) + details.delta,
                        );
                      },
                      onPanEnd: (_) {
                        _animateTo(
                          _snapToCorner(
                            _offset.value ?? defaultOffset,
                            screen,
                            width,
                            height,
                            topBound,
                          ),
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
                return Transform.translate(
                  offset: offset ?? defaultOffset,
                  child: child,
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

  /// Snaps the window to whichever corner it is closest to.
  Offset _snapToCorner(
    Offset current,
    Size screen,
    double w,
    double h,
    double topBound,
  ) {
    final toLeft = current.dx + w / 2 < screen.width / 2;
    final toTop = current.dy + h / 2 < screen.height / 2;
    return Offset(
      toLeft ? _margin : screen.width - w - _margin,
      toTop ? topBound : screen.height - h - _margin,
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
