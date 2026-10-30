import 'package:flutter/material.dart';
import 'package:onset/models/raid_arrival.dart';
import 'package:onset/screens/channel/celebrations/onset_rocket.dart';
import 'package:onset/theme.dart';
import 'package:onset/widgets/motion/motion.dart';
import 'package:onset/widgets/motion/reduce_motion.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';

/// "You followed X's raid" (board Raids, welcome): a 12 dp card washed in
/// the signal colour with its rule drawing in down the left edge and the
/// rocket popping, at the top of the chat the viewer arrived in.
///
/// It animates only while fresh: scrolled back to later, it is just there.
class RaidWelcomeCard extends StatelessWidget {
  const RaidWelcomeCard({
    super.key,
    required this.arrival,
    this.shownAt,
    this.now,
  });

  final RaidArrival arrival;

  /// When it joined the chat (else when the viewer left with the raid).
  final DateTime? shownAt;

  /// The current time (tests).
  final DateTime Function()? now;

  static const ruleKey = ValueKey('raid-welcome-rule');

  /// How long after arriving the card still plays its entrance.
  static const fresh = Duration(seconds: 4);

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    final accent = SheetColors.accentOf(context);
    final age = (now ?? DateTime.now)().difference(shownAt ?? arrival.at);
    final animate = !reduceMotionOf(context) && age < fresh;
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Semantics(
          container: true,
          label:
              "You followed ${arrival.fromName}'s raid. Welcome to "
              "${arrival.targetName}'s chat",
          child: ExcludeSemantics(
            child: DecoratedBox(
              decoration: ShapeDecoration(
                gradient: LinearGradient(
                  colors: [
                    accent.withValues(alpha: 0.09),
                    accent.withValues(alpha: 0.03),
                  ],
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: accent.withValues(alpha: 0.24),
                    width: OnsetTokens.hairlineWidth,
                  ),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Rule(color: accent, animate: animate),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(9.5, 9, 12, 9),
                          child: Row(
                            spacing: 10,
                            children: [
                              _Pop(
                                animate: animate,
                                child: const OnsetRocket(size: 26),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text.rich(
                                      TextSpan(
                                        children: [
                                          const TextSpan(text: 'You followed '),
                                          TextSpan(
                                            text: arrival.fromName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const TextSpan(text: "'s raid"),
                                        ],
                                      ),
                                      style: TextStyle(
                                        fontFamily: OnsetTokens.bodyFamily,
                                        fontSize: 13.5,
                                        height: 1.35,
                                        color: colors.text,
                                      ),
                                    ),
                                    Text(
                                      "Welcome to ${arrival.targetName}'s chat",
                                      style: TextStyle(
                                        fontFamily: OnsetTokens.bodyFamily,
                                        fontSize: 12,
                                        height: 1.35,
                                        color: colors.secondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
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
      ),
    );
  }
}

/// The 2.5 dp rule down the left edge, drawing in from the top (420 ms
/// after 90 ms).
class _Rule extends StatelessWidget {
  const _Rule({required this.color, required this.animate});

  final Color color;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final rule = ColoredBox(
      key: RaidWelcomeCard.ruleKey,
      color: color,
      child: const SizedBox(width: 2.5),
    );
    if (!animate) return rule;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 510),
      builder: (context, t, child) => Transform(
        alignment: Alignment.topCenter,
        transform: Matrix4.diagonal3Values(
          1,
          OnsetMotion.standard.transform(((t * 510 - 90) / 420).clamp(0, 1)),
          1,
        ),
        child: child,
      ),
      child: rule,
    );
  }
}

/// The rocket popping in (520 ms after 60 ms: from a third of its size,
/// tilted, past its size, then settled).
class _Pop extends StatelessWidget {
  const _Pop({required this.animate, required this.child});

  final bool animate;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!animate) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 580),
      builder: (context, t, child) {
        final p = ((t * 580 - 60) / 520).clamp(0.0, 1.0);
        final double scale;
        final double turn;
        if (p < 0.55) {
          final k = OnsetMotion.standard.transform(p / 0.55);
          scale = 0.35 + (1.1 - 0.35) * k;
          turn = -12 + 15 * k;
        } else {
          final k = OnsetMotion.standard.transform((p - 0.55) / 0.45);
          scale = 1.1 - 0.1 * k;
          turn = 3 - 3 * k;
        }
        return Opacity(
          opacity: (p / 0.55).clamp(0.0, 1.0),
          child: Transform.rotate(
            angle: turn * 3.141592653589793 / 180,
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
      child: child,
    );
  }
}
