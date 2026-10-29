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
import 'package:frosty/screens/channel/video/web_content_gate.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/screens/vod/stores/vod_chat_replay_store.dart';
import 'package:frosty/screens/vod/vod_overlay.dart';
import 'package:frosty/screens/vod/vod_player_controller.dart';
import 'package:frosty/screens/vod/vod_resume.dart';
import 'package:frosty/screens/vod/vod_screen.dart';
import 'package:frosty/screens/vod/widgets/vod_chat_replay.dart';
import 'package:frosty/screens/vod/widgets/vod_details_panel.dart';
import 'package:frosty/screens/vod/widgets/vod_info_strip.dart';
import 'package:frosty/services/playback_focus.dart';
import 'package:frosty/stores/mini_player_store.dart';
import 'package:mobx/mobx.dart' show Observable, ObservableList, runInAction;
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_vod_controller.dart';

class MockVodService extends Mock implements TwitchVodService {}

/// A web player whose page can show Twitch's own warning.
class FakeWebPagePlayer extends FakeVodController implements WebPagePlayer {
  final _gate = Observable(false);

  set gate(bool value) => runInAction(() => _gate.value = value);

  @override
  bool get webGateVisible => _gate.value;
}

class MockMiniPlayerStore extends Mock implements MiniPlayerStore {}

class MockReplayStore extends Mock implements VodChatReplayStore {}

class MockChatAssetsStore extends Mock implements ChatAssetsStore {}

final _vod = Vod(
  id: '1000000001',
  title: 'Morning stream',
  lengthSeconds: 3600,
  createdAt: DateTime.utc(2026, 10, 12),
  viewCount: 5,
  ownerId: '42',
  ownerLogin: '',
  ownerDisplayName: 'Streamer',
);

