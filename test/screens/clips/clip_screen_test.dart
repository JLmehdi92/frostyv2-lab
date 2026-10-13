import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_clip_service.dart';
import 'package:frosty/apis/twitch_vod_service.dart';
import 'package:frosty/models/clip.dart';
import 'package:frosty/models/irc.dart';
import 'package:frosty/models/vod.dart';
import 'package:frosty/screens/channel/chat/stores/chat_assets_store.dart';
import 'package:frosty/screens/clips/clip_screen.dart';
import 'package:frosty/screens/clips/widgets/clip_card.dart';
import 'package:frosty/screens/clips/widgets/clip_info_panel.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/screens/vod/stores/vod_chat_replay_store.dart';
import 'package:frosty/screens/vod/vod_overlay.dart';
import 'package:frosty/screens/vod/vod_player_controller.dart';
import 'package:frosty/services/playback_focus.dart';
import 'package:frosty/stores/mini_player_store.dart';
import 'package:mobx/mobx.dart' show ObservableList;
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fixtures/clip_responses.dart';
import '../../helpers/fake_vod_controller.dart';

class MockClipService extends Mock implements TwitchClipService {}

/// The web fallback stand-in: a player that can loop.
class FakeLoopingController extends FakeVodController implements LoopingPlayer {
  @override
  var looping = false;

  @override
  void toggleLoop() => looping = !looping;
}

class MockMiniPlayerStore extends Mock implements MiniPlayerStore {}

class MockVodService extends Mock implements TwitchVodService {}

class MockReplayStore extends Mock implements VodChatReplayStore {}

class MockChatAssetsStore extends Mock implements ChatAssetsStore {}

