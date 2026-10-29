import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/widgets/adaptive_sliver_list.dart';

void main() {
  group('columnsFor', () {
    int columns(double width, {double max = 560, bool large = true}) =>
        AdaptiveSliverList.columnsFor(
          width,
          maxItemWidth: max,
          largeScreen: large,
        );

    test('a phone always gets one column', () {
      expect(columns(915, large: false), 1);
      expect(columns(360, large: false), 1);
    });

    test('a Pad 7 gets three row cards in landscape, two in portrait', () {
      expect(columns(1600), 3);
      expect(columns(1067), 2);
    });

    test('tile cards fit four in landscape, three in portrait', () {
      expect(columns(1600, max: 420), 4);
      expect(columns(1067, max: 420), 3);
    });
  });

  Future<void> pumpAt(WidgetTester tester, Size size, Widget sliver) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: CustomScrollView(slivers: [sliver])),
    );
  }

  Widget card(int index, {double height = 100}) => SizedBox(
    key: ValueKey('card$index'),
    height: height,
    child: Text('$index'),
  );

  testWidgets('a phone lays the cards out one per row', (tester) async {
    await pumpAt(
      tester,
      const Size(360, 740),
      AdaptiveSliverList(itemCount: 3, itemBuilder: (_, i) => card(i)),
    );

    expect(tester.getTopLeft(find.byKey(const ValueKey('card1'))).dy, 100);
    expect(tester.getSize(find.byKey(const ValueKey('card0'))).width, 360);
  });

  testWidgets('a tablet puts three cards side by side', (tester) async {
    final built = <int>[];
    await pumpAt(
      tester,
      const Size(1600, 1067),
      AdaptiveSliverList(
        itemCount: 4,
        itemBuilder: (_, i) {
          built.add(i);
          return card(i, height: i == 1 ? 140 : 100);
        },
      ),
    );

    final first = tester.getRect(find.byKey(const ValueKey('card0')));
    final second = tester.getRect(find.byKey(const ValueKey('card1')));
    final fourth = tester.getRect(find.byKey(const ValueKey('card3')));
    expect(first.width, closeTo(1600 / 3, 0.01));
    expect(second.top, first.top);
    expect(second.left, closeTo(first.right, 0.01));
    // The next row starts below the tallest card of the first.
    expect(fourth.top, 140);
    expect(fourth.left, 0);
    expect(built.toSet(), {0, 1, 2, 3});
  });

  testWidgets('a short last row leaves the other columns empty', (
    tester,
  ) async {
    await pumpAt(
      tester,
      const Size(1600, 1067),
      AdaptiveSliverList(itemCount: 4, itemBuilder: (_, i) => card(i)),
    );

    expect(
      tester.getSize(find.byKey(const ValueKey('card3'))).width,
      closeTo(1600 / 3, 0.01),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('only the outer columns keep the window side insets', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1600, 1067)
      ..devicePixelRatio = 1
      ..padding = const FakeViewPadding(left: 48, right: 48);
    addTearDown(tester.view.reset);
    final insets = <int, EdgeInsets>{};
    await tester.pumpWidget(
      MaterialApp(
        home: CustomScrollView(
          slivers: [
            AdaptiveSliverList(
              itemCount: 3,
              itemBuilder: (context, i) {
                insets[i] = MediaQuery.paddingOf(context);
                return const SizedBox(height: 10);
              },
            ),
          ],
        ),
      ),
    );

    expect(insets[0]!.left, 48);
    expect(insets[0]!.right, 0);
    expect(insets[1]!.left, 0);
    expect(insets[1]!.right, 0);
    expect(insets[2]!.left, 0);
    expect(insets[2]!.right, 48);
  });
}
