import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/screens/home/stream_list/streams_list.dart';

void main() {
  Future<void> pump(WidgetTester tester, int hidden, VoidCallback onShow) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HiddenStreamsBanner(hidden: hidden, onShow: onShow),
          ),
        ),
      );

  testWidgets('says how many are hidden and shows them', (tester) async {
    var shown = 0;
    await pump(tester, 3, () => shown++);

    expect(
      find.text('3 streams hidden by your content preferences'),
      findsOneWidget,
    );
    await tester.tap(find.text('Show'));
    expect(shown, 1);

    await pump(tester, 1, () {});
    expect(
      find.text('1 stream hidden by your content preferences'),
      findsOneWidget,
    );
  });

  testWidgets('nothing hidden, nothing shown', (tester) async {
    await pump(tester, 0, () {});
    expect(find.byType(TextButton), findsNothing);
  });
}
