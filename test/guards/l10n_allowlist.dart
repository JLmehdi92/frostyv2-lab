/// Literals of `lib/` that read like UI text but stay as they are, by file:
/// `{path: {literal: why}}`. Interpolations are written `{}`. An entry that
/// no longer matches a literal fails the guard (no_hardcoded_strings_test).
///
/// Only what is never translated belongs here: brand names, Twitch's own
/// data, code that only looks like text.
const l10nAllowlist = <String, Map<String, String>>{
  'lib/apis/base_api_client.dart': {
    'No internet connection. Please check your network.': _apiLog,
    'Request was cancelled': _apiLog,
    'Security certificate error': _apiLog,
    'An unexpected error occurred': _apiLog,
    'Connection timeout. Please try again.': _apiLog,
    'Upload timeout. Please try again.': _apiLog,
    'Server response timeout. Please try again.': _apiLog,
    'Request timeout. Please try again.': _apiLog,
    'Invalid request data': _apiLog,
    'Please log in to continue': _apiLog,
    'Access denied. Insufficient permissions': _apiLog,
    'Resource not found': _apiLog,
    'Conflict with current state. Please refresh': _apiLog,
    'Invalid data provided': _apiLog,
    'Rate limit exceeded. Please wait before trying again': _apiLog,
    'Server error. Please try again later': _apiLog,
    'Service temporarily unavailable': _apiLog,
    'Service maintenance. Please try again later': _apiLog,
    'Server timeout. Please try again': _apiLog,
    'HTTP Error {} occurred': _apiLog,
  },
  'lib/apis/twitch_directory_service.dart': {
    'RELEVANCE': 'A GQL sort value sent to Twitch (StreamSort.gql): code.',
    'RECENT': 'A GQL sort value sent to Twitch (StreamSort.gql): code.',
  },
  'lib/models/clip.dart': {
    'TRENDING': 'A GQL sort value sent to Twitch (ClipSort.gqlName): code.',
  },
  'lib/screens/home/live_feed/live_preview.dart': {
    'ONSET preview':
        'The preview player\'s internal media title (media_kit), never '
        'shown: the app\'s name and a word for logs.',
  },
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

/// Why an [ApiException]'s English message is allowed: it is for logs and
/// crash reports only; screens word its kind (lib/l10n/api_errors.dart).
const _apiLog =
    'ApiException.message, English for logs and crash reports; screens '
    'show apiErrorText (lib/l10n/api_errors.dart) instead.';
