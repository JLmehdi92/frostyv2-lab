import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Opens the software keyboard the way Android does: the bottom view inset
/// grows over [frames] frames (one frame each, ~16 ms), and the bottom
/// padding (the navigation bar, [navBar] tall) shrinks as the keyboard
/// covers it, as the engine reports it (`viewPadding - viewInsets`).
Future<void> animateKeyboard(
  WidgetTester tester, {
  double height = 320,
  double navBar = 24,
  int frames = 20,
  bool open = true,
  void Function(int frame)? onFrame,
}) async {
  final view = tester.view;
  final ratio = view.devicePixelRatio;
  view.viewPadding = FakeViewPadding(bottom: navBar * ratio);
  for (var frame = 1; frame <= frames; frame++) {
    final t = Curves.easeOutCubic.transform(frame / frames);
    final inset = height * (open ? t : 1 - t);
    view.viewInsets = FakeViewPadding(bottom: inset * ratio);
    view.padding = FakeViewPadding(
      bottom: (navBar - inset).clamp(0, navBar) * ratio,
    );
    await tester.pump(const Duration(milliseconds: 16));
    onFrame?.call(frame);
  }
}

/// Counts the widget rebuilds (every [Element.rebuild], forced or dirty)
/// while [body] runs, by the widget's type and in total; [where] narrows
/// the count to the elements it accepts.
Future<RebuildCounts> countRebuilds(
  Future<void> Function() body, {
  bool Function(Element element)? where,
}) async {
  final counts = RebuildCounts._();
  final previous = debugOnRebuildDirtyWidget;
  debugOnRebuildDirtyWidget = (element, builtOnce) {
    if (where != null && !where(element)) return;
    counts._add(element.widget.runtimeType);
  };
  try {
    await body();
  } finally {
    debugOnRebuildDirtyWidget = previous;
  }
  return counts;
}

/// What [countRebuilds] saw.
class RebuildCounts {
  RebuildCounts._();

  final _byType = <Type, int>{};
  var _total = 0;

  void _add(Type type) {
    _byType[type] = (_byType[type] ?? 0) + 1;
    _total++;
  }

  /// Every rebuild counted.
  int get total => _total;

  /// The rebuilds of widgets of type [T].
  int of<T extends Widget>() => _byType[T] ?? 0;

  @override
  String toString() {
    final top = _byType.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return 'RebuildCounts(total: $_total, top: '
        '${top.take(12).map((e) => '${e.key}: ${e.value}').join(', ')})';
  }
}
