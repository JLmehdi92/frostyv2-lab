import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart' show ObservableList;
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/base_api_client.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/apis/twitch_points_service.dart';
import 'package:onset/apis/twitch_watch_streak_service.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/channel_leaderboards.dart';
import 'package:onset/models/community_goal.dart';
import 'package:onset/models/community_points.dart';
import 'package:onset/models/drop_campaign.dart';
import 'package:onset/models/emotes.dart';
import 'package:onset/models/irc.dart';
import 'package:onset/models/raid_arrival.dart';
import 'package:onset/models/resub_notification.dart';
import 'package:onset/models/shoutout_profile.dart';
import 'package:onset/models/user.dart';
import 'package:onset/models/watch_streak.dart';
import 'package:onset/screens/channel/chat/chat_commands.dart';
import 'package:onset/screens/channel/chat/chat_restrictions.dart';
import 'package:onset/screens/channel/chat/details/chat_details.dart';
import 'package:onset/screens/channel/chat/details/chat_mode_controls.dart';
import 'package:onset/screens/channel/chat/details/stores/chat_details_store.dart';
import 'package:onset/screens/channel/chat/emote_menu/emote_menu.dart';
import 'package:onset/screens/channel/chat/emote_menu/emote_menu_section.dart';
import 'package:onset/screens/channel/chat/mod_tools/mod_events.dart';
import 'package:onset/screens/channel/chat/moderation.dart';
import 'package:onset/screens/channel/chat/moderation_notice.dart';
import 'package:onset/screens/channel/chat/server_notice.dart';
import 'package:onset/screens/channel/chat/widgets/channel_points_sheet.dart';
import 'package:onset/screens/channel/chat/widgets/chat_bottom_bar.dart';
import 'package:onset/screens/channel/chat/widgets/chat_message.dart';
import 'package:onset/screens/channel/chat/widgets/chat_moderation_bar.dart';
import 'package:onset/screens/channel/chat/widgets/chat_restriction_bar.dart';
import 'package:onset/screens/channel/chat/widgets/chat_user_modal.dart';
import 'package:onset/screens/channel/chat/widgets/chat_warning_dialog.dart';
import 'package:onset/screens/channel/chat/widgets/community_goals_sheet.dart';
import 'package:onset/screens/channel/chat/widgets/drops_card.dart';
import 'package:onset/screens/channel/chat/widgets/leaderboards_sheet.dart';
import 'package:onset/screens/channel/chat/widgets/resub_share_card.dart';
import 'package:onset/screens/channel/chat/widgets/shoutout_card.dart';
import 'package:onset/screens/channel/stores/channel_events_store.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/stores/user_store.dart';
import 'package:onset/services/hermes_client.dart';
import 'package:onset/widgets/sheet/onset_panel.dart';
import 'package:provider/provider.dart';

import '../fixtures/community_goal_payloads.dart';
import '../fixtures/drops_gql_payloads.dart';
import '../fixtures/irc_messages.dart';
import '../helpers/chat_message_harness.dart';
import '../helpers/l10n.dart';

class _MockAuthStore extends Mock implements AuthStore {}

class _MockUserStore extends Mock implements UserStore {}

class _MockTwitchApi extends Mock implements TwitchApi {}

class _MockPointsService extends Mock implements TwitchPointsService {}

class _MockHermesClient extends Mock implements HermesClient {}

class _MockWatchStreakService extends Mock
    implements TwitchWatchStreakService {}

