import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/widgets/motion/rolling_number.dart';

Widget _host(String text, {bool disableAnimations = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: Center(
      child: RollingNumber(text, style: const TextStyle(fontSize: 20)),
    ),
  ),
);

void main() {
  testWidgets('shows the number and reads it out once', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_host('12 418'));
    expect(find.bySemanticsLabel('12 418'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('only the digits that change roll, old out and new in', (
    tester,
  ) async {
    await tester.pumpWidget(_host('12418'));
    await tester.pumpWidget(_host('12431'));
    await tester.pump(const Duration(milliseconds: 100));

    // Mid-roll: the changed places show both their old and new digit.
    expect(find.text('8'), findsOneWidget); // old last digit, leaving
    expect(find.text('3'), findsOneWidget); // new fourth digit, arriving
    // Unchanged places are not doubled.
    expect(find.text('4'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('8'), findsNothing);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('1'), findsNWidgets(2));
  });

  testWidgets('rolls up when the number grows, down when it falls', (
    tester,
  ) async {
    double newDigitDy() => tester
        .widget<FractionalTranslation>(
          find
              .ancestor(
                of: find.text('9'),
                matching: find.byType(FractionalTranslation),
              )
              .first,
        )
        .translation
        .dy;

    await tester.pumpWidget(_host('18'));
    await tester.pumpWidget(_host('19'));
    await tester.pump(const Duration(milliseconds: 50));
    // The new digit comes from below.
    expect(newDigitDy(), greaterThan(0));
    await tester.pumpAndSettle();

    await tester.pumpWidget(_host('20'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_host('19'));
    await tester.pump(const Duration(milliseconds: 50));
    // Falling: it comes from above.
    expect(newDigitDy(), lessThan(0));
    await tester.pumpAndSettle();
  });

  group('reads the direction off formatted numbers', () {
    for (final (from, to, grows) in [
      ('999', '1K', true),
      ('1.2K', '999', false),
      ('12.4K', '1,000', false),
      ('1.000', '999', false), // "." grouping (de, it)
      ('999', '1.000', true),
      ('12,4 k', '12,5 k', true), // "," decimal (fr)
      ('9.9', '10', true),
      ('1.5M', '900K', false),
      ('12 418', '12 431', true),
      ('2,1 k', '980', false),
      // A word after the number is not a unit.
      ('5 bits', '6 bits', true),
      ('6 bits', '5 bits', false),
      ('3 months', '12 months', true),
      ('12 months', '3 months', false),
      ('900 bits', '1K bits', true),
    ]) {
      test('$from → $to rolls ${grows ? 'up' : 'down'}', () {
        expect(rollsUp(from, to), grows);
      });
    }

    test('k, M and B are units only when they end the number', () {
      expect(readCount('5 bits'), 5);
      expect(readCount('3 months'), 3);
      expect(readCount('2kbps'), 2);
      expect(readCount('1.2K'), 1200);
      expect(readCount('3M viewers'), 3e6);
      expect(readCount('12,4 k'), 12400);
      expect(readCount('7B'), 7e9);
    });

    test('anything unreadable rolls up', () {
      expect(rollsUp('—', '12'), isTrue);
      expect(rollsUp('12', 'n/a'), isTrue);
    });
  });

  testWidgets('keeps its width while rolling (tabular figures)', (
    tester,
  ) async {
    await tester.pumpWidget(_host('12 418'));
    final before = tester.getSize(find.byType(RollingNumber));
    await tester.pumpWidget(_host('12 456'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getSize(find.byType(RollingNumber)), before);

    for (final text in tester.widgetList<Text>(
      find.descendant(
        of: find.byType(RollingNumber),
        matching: find.byType(Text),
      ),
    )) {
      expect(
        text.style?.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
    }
    await tester.pumpAndSettle();
  });

  testWidgets('a longer number grows its new leading digit in', (tester) async {
    await tester.pumpWidget(_host('999'));
    await tester.pumpWidget(_host('1,000'));
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);
    expect(find.text(','), findsOneWidget);
    expect(find.text('0'), findsNWidgets(3));
    expect(find.text('9'), findsNothing);
  });

  testWidgets('reduce motion: the new number at once', (tester) async {
    await tester.pumpWidget(_host('12418', disableAnimations: true));
    await tester.pumpWidget(_host('12431', disableAnimations: true));
    expect(find.text('8'), findsNothing);
    expect(find.text('3'), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('clips the rolling digits to the line', (tester) async {
    await tester.pumpWidget(_host('1'));
    await tester.pumpWidget(_host('2'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      find.ancestor(of: find.text('2'), matching: find.byType(ClipRect)),
      findsOneWidget,
    );
    final clip = tester.renderObject<RenderClipRect>(
      find.ancestor(of: find.text('2'), matching: find.byType(ClipRect)),
    );
    expect(clip.size.height, greaterThan(0));
    await tester.pumpAndSettle();
  });
}
