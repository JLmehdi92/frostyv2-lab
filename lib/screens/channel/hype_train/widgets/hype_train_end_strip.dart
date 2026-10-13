import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/models/hype_train.dart';
import 'package:frosty/screens/channel/hype_train/stores/hype_train_store.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_banner.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_copy.dart';
import 'package:frosty/widgets/frosty_cached_network_image.dart';

/// The 20 s after a train: its earned emotes (completed) or a plain
/// "ended" line (expired), with a bar draining until it disappears.
class HypeTrainEndStrip extends StatelessWidget {
  const HypeTrainEndStrip({super.key, required this.store});

  final HypeTrainStore store;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Observer(
        builder: (context) {
          final palette = htPaletteOf(context, store);
          final on = palette.onBackground;
          final textTheme = Theme.of(context).textTheme;
          final rewards = store.phase == HtPhase.rewards;
          final golden = store.train?.variant == HtVariant.goldenKappa;
          final emotes = (store.endSummary?.rewards ?? const <HtReward>[])
              .where((r) => r.emoteUrl != null)
              .take(3)
              .toList();
          final title = rewards ? HtCopy.rewardsOnTheWay : HtCopy.ended;
          return RepaintBoundary(
            child: Semantics(
              container: true,
              liveRegion: true,
              label: [
                title,
                if (rewards && golden) HtCopy.goldenRewards,
              ].join('. '),
              child: ExcludeSemantics(
                child: Material(
                  color: palette.background,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              rewards
                                  ? Icons.card_giftcard_rounded
                                  : Icons.train_rounded,
                              size: 20,
                              color: palette.iconColor,
                            ),
                            const SizedBox(width: 8),
                            if (emotes.isNotEmpty)
                              Row(
                                key: const ValueKey('ht-strip-emotes'),
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (final emote in emotes)
                                    Padding(
                                      padding: const EdgeInsetsDirectional.only(
                                        end: 4,
                                      ),
                                      child: FrostyCachedNetworkImage(
                                        imageUrl: emote.emoteUrl.toString(),
                                        width: 24,
                                        height: 24,
                                      ),
                                    ),
                                ],
                              ),
                            if (emotes.isNotEmpty) const SizedBox(width: 4),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: on,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (rewards && golden)
                                    Text(
                                      HtCopy.goldenRewards,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: textTheme.bodySmall?.copyWith(
                                        color: on.withValues(alpha: 0.8),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: Observer(
                            // Ticks every 500 ms: only the bar rebuilds.
                            builder: (context) => LinearProgressIndicator(
                              key: const ValueKey('ht-strip-bar'),
                              minHeight: 3,
                              value: 1 - store.stripFraction,
                              color: on.withValues(alpha: 0.6),
                              backgroundColor: palette.track,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
