/// Literals of `lib/` that read like UI text but stay as they are, by file:
/// `{path: {literal: why}}`. Interpolations are written `{}`. An entry that
/// no longer matches a literal fails the guard (no_hardcoded_strings_test).
///
/// Only what is never translated belongs here: brand names, Twitch's own
/// data, code that only looks like text.
const l10nAllowlist = <String, Map<String, String>>{
  'lib/main.dart': {
    'ONSET': 'The app\'s name (MaterialApp.title, the task switcher): a brand.',
  },
  'lib/screens/home/shell/onset_shell.dart': {
    'ONSET': 'The header\'s default title: the app\'s name, a brand.',
  },
  'lib/widgets/launch/onset_mark.dart': {
    'ONSET': 'The wordmark\'s screen-reader label: the app\'s name, a brand.',
  },
};
