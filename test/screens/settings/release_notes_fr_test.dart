import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/settings/widgets/release_notes.dart';

/// What [french] differs in from [english], the notes it translates: the
/// versions and their order, whether each has a date, its sections' kinds
/// in order, each section's points (and points under points), and the
/// [Android]/[iOS] tag of every point. Empty when it follows them.
List<String> releaseNotesTranslationProblems(String english, String french) {
  final en = parseReleaseEntries(english).entries;
  final fr = parseReleaseEntries(french).entries;
  final problems = <String>[];
  if (en.length != fr.length) {
    problems.add('${fr.length} versions in French, ${en.length} in English');
  }
  for (var i = 0; i < en.length && i < fr.length; i++) {
    final (a, b) = (en[i], fr[i]);
    final where = 'version ${i + 1} (${a.version})';
    if (a.version != b.version) {
      problems.add('$where: "${b.version}" in French');
    }
    if ((a.date == null) != (b.date == null)) {
      problems.add('$where: a date in one language only');
    }
    if (a.notes.length != b.notes.length) {
      problems.add(
        '$where: ${b.notes.length} paragraphs, ${a.notes.length} '
        'in English',
      );
    }
    if (a.sections.length != b.sections.length) {
      problems.add(
        '$where: ${b.sections.length} sections, '
        '${a.sections.length} in English',
      );
    }
    for (var s = 0; s < a.sections.length && s < b.sections.length; s++) {
      final (x, y) = (a.sections[s], b.sections[s]);
      final section = '$where, section ${s + 1} ("${x.title}")';
      if (x.kind != y.kind) {
        problems.add(
          '$section: "${y.title}" reads as ${y.kind.name}, '
          'not ${x.kind.name}',
        );
      }
      final xs = x.items.whereType<ReleasePoint>().toList();
      final ys = y.items.whereType<ReleasePoint>().toList();
      if (xs.length != ys.length) {
        problems.add(
          '$section: ${ys.length} points, ${xs.length} in '
          'English',
        );
      }
      for (var p = 0; p < xs.length && p < ys.length; p++) {
        if (xs[p].level != ys[p].level) {
          problems.add('$section, point ${p + 1}: not at the same level');
        }
        if (xs[p].platform != ys[p].platform) {
          problems.add(
            '$section, point ${p + 1}: tag [${ys[p].platform}], '
            '[${xs[p].platform}] in English',
          );
        }
      }
    }
  }
  return problems;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final english = File(ReleaseNotes.englishAsset).readAsStringSync();
  final french = File(ReleaseNotes.frenchAsset).readAsStringSync();

  group('the French release notes', () {
    test('translate the English ones, version for version', () {
      expect(parseReleaseEntries(french).entries, isNotEmpty);
      expect(releaseNotesTranslationProblems(english, french), isEmpty);
    });

    test('are read as French: dates and section kinds', () {
      final entry = parseReleaseEntries(french).entries.first;
      expect(entry.date, '29 octobre 2026');
      expect(
        [for (final section in entry.sections) section.kind],
        [
          ReleaseSectionKind.added,
          ReleaseSectionKind.improved,
          ReleaseSectionKind.fixed,
        ],
      );
      final l = lookupAppLocalizations(const Locale('fr'));
      expect(entry.summary(l), '5 nouveautés · 2 améliorations · 1 correction');
    });

    test('are declared and bundled', () async {
      final text = await rootBundle.loadString(ReleaseNotes.frenchAsset);
      expect(text, french);
    });
  });

  group('the translation check', () {
    const base = '''
## v1.1.0

December 1, 2026

### New

- [Android] One.
  - Under it.
- Two.

### Fixes

- [iOS] Three.

## v1.0.0

October 29, 2026

- First.
''';
    const translated = '''
## v1.1.0

1er décembre 2026

### Nouveautés

- [Android] Un.
  - Dessous.
- Deux.

### Corrections

- [iOS] Trois.

## v1.0.0

29 octobre 2026

- Premier.
''';

    test('passes a faithful translation', () {
      expect(releaseNotesTranslationProblems(base, translated), isEmpty);
    });

    test('catches a missing or reordered version', () {
      expect(
        releaseNotesTranslationProblems(
          base,
          translated.substring(0, translated.indexOf('## v1.0.0')),
        ),
        contains('1 versions in French, 2 in English'),
      );
      expect(
        releaseNotesTranslationProblems(
          base,
          translated
              .replaceFirst('## v1.1.0', '## vX')
              .replaceFirst('## v1.0.0', '## v1.1.0')
              .replaceFirst('## vX', '## v1.0.0'),
        ),
        hasLength(greaterThanOrEqualTo(2)),
      );
    });

    test('catches a section of another kind', () {
      expect(
        releaseNotesTranslationProblems(
          base,
          translated.replaceFirst('### Corrections', '### Divers'),
        ),
        [contains('reads as other, not fixed')],
      );
    });

    test('catches a point too many or too few', () {
      expect(
        releaseNotesTranslationProblems(
          base,
          translated.replaceFirst('- Deux.\n', ''),
        ),
        [contains('2 points, 3 in English')],
      );
      expect(
        releaseNotesTranslationProblems(
          base,
          translated.replaceFirst('- Deux.\n', '- Deux.\n- Encore.\n'),
        ),
        [contains('4 points, 3 in English')],
      );
    });

    test('catches a lost or moved platform tag', () {
      expect(
        releaseNotesTranslationProblems(
          base,
          translated.replaceFirst('[iOS] Trois', 'Trois'),
        ),
        [contains('tag [null], [iOS] in English')],
      );
      expect(
        releaseNotesTranslationProblems(
          base,
          translated.replaceFirst('[Android] Un', '[iOS] Un'),
        ),
        [contains('tag [iOS], [Android] in English')],
      );
    });

    test('catches a point under a point made a point of its own', () {
      expect(
        releaseNotesTranslationProblems(
          base,
          translated.replaceFirst('  - Dessous.', '- Dessous.'),
        ),
        isNotEmpty,
      );
    });

    test('catches a lost date', () {
      expect(
        releaseNotesTranslationProblems(
          base,
          translated.replaceFirst('1er décembre 2026', 'le 1er décembre'),
        ),
        contains(contains('a date in one language only')),
      );
    });
  });

  group('the parser reads French', () {
    test('dates, the 1st included', () {
      for (final (written, read) in const [
        ('29 octobre 2026', '29 octobre 2026'),
        ('1er janvier 2027', '1er janvier 2027'),
        ('9 février 2026', '9 février 2026'),
        ('15 août 2026', '15 août 2026'),
        ('3 décembre 2026', '3 décembre 2026'),
      ]) {
        final entry = parseReleaseEntries(
          '## v1.0.0\n\n$written\n\n- Un.\n',
        ).entries.single;
        expect(entry.date, read, reason: written);
      }
    });

    test('dates with French no-break spaces, or a decomposed accent', () {
      for (final (written, read) in const [
        ('29\u00a0octobre\u00a02026', '29\u00a0octobre\u00a02026'),
        ('1er\u202fmai\u202f2026', '1er\u202fmai\u202f2026'),
        // "août" and "février" typed as a letter then a combining accent
        // (NFD), read as the letters the screen expects.
        ('15 aou\u0302t 2026', '15 août 2026'),
        ('9 fe\u0301vrier 2026', '9 février 2026'),
        ('3 de\u0301cembre 2026', '3 décembre 2026'),
      ]) {
        final entry = parseReleaseEntries(
          '## v1.0.0\n\n$written\n\n- Un.\n',
        ).entries.single;
        expect(entry.date, read, reason: written);
        expect(entry.notes, isEmpty, reason: written);
      }
    });

    test('the day a date names, in either language', () {
      for (final (date, day) in [
        ('October 29, 2026', DateTime(2026, 10, 29)),
        ('January 9, 2026', DateTime(2026, 1, 9)),
        ('29 octobre 2026', DateTime(2026, 10, 29)),
        ('1er janvier 2027', DateTime(2027)),
        ('15\u00a0août\u00a02026', DateTime(2026, 8, 15)),
        ('15 aou\u0302t 2026', DateTime(2026, 8, 15)),
      ]) {
        expect(releaseDay(date), day, reason: date);
      }
      for (final date in const [
        'February 31, 2026',
        '31 février 2026',
        'Octember 29, 2026',
        '29 brumaire 2026',
        'soon',
      ]) {
        expect(releaseDay(date), isNull, reason: date);
      }
    });

    test('a French heading reads as the English it translates', () {
      ReleaseSectionKind kind(String title) => parseReleaseEntries(
        '## v1.0.0\n\n### $title\n\n- Un.\n',
      ).entries.single.sections.single.kind;

      // English heading, French heading, and the kind both must read as.
      const pairs = [
        ('New', 'Nouveautés', ReleaseSectionKind.added),
        ('NEW', 'NOUVEAUTÉS', ReleaseSectionKind.added),
        ('Features', 'Fonctionnalités', ReleaseSectionKind.added),
        ('New features', 'Nouvelles fonctionnalités', ReleaseSectionKind.added),
        ('Added', 'Ajouts', ReleaseSectionKind.added),
        ('Added', 'Ajouté', ReleaseSectionKind.added),
        ('Improvements', 'Améliorations', ReleaseSectionKind.improved),
        ('Improved', 'Améliorés', ReleaseSectionKind.improved),
        ('Changed', 'Changements', ReleaseSectionKind.improved),
        ('Changed', 'Modifications', ReleaseSectionKind.improved),
        ('Changed', 'Modifié', ReleaseSectionKind.improved),
        ('Fixes', 'Corrections', ReleaseSectionKind.fixed),
        ('Fixes', 'Correctifs', ReleaseSectionKind.fixed),
        ('Bug fixes', 'Bogues corrigés', ReleaseSectionKind.fixed),
        ('Bugfixes', 'Corrections de bogues', ReleaseSectionKind.fixed),
        (
          'Fixes for the new player',
          'Corrections du nouveau lecteur',
          ReleaseSectionKind.fixed,
        ),
        (
          'Improvements and fixes',
          'Améliorations et corrections',
          ReleaseSectionKind.fixed,
        ),
        (
          'New and fixed',
          'Nouveautés et corrections',
          ReleaseSectionKind.fixed,
        ),
        (
          'Incorrect behaviours',
          'Comportements incorrects',
          ReleaseSectionKind.other,
        ),
        ('Misc', 'Divers', ReleaseSectionKind.other),
        // "fix" anywhere is a fix in English, as it always was.
        (
          'Command prefixes',
          'Préfixes des commandes',
          ReleaseSectionKind.fixed,
        ),
      ];
      for (final (english, french, expected) in pairs) {
        expect(kind(english), expected, reason: english);
        expect(kind(french), expected, reason: french);
      }
      // A decomposed accent still reads.
      expect(kind('Ame\u0301liorations'), ReleaseSectionKind.improved);
    });

    test('a line that only looks like a date stays a paragraph', () {
      for (final line in const [
        '29 Octobre 2026',
        '32octobre 2026',
        'octobre 2026',
        '29 brumaire 2026',
      ]) {
        final entry = parseReleaseEntries(
          '## v1.0.0\n\n$line\n\n- Un.\n',
        ).entries.single;
        expect(entry.date, isNull, reason: line);
        expect(entry.notes, [line], reason: line);
      }
    });

    test('section names, in any case', () {
      ReleaseSectionKind kind(String title) => parseReleaseEntries(
        '## v1.0.0\n\n### $title\n\n- Un.\n',
      ).entries.single.sections.single.kind;

      expect(kind('Nouveautés'), ReleaseSectionKind.added);
      expect(kind('NOUVEAUTÉS'), ReleaseSectionKind.added);
      expect(kind('Nouvelles fonctionnalités'), ReleaseSectionKind.added);
      expect(kind('Ajouts'), ReleaseSectionKind.added);
      expect(kind('Améliorations'), ReleaseSectionKind.improved);
      expect(kind('Amélioré'), ReleaseSectionKind.improved);
      expect(kind('Corrections'), ReleaseSectionKind.fixed);
      expect(kind('Correctifs'), ReleaseSectionKind.fixed);
      // A fix first, as in English.
      expect(kind('Corrections du nouveau lecteur'), ReleaseSectionKind.fixed);
      expect(kind('Divers'), ReleaseSectionKind.other);
      // A word only starting like one is not it.
      expect(kind('Nouveautéssss'), ReleaseSectionKind.other);
    });

    test('the summary counts in French, "one" covering 0 and 1', () {
      final l = lookupAppLocalizations(const Locale('fr'));
      final entry = parseReleaseEntries('''
## v1.0.0

### Nouveautés

- Un.

### Améliorations

- Un.
- Deux.

### Corrections

- Un.

### Divers

- Un.
- Deux.
''').entries.single;
      expect(
        entry.summary(l),
        '1 nouveauté · 2 améliorations · 1 correction · 2 modifications',
      );
    });
  });

  group('reading by language', () {
    tearDown(() {
      ReleaseNotes.debugSource = null;
      ReleaseNotes.debugFrenchSource = null;
    });

    test('French reads the French notes', () async {
      ReleaseNotes.debugSource = () async => '## v1.0.0\n\n- English.\n';
      ReleaseNotes.debugFrenchSource = () async => '## v1.0.0\n\n- Français.\n';
      expect(await ReleaseNotes.read(const Locale('fr')), contains('Français'));
      expect(
        await ReleaseNotes.read(const Locale('fr', 'CA')),
        contains('Français'),
      );
    });

    test('English, no language and an unknown one read English', () async {
      ReleaseNotes.debugSource = () async => '## v1.0.0\n\n- English.\n';
      ReleaseNotes.debugFrenchSource = () async => '## v1.0.0\n\n- Français.\n';
      expect(await ReleaseNotes.read(), contains('English'));
      expect(await ReleaseNotes.read(const Locale('en')), contains('English'));
      expect(await ReleaseNotes.read(const Locale('de')), contains('English'));
    });

    test('French falls back to English when missing or empty', () async {
      ReleaseNotes.debugSource = () async => '## v1.0.0\n\n- English.\n';
      ReleaseNotes.debugFrenchSource = () async => throw FlutterError('none');
      expect(await ReleaseNotes.read(const Locale('fr')), contains('English'));
      ReleaseNotes.debugFrenchSource = () async => '  \n';
      expect(await ReleaseNotes.read(const Locale('fr')), contains('English'));
      expect(await ReleaseNotes.load(const Locale('fr')), contains('English'));
    });

    test(
      'a test giving English notes only never gets the bundled French',
      () async {
        ReleaseNotes.debugSource = () async => '## v9.9.9\n\n- Stand-in.\n';
        expect(await ReleaseNotes.read(const Locale('fr')), contains('v9.9.9'));
      },
    );

    test('the bundled notes, by language', () async {
      expect(await ReleaseNotes.read(const Locale('fr')), french);
      expect(await ReleaseNotes.read(const Locale('en')), english);
    });

    test('whether the notes open after an update still reads English', () {
      // Home asks with ReleaseNotes.read() (no language): the English notes
      // decide, whatever the language on screen.
      expect(
        File('lib/screens/home/home.dart').readAsStringSync(),
        contains('await ReleaseNotes.read();'),
      );
      expect(
        shouldShowReleaseNotes(
          lastShown: '0.9.0',
          current: '1.0.0',
          notes: english,
        ),
        isTrue,
      );
    });
  });
}
