import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/apis/twitch_stream_service.dart';
import 'package:onset/models/stream.dart';
import 'package:onset/models/user.dart';
import 'package:onset/screens/channel/chat/stores/chat_store.dart';
import 'package:onset/screens/channel/landscape_chat_cycle.dart';
import 'package:onset/screens/channel/tablet_video_column.dart';
import 'package:onset/screens/channel/video/ivs_recovery.dart';
import 'package:onset/screens/channel/video/ivs_stats_panel.dart';
import 'package:onset/screens/channel/video/latency_pill.dart';
import 'package:onset/screens/channel/video/player_controller.dart';
import 'package:onset/screens/channel/video/stores/ivs_video_store.dart';
import 'package:onset/screens/channel/video/video_overlay.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/context_extensions.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fixtures/api_responses.dart';
import '../../helpers/fake_ivs_native.dart';
import '../../helpers/fake_player.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

class MockChatStore extends Mock implements ChatStore {}

class MockAuthStore extends Mock implements AuthStore {}

class MockTwitchStreamService extends Mock implements TwitchStreamService {}

/// Stands in for the player: counts how often its state is created, the way
/// a recreated player would reload its stream.
class _PlayerProbe extends StatefulWidget {
  const _PlayerProbe({super.key});

  static var created = 0;

  @override
  State<_PlayerProbe> createState() => _PlayerProbeState();
}

class _PlayerProbeState extends State<_PlayerProbe> {
  @override
  void initState() {
    super.initState();
    _PlayerProbe.created++;
  }

  @override
  Widget build(BuildContext context) =>
      const ColoredBox(color: Colors.black, child: SizedBox.expand());
}

const _infoKey = ValueKey('info');
const _chatKey = ValueKey('chat');

/// The landscape layouts of the channel screen as `channel.dart` puts them
/// together (that screen cannot be pumped in a test, see
/// channel_wiring_test, which pins the same decisions in its code): the
/// player under the chat in full screen, beside it otherwise, a tablet's
/// video column with its info area unless the double tap opened the side
/// column. The double tap and the overlay's own buttons are the real ones.
class _Screen extends StatelessWidget {
  const _Screen({
    required this.cycle,
    required this.player,
    required this.chat,
    required this.playerKey,
  });

  final LandscapeChatCycle cycle;
  final PlayerController player;
  final ChatStore chat;
  final GlobalKey playerKey;

