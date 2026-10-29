import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/widgets/readable_width.dart';

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
