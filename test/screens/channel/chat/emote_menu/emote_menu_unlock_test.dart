import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart' show ObservableList;
import 'package:mocktail/mocktail.dart';
import 'package:onset/models/emotes.dart';
import 'package:onset/models/irc.dart';
import 'package:onset/screens/channel/chat/emote_menu/emote_menu.dart';
import 'package:onset/screens/channel/chat/emote_menu/emote_menu_section.dart';
import 'package:onset/screens/channel/chat/stores/chat_assets_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/theme.dart';
import 'package:provider/provider.dart';

import '../../../../helpers/chat_message_harness.dart';

Emote _emote(
  String name,
  EmoteType type, {
  int? subTier,
  bool animated = false,
}) => Emote(
  name: name,
  zeroWidth: false,
  url: 'https://cdn.example/$name.png',
  type: type,
  subTier: subTier,
  animated: animated,
);

void main() {
  late MockChatStore chat;
  late ObservableList<Emote> recent;
  late SettingsStore settings;

  setUpAll(() => registerFallbackValue(_emote('x', EmoteType.twitchGlobal)));

  setUp(() {
    settings = SettingsStore.fromJson({});
    chat = fakeChatStore(settings: settings);
    recent = ObservableList.of([_emote('KEKW', EmoteType.sevenTVChannel)]);
    final assets = chat.assetsStore;
    when(() => assets.recentEmotes).thenReturn(recent);
    when(() => assets.userEmoteToObject).thenReturn({});
    when(() => assets.emoteToObject).thenReturn({});
    when(() => assets.userEmoteSectionToEmotes).thenReturn({
      UserEmoteSection.channel: [
        _emote('chanHype', EmoteType.twitchChannel, subTier: 1),
        _emote('chanLove', EmoteType.twitchFollower),
        _emote('chanDance', EmoteType.twitchChannel, animated: true),
      ],
    });
    when(() => assets.sevenTVEmotes).thenReturn(const []);
    when(() => assets.bttvEmotes).thenReturn(const []);
    when(() => assets.ffzEmotes).thenReturn(const []);
    when(() => assets.removeRecentEmote(any())).thenAnswer((invocation) {
      recent.remove(invocation.positionalArguments.first);
    });
    when(
      () => chat.addEmote(
        any(),
        autocompleteMode: any(named: 'autocompleteMode'),
      ),
    ).thenReturn(null);
    when(() => chat.userState).thenReturn(const USERSTATE());
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Provider<SettingsStore>.value(
        value: settings,
        child: MaterialApp(
          theme: const OnsetThemes(colorSchemeSeed: OnsetTokens.accent).dark,
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(height: 320, child: EmoteMenu(chatStore: chat)),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> openTwitch(WidgetTester tester) async {
    await tester.tap(find.text('Twitch'));
    await tester.pumpAndSettle();
  }

  testWidgets('a locked sub emote explains how to unlock it', (tester) async {
    await pump(tester);
    await openTwitch(tester);
    final cell = find.byWidgetPredicate(
      (w) => w is EmoteCell && w.emote.name == 'chanHype',
    );
    expect(tester.widget<EmoteCell>(cell).locked, isTrue);
    await tester.tap(cell);
    await tester.pumpAndSettle();
    expect(
      find.text('Subscribe to this channel at Tier 1 to use it.'),
      findsOneWidget,
    );
    expect(find.text('Subscribe'), findsOneWidget);
    expect(find.text('Opens twitch.tv'), findsOneWidget);
    verifyNever(
      () => chat.addEmote(
        any(),
        autocompleteMode: any(named: 'autocompleteMode'),
      ),
    );
  });

  testWidgets('follower emotes come with a note on where they work', (
    tester,
  ) async {
    await pump(tester);
    await openTwitch(tester);
    expect(
      find.text('Follower emotes can only be used in Channel’s chat.'),
      findsOneWidget,
    );
  });

  testWidgets('an animated emote has its mark, and says so', (tester) async {
    final semantics = tester.ensureSemantics();
    final assets = chat.assetsStore;
    when(() => assets.userEmoteToObject).thenReturn({
      'chanDance': _emote('chanDance', EmoteType.twitchChannel, animated: true),
    });
    await pump(tester);
    await openTwitch(tester);
    expect(
      find.descendant(
        of: find.byWidgetPredicate(
          (w) => w is EmoteCell && w.emote.name == 'chanDance',
        ),
        matching: find.byType(AnimatedEmoteMark),
      ),
      findsOneWidget,
    );
    expect(find.byType(AnimatedEmoteMark), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('chanDance, animated emote')),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('one recent emote can be removed', (tester) async {
    await pump(tester);
    await tester.longPress(find.byType(EmoteCell).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove from recent emotes'));
    await tester.pumpAndSettle();
    final assets = chat.assetsStore;
    verify(() => assets.removeRecentEmote(any())).called(1);
    expect(recent, isEmpty);
    expect(find.text('No recent emotes'), findsOneWidget);
  });

  testWidgets('a limited-time emote says so in its details', (tester) async {
    recent
      ..clear()
      ..add(
        const Emote(
          name: 'seasonal',
          zeroWidth: false,
          url: 'https://cdn.example/seasonal.png',
          type: EmoteType.twitchUnlocked,
          limitedTime: true,
        ),
      );
    await pump(tester);
    await tester.longPress(find.byType(EmoteCell).first);
    await tester.pumpAndSettle();
    expect(find.text('Limited-time emote'), findsOneWidget);
  });
}
