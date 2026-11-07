import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/irc.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';

import '../../../../helpers/chat_message_harness.dart';

const _line =
    '@color=#0000AA;display-name=Fan;id=a :fan!fan@fan.tmi.twitch.tv '
    'PRIVMSG #channel :hi';

Color? _nameColor(WidgetTester tester) {
  for (final text in tester.widgetList<RichText>(find.byType(RichText))) {
    Color? found;
    text.text.visitChildren((span) {
      if (span is TextSpan && span.text == 'Fan') found = span.style?.color;
      return found == null;
    });
    if (found != null) return found;
  }
  return null;
}

void main() {
  testWidgets('a chat line follows the readable colors setting', (
    tester,
  ) async {
    final settings = SettingsStore.fromJson({});
    final store = fakeChatStore(settings: settings);
    await pumpChatMessage(tester, IRCMessage.fromString(_line), store);
    expect(_nameColor(tester), isNot(const Color(0xFF0000AA)));

    settings.readableNameColors = false;
    await pumpChatMessage(tester, IRCMessage.fromString(_line), store);
    await tester.pump();
    expect(_nameColor(tester), const Color(0xFF0000AA));
  });
}
