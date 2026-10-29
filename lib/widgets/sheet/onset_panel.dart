import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:frosty/theme.dart';
import 'package:frosty/utils/context_extensions.dart';
import 'package:frosty/widgets/motion/motion.dart';
import 'package:frosty/widgets/motion/reduce_motion.dart';
import 'package:frosty/widgets/sheet/onset_sheet.dart';

/// Where a tablet panel sits against what opened it.
enum PanelSide { above, below, left, right }

/// A panel's place on screen: its [rect], the [side] of its anchor it is
/// on, and where its nub points ([nub], along the edge facing the anchor,
/// from the panel's top or left).
@immutable
class PanelPlacement {
  const PanelPlacement(this.rect, this.side, this.nub);

  final Rect rect;
  final PanelSide side;
  final double nub;

  @override
  bool operator ==(Object other) =>
      other is PanelPlacement &&
      other.rect == rect &&
      other.side == side &&
      other.nub == nub;

  @override
  int get hashCode => Object.hash(rect, side, nub);

  @override
  String toString() => 'PanelPlacement($rect, $side, nub: $nub)';
}

/// [value] within [low]…[high]; [high] wins when the range is empty.
double _within(double value, double low, double high) =>
    high < low ? high : value.clamp(low, high);

/// Places a [size] panel next to [anchor] on the first of [sides] where it
/// fits inside [bounds] (the screen less its system insets) without
/// covering [avoid] (the video): above or below, it lines up inside
/// [region] (the chat column) when it can; beside, it centres on the
/// anchor and slides down under [avoid]. Null when no side fits.
///
/// The boards' tablet panels (ChaineOutilsTablette): the emote menu and the
/// points above the chat input, the user card beside the chat.
PanelPlacement? placePanel({
  required Rect bounds,
  required Rect anchor,
  required Size size,
  required List<PanelSide> sides,
  Rect? region,
  Rect? avoid,
  double gap = 12,
  double margin = 12,
}) {
  final inner = bounds.deflate(margin);
  if (size.width > inner.width || size.height > inner.height) return null;
  final along = region ?? bounds;
  bool clear(Rect rect) =>
      avoid == null || avoid.isEmpty || !rect.overlaps(avoid);

  for (final side in sides) {
    switch (side) {
      case PanelSide.above:
      case PanelSide.below:
        final top = side == PanelSide.above
            ? anchor.top - gap - size.height
            : anchor.bottom + gap;
        if (top < inner.top || top + size.height > inner.bottom) continue;
        final left = _within(
          _within(
            anchor.center.dx - size.width / 2,
            along.left + margin,
            along.right - margin - size.width,
          ),
          inner.left,
          inner.right - size.width,
        );
        final rect = Rect.fromLTWH(left, top, size.width, size.height);
        if (!clear(rect)) continue;
        return PanelPlacement(
          rect,
          side,
          _within(anchor.center.dx - left, 20, size.width - 20),
        );
      case PanelSide.left:
      case PanelSide.right:
        final left = side == PanelSide.left
            ? anchor.left - gap - size.width
            : anchor.right + gap;
        if (left < inner.left || left + size.width > inner.right) continue;
        var top = _within(
          anchor.center.dy - size.height * 0.47,
          inner.top,
          inner.bottom - size.height,
        );
        var rect = Rect.fromLTWH(left, top, size.width, size.height);
        if (!clear(rect)) {
          // Under the video, when there is room for it there.
          top = math.min(avoid!.bottom + 5, inner.bottom - size.height);
          rect = Rect.fromLTWH(left, top, size.width, size.height);
          if (!clear(rect)) continue;
        }
        return PanelPlacement(
          rect,
          side,
          _within(anchor.center.dy - top, 20, size.height - 20),
        );
    }
  }
  return null;
}

/// The global rectangle of [context]'s render box, or null before layout.
Rect? globalRectOf(BuildContext context) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize || !box.attached) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}

