import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';
import 'package:onset/widgets/motion/motion.dart';
import 'package:onset/widgets/motion/reduce_motion.dart';

/// How a [ShellPages] change enters.
enum ShellPagesMotion {
  /// Home's tabs: the new tab slides in from its side.
  lateral,

  /// The sections: the new page rises a little.
  rise,
}

/// Pages of the shell, one on screen: each is built the first time it is
/// shown and then kept (its scroll, its loaded lists), unless [keepAlive]
/// says otherwise (the clips feed stops when left). Off-screen pages are
/// [Offstage] with their tickers off. A change cross-fades on the standard
/// spring; under reduce motion it is a plain short fade.
class ShellPages<T extends Object> extends StatefulWidget {
  final List<T> pages;
  final T current;
  final Widget Function(BuildContext context, T page) builder;
  final bool Function(T page)? keepAlive;
  final ShellPagesMotion motion;

  /// Called once a change has finished: the page left is off screen.
  final VoidCallback? onSettled;

  const ShellPages({
    super.key,
    required this.pages,
    required this.current,
    required this.builder,
    this.keepAlive,
    this.motion = ShellPagesMotion.rise,
    this.onSettled,
  });

  @override
  State<ShellPages<T>> createState() => _ShellPagesState<T>();
}

class _ShellPagesState<T extends Object> extends State<ShellPages<T>>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController.unbounded(vsync: this, value: 1);
  late final _built = <T>{widget.current};
  T? _leaving;
  double _direction = 1;
  var _generation = 0;

  bool _keeps(T page) => widget.keepAlive?.call(page) ?? true;

  @override
  void didUpdateWidget(ShellPages<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _built.removeWhere((page) => !widget.pages.contains(page));
    if (widget.current == oldWidget.current) return;
    final from = widget.pages.indexOf(oldWidget.current);
    final to = widget.pages.indexOf(widget.current);
    _direction = to >= from ? 1 : -1;
    _leaving = widget.pages.contains(oldWidget.current)
        ? oldWidget.current
        : null;
    _built.add(widget.current);
    final generation = ++_generation;
    _controller.value = 0;
    final TickerFuture run;
    if (reduceMotionOf(context)) {
      run = _controller.animateTo(1, duration: FrostyMotion.reducedFade);
    } else {
      run = _controller.animateWith(
        SpringSimulation(
          FrostyMotion.springStandard,
          0,
          1,
          0,
          tolerance: const Tolerance(velocity: 0.01),
        ),
      );
    }
    run.whenCompleteOrCancel(() {
      if (!mounted || generation != _generation) return;
      _controller.value = 1;
      setState(_settle);
      widget.onSettled?.call();
    });
  }

  void _settle() {
    _leaving = null;
    _built.removeWhere((page) => page != widget.current && !_keeps(page));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = reduceMotionOf(context);
    final children = <Widget>[
      for (final page in widget.pages)
        if (_built.contains(page)) _slot(context, page, reduce),
    ];
    return Stack(fit: StackFit.expand, children: children);
  }

  Widget _slot(BuildContext context, T page, bool reduce) {
    final current = page == widget.current;
    final leaving = page == _leaving;
    final visible = current || leaving;
    return KeyedSubtree(
      key: ValueKey(page),
      child: Offstage(
        offstage: !visible,
        child: TickerMode(
          enabled: visible,
          child: IgnorePointer(
            ignoring: !current,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final t = _controller.value;
                final double opacity;
                var offset = Offset.zero;
                if (current) {
                  opacity = t.clamp(0.0, 1.0);
                  if (!reduce) {
                    final travel = 1 - t;
                    offset = widget.motion == ShellPagesMotion.lateral
                        ? Offset(24 * _direction * travel, 0)
                        : Offset(0, 8 * travel);
                  }
                } else if (leaving) {
                  opacity = (1 - t).clamp(0.0, 1.0);
                } else {
                  opacity = 1;
                }
                return Opacity(
                  opacity: opacity,
                  child: Transform.translate(offset: offset, child: child),
                );
              },
              child: ExcludeSemantics(
                excluding: !current,
                child: widget.builder(context, page),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
