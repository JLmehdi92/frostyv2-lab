import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/l10n/app_localizations.dart';
import 'package:onset/models/badges.dart';
import 'package:onset/models/cheermote.dart';
import 'package:onset/models/irc.dart';
import 'package:onset/screens/channel/chat/stores/chat_assets_store.dart';
import 'package:onset/theme.dart';

class MockChatAssetsStore extends Mock implements ChatAssetsStore {}

void main() {
  test('Twitch badge sets map to an explanation, others to none', () {
    expect(twitchBadgeExplainerKind('vip/1'), 'vip');
    expect(twitchBadgeExplainerKind('subscriber/3012'), 'subscriber');
    expect(twitchBadgeExplainerKind('sub-gifter/50'), 'subGifter');
    expect(twitchBadgeExplainerKind('bits-leader/1'), 'bitsLeader');
    expect(twitchBadgeExplainerKind('lead_moderator/1'), 'leadModerator');
    expect(twitchBadgeExplainerKind('glhf-pledge/1'), isNull);
  });

  testWidgets('a tapped badge says what it means', (tester) async {
    final assets = MockChatAssetsStore();
    when(() => assets.cheermotes).thenReturn(Cheermotes.empty);
    when(() => assets.emoteToObject).thenReturn({});
    when(() => assets.twitchBadgesToObject).thenReturn({
      'vip/1': const ChatBadge(
        name: 'VIP',
        url: 'https://cdn.example/vip.png',
        type: BadgeType.twitch,
      ),
      'glhf-pledge/1': const ChatBadge(
        name: 'GLHF Pledge',
        url: 'https://cdn.example/glhf.png',
        type: BadgeType.twitch,
      ),
    });
    when(() => assets.userToFFZBadges).thenReturn({});
    when(() => assets.userTo7TVBadges).thenReturn({});
    when(() => assets.userToBTTVBadges).thenReturn({});
    when(() => assets.ffzRoomInfo).thenReturn(null);
    await tester.pumpWidget(
      MaterialApp(
        theme: const OnsetThemes(colorSchemeSeed: OnsetTokens.accent).dark,
        home: Scaffold(
          body: Builder(
            builder: (context) => Text.rich(
              TextSpan(
                children:
                    IRCMessage.fromString(
                      '@badges=vip/1,glhf-pledge/1;display-name=Fan '
                      ':fan!fan@fan.tmi.twitch.tv PRIVMSG #c :hi',
                    ).generateSpan(
                      context,
                      assetsStore: assets,
                      badgeScale: 1,
                      emoteScale: 1,
                      launchExternal: false,
                    ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.bySemanticsLabel('VIP'));
    await tester.pumpAndSettle();
    expect(find.text('Twitch badge'), findsOneWidget);
    expect(find.text('Named a VIP by this channel.'), findsOneWidget);
    Navigator.of(tester.element(find.text('Twitch badge'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('GLHF Pledge'));
    await tester.pumpAndSettle();
    expect(find.text('Twitch badge'), findsOneWidget);
    expect(find.byType(BadgeDetails), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(BadgeDetails),
        matching: find.byType(Text),
      ),
      findsOneWidget,
    );
  });

  test('a channel badge from a shared chat names that channel', () {
    final l = lookupAppLocalizations(const Locale('en'));
    expect(
      badgeExplainerText(l, 'moderator', (elsewhere: true, channel: 'Guest')),
      'Moderates Guest’s chat.',
    );
    expect(
      badgeExplainerText(l, 'moderator', (elsewhere: true, channel: null)),
      isNull,
    );
    expect(
      badgeExplainerText(l, 'staff', (elsewhere: true, channel: null)),
      'Works at Twitch.',
    );
    expect(
      badgeExplainerText(l, 'moderator', (elsewhere: false, channel: null)),
      'Moderates this channel’s chat.',
    );
  });
}