void main() {
  setUpAll(() {
    registerFallbackValue(ClipPeriod.lastWeek);
    registerFallbackValue(ClipSort.top);
  });

  late SettingsStore settings;
  late MockClipService service;
  late MockMiniPlayerStore mini;
  late MockVodService vodService;
  late MockReplayStore replay;
  late List<int> replaySeconds;
  late FakeVodController player;
  late FakeLoopingController webPlayer;
  late List<bool> builds;
  final clip = Clip.fromGql(clipNode);
  final orphan = Clip.fromGql(clipNodeOrphan);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    settings = SettingsStore.fromJson({})..keepScreenAwake = false;
    service = MockClipService();
    mini = MockMiniPlayerStore();
    player = FakeVodController();
    webPlayer = FakeLoopingController();
    builds = [];
    when(() => mini.close()).thenReturn(null);
    when(() => mini.visible).thenReturn(false);
    when(
      () => service.getChannelClips(
        login: any(named: 'login'),
        period: any(named: 'period'),
        sort: any(named: 'sort'),
      ),
    ).thenAnswer((_) async => ClipPage(items: [clip, orphan], hasMore: false));
    vodService = MockVodService();
    when(() => vodService.getVideo(any())).thenAnswer((_) async => null);
    replay = MockReplayStore();
    replaySeconds = [];
    final assets = MockChatAssetsStore();
    when(() => assets.emoteToObject).thenReturn({});
    when(() => replay.status).thenReturn(ReplayStatus.active);
    when(() => replay.messages).thenReturn(ObservableList<IRCMessage>());
    when(() => replay.autoScroll).thenReturn(true);
    when(() => replay.scrollController).thenReturn(ScrollController());
    when(() => replay.settings).thenReturn(settings);
    when(() => replay.assetsStore).thenReturn(assets);
    when(() => replay.onPositionSecond(any())).thenAnswer((inv) {
      replaySeconds.add(inv.positionalArguments.single as int);
    });
  });

  Future<void> pump(
    WidgetTester tester, {
    Clip? known,
    String slug = 'SomeClipSlug',
    Size size = const Size(400, 800),
    double textScale = 1,
  }) {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<SettingsStore>.value(value: settings),
          Provider<TwitchClipService>.value(value: service),
          Provider<MiniPlayerStore>.value(value: mini),
          Provider<TwitchVodService>.value(value: vodService),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: ClipScreen(
            slug: slug,
            clip: known,
            playerFactory: (slug, clip, {required web}) {
              builds.add(web);
              return web ? webPlayer : player;
            },
            replayFactory: (vod) {
              when(() => replay.vod).thenReturn(vod);
              return replay;
            },
          ),
        ),
      ),
    );
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }

  testWidgets('holds playback focus while open and releases it after', (
    tester,
  ) async {
    await pump(tester, known: clip);
    expect(PlaybackFocus.shared.top, isNotNull);
    verify(() => mini.close()).called(1);

    await close(tester);
    expect(PlaybackFocus.shared.top, isNull);
    expect(player.calls, contains('dispose'));
  });

  testWidgets('shows the clip details and the jump to the VOD', (tester) async {
    await pump(tester, known: clip);

    expect(find.text('breakup advice'), findsWidgets);
    expect(find.text('Clipped by puertoricanporo'), findsOneWidget);
    expect(find.text('Watch full video'), findsOneWidget);
    expect(find.text('Copy link'), findsOneWidget);
    verifyNever(() => service.getClip(any()));
    await close(tester);
  });

  testWidgets('a clip whose VOD is gone has no jump', (tester) async {
    await pump(tester, known: orphan, slug: orphan.slug);
    expect(find.text('Watch full video'), findsNothing);
    await close(tester);
  });

  testWidgets('fetches unknown metadata; a gone clip says so', (tester) async {
    when(() => service.getClip(any())).thenAnswer((_) async => null);
    await pump(tester);
    await tester.pump();

    expect(find.text('This clip is no longer available'), findsOneWidget);
    await close(tester);
  });

  testWidgets('copy link copies the clips.twitch.tv link', (tester) async {
    final clipboard = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pump(tester, known: clip, slug: clip.slug);

    await tester.tap(find.text('Copy link'));
    await tester.pump();

    expect(clipboard, ['https://clips.twitch.tv/${clip.slug}']);
    expect(find.text('Link copied'), findsOneWidget);
    await close(tester);
  });

  testWidgets('a landscape tablet keeps the details beside the video', (
    tester,
  ) async {
    await pump(tester, known: clip, size: const Size(1600, 1067));

    final panel = tester.getRect(find.byType(ClipInfoPanel));
    expect(panel.left, greaterThan(1000));
    expect(tester.takeException(), isNull);

    settings.fullScreen = true;
    await tester.pump();
    expect(find.byType(ClipInfoPanel), findsNothing);
    await close(tester);
  });

  testWidgets('a landscape phone shows the video alone', (tester) async {
    await pump(tester, known: clip, size: const Size(740, 360));
    expect(find.byType(ClipInfoPanel), findsNothing);
    await close(tester);
  });

  testWidgets('a refused clip names itself', (tester) async {
    player
      ..problem = VodPlaybackProblem.geoBlocked
      ..status = VodPlaybackStatus.problem;
    await pump(tester, known: clip);
    expect(
      find.text('This clip is not available in your region'),
      findsOneWidget,
    );
    await close(tester);
  });

  testWidgets('a native failure switches to the Twitch embed, once', (
    tester,
  ) async {
    await pump(tester, known: clip);
    expect(builds, [false]);

    player.onFatalError!();
    await tester.pump();

    expect(builds, [false, true]);
    expect(player.calls, contains('dispose'));
    expect(webPlayer.onFatalError, isNull, reason: 'the embed is the end');
    await close(tester);
  });

  group('chat replay', () {
    final vod = Vod(
      id: '2897283075',
      title: 'Stream',
      lengthSeconds: 36000,
      createdAt: DateTime.utc(2026, 10, 10),
      viewCount: 1,
      ownerId: '71092938',
      ownerLogin: 'xqc',
      ownerDisplayName: 'xQc',
    );

    testWidgets('follows the clip inside its VOD', (tester) async {
      when(
        () => vodService.getVideo('2897283075'),
      ).thenAnswer((_) async => vod);
      player.position = const Duration(seconds: 5);
      await pump(tester, known: clip);
      await tester.pump();

      expect(find.text('Chat replay'), findsOneWidget);
      expect(replaySeconds.last, 1077 + 5);

      player.position = const Duration(seconds: 9);
      await tester.pump();
      expect(replaySeconds.last, 1077 + 9);

      await close(tester);
      verify(() => replay.dispose()).called(1);
    });

    testWidgets('no replay when the VOD is gone', (tester) async {
      await pump(tester, known: clip);
      await tester.pump();

      expect(find.text('Chat replay'), findsNothing);
      verify(() => vodService.getVideo('2897283075')).called(1);
      await close(tester);
    });

    testWidgets('a clip without VOD never asks', (tester) async {
      await pump(tester, known: orphan, slug: orphan.slug);
      await tester.pump();
      verifyNever(() => vodService.getVideo(any()));
      await close(tester);
    });
  });

  testWidgets("without chat replay, the channel's other clips follow", (
    tester,
  ) async {
    await pump(tester, known: orphan, slug: orphan.slug);
    await tester.pump();
    await tester.pump();

    expect(find.text('MORE CLIPS FROM XQC'), findsOneWidget);
    // The current clip is not offered again.
    expect(find.byType(ClipCard), findsOneWidget);
    expect(find.text('breakup advice'), findsOneWidget);
    await close(tester);
  });

  testWidgets('details that fail to load leave the clip playing', (
    tester,
  ) async {
    when(
      () => service.getClip(any()),
    ).thenThrow(const ClipApiException('Unreadable clip'));
    await pump(tester);
    await tester.pump();

    expect(find.text("Couldn't load the clip details"), findsOneWidget);
    expect(find.byType(VodOverlay), findsOneWidget);
    expect(player.calls, isNot(contains('pause')));

    when(() => service.getClip(any())).thenAnswer((_) async => clip);
    await tester.tap(find.byIcon(Icons.refresh_rounded));
    await tester.pump();
    await tester.pump();
    expect(find.text('Clipped by puertoricanporo'), findsOneWidget);
    await close(tester);
  });

  testWidgets('a deleted clip stops its player', (tester) async {
    when(() => service.getClip(any())).thenAnswer((_) async => null);
    await pump(tester);
    await tester.pump();

    expect(player.calls, contains('pause'));
    await close(tester);
  });

  testWidgets('a clip replaced from More clips leaves the system UI alone', (
    tester,
  ) async {
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call.method);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pump(tester, known: orphan, slug: orphan.slug);
    await tester.pump();
    await tester.pump();
    calls.clear();

    await tester.tap(find.text('breakup advice'));
    await tester.pumpAndSettle();

    expect(find.text('Clipped by puertoricanporo'), findsOneWidget);
    expect(calls, isNot(contains('SystemChrome.setPreferredOrientations')));
    expect(PlaybackFocus.shared.top, isNotNull);
    await close(tester);
    expect(PlaybackFocus.shared.top, isNull);
  });

  testWidgets('the web fallback keeps the remembered loop and its button', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'clip_loop': true});
    await pump(tester, known: clip);

    player.onFatalError!();
    await tester.pump();
    await tester.pump();

    expect(webPlayer.looping, isTrue);
    expect(find.byTooltip('Stop looping'), findsOneWidget);

    await tester.tap(find.byTooltip('Stop looping'));
    await tester.pump();
    expect(webPlayer.looping, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('clip_loop'), isFalse);
    await close(tester);
  });

  testWidgets('a small phone with large text and chat replay fits', (
    tester,
  ) async {
    when(() => vodService.getVideo(any())).thenAnswer(
      (_) async => Vod(
        id: '2897283075',
        title: 'Stream',
        lengthSeconds: 36000,
        createdAt: DateTime.utc(2026, 10, 10),
        viewCount: 1,
        ownerId: '71092938',
        ownerLogin: 'xqc',
        ownerDisplayName: 'xQc',
      ),
    );
    await pump(tester, known: clip, size: const Size(360, 640), textScale: 2);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Chat replay'), findsOneWidget);
    await close(tester);
  });

  testWidgets('"force vertical chat" never squeezes the clip in landscape', (
    tester,
  ) async {
    settings.landscapeForceVerticalChat = true;
    await pump(tester, known: clip, size: const Size(740, 360));

    expect(tester.takeException(), isNull);
    await close(tester);
  });
}
