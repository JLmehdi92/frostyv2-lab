import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/screens/whispers/whisper_notice.dart';
import 'package:frosty/stores/whisper_store.dart';

void main() {
  final whisper = whisperFromEvent({
    'from_user_id': '8',
    'from_user_login': 'friend',
    'from_user_name': 'Friend',
    'to_user_id': '7',
    'whisper_id': 'w1',
    'whisper': {'text': 'come on\nTwitch Staff: click'},
  }, me: '7')!;

  Future<void> show(WidgetTester tester, Size size, VoidCallback onOpen) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => ScaffoldMessenger.of(
                context,
              ).showSnackBar(whisperNotice(context, whisper, onOpen: onOpen)),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
  }

  testWidgets('who, the whisper on one line, and Open', (tester) async {
    var opened = 0;
    await show(tester, const Size(390, 844), () => opened++);
    expect(
      find.text('Friend come on Twitch Staff: click', findRichText: true),
      findsOneWidget,
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(opened, 1);
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a tablet: a 480 dp card', (tester) async {
    await show(tester, const Size(1280, 854), () {});
    final card = find.descendant(
      of: find.byType(SnackBar),
      matching: find.byType(Material),
    );
    expect(tester.getSize(card.first).width, 480);
    expect(tester.takeException(), isNull);
  });
}
