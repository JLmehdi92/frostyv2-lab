import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/screens/channel/chat/widgets/chat_character_counter.dart';

void main() {
  testWidgets('hidden until 50 are left, then counts down', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ChatCharacterCounter(controller: controller)),
      ),
    );
    expect(find.byType(Text), findsNothing);

    controller.text = 'a' * 451;
    await tester.pump();
    expect(find.text('49'), findsOneWidget);
    expect(find.bySemanticsLabel('49 characters left'), findsOneWidget);

    // Emoji count as one character, like Twitch.
    controller.text = '${'a' * 495}😀😀';
    await tester.pump();
    expect(find.text('3'), findsOneWidget);
  });

  test('the input stops at 500 characters', () {
    final formatter = LengthLimitingTextInputFormatter(kChatMessageMaxLength);
    final result = formatter.formatEditUpdate(
      TextEditingValue.empty,
      TextEditingValue(text: 'a' * 600),
    );
    expect(result.text.length, 500);
  });
}
