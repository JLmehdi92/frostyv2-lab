import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_vod_service.dart';
import 'package:frosty/models/cheermote.dart';
import 'package:frosty/models/irc.dart';
import 'package:frosty/models/vod.dart';
import 'package:frosty/screens/channel/chat/stores/chat_assets_store.dart';
import 'package:frosty/screens/channel/video/content_warning_gate.dart';
import 'package:frosty/screens/channel/video/live_progress.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/screens/vod/stores/vod_chat_replay_store.dart';
import 'package:frosty/screens/vod/vod_player_controller.dart';
import 'package:frosty/screens/vod/vod_resume.dart';
import 'package:frosty/screens/vod/vod_screen.dart';
import 'package:frosty/stores/mini_player_store.dart';
import 'package:mobx/mobx.dart' show ObservableList;
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_vod_controller.dart';

class MockVodService extends Mock implements TwitchVodService {}

class MockMiniPlayerStore extends Mock implements MiniPlayerStore {}

class MockReplayStore extends Mock implements VodChatReplayStore {}

class MockChatAssetsStore extends Mock implements ChatAssetsStore {}

Vod _video(String id, String title, {bool recording = false}) => Vod(
  id: id,
  title: title,
  lengthSeconds: 3600,
  createdAt: DateTime.utc(2026, 10, 12),
  viewCount: 5,
  ownerId: '42',
  ownerLogin: 'streamer',
  ownerDisplayName: 'Streamer',
  isRecording: recording,
);

