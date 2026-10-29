import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/screens/channel/video/pinch_to_fill.dart';

void main() {
  test('spread fills, close fits, a small move says nothing', () {
    expect(pinchVerdict(100, 120), isTrue);
    expect(pinchVerdict(100, 80), isFalse);
    expect(pinchVerdict(100, 105), isNull);
    expect(pinchVerdict(0, 50), isNull);
  });

  late ValueNotifier<bool> pinching;

  Future<List<bool>> pump(
    WidgetTester tester, {
    GestureTapCallback? onTap,
  }) async {
    final pinches = <bool>[];
    pinching = ValueNotifier(false);
    addTearDown(pinching.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: PinchToFill(
          onPinch: pinches.add,
          pinching: pinching,
          child: GestureDetector(
            onTap: onTap,
            child: const ColoredBox(color: Color(0xFF000000)),
          ),
        ),
      ),
    );
    return pinches;
  }

  testWidgets('two fingers spreading fill the screen once', (tester) async {
    final pinches = await pump(tester);
    final first = await tester.startGesture(
      const Offset(300, 300),
      pointer: 11,
    );
    final second = await tester.startGesture(
      const Offset(400, 300),
      pointer: 12,
    );

    await second.moveTo(const Offset(450, 300));
    await second.moveTo(const Offset(500, 300));
    await first.up();
    await second.up();

    expect(pinches, [true]);
  });

  testWidgets('two fingers closing fit the video', (tester) async {
    final pinches = await pump(tester);
    final first = await tester.startGesture(
      const Offset(200, 300),
      pointer: 21,
    );
    final second = await tester.startGesture(
      const Offset(500, 300),
      pointer: 22,
    );

    await second.moveTo(const Offset(350, 300));
    await first.up();
    await second.up();

    expect(pinches, [false]);
  });

  testWidgets('one finger is left to the other gestures', (tester) async {
    var taps = 0;
    final pinches = await pump(tester, onTap: () => taps++);

    final finger = await tester.startGesture(
      const Offset(300, 300),
      pointer: 31,
    );
    await finger.moveTo(const Offset(300, 500));
    await finger.up();
    await tester.tapAt(const Offset(300, 300));

    expect(pinches, isEmpty);
    expect(taps, 1);
  });

  testWidgets('a pinch is flagged until the next one-finger gesture', (
    tester,
  ) async {
    await pump(tester);
    final first = await tester.startGesture(
      const Offset(300, 300),
      pointer: 41,
    );
    expect(pinching.value, isFalse);
    final second = await tester.startGesture(
      const Offset(400, 300),
      pointer: 42,
    );
    expect(pinching.value, isTrue);
    await first.up();
    await second.up();
    // Still set when the gestures ending the pinch read it.
    expect(pinching.value, isTrue);

    final next = await tester.startGesture(const Offset(300, 300), pointer: 43);
    expect(pinching.value, isFalse);
    await next.up();
  });

  testWidgets('a third finger leaving does not count as a pinch', (
    tester,
  ) async {
    final pinches = await pump(tester);
    final a = await tester.startGesture(const Offset(100, 300), pointer: 51);
    final b = await tester.startGesture(const Offset(200, 300), pointer: 52);
    final c = await tester.startGesture(const Offset(600, 300), pointer: 53);

    // A lifts: B and C are 400 apart, A and B were 100 apart.
    await a.up();
    await c.moveBy(const Offset(1, 0));
    expect(pinches, isEmpty);

    // From there, spreading B and C still fills.
    await c.moveTo(const Offset(700, 300));
    expect(pinches, [true]);
    await b.up();
    await c.up();
  });
}
