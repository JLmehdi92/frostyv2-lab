import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/celebration.dart';
import 'package:onset/models/community_highlight_event.dart';
import 'package:onset/models/community_highlights.dart';
import 'package:onset/models/raid_arrival.dart';
import 'package:onset/screens/channel/celebrations/onset_rocket.dart';
import 'package:onset/screens/channel/celebrations/subtle_celebrations.dart';
import 'package:onset/screens/channel/chat/gift_bomb_tracker.dart';
import 'package:onset/screens/channel/chat/incoming_raid.dart';
import 'package:onset/screens/channel/community_highlights/highlight_reducers.dart';
import 'package:onset/screens/channel/community_highlights/widgets/gift_bomb_pin.dart';
import 'package:onset/screens/channel/community_highlights/widgets/highlight_cards.dart';
import 'package:onset/screens/channel/community_highlights/widgets/highlight_slot.dart';
import 'package:onset/screens/channel/community_highlights/widgets/incoming_raid_pin.dart';
import 'package:onset/screens/channel/community_highlights/widgets/raid_card.dart';
import 'package:onset/screens/channel/community_highlights/widgets/raid_heading_overlay.dart';

import '../helpers/community_highlights_harness.dart';
import '../helpers/l10n.dart';

/// The community highlights and celebrations in French: every card in
/// each of its states, the pager and its pills, the raids and the gift
/// subs, in every window and at both text scales, with no overflow and no
/// English.
void main() {
  final french = lookupAppLocalizations(fr);
  final start = DateTime.utc(2026, 10, 13, 20);
  var now = start;

  setUpAll(() => debugSetRocketArt(File(kRocketAsset).readAsStringSync()));
  tearDownAll(() => debugSetRocketArt(null));
  setUp(() => now = start);

  Poll poll(PollStatus status) => Poll(
    id: 'p',
    title: 'Quel jeu ensuite ?',
    status: status,
    duration: const Duration(seconds: 60),
    startedAt: start,
    totalVotes: 1230,
    totalVoters: 1230,
    choices: const [
      PollChoice(id: 'a', title: 'Outlast 2', votes: 820, voters: 820),
      PollChoice(id: 'b', title: 'Elden Ring', votes: 410, voters: 410),
    ],
  );

  Prediction prediction(PredictionStatus status, {String? winner}) =>
      Prediction(
        id: 'e',
        title: 'Top 10 ?',
        status: status,
        createdAt: start,
        window: const Duration(seconds: 120),
        winningOutcomeId: winner,
        outcomes: const [
          PredictionOutcome(
            id: 'yes',
            title: 'Oui',
            color: PredictionColor.blue,
            points: 12000,
            users: 1,
            topPredictors: [TopPredictor(name: 'Big', points: 200)],
          ),
          PredictionOutcome(
            id: 'no',
            title: 'Non',
            color: PredictionColor.pink,
            points: 1,
            users: 240,
          ),
        ],
      );

  final pin = PinnedChatMessage(
    id: 'pin',
    senderLogin: 'mod',
    senderDisplayName: 'Mod',
    text: 'Les règles du chat',
    fragments: const [],
    badges: const [],
    pinnedBy: 'Streamer',
  );

  RaidState raid({bool gone = false, bool cancelled = false}) => RaidState(
    OutgoingRaid(
      id: 'r',
      sourceId: '1',
      targetId: '2',
      targetLogin: 'friend',
      targetDisplayName: 'Friend',
      viewerCount: 1204,
      createdAt: start,
    ),
    gone: gone,
    cancelled: cancelled,
  );

  HighlightCardContext card({bool expanded = true}) => HighlightCardContext(
    expanded: expanded,
    onToggle: () {},
    onDismiss: () {},
    now: () => now,
    onTakePart: () {},
  );

  // Every card, in each of its states.
  final cards = <String, Widget Function()>{
    'poll, live': () => PollCard(poll: poll(PollStatus.active), card: card()),
    'poll, collapsed': () =>
        PollCard(poll: poll(PollStatus.active), card: card(expanded: false)),
    'poll, voting': () => PollCard(
      poll: poll(PollStatus.active),
      card: HighlightCardContext(
        expanded: true,
        onToggle: () {},
        now: () => now,
        onVote: (_) {},
      ),
    ),
    'poll, voted': () => PollCard(
      poll: poll(PollStatus.active),
      card: HighlightCardContext(
        expanded: true,
        onToggle: () {},
        now: () => now,
        onVote: (_) {},
        votedChoiceId: poll(PollStatus.active).choices.last.id,
      ),
    ),
    'poll, ended': () =>
        PollCard(poll: poll(PollStatus.completed), card: card()),
    'prediction, open': () => PredictionCard(
      prediction: prediction(PredictionStatus.active),
      card: card(),
    ),
    'prediction, locked': () => PredictionCard(
      prediction: prediction(PredictionStatus.locked),
      card: card(),
    ),
    'prediction, waiting': () => PredictionCard(
      prediction: prediction(PredictionStatus.resolvePending),
      card: card(),
    ),
    'prediction, resolved': () => PredictionCard(
      prediction: prediction(PredictionStatus.resolved, winner: 'yes'),
      card: card(),
    ),
    'prediction, canceled': () => PredictionCard(
      prediction: prediction(PredictionStatus.canceled),
      card: card(),
    ),
    'pinned': () => PinnedCard(pin: pin, card: card()),
    'pinned, timed': () => PinnedCard(
      pin: PinnedChatMessage(
        id: 'pin',
        senderLogin: 'mod',
        senderDisplayName: 'Mod',
        text: 'Les règles du chat',
        fragments: const [],
        badges: const [],
        endsAt: start.add(const Duration(minutes: 2)),
      ),
      card: card(),
    ),
    'raid, counting': () => RaidCard(
      raid: raid(),
      sourceName: 'Nisqyy',
      now: () => now,
      onWatch: () {},
      onStay: () {},
      onDismiss: () {},
    ),
    'raid, staying': () => RaidCard(
      raid: raid(),
      sourceName: 'Nisqyy',
      now: () => now,
      onWatch: () {},
      onStay: () {},
      onDismiss: () {},
      staying: true,
    ),
    'raid, leaving': () => RaidCard(
      raid: raid(),
      sourceName: 'Nisqyy',
      now: () => now,
      onWatch: () {},
      onStay: () {},
      leaving: true,
    ),
    'raid, gone': () => RaidCard(
      raid: raid(gone: true),
      sourceName: 'Nisqyy',
      now: () => now,
      onWatch: () {},
      onDismiss: () {},
    ),
    'raid, cancelled': () => RaidCard(
      raid: raid(cancelled: true),
      sourceName: 'Nisqyy',
      now: () => now,
      onWatch: () {},
    ),
    'gift subs, giving': () => GiftBombPin(
      banner: GiftBombBanner(
        bomb: const GiftBomb(
          key: 'bomb',
          gifterName: 'qqalex',
          isAnonymous: false,
          count: 5,
          tier: 'Tier 1',
          received: 3,
        ),
        startedAt: start,
        endsAt: start.add(const Duration(seconds: 30)),
      ),
      now: () => now,
      onDismiss: () {},
    ),
    'gift subs, one': () => GiftBombPin(
      banner: GiftBombBanner(
        bomb: const GiftBomb(
          key: 'bomb',
          gifterName: 'qqalex',
          isAnonymous: false,
          count: 1,
          tier: 'Tier 1',
        ),
        startedAt: start,
        endsAt: start.add(const Duration(seconds: 30)),
      ),
      now: () => now,
    ),
    'gift subs, done': () => GiftBombPin(
      banner: GiftBombBanner(
        bomb: const GiftBomb(
          key: 'bomb',
          gifterName: 'qqalex',
          isAnonymous: false,
          count: 5,
          tier: 'Tier 1',
          received: 5,
        ),
        startedAt: start,
        endsAt: start.add(const Duration(seconds: 30)),
      ),
      now: () => now,
      onDismiss: () {},
    ),
    'incoming raid': () => IncomingRaidPin(
      raid: const IncomingRaid(
        raiderName: 'Nisqyy',
        raiderLogin: 'nisqyy',
        viewers: 1204,
      ),
      onDismiss: () {},
    ),
    'incoming raid, one viewer': () => const IncomingRaidPin(
      raid: IncomingRaid(raiderName: 'Solo', viewers: 1),
    ),
  };

  /// [child] at the width the channel screen gives it: the chat's (a
  /// tablet's side chat in landscape).
  Widget atChatWidth(Widget child, Size size) => Scaffold(
    body: Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: size.width >= 1000 ? 400 : math.min(size.width, 700),
        child: child,
      ),
    ),
  );

  for (final (sizeName, size) in frenchScreenSizes) {
    for (final scale in frenchTextScales) {
      testWidgets('every card, $sizeName, text ×$scale', (tester) async {
        for (final MapEntry(key: name, value: build) in cards.entries) {
          await pumpLocalized(
            tester,
            atChatWidth(build(), size),
            size: size,
            textScale: scale,
          );
          // Its entrance and a second of its countdown.
          for (var i = 0; i < 5; i++) {
            await tester.pump(const Duration(milliseconds: 250));
          }
          await expectFrenchThroughout(tester, '$name, $sizeName, ×$scale');
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 2));
        }
      });
    }
  }

  testWidgets('the pager, its pills and the heading to a raid', (tester) async {
    for (final (sizeName, size) in frenchScreenSizes) {
      for (final compact in [false, true]) {
        final h = Harness()..create();
        await pumpLocalized(
          tester,
          atChatWidth(
            HighlightSlot(
              store: h.store,
              onWatchRaid: (_) {},
              compact: compact,
              onOpenDetails: () {},
            ),
            size,
          ),
          size: size,
          textScale: 1.3,
        );
        h.send(HighlightTopic.polls, pollPayload('POLL_CREATE'));
        await tester.pumpAndSettle();
        h.send(HighlightTopic.pinned, pinPayload('pin'));
        await tester.pumpAndSettle();
        final where = '$sizeName, compact $compact';
        await expectFrenchThroughout(tester, where);
        if (!compact) {
          expect(find.text('1 / 2'), findsOneWidget);
          // An expanded card keeps the slot: a new one shows its pill.
          h.store.toggleExpanded();
          await tester.pump();
          h.send(HighlightTopic.predictions, predictionPayload());
          await tester.pumpAndSettle();
          expect(
            find.text(french.highlightNew(kind: 'prediction')),
            findsOneWidget,
          );
          await expectFrenchThroughout(tester, '$where, new pill');
        }
        await tester.pumpWidget(const SizedBox());
        h.store.dispose();
      }

      await pumpLocalized(
        tester,
        Stack(
          children: [
            RaidHeadingOverlay(
              arrival: RaidArrival(
                fromName: 'Nisqyy',
                targetName: 'Splinter',
                viewers: 1204,
                at: start,
              ),
              leaving: true,
              onDone: () {},
            ),
          ],
        ),
        size: size,
        textScale: 1.3,
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      await expectFrenchThroughout(tester, 'heading to a raid, $sizeName');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    }
  });

  group('French words', () {
    test('counts agree, 0 and 1 singular', () {
      expect(french.raidViewers(count: 0), '0 spectateur');
      expect(french.raidViewers(count: 1204), '1 204 spectateurs');
      expect(
        french.raidWentAlong(count: 1, viewers: french.raidViewers(count: 1)),
        '1 spectateur l’a suivi',
      );
      expect(
        french.raidWentAlong(count: 5, viewers: french.raidViewers(count: 5)),
        '5 spectateurs l’ont suivi',
      );
      expect(french.highlightVotes(count: 1230), '1,23\u00a0k votes');
      expect(french.highlightPredictors(count: 1), '1 participant');
      expect(french.giftBombGifting(count: 1), 'offre 1 abonnement');
      expect(
        french.giftBombHandedOutSemantics(received: 1, count: 5),
        '1 sur 5 distribué',
      );
      expect(
        french.giftBombHandedOutSemantics(received: 3, count: 5),
        '3 sur 5 distribués',
      );
      expect(french.commonPercent(value: 62), '62 %');
    });

    test('a new highlight agrees with its kind', () {
      expect(french.highlightNew(kind: 'poll'), 'Nouveau sondage');
      expect(french.highlightNew(kind: 'prediction'), 'Nouvelle prédiction');
      expect(
        french.highlightNew(kind: 'giftBomb'),
        'Nouveaux abonnements offerts',
      );
    });

    test('a subtle celebration\'s chat line, for each effect', () {
      Celebration celebration(CelebrationEffect effect, {String? source}) =>
          Celebration(
            effect: effect,
            area: CelebrationArea.everywhere,
            intensity: CelebrationIntensity.cool,
            duration: const Duration(seconds: 2),
            source: source,
          );
      final lines = {
        for (final effect in CelebrationEffect.values)
          celebrationChatLine(celebration(effect), french),
      };
      expect(lines, hasLength(CelebrationEffect.values.length));
      expect(
        celebrationChatLine(celebration(CelebrationEffect.fireworks), french),
        'Célébration : Feu d’artifice',
      );
      expect(
        celebrationChatLine(
          celebration(CelebrationEffect.rain, source: 'system_gifting'),
          french,
        ),
        'Célébration des abonnements offerts : Pluie',
      );
    });
  });
}
