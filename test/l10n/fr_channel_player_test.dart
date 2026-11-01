import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/ivs_stats.dart';
import 'package:onset/models/user.dart';
import 'package:onset/screens/channel/channel_info.dart';
import 'package:onset/screens/channel/chat/stores/chat_store.dart';
import 'package:onset/screens/channel/stores/channel_info_store.dart';
import 'package:onset/screens/channel/stores/create_clip_store.dart';
import 'package:onset/screens/channel/video/create_clip_sheet.dart';
import 'package:onset/screens/channel/video/ivs_player_config.dart';
import 'package:onset/screens/channel/video/ivs_stats_panel.dart';
import 'package:onset/screens/channel/video/latency_controller.dart';
import 'package:onset/screens/channel/video/latency_pill.dart';
import 'package:onset/screens/channel/video/latency_stats.dart';
import 'package:onset/screens/channel/video/stores/caption_store.dart';
import 'package:onset/screens/channel/video/stores/ivs_video_store.dart';
import 'package:onset/screens/channel/video/stream_info_bar.dart';
import 'package:onset/screens/channel/video/video_overlay.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:provider/provider.dart';

import '../helpers/fake_player.dart';
import '../helpers/l10n.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

class MockChatStore extends Mock implements ChatStore {}

class MockIvsVideoStore extends Mock implements IvsVideoStore {}

