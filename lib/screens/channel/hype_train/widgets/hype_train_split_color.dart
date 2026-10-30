import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// The box a hype train fill grows in (the banner, a pill), and how far it
/// has grown: [fraction] of its width, from the start edge. [HtSplitColor]
/// below it turns its text at that edge.
class HtFillScope extends SingleChildRenderObjectWidget {
  const HtFillScope({super.key, required this.fraction, super.child});

  /// 0–1 of the width filled, as drawn (the bar's animation included).
  final ValueListenable<double> fraction;

  @override
  RenderHtFillScope createRenderObject(BuildContext context) =>
      RenderHtFillScope(
        fraction: fraction,
        textDirection: Directionality.of(context),
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderHtFillScope renderObject,
  ) => renderObject
    ..fraction = fraction
    ..textDirection = Directionality.of(context);
}

/// A fill that does not move (a pill redrawn with each value): equal to any
/// other of the same value, so a rebuild with the same fill repaints nothing.
@immutable
class HtStillFraction implements ValueListenable<double> {
  const HtStillFraction(this.value);

  @override
  final double value;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}

  @override
  bool operator ==(Object other) =>
      other is HtStillFraction && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

/// The render object of [HtFillScope].
class RenderHtFillScope extends RenderProxyBox {
  RenderHtFillScope({
    required ValueListenable<double> fraction,
    required TextDirection textDirection,
  }) : _fraction = fraction,
       _textDirection = textDirection;

  ValueListenable<double> _fraction;
  ValueListenable<double> get fraction => _fraction;
  set fraction(ValueListenable<double> value) {
    if (value == _fraction) return;
    _fraction = value;
    for (final split in _splits) {
      split._listenTo(value);
    }
  }

  TextDirection _textDirection;
  TextDirection get textDirection => _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    for (final split in _splits) {
      split.markNeedsPaint();
    }
  }

  final _splits = <RenderHtSplitColor>{};

  /// Where the fill ends, in this box's coordinates.
  double get edge {
    final filled = size.width * fraction.value.clamp(0.0, 1.0);
    return textDirection == TextDirection.ltr ? filled : size.width - filled;
  }
}

/// Paints [child] in [onFill] where the hype train fill is behind it and in
/// [onTrack] elsewhere, the colour turning exactly at the fill's edge (board
/// CadeauxHypeTrain: dark text on the fill, light on the track). Only the
/// child's shapes count: its own colours are replaced, so use it on text and
/// icons, never on pictures. Without an [HtFillScope] above it, it paints
/// the child in [onTrack].
class HtSplitColor extends SingleChildRenderObjectWidget {
  const HtSplitColor({
    super.key,
    required this.onFill,
    required this.onTrack,
    super.child,
  });

  final Color onFill;
  final Color onTrack;

  @override
  RenderHtSplitColor createRenderObject(BuildContext context) =>
      RenderHtSplitColor(onFill: onFill, onTrack: onTrack);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderHtSplitColor renderObject,
  ) => renderObject
    ..onFill = onFill
    ..onTrack = onTrack;
}

/// The render object of [HtSplitColor].
class RenderHtSplitColor extends RenderProxyBox {
  RenderHtSplitColor({required Color onFill, required Color onTrack})
    : _onFill = onFill,
      _onTrack = onTrack;

  Color _onFill;
  Color get onFill => _onFill;
  set onFill(Color value) {
    if (value == _onFill) return;
    _onFill = value;
    markNeedsPaint();
  }

  Color _onTrack;
  Color get onTrack => _onTrack;
  set onTrack(Color value) {
    if (value == _onTrack) return;
    _onTrack = value;
    markNeedsPaint();
  }

  RenderHtFillScope? _scope;
  ValueListenable<double>? _listening;

  void _listenTo(ValueListenable<double>? fraction) {
    _listening?.removeListener(markNeedsPaint);
    _listening = fraction;
    fraction?.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    var node = parent;
    while (node != null && node is! RenderHtFillScope) {
      node = node.parent;
    }
    _scope = node as RenderHtFillScope?;
    _scope?._splits.add(this);
    _listenTo(_scope?.fraction);
  }

  @override
  void detach() {
    _scope?._splits.remove(this);
    _scope = null;
    _listenTo(null);
    super.detach();
  }

  @override
  bool get alwaysNeedsCompositing => child != null;

  @override
  ShaderMaskLayer? get layer => super.layer as ShaderMaskLayer?;

  /// Where the colour turns, as a fraction of this box's width from its
  /// left edge, and which side is filled.
  @visibleForTesting
  ({double at, bool fillOnLeft}) get split {
    final scope = _scope;
    final ltr = scope == null || scope.textDirection == TextDirection.ltr;
    if (scope == null || !scope.hasSize || !hasSize || size.width <= 0) {
      return (at: ltr ? 0 : 1, fillOnLeft: ltr);
    }
    final toScope = getTransformTo(scope);
    final left = MatrixUtils.transformPoint(toScope, Offset.zero).dx;
    final right = MatrixUtils.transformPoint(toScope, Offset(size.width, 0)).dx;
    final span = right - left;
    if (span == 0) return (at: 0, fillOnLeft: ltr);
    return (at: ((scope.edge - left) / span).clamp(0.0, 1.0), fillOnLeft: ltr);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) {
      layer = null;
      return;
    }
    final (:at, :fillOnLeft) = split;
    final left = fillOnLeft ? onFill : onTrack;
    final right = fillOnLeft ? onTrack : onFill;
    final mask = layer ??= ShaderMaskLayer();
    mask
      ..shader = LinearGradient(
        colors: [left, left, right, right],
        stops: [0, at, at, 1],
      ).createShader(Offset.zero & size)
      ..maskRect = offset & size
      ..blendMode = BlendMode.srcIn;
    context.pushLayer(mask, super.paint, offset);
  }
}
