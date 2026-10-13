import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_vod_service.dart';
import 'package:frosty/models/irc.dart';
import 'package:frosty/models/vod.dart';
import 'package:frosty/screens/channel/chat/stores/chat_assets_store.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/screens/vod/stores/vod_chat_replay_store.dart';
import 'package:frosty/screens/vod/vod_player_controller.dart';
import 'package:frosty/screens/vod/vod_screen.dart';
import 'package:frosty/services/playback_focus.dart';
import 'package:frosty/stores/mini_player_store.dart';
import 'package:mobx/mobx.dart' show ObservableList;
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '../../helpers/fake_vod_controller.dart';

class MockVodService extends Mock implements TwitchVodService {}

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

  setUp(() {
    settings = SettingsStore.fromJson({})..keepScreenAwake = false;
    service = MockVodService();
    mini = MockMiniPlayerStore();
    replay = MockReplayStore();
    player = FakeVodController();
    when(() => service.getMutedSegments(any())).thenAnswer((_) async => []);
    when(() => mini.close()).thenReturn(null);
    when(() => mini.visible).thenReturn(false);
    final assets = MockChatAssetsStore();
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
            playerFactory: (vod, startAt) => player,
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

  testWidgets('holds playback focus while open and releases it after', (
    tester,
  ) async {
    await pump(tester);
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

  testWidgets('the landscape chat overlay toggle applies at once', (
    tester,
  ) async {
    settings
      ..fullScreen = true
      ..fullScreenChatOverlay = false;
    await pump(tester, size: const Size(900, 400));

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

    verify(() => replay.onPositionSecond(600)).called(1);
    verify(() => replay.playbackRate = 1.0).called(1);
    await close(tester);
  });
}
