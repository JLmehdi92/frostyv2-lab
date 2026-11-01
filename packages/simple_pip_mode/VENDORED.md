# Vendored copy

This is `simple_pip_mode` 1.0.0 (MIT, see LICENSE), kept in the repository at
the exact revision ONSET was built against (git revision
`0da5255545e10b18883c737c9eca3ec619ccc2f6` of a fork of
https://github.com/PuntitOwO/simple_pip_mode_flutter: the upstream plugin with
its Flutter upper bound removed, analysis fixes and a PiP action name fix).

ONSET depends on it by path so the build needs no third-party git fork.

The one addition is `android/src/main/res/values-fr/strings.xml`: the French
labels and descriptions of the Picture-in-picture actions (Lire, Mettre en
pause, Suivant, Précédent, Direct), next to the plugin's English ones. Android
picks them from the app's language on Android 13+ (per-app language,
`locales_config.xml`); below Android 13 they follow the system's language.
`test/guards/android_l10n_test.dart` checks that every key of `values/` has a
French entry.
