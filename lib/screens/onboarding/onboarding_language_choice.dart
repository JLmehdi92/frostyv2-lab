import 'package:flutter/material.dart';
import 'package:onset/l10n/enum_labels.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/onboarding/onboarding_parts.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/theme.dart';
import 'package:onset/widgets/motion/haptics.dart';
import 'package:onset/widgets/motion/motion.dart';
import 'package:onset/widgets/motion/reduce_motion.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';

/// The colours of an [OnboardingLanguageChoice]: the onboarding's black,
/// or a sheet's (the one-time language question over Home).
@immutable
class LanguageChoiceColors {
  const LanguageChoiceColors({
    required this.track,
    required this.ring,
    required this.indicator,
    required this.selectedText,
    required this.idleText,
  });

  /// The onboarding's, like its theme pill.
  static const onboarding = LanguageChoiceColors(
    track: OnboardingColors.raised,
    ring: OnboardingColors.ring,
    indicator: OnboardingColors.text,
    selectedText: OnsetTokens.backgroundDark,
    idleText: OnboardingColors.body,
  );

  /// A sheet's, in its theme.
  factory LanguageChoiceColors.sheet(BuildContext context) {
    final colors = SheetColors.of(context);
    return LanguageChoiceColors(
      track: colors.well,
      ring: colors.ring,
      indicator: colors.text,
      selectedText: colors.sheet,
      idleText: colors.body,
    );
  }

  final Color track;
  final Color ring;

  /// The sliding pill under the selected language.
  final Color indicator;
  final Color selectedText;
  final Color idleText;
}

/// English | Français: a two-option pill with a sliding indicator, like
/// the theme pill of the onboarding's Setup. The languages are named in
/// their own language, whatever is on screen, and a screen reader calls
/// the pill "Language · Langue".
///
/// [value] is the language shown selected (English or French);
/// [onChanged] is told the other one when it is tapped.
class OnboardingLanguageChoice extends StatelessWidget {
  const OnboardingLanguageChoice({
    super.key,
    required this.value,
    required this.onChanged,
    this.colors = LanguageChoiceColors.onboarding,
  }) : assert(value != AppLanguage.system);

  final AppLanguage value;
  final ValueChanged<AppLanguage> onChanged;
  final LanguageChoiceColors colors;

  /// The options, in order.
  static const languages = [AppLanguage.en, AppLanguage.fr];

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final reduce = reduceMotionOf(context);
    final slide = reduce ? Duration.zero : const Duration(milliseconds: 320);
    final tint = reduce
        ? OnsetMotion.reducedFade
        : const Duration(milliseconds: 200);
    final index = languages.indexOf(value);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: l.languageChoiceSemantics,
      child: Container(
        height: 44,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: colors.track,
          borderRadius: BorderRadius.circular(OnsetTokens.radiusPill),
          border: Border.all(
            color: colors.ring,
            width: OnsetTokens.hairlineWidth,
          ),
        ),
        child: Stack(
          children: [
            AnimatedAlign(
              duration: slide,
              curve: OnsetMotion.standard,
              alignment: Alignment(index == 0 ? -1 : 1, 0),
              child: FractionallySizedBox(
                widthFactor: 1 / languages.length,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.indicator,
                    borderRadius: BorderRadius.circular(OnsetTokens.radiusPill),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                for (final language in languages)
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: language == value,
                      inMutuallyExclusiveGroup: true,
                      child: GestureDetector(
                        key: ValueKey('language-${language.name}'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          if (language == value) return;
                          Haptics.selection();
                          onChanged(language);
                        },
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: tint,
                            style: TextStyle(
                              fontFamily: OnsetTokens.bodyFamily,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: language == value
                                  ? colors.selectedText
                                  : colors.idleText,
                            ),
                            child: Text(
                              language.label(l),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
