import 'package:flutter/material.dart';
import 'package:onset/screens/onboarding/onboarding_parts.dart';
import 'package:onset/theme.dart';

/// The app's three tips, as the Welcome step lists them.
const onboardingTips = [
  'Check out the GitHub repo at the top-right of the settings page to '
      'explore ONSET’s source code, report bugs, make feature requests, and '
      'more.',
  'Links to the full changelog and FAQ are in the settings page under '
      '“Other”.',
  'Don’t forget to leave a rating and/or review on the app store!',
];

/// Step 4, Welcome (boards Onboarding and OnboardingTablette): the three
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
    return OnboardingStepFrame(
      layout: layout,
      content: [
        StepRise(
          order: 1,
          child: Semantics(
            header: true,
            child: Text(
              'Welcome!',
              style: OnboardingType.title(tablet: tablet),
            ),
          ),
        ),
        SizedBox(height: tablet ? 12 : 10),
        StepRise(
          order: 2,
          child: Text(
            'Just a few more things…',
            style: OnboardingType.lead(tablet: tablet),
          ),
        ),
        SizedBox(height: tablet ? 28 : 24),
        for (final (i, tip) in onboardingTips.indexed) ...[
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
            label: 'Let’s go!',
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
                    width: FrostyTokens.hairlineWidth,
                  ),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                '$number',
                style: FrostyType.tabular(
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
