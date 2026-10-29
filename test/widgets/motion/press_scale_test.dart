import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/widgets/motion/motion.dart';
import 'package:onset/widgets/motion/press_scale.dart';

void main() {
  int taps = 0;

  Widget app({bool disableAnimations = false, bool enabled = true}) =>
      MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: PressScale(
                enabled: enabled,
                child: InkWell(
                  onTap: () => taps++,
                  child: const SizedBox(width: 200, height: 100),
                ),
              ),
            ),
          ),
        ),
      );

  double scaleOf(WidgetTester tester) => tester
      .widget<ScaleTransition>(
        find.descendant(
          of: find.byType(PressScale),
          matching: find.byType(ScaleTransition),
        ),
      )
      .scale
      .value;

  setUp(() => taps = 0);

  testWidgets('sinks to 0.97 while the finger is still down', (tester) async {
    await tester.pumpWidget(app());
    expect(scaleOf(tester), 1);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PressScale)),
    );
    await tester.pump();
    await tester.pump(OnsetMotion.pressDuration);
    expect(scaleOf(tester), closeTo(OnsetMotion.pressScale, 0.001));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(scaleOf(tester), closeTo(1, 0.001));
  });

  testWidgets('springs back from where it is when let go early', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PressScale)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    final mid = scaleOf(tester);
    expect(mid, lessThan(1));
    expect(mid, greaterThan(OnsetMotion.pressScale));

    await gesture.up();
    await tester.pump();
    // Picks up from the current value rather than jumping.
    expect(scaleOf(tester), closeTo(mid, 0.005));
    await tester.pumpAndSettle();
    expect(scaleOf(tester), closeTo(1, 0.001));
  });

  testWidgets('never steals the tap from the child', (tester) async {
    await tester.pumpWidget(app());
    await tester.tap(find.byType(PressScale));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('lets go when the finger starts a scroll', (tester) async {
    await tester.pumpWidget(app());
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PressScale)),
    );
    await tester.pump();
    await tester.pump(OnsetMotion.pressDuration);
    expect(scaleOf(tester), lessThan(1));

    await gesture.moveBy(const Offset(0, 40));
    await tester.pumpAndSettle();
    expect(scaleOf(tester), closeTo(1, 0.001));
    await gesture.up();
  });

  testWidgets('does not move under reduce motion', (tester) async {
    await tester.pumpWidget(app(disableAnimations: true));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PressScale)),
    );
    await tester.pump(OnsetMotion.pressDuration);
    expect(scaleOf(tester), 1);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('does not move when disabled', (tester) async {
    await tester.pumpWidget(app(enabled: false));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PressScale)),
    );
    await tester.pump(OnsetMotion.pressDuration);
    expect(scaleOf(tester), 1);
    await gesture.up();
  });
}
