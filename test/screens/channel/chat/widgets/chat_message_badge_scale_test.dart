import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/constants.dart';
import 'package:onset/models/irc.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';

import '../../../../helpers/chat_message_harness.dart';

const _firstMessage =
    '@badge-info=;badges=;color=#FF0000;display-name=Newcomer;emotes=;'
    'first-msg=1;id=first-1;mod=0;room-id=12345;subscriber=0;'
    'tmi-sent-ts=1234567890123;turbo=0;user-id=777;user-type= '
    ':newcomer!newcomer@newcomer.tmi.twitch.tv PRIVMSG #channel :hi all';

void main() {
  testWidgets('the badge size setting reaches the message header at once, '
      'without its parent rebuilding', (tester) async {
    final settings = SettingsStore.fromJson({})
      ..highlightFirstTimeChatter = true
      ..badgeScale = 1;
    final store = fakeChatStore(settings: settings);
    await pumpChatMessage(tester, IRCMessage.fromString(_firstMessage), store);

    double iconSize() =>
        tester.widget<Icon>(find.byIcon(Icons.auto_awesome_rounded)).size!;
    expect(iconSize(), defaultBadgeSize);

    settings.badgeScale = 1.5;
    await tester.pump();
    // Before: read outside the message's Observer, it kept the old size
    // until something else rebuilt the row.
    expect(iconSize(), defaultBadgeSize * 1.5);
  });
}