/// The column panels line up in (the chat): wraps it, and is found from
/// any widget inside it.
class PanelRegion extends SingleChildRenderObjectWidget {
  const PanelRegion({super.key, super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => RenderPanelRegion();

  /// The region holding [context], in global coordinates.
  static Rect? of(BuildContext context) {
    final box = context.findAncestorRenderObjectOfType<RenderPanelRegion>();
    if (box == null || !box.hasSize || !box.attached) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }
}

class RenderPanelRegion extends RenderProxyBox {}

/// Remembers where the video is, so tablet panels keep it clear. The
/// channel screen puts a [PanelAvoidScope] over its layouts and a
/// [PanelAvoidTarget] around its video.
class PanelAvoidHolder {
  RenderBox? _box;

  Rect? get rect {
    final box = _box;
    if (box == null || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }
}

class PanelAvoidScope extends InheritedWidget {
  const PanelAvoidScope({
    super.key,
    required this.holder,
    required super.child,
  });

  final PanelAvoidHolder holder;

  /// The video's rectangle, read when a panel opens.
  static Rect? of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<PanelAvoidScope>()?.holder.rect;

  @override
  bool updateShouldNotify(PanelAvoidScope oldWidget) =>
      oldWidget.holder != holder;
}

class PanelAvoidTarget extends SingleChildRenderObjectWidget {
  const PanelAvoidTarget({super.key, required this.holder, super.child});

  final PanelAvoidHolder holder;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderAvoidTarget(holder);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) =>
      (renderObject as _RenderAvoidTarget).holder = holder;
}

class _RenderAvoidTarget extends RenderProxyBox {
  _RenderAvoidTarget(this._holder);

  PanelAvoidHolder _holder;

  set holder(PanelAvoidHolder value) {
    if (value == _holder) return;
    if (_holder._box == this) _holder._box = null;
    _holder = value;
    if (attached) _holder._box = this;
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _holder._box = this;
  }

  @override
  void detach() {
    if (_holder._box == this) _holder._box = null;
    super.detach();
  }
}

/// Whether what is being built sits in a tablet panel or a bottom sheet:
/// the content adapts (no handle in a panel, its own sizes).
class SheetPresentation extends InheritedWidget {
  const SheetPresentation({
    super.key,
    required this.panel,
    required super.child,
  });

  final bool panel;

  static bool isPanel(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SheetPresentation>()?.panel ??
      false;

  @override
  bool updateShouldNotify(SheetPresentation oldWidget) =>
      oldWidget.panel != panel;
}

/// A tablet's anchored panel: #181818, 20 dp corners, a thin light ring,
/// a deep shadow and the nub pointing at what opened it (no scrim, no
/// blur: the video stays as it is).
class OnsetPanelSurface extends StatelessWidget {
  const OnsetPanelSurface({
    super.key,
    required this.side,
    required this.nub,
    required this.child,
  });

  final PanelSide side;
  final double nub;
  final Widget child;

  static const _nubSize = 12.0;

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(kPanelRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.65 : 0.18),
            offset: const Offset(0, 24),
            blurRadius: 60,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.4 : 0.10),
            offset: const Offset(0, 2),
            blurRadius: 10,
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kPanelRadius),
          side: BorderSide(
            color: colors.ring,
            width: FrostyTokens.hairlineWidth,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
    // The nub: a rotated square half out of the edge facing the anchor.
    const half = _nubSize / 2;
    final nubBox = Transform.rotate(
      angle: math.pi / 4,
      child: Container(width: _nubSize, height: _nubSize, color: colors.panel),
    );
    final Positioned positioned = switch (side) {
      PanelSide.above => Positioned(
        left: nub - half,
        bottom: -half,
        child: nubBox,
      ),
      PanelSide.below => Positioned(
        left: nub - half,
        top: -half,
        child: nubBox,
      ),
      PanelSide.left => Positioned(
        right: -half,
        top: nub - half,
        child: nubBox,
      ),
      PanelSide.right => Positioned(
        left: -half,
        top: nub - half,
        child: nubBox,
      ),
    };
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: surface),
        positioned,
      ],
    );
  }
}

