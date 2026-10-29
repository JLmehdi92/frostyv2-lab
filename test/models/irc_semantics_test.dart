import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/models/badges.dart';
import 'package:onset/models/cheermote.dart';
import 'package:onset/models/emotes.dart';
import 'package:onset/models/irc.dart';
import 'package:onset/screens/channel/chat/stores/chat_assets_store.dart';

class MockChatAssetsStore extends Mock implements ChatAssetsStore {}

void main() {
  late MockChatAssetsStore assets;

  setUp(() {
    assets = MockChatAssetsStore();
    when(() => assets.cheermotes).thenReturn(Cheermotes.empty);
    when(() => assets.emoteToObject).thenReturn({
      'catJAM': const Emote(
        name: 'catJAM',
        zeroWidth: false,
        url: 'https://cdn.7tv.app/emote/a/3x.webp',
        type: EmoteType.sevenTVChannel,
      ),
      'RainTime': const Emote(
        name: 'RainTime',
        zeroWidth: true,
        url: 'https://cdn.7tv.app/emote/b/3x.webp',
        type: EmoteType.sevenTVChannel,
      ),
    });
    when(() => assets.twitchBadgesToObject).thenReturn({
      'subscriber/12': const ChatBadge(
        name: '1-Year Subscriber',
        url: 'https://static-cdn.jtvnw.net/badges/v1/x/3',
        type: BadgeType.twitch,
      ),
    });
    when(() => assets.userToFFZBadges).thenReturn({});
    when(() => assets.userTo7TVBadges).thenReturn({});
    when(() => assets.userToBTTVBadges).thenReturn({});
    when(() => assets.ffzRoomInfo).thenReturn(null);
  });

  Future<void> render(WidgetTester tester, String line) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Text.rich(
              TextSpan(
                children: IRCMessage.fromString(line).generateSpan(
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
  }

  testWidgets('screen readers hear the names of emotes and badges', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await render(
      tester,
      '@badges=subscriber/12;display-name=Fan :fan!fan@fan.tmi.twitch.tv '
      'PRIVMSG #c :hi catJAM',
    );

    expect(find.bySemanticsLabel('catJAM'), findsOneWidget);
    expect(find.bySemanticsLabel('1-Year Subscriber'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('a zero-width stack reads as its emotes joined', (tester) async {
    final semantics = tester.ensureSemantics();
    await render(
      tester,
      '@display-name=Fan :fan!fan@fan.tmi.twitch.tv PRIVMSG #c '
      ':catJAM RainTime',
    );

    expect(find.bySemanticsLabel('catJAM + RainTime'), findsOneWidget);
    semantics.dispose();
  });
}
