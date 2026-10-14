import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/screens/channel/video/pinch_to_fill.dart';

void main() {
  test('spread fills, close fits, a small move says nothing', () {
    expect(pinchVerdict(100, 120), isTrue);
    expect(pinchVerdict(100, 80), isFalse);
    expect(pinchVerdict(100, 105), isNull);
    expect(pinchVerdict(0, 50), isNull);
  });

  Future<List<bool>> pump(
    WidgetTester tester, {
    GestureTapCallback? onTap,
  }) async {
    final pinches = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        home: PinchToFill(
          onPinch: pinches.add,
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
}
