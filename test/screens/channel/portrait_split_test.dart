import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/screens/channel/portrait_split.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';

void main() {
  test('the video keeps between 40 % and full width', () {
    expect(clampPortraitVideoScale(0.1), kMinPortraitVideoScale);
    expect(clampPortraitVideoScale(2), 1.0);
    expect(clampPortraitVideoScale(double.nan), 1.0);
    expect(portraitVideoHeight(1600, 1), 900);
    expect(portraitVideoHeight(1600, 0.5), 450);
  });

  Future<List<double>> pump(WidgetTester tester, double scale) async {
    final changes = <double>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: PortraitSplitHandle(
              width: 1600,
              scale: scale,
              onChanged: changes.add,
            ),
          ),
        ),
      ),
    );
    return changes;
  }

  testWidgets('dragging up makes the video smaller, down bigger', (
    tester,
  ) async {
    final changes = await pump(tester, 1.0);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PortraitSplitHandle)),
    );
    await gesture.moveBy(const Offset(0, -20));
    await gesture.moveBy(const Offset(0, -225));
    await gesture.up();

    expect(changes.last, closeTo(0.75, 0.01));
    // Never under the minimum, however far.
    final far = await tester.startGesture(
      tester.getCenter(find.byType(PortraitSplitHandle)),
    );
    await far.moveBy(const Offset(0, -20));
    await far.moveBy(const Offset(0, -2000));
    await far.up();
    expect(changes.last, kMinPortraitVideoScale);
    // Let the double-tap timer run out.
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('a double tap restores full width', (tester) async {
    final changes = await pump(tester, 0.5);

    await tester.tap(find.byType(PortraitSplitHandle));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byType(PortraitSplitHandle));
    await tester.pumpAndSettle();

    expect(changes, [1.0]);
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
