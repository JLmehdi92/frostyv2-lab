import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/models/celebration.dart';
import 'package:onset/screens/channel/celebrations/particles/celebration_particles.dart';
import 'package:onset/screens/channel/celebrations/particles/celebration_view.dart';
import 'package:onset/screens/channel/stores/channel_events_store.dart';
import 'package:onset/utils/context_extensions.dart';
import 'package:onset/widgets/motion/reduce_motion.dart';

/// Plays a celebration over the channel, then gets out of the way.
///
/// Twitch fires these for gifted subs and for the alert sets a streamer
/// configures. They are drawn by ONSET's own particles
/// ([CelebrationParticles]) in the app's palette, never Twitch's artwork.
///
/// Always non-interactive. A celebration that swallowed a tap on the player
/// would be worse than no celebration at all.
class CelebrationOverlay extends StatelessWidget {
  final ChannelEventsStore store;

  const CelebrationOverlay({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        // Twitch has this switch too (`celebrations_switch` in its resources):
        // a full-screen animation on every gifted sub is not for everyone.
        final settings = context.settingsStore;
        final celebration = store.celebration;
        // Off, or Subtle (nothing covers the video; the channel says it in
        // chat, see feedSubtleCelebrations): a celebration cut short by the
        // switch is over, never kept to replay when it is switched back.
        if (!settings.showCelebrations ||
            settings.celebrationsSubtle(landscape: context.isLandscape)) {
          if (celebration != null) _clearAfterFrame(context, celebration);
          return const SizedBox.shrink();
        }

        if (celebration == null) return const SizedBox.shrink();

        return IgnorePointer(
          child: _CelebrationPlayer(
            // Keyed on the event so a second celebration restarts the
            // animation instead of resuming the previous one mid-flight.
            key: ValueKey(celebration.eventId ?? celebration.hashCode),
            celebration: celebration,
            onFinished: store.clearCelebration,
            chatOnLeft: settings.landscapeChatLeftSide,
          ),
        );
      },
    );
  }

  /// Clears [celebration] once this frame is built (an observer may not
  /// change the store it reads), unless the channel closed meanwhile or
  /// another celebration came.
  void _clearAfterFrame(BuildContext context, Celebration celebration) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted && identical(store.celebration, celebration)) {
        store.clearCelebration();
      }
    });
  }
}

class _CelebrationPlayer extends StatefulWidget {
  final Celebration celebration;
  final VoidCallback onFinished;

  /// Which side the chat column sits on in landscape, so a CHAT-scoped
  /// celebration lands on the chat rather than on the player.
  final bool chatOnLeft;

  const _CelebrationPlayer({
    super.key,
    required this.celebration,
    required this.onFinished,
    required this.chatOnLeft,
  });

  @override
  State<_CelebrationPlayer> createState() => _CelebrationPlayerState();
}

class _CelebrationPlayerState extends State<_CelebrationPlayer>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  /// The one ticker of a celebration: it times the fade and the particles.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.celebration.duration,
  );

  late Animation<double> _fade;

  /// Read once, when the celebration starts: switching it mid-way does not
  /// turn a running celebration into another.
  late bool _reduceMotion;

  var _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_started) {
      _started = true;
      _reduceMotion = reduceMotionOf(context);
      if (_reduceMotion) _controller.duration = kReducedCelebrationDuration;

      // Fades the whole thing in and out, so it never appears or vanishes
      // abruptly over the video. Under reduce motion the particles flash on
      // their own, a still fade with nothing travelling.
      _fade = _reduceMotion
          ? const AlwaysStoppedAnimation(1)
          : TweenSequence<double>([
              TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 12),
              TweenSequenceItem(tween: ConstantTween(1.0), weight: 68),
              TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
            ]).animate(_controller);

      _controller.forward().whenCompleteOrCancel(() {
        // Guard: the channel can be closed mid-celebration.
        if (mounted) widget.onFinished();
      });
    }

    // Hidden (another screen on top, an offstage page): a celebration is a
    // moment, so it ends rather than waiting, paused, to replay late.
    if (!TickerMode.of(context)) _end();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Sent to the background: same — over, not kept for the return.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _end();
    }
  }

  /// Stops the celebration; its finish callback runs once, as at the end.
  void _end() {
    if (_controller.isAnimating) _controller.stop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final celebration = widget.celebration;
    final peak = celebration.intensity.opacity;
    final chatOnLeft = widget.chatOnLeft;

    return LayoutBuilder(
      builder: (context, constraints) {
        final side =
            constraints.biggest.shortestSide * celebration.intensity.scale;

        // Twitch scopes a celebration to a region, and honouring that matters:
        // a CHAT celebration spilling over the player is the difference
        // between "the app does what Twitch does" and "the app is noisy".
        //
        // The regions are derived from the layout rather than measured: in
        // landscape the chat is a column on one side, in portrait it is the
        // lower half. Both match how this screen is actually composed.
        final isLandscape = constraints.maxWidth > constraints.maxHeight;

        final alignment = switch (celebration.area) {
          CelebrationArea.chat =>
            isLandscape
                ? (chatOnLeft ? Alignment.centerLeft : Alignment.centerRight)
                : Alignment.bottomCenter,
          CelebrationArea.video =>
            isLandscape
                ? (chatOnLeft ? Alignment.centerRight : Alignment.centerLeft)
                : Alignment.topCenter,
          CelebrationArea.everywhere => Alignment.center,
        };

        return Align(
          alignment: alignment,
          child: FadeTransition(
            opacity: _fade.drive(Tween(begin: 0, end: peak)),
            child: SizedBox(
              width: side,
              height: side,
              child: CelebrationParticles(
                preset: celebration.effect.preset,
                progress: _controller,
                duration: _controller.duration!,
                seed:
                    celebration.eventId?.hashCode ??
                    identityHashCode(celebration),
                reduceMotion: _reduceMotion,
              ),
            ),
          ),
        );
      },
    );
  }
}
