import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/screens/channel/hype_train/stores/hype_train_store.dart';
import 'package:onset/screens/channel/hype_train/widgets/hype_train_copy.dart';

/// `m:ss` (or `h:mm:ss`) until the level runs out. Read out as part of the banner's
/// label, so it has no semantics of its own.
class HypeTrainCountdown extends StatelessWidget {
  const HypeTrainCountdown({super.key, required this.store, this.style});

  final HypeTrainStore store;
  final TextStyle? style;

  static String format(Duration remaining) => HtCopy.countdown(remaining);

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Observer(
      builder: (context) => Text(
        format(store.remaining),
        style: (style ?? const TextStyle()).copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    ),
  );
}
