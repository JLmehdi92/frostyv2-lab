import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `L10n.untranslated` (English on purpose) where a screen is not in French
/// yet: each use by file. A ratchet like l10n_baseline.dart: counts must
/// match exactly, only go down, and the map is empty once every screen is
/// translated. `L10n.english` (the fallback) is for lib/l10n/ only, so a
/// screen cannot keep English under another name.
const _untranslated = <String, int>{
  'lib/screens/channel/video/ivs_stats_panel.dart': 1,
  'lib/screens/vod/widgets/vod_details_panel.dart': 1,
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
