import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/widgets/readable_width.dart';
import 'package:frosty/widgets/settings_page_layout.dart';

void main() {
  test('the inset centres a 720 dp column', () {
    expect(readableInset(1600), 440);
    expect(readableInset(1067), closeTo(173.5, 0.01));
    expect(readableInset(600), 0);
  });

  Future<void> pumpAt(WidgetTester tester, Size size, Widget body) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: body)));
  }

  final tiles = [
    for (var i = 0; i < 40; i++)
      ListTile(key: ValueKey('tile$i'), title: Text('Tile $i')),
  ];

  testWidgets('a tablet settings page is a centred, full-width scroller', (
    tester,
  ) async {
    await pumpAt(
      tester,
      const Size(1600, 1067),
      SettingsPageLayout(children: tiles),
    );
    final rect = tester.getRect(find.byKey(const ValueKey('tile0')));
    expect(rect.width, 720);
    expect(rect.left, 440);

    // Dragging in the side gutter scrolls the page too.
    await tester.dragFrom(const Offset(20, 600), const Offset(0, -300));
    await tester.pump();
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    expect(position.pixels, greaterThan(0));
  });

  testWidgets('a phone in landscape keeps the full width', (tester) async {
    await pumpAt(
      tester,
      const Size(915, 412),
      SettingsPageLayout(children: tiles),
    );
    expect(tester.getSize(find.byKey(const ValueKey('tile0'))).width, 915);
  });

  testWidgets('the sliver version keeps a full-width scroll view', (
    tester,
  ) async {
    await pumpAt(
      tester,
      const Size(1600, 1067),
      CustomScrollView(
        slivers: [
          SliverReadableWidth(sliver: SliverToBoxAdapter(child: tiles.first)),
        ],
      ),
    );
    expect(tester.getRect(find.byKey(const ValueKey('tile0'))).left, 440);
    expect(tester.getSize(find.byType(CustomScrollView)).width, 1600);
  });
}
