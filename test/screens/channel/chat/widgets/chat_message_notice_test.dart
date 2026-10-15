import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/models/irc.dart';
import 'package:frosty/screens/channel/chat/widgets/user_notice_row.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../fixtures/irc_messages.dart';
import '../../../../helpers/chat_message_harness.dart';

String _systemLine(WidgetTester tester) => tester
    .widget<Text>(find.byKey(UserNoticeRow.systemLineKey))
    .textSpan!
    .toPlainText();

void main() {
  testWidgets('a resub is worded like Twitch, above its message', (
    tester,
  ) async {
    await pumpChatMessage(
      tester,
      IRCMessage.fromString(resubStreak),
      fakeChatStore(),
    );

    expect(find.byType(UserNoticeRow), findsOneWidget);
    expect(
      _systemLine(tester),
      "ReSubber subscribed at Tier 1. They've subscribed for 14 months, "
      'currently on a 5 month streak!',
    );
    expect(find.textContaining('14 months!', findRichText: true), findsWidgets);
  });

  testWidgets('a named sub has no star any more', (tester) async {
    await pumpChatMessage(
      tester,
      IRCMessage.fromString(userNoticeSubscription),
      fakeChatStore(),
    );

    expect(find.byIcon(Icons.star_rounded), findsNothing);
    expect(_systemLine(tester), 'NewSub subscribed at Tier 1.');
  });

  testWidgets('an anonymous gift keeps its icon', (tester) async {
    await pumpChatMessage(
      tester,
      IRCMessage.fromString(anonymousSubGift),
      fakeChatStore(),
    );

    expect(find.byIcon(Icons.card_giftcard_rounded), findsOneWidget);
  });

  testWidgets("a gift bomb is aimed at the channel's community", (
    tester,
  ) async {
    await pumpChatMessage(
      tester,
      IRCMessage.fromString(massGiftHeader),
      fakeChatStore(),
    );

    expect(
      _systemLine(tester),
      "BigGifter is gifting 5 Tier 1 Subs to Channel's community. They've "
      'gifted a total of 50 in the channel!',
    );
  });

  testWidgets('a notice spans the full width of the chat', (tester) async {
    await pumpChatMessage(
      tester,
      IRCMessage.fromString(subGift),
      fakeChatStore(),
    );

    final body = tester.getRect(find.byKey(UserNoticeRow.bodyKey));
    expect(body.left, 0);
    expect(body.right, tester.getSize(find.byType(ListView)).width);
  });

  testWidgets('an announcement keeps its own look', (tester) async {
    await pumpChatMessage(
      tester,
      IRCMessage.fromString(
        '@badge-info=;badges=;color=;display-name=Mod;emotes=;id=ann-1;'
        'login=mod;mod=1;msg-id=announcement;msg-param-color=BLUE;'
        'room-id=12345;subscriber=0;system-msg=;tmi-sent-ts=1700000000800;'
        'user-id=20009;user-type= :tmi.twitch.tv USERNOTICE #channel '
        ':hello chat',
      ),
      fakeChatStore(),
    );

    expect(find.byType(UserNoticeRow), findsNothing);
    expect(find.text('Announcement'), findsOneWidget);
  });

  testWidgets('hiding user notices hides the row', (tester) async {
    await pumpChatMessage(
      tester,
      IRCMessage.fromString(resubStreak),
      fakeChatStore(
        settings: SettingsStore.fromJson({'showUserNotices': false}),
      ),
    );

    expect(find.byType(UserNoticeRow), findsNothing);
  });

  testWidgets('a long press copies the sentence and the message', (
    tester,
  ) async {
    final copied = captureClipboard(tester);
    final store = fakeChatStore();
    await pumpChatMessage(tester, IRCMessage.fromString(resubStreak), store);

    await tester.longPress(find.byType(UserNoticeRow));
    await tester.pump();

    expect(copied, [
      "ReSubber subscribed at Tier 1. They've subscribed for 14 months, "
          'currently on a 5 month streak!\nKappa 14 months!',
    ]);
  });

  test('a notice is parsed once and kept', () {
    final message = IRCMessage.fromString(resubStreak);

    expect(message.notice, isNotNull);
    expect(identical(message.notice, message.notice), isTrue);
    expect(
      identical(
        message.noticeText(channelName: 'Channel'),
        message.noticeText(channelName: 'Channel'),
      ),
      isTrue,
    );
    expect(IRCMessage.fromString(basicPrivmsg).notice, isNull);
  });
  group('a deleted or banned notice', () {
    IRCMessage deleted() {
      final message = IRCMessage.fromString(resubStreak);
      IRCMessage.clearMessage(
        messages: [message],
        bufferedMessages: [],
        ircMessage: IRCMessage.fromString(clearMsgResub),
      );
      return message;
    }

    IRCMessage timedOut() {
      final message = IRCMessage.fromString(resubStreak);
      IRCMessage.clearChat(
        messages: [message],
        bufferedMessages: [],
        ircMessage: IRCMessage.fromString(clearChatResubber),
      );
      return message;
    }

    testWidgets('keeps the sentence and hides the message', (tester) async {
      await pumpChatMessage(tester, deleted(), fakeChatStore());

      expect(find.byType(UserNoticeRow), findsOneWidget);
      expect(_systemLine(tester), startsWith('ReSubber subscribed at Tier 1.'));
      expect(
        find.textContaining('<message deleted>', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('14 months!', findRichText: true),
        findsNothing,
      );
      expect(find.text('Message deleted'), findsNothing);
    });

    testWidgets('reveals the message on tap', (tester) async {
      final store = fakeChatStore();
      await pumpChatMessage(tester, deleted(), store);

      await tester.tapOnText(find.textRange.ofSubstring('<message deleted>'));
      await tester.pump();

      verify(() => store.revealMessage('resub-1')).called(1);
      expect(
        find.textContaining('14 months!', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('shows the message when deleted messages are shown', (
      tester,
    ) async {
      await pumpChatMessage(
        tester,
        deleted(),
        fakeChatStore(
          settings: SettingsStore.fromJson({'showDeletedMessages': true}),
        ),
      );

      expect(
        find.textContaining('14 months!', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('a timeout keeps the sentence too', (tester) async {
      await pumpChatMessage(tester, timedOut(), fakeChatStore());

      expect(find.byType(UserNoticeRow), findsOneWidget);
      expect(find.textContaining('Timed out'), findsNothing);
      expect(
        find.textContaining('<message deleted>', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('a long press copies the sentence without the hidden message', (
      tester,
    ) async {
      final copied = captureClipboard(tester);
      await pumpChatMessage(tester, deleted(), fakeChatStore());

      await tester.longPress(find.byType(UserNoticeRow));
      await tester.pump();

      expect(copied, [
        "ReSubber subscribed at Tier 1. They've subscribed for 14 months, "
            'currently on a 5 month streak!',
      ]);
    });

    testWidgets('a deleted chat message still reads "Message deleted"', (
      tester,
    ) async {
      final message = IRCMessage.fromString(basicPrivmsg);
      message.command = Command.clearMessage;
      await pumpChatMessage(tester, message, fakeChatStore());

      expect(find.byType(UserNoticeRow), findsNothing);
      expect(find.text('Message deleted'), findsOneWidget);
    });
  });
}
