import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart' show ObservableMap, runInAction;
import 'package:mocktail/mocktail.dart';
import 'package:onset/models/irc.dart';
import 'package:onset/models/user.dart';
import 'package:onset/screens/channel/chat/gift_bomb_tracker.dart';
import 'package:onset/screens/channel/chat/widgets/chat_message.dart';
import 'package:onset/screens/channel/chat/widgets/gift_bomb_recipients.dart';
import 'package:onset/screens/channel/chat/widgets/overlay_chat_scope.dart';
import 'package:onset/screens/channel/chat/widgets/user_notice_row.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';

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
      'ReSubber subscribed at Tier 1. They’ve subscribed for 14 months, '
      'currently on a 5-month streak!',
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

  testWidgets('a gift bomb is aimed at the channel’s community', (
    tester,
  ) async {
    await pumpChatMessage(
      tester,
      IRCMessage.fromString(massGiftHeader),
      fakeChatStore(),
    );

    expect(
      _systemLine(tester),
      'BigGifter is gifting 5 Tier 1 subs to Channel’s community. They’ve '
      'gifted a total of 50 subs in the channel!',
    );
  });

  group('a collapsed gift bomb', () {
    late GiftBombTracker tracker;
    late MockChatStore store;
    late Set<String> expanded;

    setUp(() {
      tracker = GiftBombTracker();
      store = fakeChatStore();
      expanded = {};
      when(() => store.watchGiftBomb(any())).thenAnswer(
        (invocation) =>
            tracker.watch(invocation.positionalArguments.first as String),
      );
      when(() => store.expandedGiftBombs).thenReturn(expanded);
      when(() => store.setGiftBombExpanded(any(), any())).thenAnswer((i) {
        final key = i.positionalArguments.first as String;
        if (i.positionalArguments.last as bool) {
          expanded.add(key);
        } else {
          expanded.remove(key);
        }
      });
    });

    void feed(String raw, {bool collapse = true}) => tracker.onNotice(
      IRCMessage.fromString(raw).notice!,
      collapse: collapse,
      channelId: '12345',
    );

    testWidgets('lists its recipients in the header row', (tester) async {
      feed(massGiftHeader);
      await pumpChatMessage(
        tester,
        IRCMessage.fromString(massGiftHeader),
        store,
      );
      expect(find.text('0 of 5 recipients'), findsOneWidget);

      for (final raw in massGiftRecipients) {
        feed(raw);
      }
      await tester.pump();
      expect(find.text('5 recipients'), findsOneWidget);
      expect(find.text('Viewer1'), findsNothing);

      await tester.tap(find.byKey(GiftBombRecipients.toggleKey));
      await tester.pumpAndSettle();
      for (var i = 1; i <= 5; i++) {
        expect(find.text('Viewer$i'), findsOneWidget);
      }
      // The choice outlives the row.
      expect(expanded, {'1234567890123456789'});
      await pumpChatMessage(
        tester,
        IRCMessage.fromString(massGiftHeader),
        store,
      );
      expect(find.text('Viewer1'), findsOneWidget);
    });

    testWidgets('without collapsing the header has no list', (tester) async {
      feed(massGiftHeader, collapse: false);
      await pumpChatMessage(
        tester,
        IRCMessage.fromString(massGiftHeader),
        store,
      );

      expect(find.byType(GiftBombRecipients), findsNothing);
    });
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
      'ReSubber subscribed at Tier 1. They’ve subscribed for 14 months, '
          'currently on a 5-month streak!\nKappa 14 months!',
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

    MockChatStore hidingStore() => fakeChatStore(
      settings: SettingsStore.fromJson({'revealDeletedMessages': false}),
    );

    testWidgets('keeps the sentence and hides the message', (tester) async {
      await pumpChatMessage(tester, deleted(), hidingStore());

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
      final store = hidingStore();
      await pumpChatMessage(tester, deleted(), store);

      await tester.tapOnText(find.textRange.ofSubstring('<message deleted>'));
      await tester.pump();

      verify(() => store.revealMessage('resub-1')).called(1);
      expect(
        find.textContaining('14 months!', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('shows the message without a tap by default', (tester) async {
      final store = fakeChatStore();
      await pumpChatMessage(tester, deleted(), store);

      expect(
        find.textContaining('14 months!', findRichText: true),
        findsOneWidget,
      );
      verifyNever(() => store.revealMessage(any()));
    });

    testWidgets('a timeout keeps the sentence too', (tester) async {
      await pumpChatMessage(tester, timedOut(), hidingStore());

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
      await pumpChatMessage(tester, deleted(), hidingStore());

      await tester.longPress(find.byType(UserNoticeRow));
      await tester.pump();

      expect(copied, [
        'ReSubber subscribed at Tier 1. They’ve subscribed for 14 months, '
            'currently on a 5-month streak!',
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

    testWidgets('a deleted chat message shows its text by default', (
      tester,
    ) async {
      final message = IRCMessage.fromString(basicPrivmsg);
      message.command = Command.clearMessage;
      await pumpChatMessage(tester, message, fakeChatStore());

      expect(find.text('Message deleted'), findsOneWidget);
      expect(
        find.textContaining('Hello World', findRichText: true),
        findsOneWidget,
      );
    });
  });

  testWidgets('a notice in the chat over the video uses the overlay row', (
    tester,
  ) async {
    final store = fakeChatStore();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OverlayChatScope(
            child: ListView(
              children: [
                ChatMessage(
                  ircMessage: IRCMessage.fromString(subGift),
                  chatStore: store,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(
      tester.widget<UserNoticeRow>(find.byType(UserNoticeRow)).overlay,
      isTrue,
    );
  });

  testWidgets('a notice in the chat list does not', (tester) async {
    await pumpChatMessage(
      tester,
      IRCMessage.fromString(subGift),
      fakeChatStore(),
    );

    expect(
      tester.widget<UserNoticeRow>(find.byType(UserNoticeRow)).overlay,
      isFalse,
    );
  });

  group('shared chat', () {
    testWidgets('a partner announcement is drawn as an announcement', (
      tester,
    ) async {
      await pumpChatMessage(
        tester,
        IRCMessage.fromString(sharedAnnouncement),
        fakeChatStore(),
      );

      expect(find.byType(UserNoticeRow), findsNothing);
      expect(find.text('Announcement'), findsOneWidget);
    });

    testWidgets('a partner gift is worded like a gift', (tester) async {
      await pumpChatMessage(
        tester,
        IRCMessage.fromString(sharedSubGift),
        fakeChatStore(),
      );

      expect(
        _systemLine(tester),
        'PartnerGifter gifted a Tier 1 sub to Lucky! It’s their first gift '
        'sub in the channel!',
      );
    });

    testWidgets('a partner gift bomb names the partner once it is known', (
      tester,
    ) async {
      final message = IRCMessage.fromString(sharedMassGiftHeader);
      final profiles = ObservableMap<String, UserTwitch>();
      final store = fakeChatStore(channelProfiles: profiles);

      await pumpChatMessage(tester, message, store);
      expect(_systemLine(tester), contains('Channel’s community'));

      runInAction(
        () => profiles['99999'] = const UserTwitch(
          '99999',
          'partner',
          'Partner',
          'https://example.com/p.png',
        ),
      );
      await tester.pump();
      expect(_systemLine(tester), contains('Partner’s community'));
    });
  });
}