  @override
  Widget build(BuildContext context) {
    final settings = player.settingsStore;
    final gestures = GestureDetector(
      onDoubleTap: context.isLandscape ? cycle.next : null,
      onTap: player.handleVideoTap,
      child: ColoredBox(
        color: Colors.transparent,
        child: VideoOverlay(
          videoStore: player,
          chatStore: chat,
          settingsStore: settings,
        ),
      ),
    );
    // The latency over the video and the IVS stats under the controls' top
    // row, as the channel screen draws them.
    final metrics = PlayerChromeMetrics.of(context);
    final chrome = Stack(
      fit: StackFit.expand,
      children: [
        gestures,
        Positioned(
          top: metrics.pillTop,
          right: metrics.pillEdge,
          child: Observer(
            builder: (context) {
              if (!settings.showLatency || player.streamInfo == null) {
                return const SizedBox.shrink();
              }
              return IgnorePointer(
                ignoring: !(player.overlayVisible || player.paused),
                child: LatencyPill(store: player, large: metrics.large),
              );
            },
          ),
        ),
      ],
    );
    final statsLayer = Observer(
      // Only the IVS engine has stats to read.
      warnWhenNoObservables: false,
      builder: (context) {
        if (player case final IvsVideoStore ivs when ivs.statsVisible) {
          return IgnorePointer(
            child: Padding(
              padding: EdgeInsets.fromLTRB(8, metrics.top + 44, 8, 8),
              child: Align(
                alignment: Alignment.topLeft,
                child: IvsStatsPanel(store: ivs),
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
    final probe = _PlayerProbe(key: playerKey);
    final video = Stack(
      fit: StackFit.expand,
      children: [probe, chrome, statsLayer],
    );
    const chatPane = ColoredBox(
      color: Colors.grey,
      child: SizedBox.expand(key: _chatKey),
    );
    return Scaffold(
      body: Observer(
        builder: (context) {
          final plainSide = cycle.plainSide;
          final overlayChat = settings.fullScreenChatOverlay;
          if (settings.fullScreen) {
            return LayoutBuilder(
              builder: (context, constraints) => Stack(
                children: [
                  Positioned.fill(child: probe),
                  Row(
                    children: [
                      Expanded(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [chrome, statsLayer],
                        ),
                      ),
                      Visibility(
                        visible: overlayChat,
                        maintainState: true,
                        child: SizedBox(
                          width: constraints.maxWidth * settings.chatWidth,
                          child: chatPane,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              final tablet = context.isLargeScreen;
              return Row(
                children: [
                  Expanded(
                    child: tablet
                        ? TabletVideoColumn(
                            infoArea: !plainSide,
                            video: video,
                            info: const ColoredBox(
                              color: Colors.blueGrey,
                              child: SizedBox.expand(key: _infoKey),
                            ),
                          )
                        : video,
                  ),
                  SizedBox(
                    width: constraints.maxWidth * settings.chatWidth,
                    child: chatPane,
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

void main() {
  group('the rules', () {
    late SettingsStore settings;
    late LandscapeChatCycle cycle;

    setUp(() {
      settings = SettingsStore.fromJson({});
      cycle = LandscapeChatCycle(settings);
    });
    tearDown(() => cycle.dispose());

    void overlay() => settings
      ..fullScreen = true
      ..fullScreenChatOverlay = true;

    test('overlay → plain side column → hidden → overlay', () {
      overlay();
      cycle.next();
      expect(settings.fullScreen, isFalse);
      expect(cycle.plainSide, isTrue);

      cycle.next();
      expect(settings.fullScreen, isTrue);
      expect(settings.fullScreenChatOverlay, isFalse);
      expect(cycle.plainSide, isFalse);

      cycle.next();
      expect(settings.fullScreen, isTrue);
      expect(settings.fullScreenChatOverlay, isTrue);
      expect(cycle.plainSide, isFalse);

      cycle.next();
      expect(settings.fullScreen, isFalse);
      expect(cycle.plainSide, isTrue);
    });

    test('a layout turned off in Settings is skipped', () {
      settings.setLandscapeChatMode(LandscapeChatMode.hidden, on: false);
      overlay();
      cycle.next();
      expect(settings.fullScreen, isFalse);
      expect(cycle.plainSide, isTrue);
      cycle.next();
      expect(settings.fullScreen, isTrue);
      expect(settings.fullScreenChatOverlay, isTrue);
    });

    test('without the side column, overlay and hidden swap', () {
      settings.setLandscapeChatMode(LandscapeChatMode.column, on: false);
      overlay();
      cycle.next();
      expect(settings.fullScreen, isTrue);
      expect(settings.fullScreenChatOverlay, isFalse);
      cycle.next();
      expect(settings.fullScreenChatOverlay, isTrue);
      settings.fullScreen = false;
      cycle.next();
      expect(settings.fullScreen, isTrue);
      expect(settings.fullScreenChatOverlay, isFalse);
    });

    test('the next mode wraps around the cycle order', () {
      const all = LandscapeChatMode.values;
      expect(
        nextLandscapeChatMode(LandscapeChatMode.hidden, all),
        LandscapeChatMode.overlay,
      );
      expect(
        nextLandscapeChatMode(LandscapeChatMode.column, const [
          LandscapeChatMode.overlay,
          LandscapeChatMode.column,
        ]),
        LandscapeChatMode.overlay,
      );
      expect(
        nextLandscapeChatMode(LandscapeChatMode.hidden, const [
          LandscapeChatMode.overlay,
          LandscapeChatMode.column,
        ]),
        LandscapeChatMode.overlay,
      );
    });

    test("from a tablet's side column the double tap hides the chat", () {
      cycle.next();
      expect(settings.fullScreen, isTrue);
      expect(settings.fullScreenChatOverlay, isFalse);
      expect(cycle.plainSide, isFalse);
    });

    test('"Show chat" from hidden opens the tablet side column', () {
      settings
        ..fullScreen = true
        ..fullScreenChatOverlay = false;
      // The sidebar button sets the settings, nothing else.
      settings.fullScreen = false;
      expect(cycle.plainSide, isFalse);
    });

    test('full screen by any path ends the plain side column', () {
      overlay();
      cycle.next();
      expect(cycle.plainSide, isTrue);
      // "Hide chat" …
      settings
        ..fullScreen = true
        ..fullScreenChatOverlay = false;
      expect(cycle.plainSide, isFalse);
      // … then "Show chat": the tablet's side column, not a stuck flag.
      settings.fullScreen = false;
      expect(cycle.plainSide, isFalse);
    });

    test('portrait ends it', () {
      overlay();
      cycle.next();
      expect(cycle.plainSide, isTrue);
      cycle.reset();
      expect(cycle.plainSide, isFalse);
    });

    test('it is never saved: a channel opened again starts plain-free', () {
      overlay();
      cycle.next();
      expect(cycle.plainSide, isTrue);
      final saved = SettingsStore.fromJson(settings.toJson());
      final reopened = LandscapeChatCycle(saved);
      addTearDown(reopened.dispose);
      expect(saved.fullScreen, isFalse);
      expect(reopened.plainSide, isFalse);
    });
  });

  group('the layouts', () {
    late MockTwitchApi api;
    late MockChatStore chat;

    setUp(() {
      _PlayerProbe.created = 0;
      api = MockTwitchApi();
      when(() => api.getUser(userLogin: any(named: 'userLogin'))).thenAnswer(
        (_) async => const UserTwitch('42', 'streamer', 'Streamer', ''),
      );
      chat = MockChatStore();
      when(() => chat.displayName).thenReturn('Streamer');
      when(() => chat.channelName).thenReturn('streamer');
      when(() => chat.isInSharedChatMode).thenReturn(false);
    });

    /// The screen in the state the fullscreen entry leaves it: the chat
    /// over the video.
    Future<(LandscapeChatCycle, SettingsStore)> pump(
      WidgetTester tester,
      Size screen, {
      PlayerController Function(SettingsStore settings)? player,
    }) async {
      tester.view.physicalSize = screen;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final settings = SettingsStore.fromJson({})
        ..fullScreen = true
        ..fullScreenChatOverlay = true;
      final cycle = LandscapeChatCycle(settings);
      addTearDown(cycle.dispose);
      final controller =
          player?.call(settings) ??
          FakePlayer(settings: settings, stream: fakeStream());
      const themes = OnsetThemes(colorSchemeSeed: OnsetTokens.accent);
      await tester.pumpWidget(
        Provider<TwitchApi>.value(
          value: api,
          child: MaterialApp(
            theme: themes.dark,
            home: _Screen(
              cycle: cycle,
              player: controller,
              chat: chat,
              playerKey: GlobalKey(),
            ),
          ),
        ),
      );
      await tester.pump();
      return (cycle, settings);
    }

    Rect videoRect(WidgetTester tester) =>
        tester.getRect(find.byType(_PlayerProbe));
    Rect chatRect(WidgetTester tester) => tester.getRect(find.byKey(_chatKey));

    /// A finger's double tap on the video, away from its buttons.
    Future<void> doubleTap(WidgetTester tester) async {
      final at = Offset(videoRect(tester).width * 0.3, 300);
      await tester.tapAt(at);
      await tester.pump(const Duration(milliseconds: 90));
      await tester.tapAt(at);
      await tester.pump(kDoubleTapTimeout);
      await tester.pump();
    }

    /// A button over the video: it answers once the double tap has given
    /// up (the video's double tap waits for a second tap first).
    Future<void> press(WidgetTester tester, String tooltip) async {
      await tester.tap(find.byTooltip(tooltip));
      await tester.pump(kDoubleTapTimeout);
      await tester.pump();
    }

    Future<void> done(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets(
      'tablet: the double tap from the overlay gives full screen beside the '
      'chat, without the info area',
      (tester) async {
        final (cycle, settings) = await pump(tester, const Size(1600, 1066));
        // The chat starts over the video.
        expect(videoRect(tester).overlaps(chatRect(tester)), isTrue);

        await doubleTap(tester);
        expect(settings.fullScreen, isFalse);
        expect(cycle.plainSide, isTrue);
        // The video's box is its whole column, its full height: the player
        // centres its 16:9 picture in it (black bars), as in full screen.
        expect(videoRect(tester), const Rect.fromLTWH(0, 0, 1280, 1066));
        expect(videoRect(tester).overlaps(chatRect(tester)), isFalse);
        expect(chatRect(tester), const Rect.fromLTWH(1280, 0, 320, 1066));
        expect(find.byKey(_infoKey), findsNothing);
        // The controls carry the title, the info area being gone.
        expect(find.text(fakeStream().title), findsOneWidget);

        // The cycle goes on: hidden, then the overlay again.
        await doubleTap(tester);
        expect(settings.fullScreen, isTrue);
        expect(settings.fullScreenChatOverlay, isFalse);
        expect(find.byKey(_chatKey), findsNothing);
        await doubleTap(tester);
        expect(settings.fullScreenChatOverlay, isTrue);
        expect(videoRect(tester).overlaps(chatRect(tester)), isTrue);
        await doubleTap(tester);
        expect(find.byKey(_infoKey), findsNothing);
        expect(videoRect(tester), const Rect.fromLTWH(0, 0, 1280, 1066));

        // One player throughout: never rebuilt, never reloaded.
        expect(_PlayerProbe.created, 1);
        await done(tester);
      },
    );

    testWidgets('tablet: "Show chat" keeps the info area under the video', (
      tester,
    ) async {
      final (cycle, settings) = await pump(tester, const Size(1600, 1066));
      // Hidden, then the sidebar button.
      await doubleTap(tester);
      await doubleTap(tester);
      expect(settings.fullScreen, isTrue);
      expect(settings.fullScreenChatOverlay, isFalse);
      await press(tester, 'Show chat');
      expect(settings.fullScreen, isFalse);
      expect(cycle.plainSide, isFalse);
      // 1280 wide → a 720 high video, the info area under it.
      expect(videoRect(tester), const Rect.fromLTWH(0, 0, 1280, 720));
      expect(find.byKey(_infoKey), findsOneWidget);

      // From the double tap's side column too: "Hide chat" then "Show
      // chat" lands on the info area, nothing stuck.
      await doubleTap(tester); // hidden
      await doubleTap(tester); // overlay
      await doubleTap(tester); // side, plain
      expect(find.byKey(_infoKey), findsNothing);
      await press(tester, 'Hide chat');
      expect(settings.fullScreen, isTrue);
      await press(tester, 'Show chat');
      expect(find.byKey(_infoKey), findsOneWidget);
      expect(videoRect(tester), const Rect.fromLTWH(0, 0, 1280, 720));
      expect(_PlayerProbe.created, 1);
      await done(tester);
    });

    testWidgets(
      'tablet: the latency stays over the video and still opens the stats',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final native = FakeIvsNative()..install();
        addTearDown(native.uninstall);
        final streams = MockTwitchStreamService();
        when(
          () => streams.getUsherUrl(
            userLogin: any(named: 'userLogin'),
            forceFreshToken: any(named: 'forceFreshToken'),
          ),
        ).thenAnswer((_) async => 'https://usher.ttvnw.net/x.m3u8');
        when(() => streams.refusalFor(any())).thenReturn(null);
        when(() => streams.usherRefusal(any())).thenAnswer((_) async => null);
        when(
          () => api.getStream(userLogin: any(named: 'userLogin')),
        ).thenAnswer(
          (_) async => StreamTwitch.fromJson(
            (twitchStreamResponse['data']! as List).first
                as Map<String, dynamic>,
          ),
        );
        final auth = MockAuthStore();
        when(() => auth.twitchWebToken).thenReturn(null);
        when(() => auth.isLoggedIn).thenReturn(false);
        late IvsVideoStore ivs;
        await pump(
          tester,
          const Size(1600, 1066),
          player: (settings) => ivs = IvsVideoStore(
            userLogin: 'streamer',
            userId: '42',
            twitchApi: api,
            authStore: auth,
            settingsStore: settings,
            streamService: streams,
            recoveryPolicy: IvsRecoveryPolicy(backoff: const [Duration.zero]),
            liveStartDelay: Duration.zero,
          ),
        );
        for (var i = 0; i < 5 && ivs.streamInfo == null; i++) {
          await tester.pump(const Duration(milliseconds: 10));
        }
        expect(ivs.streamInfo, isNotNull);

        await doubleTap(tester);
        expect(find.byKey(_infoKey), findsNothing);
        expect(videoRect(tester), const Rect.fromLTWH(0, 0, 1280, 1066));

        // Shown with the controls: the double tap's taps never toggled them.
        if (!ivs.overlayVisible) {
          ivs.handleVideoTap();
          await tester.pump();
        }
        final pill = tester.getRect(find.byType(LatencyPill));
        // Top right of the video, left of the chat, never in it.
        expect(videoRect(tester).contains(pill.topLeft), isTrue);
        expect(videoRect(tester).contains(pill.bottomRight), isTrue);
        expect(pill.overlaps(chatRect(tester)), isFalse);
        expect(pill.right, closeTo(1280, 24));
        expect(pill.top, lessThan(40));

        expect(ivs.statsVisible, isFalse);
        expect(find.byType(IvsStatsPanel), findsNothing);
        await tester.tap(find.byType(LatencyPill));
        await tester.pump();
        expect(ivs.statsVisible, isTrue);
        expect(find.byType(IvsStatsPanel), findsOneWidget);
        await tester.tap(find.byType(LatencyPill));
        await tester.pump();
        expect(ivs.statsVisible, isFalse);
        ivs.dispose();
        await done(tester);
      },
    );

    testWidgets('phone: the side column it always had', (tester) async {
      final (cycle, settings) = await pump(tester, const Size(800, 360));
      await doubleTap(tester);
      expect(settings.fullScreen, isFalse);
      expect(find.byKey(_infoKey), findsNothing);
      expect(videoRect(tester), const Rect.fromLTWH(0, 0, 640, 360));
      expect(chatRect(tester), const Rect.fromLTWH(640, 0, 160, 360));
      expect(_PlayerProbe.created, 1);
      await done(tester);
    });
  });
}
