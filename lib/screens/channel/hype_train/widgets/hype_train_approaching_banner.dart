import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/screens/channel/hype_train/stores/hype_train_store.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_copy.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_palette.dart';

/// A train is about to start: how many events are left, three check
/// circles in the creator's colour and the time window running out.
class HypeTrainApproachingBanner extends StatelessWidget {
  const HypeTrainApproachingBanner({super.key, required this.store});

  final HypeTrainStore store;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Observer(
        builder: (context) {
          final approaching = store.approaching;
          if (approaching == null) return const SizedBox.shrink();
          final scheme = Theme.of(context).colorScheme;
          final palette = HtPalette.of(
            HtStyle.regular,
            scheme,
            creatorColor: approaching.creatorColor,
          );
          final on = palette.onBackground;
          final textTheme = Theme.of(context).textTheme;
          final subtitle = HtCopy.approachingSubtitle(
            store.approachingEventsLeft,
            nMore: store.approachingNMore,
          );
          return RepaintBoundary(
            child: Semantics(
              container: true,
              liveRegion: true,
              label: '${HtCopy.approaching}. $subtitle',
              child: ExcludeSemantics(
                child: Material(
                  color: palette.background,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Icon(palette.icon, color: palette.iconColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    HtCopy.approaching,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: textTheme.titleSmall?.copyWith(
                                      color: on,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    subtitle,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: textTheme.bodySmall?.copyWith(
                                      color: on.withValues(alpha: 0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            for (var i = 1; i <= 3; i++)
                              Padding(
                                padding: const EdgeInsetsDirectional.only(
                                  start: 4,
                                ),
                                child: store.approachingChecks >= i
                                    ? Icon(
                                        Icons.check_circle_rounded,
                                        key: const ValueKey('ht-check-filled'),
                                        size: 20,
                                        color: palette.fill,
                                      )
                                    : Icon(
                                        Icons.radio_button_unchecked_rounded,
                                        key: const ValueKey('ht-check-empty'),
                                        size: 20,
                                        color: on.withValues(alpha: 0.5),
                                      ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            key: const ValueKey('ht-approaching-bar'),
                            minHeight: 6,
                            value: store.approachingCompleted
                                ? 1
                                : store.approachingFraction,
                            color: palette.fill,
                            backgroundColor: palette.track,
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
