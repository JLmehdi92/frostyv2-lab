import 'package:flutter/material.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/onboarding/onboarding_parts.dart';
import 'package:onset/theme.dart';

/// The app's three tips, as the Welcome step lists them.
List<String> onboardingTips(AppLocalizations l) => [
  l.onboardingWelcomeTipGitHub,
  l.onboardingWelcomeTipChangelog,
  l.onboardingWelcomeTipRating,
];

/// Step 4, Welcome: the three
/// tips, then "Let's go!" opens the app.
class OnboardingWelcomeStep extends StatelessWidget {
  const OnboardingWelcomeStep({
    super.key,
    required this.layout,
    required this.accent,
    required this.onFinish,
  });

  final OnboardingStepLayout layout;
  final Color accent;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final tablet = layout.tablet;
    final l = context.l10n;
    return OnboardingStepFrame(
      layout: layout,
      content: [
        StepRise(
          order: 1,
          child: Semantics(
            header: true,
            child: Text(
              l.onboardingWelcomeTitle,
              style: OnboardingType.title(tablet: tablet),
            ),
          ),
        ),
        SizedBox(height: tablet ? 12 : 10),
        StepRise(
          order: 2,
          child: Text(
            l.onboardingWelcomeLead,
            style: OnboardingType.lead(tablet: tablet),
          ),
        ),
        SizedBox(height: tablet ? 28 : 24),
        for (final (i, tip) in onboardingTips(l).indexed) ...[
          if (i > 0) SizedBox(height: tablet ? 12 : 10),
          StepRise(
            order: 3 + i,
            child: _Tip(number: i + 1, text: tip),
          ),
        ],
      ],
      footer: OnboardingFooter(
        tablet: tablet,
        primary: StepRise(
          order: 6,
          child: OnboardingButton(
            label: l.onboardingWelcomeGo,
            accent: accent,
            trailing: OnboardingGlyphKind.arrowRight,
            onPressed: onFinish,
          ),
        ),
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: onboardingCard(),
      padding: const EdgeInsets.all(16),
      child: MergeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 14,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                border: Border.fromBorderSide(
                  BorderSide(
                    color: OnboardingColors.ringNumber,
                    width: OnsetTokens.hairlineWidth,
                  ),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                '$number',
                style: OnsetType.tabular(
                  const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: OnboardingColors.secondary,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 14.5,
                  height: 1.55,
                  color: OnboardingColors.body,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
