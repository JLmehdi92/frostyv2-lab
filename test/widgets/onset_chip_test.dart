import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/widgets/onset_chip.dart';

void main() {
  testWidgets('a screen reader can pick a chip', (tester) async {
    final handle = tester.ensureSemantics();
    var picked = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: OnsetChip(
              label: 'Clips',
              selected: false,
              onSelected: () => picked++,
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSemantics(find.byType(OnsetChip)),
      matchesSemantics(
        label: 'Clips',
        isButton: true,
        hasSelectedState: true,
        isInMutuallyExclusiveGroup: true,
        hasTapAction: true,
      ),
    );
    tester.semantics.tap(find.semantics.byLabel('Clips'));
    expect(picked, 1);
    handle.dispose();
  });

  testWidgets('the chip is 44 dp tall to the finger, its pill smaller', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: OnsetChip(
              label: '24 hours',
              selected: true,
              height: OnsetChip.filterHeight,
              onSelected: () {},
            ),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(OnsetChip)).height, 44);
    expect(
      tester.getSize(find.byType(AnimatedContainer)).height,
      OnsetChip.filterHeight,
    );
  });
}
