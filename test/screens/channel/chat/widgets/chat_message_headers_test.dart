import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/irc.dart';
import 'package:onset/models/user.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';

import '../../../../helpers/chat_message_harness.dart';

String _privmsg(String tags, String text) =>
    '@display-name=Fan;id=x1;user-id=5;tmi-sent-ts=1700000000000;$tags '
    ':fan!fan@fan.tmi.twitch.tv PRIVMSG #channel :$text';

void main() {
  const partner = UserTwitch('777', 'partner', 'Partner', '');

  testWidgets('a cheer from another channel of a shared chat names it', (
    tester,
  ) async {
    await pumpChatMessage(
      tester,
      IRCMessage.fromString(
        _privmsg('bits=100;room-id=12345;source-room-id=777', 'Cheer100 hi'),
      ),
      fakeChatStore(channelIdToUserTwitch: {'777': partner}),
    );
    expect(find.text('Cheered in Partner'), findsOneWidget);
  });

  testWidgets('a cheer in this channel, or a plain message, does not', (
    tester,
  ) async {
    final store = fakeChatStore(channelIdToUserTwitch: {'777': partner});
    await pumpChatMessage(
      tester,
      IRCMessage.fromString(
        _privmsg('bits=100;room-id=12345;source-room-id=12345', 'Cheer100'),
      ),
      store,
    );
    expect(find.textContaining('Cheered in'), findsNothing);
    await pumpChatMessage(
      tester,
      IRCMessage.fromString(
        _privmsg('room-id=12345;source-room-id=777', 'hello'),
      ),
      store,
    );
    expect(find.textContaining('Cheered in'), findsNothing);
  });

  testWidgets('a message sent with the subscribers-only reward is marked', (
    tester,
  ) async {
    await pumpChatMessage(
      tester,
      IRCMessage.fromString(_privmsg('msg-id=skip-subs-mode-message', 'hi')),
      fakeChatStore(),
    );
    expect(
      find.text('Sent with channel points in subscribers-only chat'),
      findsOneWidget,
    );
  });

  testWidgets('an animated message is marked, unless notices are off', (
    tester,
  ) async {
    final line = _privmsg('msg-id=animated-message;animation-id=simmer', 'hi');
    await pumpChatMessage(tester, IRCMessage.fromString(line), fakeChatStore());
    expect(find.text('Animated message'), findsOneWidget);

    await pumpChatMessage(
      tester,
      IRCMessage.fromString(line),
      fakeChatStore(
        settings: SettingsStore.fromJson({})..showUserNotices = false,
      ),
    );
    expect(find.text('Animated message'), findsNothing);
  });

  testWidgets('a first message keeps its highlight over the cheer header', (
    tester,
  ) async {
    await pumpChatMessage(
      tester,
      IRCMessage.fromString(
        _privmsg(
          'bits=100;first-msg=1;room-id=12345;source-room-id=777',
          'Cheer100 hi',
        ),
      ),
      fakeChatStore(channelIdToUserTwitch: {'777': partner}),
    );
    expect(find.text('First message'), findsOneWidget);
  });
}
