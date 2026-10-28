import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/theme.dart';
import 'package:frosty/widgets/skeleton_loader.dart';

Widget _host(Widget child, {bool dark = true, bool disableAnimations = false}) {
  const themes = FrostyThemes(colorSchemeSeed: FrostyTokens.accent);
  return MaterialApp(
    theme: dark ? themes.dark : themes.light,
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Scaffold(body: child),
    ),
  );
}

RenderSkeletonSheen _painter(WidgetTester tester) => tester.renderObject(
  find.descendant(
    of: find.byType(SkeletonLoader),
    matching: find.byType(SkeletonSheenBox),
  ),
);

void main() {
  testWidgets('dark: the board greys, with a moving sheen', (tester) async {
    await tester.pumpWidget(
      _host(const Center(child: SkeletonLoader(width: 120, height: 40))),
    );
    final painter = _painter(tester);
    expect(painter.base, FrostyTokens.skeletonDark);
    expect(painter.highlight, FrostyTokens.skeletonSheenDark);
    expect(painter.sheen, isTrue);
    expect(tester.binding.transientCallbackCount, greaterThan(0));

    final before = painter.debugLastSheenOrigin;
    await tester.pump(const Duration(milliseconds: 400));
    expect(painter.debugLastSheenOrigin, isNot(before));
  });

  testWidgets('the sweep loops without a jump', (tester) async {
    await tester.pumpWidget(
      _host(const Center(child: SkeletonLoader(width: 120, height: 40))),
    );
    const period = SkeletonSheen.period;
    final start = SkeletonSheen.originAt(Duration.zero);
    final end = SkeletonSheen.originAt(
      period - const Duration(microseconds: 1),
    );
    // One loop moves the band by exactly one repeat of the gradient, so the
    // first frame of the next loop draws what the last one did.
    expect((end - start).distance, closeTo(SkeletonSheen.bandWidth, 0.01));
  });

  testWidgets('skeletons side by side show one band across them', (
    tester,
  ) async {
    // A thumbnail and the text lines next to it, at different x and y: the
    // band must sit at the same place on screen in both, not restart at
    // each box's own corner.
    await tester.pumpWidget(
      _host(
        const Padding(
          padding: EdgeInsets.only(left: 16, top: 40),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonLoader(key: Key('thumbnail'), width: 150, height: 84),
              SizedBox(width: 12),
              Padding(
                padding: EdgeInsets.only(top: 20),
                child: SkeletonLoader(key: Key('line'), width: 140, height: 14),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    RenderSkeletonSheen box(String key) => tester.renderObject(
      find.descendant(
        of: find.byKey(Key(key)),
        matching: find.byType(SkeletonSheenBox),
      ),
    );
    final thumbnail = box('thumbnail').debugLastSheenOrigin;
    final line = box('line').debugLastSheenOrigin;
    expect(thumbnail, isNotNull);
    expect(line, isNotNull);
    expect(line!.dx, closeTo(thumbnail!.dx, 0.01));
    expect(line.dy, closeTo(thumbnail.dy, 0.01));
    // And it is where the frame clock puts it, on screen.
    final expected = SkeletonSheen.originAt(
      tester.binding.currentSystemFrameTimeStamp,
    );
    expect(thumbnail.dx, closeTo(expected.dx, 0.01));
    expect(thumbnail.dy, closeTo(expected.dy, 0.01));
  });

  testWidgets('light theme keeps its own greys', (tester) async {
    await tester.pumpWidget(
      _host(
        const Center(child: SkeletonLoader(width: 120, height: 40)),
        dark: false,
      ),
    );
    final context = tester.element(find.byType(SkeletonLoader));
    expect(
      _painter(tester).base,
      Theme.of(context).colorScheme.surfaceContainer,
    );
  });

  testWidgets('reduce motion: a still block, no ticker', (tester) async {
    await tester.pumpWidget(
      _host(
        const Center(child: SkeletonLoader(width: 120, height: 40)),
        disableAnimations: true,
      ),
    );
    expect(_painter(tester).sheen, isFalse);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('off-screen: no ticker (TickerMode)', (tester) async {
    await tester.pumpWidget(
      _host(
        const TickerMode(
          enabled: false,
          child: Center(child: SkeletonLoader(width: 120, height: 40)),
        ),
      ),
    );
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('sizes itself like before', (tester) async {
    await tester.pumpWidget(
      _host(
        const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SkeletonLoader(key: Key('fixed'), width: 50, height: 10),
              SizedBox(
                width: 100,
                height: 40,
                child: SkeletonLoader(key: Key('filled')),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [SkeletonLoader(key: Key('unbounded'), height: 8)],
              ),
            ],
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(const Key('fixed'))), const Size(50, 10));
    expect(
      tester.getSize(find.byKey(const Key('filled'))),
      const Size(100, 40),
    );
    expect(
      tester.getSize(find.byKey(const Key('unbounded'))),
      const Size(0, 8),
    );
  });
}
