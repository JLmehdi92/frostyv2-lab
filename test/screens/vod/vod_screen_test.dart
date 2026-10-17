import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_vod_service.dart';
import 'package:frosty/models/cheermote.dart';
import 'package:frosty/models/irc.dart';
import 'package:frosty/models/vod.dart';
import 'package:frosty/screens/channel/chat/stores/chat_assets_store.dart';
import 'package:frosty/screens/channel/video/content_warning_gate.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/screens/vod/stores/vod_chat_replay_store.dart';
import 'package:frosty/screens/vod/vod_overlay.dart';
import 'package:frosty/screens/vod/vod_player_controller.dart';
import 'package:frosty/screens/vod/vod_resume.dart';
import 'package:frosty/screens/vod/vod_screen.dart';
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

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    VodResumeRepository.shared.resetQueue();
    starts.clear();
    deepLink = null;
    settings = SettingsStore.fromJson({})..keepScreenAwake = false;
    service = MockVodService();
    mini = MockMiniPlayerStore();
    replay = MockReplayStore();
    player = FakeVodController();
    when(() => service.getMutedSegments(any())).thenAnswer((_) async => []);
    when(() => service.getContentLabels(any())).thenAnswer((_) async => []);
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

  Future<void> pump(WidgetTester tester, {Size size = const Size(400, 800)}) {
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
            vodId: _vod.id,
            vod: _vod,
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
}
