import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/screens/channel/hype_train/widgets/hype_train_split_color.dart';

const _onFill = Color(0xFF0A0A0A);
const _onTrack = Color(0xFFF5F5F5);

void main() {
  Future<RenderHtSplitColor> pump(
    WidgetTester tester, {
    required ValueListenable<double>? fraction,
    TextDirection direction = TextDirection.ltr,
    double left = 50,
  }) async {
    final split = Padding(
      padding: EdgeInsetsDirectional.only(start: left),
      child: const SizedBox(
        width: 100,
        height: 20,
        child: HtSplitColor(
          onFill: _onFill,
          onTrack: _onTrack,
          child: ColoredBox(color: Colors.white),
        ),
      ),
    );
    await tester.pumpWidget(
      Directionality(
        textDirection: direction,
        child: Align(
          alignment: AlignmentDirectional.topStart,
          child: SizedBox(
            width: 200,
            height: 20,
            child: fraction == null
                ? split
                : HtFillScope(
                    fraction: fraction,
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: split,
                    ),
                  ),
          ),
        ),
      ),
    );
    return tester.renderObject<RenderHtSplitColor>(find.byType(HtSplitColor));
  }

  testWidgets('turns where the fill ends, in the box', (tester) async {
    final split = await pump(tester, fraction: const HtStillFraction(0.5));
    // The fill ends at 100 of 200; the box runs from 50 to 150.
    expect(split.split, (at: 0.5, fillOnLeft: true));
  });

  testWidgets('follows the fill as it moves', (tester) async {
    final fill = ValueNotifier(0.25);
    addTearDown(fill.dispose);
    final split = await pump(tester, fraction: fill);
    expect(split.split.at, 0);

    fill.value = 0.75;
    await tester.pump();
    expect(split.split.at, 1);
    expect(split.debugNeedsPaint, isFalse);
  });

  testWidgets('right to left the fill is on the right', (tester) async {
    final split = await pump(
      tester,
      fraction: const HtStillFraction(0.5),
      direction: TextDirection.rtl,
    );
    expect(split.split, (at: 0.5, fillOnLeft: false));
  });

  testWidgets('without a scope it is all track colour', (tester) async {
    final split = await pump(tester, fraction: null);
    expect(split.split, (at: 0.0, fillOnLeft: true));
  });

  test('a still fill equals another of the same value', () {
    expect(const HtStillFraction(0.4), const HtStillFraction(0.4));
    expect(const HtStillFraction(0.4), isNot(const HtStillFraction(0.5)));
  });
}
