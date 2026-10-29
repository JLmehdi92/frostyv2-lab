import 'package:flutter/widgets.dart';
import 'package:onset/widgets/motion/motion.dart';

/// Whether the viewer asked for less motion.
///
/// Android's "Remove animations" arrives as [MediaQueryData.disableAnimations].
/// iOS's "Reduce Motion" does not: it is only on the platform's accessibility
/// features, so both are read.
///
/// Under reduce motion every animation of the redesign becomes a short
/// cross-fade ([OnsetMotion.reducedFade]): no travel, no overshoot, no
/// stagger, no looping shimmer or ping, and no launch intro.
bool reduceMotionOf(BuildContext context) {
  if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return true;
  final view = View.maybeOf(context);
  return view?.platformDispatcher.accessibilityFeatures.reduceMotion ?? false;
}

/// [normal], or the short cross-fade when the viewer reduces motion.
Duration motionDuration(BuildContext context, Duration normal) =>
    reduceMotionOf(context) ? OnsetMotion.reducedFade : normal;
