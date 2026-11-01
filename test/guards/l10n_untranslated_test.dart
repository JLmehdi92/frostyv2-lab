import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `L10n.untranslated` (English on purpose) where a screen is not in French
/// yet: each use by file. A ratchet like l10n_baseline.dart: counts must
/// match exactly, only go down, and the map is empty once every screen is
/// translated. `L10n.english` (the fallback) is for lib/l10n/ only, so a
/// screen cannot keep English under another name.
const _untranslated = <String, int>{
  'lib/screens/vod/widgets/vod_details_panel.dart': 1,
};

/// Where the app looks a language's texts up by itself
/// (`lookupAppLocalizations`, `AppLocalizationsEn()`…) outside lib/l10n/:
/// English got that way would pass both tests above. Each use by file, with
/// why it may.
const _directLookups = <String, (int, String)>{
  'lib/screens/onboarding/onboarding_flow.dart': (
    1,
    'the Intro measures its description in every supported language, so '
        'switching language never moves the layout',
  ),
};

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

void main() {
  test('L10n.english is only used inside lib/l10n/', () {
    final uses = usesIn('lib', RegExp(r'\bL10n\.english\b'))
      ..removeWhere((path, _) => path.startsWith('lib/l10n/'));
    expect(
      uses,
      isEmpty,
      reason:
          'use context.l10n (or L10n.current); English on purpose in a '
          'screen not translated yet is L10n.untranslated',
    );
  });

  test('L10n.untranslated: exactly the uses listed, by file', () {
    final uses = usesIn('lib', RegExp(r'\bL10n\.untranslated\b'))
      ..removeWhere((path, _) => path.startsWith('lib/l10n/'));
    expect(
      uses,
      _untranslated,
      reason:
          'a file under its count: lower it here (the screen was '
          'translated); over it, or not listed: translate the text instead',
    );
  });

  test('no language looked up by itself outside lib/l10n/, but the listed '
      'uses', () {
    final uses = usesIn(
      'lib',
      RegExp(r'\blookupAppLocalizations\s*\(|\bAppLocalizations(En|Fr)\s*\('),
    )..removeWhere((path, _) => path.startsWith('lib/l10n/'));
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
      'final d = lookupAppLocalizationsNot;\n',
    );
    expect(
      usesIn(
        dir.path,
        RegExp(r'\blookupAppLocalizations\s*\(|\bAppLocalizations(En|Fr)\s*\('),
      ).values,
      [3],
    );
  });

  test('the counter sees a use', () {
    final dir = Directory.systemTemp.createTempSync('untranslated');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/a.dart').writeAsStringSync(
      'final a = x.label(L10n.untranslated);\n'
      '// L10n.untranslated in a comment counts too\n'
      'final b = L10n.untranslatedness;\n',
    );
    expect(usesIn(dir.path, RegExp(r'\bL10n\.untranslated\b')).values, [2]);
  });
}
