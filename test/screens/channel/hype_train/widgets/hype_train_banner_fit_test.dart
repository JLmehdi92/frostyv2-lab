import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/apis/twitch_hype_train_service.dart';
import 'package:onset/models/hype_train.dart';
import 'package:onset/screens/channel/hype_train/widgets/hype_train_slot.dart';

import '../../../../helpers/l10n.dart';
import '../hype_train_test_data.dart';
import 'hype_train_widget_harness.dart';

/// Every banner shows all its words, in English and in French, at phone
/// widths and in landscape, at both text scales: its two-line subtitles
/// are never cut in half (the banner grows), and a train's name never
/// loses its variant to an ellipsis (it shrinks, then wraps).
void main() {
  const treasure = HtTreasure(
    discountPercentage: 50,
    threshold: 3,
    status: HtUnlockStatus.none,
  );
  final community = HtCommunity.parse(const {
    'rewardLevelThreshold': 5,
    'nextRewardAmount': 20,
    'currentRewardAmount': 30,
  });
  final shared = HtShared(
    id: 's',
    channels: [
      for (final id in ['alice', 'bob'])
        HtSharedChannel(user: user(id), progress: progress(total: 50)),
    ],
  );
  const five = Duration(minutes: 5);
  final trains = <String, HypeTrainExecution Function()>{
    'regular': () => liveTrain(level: 2, expiresIn: five),
    'treasure locked': () =>
        liveTrain(level: 2, treasure: treasure, expiresIn: five),
    'treasure unlocked': () =>
        liveTrain(level: 4, treasure: treasure, expiresIn: five),
    'community locked': () =>
        liveTrain(level: 2, community: community, expiresIn: five),
    'community unlocked': () =>
        liveTrain(level: 6, community: community, expiresIn: five),
    'golden Kappa': () =>
        liveTrain(level: 2, variant: HtVariant.goldenKappa, expiresIn: five),
    'shared golden Kappa': () => liveTrain(
      level: 2,
      variant: HtVariant.goldenKappa,
      expiresIn: five,
      shared: shared,
    ),
    'shared community': () => liveTrain(
      level: 2,
      community: community,
      expiresIn: five,
      shared: shared,
    ),
  };

  for (final locale in [en, fr]) {
    for (final (name, size, compact) in const [
      ('360x640', Size(360, 640), false),
      ('390x844', Size(390, 844), false),
      ('844x390', Size(844, 390), true),
    ]) {
      for (final scale in frenchTextScales) {
        testWidgets('${locale.languageCode} $name ×$scale: every word shows', (
          tester,
        ) async {
          for (final MapEntry(key: train, value: build) in trains.entries) {
            final h = HtHarness(
              snapshot: HtOngoingSnapshot(
                build(),
                fetchedAt: DateTime.utc(2026),
              ),
            );
            await pumpLocalized(
              tester,
              Scaffold(
                body: Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: compact ? 360 : size.width - 16,
                    child: HypeTrainSlot(
                      store: h.store,
                      compact: compact,
                      onLearnMore: () {},
                    ),
                  ),
                ),
              ),
              locale: locale,
              size: size,
              textScale: scale,
            );
            await tester.pump();
            await tester.pump(const Duration(seconds: 30));
            final where = '$train, ${locale.languageCode} $name ×$scale';
            expect(tester.takeException(), isNull, reason: where);
            expect(clippedTexts(tester), isEmpty, reason: where);
            final title = find.byKey(const ValueKey('ht-title'));
            if (title.evaluate().isNotEmpty) {
              final paragraph = tester.renderObject<RenderParagraph>(
                find
                    .descendant(of: title, matching: find.byType(RichText))
                    .first,
              );
              expect(paragraph.didExceedMaxLines, isFalse, reason: where);
            }
            await h.close(tester);
          }
        });
      }
    }
  }
}