/// The live player and the channel around it in French: the controls over
/// the video, the quality and settings sheet, the stats panel, the latency
/// pill, the clip sheet, the channel's info under the video and on a
/// tablet, in every window and at both text scales, with no overflow and
/// no English.
void main() {
  final french = lookupAppLocalizations(fr);
  late MockTwitchApi api;
  late MockChatStore chat;

  setUp(() {
    api = MockTwitchApi();
    when(() => api.getUser(userLogin: any(named: 'userLogin'))).thenAnswer(
      (_) async => const UserTwitch('42', 'streamer', 'Streamer', ''),
    );
    chat = MockChatStore();
    when(() => chat.displayName).thenReturn('Streamer');
    when(() => chat.channelName).thenReturn('streamer');
    when(() => chat.isInSharedChatMode).thenReturn(false);
  });

  /// The video's size in [size]: the full window in landscape, 16:9 under
  /// the top in portrait.
  Size videoIn(Size size) =>
      size.width > size.height ? size : Size(size.width, size.width * 9 / 16);

  Widget overlay(Widget player, Size size) => Provider<TwitchApi>.value(
    value: api,
    child: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox.fromSize(
          size: videoIn(size),
          child: ColoredBox(color: Colors.black, child: player),
        ),
      ),
    ),
  );

  /// An IVS player as the overlay and its sheet read it.
  MockIvsVideoStore ivsPlayer(SettingsStore settings) {
    final ivs = MockIvsVideoStore();
    when(() => ivs.settingsStore).thenReturn(settings);
    when(() => ivs.streamInfo).thenReturn(fakeStream());
    when(() => ivs.offlineChannelInfo).thenReturn(null);
    when(() => ivs.paused).thenReturn(false);
    when(() => ivs.isInPipMode).thenReturn(false);
    when(() => ivs.overlayVisible).thenReturn(true);
    when(
      () => ivs.availableStreamQualities,
    ).thenReturn(['Auto', '1080p60', '720p60', 'audio_only']);
    when(() => ivs.streamQuality).thenReturn('Auto');
    when(ivs.updateStreamQualities).thenAnswer((_) async {});
    when(() => ivs.fillScreen).thenReturn(false);
    when(() => ivs.muted).thenReturn(false);
    when(() => ivs.volume).thenReturn(0.8);
    when(() => ivs.statsVisible).thenReturn(true);
    final captions = CaptionStore(
      settings: settings,
      invoke: (method, [args]) async {},
    );
    settings.showCaptions = true;
    captions.handleEvent({
      'type': 'textTracks',
      'list': [
        {'id': 'a', 'label': 'English CC'},
        {'id': 'b'},
      ],
    });
    when(() => ivs.captions).thenReturn(captions);
    return ivs;
  }

  for (final (sizeName, size) in frenchChannelScreenSizes) {
    for (final scale in frenchTextScales) {
      testWidgets('the controls over the video, live and offline, $sizeName, '
          'text ×$scale', (tester) async {
        final settings = SettingsStore.fromJson({});
        final players = <String, FakePlayer>{
          'live': FakePlayer(stream: fakeStream(), settings: settings),
          'offline': FakePlayer(
            offline: fakeOfflineChannel,
            settings: settings,
          ),
        };
        for (final MapEntry(key: name, value: player) in players.entries) {
          for (final fullScreen in [false, true]) {
            settings
              ..fullScreen = fullScreen
              ..fullScreenChatOverlay = fullScreen;
            await pumpLocalized(
              tester,
              overlay(
                VideoOverlay(
                  videoStore: player,
                  chatStore: chat,
                  settingsStore: settings,
                ),
                size,
              ),
              size: size,
              textScale: scale,
            );
            await tester.pump();
            await expectFrenchThroughout(
              tester,
              '$name, full screen $fullScreen, $sizeName, ×$scale',
            );
            await tester.pumpWidget(const SizedBox());
          }
        }
      });

      testWidgets('the quality and settings sheet, $sizeName, text ×$scale', (
        tester,
      ) async {
        final settings = SettingsStore.fromJson({});
        final ivs = ivsPlayer(settings);
        await pumpLocalized(
          tester,
          overlay(
            VideoOverlay(
              videoStore: ivs,
              chatStore: chat,
              settingsStore: settings,
            ),
            size,
          ),
          size: size,
          textScale: scale,
        );
        await tester.pump();
        await expectFrenchThroughout(tester, 'IVS controls');
        await tester.tap(find.byTooltip(french.livePlayerQualityAndSettings));
        await tester.pumpAndSettle();
        expect(
          find.text(french.livePlayerStreamQuality.toUpperCase()),
          findsOneWidget,
        );
        expect(find.text(french.livePlayerAudioOnly), findsOneWidget);
        expect(
          find.text(french.liveCaptionsTrack(number: 2), skipOffstage: false),
          findsOneWidget,
        );
        await expectFrenchThroughout(tester, 'settings sheet');
        await tester.pumpWidget(const SizedBox());
      });
    }
  }

  group('the stats panel', () {
    late MockIvsVideoStore store;

    setUp(() {
      store = MockIvsVideoStore();
      when(() => store.stats).thenReturn(
        IvsStats.fromEvent({
          'playbackRate': 1.05,
          'bufferedMs': 1700,
          'bitrate': 6200000,
          'bandwidth': 850000,
          'fps': 60,
          'droppedFrames': 3,
          'decodedFrames': 18000,
          'lowLatency': true,
          'qualityName': '1080p60',
        }),
      );
      when(() => store.latencySampler).thenReturn(
        LatencySampler()
          ..add(2100)
          ..add(2300),
      );
      when(() => store.latencyMs).thenReturn(2200);
      when(() => store.samplesVersion).thenReturn(0);
      when(() => store.streamQuality).thenReturn('Auto');
      when(() => store.playerConfig).thenReturn(
        const IvsPlayerConfig(
          catchUp: LiveCatchUpMode.speedUp,
          buffer: BufferProfile.ultra,
          autoLatency: true,
        ),
      );
      when(() => store.startupMs).thenReturn(900);
      when(() => store.rebufferCount).thenReturn(2);
      when(() => store.liveJumps).thenReturn(1);
      when(
        () => store.bufferFallbackUntil,
      ).thenReturn(DateTime(2026, 11, 1, 14, 5));
    });

    // What auto latency can be doing, each worded.
    final statuses = <AutoLatencyStatus?>[
      null,
      const AutoLatencyStatus(phase: AutoLatencyPhase.off, rate: 1),
      const AutoLatencyStatus(
        phase: AutoLatencyPhase.catchingUp,
        rate: 1.05,
        targetMs: 1300,
      ),
      const AutoLatencyStatus(
        phase: AutoLatencyPhase.settling,
        rate: 1,
        targetMs: 1800,
        calmLeftSeconds: 12,
      ),
      const AutoLatencyStatus(
        phase: AutoLatencyPhase.steady,
        rate: 1,
        targetMs: 1300,
      ),
      for (final reason in AutoLatencyReason.values)
        AutoLatencyStatus(
          phase: AutoLatencyPhase.held,
          rate: 1,
          targetMs: 1300,
          reason: reason,
          reasonRate: 1.05,
        ),
      for (final reason in AutoLatencyReason.values)
        AutoLatencyStatus(
          phase: AutoLatencyPhase.stopped,
          rate: 1,
          reason: reason,
          reasonRate: 1.03,
        ),
      const AutoLatencyStatus(
        phase: AutoLatencyPhase.draining,
        rate: 1.03,
        targetMs: 2800,
        reason: AutoLatencyReason.stallsAfterCatchUp,
      ),
    ];

    for (final (sizeName, size) in frenchChannelScreenSizes) {
      for (final scale in frenchTextScales) {
        testWidgets('every row, $sizeName, text ×$scale', (tester) async {
          for (final status in statuses) {
            when(() => store.autoLatencyStatus).thenReturn(status);
            await pumpLocalized(
              tester,
              Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: math.min(size.width, 420),
                    child: IvsStatsPanel(store: store),
                  ),
                ),
              ),
              size: size,
              textScale: scale,
            );
            await expectFrenchThroughout(tester, '$status');
          }
          expect(find.textContaining(french.latencyStatsLatency), findsWidgets);
        });
      }
    }

    test('French numbers: decimal commas, units after a space', () async {
      await useLocale(fr);
      expect(displayLatency('2.3s', french), '2,3 s');
      expect(displayLatency('2s', french), '2 s');
      expect(displayLatency('—', french), '—');
      expect(formatBitrate(6200000, french), '6,2 Mbit/s');
      expect(formatBitrate(850000, french), '850 kbit/s');
      expect(
        describeAutoLatency(
          const AutoLatencyStatus(
            phase: AutoLatencyPhase.catchingUp,
            rate: 1.05,
            targetMs: 1300,
          ),
          french,
        ),
        'rattrapage 1,05× · cible 1,3 s',
      );
      expect(
        describeAutoLatency(
          const AutoLatencyStatus(
            phase: AutoLatencyPhase.stopped,
            rate: 1,
            reason: AutoLatencyReason.stuckFast,
            reasonRate: 1.05,
          ),
          french,
        ),
        'arrêtée : le lecteur est resté à 1,05×',
      );
      // Every reason has its own words.
      final reasons = {
        for (final reason in AutoLatencyReason.values)
          autoLatencyReasonText(reason, french, rate: 1.05),
      };
      expect(reasons, hasLength(AutoLatencyReason.values.length));
    });

    test('English reads as the panel always did', () async {
      final english = L10n.english;
      await useLocale(en);
      expect(
        describeAutoLatency(
          const AutoLatencyStatus(
            phase: AutoLatencyPhase.stopped,
            rate: 1,
            reason: AutoLatencyReason.stuckFast,
            reasonRate: 1.05,
          ),
          english,
        ),
        'stopped: the player stayed at 1.05x',
      );
      expect(
        describeAutoLatency(
          const AutoLatencyStatus(
            phase: AutoLatencyPhase.stopped,
            rate: 1,
            reason: AutoLatencyReason.notBackToNormal,
          ),
          english,
        ),
        'stopped: the player did not return to 1.0x',
      );
      expect(
        describeAutoLatency(
          const AutoLatencyStatus(
            phase: AutoLatencyPhase.held,
            rate: 1,
            targetMs: 1300,
          ),
          english,
        ),
        'held: held · target 1.3s',
      );
      expect(
        describeAutoLatency(
          const AutoLatencyStatus(phase: AutoLatencyPhase.stopped, rate: 1),
          english,
        ),
        'stopped: gave up',
      );
      expect(displayLatency('2.3s', english), '2.3s');
    });
  });

  testWidgets('the latency pill, and its tooltip', (tester) async {
    for (final (sizeName, size) in frenchChannelScreenSizes) {
      await pumpLocalized(
        tester,
        Scaffold(
          body: Center(child: LatencyPill(store: FakePlayer())),
        ),
        size: size,
        textScale: 1.3,
      );
      expect(find.text('2,1 s'), findsOneWidget);
      expect(
        find.bySemanticsLabel(french.latencyPillSemantics(latency: '2,1 s')),
        findsOneWidget,
      );
      await expectFrenchThroughout(tester, 'latency pill, $sizeName');
    }
  });

  group('the clip sheet', () {
    /// The sheet once [store] reached its state.
    Future<void> pumpSheet(
      WidgetTester tester,
      CreateClipStore store,
      Size size,
      double scale,
    ) async {
      await pumpLocalized(
        tester,
        Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              width: math.min(size.width, 600),
              child: CreateClipSheet(
                store: store,
                onLogIn: () {},
                onOpenEditor: (_) {},
                onShare: (_) {},
              ),
            ),
          ),
        ),
        size: size,
        textScale: scale,
      );
    }

    for (final (sizeName, size) in frenchChannelScreenSizes) {
      for (final scale in frenchTextScales) {
        testWidgets('each state, $sizeName, text ×$scale', (tester) async {
          // Signed out, then each answer Twitch can give.
          final cases = <String, (bool, Object Function()?)>{
            'signed out': (false, null),
            'missing scope': (true, null),
            'rendering': (true, null),
            'ready': (true, null),
            for (final failure in ClipCreateFailure.values)
              if (failure != ClipCreateFailure.missingScope)
                'failed, ${failure.name}': (
                  true,
                  () => ClipCreateException(failure),
                ),
          };
          for (final MapEntry(key: name, value: (loggedIn, error))
              in cases.entries) {
            when(() => api.getTokenScopes()).thenAnswer(
              (_) async => name == 'missing scope' ? {} : {'clips:edit'},
            );
            final created = Completer<ClipCreation>();
            when(() => api.createClip(broadcasterId: '42')).thenAnswer((_) {
              if (error != null) throw error();
              return name == 'rendering'
                  ? created.future
                  : Future.value(
                      ClipCreation(
                        id: 'Slug-abc',
                        editUrl: Uri.parse(
                          'https://www.twitch.tv/streamer/clip/Slug-abc',
                        ),
                      ),
                    );
            });
            when(
              () => api.getCreatedClip('Slug-abc'),
            ).thenAnswer((_) async => const CreatedClip(id: 'Slug-abc'));
            final store = CreateClipStore(
              twitchApi: api,
              broadcasterId: '42',
              isLoggedIn: () => loggedIn,
              pollInterval: const Duration(milliseconds: 100),
            );
            await pumpSheet(tester, store, size, scale);
            unawaited(store.start());
            for (var i = 0; i < 8; i++) {
              await tester.pump(const Duration(milliseconds: 150));
            }
            await expectFrenchThroughout(tester, '$name, $sizeName, ×$scale');
            await tester.pumpWidget(const SizedBox());
            store.dispose();
            // Twitch answers after the sheet closed: nothing is shown.
            if (!created.isCompleted) {
              created.complete(const ClipCreation(id: 'late'));
              await tester.pump();
            }
          }
        });
      }
    }
  });

  group('the channel around the video', () {
    late ChannelInfoStore info;

    setUp(() {
      info = ChannelInfoStore(channelId: '42', api: api, viewerId: () => '7');
    });

    tearDown(() => info.dispose());

    Widget providers(Widget child) => MultiProvider(
      providers: [
        Provider<TwitchApi>.value(value: api),
        Provider<SettingsStore>.value(value: SettingsStore.fromJson({})),
      ],
      child: child,
    );

    for (final (sizeName, size) in frenchChannelScreenSizes) {
      for (final scale in frenchTextScales) {
        testWidgets('the info row, the tablet panel and the chat header, '
            '$sizeName, text ×$scale', (tester) async {
          final settings = SettingsStore.fromJson({});
          for (final live in [true, false]) {
            final player = live
                ? FakePlayer(stream: fakeStream())
                : FakePlayer(offline: fakeOfflineChannel);
            await pumpLocalized(
              tester,
              providers(
                Scaffold(
                  body: ListView(
                    children: [
                      ChannelInfoRow(
                        player: player,
                        login: 'streamer',
                        displayName: 'Streamer',
                        info: info,
                        viewerLogin: () => 'viewer',
                        onOpenProfile: () {},
                        large: size.shortestSide >= 600,
                      ),
                      SizedBox(
                        height: 380,
                        child: TabletChannelPanel(
                          player: player,
                          login: 'streamer',
                          displayName: 'Streamer',
                          info: info,
                          viewerLogin: () => 'viewer',
                          onOpenChannel: (_) {},
                          watchStreak: () => 12,
                        ),
                      ),
                      TabletChatHeader(settings: settings, onMore: () {}),
                      StreamInfoBar(
                        displayName: 'Streamer',
                        isOffline: !live,
                        streamInfo: live ? fakeStream() : null,
                        offlineChannelInfo: live ? null : fakeOfflineChannel,
                        onTapChannel: () {},
                      ),
                    ],
                  ),
                ),
              ),
              size: size,
              textScale: scale,
            );
            info.alsoLive.value = [
              fakeStream(userId: '1', login: 'splinter', name: 'Splinter'),
            ];
            await tester.pump();
            for (final delay in [true, false]) {
              settings
                ..autoSyncChatDelay = delay
                ..chatDelay = 3;
              await tester.pump();
              await expectFrenchThroughout(
                tester,
                'live $live, synced $delay, $sizeName, ×$scale',
              );
            }
            info.following.value = true;
            await tester.pump();
            await expectFrenchThroughout(tester, 'following, $sizeName');
            info.following.value = false;
            await tester.pumpWidget(const SizedBox());
          }
        });
      }
    }

    test('the short uptime, in French', () {
      expect(
        shortUptime(const Duration(hours: 3, minutes: 12), french),
        '3 h 12',
      );
      expect(shortUptime(const Duration(minutes: 45), french), '45 min');
    });
  });
}
