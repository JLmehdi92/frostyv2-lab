import 'dart:async';

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/apis/twitch_stream_service.dart';
import 'package:frosty/models/channel.dart';
import 'package:frosty/models/stream.dart';
import 'package:frosty/models/user.dart';
import 'package:frosty/screens/channel/chat/stores/chat_tabs_store.dart';
import 'package:frosty/screens/channel/video/content_warning_gate.dart';
import 'package:frosty/screens/channel/video/stores/ivs_video_store.dart';
import 'package:frosty/screens/home/live_feed/live_feed.dart';
import 'package:frosty/screens/home/live_feed/live_preview.dart';
import 'package:frosty/screens/home/live_feed/stores/live_feed_store.dart';
import 'package:frosty/screens/home/stream_list/stream_card_parts.dart';
import 'package:frosty/screens/settings/stores/auth_store.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/screens/settings/stores/user_store.dart';
import 'package:frosty/services/playback_preloader.dart';
import 'package:frosty/stores/mini_player_store.dart';
import 'package:frosty/theme.dart';
import 'package:frosty/widgets/frosty_photo_view_dialog.dart';
import 'package:frosty/widgets/user_actions_modal.dart';
import 'package:mobx/mobx.dart' show ObservableList;
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

class MockAuthStore extends Mock implements AuthStore {}

class MockUserStore extends Mock implements UserStore {}

class MockIvsVideoStore extends Mock implements IvsVideoStore {}

class MockChatTabsStore extends Mock implements ChatTabsStore {}

class MockTwitchStreamService extends Mock implements TwitchStreamService {}

class FakeBackend implements LivePreviewBackend {
  FakeBackend(this.log);

  /// How long letting a decoder go takes (libmpv takes a few frames).
  static var disposeDelay = Duration.zero;

  final List<String> log;
  static var alive = 0;
  static var mostAlive = 0;
  String? url;
  var volume = 0.0;

  @override
  final ValueNotifier<bool> showing = ValueNotifier(false);

  @override
  Future<void> open(String url) async {
    this.url = url;
    alive++;
    if (alive > mostAlive) mostAlive = alive;
    log.add('open $url');
    showing.value = true;
  }

  @override
  Future<void> setVolume(double volume) async => this.volume = volume;

  @override
  Widget buildVideo() => const ColoredBox(
    key: ValueKey('preview-video'),
    color: Color(0xFF00FF00),
  );

  @override
  Future<void> dispose() async {
    if (disposeDelay > Duration.zero) await Future<void>.delayed(disposeDelay);
    if (url != null) alive--;
    log.add('dispose $url');
  }
}

StreamTwitch _stream(int i) => StreamTwitch(
  '$i',
  'login$i',
  'Name $i',
  i.isEven ? '20' : '10',
  i.isEven ? 'League of Legends' : 'Just Chatting',
  'Title $i',
  1000 * (20 - i),
  '2026-10-28T10:00:00Z',
  'https://static-cdn.jtvnw.net/previews-ttv/live_user_login$i-{width}x{height}.jpg',
  tags: const ['Français'],
  language: 'fr',
);

