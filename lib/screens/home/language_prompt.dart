import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/onboarding/onboarding_language_choice.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';

/// The language the question shows selected: the one picked (a tap on the
/// pill applies it at once), else the device's.
AppLanguage _selected(SettingsStore settings) => resolveAppLanguage(
  settings.appLanguage,
  WidgetsBinding.instance.platformDispatcher.locales,
);

/// Asks once, after the update that brought French, which language the
/// app shows: a sheet with the English | Français pill, preselected to the
/// device's language, and "Continue".
///
/// A tap on the pill switches the app (the sheet with it) at once. Only
/// "Continue" and Android's back close the sheet (not the scrim, not a
/// drag); both keep the language selected, and the question is answered
/// for good ([SettingsStore.chooseLanguage]).
Future<void> showLanguagePrompt(
  BuildContext context, {
  required SettingsStore settings,
}) async {
  final chosen = await showOnsetSheet<AppLanguage>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    showHandle: false,
    constraints: const BoxConstraints(maxWidth: 480),
    builder: (context) => _LanguagePrompt(settings: settings),
  );
  settings.chooseLanguage(chosen ?? _selected(settings));
}

class _LanguagePrompt extends StatelessWidget {
  const _LanguagePrompt({required this.settings});

  final SettingsStore settings;

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    return Observer(
      builder: (context) {
        final l = context.l10n;
        final selected = _selected(settings);
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  l.languagePromptTitle,
                  style: SheetText.title.copyWith(color: colors.text),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l.languagePromptBody,
                style: SheetText.body.copyWith(color: colors.secondary),
              ),
              const SizedBox(height: 20),
              OnboardingLanguageChoice(
                value: selected,
                colors: LanguageChoiceColors.sheet(context),
                onChanged: (language) => settings.appLanguage = language,
              ),
              const SizedBox(height: 20),
              SheetButton(
                label: l.languagePromptConfirm,
                large: true,
                expand: true,
                // Read now: a tap on the pill in the same frame counts.
                onPressed: () => Navigator.pop(context, _selected(settings)),
              ),
            ],
          ),
        );
      },
    );
  }
}