/// Shows [builder] in a panel anchored to [anchor] on a tablet (the first
/// of [sides] where [size] fits, clear of the video), and as a channel
/// sheet ([showOnsetSheet]) otherwise: on a phone, without an anchor, or
/// with no room for the panel.
Future<T?> showSheetOrPanel<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  required Size size,
  required List<PanelSide> sides,
  Rect? anchor,
  Rect? region,
  bool panelSheet = false,
}) {
  final screen = MediaQuery.sizeOf(context);
  final padding = MediaQuery.paddingOf(context);
  final bounds = Rect.fromLTRB(
    padding.left,
    padding.top,
    screen.width - padding.right,
    screen.height - padding.bottom,
  );
  final placement = anchor == null || !context.isLargeScreen
      ? null
      : placePanel(
          bounds: bounds,
          anchor: anchor,
          size: size,
          sides: sides,
          region: region,
          avoid: PanelAvoidScope.of(context),
        );
  if (placement == null) {
    return showOnsetSheet<T>(
      context: context,
      panel: panelSheet,
      builder: (context) =>
          SheetPresentation(panel: false, child: Builder(builder: builder)),
    );
  }
  FocusScope.of(context).unfocus();
  final navigator = Navigator.of(context);
  return navigator.push(
    _PanelRoute<T>(
      placement: placement,
      builder: builder,
      capturedThemes: InheritedTheme.capture(
        from: context,
        to: navigator.context,
      ),
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    ),
  );
}

class _PanelRoute<T> extends PopupRoute<T> {
  _PanelRoute({
    required this.placement,
    required this.builder,
    required this.capturedThemes,
    required this.barrierLabel,
  });

  final PanelPlacement placement;
  final WidgetBuilder builder;
  final CapturedThemes capturedThemes;

  @override
  final String barrierLabel;

  @override
  Color? get barrierColor => Colors.transparent;

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 220);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 160);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final rect = placement.rect;
    return capturedThemes.wrap(
      SheetPresentation(
        panel: true,
        child: Stack(
          children: [
            Positioned.fromRect(
              rect: rect,
              child: Semantics(
                scopesRoute: true,
                namesRoute: true,
                explicitChildNodes: true,
                child: OnsetPanelSurface(
                  side: placement.side,
                  nub: placement.nub,
                  child: Builder(builder: builder),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final fade = CurvedAnimation(
      parent: animation,
      curve: FrostyMotion.standard,
      reverseCurve: FrostyMotion.emphasizedAccelerate,
    );
    if (reduceMotionOf(context)) {
      return FadeTransition(opacity: fade, child: child);
    }
    // The boards' "pop": up 6 dp from 97 %, growing from the anchor.
    final rect = placement.rect;
    final origin = switch (placement.side) {
      PanelSide.above => Offset(placement.nub, rect.height),
      PanelSide.below => Offset(placement.nub, 0),
      PanelSide.left => Offset(rect.width, placement.nub),
      PanelSide.right => Offset(0, placement.nub),
    };
    return FadeTransition(
      opacity: fade,
      child: AnimatedBuilder(
        animation: fade,
        builder: (context, child) {
          final t = fade.value;
          final scale = 0.97 + 0.03 * t;
          final dy = 6 * (1 - t);
          return Transform(
            transform:
                Matrix4.translationValues(
                    rect.left + origin.dx,
                    rect.top + origin.dy + dy,
                    0,
                  )
                  ..scaleByDouble(scale, scale, 1, 1)
                  ..translateByDouble(
                    -(rect.left + origin.dx),
                    -(rect.top + origin.dy),
                    0,
                    1,
                  ),
            child: child,
          );
        },
        child: child,
      ),
    );
  }
}