void main() {
  late MockTwitchApi api;
  late MockAuthStore auth;
  late SettingsStore settings;
  late MiniPlayerStore mini;
  late List<StreamTwitch> top;
  late Object? failure;
  late List<String> log;
  late bool loggedIn;

  /// The content labels Twitch gives each channel (by id).
  late Map<String, List<String>> labels;

  setUp(() {
    api = MockTwitchApi();
    auth = MockAuthStore();
    settings = SettingsStore.fromJson({});
    mini = MiniPlayerStore();
    top = [for (var i = 1; i <= 6; i++) _stream(i)];
    failure = null;
    log = [];
    loggedIn = true;
    FakeBackend.alive = 0;
    FakeBackend.mostAlive = 0;
    FakeBackend.disposeDelay = Duration.zero;
    final user = MockUserStore();
    when(() => auth.user).thenReturn(user);
    when(() => auth.isLoggedIn).thenAnswer((_) => loggedIn);
    when(() => auth.twitchWebToken).thenReturn(null);
    when(() => user.details).thenReturn(const UserTwitch('7', 'me', 'Me', ''));
    when(() => user.blockedUsers).thenReturn(ObservableList());
    when(
      () => api.getTopStreams(
        cursor: any(named: 'cursor'),
        language: any(named: 'language'),
      ),
    ).thenAnswer((_) async {
      if (failure != null) throw failure!;
      return StreamsTwitch(top, const {});
    });
    when(
      () => api.getStreamsUnderCategory(
        gameId: any(named: 'gameId'),
        cursor: any(named: 'cursor'),
        language: any(named: 'language'),
      ),
    ).thenAnswer((_) async => StreamsTwitch([_stream(2)], const {}));
    when(
      () => api.getUser(userLogin: any(named: 'userLogin')),
    ).thenAnswer((_) => Future.error(Exception('offline')));
    labels = {};
    when(() => api.getChannelsByIds(any())).thenAnswer(
      (invocation) async => {
        for (final id in invocation.positionalArguments.first as List)
          id as String: Channel(
            broadcasterId: id,
            broadcasterLogin: 'login$id',
            broadcasterName: 'Name $id',
            broadcasterLanguage: 'fr',
            title: 'Title $id',
            gameId: '',
            gameName: '',
            contentClassificationLabels: labels[id] ?? const [],
          ),
      },
    );
    AcceptedContentWarnings.reset();
  });

  tearDown(AcceptedContentWarnings.reset);

  late LiveFeedStore store;
  late PageController controller;
  late LivePreviewController preview;

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    ThemeMode mode = ThemeMode.dark,
    bool active = true,
    bool reduceMotion = false,
    ValueNotifier<bool>? activeNotifier,
    Route<void> Function(StreamTwitch)? channelRoute,
    Stream<bool?>? meteredChanges,
    ValueListenable<bool>? introRunning,
    Future<bool?> Function()? isMetered,
    Future<String> Function(String login, CancelToken cancel)? resolve,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    store = LiveFeedStore(
      authStore: auth,
      settingsStore: settings,
      twitchApi: api,
    );
    controller = PageController();
    preview = LivePreviewController(
      resolveUrl: resolve ?? (login, cancel) async => 'https://usher/$login',
      createBackend: () => FakeBackend(log),
    );
    final themes = FrostyThemes(colorSchemeSeed: FrostyTokens.accent);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthStore>.value(value: auth),
          Provider<SettingsStore>.value(value: settings),
          Provider<TwitchApi>.value(value: api),
          Provider<MiniPlayerStore>.value(value: mini),
        ],
        child: MaterialApp(
          theme: themes.light,
          darkTheme: themes.dark,
          themeMode: mode,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: reduceMotion),
            child: child!,
          ),
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: activeNotifier ?? ValueNotifier(active),
              builder: (context, active, _) => LiveFeed(
                store: store,
                controller: controller,
                active: active,
                preview: preview,
                isMetered: isMetered ?? () async => true,
                meteredChanges: meteredChanges ?? const Stream.empty(),
                introRunning: introRunning,
                channelRoute: channelRoute,
              ),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    preview.dispose();
    store.dispose();
    controller.dispose();
    await tester.pump(const Duration(seconds: 1));
  }

  for (final (name, size) in [
    ('phone', const Size(390, 844)),
    ('tablet landscape', const Size(1280, 854)),
    ('tablet portrait', const Size(854, 1280)),
  ]) {
    for (final mode in [ThemeMode.dark, ThemeMode.light]) {
      testWidgets('$name, ${mode.name}: one live, its muted preview, its '
          'actions, without overflow', (tester) async {
        await pump(tester, size: size, mode: mode);

        expect(tester.takeException(), isNull);
        expect(find.text('Name 1'), findsWidgets);
        expect(find.text('LIVE'), findsOneWidget);
        expect(find.textContaining('Muted preview'), findsOneWidget);
        expect(find.text('Watch with chat'), findsOneWidget);
        expect(find.byTooltip('Unmute'), findsOneWidget);
        expect(find.byTooltip('Not interested'), findsOneWidget);
        expect(find.byTooltip('Share'), findsOneWidget);
        expect(find.text('Follow'), findsOneWidget);
        expect(find.text('Just Chatting · FR'), findsOneWidget);
        // One decoder, for the channel on screen, muted.
        expect(log, ['open https://usher/login1']);
        expect(find.byKey(const ValueKey('preview-video')), findsOneWidget);
        if (size.shortestSide >= 600) {
          expect(find.text('UP NEXT'), findsOneWidget);
          expect(find.text('Name 2'), findsOneWidget);
        } else {
          // The chips sit over the video on a phone (the tablet's are in
          // the shell's tab row).
          expect(find.text('All'), findsOneWidget);
          expect(find.text('SWIPE UP FOR THE NEXT LIVE'), findsOneWidget);
        }
        await close(tester);
      });
    }
  }

  group('content warnings (the setting on)', () {
    Finder warning() => find.text('Content warning · Play preview');

    for (final (name, size) in [
      ('phone', const Size(390, 844)),
      ('tablet', const Size(1280, 854)),
    ]) {
      testWidgets('$name: a labelled channel never previews on its own; '
          'its warning, then Start watching plays it', (tester) async {
        labels = {
          '1': ['SexualThemes'],
        };
        await pump(tester, size: size);
        await tester.pump(const Duration(seconds: 1));

        expect(log, isEmpty);
        expect(find.byKey(const ValueKey('preview-video')), findsNothing);
        expect(warning(), findsOneWidget);
        // Nothing to unmute.
        expect(find.byTooltip('Unmute'), findsNothing);

        await tester.tap(warning());
        await tester.pump();
        expect(find.text('Just one second…'), findsOneWidget);
        expect(find.text('It may contain: Sexual Themes'), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(log, isEmpty);

        await tester.tap(find.text('Start watching'));
        await tester.pump(const Duration(seconds: 1));
        expect(AcceptedContentWarnings.has('1'), isTrue);
        expect(log, ['open https://usher/login1']);
        expect(find.text('Just one second…'), findsNothing);
        expect(warning(), findsNothing);
        await close(tester);
      });
    }

    testWidgets('Go back: the picture again, nothing plays, Home stays', (
      tester,
    ) async {
      labels = {
        '1': ['SexualThemes'],
      };
      await pump(tester);
      await tester.tap(warning());
      await tester.pump();
      await tester.tap(find.text('Go back'));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Just one second…'), findsNothing);
      expect(warning(), findsOneWidget);
      expect(find.byType(LiveFeed), findsOneWidget);
      expect(AcceptedContentWarnings.has('1'), isFalse);
      expect(log, isEmpty);
      await close(tester);
    });

    testWidgets('labels Twitch cannot give: no preview (fail closed), the '
        'same consent plays it', (tester) async {
      when(
        () => api.getChannelsByIds(any()),
      ).thenAnswer((_) => Future.error(Exception('helix down')));
      await pump(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(log, isEmpty);

      await tester.tap(warning());
      await tester.pump();
      expect(find.text('Just one second…'), findsOneWidget);
      await tester.tap(find.text('Start watching'));
      await tester.pump(const Duration(seconds: 1));
      expect(log, ['open https://usher/login1']);
      await close(tester);
    });

    testWidgets('the next unlabelled channel previews as before', (
      tester,
    ) async {
      labels = {
        '1': ['SexualThemes'],
      };
      await pump(tester);
      await tester.fling(find.text('Title 1'), const Offset(0, -500), 2000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(store.current!.userId, '2');
      expect(log, ['open https://usher/login2']);
      await close(tester);
    });

    testWidgets('accepted on the channel this session, or warnings off: it '
        'previews', (tester) async {
      labels = {
        '1': ['SexualThemes'],
      };
      AcceptedContentWarnings.add('1');
      await pump(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(log, ['open https://usher/login1']);
      expect(warning(), findsNothing);
      await close(tester);

      AcceptedContentWarnings.reset();
      log.clear();
      settings.warnMatureContent = false;
      await pump(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(log, ['open https://usher/login1']);
      expect(warning(), findsNothing);
      await close(tester);
    });

    testWidgets('autoplay off: Play preview asks first', (tester) async {
      labels = {
        '1': ['SexualThemes'],
      };
      settings.vodAutoplay = VodAutoplay.never;
      await pump(tester);
      await tester.tap(find.byTooltip('Play preview'));
      await tester.pump();
      expect(find.text('Just one second…'), findsOneWidget);
      expect(log, isEmpty);
      await tester.tap(find.text('Start watching'));
      await tester.pump(const Duration(seconds: 1));
      expect(log, ['open https://usher/login1']);
      await close(tester);
    });
  });

  testWidgets('a swipe up: the next live, its preview, never two', (
    tester,
  ) async {
    await pump(tester);

    await tester.fling(find.text('Title 1'), const Offset(0, -500), 2000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(store.index, 1);
    expect(store.current!.userId, '2');
    expect(log, [
      'open https://usher/login1',
      'dispose https://usher/login1',
      'open https://usher/login2',
    ]);
    expect(FakeBackend.mostAlive, 1);
    await close(tester);
  });

  testWidgets('inactive (another tab, a page above): no preview', (
    tester,
  ) async {
    await pump(tester, active: false);

    expect(log, isEmpty);
    expect(find.byKey(const ValueKey('preview-video')), findsNothing);
    await close(tester);
  });

  testWidgets('the mini player playing: no preview until it closes', (
    tester,
  ) async {
    mini.adopt(
      player: MockIvsVideoStore(),
      chatTabsStore: MockChatTabsStore(),
      userLogin: 'other',
      userId: '99',
      displayName: 'Other',
    );
    await pump(tester);
    expect(log, isEmpty);

    mini.release();
    await tester.pump(const Duration(seconds: 1));
    expect(log, ['open https://usher/login1']);
    await close(tester);
  });

  testWidgets('autoplay off: the picture, and a preview only by hand', (
    tester,
  ) async {
    settings.vodAutoplay = VodAutoplay.never;
    await pump(tester);
    expect(log, isEmpty);

    await tester.tap(find.byTooltip('Play preview'));
    await tester.pump(const Duration(seconds: 1));
    expect(log, ['open https://usher/login1']);
    expect(find.byTooltip('Unmute'), findsOneWidget);
    await close(tester);
  });

  testWidgets('Wi-Fi only, on mobile data: no preview', (tester) async {
    settings.vodAutoplay = VodAutoplay.wifiOnly;
    await pump(tester);
    await tester.pump(const Duration(seconds: 1));

    expect(log, isEmpty);
    await close(tester);
  });

  testWidgets('unmute is asked, never automatic', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('Unmute'));
    await tester.pump();

    expect(preview.muted, isFalse);
    expect(find.byTooltip('Mute'), findsOneWidget);
    await close(tester);
  });

  testWidgets('not interested: the next live, and Undo', (tester) async {
    await pump(tester);

    await tester.tap(find.byTooltip('Not interested'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(store.current!.userId, '2');
    expect(find.text("You won't see Name 1 in Live for now"), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Undo'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(store.current!.userId, '1');
    await close(tester);
  });

  testWidgets('a long press: the picture enlarges, as on every card; on '
      "the channel's lines, its actions", (tester) async {
    await pump(tester);

    await tester.longPress(
      find.bySemanticsLabel(RegExp('Name 1 live preview')),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(FrostyPhotoViewDialog), findsOneWidget);
    Navigator.of(tester.element(find.byType(FrostyPhotoViewDialog))).pop();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.longPress(find.text('Title 1'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(UserActionsModal), findsOneWidget);
    await close(tester);
  });

  testWidgets('logged out: no Follow', (tester) async {
    loggedIn = false;
    await pump(tester);

    expect(find.text('Follow'), findsNothing);
    await close(tester);
  });

  testWidgets('a chip shows its category from the first live', (tester) async {
    await pump(tester);

    final chip = find.text('League of Legends').first;
    await tester.ensureVisible(chip);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(chip);
    await tester.pump(const Duration(milliseconds: 500));

    expect(store.categoryId, '20');
    expect(store.current!.userId, '2');
    await close(tester);
  });

  testWidgets('nobody live: the message', (tester) async {
    top = [];
    await pump(tester);

    expect(find.text('No top streams'), findsOneWidget);
    expect(log, isEmpty);
    await close(tester);
  });

  testWidgets('a failure: the message and "Try again", which reloads', (
    tester,
  ) async {
    failure = Exception('down');
    await pump(tester);
    expect(find.text('Something went wrong loading streams'), findsOneWidget);

    failure = null;
    await tester.tap(find.text('Try again'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Title 1'), findsOneWidget);
    await close(tester);
  });

  testWidgets('the page after the last live: no preview plays there', (
    tester,
  ) async {
    top = [_stream(1)];
    await pump(tester);
    expect(log, ['open https://usher/login1']);

    await tester.fling(find.text('Title 1'), const Offset(0, -500), 2000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Back to the first'), findsOneWidget);
    expect(log, ['open https://usher/login1', 'dispose https://usher/login1']);
    await close(tester);
  });

  testWidgets('a channel opened from the feed: its decoder goes first, no '
      'preview under it (app resumed meanwhile, its page leaving), then '
      'the preview is back', (tester) async {
    // Letting the decoder go takes 80 ms here (under the 100 ms cap).
    FakeBackend.disposeDelay = const Duration(milliseconds: 80);
    late int aliveAtBuild;
    await pump(
      tester,
      // A page that takes a full second to leave (its player lives until
      // then).
      channelRoute: (stream) => PageRouteBuilder<void>(
        reverseTransitionDuration: const Duration(seconds: 1),
        pageBuilder: (context, animation, secondary) {
          aliveAtBuild = FakeBackend.alive;
          return Scaffold(body: Text('Channel ${stream.userLogin}'));
        },
      ),
    );
    expect(log, ['open https://usher/login1']);

    await tester.tap(find.text('Watch with chat'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Channel login1'), findsOneWidget);
    // The preview's decoder was gone before the channel's page was built.
    expect(aliveAtBuild, 0);

    // The app goes away and comes back while the channel is open.
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump(const Duration(seconds: 1));
    expect(log.where((e) => e.startsWith('open')), hasLength(1));

    // Back: while the channel's page is still leaving (its player too),
    // nothing starts, well past the preview's settle time.
    Navigator.of(tester.element(find.text('Channel login1'))).pop();
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Channel login1'), findsOneWidget);
    expect(log.where((e) => e.startsWith('open')), hasLength(1));

    // Its page gone, the preview settles and starts again.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Channel login1'), findsNothing);
    expect(log.where((e) => e.startsWith('open')), hasLength(2));
    expect(FakeBackend.mostAlive, 1);
    await close(tester);
  });

  testWidgets('a finger on the preview or on Watch asks for its token', (
    tester,
  ) async {
    final service = MockTwitchStreamService();
    when(() => service.preload(any())).thenAnswer((_) async {});
    final previous = PlaybackPreloader.instance;
    PlaybackPreloader.instance = PlaybackPreloader(service, isAndroid: true);
    addTearDown(() => PlaybackPreloader.instance = previous);
    await pump(
      tester,
      channelRoute: (stream) => MaterialPageRoute<void>(
        builder: (context) => const Scaffold(body: Text('Channel')),
      ),
    );

    for (final target in [
      find.bySemanticsLabel(RegExp('Name 1 live preview')),
      find.text('Watch with chat'),
    ]) {
      final gesture = await tester.startGesture(tester.getCenter(target));
      // Past the press timeout (a long press is also possible there).
      await tester.pump(const Duration(milliseconds: 150));
      await gesture.cancel();
      await tester.pump();
    }

    verify(() => service.preload('login1')).called(2);
    await close(tester);
  });

  testWidgets('leaving Wi-Fi stops a "Wi-Fi only" preview at once', (
    tester,
  ) async {
    settings.vodAutoplay = VodAutoplay.wifiOnly;
    final network = StreamController<bool?>();
    addTearDown(network.close);
    await pump(
      tester,
      isMetered: () async => false,
      meteredChanges: network.stream,
    );
    await tester.pump(const Duration(seconds: 1));
    expect(log, ['open https://usher/login1']);

    // Wi-Fi signal updates repeat the same answer: nothing rebuilds.
    LiveFeed.debugMeteredUpdates = 0;
    for (var i = 0; i < 5; i++) {
      network.add(false);
    }
    await tester.pump(const Duration(milliseconds: 100));
    expect(LiveFeed.debugMeteredUpdates, 0);
    expect(log, ['open https://usher/login1']);

    network.add(true);
    await tester.pump(const Duration(milliseconds: 100));
    expect(LiveFeed.debugMeteredUpdates, 1);
    expect(log.last, 'dispose https://usher/login1');
    expect(find.byTooltip('Play preview'), findsOneWidget);

    network.add(false);
    await tester.pump(const Duration(seconds: 1));
    expect(log.last, 'open https://usher/login1');
    await close(tester);
  });

  testWidgets('thumbnails off: no picture, no preview unless asked', (
    tester,
  ) async {
    settings.showThumbnails = false;
    await pump(tester);

    expect(find.byType(StreamThumbnail), findsNothing);
    expect(log, isEmpty);
    await tester.tap(find.byTooltip('Play preview'));
    await tester.pump(const Duration(seconds: 1));
    expect(log, ['open https://usher/login1']);
    // No picture to enlarge: a long press opens the actions.
    await tester.longPress(
      find.bySemanticsLabel(RegExp('Name 1 live preview')),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(UserActionsModal), findsOneWidget);
    await close(tester);
  });

  testWidgets('a preview that cannot start says so, with no dead Unmute', (
    tester,
  ) async {
    await pump(tester, resolve: (login, cancel) async => throw Exception('x'));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Preview unavailable'), findsOneWidget);
    expect(find.byTooltip('Unmute'), findsNothing);
    await close(tester);
  });

  testWidgets('no preview while the launch intro covers the app', (
    tester,
  ) async {
    final intro = ValueNotifier(true);
    await pump(tester, introRunning: intro);
    await tester.pump(const Duration(seconds: 1));
    expect(log, isEmpty);

    intro.value = false;
    await tester.pump(const Duration(seconds: 1));
    expect(log, ['open https://usher/login1']);
    await close(tester);
  });

  testWidgets('a failed refresh says so; the end page offers to try again', (
    tester,
  ) async {
    top = [_stream(1)];
    await pump(tester);
    failure = Exception('down');

    await tester.fling(find.text('Title 1'), const Offset(0, 500), 2000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    // The channels stay; a snack bar says what went wrong.
    expect(find.text('Title 1'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.text('Something went wrong loading streams'),
      ),
      findsOneWidget,
    );

    await tester.fling(find.text('Title 1'), const Offset(0, -500), 2000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('That’s every live channel here for now'), findsNothing);

    failure = null;
    top = [_stream(1), _stream(2)];
    await tester.tap(find.text('Try again'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // Back where it was, with the channel that came in.
    expect(find.text('Title 2'), findsOneWidget);
    await close(tester);
  });

  testWidgets('a stale refresh keeps the channel on screen', (tester) async {
    final active = ValueNotifier(true);
    await pump(tester, activeNotifier: active);
    await tester.fling(find.text('Title 1'), const Offset(0, -500), 2000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.fling(find.text('Title 2'), const Offset(0, -500), 2000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(store.current!.userId, '3');

    // Now channel 3 is second in the list.
    top = [_stream(5), _stream(3), _stream(1)];
    active.value = false;
    await tester.pump();
    store.list.lastTimeRefreshed = DateTime.now().subtract(
      const Duration(minutes: 6),
    );
    active.value = true;
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(store.current!.userId, '3');
    expect(store.index, 1);
    expect(find.text('Title 3'), findsOneWidget);
    await close(tester);
  });

  testWidgets('another language: the feed starts over, chips taken again', (
    tester,
  ) async {
    await pump(tester);
    await tester.fling(find.text('Title 1'), const Offset(0, -500), 2000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(store.index, 1);
    expect(store.chips.map((c) => c.id), ['10', '20']);

    top = [
      for (var i = 7; i <= 9; i++)
        StreamTwitch(
          '$i',
          'login$i',
          'Name $i',
          '30',
          'Chess',
          'Title $i',
          10,
          '2026-10-28T10:00:00Z',
          '',
        ),
    ];
    settings.streamLanguage = 'fr';
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(store.index, 0);
    expect(controller.page, 0);
    expect(find.text('Title 7'), findsOneWidget);
    expect(store.chips.map((c) => c.name), ['Chess']);
    await close(tester);
  });

  testWidgets('back on Live after five minutes: fresh channels', (
    tester,
  ) async {
    final active = ValueNotifier(true);
    await pump(tester, activeNotifier: active);
    clearInteractions(api);

    active.value = false;
    await tester.pump();
    store.list.lastTimeRefreshed = DateTime.now().subtract(
      const Duration(minutes: 6),
    );
    active.value = true;
    await tester.pump(const Duration(milliseconds: 500));

    verify(
      () => api.getTopStreams(
        cursor: any(named: 'cursor'),
        language: any(named: 'language'),
      ),
    ).called(1);
    await close(tester);
  });

  testWidgets('unmuted, the label says so', (tester) async {
    await pump(tester);
    expect(find.text('· Muted preview'), findsOneWidget);

    await tester.tap(find.byTooltip('Unmute'));
    await tester.pump();

    expect(find.text('· Sound on'), findsOneWidget);
    await close(tester);
  });

  testWidgets('reduce motion: the hint stays still', (tester) async {
    await pump(tester, reduceMotion: true);

    final hint = find.text('SWIPE UP FOR THE NEXT LIVE');
    final before = tester.getTopLeft(hint);
    await tester.pump(const Duration(milliseconds: 1200));
    expect(tester.getTopLeft(hint), before);
    await close(tester);
  });
}
