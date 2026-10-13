/// Languages the live lists can be filtered by (Helix `language`, ISO
/// 639-1), with their own names; '' is every language.
const kStreamLanguages = <String, String>{
  '': 'All languages',
  'en': 'English',
  'fr': 'Français',
  'es': 'Español',
  'de': 'Deutsch',
  'pt': 'Português',
  'it': 'Italiano',
  'ru': 'Русский',
  'ja': '日本語',
  'ko': '한국어',
  'zh': '中文',
  'ar': 'العربية',
  'tr': 'Türkçe',
  'pl': 'Polski',
  'nl': 'Nederlands',
  'sv': 'Svenska',
  'other': 'Other',
};

/// [code] when it is a known filter, '' (every language) otherwise.
String streamLanguageOrAll(String code) =>
    kStreamLanguages.containsKey(code) ? code : '';
