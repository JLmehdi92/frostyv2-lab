import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/models/stream.dart';
import 'package:frosty/models/user.dart';
import 'package:frosty/screens/channel/channel_info.dart';
import 'package:frosty/screens/channel/stores/channel_info_store.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/theme.dart';
import 'package:mobx/mobx.dart' show Observable, runInAction;
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '../../helpers/fake_player.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

void main() {
  late MockTwitchApi api;
  late ChannelInfoStore info;

  setUp(() {
    api = MockTwitchApi();
    when(() => api.getUser(userLogin: any(named: 'userLogin'))).thenAnswer(
      (_) async => const UserTwitch('42', 'streamer', 'Streamer', ''),
    );
    info = ChannelInfoStore(channelId: '42', api: api, viewerId: () => null);
  });

  tearDown(() => info.dispose());

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    Size screen = const Size(390, 844),
    bool dark = true,
  }) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const themes = FrostyThemes(colorSchemeSeed: FrostyTokens.accent);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<TwitchApi>.value(value: api),
          Provider<SettingsStore>.value(value: SettingsStore.fromJson({})),
        ],
        child: MaterialApp(
          theme: themes.light,
          darkTheme: themes.dark,
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          home: Scaffold(body: child),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> done(WidgetTester tester) =>
      tester.pumpWidget(const SizedBox.shrink());

  test('shortUptime reads like the board', () {
    expect(shortUptime(const Duration(hours: 3, minutes: 12)), '3 h 12');
    expect(shortUptime(const Duration(hours: 1, minutes: 5)), '1 h 05');
    expect(shortUptime(const Duration(minutes: 45)), '45 min');
    expect(shortUptime(const Duration(minutes: -3)), '0 min');
  });

  group('ChannelInfoRow (board Chaine)', () {
    Widget row(
      FakePlayer player, {
      String? viewer = 'viewer',
      bool large = false,
      VoidCallback? onOpenProfile,
    }) => Column(
      children: [
        ChannelInfoRow(
          player: player,
          login: 'streamer',
          displayName: 'Streamer',
          info: info,
          viewerLogin: () => viewer,
          onOpenProfile: onOpenProfile ?? () {},
          large: large,
        ),
      ],
    );

    testWidgets('the channel, what it streams, and Follow', (tester) async {
      var opened = 0;
      for (final dark in [true, false]) {
        for (final width in [390.0, 320.0]) {
          await pump(
            tester,
            row(
              FakePlayer(stream: fakeStream()),
              onOpenProfile: () => opened++,
            ),
            screen: Size(width, 844),
            dark: dark,
          );
          expect(tester.takeException(), isNull);
          expect(find.text('Streamer'), findsOneWidget);
          expect(find.text('Dota 2'), findsOneWidget);
          expect(find.text(' · 2,445 watching · 3 h 12'), findsOneWidget);
          expect(find.text('Follow'), findsOneWidget);
        }
      }
      await tester.tap(find.text('Streamer'));
      expect(opened, 1);

      info.following.value = true;
      await tester.pump();
      expect(find.text('Following'), findsOneWidget);
      expect(find.text('Follow'), findsNothing);
      await done(tester);
    });

    testWidgets('no Follow signed out or on your own channel', (tester) async {
      await pump(tester, row(FakePlayer(stream: fakeStream()), viewer: null));
      expect(find.text('Follow'), findsNothing);
      await pump(
        tester,
        row(FakePlayer(stream: fakeStream()), viewer: 'Streamer'),
      );
      expect(find.text('Follow'), findsNothing);
      await done(tester);
    });

    testWidgets('Follow follows the account: known late, then signed out', (
      tester,
    ) async {
      final viewer = Observable<String?>(null);
      await pump(
        tester,
        Column(
          children: [
            ChannelInfoRow(
              player: FakePlayer(stream: fakeStream()),
              login: 'streamer',
              displayName: 'Streamer',
              info: info,
              viewerLogin: () => viewer.value,
              onOpenProfile: () {},
            ),
          ],
        ),
      );
      expect(find.text('Follow'), findsNothing);

      runInAction(() => viewer.value = 'viewer');
      await tester.pump();
      expect(find.text('Follow'), findsOneWidget);

      runInAction(() => viewer.value = null);
      await tester.pump();
      expect(find.text('Follow'), findsNothing);
      await done(tester);
    });

    testWidgets('steps aside while the keyboard is up on a phone', (
      tester,
    ) async {
      // A small phone, the keyboard taking 200 dp: the portrait column of
      // the channel screen (video, handle, this row, chat).
      tester.view.viewInsets = const FakeViewPadding(bottom: 200);
      addTearDown(tester.view.resetViewInsets);
      await pump(
        tester,
        Column(
          children: [
            const SizedBox(height: 220 + 14),
            ChannelInfoRow(
              player: FakePlayer(stream: fakeStream()),
              login: 'streamer',
              displayName: 'Streamer',
              info: info,
              viewerLogin: () => 'viewer',
              onOpenProfile: () {},
            ),
            const Expanded(child: SizedBox.expand(key: ValueKey('chat'))),
          ],
        ),
        screen: const Size(390, 600),
      );
      expect(find.text('Streamer'), findsNothing);
      // The input (68), a reply (41) and the autocomplete (51) fit.
      expect(
        tester.getSize(find.byKey(const ValueKey('chat'))).height,
        greaterThanOrEqualTo(68 + 41 + 51),
      );

      tester.view.resetViewInsets();
      await tester.pump();
      expect(find.text('Streamer'), findsOneWidget);
      await done(tester);
    });

    testWidgets('no Follow for a login twitch.tv would not take', (
      tester,
    ) async {
      for (final login in ['a/b', 'evil.com', 'a' * 26, '']) {
        await pump(
          tester,
          Column(
            children: [
              ChannelInfoRow(
                player: FakePlayer(stream: fakeStream()),
                login: login,
                displayName: 'Streamer',
                info: info,
                viewerLogin: () => 'viewer',
                onOpenProfile: () {},
              ),
            ],
          ),
        );
        expect(find.text('Follow'), findsNothing, reason: login);
      }
      await done(tester);
    });

    testWidgets('offline, it says so', (tester) async {
      await pump(tester, row(FakePlayer(offline: fakeOfflineChannel)));
      expect(tester.takeException(), isNull);
      expect(find.text(' · Offline'), findsOneWidget);
      await done(tester);
    });

    testWidgets('tablet portrait: title — category, Subscribe (board '
        'TablettePortrait)', (tester) async {
      await pump(
        tester,
        row(FakePlayer(stream: fakeStream()), large: true),
        screen: const Size(854, 1280),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('ON TEST DOTA 2 AVEC @befreesh'), findsOneWidget);
      // The category opens its streams here too.
      final link = tester.widget<GestureDetector>(
        find
            .ancestor(
              of: find.text('Dota 2'),
              matching: find.byType(GestureDetector),
            )
            .first,
      );
      expect(link.onTap, isNotNull);
      expect(find.text('Follow'), findsOneWidget);
      expect(find.text('Subscribe'), findsOneWidget);
      await done(tester);
    });
  });

  group('TabletChannelPanel (board Tablette)', () {
    testWidgets('title, chips, buttons and the other live follows', (
      tester,
    ) async {
      final opened = <String>[];
      final other = fakeStream(
        userId: '1',
        login: 'splinter',
        name: 'Splinter',
      );
      for (final dark in [true, false]) {
        await pump(
          tester,
          SizedBox(
            width: 880,
            height: 359,
            child: TabletChannelPanel(
              player: FakePlayer(stream: fakeStream()),
              login: 'streamer',
              displayName: 'Streamer',
              info: info,
              viewerLogin: () => 'viewer',
              onOpenChannel: (stream) => opened.add(stream.userLogin),
              watchStreak: () => 12,
            ),
          ),
          screen: const Size(1280, 854),
          dark: dark,
        );
        info.alsoLive.value = [other];
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.text('ON TEST DOTA 2 AVEC @befreesh'), findsOneWidget);
        expect(find.text('Dota 2'), findsOneWidget);
        expect(find.text('FR'), findsOneWidget);
        expect(find.text('Watch streak 12'), findsOneWidget);
        expect(find.text('Follow'), findsOneWidget);
        expect(find.text('Subscribe'), findsOneWidget);
        expect(find.text('ALSO LIVE FROM YOUR FOLLOWS'), findsOneWidget);
        info.alsoLive.value = const <StreamTwitch>[];
      }
      info.alsoLive.value = [other];
      await tester.pump();
      await tester.tap(find.text('Splinter'));
      expect(opened, ['splinter']);
      await done(tester);
    });
  });

  testWidgets('the tablet panel shows Follow once the account is known', (
    tester,
  ) async {
    final viewer = Observable<String?>(null);
    await pump(
      tester,
      SizedBox(
        width: 880,
        height: 359,
        child: TabletChannelPanel(
          player: FakePlayer(stream: fakeStream()),
          login: 'streamer',
          displayName: 'Streamer',
          info: info,
          viewerLogin: () => viewer.value,
          onOpenChannel: (_) {},
        ),
      ),
      screen: const Size(1280, 854),
    );
    expect(find.text('Follow'), findsNothing);
    runInAction(() => viewer.value = 'viewer');
    await tester.pump();
    expect(find.text('Follow'), findsOneWidget);
    await done(tester);
  });

  testWidgets('a narrow info area gets one card that fits', (tester) async {
    await pump(
      tester,
      Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          // The video column of a split-screen tablet window.
          width: 304,
          height: 400,
          child: TabletChannelPanel(
            player: FakePlayer(stream: fakeStream()),
            login: 'streamer',
            displayName: 'Streamer',
            info: info,
            viewerLogin: () => null,
            onOpenChannel: (_) {},
          ),
        ),
      ),
      screen: const Size(760, 1000),
    );
    info.alsoLive.value = [
      fakeStream(userId: '1', login: 'a', name: 'A'),
      fakeStream(userId: '2', login: 'b', name: 'B'),
    ];
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsNothing);
    await done(tester);
  });

  testWidgets('TabletChatHeader says whether chat waits for the video', (
    tester,
  ) async {
    final settings = SettingsStore.fromJson({})..autoSyncChatDelay = true;
    var more = 0;
    await pump(
      tester,
      Column(
        children: [TabletChatHeader(settings: settings, onMore: () => more++)],
      ),
      screen: const Size(1280, 854),
    );
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('synced to video'), findsOneWidget);

    settings
      ..autoSyncChatDelay = false
      ..chatDelay = 3;
    await tester.pump();
    expect(find.text('3s delay'), findsOneWidget);

    settings.chatDelay = 0;
    await tester.pump();
    expect(find.text('synced to video'), findsNothing);
    expect(find.text('0s delay'), findsNothing);

    await tester.tap(find.byTooltip('Chat settings'));
    expect(more, 1);
  });
}
