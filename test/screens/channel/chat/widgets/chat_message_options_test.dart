import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/models/irc.dart';
import 'package:onset/screens/channel/chat/chat_commands.dart';
import 'package:onset/screens/channel/chat/widgets/chat_message.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';

import '../../../../helpers/chat_message_harness.dart';

const _line =
    '@badge-info=;badges=;color=#00FF00;display-name=Viewer;emotes=;'
    'id=msg-1;room-id=12345;user-id=55555 '
    ':viewer!viewer@viewer.tmi.twitch.tv PRIVMSG #channel :buy viewers';

void main() {
  setUpAll(() => registerFallbackValue(const DeleteMessageCommand('x')));

  Future<MockChatStore> open(WidgetTester tester, {required bool mod}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    captureClipboard(tester);
    final store = fakeChatStore();
    when(() => store.canModerate).thenReturn(mod);
    when(
      () => store.moderate(any(), userId: any(named: 'userId')),
    ).thenAnswer((_) async => (ok: true, message: 'Message deleted.'));
    await pumpChatMessage(tester, IRCMessage.fromString(_line), store);
    await tester.longPress(find.byType(ChatMessage).first);
    await tester.pumpAndSettle();
    return store;
  }

  testWidgets('long press: the message in a card and the rows', (tester) async {
    await open(tester, mod: false);
    expect(tester.takeException(), isNull);
    final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
    expect(sheet.backgroundColor, SheetColors.dark.sheet);
    for (final label in [
      'Copy message',
      'Copy message and paste',
      'Reply to message',
    ]) {
      expect(find.widgetWithText(SheetRow, label), findsOneWidget);
    }
    expect(find.text('Delete message'), findsNothing);
  });

  testWidgets('a moderator deletes it from the red row', (tester) async {
    final store = await open(tester, mod: true);
    expect(
      tester
          .widget<SheetRow>(find.widgetWithText(SheetRow, 'Delete message'))
          .danger,
      isTrue,
    );
    await tester.tap(find.text('Delete message'));
    await tester.pumpAndSettle();
    final command =
        verify(
              () => store.moderate(captureAny(), userId: any(named: 'userId')),
            ).captured.single
            as DeleteMessageCommand;
    expect(command.messageId, 'msg-1');
    expect(find.byType(BottomSheet), findsNothing);
  });
}
