import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/screens/home/stream_list/stream_tags.dart';

void main() {
  Future<void> pump(WidgetTester tester, List<String> tags, double width) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: StreamTags(tags: tags),
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
}
