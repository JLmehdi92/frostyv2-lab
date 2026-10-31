import 'package:onset/l10n/l10n.dart';

/// Languages the live lists can be filtered by (Helix `language`, ISO
/// 639-1), with their own names (endonyms, the same in every language).
const _endonyms = <String, String>{
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
};

/// Every filter, in order: '' (every language) first, the languages, then
/// 'other' (a language not listed).
final kStreamLanguageCodes = List<String>.unmodifiable([
  '',
  ..._endonyms.keys,
  'other',
]);

/// What the filter [code] is called: the language's own name, or for ''
/// and 'other' their names in [l]'s language.
String streamLanguageName(String code, AppLocalizations l) => switch (code) {
  '' => l.streamLanguageAll,
  'other' => l.streamLanguageOther,
  _ => _endonyms[code] ?? code,
};

/// [code] when it is a known filter, '' (every language) otherwise.
String streamLanguageOrAll(String code) =>
    kStreamLanguageCodes.contains(code) ? code : '';