void main() {
  late SettingsStore settings;
  late MockVodService service;
  late MockMiniPlayerStore mini;
  late Map<String, FakeVodController> players;

  final first = _video('1000000001', 'Morning stream');
  final second = _video('1000000002', 'Evening stream');

  setUpAll(() => registerFallbackValue(WatchedVideoType.vod));

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    VodResumeRepository.shared.resetQueue();
    LiveProgressRepository.shared.resetQueue();
    AcceptedContentWarnings.reset();
    settings = SettingsStore.fromJson({})..keepScreenAwake = false;
    service = MockVodService();
    mini = MockMiniPlayerStore();
    players = {};
    when(() => service.getMutedSegments(any())).thenAnswer((_) async => []);
    when(() => service.getContentLabels(any())).thenAnswer((_) async => []);
    when(() => service.getViewingHistory(any())).thenAnswer((_) async => null);
    when(
      () => service.updateViewedVideo(
        videoId: any(named: 'videoId'),
        type: any(named: 'type'),
        positionSec: any(named: 'positionSec'),
      ),
    ).thenAnswer((_) async => true);
    when(
      () => service.getChannelVideos(login: 'streamer'),
    ).thenAnswer((_) async => VodPage(items: [second, first], hasMore: false));
    when(() => mini.close()).thenReturn(null);
    when(() => mini.visible).thenReturn(false);
  });

  MockReplayStore replayFor(Vod vod) {
    final replay = MockReplayStore();
    final assets = MockChatAssetsStore();
    when(() => assets.cheermotes).thenReturn(Cheermotes.empty);
    when(() => assets.emoteToObject).thenReturn({});
    when(() => replay.status).thenReturn(ReplayStatus.active);
    when(() => replay.messages).thenReturn(ObservableList<IRCMessage>());
    when(() => replay.autoScroll).thenReturn(true);
    when(() => replay.scrollController).thenReturn(ScrollController());
    when(() => replay.settings).thenReturn(settings);
    when(() => replay.assetsStore).thenReturn(assets);
    when(() => replay.vod).thenReturn(vod);
    return replay;
  }

  Future<void> pump(WidgetTester tester, Vod vod) {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<SettingsStore>.value(value: settings),
          Provider<TwitchVodService>.value(value: service),
          Provider<MiniPlayerStore>.value(value: mini),
        ],
        child: MaterialApp(
          home: VodScreen(
            vodId: vod.id,
            vod: vod,
            playerFactory: (vod, startAt) =>
                players[vod.id] = FakeVodController(),
            replayFactory: replayFor,
          ),
        ),
      ),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }

  testWidgets('at the end, Up Next counts down then plays the next video', (
    tester,
  ) async {
    await pump(tester, first);
    await settle(tester);

    players[first.id]!.status = VodPlaybackStatus.ended;
    await settle(tester);

    expect(find.textContaining('UP NEXT'), findsOneWidget);
    expect(find.textContaining('10 seconds'), findsOneWidget);
    expect(find.text('Evening stream'), findsWidgets);
    expect(find.text('Cancel'), findsOneWidget);

    await tester.pump(const Duration(seconds: 10));
    await settle(tester);
    await tester.pumpAndSettle();

    expect(players.keys, contains(second.id), reason: 'the next one plays');
    expect(find.byType(VodScreen), findsOneWidget, reason: 'replaced');
    await close(tester);
  });

  testWidgets('cancel keeps the ended video, a replay hides the card', (
    tester,
  ) async {
    await pump(tester, first);
    await settle(tester);
    final player = players[first.id]!;

    player.status = VodPlaybackStatus.ended;
    await settle(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pump();

    expect(find.textContaining('UP NEXT'), findsNothing);
    await tester.pump(const Duration(seconds: 15));
    expect(players.keys, isNot(contains(second.id)));

    player.status = VodPlaybackStatus.playing;
    await tester.pump();
    player.status = VodPlaybackStatus.ended;
    await settle(tester);
    expect(
      find.textContaining('UP NEXT'),
      findsOneWidget,
      reason: 'the next end offers it again',
    );
    await close(tester);
  });

  testWidgets('a screen over the VOD holds the countdown, never replaced', (
    tester,
  ) async {
    await pump(tester, first);
    await settle(tester);
    players[first.id]!.status = VodPlaybackStatus.ended;
    await settle(tester);
    expect(find.textContaining('10 seconds'), findsOneWidget);

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Category page')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 15));
    await settle(tester);

    expect(find.text('Category page'), findsOneWidget);
    expect(players.keys, isNot(contains(second.id)));

    navigator.pop();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 11));
    await settle(tester);
    await tester.pumpAndSettle();

    expect(players.keys, contains(second.id), reason: 'resumes once visible');
    expect(find.byType(VodScreen), findsOneWidget);
    await close(tester);
  });

  testWidgets('with autoplay off, the card waits for Play now', (tester) async {
    settings.vodAutoplay = VodAutoplay.never;
    await pump(tester, first);
    await settle(tester);

    players[first.id]!.status = VodPlaybackStatus.ended;
    await settle(tester);
    expect(find.textContaining('seconds'), findsNothing);
    await tester.pump(const Duration(seconds: 15));
    expect(players.keys, isNot(contains(second.id)));

    await tester.tap(find.byTooltip('Play now'));
    await settle(tester);
    await tester.pumpAndSettle();

    expect(players.keys, contains(second.id));
    await close(tester);
  });

  testWidgets('the next video keeps its own mature-content warning', (
    tester,
  ) async {
    when(
      () => service.getContentLabels(second.id),
    ).thenAnswer((_) async => ['MatureGame']);
    await pump(tester, first);
    await settle(tester);

    players[first.id]!.status = VodPlaybackStatus.ended;
    await settle(tester);
    await tester.tap(find.byTooltip('Play now'));
    await settle(tester);
    await tester.pumpAndSettle();

    expect(find.byType(ContentWarningCover), findsOneWidget);
    expect(
      players.keys,
      isNot(contains(second.id)),
      reason: 'nothing plays before the viewer accepts',
    );
    await close(tester);
  });

  testWidgets('a broadcast still recording has no Up Next', (tester) async {
    final live = _video('1000000003', 'Live now', recording: true);
    await pump(tester, live);
    await settle(tester);

    players[live.id]!.status = VodPlaybackStatus.ended;
    await settle(tester);

    expect(find.textContaining('UP NEXT'), findsNothing);
    verifyNever(() => service.getChannelVideos(login: 'streamer'));
    await close(tester);
  });
}
