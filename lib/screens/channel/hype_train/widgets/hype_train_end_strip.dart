import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/models/hype_train.dart';
import 'package:onset/screens/channel/hype_train/stores/hype_train_store.dart';
import 'package:onset/screens/channel/hype_train/widgets/hype_train_banner.dart';
import 'package:onset/screens/channel/hype_train/widgets/hype_train_copy.dart';
import 'package:onset/screens/channel/hype_train/widgets/hype_train_palette.dart';
import 'package:onset/screens/channel/hype_train/widgets/hype_train_tokens.dart';
import 'package:onset/widgets/onset_cached_network_image.dart';

/// The 20 s after a train, like Twitch's rewards and expired layouts: 74 dp
/// in the train's style with a 3 dp bar draining along the bottom. A
/// completed train thanks its supporters, then (at 14.9 s) shows three of
/// the earned emotes; an expired one says it was missed, with the golden
/// Kappa at the end for a golden train.
class HypeTrainEndStrip extends StatelessWidget {
  const HypeTrainEndStrip({super.key, required this.store});

  final HypeTrainStore store;

  /// Twitch's golden Kappa emote.
  static const _goldenKappa = HtReward(type: HtRewardType.emote, id: '80393');

  /// The text gives way to the emotes at 14.9 s of the 20.
  static const _swapAt = 0.745;

  /// The text fades out, then the emotes fade in, 100 ms each.
  static const _swap = Duration(milliseconds: 200);

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 2.0,
      child: Observer(
        builder: (context) {
          final palette = htPaletteOf(context, store);
          final rewards = store.phase == HtPhase.rewards;
          final golden = store.train?.variant == HtVariant.goldenKappa;
          final emotes = (store.endSummary?.rewards ?? const <HtReward>[])
              .where((r) => r.emoteUrl != null)
              .take(3)
              .toList();
          final title = switch ((rewards, golden)) {
            (true, true) => HtCopy.goldenRewards,
            (true, false) => HtCopy.rewards,
            (false, true) => HtCopy.goldenExpired,
            (false, false) => HtCopy.expired,
          };
          final text = Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: rewards ? TextAlign.center : TextAlign.start,
            style: palette.textStyle(HtType.bodySmall),
          );
          final Widget content;
          if (rewards) {
            content = _RewardsContent(store: store, text: text, emotes: emotes);
          } else {
            content = Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(HtDims.margin),
                    child: text,
                  ),
                ),
                if (golden)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      end: HtDims.margin,
                    ),
                    child: OnsetCachedNetworkImage(
                      key: const ValueKey('ht-strip-golden'),
                      imageUrl: _goldenKappa.emoteUrl.toString(),
                      width: HtDims.iconLarge,
                      height: HtDims.iconLarge,
                    ),
                  ),
              ],
            );
          }
          return RepaintBoundary(
            child: Semantics(
              container: true,
              liveRegion: true,
              label: title,
              child: ExcludeSemantics(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(HtDims.radius),
                  child: DecoratedBox(
                    decoration: _background(palette),
                    child: SizedBox(
                      height: htBannerHeight(MediaQuery.textScalerOf(context)),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          content,
                          PositionedDirectional(
                            start: 0,
                            end: 0,
                            bottom: 0,
                            child: Observer(
                              // Ticks every 500 ms: only the bar rebuilds.
                              builder: (context) => LinearProgressIndicator(
                                key: const ValueKey('ht-strip-bar'),
                                minHeight: HtDims.bar,
                                value: 1 - store.stripFraction,
                                color: palette.fillColors?.last ?? palette.fill,
                                backgroundColor: Colors.transparent,
                              ),
                            ),
                          ),
                        ],
                      ),
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

  /// The style's background: its track, or the gradient covering it all.
  static BoxDecoration _background(HtPalette palette) => BoxDecoration(
    color: palette.fillCoversAll ? null : palette.track,
    gradient: palette.fillCoversAll
        ? LinearGradient(
            begin: AlignmentDirectional.centerStart,
            end: AlignmentDirectional.centerEnd,
            colors: palette.fillColors!,
          )
        : null,
  );
}

/// The thanks, giving way to the earned emotes at 14.9 s.
class _RewardsContent extends StatelessWidget {
  const _RewardsContent({
    required this.store,
    required this.text,
    required this.emotes,
  });

  final HypeTrainStore store;
  final Widget text;
  final List<HtReward> emotes;

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final swapped =
            emotes.isNotEmpty &&
            store.stripFraction >= HypeTrainEndStrip._swapAt;
        return AnimatedSwitcher(
          duration: store.reduceMotion
              ? Duration.zero
              : HypeTrainEndStrip._swap,
          // One after the other: out in the first half, in the second.
          switchInCurve: const Interval(0.5, 1),
          switchOutCurve: const Interval(0.5, 1),
          child: swapped
              ? Center(
                  key: const ValueKey('emotes'),
                  child: Row(
                    key: const ValueKey('ht-strip-emotes'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final emote in emotes)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: HtDims.margin,
                          ),
                          child: OnsetCachedNetworkImage(
                            imageUrl: emote.emoteUrl.toString(),
                            width: HtDims.icon,
                            height: HtDims.icon,
                          ),
                        ),
                    ],
                  ),
                )
              : Center(
                  key: const ValueKey('text'),
                  child: Padding(
                    padding: const EdgeInsets.all(HtDims.margin),
                    child: text,
                  ),
                ),
        );
      },
    );
  }
}
