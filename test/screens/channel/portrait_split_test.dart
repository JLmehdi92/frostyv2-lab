import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/screens/channel/portrait_split.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';

void main() {
  test('a tablet can go down to 40 %, a phone keeps room for the controls', () {
    // Xiaomi Pad 7 in portrait.
    expect(minPortraitVideoScale(1067), kMinPortraitVideoScale);
    // A 360 dp phone: never narrower than 300 dp.
    expect(minPortraitVideoScale(360), closeTo(300 / 360, 1e-9));
    expect(minPortraitVideoScale(280), 1.0);
    expect(clampPortraitVideoScale(0.1, 1600), kMinPortraitVideoScale);
    expect(clampPortraitVideoScale(2, 1600), 1.0);
    expect(clampPortraitVideoScale(double.nan, 1600), 1.0);
    expect(portraitVideoHeight(1600, 1), 900);
    expect(portraitVideoHeight(1600, 0.5), 450);
    expect(portraitVideoHeight(360, 0.4) * 16 / 9, closeTo(300, 1e-9));
  });

  Future<({List<double> live, List<double> kept})> pump(
    WidgetTester tester,
    double scale,
  ) async {
    final live = <double>[];
    final kept = <double>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: PortraitSplitHandle(
              width: 1600,
              scale: scale,
              onChanged: live.add,
              onChangeEnd: kept.add,
            ),
          ),
        ),
      ),
    );
    return (live: live, kept: kept);
  }

  Future<void> drag(WidgetTester tester, List<double> moves) async {
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PortraitSplitHandle)),
    );
    await gesture.moveBy(const Offset(0, -20));
    for (final dy in moves) {
      await gesture.moveBy(Offset(0, dy));
    }
    await gesture.up();
    // Let the double-tap timer run out.
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('dragging follows the finger and keeps the size once', (
    tester,
  ) async {
    final calls = await pump(tester, 1.0);

    await drag(tester, [-100, -125]);

    expect(calls.live.length, greaterThan(1));
    expect(calls.kept, hasLength(1));
    expect(calls.kept.single, closeTo(0.75, 0.01));
  });

  testWidgets('past the limit, dragging back answers at once', (tester) async {
    final calls = await pump(tester, 1.0);

    await drag(tester, [-2000, 90]);

    expect(calls.live, contains(kMinPortraitVideoScale));
    expect(calls.kept.single, closeTo(0.5, 0.01));
  });

  testWidgets('a double tap restores full width', (tester) async {
    final calls = await pump(tester, 0.5);

    await tester.tap(find.byType(PortraitSplitHandle));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byType(PortraitSplitHandle));
    await tester.pumpAndSettle();

    expect(calls.kept, [1.0]);
    expect(find.bySemanticsLabel('Resize video'), findsOneWidget);
  });

  test('the size is saved and reset with the video settings', () {
    expect(SettingsStore.fromJson({}).portraitVideoScale, 1.0);
    final store = SettingsStore.fromJson({'portraitVideoScale': 0.6});
    expect(store.portraitVideoScale, 0.6);
    store.resetVideoSettings();
    expect(store.portraitVideoScale, 1.0);
  });
}
