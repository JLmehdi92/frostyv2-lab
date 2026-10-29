import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/models/hype_train.dart';
import 'package:onset/screens/channel/hype_train/hype_train_sequence.dart';
import 'package:onset/screens/channel/hype_train/stores/hype_train_store.dart';
import 'package:onset/screens/channel/hype_train/widgets/hype_train_banner.dart';
import 'package:onset/screens/channel/hype_train/widgets/hype_train_copy.dart';
import 'package:onset/screens/channel/hype_train/widgets/hype_train_pill_shell.dart';
import 'package:onset/screens/channel/hype_train/widgets/hype_train_tokens.dart';

/// The train over the video when landscape chat is hidden, as Twitch's
/// landscape pill: "Approaching" with its check circles, the level and
/// percentage over a sweeping fill, "Level n Complete!", then the end.
/// Tap for details.
/// While mounted it presents the store in compact form.
class HypeTrainVideoPill extends StatefulWidget {
  const HypeTrainVideoPill({
    super.key,
    required this.store,
    required this.onTap,
  });

  final HypeTrainStore store;
  final VoidCallback onTap;

  @override
  State<HypeTrainVideoPill> createState() => _HypeTrainVideoPillState();
}

class _HypeTrainVideoPillState extends State<HypeTrainVideoPill> {
  @override
  void initState() {
    super.initState();
    widget.store.attachPresenter();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.store.updatePresentation(
      compact: true,
      reduceMotion: MediaQuery.disableAnimationsOf(context),
    );
  }

  @override
  void dispose() {
    widget.store.detachPresenter();
    super.dispose();
  }

  String? _text(HypeTrainStore store) {
    switch (store.phase) {
      case HtPhase.hidden:
        return null;
      case HtPhase.approaching:
        return HtCopy.approachingShort;
      case HtPhase.ongoing || HtPhase.ending:
        if (store.step case HtStep(
          kind: HtStepKind.levelComplete,
          :final data,
        )) {
          return HtCopy.levelComplete(data['level'] as int? ?? store.level);
        }
        return null;
      case HtPhase.rewards:
        return HtCopy.completed(
          store.train?.variant ?? HtVariant.regular,
          shared: store.train?.shared != null,
        );
      case HtPhase.expired:
        return HtCopy.expired;
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Observer(
        builder: (context) {
          if (store.phase == HtPhase.hidden) return const SizedBox.shrink();
          final palette = htPaletteOf(context, store);
          final text = _text(store);
          final label = store.semanticsSummary.isNotEmpty
              ? store.semanticsSummary
              : (text ?? HtCopy.title);
          final Widget content;
          final double fraction;
          switch (store.phase) {
            case HtPhase.approaching:
              fraction = store.approachingCompleted
                  ? 1
                  : store.approachingFraction;
              content = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.train_rounded),
                  const SizedBox(width: HtDims.marginHalf),
                  Text(text ?? HtCopy.approachingShort),
                  if (store.approaching case final approaching?)
                    HtCheckCircles(
                      filled: htFilledChecks(
                        approaching,
                        store.approachingEventsLeft,
                        htCheckCircleCount(approaching),
                      ),
                      count: htCheckCircleCount(approaching),
                    ),
                ],
              );
            case HtPhase.ongoing || HtPhase.ending:
              fraction = text != null ? 1 : store.shownPercent / 100;
              content = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(palette.icon),
                  const SizedBox(width: HtDims.marginHalf),
                  if (text != null)
                    Text(text)
                  else ...[
                    Text(HtCopy.level(store.shownLevel)),
                    const SizedBox(width: HtDims.margin),
                    Text(HtCopy.percent(store.shownPercent)),
                  ],
                ],
              );
            case HtPhase.hidden || HtPhase.rewards || HtPhase.expired:
              fraction = 1 - store.stripFraction;
              content = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(palette.icon),
                  const SizedBox(width: HtDims.marginHalf),
                  Text(text ?? HtCopy.title),
                ],
              );
          }
          return HtPillShell(
            pillKey: const ValueKey('ht-video-pill'),
            targetKey: const ValueKey('ht-video-pill-target'),
            fraction: fraction,
            fillColors: palette.pillFillColors,
            label: label,
            hint: HtCopy.detailsHint,
            onTap: widget.onTap,
            child: content,
          );
        },
      ),
    );
  }
}
