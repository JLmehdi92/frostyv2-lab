import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/theme.dart';
import 'package:onset/widgets/external_link_dialog.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';

void main() {
  final url = Uri.parse('https://example.com/page?x=1');

  Future<Future<bool>> ask(
    WidgetTester tester, {
    bool ask = true,
    void Function()? stopAsking,
  }) async {
    late Future<bool> answer;
    await tester.pumpWidget(
      MaterialApp(
        theme: const OnsetThemes(colorSchemeSeed: OnsetTokens.accent).dark,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => answer = confirmExternalLink(
                context,
                url,
                ask: ask,
                stopAsking: stopAsking ?? () {},
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    return answer;
  }

  testWidgets('says where the link leads, and Cancel keeps the viewer here', (
    tester,
  ) async {
    final answer = await ask(tester);
    expect(find.text('Open this link?'), findsOneWidget);
    expect(
      find.text(
        'This link leads to example.com, outside ONSET.',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(find.text('https://example.com/page?x=1'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await answer, isFalse);
  });

  testWidgets('Open goes on; with “Don’t ask again” it stops asking', (
    tester,
  ) async {
    var stopped = 0;
    final answer = await ask(tester, stopAsking: () => stopped++);
    await tester.tap(find.text('Don’t ask again'));
    await tester.pump();
    expect(tester.widget<OnsetSwitch>(find.byType(OnsetSwitch)).value, isTrue);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(await answer, isTrue);
    expect(stopped, 1);
  });

  testWidgets('Open alone keeps asking next time', (tester) async {
    var stopped = 0;
    final answer = await ask(tester, stopAsking: () => stopped++);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(await answer, isTrue);
    expect(stopped, 0);
  });

  testWidgets('a look-alike host is shown in its ASCII form', (tester) async {
    final lookAlike = Uri.parse('https://twit\u0441h.tv/login');
    await tester.pumpWidget(
      MaterialApp(
        theme: const OnsetThemes(colorSchemeSeed: OnsetTokens.accent).dark,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showExternalLinkDialog(context, lookAlike),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'This link leads to xn--twith-4ye.tv, outside ONSET.',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(find.text('https://xn--twith-4ye.tv/login'), findsOneWidget);
    expect(find.textContaining('%D1'), findsNothing);
  });

  testWidgets('with the setting off, nothing is asked', (tester) async {
    final answer = await ask(tester, ask: false);
    expect(find.text('Open this link?'), findsNothing);
    expect(await answer, isTrue);
  });
}
