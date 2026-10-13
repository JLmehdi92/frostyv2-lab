import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/screens/home/stream_list/stream_tags.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    List<String> tags,
    double width, {
    ValueChanged<String>? onTap,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: StreamTags(tags: tags, onTap: onTap),
          ),
        ),
      ),
    ),
  );

  testWidgets('one line of pills, cut instead of wrapping', (tester) async {
    await pump(tester, [
      'English',
      'Speedrun',
      'A very long tag name indeed',
      'Chill',
      'Fifth',
    ], 160);
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(StreamTags)).height, StreamTags.height);
    // At most four.
    expect(find.text('Fifth'), findsNothing);
    expect(
      find.bySemanticsLabel(RegExp('Tags: English, Speedrun')),
      findsOneWidget,
    );
  });

  testWidgets('no tags, no space', (tester) async {
    await pump(tester, [' '], 160);
    expect(tester.getSize(find.byType(StreamTags)).height, 0);
  });

  testWidgets('a pill opens its tag; odd tags and hidden ones do not', (
    tester,
  ) async {
    final opened = <String>[];
    await pump(
      tester,
      ['Chill', 'not a tag', 'Français', 'Hidden'],
      120,
      onTap: opened.add,
    );

    await tester.tap(find.text('Chill'));
    await tester.tap(find.text('not a tag'), warnIfMissed: false);
    expect(opened, ['Chill']);
    expect(find.bySemanticsLabel('Tag Chill'), findsOneWidget);
    expect(find.bySemanticsLabel('Tag not a tag'), findsNothing);

    // Cut off by the card's edge: not reachable.
    await tester.tapAt(tester.getCenter(find.text('Hidden')));
    expect(opened, ['Chill']);
  });
}
