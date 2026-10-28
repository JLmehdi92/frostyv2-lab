import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:frosty/widgets/motion/motion.dart';
import 'package:frosty/widgets/motion/reduce_motion.dart';

/// Holds every [StaggeredEntrance] below it until [open] turns true.
///
/// The launch intro wraps the app in one, closed while it covers the screen:
/// the home screen builds (and loads its data) underneath, and its cards
/// enter only once the intro uncovers them. Entrances held by a gate use the
/// launch step ([FrostyMotion.launchStaggerStep]).
class EntranceGate extends InheritedNotifier<ValueListenable<bool>> {
  const EntranceGate({
    super.key,
    required ValueListenable<bool> open,
    required super.child,
  }) : super(notifier: open);

  static ValueListenable<bool>? _of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<EntranceGate>()?.notifier;
}

/// Groups the [StaggeredEntrance]s of one list so that only its first
/// appearance cascades in.
///
/// The rows built in the same frame as the first one form the batch and
/// cascade; a row built in any later frame (scrolled into view, added by a
/// refresh) shows at once, as lists do once they are on screen.
class StaggerScope extends StatefulWidget {
  final Widget child;

  const StaggerScope({super.key, required this.child});

  @override
  State<StaggerScope> createState() => _StaggerScopeState();
}

class _StaggerScopeState extends State<StaggerScope> {
  bool _batchStarted = false;
  bool _batchClosed = false;

  /// Whether a row mounting now belongs to the first batch.
  bool _admit() {
    if (_batchClosed) return false;
    if (!_batchStarted) {
      _batchStarted = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _batchClosed = true;
      });
    }
    return true;
  }

  @override
  Widget build(BuildContext context) =>
      _StaggerBatch(state: this, child: widget.child);
}

class _StaggerBatch extends InheritedWidget {
  final _StaggerScopeState state;

  const _StaggerBatch({required this.state, required super.child});

  @override
  bool updateShouldNotify(_StaggerBatch oldWidget) => false;
}

/// Brings [child] in the first time it appears: it rises 16 px and fades in
/// on an emphasized-decelerate curve, [index] steps after the first row.
///
/// - Plays once per mounted element: a rebuild never replays it.
/// - Under a [StaggerScope], only the list's first batch plays.
/// - Under a closed [EntranceGate], it waits for the gate.
/// - Rows past [FrostyMotion.staggerCap] enter with the last one.
/// - Reduce motion: a short fade, no travel, no stagger.
///
/// The animation is a single controller (the delay is an [Interval]), so it
/// leaves no timer behind and costs nothing once settled.
class StaggeredEntrance extends StatefulWidget {
  /// Position in the list.
  final int index;

  /// Gap between two rows; defaults to [FrostyMotion.staggerStep] (or the
  /// launch step when held by a gate).
  final Duration? step;

  /// How far the child rises, in logical pixels.
  final double offset;

  final Widget child;

  const StaggeredEntrance({
    super.key,
    required this.index,
    required this.child,
    this.step,
    this.offset = 16,
  });

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
  );

  /// Opacity, 0 → 1, after the row's delay.
  Animation<double> _progress = kAlwaysCompleteAnimation;
  bool _reduced = false;
  bool _decided = false;
  bool _heldByGate = false;
  ValueListenable<bool>? _gate;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_decided) return;
    _decided = true;

    final scope = context
        .getInheritedWidgetOfExactType<_StaggerBatch>()
        ?.state;
    if (scope != null && !scope._admit()) {
      _controller.value = 1;
      return;
    }

    _reduced = reduceMotionOf(context);
    _gate = EntranceGate._of(context);
    if (_gate != null && !_gate!.value) {
      _heldByGate = true;
      _gate!.addListener(_onGate);
      _prepare();
      return;
    }
    _prepare();
    _controller.forward();
  }

  void _prepare() {
    if (_reduced) {
      _controller.duration = FrostyMotion.reducedFade;
      _progress = _controller;
      return;
    }
    final step =
        widget.step ??
        (_heldByGate
            ? FrostyMotion.launchStaggerStep
            : FrostyMotion.staggerStep);
    final delay = step * math.min(widget.index, FrostyMotion.staggerCap);
    final total = delay + FrostyMotion.enter;
    _controller.duration = total;
    _progress = CurvedAnimation(
      parent: _controller,
      curve: Interval(
        delay.inMicroseconds / total.inMicroseconds,
        1,
        curve: FrostyMotion.emphasizedDecelerate,
      ),
    );
  }

  void _onGate() {
    if (_gate?.value != true) return;
    _gate!.removeListener(_onGate);
    _gate = null;
    if (mounted) _controller.forward();
  }

  @override
  void dispose() {
    _gate?.removeListener(_onGate);
    final progress = _progress;
    if (progress is CurvedAnimation) progress.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _progress,
      child: AnimatedBuilder(
        animation: _progress,
        builder: (context, child) => Transform.translate(
          offset: Offset(
            0,
            _reduced ? 0 : (1 - _progress.value) * widget.offset,
          ),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
