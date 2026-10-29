import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_clip_service.dart';
import 'package:onset/models/clip.dart';
import 'package:onset/screens/clips/clips_feed_screen.dart';
import 'package:onset/screens/clips/stores/clips_feed_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/vod/vod_player_controller.dart';
import 'package:onset/services/playback_focus.dart';
import 'package:onset/stores/mini_player_store.dart';
import 'package:onset/widgets/onset_cached_network_image.dart';
import 'package:onset/widgets/skeleton_loader.dart';
import 'package:provider/provider.dart';

import '../../helpers/fake_vod_controller.dart';

class MockClipService extends Mock implements TwitchClipService {}

class MockMiniPlayerStore extends Mock implements MiniPlayerStore {}

/// A player that draws its own video, marked with its clip's slug.
class FakeSurfaceController extends FakeVodController
    implements VideoSurfacePlayer {
  FakeSurfaceController(this.slug);

  final String slug;

  bool get disposed => calls.contains('dispose');

  @override
  Widget buildVideo({required bool fill}) =>
      SizedBox.expand(key: ValueKey('video-$slug'));
}

Clip clip(String slug, {String? thumbnail}) => Clip(
  id: slug,
  slug: slug,
  thumbnailUrl: thumbnail,
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
  late int autoPipOff;

  setUp(() {
    service = MockClipService();
    mini = MockMiniPlayerStore();
    built = [];
    players = {};
    autoPipOff = 0;
    when(() => mini.close()).thenReturn(null);
    when(() => mini.visible).thenReturn(false);
  });

  Future<void> pump(
    WidgetTester tester, {
    required ClipFeedPage first,
    ValueListenable<bool>? active,
    ClipsFeedStore? store,
  }) async {
    when(
      () => service.getTopClips(language: any(named: 'language')),
    ).thenAnswer((_) async => first);
    final settings = SettingsStore.fromJson({})..keepScreenAwake = false;
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final feedStore = store ?? ClipsFeedStore(clipService: service);
    Widget feed(bool isActive) => ClipsFeedScreen(
      store: feedStore,
      active: isActive,
      disableAutoPip: () => autoPipOff++,
      playerFactory: (clip, {required focused}) {
        built.add((clip.slug, focused));
        return players[clip.slug] = FakeVodController();
      },
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<SettingsStore>.value(value: settings),
          Provider<MiniPlayerStore>.value(value: mini),
          Provider<TwitchClipService>.value(value: service),
        ],
        child: MaterialApp(
          home: active == null
              ? feed(true)
              : ValueListenableBuilder<bool>(
                  valueListenable: active,
                  builder: (context, isActive, _) => feed(isActive),
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

  testWidgets('more clips arriving never restart a paused clip', (
    tester,
  ) async {
    final more = Completer<ClipFeedPage>();
    when(
      () => service.getTopClips(
        cursor: 'Mg==',
        language: any(named: 'language'),
      ),
    ).thenAnswer((_) => more.future);
    await pump(
      tester,
      first: ClipFeedPage(items: [clip('a'), clip('b')], cursor: 'Mg=='),
    );

    await swipeUp(tester);
    final current = players['b']!;
    final plays = current.calls.where((c) => c == 'play').length;
    more.complete(ClipFeedPage(items: [clip('c'), clip('d')]));
    await tester.pump();
    await tester.pump();

    expect(find.text('Clip b'), findsOneWidget);
    expect(
      current.calls.where((c) => c == 'play'),
      hasLength(plays),
      reason: 'the viewer may have paused it',
    );
    await close(tester);
  });

  testWidgets('a clip that cannot play says so, without a crash', (
    tester,
  ) async {
    when(
      () => service.getTopClips(language: any(named: 'language')),
    ).thenAnswer((_) async => ClipFeedPage(items: [clip('a')]));
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
                players[clip.slug] = FakeVodController()
                  ..status = VodPlaybackStatus.failed
                  ..ready = Future.error(StateError('no playlist')),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text("This clip can't be played here"), findsOneWidget);
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

  testWidgets('no clip left playing: auto-PiP is turned off', (tester) async {
    await pump(tester, first: ClipFeedPage(items: [clip('a')]));
    expect(autoPipOff, 0);

    await swipeUp(tester);
    expect(autoPipOff, greaterThan(0), reason: 'the end page plays nothing');

    final before = autoPipOff;
    await close(tester);
    expect(autoPipOff, greaterThan(before), reason: 'closing the feed');
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

    // The default 800 × 600 window is a tablet: the stage and the queue.
    expect(find.text('Clip a'), findsWidgets);
    await close(tester);
  });

  group('only while the feed is the page in front', () {
    testWidgets('covered, the clip pauses and auto-PiP goes off; uncovered, '
        'it plays again', (tester) async {
      final active = ValueNotifier(true);
      addTearDown(active.dispose);
      await pump(
        tester,
        first: ClipFeedPage(items: [clip('a'), clip('b')]),
        active: active,
      );
      final current = players['a']!..status = VodPlaybackStatus.playing;
      current.calls.clear();
      final pipOffBefore = autoPipOff;

      active.value = false;
      await tester.pump();
      expect(current.calls, containsAllInOrder(['focused false', 'pause']));
      expect(autoPipOff, greaterThan(pipOffBefore));
      current.status = VodPlaybackStatus.paused;

      current.calls.clear();
      active.value = true;
      await tester.pump();
      await tester.pump();
      expect(current.calls, containsAllInOrder(['focused true', 'play']));
      await close(tester);
    });

    testWidgets('a clip the viewer paused stays paused when uncovered', (
      tester,
    ) async {
      final active = ValueNotifier(true);
      addTearDown(active.dispose);
      await pump(
        tester,
        first: ClipFeedPage(items: [clip('a')]),
        active: active,
      );
      final current = players['a']!..status = VodPlaybackStatus.paused;
      active.value = false;
      await tester.pump();
      current.calls.clear();
      active.value = true;
      await tester.pump();
      await tester.pump();
      expect(current.calls, isNot(contains('play')));
      await close(tester);
    });

    testWidgets('focus coming back while covered leaves the clip paused', (
      tester,
    ) async {
      final active = ValueNotifier(true);
      addTearDown(active.dispose);
      await pump(
        tester,
        first: ClipFeedPage(items: [clip('a'), clip('b')]),
        active: active,
      );
      final current = players['a']!..status = VodPlaybackStatus.playing;
      // A page over Home (search), then a channel opened from it.
      active.value = false;
      await tester.pump();
      current.status = VodPlaybackStatus.paused;
      final channel = Object();
      PlaybackFocus.shared
        ..register(channel, onLost: () {}, onRegained: () {})
        ..claim(channel);
      current.calls.clear();

      // The channel closes; the search is still over Home.
      PlaybackFocus.shared.release(channel);
      await tester.pump();
      await tester.pump();
      expect(current.calls, isNot(contains('play')));
      expect(current.calls, isNot(contains('focused true')));

      // The search closes too: the clip plays on.
      active.value = true;
      await tester.pump();
      await tester.pump();
      expect(current.calls, containsAllInOrder(['focused true', 'play']));
      await close(tester);
    });

    testWidgets('made while not in front (the launch intro), nothing plays '
        'until it is', (tester) async {
      final active = ValueNotifier(false);
      addTearDown(active.dispose);
      await pump(
        tester,
        first: ClipFeedPage(items: [clip('a'), clip('b')]),
        active: active,
      );
      expect(built, [('a', false), ('b', false)]);
      expect(players['a']!.calls, isNot(contains('play')));

      active.value = true;
      await tester.pump();
      await tester.pump();
      expect(players['a']!.calls, containsAllInOrder(['focused true', 'play']));
      expect(players['b']!.calls, isNot(contains('play')));
      await close(tester);
    });

    testWidgets('watched a quarter of an hour, left for two seconds: the '
        'same clip; left ten minutes: fresh clips', (tester) async {
      var now = DateTime.utc(2026, 10, 29, 12);
      final store = ClipsFeedStore(clipService: service, now: () => now);
      await pump(
        tester,
        first: ClipFeedPage(items: [clip('a'), clip('b'), clip('c')]),
        store: store,
      );
      await swipeUp(tester);
      now = now.add(const Duration(minutes: 15));
      await close(tester);
      now = now.add(const Duration(seconds: 2));
      built.clear();

      await pump(
        tester,
        first: ClipFeedPage(items: [clip('x'), clip('y')]),
        store: store,
      );
      expect(find.text('Clip b'), findsOneWidget);
      expect(built, [('b', true), ('c', false)]);
      await close(tester);
      built.clear();

      now = now.add(ClipsFeedStoreBase.staleAfter);
      await pump(
        tester,
        first: ClipFeedPage(items: [clip('x'), clip('y')]),
        store: store,
      );
      expect(find.text('Clip x'), findsOneWidget);
      expect(built, [('x', true), ('y', false)]);
      expect(store.position, 0);
      await close(tester);
    });

    testWidgets('the end after a page that failed offers to try again', (
      tester,
    ) async {
      var fail = true;
      when(
        () => service.getTopClips(
          cursor: 'Mg==',
          language: any(named: 'language'),
        ),
      ).thenAnswer((_) async {
        if (fail) throw const ClipApiException('down');
        return ClipFeedPage(items: [clip('b')]);
      });
      await pump(
        tester,
        first: ClipFeedPage(items: [clip('a')], cursor: 'Mg=='),
      );
      await swipeUp(tester);
      await tester.pumpAndSettle();
      expect(find.text('Try again'), findsOneWidget);

      fail = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Clip b'), findsWidgets);
      await close(tester);
    });

    testWidgets('a feed made again on a kept list opens at the same clip, '
        'without loading it again', (tester) async {
      final store = ClipsFeedStore(clipService: service);
      await pump(
        tester,
        first: ClipFeedPage(items: [clip('a'), clip('b'), clip('c')]),
        store: store,
      );
      await swipeUp(tester);
      await close(tester);
      expect(players['b']!.calls, contains('dispose'));
      built.clear();

      await pump(
        tester,
        first: ClipFeedPage(items: [clip('x')]),
        store: store,
      );
      verify(
        () => service.getTopClips(language: any(named: 'language')),
      ).called(1);
      expect(find.text('Clip b'), findsOneWidget);
      expect(built, [('b', true), ('c', false)]);
      await close(tester);
    });
  });

  group('board Clips', () {
    testWidgets('the next clip waits under the details; a tap goes there', (
      tester,
    ) async {
      await pump(tester, first: ClipFeedPage(items: [clip('a'), clip('b')]));
      tester.view.physicalSize = const Size(390, 844);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('NEXT'), findsOneWidget);
      expect(find.text('Streamer · Clip b'), findsOneWidget);
      expect(find.text('You can swipe to the next clip'), findsOneWidget);
      expect(find.text('Open clip'), findsOneWidget);

      await tester.tap(find.text('Streamer · Clip b'));
      await tester.pumpAndSettle();
      expect(players['b']!.calls, containsAllInOrder(['focused true', 'play']));
      await close(tester);
    });

    testWidgets('a phone held sideways fits the clip and its details', (
      tester,
    ) async {
      await pump(tester, first: ClipFeedPage(items: [clip('a'), clip('b')]));
      tester.view.physicalSize = const Size(844, 390);
      await tester.pump();

      expect(tester.takeException(), isNull);
      final box = tester.getRect(find.bySemanticsLabel(RegExp('Clip player')));
      expect(box.bottom, lessThanOrEqualTo(390));
      final open = tester.getRect(find.text('Open clip'));
      expect(open.bottom, lessThanOrEqualTo(390));
      await close(tester);
    });

    testWidgets('the hint stands still under reduce motion', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await pump(tester, first: ClipFeedPage(items: [clip('a'), clip('b')]));

      expect(find.text('You can swipe to the next clip'), findsOneWidget);
      // Nothing left animating: the page settles.
      await tester.pumpAndSettle();
      await close(tester);
    });
  });

  group('loading', () {
    testWidgets('the skeleton fits a phone held sideways, notch included, '
        'and a rotation', (tester) async {
      final page = Completer<ClipFeedPage>();
      when(
        () => service.getTopClips(language: any(named: 'language')),
      ).thenAnswer((_) => page.future);
      final settings = SettingsStore.fromJson({})..keepScreenAwake = false;
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(left: 48, right: 48);
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
              playerFactory: (clip, {required focused}) =>
                  players[clip.slug] = FakeVodController(),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      final box = tester.getRect(find.byType(SkeletonLoader).first);
      expect(box.left, greaterThanOrEqualTo(48));
      expect(box.right, lessThanOrEqualTo(844 - 48));
      expect(box.bottom, lessThanOrEqualTo(390));

      // Rotated while the first page still loads.
      tester.view.physicalSize = const Size(390, 844);
      tester.view.padding = FakeViewPadding.zero;
      await tester.pump();
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(844, 390);
      await tester.pump();
      expect(tester.takeException(), isNull);

      page.complete(ClipFeedPage(items: [clip('a')]));
      await tester.pump();
      await close(tester);
    });
  });

  testWidgets('small pictures are decoded at the size they are drawn', (
    tester,
  ) async {
    String thumb(String slug) => 'https://clips-media.example/$slug.jpg';
    int? decodedWidth(String slug) => tester
        .widgetList<OnsetCachedNetworkImage>(
          find.byType(OnsetCachedNetworkImage),
        )
        .where((image) => image.imageUrl == thumb(slug))
        .map((image) => image.memCacheWidth)
        .firstWhere((width) => width != 24 && width != null, orElse: () => -1);
    await pump(
      tester,
      first: ClipFeedPage(
        items: [for (final s in 'abcd'.split('')) clip(s, thumbnail: thumb(s))],
      ),
    );
    // A phone (390 × 844) at 2×: the next clip's 78 dp picture.
    tester.view
      ..devicePixelRatio = 2
      ..physicalSize = const Size(780, 1688);
    await tester.pump();
    expect(find.text('NEXT'), findsOneWidget);
    expect(decodedWidth('b'), 156);

    // A tablet at 2×: the queue's 136 dp pictures.
    tester.view.physicalSize = const Size(2560, 1708);
    await tester.pump();
    await tester.pump();
    expect(find.text('UP NEXT IN CLIPS'), findsOneWidget);
    expect(decodedWidth('c'), 272);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets('a clip without a player draws its picture once', (tester) async {
    String thumb(String slug) => 'https://clips-media.example/$slug.jpg';
    await pump(
      tester,
      first: ClipFeedPage(
        items: [for (final s in 'abc'.split('')) clip(s, thumbnail: thumb(s))],
      ),
    );
    await swipeUp(tester);
    expect(players['a']!.calls, contains('dispose'));

    // Dragged back towards the first clip, whose player is gone: its page
    // shows its picture (the soft one behind aside), once.
    final gesture = await tester.startGesture(const Offset(200, 400));
    await gesture.moveBy(const Offset(0, 150));
    await gesture.moveBy(const Offset(0, 150));
    await tester.pump();
    final pictures = tester
        .widgetList<OnsetCachedNetworkImage>(
          find.byType(OnsetCachedNetworkImage),
        )
        .where((image) => image.imageUrl == thumb('a'))
        .where((image) => image.memCacheWidth != 24);
    expect(pictures, hasLength(1));
    await gesture.up();
    await tester.pumpAndSettle();
    await close(tester);
  });

  group('board ClipsTablette', () {
    Future<void> pumpAt(
      WidgetTester tester,
      Size size, {
      required ClipFeedPage first,
    }) async {
      await pump(tester, first: first);
      tester.view.physicalSize = size;
      await tester.pump();
      await tester.pump();
    }

    for (final size in const [Size(1280, 854), Size(854, 1280)]) {
      testWidgets('the stage and the queue fit ${size.width.toInt()} wide', (
        tester,
      ) async {
        await pumpAt(
          tester,
          size,
          first: ClipFeedPage(
            items: [for (final s in 'abcdef'.split('')) clip(s)],
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.text('UP NEXT IN CLIPS'), findsOneWidget);
        expect(find.text('Swipe the video or pick one'), findsOneWidget);
        expect(find.text('Open clip'), findsOneWidget);
        expect(find.byType(PageView), findsNothing);
        await close(tester);
      });
    }

    testWidgets('a tap in the queue plays that clip', (tester) async {
      await pumpAt(
        tester,
        const Size(1280, 854),
        first: ClipFeedPage(items: [for (final s in 'abcd'.split('')) clip(s)]),
      );
      expect(built.first, ('a', true));

      await tester.tap(find.text('Clip c').last);
      await tester.pumpAndSettle();

      expect(
        players['a']!.calls,
        containsAllInOrder(['focused false', 'pause']),
      );
      expect(built, contains(('c', true)), reason: 'the picked clip plays');
      expect(built.last, ('d', false), reason: 'the one after is preloaded');
      expect(players.containsKey('b'), isTrue);
      expect(players['b']!.calls, contains('dispose'));
      await close(tester);
    });

    testWidgets('a clip sliding off the stage never draws a disposed player', (
      tester,
    ) async {
      when(
        () => service.getTopClips(language: any(named: 'language')),
      ).thenAnswer(
        (_) async =>
            ClipFeedPage(items: [for (final s in 'abcd'.split('')) clip(s)]),
      );
      final settings = SettingsStore.fromJson({})..keepScreenAwake = false;
      final surfaces = <String, FakeSurfaceController>{};
      tester.view.physicalSize = const Size(1280, 854);
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
              disableAutoPip: () {},
              playerFactory: (clip, {required focused}) =>
                  surfaces[clip.slug] = FakeSurfaceController(clip.slug),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey('video-a')), findsOneWidget);

      await tester.tap(find.text('Clip c').last);
      // Every frame of the 460 ms slide.
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        expect(tester.takeException(), isNull);
        for (final slug in ['a', 'b']) {
          if (surfaces[slug]!.disposed) {
            expect(
              find.byKey(ValueKey('video-$slug')),
              findsNothing,
              reason: '$slug is drawn after its player was let go',
            );
          }
        }
      }
      expect(surfaces['a']!.disposed, isTrue);
      expect(surfaces['b']!.disposed, isTrue);
      expect(find.byKey(const ValueKey('video-c')), findsOneWidget);
      await close(tester);
    });

    testWidgets('a swipe on the stage goes to the next clip', (tester) async {
      await pumpAt(
        tester,
        const Size(1280, 854),
        first: ClipFeedPage(items: [clip('a'), clip('b')]),
      );

      await tester.fling(
        find.bySemanticsLabel(RegExp('Clip player')),
        const Offset(0, -300),
        1500,
      );
      await tester.pumpAndSettle();

      expect(players['b']!.calls, containsAllInOrder(['focused true', 'play']));
      await close(tester);
    });

    testWidgets('the clip shown survives a phone ↔ tablet change', (
      tester,
    ) async {
      await pump(
        tester,
        first: ClipFeedPage(items: [clip('a'), clip('b'), clip('c')]),
      );
      await swipeUp(tester);
      expect(players['b']!.calls, contains('play'));
      final playsBefore = players['b']!.calls.where((c) => c == 'play').length;

      tester.view.physicalSize = const Size(1280, 854);
      await tester.pumpAndSettle();
      expect(find.text('Clip b'), findsWidgets);

      tester.view.physicalSize = const Size(400, 800);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // Back on the phone, its pages open at the same clip and do not
      // pause or restart it.
      expect(find.text('Clip b'), findsOneWidget);
      expect(players['b']!.calls.where((c) => c == 'play').length, playsBefore);
      expect(players['b']!.calls.last, isNot('pause'));
      await close(tester);
    });
  });
}
