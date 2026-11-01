import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Where the app looks a language's texts up by itself outside lib/l10n/
/// ([_directLookup]): English got that way would pass the test on
/// `L10n.english`. Each use by file, with why it may.
const _directLookups = <String, (int, String)>{
  'lib/screens/onboarding/onboarding_flow.dart': (
    1,
    'the Intro measures its description in every supported language, so '
        'switching language never moves the layout',
  ),
};

/// Every way to a language's texts but `context.l10n` and `L10n.current`:
/// `lookupAppLocalizations` called or torn off, `AppLocalizationsEn` /
/// `AppLocalizationsFr` built (`.new` too) or named, the delegate's `load`,
/// and `Localizations.override` (a subtree in a language of its own).
final _directLookup = RegExp(
  r'\blookupAppLocalizations\b|\bAppLocalizations(En|Fr)\b|'
  r'\bdelegate\s*\.\s*load\b|\bLocalizations\s*\.\s*override\b',
);

/// `L10n.english`, split across lines by the formatter or not.
final _english = RegExp(r'\bL10n\s*\.\s*english\b');

/// How many times [pattern] occurs in each Dart file of [root], comments
/// included (a commented-out use would come back).
Map<String, int> usesIn(String root, RegExp pattern) {
  final counts = <String, int>{};
  final files = Directory(root)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));
  for (final file in files) {
    final count = pattern.allMatches(file.readAsStringSync()).length;
    if (count > 0) counts[file.path.replaceAll('\\', '/')] = count;
  }
  return counts;
}

/// Screens read the language shown (`context.l10n`, `L10n.current`),
/// never one picked by name: `L10n.english` (the fallback) is for
/// lib/l10n/ only, and a language looked up by itself is allowed only
/// where listed below, so no screen can keep English under another name.
///
/// (The `L10n.untranslated` getter, English on purpose for screens not
/// translated yet, is gone with its ratchet now that every screen is: a
/// use would no longer compile.)
void main() {
  test('L10n.english is only used inside lib/l10n/', () {
    final uses = usesIn('lib', _english)
      ..removeWhere((path, _) => path.startsWith('lib/l10n/'));
    expect(
      uses,
      isEmpty,
      reason:
          'use context.l10n (or L10n.current): a screen shows the '
          'language picked, never English by name',
    );
  });

  test('no language looked up by itself outside lib/l10n/, but the listed '
      'uses', () {
    final uses = usesIn('lib', _directLookup)
      ..removeWhere((path, _) => path.startsWith('lib/l10n/'));
    expect(
      uses,
      {
        for (final MapEntry(:key, :value) in _directLookups.entries)
          key: value.$1,
      },
      reason:
          'read context.l10n (or L10n.current): a language looked up by '
          'name keeps a screen in it whatever the viewer picked',
    );
  });

  test('the direct lookup counter sees each way in', () {
    final dir = Directory.systemTemp.createTempSync('lookups');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/a.dart').writeAsStringSync(
      "final a = lookupAppLocalizations(const Locale('en'));\n"
      'final b = AppLocalizationsEn();\n'
      "final c = AppLocalizationsFr('fr');\n"
      'final d = lookupAppLocalizationsNot;\n'
      'final e = AppLocalizationsEn.new();\n'
      'final f = [en].map(lookupAppLocalizations);\n'
      'final g = AppLocalizations.delegate.load(en);\n'
      'final h = AppLocalizations.delegate\n    .load(en);\n'
      'final i = Localizations.override(context: c, locale: en);\n'
      'final j = AppLocalizationsEnglish;\n',
    );
    expect(usesIn(dir.path, _directLookup).values, [8]);
  });

  test('the English counter sees a use split by the formatter', () {
    final dir = Directory.systemTemp.createTempSync('english');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/a.dart').writeAsStringSync(
      'final a = L10n.english;\n'
      'final b = L10n\n    .english.commonNext;\n'
      'final c = L10n.englishness;\n',
    );
    expect(usesIn(dir.path, _english).values, [2]);
  });
}
