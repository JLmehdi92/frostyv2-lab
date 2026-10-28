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

SkeletonSheenPainter _painter(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find.descendant(
                of: find.byType(SkeletonLoader),
                matching: find.byType(CustomPaint),
              ),
            )
            .painter!
        as SkeletonSheenPainter;

void main() {
  testWidgets('dark: the board greys, with a moving sheen', (tester) async {
    await tester.pumpWidget(
      _host(const Center(child: SkeletonLoader(width: 120, height: 40))),
    );
    final painter = _painter(tester);
    expect(painter.base, const Color(0xFF161616));
    expect(painter.highlight, const Color(0xFF232323));
    expect(painter.sheen, isTrue);
    expect(tester.binding.transientCallbackCount, greaterThan(0));

    final before = painter.offsetAt(tester.binding.currentSystemFrameTimeStamp);
    await tester.pump(const Duration(milliseconds: 400));
    final after = painter.offsetAt(tester.binding.currentSystemFrameTimeStamp);
    expect(after, isNot(before));
  });

  testWidgets('every skeleton on screen shares one sweep', (tester) async {
    await tester.pumpWidget(
      _host(const Center(child: SkeletonLoader(width: 10, height: 10))),
    );
    await tester.pump(const Duration(milliseconds: 230));
    // Mounted later, it still sweeps in step with the first one: the phase
    // is read off the frame clock, not off its own start.
    final a = _painter(tester);
    await tester.pumpWidget(
      _host(
        const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SkeletonLoader(width: 10, height: 10),
              SkeletonLoader(width: 10, height: 10),
            ],
          ),
        ),
      ),
    );
    final painters = tester
        .widgetList<CustomPaint>(
          find.descendant(
            of: find.byType(SkeletonLoader),
            matching: find.byType(CustomPaint),
          ),
        )
        .map((p) => p.painter! as SkeletonSheenPainter)
        .toList();
    final now = tester.binding.currentSystemFrameTimeStamp;
    expect(painters[0].offsetAt(now), painters[1].offsetAt(now));
    expect(a.offsetAt(now), painters[1].offsetAt(now));
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
