import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/widgets/draggable_divider.dart';

void main() {
  Future<List<double>> pump(WidgetTester tester, double width) async {
    final drags = <double>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Row(
          children: [
            DraggableDivider(
              currentWidth: width,
              maxWidth: 0.6,
              onDrag: drags.add,
            ),
          ],
        ),
      ),
    );
    return drags;
  }

  testWidgets('a screen reader resizes the chat in steps', (tester) async {
    final semantics = tester.ensureSemantics();
    final drags = await pump(tester, 0.3);

    final node = tester.getSemantics(find.bySemanticsLabel('Chat width'));
    expect(
      node,
      matchesSemantics(
        label: 'Chat width',
        isSlider: true,
        value: '30%',
        increasedValue: '35%',
        decreasedValue: '25%',
        hasIncreaseAction: true,
        hasDecreaseAction: true,
      ),
    );
    tester.semantics.performAction(
      find.semantics.byLabel('Chat width'),
      SemanticsAction.increase,
    );
    tester.semantics.performAction(
      find.semantics.byLabel('Chat width'),
      SemanticsAction.decrease,
    );
    expect(drags, [closeTo(0.35, 1e-9), closeTo(0.25, 1e-9)]);
    semantics.dispose();
  });

  testWidgets('it cannot grow past its maximum', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, 0.6);

    expect(
      tester.getSemantics(find.bySemanticsLabel('Chat width')),
      matchesSemantics(
        label: 'Chat width',
        isSlider: true,
        value: '60%',
        increasedValue: '60%',
        decreasedValue: '55%',
        hasDecreaseAction: true,
      ),
    );
    semantics.dispose();
  });
}
