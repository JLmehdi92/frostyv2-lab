import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_clip_service.dart';
import 'package:frosty/models/clip.dart';
import 'package:frosty/screens/clips/clips_feed_screen.dart';
import 'package:frosty/screens/clips/stores/clips_feed_store.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/screens/vod/vod_player_controller.dart';
import 'package:frosty/services/playback_focus.dart';
import 'package:frosty/stores/mini_player_store.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '../../helpers/fake_vod_controller.dart';

class MockClipService extends Mock implements TwitchClipService {}

class MockMiniPlayerStore extends Mock implements MiniPlayerStore {}

Clip clip(String slug) => Clip(
  id: slug,
  slug: slug,
  title: 'Clip $slug',
  viewCount: 1234,
  createdAt: DateTime.utc(2026, 10, 2),
  durationSeconds: 30,
  broadcasterId: '42',
  broadcasterLogin: 'streamer',
  broadcasterDisplayName: 'Streamer',
  gameName: 'Just Chatting',
);

void main() {
  late MockClipService service;
  late MockMiniPlayerStore mini;
  late List<(String, bool)> built;
  late Map<String, FakeVodController> players;

  setUp(() {
    service = MockClipService();
    mini = MockMiniPlayerStore();
    built = [];
    players = {};
    when(() => mini.close()).thenReturn(null);
    when(() => mini.visible).thenReturn(false);
  });

  Future<void> pump(WidgetTester tester, {required ClipFeedPage first}) async {
    when(
      () => service.getTopClips(language: any(named: 'language')),
    ).thenAnswer((_) async => first);
    final settings = SettingsStore.fromJson({})..keepScreenAwake = false;
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<SettingsStore>.value(value: settings),
          Provider<MiniPlayerStore>.value(value: mini),
          Provider<TwitchClipService>.value(value: service),
        ],
        child: MaterialApp(
          home: ClipsFeedScreen(
            store: ClipsFeedStore(clipService: service),
            playerFactory: (clip, {required focused}) {
              built.add((clip.slug, focused));
              return players[clip.slug] = FakeVodController();
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }

  Future<void> swipeUp(WidgetTester tester) async {
    await tester.fling(find.byType(PageView), const Offset(0, -600), 2000);
    await tester.pumpAndSettle();
  }

  testWidgets('plays the first clip and preloads only the next one', (
    tester,
  ) async {
    await pump(
      tester,
      first: ClipFeedPage(items: [clip('a'), clip('b'), clip('c')]),
    );

    expect(built, [('a', true), ('b', false)]);
    expect(find.text('Clip a'), findsOneWidget);
    expect(find.text('Streamer'), findsWidgets);
    verify(() => mini.close()).called(1);
    expect(PlaybackFocus.shared.top, isNotNull);

    await close(tester);
    expect(players['a']!.calls, contains('dispose'));
    expect(players['b']!.calls, contains('dispose'));
    expect(PlaybackFocus.shared.top, isNull);
  });

  testWidgets('a swipe plays the next clip and lets the previous one go', (
    tester,
  ) async {
    await pump(
      tester,
      first: ClipFeedPage(items: [clip('a'), clip('b'), clip('c')]),
    );

    await swipeUp(tester);

    expect(
      players['a']!.calls,
      containsAllInOrder(['focused false', 'dispose']),
    );
    expect(players['b']!.calls, containsAllInOrder(['focused true', 'play']));
    expect(built.last, ('c', false), reason: 'the one after is preloaded');
    expect(
      players.values.where((p) => !p.calls.contains('dispose')),
      hasLength(2),
      reason: 'never more than two players',
    );
    await close(tester);
  });

  testWidgets('double-tap plays or pauses', (tester) async {
    await pump(tester, first: ClipFeedPage(items: [clip('a')]));

    await tester.tap(find.bySemanticsLabel(RegExp('Clip player')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.bySemanticsLabel(RegExp('Clip player')));
    await tester.pumpAndSettle();

    expect(players['a']!.calls, contains('togglePlay'));
    await close(tester);
  });

  testWidgets('the end of the feed says so', (tester) async {
    await pump(tester, first: ClipFeedPage(items: [clip('a')]));

    await swipeUp(tester);

    expect(
      find.text(
        'That’s all for now! Check out more clips from previous streams',
      ),
      findsOneWidget,
    );
    expect(players['a']!.calls, contains('pause'));
    await close(tester);
  });

  testWidgets('another player taking focus pauses the clip', (tester) async {
    await pump(tester, first: ClipFeedPage(items: [clip('a'), clip('b')]));
    final current = players['a']!..status = VodPlaybackStatus.playing;
    final other = Object();
    PlaybackFocus.shared.register(other, onLost: () {}, onRegained: () {});

    PlaybackFocus.shared.claim(other);
    expect(current.calls, containsAllInOrder(['focused false', 'pause']));

    current.status = VodPlaybackStatus.paused;
    PlaybackFocus.shared.release(other);
    await tester.pump();
    expect(current.calls, containsAllInOrder(['focused true', 'play']));
    await close(tester);
  });

  testWidgets('a failed load offers to try again', (tester) async {
    var calls = 0;
    when(
      () => service.getTopClips(language: any(named: 'language')),
    ).thenAnswer((_) async {
      if (calls++ == 0) throw const ClipApiException('boom');
      return ClipFeedPage(items: [clip('a')]);
    });
    final settings = SettingsStore.fromJson({})..keepScreenAwake = false;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<SettingsStore>.value(value: settings),
          Provider<MiniPlayerStore>.value(value: mini),
          Provider<TwitchClipService>.value(value: service),
        ],
        child: MaterialApp(
          home: ClipsFeedScreen(
            store: ClipsFeedStore(clipService: service),
            playerFactory: (clip, {required focused}) =>
                players[clip.slug] = FakeVodController(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Unable to load clips'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Clip a'), findsOneWidget);
    await close(tester);
  });

  testWidgets('the Clips button opens the feed', (tester) async {
    when(
      () => service.getTopClips(language: any(named: 'language')),
    ).thenAnswer((_) async => const ClipFeedPage(items: []));
    final settings = SettingsStore.fromJson({})..keepScreenAwake = false;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<SettingsStore>.value(value: settings),
          Provider<MiniPlayerStore>.value(value: mini),
          Provider<TwitchClipService>.value(value: service),
        ],
        child: const MaterialApp(home: Scaffold(body: ClipsFeedButton())),
      ),
    );

    await tester.tap(find.byTooltip('Clips'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(ClipsFeedScreen), findsOneWidget);
    expect(find.text('No clips right now'), findsOneWidget);
    await close(tester);
  });
}
