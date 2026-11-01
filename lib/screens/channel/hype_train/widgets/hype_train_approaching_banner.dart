import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/screens/channel/hype_train/hype_train_timings.dart';
import 'package:onset/screens/channel/hype_train/stores/hype_train_store.dart';
import 'package:onset/screens/channel/hype_train/widgets/hype_train_copy.dart';
import 'package:onset/screens/channel/hype_train/widgets/hype_train_palette.dart';
import 'package:onset/screens/channel/hype_train/widgets/hype_train_pill_shell.dart';
import 'package:onset/screens/channel/hype_train/widgets/hype_train_tokens.dart';

/// A train is about to start, laid out like Twitch's approaching banner:
/// the title over the subtitle on the float card, the events pill (train
/// icon and check circles, green) at the end,
/// and the time window running out along a green 3 dp bar at the bottom.
class HypeTrainApproachingBanner extends StatelessWidget {
  const HypeTrainApproachingBanner({
    super.key,
    required this.store,
    this.onTap,
    this.compact = false,
  });

  final HypeTrainStore store;

  /// Instead of expanding the details below (landscape opens a sheet).
  final VoidCallback? onTap;

  /// Landscape: no subtitle, its natural height.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: compact ? 1.3 : 2.0,
      child: Observer(
        builder: (context) {
          final approaching = store.approaching;
          if (approaching == null) return const SizedBox.shrink();
          final palette = HtPalette.approaching(Theme.of(context).colorScheme);
          final title = HtCopy.of(
            context,
          ).approachingTitle(approaching.variant);
          final subtitle = store.approachingNMore
              ? HtCopy.of(context).approachingMore(store.approachingEventsLeft)
              : HtCopy.of(context).approachingSubtitle(approaching.variant);
          final titleText = Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              HtDims.margin,
              compact ? HtDims.margin : 12,
              HtDims.margin,
              compact ? HtDims.margin : 0,
            ),
            child: Text(
              title,
              maxLines: compact ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              style: palette.textStyle(HtType.titleDefault),
            ),
          );
          final text = compact
              ? titleText
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(child: titleText),
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          HtDims.margin,
                          HtDims.marginQuarter,
                          HtDims.marginHalf,
                          12,
                        ),
                        child: Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: palette.textStyle(HtType.bodySmall),
                        ),
                      ),
                    ),
                  ],
                );
          return RepaintBoundary(
            child: Semantics(
              container: true,
              liveRegion: true,
              button: true,
              onTap: onTap ?? store.toggleExpanded,
              hint: HtCopy.of(context).detailsHint,
              label: '$title. $subtitle',
              child: ExcludeSemantics(
                child: Material(
                  color: palette.track,
                  borderRadius: BorderRadius.circular(HtDims.radius),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onTap ?? store.toggleExpanded,
                    child: SizedBox(
                      height: compact
                          ? null
                          : htBannerHeight(MediaQuery.textScalerOf(context)),
                      child: Stack(
                        fit: StackFit.passthrough,
                        children: [
                          Row(
                            children: [
                              // Twitch keeps room for it; it shows with the
                              // details open.
                              AnimatedOpacity(
                                opacity: store.expanded ? 1 : 0,
                                duration: store.reduceMotion
                                    ? Duration.zero
                                    : HtTimings.extraShort,
                                child: SizedBox(
                                  width: HtDims.marginHalf,
                                  height: compact
                                      ? HtDims.icon
                                      : double.infinity,
                                  child: const ColoredBox(
                                    key: ValueKey('ht-approaching-side'),
                                    color: HtGreen.base,
                                  ),
                                ),
                              ),
                              Expanded(child: text),
                              Padding(
                                padding: const EdgeInsetsDirectional.only(
                                  end: HtDims.margin,
                                ),
                                child: _EventsPill(
                                  store: store,
                                  color: palette.checkPill,
                                  circles: htCheckCircleCount(approaching),
                                ),
                              ),
                            ],
                          ),
                          PositionedDirectional(
                            start: 0,
                            end: 0,
                            bottom: 0,
                            child: Observer(
                              // Ticks every 500 ms: only the bar rebuilds.
                              builder: (context) => LinearProgressIndicator(
                                key: const ValueKey('ht-approaching-bar'),
                                minHeight: HtDims.bar,
                                value: store.approachingCompleted
                                    ? 1
                                    : store.approachingFraction,
                                color: palette.fill,
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
}

/// The train icon and the check circles on a pill of [color]: filled for
/// the events already in, rings for the rest.
class _EventsPill extends StatelessWidget {
  const _EventsPill({
    required this.store,
    required this.color,
    required this.circles,
  });

  final HypeTrainStore store;
  final Color color;
  final int circles;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: DecoratedBox(
        key: const ValueKey('ht-events-pill'),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(HtDims.pillRadius),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            HtDims.margin,
            HtDims.margin,
            HtDims.margin,
            HtDims.margin,
          ),
          child: Observer(
            builder: (context) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.train_rounded, size: 20, color: Colors.white),
                HtCheckCircles(
                  filled: switch (store.approaching) {
                    final approaching? => htFilledChecks(
                      approaching,
                      store.approachingEventsLeft,
                      circles,
                    ),
                    null => 0,
                  },
                  count: circles,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
