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
  'lib/screens/settings/other_settings.dart': {
    'ONSET': 'The app\'s name on the licences page (applicationName): a brand.',
  },
  'lib/screens/settings/profile_tab.dart': {
    'ONSET v{} ({})':
        'The app\'s name, its version and build number: a brand and figures.',
  },
  'lib/screens/settings/stores/auth_store.dart': {
    'Twitch refuses it':
        'Why the token proxy\'s app token is refused: only printed for '
        'debugging (debugPrint), never shown.',
    "it is the login application's (check the Worker's credentials)":
        'Same: a debug log, never shown.',
    "it is a user's token": 'Same: a debug log, never shown.',
    'it is not the application the proxy named':
        'Same: a debug log, never shown.',
  },
  'lib/screens/settings/widgets/settings_page.dart': {
    'ONSET v{} ({})':
        'The app\'s name, its version and build number: a brand and figures.',
  },
  'lib/screens/settings/widgets/settings_twitch_web_token.dart': {
    'auth-token':
        'The name of Twitch\'s cookie, shown as the field\'s label: code, the '
        'same in every language.',
  },
  'lib/utils/stream_languages.dart': {
    'English':
        'A language\'s own name (an endonym), the same in every language.',
    'Français':
        'A language\'s own name (an endonym), the same in every language.',
    'Español':
        'A language\'s own name (an endonym), the same in every language.',
    'Deutsch':
        'A language\'s own name (an endonym), the same in every language.',
    'Português':
        'A language\'s own name (an endonym), the same in every language.',
    'Italiano':
        'A language\'s own name (an endonym), the same in every language.',
    'Русский':
        'A language\'s own name (an endonym), the same in every language.',
    '日本語': 'A language\'s own name (an endonym), the same in every language.',
    '한국어': 'A language\'s own name (an endonym), the same in every language.',
    '中文': 'A language\'s own name (an endonym), the same in every language.',
    'العربية':
        'A language\'s own name (an endonym), the same in every language.',
    'Türkçe':
        'A language\'s own name (an endonym), the same in every language.',
    'Polski':
        'A language\'s own name (an endonym), the same in every language.',
    'Nederlands':
        'A language\'s own name (an endonym), the same in every language.',
    'Svenska':
        'A language\'s own name (an endonym), the same in every language.',
  },
  'lib/widgets/launch/onset_mark.dart': {
    'ONSET': 'The wordmark\'s screen-reader label: the app\'s name, a brand.',
  },
};
