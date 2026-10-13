import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/models/vod.dart';
import 'package:frosty/screens/vod/widgets/vod_seek_bar.dart';

void main() {
  Future<List<Duration>> pump(
    WidgetTester tester, {
    Duration duration = const Duration(minutes: 100),
    Duration position = const Duration(minutes: 10),
    List<MutedSegment> muted = const [],
    List<bool>? scrubbing,
  }) async {
    final seeks = <Duration>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              child: VodSeekBar(
                position: position,
                duration: duration,
                buffered: const Duration(minutes: 20),
                mutedSegments: muted,
                onSeek: seeks.add,
                onScrubbing: scrubbing?.add,
              ),
            ),
          ),
        ),
      ),
    );
    return seeks;
  }

  VodSeekBarPainter painter(WidgetTester tester) => tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((p) => p.painter)
      .whereType<VodSeekBarPainter>()
      .single;

  testWidgets('dragging seeks once, on release, to the dragged time', (
    tester,
  ) async {
    final scrubbing = <bool>[];
    final seeks = await pump(tester, scrubbing: scrubbing);
    final bar = find.byType(VodSeekBar);
    final left = tester.getTopLeft(bar);
    final size = tester.getSize(bar);

    final gesture = await tester.startGesture(
      left + Offset(size.width * 0.1, size.height / 2),
    );
    await gesture.moveBy(const Offset(40, 0));
    await gesture.moveBy(Offset(size.width * 0.4 - 40, 0));
    await tester.pump();
    expect(seeks, isEmpty);
    expect(find.text('50:00'), findsOneWidget, reason: 'time bubble');

    await gesture.up();
    await tester.pump();

    expect(seeks, hasLength(1));
    expect(
      (seeks.single - const Duration(minutes: 50)).inSeconds.abs(),
      lessThanOrEqualTo(30),
    );
    expect(scrubbing, [true, false]);
    expect(find.text('50:00'), findsNothing);
  });

  testWidgets('a tap seeks to the tapped time', (tester) async {
    final seeks = await pump(tester);
    final bar = find.byType(VodSeekBar);

    await tester.tapAt(
      tester.getTopLeft(bar) + Offset(tester.getSize(bar).width * 0.75, 8),
    );

    expect(seeks.single.inMinutes, 75);
  });

  testWidgets('paints played, buffered and muted parts', (tester) async {
    await pump(
      tester,
      muted: const [
        MutedSegment(offset: 600, duration: 300),
        MutedSegment(offset: 3000, duration: 60),
      ],
    );

    final p = painter(tester);
    expect(p.played, closeTo(0.1, 1e-9));
    expect(p.buffered, closeTo(0.2, 1e-9));
    expect(p.mutedRanges, hasLength(2));
    expect(p.mutedRanges.first.$1, closeTo(0.1, 1e-9));
    expect(p.mutedRanges.first.$2, closeTo(0.15, 1e-9));
  });

  testWidgets('an unknown duration shows a disabled bar', (tester) async {
    final seeks = await pump(tester, duration: Duration.zero);
    final bar = find.byType(VodSeekBar);

    await tester.tapAt(tester.getCenter(bar));
    await tester.drag(bar, const Offset(100, 0));

    expect(seeks, isEmpty);
    expect(painter(tester).enabled, isFalse);
  });

  testWidgets('is announced as a slider', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester);

    expect(
      tester.getSemantics(find.byType(VodSeekBar)),
      matchesSemantics(
        label: 'Seek',
        value: '10:00 of 1:40:00',
        isSlider: true,
        hasIncreaseAction: true,
        hasDecreaseAction: true,
      ),
    );
    handle.dispose();
  });
}
