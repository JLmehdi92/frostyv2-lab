import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/models/badges.dart';
import 'package:onset/models/cheermote.dart';
import 'package:onset/models/irc.dart';
import 'package:onset/models/user.dart';
import 'package:onset/screens/channel/chat/chat.dart';
import 'package:onset/screens/channel/chat/details/chat_modes.dart';
import 'package:onset/screens/channel/chat/stores/chat_assets_store.dart';
import 'package:onset/screens/channel/chat/widgets/shared_chat_banner.dart';
import 'package:onset/screens/channel/stores/channel_events_store.dart';
import 'package:onset/widgets/external_link_dialog.dart';
import 'package:provider/provider.dart';

import '../helpers/chat_widget_harness.dart';
import '../helpers/l10n.dart';

class _MockChatAssetsStore extends Mock implements ChatAssetsStore {}

const _partners = [
  UserTwitch('777', 'guest', 'Guest', ''),
  UserTwitch('778', 'cohost', 'Cohost', ''),
];

void main() {
  for (final (sizeName, size) in frenchScreenSizes) {
    for (final scale in frenchTextScales) {
      final at = '$sizeName, text ×$scale';
      for (final locale in sweepLocales) {
        final name = sweepName(locale);

        testWidgets('the outside link dialog, $at$name', (tester) async {
          await pumpLocalized(
            tester,
            Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showExternalLinkDialog(
                    context,
                    Uri.parse('https://www.example-long-domain-name.com/page'),
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
          await expectFrenchThroughout(
            tester,
            'link dialog, $at',
            content: const ['https://www.example-long-domain-name.com/page'],
          );
        });

        testWidgets('the shared chat banner, $at$name', (tester) async {
          final chat = chatWidgetStore();
          when(() => chat.showSharedChatBanner).thenReturn(true);
          when(() => chat.sharedChatPartners).thenReturn(_partners);
          await pumpLocalized(
            tester,
            Scaffold(
              body: Chat(chatStore: chat, onAddChat: () {}),
            ),
            locale: locale,
            size: size,
            textScale: scale,
            wrap: (app) =>
                Provider<ChannelEventsStore?>.value(value: null, child: app),
          );
          await tester.pumpAndSettle();
          expect(find.byType(SharedChatBanner), findsOneWidget);
          await expectFrenchThroughout(tester, 'shared chat banner, $at');
        });

        testWidgets('a badge and the chat modes, $at$name', (tester) async {
          final assets = _MockChatAssetsStore();
          when(() => assets.cheermotes).thenReturn(Cheermotes.empty);
          when(() => assets.emoteToObject).thenReturn({});
          when(() => assets.twitchBadgesToObject).thenReturn({
            'subscriber/12': const ChatBadge(
              name: '1-Year Subscriber',
              url: 'https://cdn.example/sub.png',
              type: BadgeType.twitch,
            ),
          });
          when(() => assets.userToFFZBadges).thenReturn({});
          when(() => assets.userTo7TVBadges).thenReturn({});
          when(() => assets.userToBTTVBadges).thenReturn({});
          when(() => assets.ffzRoomInfo).thenReturn(null);
          await pumpLocalized(
            tester,
            Scaffold(
              body: Column(
                children: [
                  const SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ChatModes(
                      roomState: ROOMSTATE(
                        slowMode: '30',
                        followersOnly: '10',
                        r9k: '1',
                        subMode: '1',
                        emoteOnly: '1',
                      ),
                    ),
                  ),
                  Builder(
                    builder: (context) => Text.rich(
                      TextSpan(
                        children:
                            IRCMessage.fromString(
                              '@badges=subscriber/12;display-name=Fan '
                              ':fan!fan@fan.tmi.twitch.tv PRIVMSG #c :salut',
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
                ],
              ),
            ),
            locale: locale,
            size: size,
            textScale: scale,
          );
          await expectFrenchThroughout(
            tester,
            'chat modes, $at',
            content: const ['Fan', 'salut'],
          );
          await tester.tap(find.bySemanticsLabel('1-Year Subscriber'));
          await tester.pumpAndSettle();
          expect(find.byType(BadgeDetails), findsOneWidget);
          await expectFrenchThroughout(
            tester,
            'badge details, $at',
            content: const ['1-Year Subscriber', 'Fan', 'salut'],
          );
        });
      }
    }
  }

  testWidgets('the strip in the chat menu lists every partner', (tester) async {
    await pumpLocalized(
      tester,
      const Scaffold(body: SharedChatStrip(channels: _partners)),
    );
    expect(find.text('Guest'), findsOneWidget);
    expect(find.text('Cohost'), findsOneWidget);
    expect(find.text('CHAT PARTAGÉ AVEC'), findsOneWidget);
  });
}