/// The chat in French: every line the app writes into it (notices, sub,
/// gift, raid and Bits lines, moderation), the input with its command
/// suggestions, reply bar and counter, the moderator's tools, the user
/// card, the emote menu, the chat's details and modes, and the channel
/// points sheet with a prediction, at every size and text scale, with no
/// overflow, no English and no text cut off.
void main() {
  final french = lookupAppLocalizations(fr);

  setUpAll(() {
    registerFallbackValue(Duration.zero);
    registerFallbackValue(() {});
    registerFallbackValue(
      const Emote(
        name: 'x',
        zeroWidth: false,
        url: 'https://cdn.example/x.png',
        type: EmoteType.twitchGlobal,
      ),
    );
    registerFallbackValue(const PointsReward(id: 'x', title: 'x', cost: 1));
  });

  /// Every line the app itself puts in the chat, worded in the language on
  /// screen when it is made (call it once French is on).
  List<IRCMessage> appLines() {
    final l = L10n.current;
    IRCMessage notice(String text) => IRCMessage.createNotice(message: text);
    final moderation = <String>[
      l.chatModBanned(name: 'Troll'),
      l.chatModTimedOut(name: 'Troll', duration: timeoutLength(600, l)),
      l.chatModUntimedOut(name: 'Troll'),
      l.chatModUnbanned(name: 'Troll'),
      l.chatModWarned(name: 'Troll'),
      l.chatModMessageDeleted,
      l.chatModCleared,
      for (final mode in ChatMode.values)
        for (final on in [true, false])
          l.chatModeChanged(mode: mode.name, state: OnOff.of(on).name),
      l.chatModeSlowOn(duration: timeoutLength(30, l)),
      l.chatModeFollowersOn(duration: timeoutLength(604800, l)),
      for (final command in const <ModerationCommand>[
        BanCommand('troll', ''),
        TimeoutCommand('troll', Duration(minutes: 10), ''),
        UnbanCommand('troll', timeout: true),
        UnbanCommand('troll'),
        WarnCommand('troll', 'be nice'),
        DeleteMessageCommand('abc'),
        ClearChatCommand(),
        ChatModeCommand(ChatMode.slow, on: true),
        ChatModeCommand(ChatMode.emoteOnly, on: false),
      ]) ...[
        moderationFailure(
          const ApiException('Access denied', 403),
          moderationCommand(command),
        ),
        moderationFailure(
          const NetworkException('offline'),
          moderationCommand(command),
        ),
        moderationFailure(StateError('boom'), moderationCommand(command)),
      ],
      moderationFailure(
        const UnauthorizedException('log in'),
        moderationCommand(const ClearChatCommand()),
      ),
      moderationFailed.message,
    ];
    final typed = [
      for (final line in const [
        '/color',
        '/color purple',
        '/block',
        '/w friend',
        '/ban',
        '/timeout troll 5min',
        '/timeout troll 3w',
        '/slow 200',
        '/followers 4mo',
        '/subscribers now',
        '/pin someone',
        '/dance',
      ])
        (parseChatCommand(line) as UnsupportedCommand).text(l),
    ];
    return [
      notice(l.chatConnecting),
      notice(l.chatWelcome(name: 'Streamer')),
      notice(l.chatReconnectingIn(seconds: 4, attempt: 2, max: 5)),
      notice(l.chatReconnecting(attempt: 2, max: 5)),
      notice(l.chatReconnected(attempts: 1, seconds: 5)),
      notice(l.chatReconnected(attempts: 3, seconds: 12)),
      IRCMessage.createNotice(
        message: l.chatDisconnected,
        actionCallback: () {},
        actionLabel: l.chatReconnect,
      ),
      notice(l.chatSyncIn(seconds: 6)),
      notice(l.chatSevenTvEmoteAdded(name: 'Editor', emote: 'catJAM')),
      notice(l.chatSevenTvEmoteRemoved(name: 'Editor', emote: 'catJAM')),
      notice(l.chatCannotSendDisconnected),
      notice(l.chatClearedByModerator),
      notice(
        l.chatHelpCommands(
          commands: [
            for (final c in [...kChatCommands, ...kModeratorChatCommands])
              c.usage(l),
          ].join(', '),
        ),
      ),
      for (final text in typed) notice(text),
      notice(l.chatLogInToWhisper),
      notice(l.chatWhisperSent(name: 'Friend')),
      notice(l.chatWhisperSentNoReplies(name: 'Friend')),
      notice(l.chatWhisperNoUser(login: 'ghost')),
      notice(l.chatWhisperFailedBecause(reason: l.apiErrorNetwork)),
      notice(l.chatWhisperFailed),
      notice(l.chatLogInToChangeColor),
      notice(l.chatColorChanged),
      notice(l.chatColorFailedHex),
      notice(l.chatAlreadyBlocked(name: 'Troll')),
      notice(l.chatBlockedUser(name: 'Troll')),
      notice(l.chatUnblockedUser(name: 'Troll')),
      notice(l.chatBlockFailed(login: 'troll')),
      notice(l.chatUnblockFailed(login: 'troll')),
      notice(l.chatLogInToModerate),
      notice(l.chatUserCardNoUser(login: 'ghost')),
      notice(l.chatUserCardFailed(login: 'friend')),
      IRCMessage.createNotice(
        message: l.chatAnimatedEmotesCallout,
        actionCallback: () {},
        actionLabel: l.chatAnimatedEmotesCalloutShow,
      ),
      notice(l.chatPinnedBy(name: 'Mira')),
      notice(l.chatPinnedNew),
      for (final kind in kPlainServerNotices.values)
        notice(l.chatServerNotice(notice: kind)),
      notice(l.chatServerNoticeTimedOut(wait: timeoutLength(600, l))),
      notice(l.chatServerNoticeSlowMode(wait: timeoutLength(12, l))),
      notice(l.chatServerNoticeUnknownCommand(command: '/\u2060dance')),
      ?ownDeletedMessageNotice(
        IRCMessage.fromString(
          '@login=me;room-id=12345;target-msg-id=m1;tmi-sent-ts=1 '
          ':tmi.twitch.tv CLEARMSG #channel :salut tout le monde',
        ),
        ownLogin: 'me',
      ),
      for (final decision in const ['approved', 'denied', 'invalid']) ...[
        notice('${l.chatHeldDecision(decision: decision)}.'),
        notice(
          l.chatHeldQuoted(
            decision: l.chatHeldDecision(decision: decision),
            quote: 'salut le chat',
          ),
        ),
      ],
      for (final text in moderation) notice(text),
      ?moderationNoticeLine(
        IRCMessage.fromString(clearChatUser),
        hiddenLogins: const {},
        newestFirst: const [],
      ),
      ?moderationNoticeLine(
        IRCMessage.fromString(
          '@room-id=12345;target-user-id=67890;tmi-sent-ts=1234567890124 '
          ':tmi.twitch.tv CLEARCHAT #channel :banneduser',
        ),
        hiddenLogins: const {},
        newestFirst: const [],
      ),
      IRCMessage.raidWelcome(
        RaidArrival(
          fromName: 'Raider',
          targetName: 'Streamer',
          viewers: 1204,
          at: DateTime.now(),
        ),
      ),
    ];
  }

  /// Sub, gift, raid and Bits lines, and messages a moderator acted on.
  List<IRCMessage> twitchLines() {
    final timedOut = IRCMessage.fromString(
      '@display-name=Troll;id=t1;user-id=67890;tmi-sent-ts=1700000000100 '
      ':banneduser!banneduser@banneduser.tmi.twitch.tv PRIVMSG #channel '
      ':spam',
    );
    final banned = IRCMessage.fromString(
      '@display-name=Spammeur;id=t2;user-id=67891;tmi-sent-ts=1700000000101 '
      ':other!other@other.tmi.twitch.tv PRIVMSG #channel :spam',
    );
    final deleted = IRCMessage.fromString(
      '@display-name=Deleted;id=target-msg-abc123;user-id=67892;'
      'tmi-sent-ts=1700000000102 '
      ':deleteduser!deleteduser@deleteduser.tmi.twitch.tv PRIVMSG #channel '
      ':deleted message content',
    );
    final moderated = [timedOut, banned, deleted];
    IRCMessage.clearChat(
      messages: moderated,
      bufferedMessages: [],
      ircMessage: IRCMessage.fromString(clearChatUser),
    );
    IRCMessage.clearChat(
      messages: moderated,
      bufferedMessages: [],
      ircMessage: IRCMessage.fromString(
        '@room-id=12345;target-user-id=67891;tmi-sent-ts=1700000000200 '
        ':tmi.twitch.tv CLEARCHAT #channel :other',
      ),
    );
    IRCMessage.clearMessage(
      messages: moderated,
      bufferedMessages: [],
      ircMessage: IRCMessage.fromString(clearMsg),
    );
    return [
      for (final raw in [
        userNoticeSubscription,
        // The viewer's own message, in English: theirs, not the app's
        // (marked as content where the lines are checked).
        resubStreak,
        resubHiddenStreak,
        primeSub,
        subGift,
        multiMonthGift,
        anonymousSubGift,
        massGiftHeader,
        anonymousMassGift,
        extendSub,
        raidNotice,
        // An IRC NOTICE, shown as Twitch sends it (English, its words).
        '@msg-id=slow_on :tmi.twitch.tv NOTICE #channel :$_slowNotice',
        // A tier Twitch does not name, a gift of months without a tier.
        '@display-name=Fan;login=fan;id=n1;msg-id=sub;msg-param-sub-plan=x;'
            'system-msg=Fan\\ssubscribed.;tmi-sent-ts=1700000000300 '
            ':tmi.twitch.tv USERNOTICE #channel',
        '@display-name=G;login=g;id=n2;msg-id=subgift;msg-param-sub-plan=x;'
            'msg-param-gift-months=6;msg-param-recipient-display-name=R;'
            'msg-param-recipient-user-name=r;msg-param-sender-count=12;'
            'system-msg=G\\sgifted\\sa\\ssub!;tmi-sent-ts=1700000000301 '
            ':tmi.twitch.tv USERNOTICE #channel',
        '@display-name=Big;login=big;id=n3;msg-id=submysterygift;'
            'msg-param-mass-gift-count=1;msg-param-sender-count=1;'
            'msg-param-sub-plan=x;msg-param-community-gift-id=77;'
            'system-msg=Big\\sis\\sgifting;tmi-sent-ts=1700000000302 '
            ':tmi.twitch.tv USERNOTICE #channel',
        // Bits, an announcement, a first and a highlighted message.
        '@bits=100;display-name=Cheerer;id=b1;user-id=1;'
            'tmi-sent-ts=1700000000400 '
            ':cheerer!cheerer@cheerer.tmi.twitch.tv PRIVMSG #channel '
            ':Cheer100 allez',
        '@display-name=Mod;id=a1;login=mod;msg-id=announcement;'
            'msg-param-color=PRIMARY;tmi-sent-ts=1700000000401 '
            ':tmi.twitch.tv USERNOTICE #channel :bonjour à tous',
        '@display-name=New;first-msg=1;id=f1;user-id=2;'
            'tmi-sent-ts=1700000000402 '
            ':new!new@new.tmi.twitch.tv PRIVMSG #channel :premier message',
        '@display-name=Pay;msg-id=highlighted-message;id=h1;user-id=3;'
            'tmi-sent-ts=1700000000403 '
            ':pay!pay@pay.tmi.twitch.tv PRIVMSG #channel :regardez-moi',
        '@display-name=Pass;msg-id=skip-subs-mode-message;id=h2;user-id=4;'
            'tmi-sent-ts=1700000000404 '
            ':pass!pass@pass.tmi.twitch.tv PRIVMSG #channel :coucou',
        '@display-name=Anim;msg-id=animated-message;id=h3;user-id=6;'
            'tmi-sent-ts=1700000000405 '
            ':anim!anim@anim.tmi.twitch.tv PRIVMSG #channel :bravo',
        '@display-name=Upgrader;login=upgrader;id=n4;msg-id=giftpaidupgrade;'
            'msg-param-sender-name=Gifter;msg-param-sender-login=gifter;'
            'system-msg=x;tmi-sent-ts=1700000000500 '
            ':tmi.twitch.tv USERNOTICE #channel',
        '@display-name=Upgrader;login=upgrader;id=n5;'
            'msg-id=anongiftpaidupgrade;system-msg=x;'
            'tmi-sent-ts=1700000000501 :tmi.twitch.tv USERNOTICE #channel',
        '@display-name=Kind;login=kind;id=n6;msg-id=standardpayforward;'
            'msg-param-prior-gifter-display-name=First;'
            'msg-param-recipient-display-name=Lucky;system-msg=x;'
            'tmi-sent-ts=1700000000502 :tmi.twitch.tv USERNOTICE #channel',
        '@display-name=Kind;login=kind;id=n7;msg-id=communitypayforward;'
            'msg-param-prior-gifter-display-name=First;system-msg=x;'
            'tmi-sent-ts=1700000000503 :tmi.twitch.tv USERNOTICE #channel',
        '@id=n8;msg-id=giftsubbasematch;msg-param-advertiser-name=Brand;'
            'msg-param-gift-sub-match-quantity=5;system-msg=x;'
            'tmi-sent-ts=1700000000504 :tmi.twitch.tv USERNOTICE #channel',
        '@display-name=Fan;login=fan;id=n9;msg-id=rewardgift;'
            'msg-param-selected-count=10;system-msg=x;'
            'tmi-sent-ts=1700000000505 :tmi.twitch.tv USERNOTICE #channel',
        '@display-name=Fan;login=fan;id=n10;msg-id=viewermilestone;'
            'msg-param-category=watch-streak;msg-param-value=7;'
            'msg-param-copoReward=1450;system-msg=x;'
            'tmi-sent-ts=1700000000506 :tmi.twitch.tv USERNOTICE #channel',
        '@display-name=Fan;login=fan;id=n11;msg-id=charitydonation;'
            'msg-param-charity-name=Save\\sthe\\sKids;'
            'msg-param-donation-amount=500;msg-param-exponent=2;'
            'msg-param-donation-currency=EUR;system-msg=x;'
            'tmi-sent-ts=1700000000507 :tmi.twitch.tv USERNOTICE #channel',
        '@display-name=X;login=x;id=n12;msg-id=resub;msg-param-sub-plan=1000;'
            'msg-param-cumulative-months=3;msg-param-multimonth-duration=6;'
            'msg-param-was-gifted=true;msg-param-gift-months=6;'
            'msg-param-gift-month-being-redeemed=2;'
            'msg-param-gifter-name=Santa;system-msg=x;'
            'tmi-sent-ts=1700000000508 :tmi.twitch.tv USERNOTICE #channel',
      ])
        IRCMessage.fromString(raw),
      ...moderated,
    ];
  }

  for (final (sizeName, size) in frenchScreenSizes) {
    for (final scale in frenchTextScales) {
      final at = '$sizeName, text ×$scale';

      for (final locale in sweepLocales) {
        testWidgets('every line in the chat, $at${sweepName(locale)}', (
          tester,
        ) async {
          await useLocale(locale);
          final store = fakeChatStore();
          final lines = [...appLines(), ...twitchLines()];
          await pumpLocalized(
            tester,
            Scaffold(
              body: ListView(
                children: [
                  for (final line in lines)
                    ChatMessage(ircMessage: line, chatStore: store),
                ],
              ),
            ),
            locale: locale,
            size: size,
            textScale: scale,
          );
          await tester.pump();
          await expectFrenchThroughout(
            tester,
            'chat lines, $at',
            content: const ['14 months!', _slowNotice],
          );
        });
      }

      testWidgets('the input: commands, reply, counter, $at', (tester) async {
        final chat = fakeChatStore();
        final text = TextEditingController();
        final focus = FocusNode();
        addTearDown(text.dispose);
        addTearDown(focus.dispose);
        final auth = _MockAuthStore();
        when(() => auth.isLoggedIn).thenReturn(true);
        when(() => chat.auth).thenReturn(auth);
        final assets = chat.assetsStore;
        when(() => assets.userEmoteToObject).thenReturn({});
        when(() => chat.matchingEmotes).thenReturn(const []);
        when(() => chat.matchingChatters).thenReturn(const []);
        when(
          () => chat.matchingCommands,
        ).thenReturn([...kModeratorChatCommands, ...kChatCommands]);
        when(() => chat.showEmoteAutocomplete).thenReturn(false);
        when(() => chat.showMentionAutocomplete).thenReturn(false);
        when(() => chat.expandChat).thenReturn(true);
        when(() => chat.restriction).thenReturn(null);
        when(
          () => chat.replyingToMessage,
        ).thenReturn(IRCMessage.fromString(basicPrivmsg));
        when(() => chat.isWaitingForAck).thenReturn(false);
        when(() => chat.isConnected).thenReturn(true);
        when(() => chat.hasConnected).thenReturn(true);
        when(() => chat.textFieldFocusNode).thenReturn(focus);
        when(() => chat.textController).thenReturn(text);
        when(() => chat.showSendButton).thenReturn(true);
        when(
          () => chat.settings,
        ).thenReturn(SettingsStore.fromJson({})..autocomplete = true);
        // Near the length limit: the counter shows.
        text.text = 'a' * 480;
        await pumpLocalized(
          tester,
          Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: ChatBottomBar(
                chatStore: chat,
                onAddChat: () {},
                channelDisplayName: 'Streamer',
              ),
            ),
          ),
          size: size,
          textScale: scale,
          wrap: (app) =>
              Provider<ChannelEventsStore?>.value(value: null, child: app),
        );
        await tester.pump();
        await expectFrenchThroughout(tester, 'input, $at');
        expect(
          find.textContaining('<${french.chatCommandArgUser}>'),
          findsWidgets,
          reason: 'the usages read « <utilisateur> »',
        );
        expect(find.textContaining('/ban'), findsWidgets);
      });

      for (final locale in sweepLocales) {
        testWidgets('the input\'s placeholders and the restriction bar keep '
            'their values in sight, $at${sweepName(locale)}', (tester) async {
          final words = lookupAppLocalizations(locale);
          // [text] with [mark] read as [digits]: a countdown that moves.
          RegExp pattern(String text, String mark, String digits) =>
              RegExp('^${RegExp.escape(text).replaceFirst(mark, digits)}\$');
          // What each one shows, and the value it must never lose to an
          // ellipsis (the channel's name, the delay, the follow age, the
          // countdown). The banned line has none: the bar shows it whole.
          final cases =
              <
                String,
                ({
                  ChatRestriction? Function() restriction,
                  bool reply,
                  double delay,
                  List<Pattern> values,
                })
              >{
                'named': (
                  restriction: () => null,
                  reply: false,
                  delay: 0,
                  values: [words.chatInChannel(name: 'Streamer')],
                ),
                'delayed': (
                  restriction: () => null,
                  reply: false,
                  delay: 5,
                  values: [
                    words.chatInChannelDelayed(name: 'Streamer', seconds: 5),
                  ],
                ),
                'reply': (
                  restriction: () => null,
                  reply: true,
                  delay: 0,
                  values: [words.chatReplyIn(name: 'Streamer')],
                ),
                'followers for a while': (
                  restriction: () => const ChatRestriction(
                    ChatRestrictionKind.followersOnly,
                    minutes: 10,
                  ),
                  reply: false,
                  delay: 0,
                  values: [
                    words.chatRestrictionFollowersFor(
                      duration: words.chatShortMinutes(minutes: 10),
                    ),
                  ],
                ),
                'timed out': (
                  restriction: () => ChatRestriction(
                    ChatRestrictionKind.timedOut,
                    until: DateTime.now().add(
                      const Duration(minutes: 4, seconds: 30),
                    ),
                  ),
                  reply: false,
                  delay: 0,
                  values: [
                    pattern(
                      words.chatRestrictionTimedOutFor(wait: '4:99'),
                      '99',
                      r'[0-3]\d',
                    ),
                  ],
                ),
                'slow mode': (
                  restriction: () => ChatRestriction(
                    ChatRestrictionKind.slowMode,
                    until: DateTime.now().add(const Duration(seconds: 30)),
                  ),
                  reply: false,
                  delay: 0,
                  values: [
                    pattern(
                      words.chatRestrictionSlow(
                        wait: words.chatShortSeconds(seconds: 99),
                      ),
                      '99',
                      r'[23]\d',
                    ),
                  ],
                ),
                'banned': (
                  restriction: () =>
                      const ChatRestriction(ChatRestrictionKind.banned),
                  reply: false,
                  delay: 0,
                  values: [words.chatRestrictionBanned],
                ),
                for (final kind in const [
                  ChatRestrictionKind.verifiedEmail,
                  ChatRestrictionKind.verifiedPhone,
                  ChatRestrictionKind.emailAliasBanned,
                  ChatRestrictionKind.phoneAliasBanned,
                  ChatRestrictionKind.accountRestricted,
                  ChatRestrictionKind.channelRestricted,
                  ChatRestrictionKind.followRequired,
                  ChatRestrictionKind.warned,
                ])
                  kind.name: (
                    restriction: () => ChatRestriction(kind),
                    reply: false,
                    delay: 0,
                    values: [ChatRestriction(kind).describe(null, words)],
                  ),
              };
          for (final MapEntry(key: name, value: setup) in cases.entries) {
            final chat = fakeChatStore();
            final text = TextEditingController();
            final focus = FocusNode();
            addTearDown(text.dispose);
            addTearDown(focus.dispose);
            final auth = _MockAuthStore();
            when(() => auth.isLoggedIn).thenReturn(true);
            when(() => chat.auth).thenReturn(auth);
            final assets = chat.assetsStore;
            when(() => assets.userEmoteToObject).thenReturn({});
            when(() => chat.matchingEmotes).thenReturn(const []);
            when(() => chat.matchingChatters).thenReturn(const []);
            when(() => chat.matchingCommands).thenReturn(const []);
            when(() => chat.showEmoteAutocomplete).thenReturn(false);
            when(() => chat.showMentionAutocomplete).thenReturn(false);
            when(() => chat.expandChat).thenReturn(true);
            when(() => chat.restriction).thenReturn(setup.restriction());
            when(() => chat.replyingToMessage).thenReturn(
              setup.reply ? IRCMessage.fromString(basicPrivmsg) : null,
            );
            when(() => chat.isWaitingForAck).thenReturn(false);
            when(() => chat.isConnected).thenReturn(true);
            when(() => chat.hasConnected).thenReturn(true);
            when(() => chat.textFieldFocusNode).thenReturn(focus);
            when(() => chat.textController).thenReturn(text);
            when(() => chat.showSendButton).thenReturn(false);
            when(() => chat.settings).thenReturn(
              SettingsStore.fromJson({})
                ..showVideo = true
                ..autoSyncChatDelay = false
                ..chatDelay = setup.delay,
            );
            await pumpLocalized(
              tester,
              Scaffold(
                body: Align(
                  alignment: Alignment.bottomCenter,
                  child: ChatBottomBar(
                    chatStore: chat,
                    onAddChat: () {},
                    channelDisplayName: 'Streamer',
                  ),
                ),
              ),
              locale: locale,
              size: size,
              textScale: scale,
              wrap: (app) =>
                  Provider<ChannelEventsStore?>.value(value: null, child: app),
            );
            await tester.pump();
            final where = '$name, $at';
            await expectFrenchThroughout(tester, 'input, $where');
            // The one-line bar above the input never loses words; nor does
            // the placeholder when it carries a value.
            final bar = find.byType(ChatRestrictionBar);
            expect(
              ellipsizedTexts(tester, within: bar),
              isEmpty,
              reason: where,
            );
            if (setup.restriction()?.showsBar != true) {
              expect(ellipsizedTexts(tester), isEmpty, reason: where);
            }
            final shown = [
              for (final element in find.byType(RichText).evaluate())
                (element.widget as RichText).text.toPlainText(),
            ];
            for (final value in setup.values) {
              expect(
                shown.any(
                  (text) => value is String
                      ? text == value
                      : value.allMatches(text).isNotEmpty,
                ),
                isTrue,
                reason: '$where: $value in $shown',
              );
            }
            await tester.pumpWidget(const SizedBox.shrink());
          }
        });
      }

      testWidgets('the moderation bar and its dialog, $at', (tester) async {
        final answer = Completer<ModerationOutcome?>();
        await pumpLocalized(
          tester,
          Scaffold(
            body: Align(
              alignment: const Alignment(0, 0.4),
              child: ChatModerationBar(
                login: 'troll',
                name: 'Troll',
                onModerate: (_) => answer.future,
              ),
            ),
          ),
          size: size,
          textScale: scale,
        );
        await expectFrenchThroughout(tester, 'moderation bar, $at');
        // « Exclure » on screen, the full words for a screen reader.
        expect(find.text(french.chatModBarTimeoutShort), findsOneWidget);
        expect(find.bySemanticsLabel(french.chatModBarTimeout), findsOneWidget);
        await tester.tap(find.text(french.chatModBarTimeoutShort));
        await tester.pumpAndSettle();
        await expectFrenchThroughout(tester, 'timeout lengths, $at');
        await tester.tapAt(Offset.zero);
        await tester.pumpAndSettle();
        await tester.tap(find.text(french.chatModBarBan));
        await tester.pumpAndSettle();
        await expectFrenchThroughout(tester, 'ban dialog, $at');
        await tester.tap(find.text(french.commonCancel));
        await tester.pumpAndSettle();
        await tester.tap(find.text(french.chatModBarUnban));
        await tester.pump();
        answer.complete((
          ok: false,
          message: L10n.current.chatModCannotModerate,
        ));
        await tester.pumpAndSettle();
        await expectFrenchThroughout(tester, 'moderation outcome, $at');
      });

      testWidgets('the chat modes, $at', (tester) async {
        await pumpLocalized(
          tester,
          Scaffold(
            body: SingleChildScrollView(
              child: ChatModeControls(
                roomState: const ROOMSTATE(
                  slowMode: '30',
                  followersOnly: '10',
                  subMode: '1',
                  emoteOnly: '1',
                  r9k: '1',
                ),
                onModerate: (_) async => (
                  ok: true,
                  message: L10n.current.chatModeSlowOn(
                    duration: timeoutLength(30),
                  ),
                ),
              ),
            ),
          ),
          size: size,
          textScale: scale,
        );
        await expectFrenchThroughout(tester, 'chat modes, $at');
        await tester.tap(find.text(french.chatModesClearChat));
        await tester.pumpAndSettle();
        await expectFrenchThroughout(tester, 'clear chat dialog, $at');
      });

      testWidgets('the user card, $at', (tester) async {
        final store = fakeChatStore();
        final api = _MockTwitchApi();
        when(() => api.getUser(id: any(named: 'id'))).thenAnswer(
          (_) async => UserTwitch(
            '33',
            'troll',
            'Troll',
            '',
            createdAt: DateTime(2019, 3, 1, 12),
          ),
        );
        when(
          () => api.getFollowedAt(
            broadcasterId: any(named: 'broadcasterId'),
            userId: any(named: 'userId'),
          ),
        ).thenAnswer((_) async => DateTime(2023, 1, 12, 12));
        final auth = _MockAuthStore();
        final user = _MockUserStore();
        when(() => auth.isLoggedIn).thenReturn(true);
        when(() => auth.user).thenReturn(user);
        when(
          () => user.details,
        ).thenReturn(const UserTwitch('1', 'mod', 'Mod', ''));
        final text = TextEditingController();
        addTearDown(text.dispose);
        when(() => store.auth).thenReturn(auth);
        when(() => store.twitchApi).thenReturn(api);
        when(() => store.whispers).thenReturn(null);
        when(() => store.canModerate).thenReturn(true);
        when(() => store.textController).thenReturn(text);
        when(() => store.safeRequestFocus()).thenReturn(null);
        when(() => store.messages).thenReturn(
          ObservableList.of([
            IRCMessage.fromString(
              '@display-name=Troll;user-id=33;id=a '
              ':troll!troll@troll.tmi.twitch.tv PRIVMSG #channel :clip ça',
            ),
          ]),
        );
        late BuildContext inside;
        await pumpLocalized(
          tester,
          Scaffold(
            body: PanelRegion(
              child: Builder(
                builder: (context) {
                  inside = context;
                  return const SizedBox.expand();
                },
              ),
            ),
          ),
          size: size,
          textScale: scale,
          wrap: (app) => Provider<TwitchApi>.value(value: api, child: app),
        );
        showChatUserCard(
          inside,
          chatStore: store,
          username: 'troll',
          userId: '33',
          displayName: 'Troll',
        );
        await tester.pumpAndSettle();
        await expectFrenchThroughout(tester, 'user card, $at');
        expect(
          find.textContaining(
            french.chatUserAccountCreated(date: '1er mars 2019'),
          ),
          findsOneWidget,
        );
      });

      testWidgets('the emote menu, $at', (tester) async {
        final settings = SettingsStore.fromJson({});
        final chat = fakeChatStore(settings: settings);
        Emote emote(String name, EmoteType type) => Emote(
          name: name,
          zeroWidth: false,
          url: 'https://cdn.example/$name.png',
          type: type,
        );
        final assets = chat.assetsStore;
        when(() => assets.recentEmotes).thenReturn(
          ObservableList.of([
            const Emote(
              name: 'seasonal',
              zeroWidth: false,
              url: 'https://cdn.example/seasonal.png',
              type: EmoteType.twitchUnlocked,
              limitedTime: true,
            ),
          ]),
        );
        when(() => assets.emoteToObject).thenReturn({});
        when(() => assets.userEmoteToObject).thenReturn({});
        when(() => assets.userEmoteSectionToEmotes).thenReturn({
          'Channel Emotes': [
            emote('nisqyHype', EmoteType.twitchSub),
            const Emote(
              name: 'nisqyTier',
              zeroWidth: false,
              url: 'https://cdn.example/nisqyTier.png',
              type: EmoteType.twitchChannel,
              subTier: 2,
              animated: true,
            ),
            emote('nisqyLove', EmoteType.twitchFollower),
          ],
          'Global Emotes': [emote('Kappa', EmoteType.twitchGlobal)],
          'Unlocked Emotes': [emote('Prime', EmoteType.twitchUnlocked)],
          'Other Channels': [emote('Other', EmoteType.twitchSub)],
        });
        when(() => assets.sevenTVEmotes).thenReturn([
          emote('KEKW', EmoteType.sevenTVChannel),
          emote('OMEGALUL', EmoteType.sevenTVGlobal),
        ]);
        when(
          () => assets.bttvEmotes,
        ).thenReturn([emote('monkaW', EmoteType.bttvGlobal)]);
        when(
          () => assets.ffzEmotes,
        ).thenReturn([emote('LULW', EmoteType.ffzGlobal)]);
        when(() => chat.userState).thenReturn(const USERSTATE());
        await pumpLocalized(
          tester,
          Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(height: 320, child: EmoteMenu(chatStore: chat)),
            ),
          ),
          size: size,
          textScale: scale,
          wrap: (app) =>
              Provider<SettingsStore>.value(value: settings, child: app),
        );
        await tester.pump();
        await expectFrenchThroughout(tester, 'emote menu, recent, $at');
        await tester.longPress(find.byType(EmoteCell).first);
        await tester.pumpAndSettle();
        expect(find.text(french.emoteMenuRemoveRecent), findsOneWidget);
        expect(find.text(french.emoteLimitedTime), findsOneWidget);
        await expectFrenchThroughout(tester, 'recent emote details, $at');
        await tester.tapAt(const Offset(4, 4));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Twitch'));
        await tester.pumpAndSettle();
        await expectFrenchThroughout(tester, 'emote menu, Twitch, $at');
        expect(find.text(french.emoteMenuChannel), findsOneWidget);
        expect(
          find.text(french.emoteMenuFollowerInfo(channel: 'Channel')),
          findsOneWidget,
        );
        await tester.tap(
          find.byWidgetPredicate(
            (w) => w is EmoteCell && w.emote.name == 'nisqyTier',
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(french.emoteUnlockTier(tier: 2)), findsOneWidget);
        await expectFrenchThroughout(tester, 'locked emote details, $at');
        await tester.tapAt(const Offset(4, 4));
        await tester.pumpAndSettle();
        await tester.tap(find.text('7TV'));
        await tester.pumpAndSettle();
        await expectFrenchThroughout(tester, 'emote menu, 7TV, $at');
      });

      for (final locale in sweepLocales) {
        testWidgets('the chat details, $at${sweepName(locale)}', (
          tester,
        ) async {
          final words = lookupAppLocalizations(locale);
          final api = _MockTwitchApi();
          when(
            () => api.getUserChatColor(userId: any(named: 'userId')),
          ).thenAnswer((_) async => '#FF7F50');
          final auth = _MockAuthStore();
          final user = _MockUserStore();
          when(() => auth.isLoggedIn).thenReturn(true);
          when(() => auth.user).thenReturn(user);
          when(
            () => user.details,
          ).thenReturn(const UserTwitch('1', 'viewer', 'Viewer', ''));
          final settings = SettingsStore.fromJson({});
          final details = ChatDetailsStore(
            twitchApi: api,
            channelName: 'channel',
          );
          final store = fakeChatStore(settings: settings);
          when(() => store.auth).thenReturn(auth);
          when(() => store.twitchApi).thenReturn(api);
          when(() => store.chatDetailsStore).thenReturn(details);
          when(() => store.chatRules).thenReturn(null);
          when(() => store.canModerate).thenReturn(true);
          when(() => store.timeRemaining).thenReturn(Duration.zero);
          when(() => store.sleepTimer).thenReturn(null);
          when(() => store.userState).thenReturn(const USERSTATE());
          await pumpLocalized(
            tester,
            Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showChatDetails(
                    context,
                    chatStore: store,
                    onAddChat: () {},
                  ),
                  child: const Text('⋯'),
                ),
              ),
            ),
            locale: locale,
            size: size,
            textScale: scale,
          );
          await tester.tap(find.text('⋯'));
          await tester.pumpAndSettle();
          await expectFrenchThroughout(tester, 'chat details, $at');
          final menu = find
              .descendant(
                of: find.byType(ChatDetails),
                matching: find.byType(Scrollable),
              )
              .first;
          await tester.scrollUntilVisible(
            find.text(words.settingsIncreaseChatContrast),
            80,
            scrollable: menu,
          );
          await tester.pumpAndSettle();
          await expectFrenchThroughout(tester, 'chat preferences, $at');
          await tester.scrollUntilVisible(
            find.text(words.chatDetailsSleepTimer),
            -80,
            scrollable: menu,
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text(words.chatDetailsSleepTimer));
          await tester.pumpAndSettle();
          await expectFrenchThroughout(tester, 'sleep timer, $at');
          // Back to the menu, as the system back does.
          await tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.text(words.chatDetailsUsernameColor),
            -80,
            scrollable: find
                .descendant(
                  of: find.byType(ChatDetails),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text(words.chatDetailsUsernameColor));
          await tester.pumpAndSettle();
          await expectFrenchThroughout(tester, 'name colours, $at');
        });
      }

      testWidgets('the warning dialog, $at', (tester) async {
        await pumpLocalized(
          tester,
          const Scaffold(body: ChatWarningDialog()),
          size: size,
          textScale: scale,
        );
        await tester.pump();
        expect(find.text(french.chatWarningAcknowledge), findsOneWidget);
        await expectFrenchThroughout(tester, 'warning dialog, $at');
      });

      testWidgets('a watch streak to share, $at', (tester) async {
        await pumpLocalized(
          tester,
          Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: WatchStreakCard(
                streak: const WatchStreak(
                  value: 5,
                  threshold: 5,
                  pointsBonus: 450,
                  milestoneId: 'm1',
                  canShare: true,
                ),
                live: true,
                channelName: 'Streamer',
                onShare: () {},
              ),
            ),
          ),
          size: size,
          textScale: scale,
        );
        await tester.pump();
        expect(find.text(french.streakShareInChat), findsOneWidget);
        await expectFrenchThroughout(tester, 'watch streak share, $at');
      });

      testWidgets('a resub to share, $at', (tester) async {
        await pumpLocalized(
          tester,
          Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: ResubShareCard(
                resub: const ResubNotification(months: 14, tokenId: 't'),
                onShare: () {},
              ),
            ),
          ),
          size: size,
          textScale: scale,
        );
        await tester.pump();
        expect(find.text(french.resubShareTitle(months: 14)), findsOneWidget);
        await expectFrenchThroughout(tester, 'resub share, $at');
      });

      testWidgets('the resub share dialog, $at', (tester) async {
        await pumpLocalized(
          tester,
          const Scaffold(body: ResubShareDialog()),
          size: size,
          textScale: scale,
        );
        await tester.pump();
        expect(find.text(french.resubShareSend), findsOneWidget);
        await expectFrenchThroughout(tester, 'resub share dialog, $at');
      });

      for (final signedIn in [true, false]) {
        testWidgets('the Drops card, signed in $signedIn, $at', (tester) async {
          final campaigns = DropCampaign.listFrom(
            signedIn
                ? signedInDropCampaignsResponse(connected: false)
                : anonymousDropCampaignsResponse,
          )!;
          await pumpLocalized(
            tester,
            Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: DropsCard(
                  campaigns: campaigns,
                  onClaim: (_) {},
                  onLinkAccount: (_) {},
                ),
              ),
            ),
            size: size,
            textScale: scale,
          );
          await tester.pump();
          expect(find.text(french.dropsCardTitle), findsOneWidget);
          await expectFrenchThroughout(tester, 'drops $signedIn, $at');
        });
      }

      testWidgets('the community goals, $at', (tester) async {
        final goals = CommunityGoal.listFrom(
          communityGoalsResponse([
            communityGoalFixture(),
            communityGoalFixture(id: 'goal-2', status: 'ENDED'),
          ]),
        )!;
        await pumpLocalized(
          tester,
          Scaffold(
            body: CommunityGoalsSheet(
              load: () async => [
                goals.first,
                goals.last,
                goals.first.withContributedThisStream(2000),
              ],
              balance: () => 5000,
              contribute: (_, _) async => GoalContributionResult.contributed,
            ),
          ),
          size: size,
          textScale: scale,
        );
        await tester.pumpAndSettle();
        expect(find.text(french.communityGoalsTitle), findsOneWidget);
        await expectFrenchThroughout(tester, 'community goals, $at');
      });

      testWidgets('the goal contribution dialog, $at', (tester) async {
        final goal = CommunityGoal.listFrom(
          communityGoalsResponse([communityGoalFixture()]),
        )!.single;
        await pumpLocalized(
          tester,
          Scaffold(body: GoalContributionDialog(goal: goal, maximum: 2000)),
          size: size,
          textScale: scale,
        );
        await tester.pump();
        expect(find.text(french.communityGoalContributeTitle), findsOneWidget);
        await expectFrenchThroughout(tester, 'goal contribution, $at');
      });

      testWidgets('the streak help without a streak, $at', (tester) async {
        await pumpLocalized(
          tester,
          const Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: StreakHelpCard(),
            ),
          ),
          size: size,
          textScale: scale,
        );
        await tester.pump();
        await tester.tap(find.byKey(WatchStreakCard.helpKey));
        await tester.pumpAndSettle();
        expect(find.text(french.streakHelpBody), findsOneWidget);
        await expectFrenchThroughout(tester, 'streak help alone, $at');
      });

      for (final kind in LeaderboardKind.values) {
        testWidgets('the leaderboards, ${kind.name}, $at', (tester) async {
          await pumpLocalized(
            tester,
            Scaffold(
              body: LeaderboardsSheet(
                load: () async => ChannelLeaderboards(
                  period: LeaderboardPeriod.allTime,
                  boards: {
                    for (final board in LeaderboardKind.values)
                      board: [
                        const LeaderboardEntry(
                          rank: 1,
                          score: 1234567,
                          userId: '1',
                          displayName: 'UnSpectateurAuNomTrèsLong',
                        ),
                        const LeaderboardEntry(
                          rank: 2,
                          score: 1,
                          userId: '2',
                          displayName: 'Deux',
                        ),
                      ],
                  },
                  preferred: kind,
                  mine: {
                    kind: const LeaderboardEntry(
                      rank: 12,
                      score: 3,
                      userId: '9',
                      displayName: 'Moi',
                    ),
                  },
                ),
              ),
            ),
            size: size,
            textScale: scale,
          );
          await tester.pumpAndSettle();
          expect(find.text(french.leaderboardsTitle), findsOneWidget);
          await expectFrenchThroughout(
            tester,
            'leaderboards ${kind.name}, $at',
          );
        });
      }

      testWidgets('the leaderboards failing, $at', (tester) async {
        await pumpLocalized(
          tester,
          Scaffold(body: LeaderboardsSheet(load: () async => null)),
          size: size,
          textScale: scale,
        );
        await tester.pumpAndSettle();
        expect(find.text(french.leaderboardsFailed), findsOneWidget);
        await expectFrenchThroughout(tester, 'leaderboards failed, $at');
      });

      testWidgets('the shoutout card, $at', (tester) async {
        await pumpLocalized(
          tester,
          Scaffold(
            body: ShoutoutCard(
              notice: const ShoutoutNotice(
                id: 's',
                targetId: '2',
                targetLogin: 'unechaine',
                targetName: 'UneChaîneAuNomTrèsLong',
              ),
              load: () async => ShoutoutProfile(
                id: '2',
                login: 'unechaine',
                displayName: 'UneChaîneAuNomTrèsLong',
                categories: const [
                  ShoutoutCategory(id: '1', name: 'Juste discuter'),
                  ShoutoutCategory(id: '2', name: 'Grand Theft Auto V'),
                  ShoutoutCategory(id: '3', name: 'VALORANT'),
                ],
                nextStream: ShoutoutSchedule(
                  startAt: DateTime(2026, 12, 1, 20, 30),
                  title: 'Soirée classée',
                ),
              ),
              onViewProfile: () {},
            ),
          ),
          size: size,
          textScale: scale,
        );
        await tester.pumpAndSettle();
        expect(find.text(french.shoutoutCardRecent), findsOneWidget);
        await expectFrenchThroughout(tester, 'shoutout card, $at');
      });

      testWidgets('the shoutout card failing, $at', (tester) async {
        await pumpLocalized(
          tester,
          Scaffold(
            body: ShoutoutCard(
              notice: const ShoutoutNotice(
                id: 's',
                targetId: '2',
                targetLogin: 'unechaine',
                targetName: 'UneChaîne',
              ),
              load: () async => null,
              onViewProfile: () {},
            ),
          ),
          size: size,
          textScale: scale,
        );
        await tester.pumpAndSettle();
        expect(find.text(french.shoutoutCardFailed), findsOneWidget);
        await expectFrenchThroughout(tester, 'shoutout failed, $at');
      });

      testWidgets('the watch streak help, $at', (tester) async {
        await pumpLocalized(
          tester,
          const Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: WatchStreakCard(
                streak: WatchStreak(value: 3, threshold: 5, pointsBonus: 450),
                live: true,
                channelName: 'Streamer',
              ),
            ),
          ),
          size: size,
          textScale: scale,
        );
        await tester.pump();
        await tester.tap(find.byKey(WatchStreakCard.helpKey));
        await tester.pumpAndSettle();
        expect(find.text(french.streakHelpBody), findsOneWidget);
        await expectFrenchThroughout(tester, 'watch streak help, $at');
      });

      testWidgets('channel points, a prediction and the bet, $at', (
        tester,
      ) async {
        final service = _MockPointsService();
        final points = CommunityPointsContext(
          balance: 12400,
          rewards: const [
            PointsReward(id: 'hydrate', title: 'Hydrate', cost: 100),
            PointsReward(
              id: 'auto',
              title: 'Highlight my message',
              cost: 50,
              automaticType: 'SEND_HIGHLIGHTED_MESSAGE',
            ),
          ],
          predictions: [
            Prediction(
              id: 'pred',
              title: 'Va-t-il gagner ?',
              status: 'ACTIVE',
              outcomes: const [
                PredictionOutcome(
                  id: 'yes',
                  title: 'Oui',
                  color: 'BLUE',
                  totalPoints: 3000,
                  totalUsers: 3,
                ),
                PredictionOutcome(
                  id: 'no',
                  title: 'Non',
                  color: 'PINK',
                  totalPoints: 1000,
                  totalUsers: 1,
                ),
              ],
            ),
          ],
        );
        when(
          () => service.fetchContext(
            userLogin: any(named: 'userLogin'),
            authToken: any(named: 'authToken'),
          ),
        ).thenAnswer((_) async => points);
        final streaks = _MockWatchStreakService();
        when(
          () => streaks.getWatchStreak(
            channelId: any(named: 'channelId'),
            authToken: any(named: 'authToken'),
          ),
        ).thenAnswer(
          (_) async =>
              const WatchStreak(value: 4, threshold: 5, pointsBonus: 450),
        );
        final store = ChannelEventsStore(
          channelId: '42',
          channelLogin: 'streamer',
          channelName: 'Streamer',
          isChannelLive: () => true,
          client: _MockHermesClient(),
          pointsService: service,
          watchStreakService: streaks,
          tokenProvider: () async => 'tok',
        );
        await store.refreshPoints();
        await store.refreshWatchStreak();
        await pumpLocalized(
          tester,
          Scaffold(
            body: ChannelPointsSheet(points: points, store: store),
          ),
          size: size,
          textScale: scale,
        );
        await tester.pump();
        // The prediction's heading (in capitals), before the lists scroll.
        expect(
          find.text(french.pointsPredictionOpen.toUpperCase()),
          findsOneWidget,
        );
        await expectFrenchThroughout(tester, 'channel points, $at');
        // Back to the top, where the outcomes are.
        for (final list in tester.stateList<ScrollableState>(
          find.byType(Scrollable),
        )) {
          list.position.jumpTo(0);
        }
        await tester.pump();
        await tester.tap(find.text('Oui'));
        await tester.pumpAndSettle();
        await expectFrenchThroughout(tester, 'bet, $at');
      });
    }
  }

  test('every command, mode and emote kind has French words', () {
    for (final command in [...kChatCommands, ...kModeratorChatCommands]) {
      expect(command.description(french), isNotEmpty, reason: command.name);
      expect(command.usage(french), startsWith('/${command.name}'));
    }
    expect(
      [for (final c in kModeratorChatCommands) c.usage(french)],
      containsAll([
        '/ban <utilisateur> [motif]',
        '/timeout <utilisateur> [durée] [motif]',
        '/delete <ID\u00a0du\u00a0message>',
        '/slow [secondes]',
      ]),
    );
    for (final mode in ChatMode.values) {
      expect(french.chatModeName(mode: mode.name), isNotEmpty);
      expect(french.chatModePill(mode: mode.name), isNotEmpty);
    }
    for (final type in EmoteType.values) {
      expect(french.emoteTypeName(type: type.name), isNotEmpty);
    }
  });
}

/// An IRC NOTICE as Twitch sends it: its words, never translated.
const _slowNotice =
    'This room is now in slow mode. You may send messages every 30 seconds.';
