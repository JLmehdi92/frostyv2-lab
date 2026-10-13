import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/screens/channel/hype_train/hype_train_sequence.dart';
import 'package:frosty/screens/channel/hype_train/stores/hype_train_store.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_banner.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_copy.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_palette.dart';

/// The train over the video when landscape chat is hidden: a small pill
/// (approaching, level and %, "level complete", ended). Tap for details.
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
        return 'Hype Train soon · ${store.approachingEventsLeft} to go';
      case HtPhase.ongoing || HtPhase.ending:
        if (store.step case HtStep(
          kind: HtStepKind.levelComplete,
          :final data,
        )) {
          return HtCopy.levelComplete(data['level'] as int? ?? store.level);
        }
        return null;
      case HtPhase.rewards:
        return 'Hype Train complete!';
      case HtPhase.expired:
        return HtCopy.ended;
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return MediaQuery.withNoTextScaling(
      child: Observer(
        builder: (context) {
          if (store.phase == HtPhase.hidden) return const SizedBox.shrink();
          final palette = store.phase == HtPhase.approaching
              ? HtPalette.of(
                  HtStyle.regular,
                  Theme.of(context).colorScheme,
                  creatorColor: store.approaching?.creatorColor,
                )
              : htPaletteOf(context, store);
          final on = palette.onBackground;
          final style = Theme.of(context).textTheme.labelMedium?.copyWith(
            color: on,
            fontWeight: FontWeight.w700,
          );
          final text = _text(store);
          final ongoing =
              store.phase == HtPhase.ongoing || store.phase == HtPhase.ending;
          final label = store.semanticsSummary.isNotEmpty
              ? store.semanticsSummary
              : (text ?? HtCopy.title);
          return Semantics(
            container: true,
            button: true,
            label: label,
            hint: HtCopy.detailsHint,
            child: Material(
              key: const ValueKey('ht-video-pill'),
              color: palette.background.withValues(alpha: 0.92),
              shape: const StadiumBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: widget.onTap,
                child: SizedBox(
                  height: 28,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: ExcludeSemantics(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            palette.icon,
                            size: 16,
                            color: palette.iconColor,
                          ),
                          const SizedBox(width: 6),
                          if (text != null)
                            Text(text, style: style)
                          else if (ongoing) ...[
                            Text('LVL ${store.shownLevel}', style: style),
                            const SizedBox(width: 8),
                            SizedBox.square(
                              dimension: 14,
                              child: CircularProgressIndicator(
                                value: store.shownPercent / 100,
                                strokeWidth: 2.5,
                                color: palette.fill,
                                backgroundColor: palette.track,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text('${store.shownPercent}%', style: style),
                          ],
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
