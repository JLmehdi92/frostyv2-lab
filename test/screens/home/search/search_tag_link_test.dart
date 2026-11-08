import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/screens/home/search/search.dart';

import '../../../helpers/l10n.dart';

void main() {
  test('a single word is offered as a tag', () {
    expect(searchTagOf(' Speedrun '), 'Speedrun');
    expect(searchTagOf('Français'), 'Français');
    expect(searchTagOf('two words'), isNull);
    expect(searchTagOf(''), isNull);
    expect(searchTagOf('a' * 26), isNull);
  });

  testWidgets('the tag link opens the tag', (tester) async {
    var opened = 0;
    await pumpLocalized(
      tester,
      Scaffold(
        body: Center(
          child: SearchTagLink(tag: 'Speedrun', onOpen: () => opened++),
        ),
      ),
      locale: en,
    );
    expect(find.text('Live channels tagged Speedrun'), findsOneWidget);
    await tester.tap(find.byType(SearchTagLink));
    expect(opened, 1);
  });
}
