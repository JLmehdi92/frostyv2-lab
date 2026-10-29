import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/widgets/motion/motion.dart';
import 'package:onset/widgets/motion/staggered_entrance.dart';

Finder _entrance(Key key) =>
    find.descendant(of: find.byKey(key), matching: find.byType(FadeTransition));

double _opacity(WidgetTester tester, Key key) =>
    tester.widget<FadeTransition>(_entrance(key)).opacity.value;

double _dy(WidgetTester tester, Key key) => tester
    .widget<Transform>(
      find.descendant(of: find.byKey(key), matching: find.byType(Transform)),
    )
    .transform
    .getTranslation()
    .y;

Widget _host(Widget child, {bool disableAnimations = false}) => MediaQuery(
  data: MediaQueryData(disableAnimations: disableAnimations),
  child: Directionality(textDirection: TextDirection.ltr, child: child),
);

void main() {
  testWidgets('rises and fades in on first build', (tester) async {
    const key = Key('a');
    await tester.pumpWidget(
      _host(const StaggeredEntrance(key: key, index: 0, child: Text('row'))),
    );
    expect(_opacity(tester, key), 0);
    expect(_dy(tester, key), greaterThan(0));

    await tester.pump(OnsetMotion.enter);
    expect(_opacity(tester, key), 1);
    expect(_dy(tester, key), 0);
  });

  testWidgets('later rows start later, one step apart', (tester) async {
    await tester.pumpWidget(
      _host(
        const Column(
          children: [
            StaggeredEntrance(key: Key('0'), index: 0, child: Text('0')),
            StaggeredEntrance(key: Key('3'), index: 3, child: Text('3')),
          ],
        ),
      ),
    );
    // Row 3 waits 3 × 40 ms.
    await tester.pump(const Duration(milliseconds: 100));
    expect(_opacity(tester, const Key('0')), greaterThan(0));
    expect(_opacity(tester, const Key('3')), 0);

    await tester.pump(const Duration(milliseconds: 60));
    expect(_opacity(tester, const Key('3')), greaterThan(0));
    await tester.pumpAndSettle();
    expect(_opacity(tester, const Key('3')), 1);
  });

  testWidgets('rows past the cap enter with the last one', (tester) async {
    await tester.pumpWidget(
      _host(
        const Column(
          children: [
            StaggeredEntrance(key: Key('8'), index: 8, child: Text('8')),
            StaggeredEntrance(key: Key('40'), index: 40, child: Text('40')),
          ],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 380));
    expect(_opacity(tester, const Key('40')), _opacity(tester, const Key('8')));
    expect(_opacity(tester, const Key('40')), greaterThan(0));
  });

  testWidgets('a rebuild never replays it', (tester) async {
    const key = Key('a');
    await tester.pumpWidget(
      _host(const StaggeredEntrance(key: key, index: 0, child: Text('one'))),
    );
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      _host(const StaggeredEntrance(key: key, index: 0, child: Text('two'))),
    );
    expect(find.text('two'), findsOneWidget);
    expect(_opacity(tester, key), 1);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('in a scope, only the first batch of rows animates', (
    tester,
  ) async {
    final rows = ValueNotifier<int>(2);
    addTearDown(rows.dispose);
    await tester.pumpWidget(
      _host(
        StaggerScope(
          child: ValueListenableBuilder<int>(
            valueListenable: rows,
            builder: (context, count, _) => Column(
              children: [
                for (var i = 0; i < count; i++)
                  StaggeredEntrance(
                    key: Key('$i'),
                    index: i,
                    child: Text('$i'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(_opacity(tester, const Key('0')), 0);
    expect(_opacity(tester, const Key('1')), 0);
    await tester.pumpAndSettle();

    // A row that appears later (scrolled into view, loaded by a refresh)
    // shows at once.
    rows.value = 3;
    await tester.pump();
    expect(_opacity(tester, const Key('2')), 1);
    expect(_dy(tester, const Key('2')), 0);
  });

  testWidgets('a closed gate holds the entrance until it opens', (
    tester,
  ) async {
    final open = ValueNotifier<bool>(false);
    addTearDown(open.dispose);
    const key = Key('a');
    await tester.pumpWidget(
      _host(
        EntranceGate(
          open: open,
          child: const StaggeredEntrance(
            key: key,
            index: 1,
            child: Text('row'),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(_opacity(tester, key), 0);
    expect(tester.binding.hasScheduledFrame, isFalse);

    open.value = true;
    await tester.pump();
    // Held rows use the launch step: row 1 waits 60 ms, not 40.
    await tester.pump(const Duration(milliseconds: 50));
    expect(_opacity(tester, key), 0);
    await tester.pumpAndSettle();
    expect(_opacity(tester, key), 1);
  });

  testWidgets('reduce motion: a short fade, no travel, no stagger', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const StaggeredEntrance(key: Key('5'), index: 5, child: Text('5')),
        disableAnimations: true,
      ),
    );
    expect(_dy(tester, const Key('5')), 0);
    await tester.pump(const Duration(milliseconds: 50));
    expect(_opacity(tester, const Key('5')), greaterThan(0));
    await tester.pump(OnsetMotion.reducedFade);
    expect(_opacity(tester, const Key('5')), 1);
    expect(_dy(tester, const Key('5')), 0);
  });

  testWidgets('leaves no frame scheduled once settled', (tester) async {
    await tester.pumpWidget(
      _host(const StaggeredEntrance(index: 2, child: Text('row'))),
    );
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
  });
}