void main() {
  late SettingsStore settings;
  late MockVodService service;
  late MockMiniPlayerStore mini;
  late MockReplayStore replay;
  late FakeVodController player;
  final starts = <Duration?>[];
  Duration? deepLink;

  setUpAll(() => registerFallbackValue(WatchedVideoType.vod));

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    VodResumeRepository.shared.resetQueue();
    LiveProgressRepository.shared.resetQueue();
    starts.clear();
    deepLink = null;
    settings = SettingsStore.fromJson({})..keepScreenAwake = false;
    service = MockVodService();
    mini = MockMiniPlayerStore();
    replay = MockReplayStore();
    player = FakeVodController();
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
    AcceptedContentWarnings.reset();
    when(() => mini.close()).thenReturn(null);
    when(() => mini.visible).thenReturn(false);
    final assets = MockChatAssetsStore();
    when(() => assets.cheermotes).thenReturn(Cheermotes.empty);
    when(() => assets.emoteToObject).thenReturn({});
    when(() => replay.status).thenReturn(ReplayStatus.active);
    when(() => replay.messages).thenReturn(ObservableList<IRCMessage>());
    when(() => replay.autoScroll).thenReturn(true);
    when(() => replay.scrollController).thenReturn(ScrollController());
    when(() => replay.settings).thenReturn(settings);
    when(() => replay.assetsStore).thenReturn(assets);
    when(() => replay.vod).thenReturn(_vod);
  });

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(400, 800),
    Vod? vod,
  }) {
    tester.view.physicalSize = size;
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
            vodId: (vod ?? _vod).id,
            vod: vod ?? _vod,
            startAt: deepLink,
            playerFactory: (vod, startAt) {
              starts.add(startAt);
              return player;
            },
            replayFactory: (vod) => replay,
          ),
        ),
      ),
    );
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }

  /// Lets the async metadata/resume lookup finish and the player appear.
  Future<void> ready(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }

  testWidgets('holds playback focus while open and releases it after', (
    tester,
  ) async {
    await pump(tester);
    await ready(tester);
    expect(PlaybackFocus.shared.top, isNotNull);
    verify(() => mini.close()).called(1);

    await close(tester);

    expect(PlaybackFocus.shared.top, isNull);
    expect(player.calls, contains('dispose'));
    verify(() => replay.dispose()).called(1);
  });

  testWidgets('another player taking focus pauses it; closing resumes it', (
    tester,
  ) async {
    player.status = VodPlaybackStatus.playing;
    await pump(tester);
    await ready(tester);
    final other = Object();
    PlaybackFocus.shared.register(other, onLost: () {}, onRegained: () {});

    PlaybackFocus.shared.claim(other);
    expect(player.calls, containsAllInOrder(['focused false', 'pause']));

    player.status = VodPlaybackStatus.paused;
    PlaybackFocus.shared.release(other);
    await tester.pump();
    expect(player.calls, containsAllInOrder(['focused true', 'play']));

    await close(tester);
  });

  testWidgets('a channel left in the mini player keeps the VOD paused', (
    tester,
  ) async {
    player.status = VodPlaybackStatus.playing;
    await pump(tester);
    await ready(tester);
    final other = Object();
    PlaybackFocus.shared
      ..register(other, onLost: () {}, onRegained: () {})
      ..claim(other);
    player.status = VodPlaybackStatus.paused;
    when(() => mini.visible).thenReturn(true);

    PlaybackFocus.shared.release(other);
    await tester.pump();

    expect(player.calls.where((c) => c == 'play'), isEmpty);
    await close(tester);
  });

  testWidgets('playing over the mini player closes it', (tester) async {
    player.status = VodPlaybackStatus.playing;
    await pump(tester);
    await ready(tester);
    final other = Object();
    PlaybackFocus.shared
      ..register(other, onLost: () {}, onRegained: () {})
      ..claim(other);
    player.status = VodPlaybackStatus.paused;
    when(() => mini.visible).thenReturn(true);
    PlaybackFocus.shared.release(other);
    await tester.pump();
    clearInteractions(mini);

    player.status = VodPlaybackStatus.playing;
    await tester.pump();

    verify(() => mini.close()).called(1);
    await close(tester);
  });

  testWidgets('the landscape chat overlay toggle applies at once', (
    tester,
  ) async {
    settings
      ..fullScreen = true
      ..fullScreenChatOverlay = false;
    await pump(tester, size: const Size(900, 400));
    await ready(tester);

    Visibility overlayChat() => tester.widget<Visibility>(
      find.byWidgetPredicate((w) => w is Visibility && w.maintainState),
    );
    expect(overlayChat().visible, isFalse);

    settings.fullScreenChatOverlay = true;
    await tester.pump();

    expect(overlayChat().visible, isTrue);
    await close(tester);
  });

  testWidgets('feeds the chat replay the playback second and rate', (
    tester,
  ) async {
    await pump(tester);
    await ready(tester);

    verify(() => replay.onPositionSecond(600)).called(1);
    verify(() => replay.playbackRate = 1.0).called(1);
    await close(tester);
  });

  testWidgets('resumes 30 s before where the viewer left', (tester) async {
    await tester.runAsync(
      () => VodResumeRepository.shared.save(
        _vod.id,
        positionSec: 600,
        lengthSec: 3600,
      ),
    );
    await pump(tester);
    await ready(tester);

    expect(starts, [const Duration(seconds: 570)]);
    await close(tester);
  });

  group('with the viewer\'s account and the live', () {
    final archive = Vod(
      id: '2905241941',
      title: 'Past broadcast',
      lengthSeconds: 36000,
      createdAt: DateTime.utc(2026, 10, 19, 18, 0, 7),
      viewCount: 5,
      ownerId: '42',
      ownerLogin: 'streamer',
      ownerDisplayName: 'Streamer',
      type: VodType.archive,
      broadcastId: '318071962212',
    );

    testWidgets('starts where the account left the video', (tester) async {
      when(() => service.getViewingHistory(archive.id)).thenAnswer(
        (_) => Future<ViewingHistory?>.value(
          const ViewingHistory(positionSec: 5400),
        ),
      );

      await pump(tester, vod: archive);
      await ready(tester);

      expect(starts, [const Duration(seconds: 5400)]);
      await close(tester);
    });

    testWidgets('starts where this device saw the live left', (tester) async {
      when(() => service.viewerId).thenReturn(() => '1234');
      await tester.runAsync(
        () => LiveProgressRepository.shared.save(
          viewer: '1234',
          streamId: '318071962212',
          channelId: '42',
          startedAt: DateTime.utc(2026, 10, 19, 18),
          offsetSec: 7200,
        ),
      );

      await pump(tester, vod: archive);
      await ready(tester);

      expect(starts, [const Duration(seconds: 7170)]);
      await close(tester);
    });

    testWidgets('another account\'s live position is not used', (tester) async {
      when(() => service.viewerId).thenReturn(() => '9999');
      await tester.runAsync(
        () => LiveProgressRepository.shared.save(
          viewer: '1234',
          streamId: '318071962212',
          channelId: '42',
          startedAt: DateTime.utc(2026, 10, 19, 18),
          offsetSec: 7200,
        ),
      );

      await pump(tester, vod: archive);
      await ready(tester);

      expect(starts, [Duration.zero]);
      await close(tester);
    });

    testWidgets('a link time does not ask the account', (tester) async {
      deepLink = const Duration(minutes: 2);

      await pump(tester, vod: archive);
      await ready(tester);

      expect(starts, [const Duration(minutes: 2)]);
      verifyNever(() => service.getViewingHistory(any()));
      await close(tester);
    });

    testWidgets('an account that never answers does not hold the video', (
      tester,
    ) async {
      final never = Completer<ViewingHistory?>();
      when(
        () => service.getViewingHistory(any()),
      ).thenAnswer((_) => never.future);

      await pump(tester, vod: archive);
      await tester.pump(const Duration(seconds: 4));
      await ready(tester);

      expect(starts, [Duration.zero]);
      await close(tester);
    });

    testWidgets('a VOD still recording is saved at its moving end as is', (
      tester,
    ) async {
      final recording = Vod(
        id: archive.id,
        title: archive.title,
        lengthSeconds: 3600,
        createdAt: archive.createdAt,
        viewCount: 5,
        ownerId: '42',
        ownerLogin: 'streamer',
        ownerDisplayName: 'Streamer',
        type: VodType.archive,
        broadcastId: archive.broadcastId,
        isRecording: true,
      );
      await pump(tester, vod: recording);
      await ready(tester);
      player.status = VodPlaybackStatus.playing;
      await tester.pump();
      player
        ..position = const Duration(seconds: 3590)
        ..status = VodPlaybackStatus.paused;
      await tester.pump();
      await ready(tester);

      final saved = await tester.runAsync(
        () => VodResumeRepository.shared.entry(archive.id),
      );
      expect(saved?.finished, isFalse);
      expect(saved?.positionSec, 3590);
      await close(tester);
    });

    testWidgets('the position is written to the account as a VOD', (
      tester,
    ) async {
      when(() => service.viewerId).thenReturn(() => '1234');
      await pump(tester, vod: archive);
      await ready(tester);
      player.status = VodPlaybackStatus.playing;
      await tester.pump();
      player
        ..position = const Duration(minutes: 7)
        ..status = VodPlaybackStatus.paused;
      await tester.pump();
      await ready(tester);

      verify(
        () => service.updateViewedVideo(
          videoId: archive.id,
          type: WatchedVideoType.vod,
          positionSec: 420,
        ),
      ).called(1);
      final saved = await tester.runAsync(
        () => VodResumeRepository.shared.entry(archive.id, viewer: '1234'),
      );
      expect(saved?.positionSec, 420);
      await close(tester);
    });
  });

  testWidgets('a link time wins over the saved position', (tester) async {
    await tester.runAsync(
      () => VodResumeRepository.shared.save(
        _vod.id,
        positionSec: 600,
        lengthSec: 3600,
      ),
    );
    deepLink = const Duration(minutes: 2);
    await pump(tester);
    await ready(tester);

    expect(starts, [const Duration(minutes: 2)]);
    await close(tester);
  });

  group('mature-content warning', () {
    testWidgets('a labelled video waits for the viewer, then plays', (
      tester,
    ) async {
      when(
        () => service.getContentLabels(_vod.id),
      ).thenAnswer((_) async => ['MatureGame']);
      await pump(tester);
      await ready(tester);

      expect(find.text('Just one second…'), findsOneWidget);
      expect(find.text('It may contain: Mature-Rated Game'), findsOneWidget);
      expect(
        find.text("Streamer's content is intended for certain audiences."),
        findsOneWidget,
      );
      expect(starts, isEmpty, reason: 'no player, so nothing plays behind');

      await tester.tap(find.text('Start watching'));
      await tester.pump();

      expect(find.text('Just one second…'), findsNothing);
      expect(starts, [Duration.zero], reason: 'from where it would start');
      expect(AcceptedContentWarnings.has('42'), isTrue);
      verify(() => replay.onPositionSecond(600)).called(1);
      await close(tester);
    });

    testWidgets('the position of a video watched past the warning is saved', (
      tester,
    ) async {
      when(
        () => service.getContentLabels(_vod.id),
      ).thenAnswer((_) async => ['MatureGame']);
      await pump(tester);
      await ready(tester);
      await tester.tap(find.text('Start watching'));
      await tester.pump();

      player.status = VodPlaybackStatus.playing;
      await tester.pump();
      player.status = VodPlaybackStatus.paused;
      await tester.pump();
      await ready(tester);

      final saved = await tester.runAsync(
        () => VodResumeRepository.shared.entry(_vod.id),
      );
      expect(saved?.positionSec, 600);
      await close(tester);
    });

    testWidgets('accepted for this channel already: never asks again', (
      tester,
    ) async {
      AcceptedContentWarnings.add('42');
      await pump(tester);
      await ready(tester);

      expect(find.text('Just one second…'), findsNothing);
      expect(starts, hasLength(1));
      verifyNever(() => service.getContentLabels(any()));
      await close(tester);
    });

    testWidgets('with the setting off it never asks', (tester) async {
      settings.warnMatureContent = false;
      when(
        () => service.getContentLabels(any()),
      ).thenAnswer((_) async => ['MatureGame']);
      await pump(tester);
      await ready(tester);

      expect(find.text('Just one second…'), findsNothing);
      expect(starts, hasLength(1));
      verifyNever(() => service.getContentLabels(any()));
      await close(tester);
    });

    testWidgets('no labels, or labels that cannot be read: it plays', (
      tester,
    ) async {
      when(
        () => service.getContentLabels(any()),
      ).thenThrow(const VodApiException('offline'));
      await pump(tester);
      await ready(tester);

      expect(find.text('Just one second…'), findsNothing);
      expect(starts, hasLength(1));
      await close(tester);
    });

    testWidgets('labels that never come do not hold the video', (tester) async {
      when(
        () => service.getContentLabels(any()),
      ).thenAnswer((_) => Completer<List<String>>().future);
      await pump(tester);
      await ready(tester);
      expect(starts, isEmpty);

      await tester.pump(const Duration(seconds: 5));
      await ready(tester);

      expect(find.text('Just one second…'), findsNothing);
      expect(starts, hasLength(1));
      await close(tester);
    });
  });

  testWidgets("twitch's own warning in the web player gets the taps", (
    tester,
  ) async {
    final web = FakeWebPagePlayer();
    player = web;
    await pump(tester);
    await ready(tester);
    expect(find.byTooltip('Play'), findsOneWidget, reason: 'our controls');

    web.gate = true;
    await tester.pump();

    expect(find.byTooltip('Play'), findsNothing);
    expect(find.byTooltip('Back'), findsOneWidget, reason: 'still a way out');
    // Nothing of ours lies over the page, but for the back button.
    expect(find.byType(VodOverlay), findsNothing);

    web.gate = false;
    await tester.pump();
    expect(find.byTooltip('Play'), findsOneWidget);
    await close(tester);
  });

  testWidgets('a replaced player (fallback, retry) still saves the position', (
    tester,
  ) async {
    final first = FakeVodController()
      ..problem = VodPlaybackProblem.subscriberOnly
      ..status = VodPlaybackStatus.problem;
    final second = FakeVodController();
    final players = [first, second];
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<SettingsStore>.value(value: settings),
          Provider<TwitchVodService>.value(value: service),
          Provider<MiniPlayerStore>.value(value: mini),
        ],
        child: MaterialApp(
          home: VodScreen(
            vodId: _vod.id,
            vod: _vod,
            playerFactory: (vod, startAt) => players.removeAt(0),
            replayFactory: (vod) => replay,
          ),
        ),
      ),
    );
    await ready(tester);

    // The first player is refused before playing; Retry builds another.
    await tester.tap(find.byIcon(Icons.refresh_rounded));
    await ready(tester);
    await tester.pump();
    expect(players, isEmpty, reason: 'the second player was built');

    second.status = VodPlaybackStatus.playing;
    await tester.pump();
    second
      ..position = const Duration(minutes: 7)
      ..status = VodPlaybackStatus.paused;
    await tester.pump();
    await ready(tester);

    final saved = await tester.runAsync(
      () => VodResumeRepository.shared.entry(_vod.id),
    );
    expect(saved?.positionSec, 420);
    await close(tester);
  });

  group('layouts (boards Rediff, RediffTablette)', () {
    testWidgets('a phone: the title strip, then the synced replay', (
      tester,
    ) async {
      await pump(tester, size: const Size(390, 844));
      await ready(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(VodInfoStrip), findsOneWidget);
      expect(find.byType(VodDetailsPanel), findsNothing);
      expect(find.text('Chat replay'), findsOneWidget);
      expect(find.text('synced to video'), findsOneWidget);
      await close(tester);
    });

    testWidgets('a tablet in landscape: details under the video, chat beside', (
      tester,
    ) async {
      await pump(tester, size: const Size(1280, 854));
      await ready(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(VodDetailsPanel), findsOneWidget);
      expect(find.text('Copy link at current time'), findsOneWidget);
      expect(find.text('Speed Normal'), findsOneWidget);
      expect(find.text('Quality Auto'), findsOneWidget);
      expect(find.text('Double-tap the sides to skip 10 s'), findsOneWidget);
      expect(find.text('Chat replay'), findsOneWidget);
      // The video keeps 16:9 at the top of its column.
      final details = tester.getRect(find.byType(VodDetailsPanel));
      final chat = tester.getRect(find.byType(VodChatReplay));
      expect(details.right, lessThanOrEqualTo(chat.left + 0.5));
      expect(details.top, closeTo(details.width * 9 / 16, 1));
      await close(tester);
    });

    testWidgets('the speed pill follows the player and opens its settings', (
      tester,
    ) async {
      await pump(tester, size: const Size(1280, 854));
      await ready(tester);

      player.setPlaybackRate(1.5);
      await tester.pump();
      expect(find.text('Speed 1.5×'), findsOneWidget);

      await tester.tap(find.text('Speed 1.5×'));
      await tester.pumpAndSettle();
      expect(find.byType(VodSettingsSheet), findsOneWidget);
      await close(tester);
    });

    testWidgets('a tablet in portrait: details between video and chat', (
      tester,
    ) async {
      await pump(tester, size: const Size(854, 1280));
      await ready(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(VodDetailsPanel), findsOneWidget);
      // Under a portrait video, no legend: the chat replay needs the room.
      expect(find.text('Double-tap the sides to skip 10 s'), findsNothing);
      final details = tester.getRect(find.byType(VodDetailsPanel));
      final chat = tester.getRect(find.byType(VodChatReplay));
      expect(chat.top, greaterThanOrEqualTo(details.bottom - 0.5));
      await close(tester);
    });

    testWidgets('an upload (no chat) on a tablet keeps its details', (
      tester,
    ) async {
      when(() => replay.status).thenReturn(ReplayStatus.notApplicable);
      await pump(tester, size: const Size(1280, 854));
      await ready(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(VodDetailsPanel), findsOneWidget);
      expect(find.byType(VodChatReplay), findsNothing);
      await close(tester);
    });

    testWidgets('large text in tablet portrait leaves the chat its room', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pump(tester, size: const Size(854, 1280));
      await ready(tester);

      expect(tester.takeException(), isNull);
      final chat = tester.getRect(find.byType(VodChatReplay));
      expect(chat.height, greaterThan(300));
      await close(tester);
    });

    testWidgets('the tablet keeps the full screen modes', (tester) async {
      settings.fullScreen = true;
      await pump(tester, size: const Size(1280, 854));
      await ready(tester);

      expect(find.byType(VodDetailsPanel), findsNothing);
      await close(tester);
    });

    testWidgets('light theme lays out too', (tester) async {
      tester.view.physicalSize = const Size(1280, 854);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<SettingsStore>.value(value: settings),
            Provider<TwitchVodService>.value(value: service),
            Provider<MiniPlayerStore>.value(value: mini),
          ],
          child: MaterialApp(
            theme: ThemeData.light(),
            home: VodScreen(
              vodId: _vod.id,
              vod: _vod,
              playerFactory: (vod, startAt) => player,
              replayFactory: (vod) => replay,
            ),
          ),
        ),
      );
      await ready(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(VodDetailsPanel), findsOneWidget);
      await close(tester);
    });
  });
}
