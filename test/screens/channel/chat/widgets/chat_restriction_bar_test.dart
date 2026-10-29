import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/irc.dart';
import 'package:onset/screens/channel/chat/chat_restrictions.dart';
import 'package:onset/screens/channel/chat/widgets/chat_restriction_bar.dart';

void main() {
  var now = DateTime.utc(2026, 10, 13, 20);

  Future<void> pump(WidgetTester tester, ChatRestriction? restriction) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatRestrictionBar(restriction: restriction, now: () => now),
          ),
        ),
      );

  testWidgets('a timeout counts down every second', (tester) async {
    await pump(
      tester,
      ChatRestriction(
        ChatRestrictionKind.timedOut,
        until: now.add(const Duration(seconds: 65)),
      ),
    );
    expect(find.text('You are timed out · 1:05'), findsOneWidget);

    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('You are timed out · 1:04'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('room modes stay out of this line', (tester) async {
    await pump(
      tester,
      const ChatRestriction(ChatRestrictionKind.followersOnly, minutes: 10),
    );
    expect(find.byType(Text), findsNothing);
    await pump(tester, null);
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('a ban shows its line (fixed height) without a countdown', (
    tester,
  ) async {
    await pump(tester, const ChatRestriction(ChatRestrictionKind.banned));
    expect(
      find.text('You are permanently banned from this chat'),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byType(ChatRestrictionBar)).height,
      kRestrictionBarHeight,
    );
  });

  test('USERSTATE knows a VIP from its badges', () {
    final state = const USERSTATE().fromIRCMessage(
      IRCMessage.fromString(
        '@badges=vip/1,subscriber/12;mod=0;subscriber=1 '
        ':tmi.twitch.tv USERSTATE #channel',
      ),
    );
    expect(state.vip, isTrue);
    expect(state.mod, isFalse);
    final plain = state.fromIRCMessage(
      IRCMessage.fromString(
        '@badges=subscriber/12;mod=0 :tmi.twitch.tv USERSTATE #channel',
      ),
    );
    expect(plain.vip, isFalse);
    // No badges at all (an empty tag) is no VIP either.
    final none = state.fromIRCMessage(
      IRCMessage.fromString('@badges=;mod=0 :tmi.twitch.tv USERSTATE #channel'),
    );
    expect(none.vip, isFalse);
  });
}
