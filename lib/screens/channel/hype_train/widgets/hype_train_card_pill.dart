import 'package:flutter/material.dart';
import 'package:onset/models/hype_train.dart';
import 'package:onset/screens/channel/hype_train/widgets/hype_train_copy.dart';
import 'package:onset/screens/channel/hype_train/widgets/hype_train_tokens.dart';

/// Twitch's followed-stream indicator, "Hype Train Level n" (per variant)
/// after a green train, on a small float chip over the stream thumbnail.
class HypeTrainCardPill extends StatelessWidget {
  const HypeTrainCardPill({super.key, required this.status});

  final HtCardStatus status;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final neutrals = HtNeutrals.of(brightness);
    final text = HtCopy.cardLevel(
      status.level,
      variant: status.variant,
      ath: status.isAllTimeHigh,
    );
    return Semantics(
      label: text,
      child: ExcludeSemantics(
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: Container(
            // The thumbnail leaves it unbounded: long names ellipsize.
            constraints: const BoxConstraints(maxWidth: 160),
            margin: const EdgeInsets.all(3),
            padding: const EdgeInsetsDirectional.only(end: HtDims.marginHalf),
            decoration: BoxDecoration(
              color: neutrals.backgroundFloat,
              borderRadius: BorderRadius.circular(HtDims.marginHalf),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(HtDims.marginHalf),
                  child: SizedBox(
                    width: 15,
                    height: 13,
                    child: FittedBox(
                      child: Icon(
                        Icons.train_rounded,
                        size: 15,
                        color: brightness == Brightness.dark
                            ? HtGreen.light
                            : HtGreen.strong,
                      ),
                    ),
                  ),
                ),
                Flexible(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HtType.footnote.copyWith(color: neutrals.textBase),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
