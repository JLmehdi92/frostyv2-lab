import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart' show ObservableList;
import 'package:mocktail/mocktail.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/cheermote.dart';
import 'package:onset/models/irc.dart';
import 'package:onset/models/vod.dart';
import 'package:onset/models/vod_comment.dart';
import 'package:onset/screens/channel/chat/stores/chat_assets_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/vod/player_media.dart';
import 'package:onset/screens/vod/stores/up_next_store.dart';
import 'package:onset/screens/vod/stores/vod_chat_replay_store.dart';
import 'package:onset/screens/vod/vod_comment_to_irc.dart';
import 'package:onset/screens/vod/vod_overlay.dart';
import 'package:onset/screens/vod/widgets/up_next_overlay.dart';
import 'package:onset/screens/vod/widgets/vod_chat_replay.dart';
import 'package:onset/screens/vod/widgets/vod_details_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_vod_controller.dart';
import '../helpers/l10n.dart';

class _MockReplayStore extends Mock implements VodChatReplayStore {}

class _MockChatAssetsStore extends Mock implements ChatAssetsStore {}

/// The VOD screens in French: the player's controls and its settings sheet,
/// a tablet's details panel and legend, the chat replay in each state (a
/// deleted viewer's name too), and the card of the video up next, at every
/// size and text scale, with no overflow, no English and no text cut off.
void main() {
  final french = lookupAppLocalizations(fr);

  final vod = Vod(
    id: '1000000001',
    title: 'Partie classée du matin',
    lengthSeconds: 3600,
    createdAt: DateTime.utc(2026, 10, 12),
    viewCount: 1234,
    ownerId: '42',
    ownerLogin: 'streamer',
    ownerDisplayName: 'Streamer',
    gameId: '33',
    gameName: 'Échecs',
    type: VodType.archive,
  );

  setUp(() => SharedPreferences.setMockInitialValues({}));

  _MockReplayStore replayStore(ReplayStatus status, List<IRCMessage> lines) {
    final store = _MockReplayStore();
    final assets = _MockChatAssetsStore();
    when(() => assets.cheermotes).thenReturn(Cheermotes.empty);
    when(() => assets.emoteToObject).thenReturn({});
    when(() => assets.twitchBadgesToObject).thenReturn({});
    when(() => assets.userToFFZBadges).thenReturn({});
    when(() => assets.userTo7TVBadges).thenReturn({});
    when(() => assets.userToBTTVBadges).thenReturn({});
    when(() => assets.ffzRoomInfo).thenReturn(null);
    when(() => store.assetsStore).thenReturn(assets);
    when(() => store.settings).thenReturn(SettingsStore.fromJson({}));
    when(() => store.messages).thenReturn(ObservableList.of(lines));
    when(() => store.autoScroll).thenReturn(true);
    when(() => store.scrollController).thenReturn(ScrollController());
    when(() => store.vod).thenReturn(vod);
    when(() => store.status).thenReturn(status);
    when(() => store.retry()).thenAnswer((_) async {});
    return store;
  }

  List<IRCMessage> replayLines() => [
    for (final (index, (login, name, text)) in const [
      ('viewer_one', 'Viewer_One', 'bonne chance pour la partie'),
      (null, null, 'message d’un compte supprimé'),
      ('fan', 'Fan', 'quel coup !'),
    ].indexed)
      vodCommentToIrcMessage(
        VodComment(
          id: 'c$index',
          offsetSeconds: 60 + index,
          fragments: [VodFragment(text: text)],
          badges: const [],
          commenterId: login == null ? null : '10$index',
          commenterLogin: login,
          commenterDisplayName: name,
          color: '#FF4500',
        ),
        channelId: '42',
        channelLogin: 'streamer',
        vodCreatedAt: vod.createdAt,
      ),
  ];

  for (final (sizeName, size) in frenchScreenSizes) {
    for (final scale in frenchTextScales) {
      final at = '$sizeName, text ×$scale';

      testWidgets('the player\'s controls and settings, $at', (tester) async {
        final controller = FakeVodController();
        await pumpLocalized(
          tester,
          Scaffold(
            body: Builder(
              builder: (context) => VodOverlay(
                controller: controller,
                media: PlayerMedia.vod(vod, context.l10n),
                settings: SettingsStore.fromJson({}),
                isLandscape: size.width > size.height,
              ),
            ),
          ),
          size: size,
          textScale: scale,
        );
        await tester.pump();
        await expectFrenchThroughout(tester, 'VOD controls, $at');
        controller.setPlaybackRate(1.25);
        await tester.pump();
        expect(
          find.text('1,25 ×'),
          findsWidgets,
          reason: 'the speed in French digits',
        );
        await tester.tap(find.byTooltip(french.playerSettings).first);
        await tester.pumpAndSettle();
        await expectFrenchThroughout(tester, 'VOD settings, $at');
        expect(find.text(french.vodCopyLinkAtTime), findsOneWidget);
      });

      testWidgets('a tablet\'s details panel, $at', (tester) async {
        final controller = FakeVodController();
        await pumpLocalized(
          tester,
          Scaffold(
            body: VodDetailsPanel(
              vod: vod,
              player: controller,
              settings: SettingsStore.fromJson({})
                ..vodAutoplay = VodAutoplay.wifiOnly,
              mutedSegments: const [MutedSegment(offset: 60, duration: 30)],
              upNext: true,
            ),
          ),
          size: size,
          textScale: scale,
        );
        await tester.pump();
        await expectFrenchThroughout(tester, 'VOD details, $at');
        expect(find.text(french.vodLegendMuted), findsOneWidget);
        expect(
          find.text(
            french.vodLegendUpNextWhen(autoplay: french.vodAutoplayWifiOnly),
          ),
          findsOneWidget,
        );
        controller.setPlaybackRate(1.5);
        await tester.pump();
        expect(find.text('Vitesse 1,5 ×'), findsOneWidget);
        await tester.tap(find.text(french.vodCopyLinkAtTime));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 750));
        expect(find.text(french.vodLinkCopied), findsOneWidget);
        await expectFrenchThroughout(tester, 'link copied, $at');
      });

      testWidgets('the chat replay in each state, $at', (tester) async {
        for (final (status, lines) in [
          (ReplayStatus.active, replayLines()),
          (ReplayStatus.active, <IRCMessage>[]),
          (ReplayStatus.loading, <IRCMessage>[]),
          (ReplayStatus.unavailable, <IRCMessage>[]),
          (ReplayStatus.notApplicable, <IRCMessage>[]),
        ]) {
          await pumpLocalized(
            tester,
            Scaffold(body: VodChatReplay(store: replayStore(status, lines))),
            size: size,
            textScale: scale,
          );
          await tester.pump();
          final where = 'chat replay, ${status.name} ${lines.length}, $at';
          await expectFrenchThroughout(
            tester,
            where,
            content: [for (final line in lines) ?line.message],
          );
          if (lines.isNotEmpty) {
            expect(
              find.textContaining(french.chatDeletedUser, findRichText: true),
              findsOneWidget,
              reason: where,
            );
            // The note about emotes.
            await tester.tap(find.byTooltip(french.vodReplayEmotesAbout));
            await tester.pump();
            await expectFrenchThroughout(tester, '$where, note');
            expect(find.text(french.vodReplayEmotesNote), findsOneWidget);
          }
          await tester.pumpWidget(const SizedBox.shrink());
        }
      });

      testWidgets('the video up next, $at', (tester) async {
        final next = Vod(
          id: '2',
          title: 'Une autre partie',
          lengthSeconds: 5400,
          createdAt: DateTime.utc(2026, 10, 2),
          viewCount: 1,
          ownerId: '43',
          ownerLogin: 'rival',
          ownerDisplayName: 'Rival',
          gameId: '33',
        );
        final store = UpNextStore(
          current: vod,
          channelVideos: () async => const [],
          similarVideos: (_) async => [next],
          savedPositions: () async => const {},
          autoplay: () => VodAutoplay.always,
          isMetered: () async => false,
          onPlay: (_) {},
        );
        addTearDown(store.dispose);
        await tester.runAsync(store.onEnded);
        await pumpLocalized(
          tester,
          Scaffold(
            body: Stack(children: [UpNextOverlay(store: store)]),
          ),
          size: size,
          textScale: scale,
        );
        await tester.pump(const Duration(milliseconds: 300));
        await expectFrenchThroughout(
          tester,
          'up next, $at',
          content: [next.title],
        );
        expect(find.text(french.vodUpNext.toUpperCase()), findsOneWidget);
        final similar = find.text(french.vodUpNextSimilar(channel: 'Rival'));
        expect(similar, findsOneWidget);
        // « Rival · Suggestion » keeps its last word.
        expect(
          tester.renderObject<RenderParagraph>(similar).didExceedMaxLines,
          isFalse,
          reason: at,
        );
        store.cancel();
      });
    }
  }
}
