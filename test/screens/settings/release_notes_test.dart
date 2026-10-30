import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/screens/settings/widgets/release_notes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the release notes read as versions, sections and points', () {
    final blocks = parseReleaseNotes('''
## v5.0.5

January 9, 2026

### Bug Fixes

- Fixed lag.
- [iOS] Fixed user agent breaking login.

---

#### See all release notes at [https://x.dev](https://x.dev)
''');
    expect(blocks, hasLength(6));
    final version = blocks[0] as ReleaseVersion;
    expect((version.version, version.date), ('v5.0.5', 'January 9, 2026'));
    expect((blocks[1] as ReleaseSection).title, 'Bug Fixes');
    expect((blocks[2] as ReleasePoint).platform, isNull);
    final ios = blocks[3] as ReleasePoint;
    expect(
      (ios.text, ios.platform),
      ('Fixed user agent breaking login.', 'iOS'),
    );
    expect(blocks[4], isA<ReleaseRule>());
    expect(
      (blocks[5] as ReleaseParagraph).text,
      'See all release notes at [https://x.dev](https://x.dev)',
    );
  });

  test('release notes: no date, wrapped and nested points, bold', () {
    final blocks = parseReleaseNotes('''
## v6.0.0

A big update.

- **Faster** chat with `code`,
  wrapped here.
  - A point under it.
''');
    final version = blocks[0] as ReleaseVersion;
    expect(version.date, isNull);
    expect((blocks[1] as ReleaseParagraph).text, 'A big update.');
    final point = blocks[2] as ReleasePoint;
    expect(point.text, '**Faster** chat with `code`, wrapped here.');
    expect(point.level, 0);
    final nested = blocks[3] as ReleasePoint;
    expect((nested.text, nested.level), ('A point under it.', 1));
    expect(blocks, hasLength(4));
  });

  group('shouldShowReleaseNotes', () {
    const notes = '''
## v1.1.0

- New.

---

## v1.0.0

- First.
''';

    test('never on a first launch', () {
      expect(
        shouldShowReleaseNotes(lastShown: null, current: '1.1.0', notes: notes),
        isFalse,
      );
    });

    test('after an update with an entry for the new version', () {
      expect(
        shouldShowReleaseNotes(
          lastShown: '1.0.0',
          current: '1.1.0',
          notes: notes,
        ),
        isTrue,
      );
    });

    test('not after an update without an entry for the new version', () {
      expect(
        shouldShowReleaseNotes(
          lastShown: '1.0.0',
          current: '1.2.0',
          notes: notes,
        ),
        isFalse,
      );
      expect(
        shouldShowReleaseNotes(lastShown: '1.0.0', current: '1.1.0', notes: ''),
        isFalse,
      );
    });

    test('not for the same version or a patch of it', () {
      expect(
        shouldShowReleaseNotes(
          lastShown: '1.1.0',
          current: '1.1.0',
          notes: notes,
        ),
        isFalse,
      );
      expect(
        shouldShowReleaseNotes(
          lastShown: '1.1.0',
          current: '1.1.3',
          notes: '## v1.1.3\n\n- Fix.\n',
        ),
        isFalse,
      );
    });

    test('an entry of the same major.minor counts (an update to a patch)', () {
      expect(
        shouldShowReleaseNotes(
          lastShown: '1.0.0',
          current: '1.1.1',
          notes: notes,
        ),
        isTrue,
      );
      expect(
        shouldShowReleaseNotes(
          lastShown: '1.0.0',
          current: '1.10.0',
          notes: notes,
        ),
        isFalse,
      );
    });

    test('an entry may be written with or without the v', () {
      expect(
        shouldShowReleaseNotes(
          lastShown: '1.0.0',
          current: '2.0.0',
          notes: '## 2.0.0\n\n- Big.\n',
        ),
        isTrue,
      );
    });
  });

  test('the bundled release notes hold the 1.0.0 entry', () {
    final bundled = File('assets/release-notes.md').readAsStringSync();
    // The comment for writers stays first.
    expect(bundled.trimLeft(), startsWith('<!--'));
    final entries = parseReleaseEntries(bundled).entries;
    expect(entries, hasLength(1));
    final entry = entries.single;
    expect(entry.version, '1.0.0');
    expect(entry.label, 'v1.0.0');
    expect(entry.date, matches(RegExp(r'^[A-Z][a-z]+ \d{1,2}, \d{4}$')));
    expect(entry.sections, isNotEmpty);
    expect(entry.summary, isNotEmpty);
    // Never on a first launch, whatever the notes say.
    expect(
      shouldShowReleaseNotes(lastShown: null, current: '1.0.0', notes: bundled),
      isFalse,
    );
    expect(
      shouldShowReleaseNotes(
        lastShown: '1.0.0',
        current: '1.0.0',
        notes: bundled,
      ),
      isFalse,
    );
  });

  // On a device, rootBundle refuses a 0-byte asset ("The asset does not
  // exist or has empty data"): the bundled file must never be empty.
  test('the bundled release notes load through the asset bundle', () async {
    final data = await rootBundle.load('assets/release-notes.md');
    expect(data.lengthInBytes, greaterThan(0));
    final text = await rootBundle.loadString('assets/release-notes.md');
    expect(parseReleaseEntries(text).entries, hasLength(1));
    expect(await ReleaseNotes.read(), text);
    expect(
      parseReleaseEntries(await ReleaseNotes.load()).entries,
      hasLength(1),
    );
  });

  test('an HTML comment line is not a block', () {
    expect(parseReleaseNotes('<!-- a note for writers -->\n'), isEmpty);
    expect(
      parseReleaseNotes('<!-- note -->\n## v1.0.0\n\n- First.\n'),
      hasLength(2),
    );
  });

  group('unreadable notes', () {
    tearDown(() => ReleaseNotes.debugSource = null);

    test('read is null and load is empty, never a throw', () async {
      ReleaseNotes.debugSource = () async => throw FlutterError('no asset');
      expect(await ReleaseNotes.read(), isNull);
      expect(await ReleaseNotes.load(), '');
    });

    test('a synchronous throw too', () async {
      ReleaseNotes.debugSource = () => throw StateError('no asset');
      expect(await ReleaseNotes.read(), isNull);
      expect(await ReleaseNotes.load(), '');
    });
  });

  group('parseReleaseEntries', () {
    const notes = '''
Read this first.

## v1.1.0

November 12, 2026

What changed.

### New

- One.
- **Two** with `code`.
  - Under two (not counted).

### Bug Fixes

- [iOS] A fix.

### Odds and ends

- Something else.
- And another.

---

## 1.0.0

- Written before any section.

#### See all release notes at [x](https://x.dev)
''';

    test('versions, notes, sections and their points', () {
      final data = parseReleaseEntries(notes);
      expect(
        [for (final b in data.preamble) (b as ReleaseParagraph).text],
        ['Read this first.'],
      );
      expect(data.entries, hasLength(2));
      final latest = data.entries.first;
      expect(latest.version, '1.1.0');
      expect(latest.label, 'v1.1.0');
      expect(latest.name, 'ONSET 1.1.0');
      expect(latest.date, 'November 12, 2026');
      expect(latest.notes, ['What changed.']);
      expect(
        [for (final s in latest.sections) (s.title, s.kind, s.count)],
        [
          ('New', ReleaseSectionKind.added, 2),
          ('Bug Fixes', ReleaseSectionKind.fixed, 1),
          ('Odds and ends', ReleaseSectionKind.other, 2),
        ],
      );
      expect(latest.sections.first.items, hasLength(3));
      expect(latest.summary, '2 new · 1 fix · 2 changes');

      final first = data.entries.last;
      expect((first.version, first.date), ('1.0.0', null));
      expect(first.sections.single.title, isNull);
      expect(first.sections.single.items.last, isA<ReleaseParagraph>());
      expect(first.summary, '1 change');
    });

    test('section names decide the kind, whatever their case', () {
      ReleaseSectionKind kind(String title) => parseReleaseEntries(
        '## v1.0.0\n\n### $title\n\n- x\n',
      ).entries.single.sections.single.kind;
      expect(kind('NEW'), ReleaseSectionKind.added);
      expect(kind('Features'), ReleaseSectionKind.added);
      expect(kind('Improvements'), ReleaseSectionKind.improved);
      expect(kind('Changed'), ReleaseSectionKind.improved);
      expect(kind('Fixes'), ReleaseSectionKind.fixed);
      expect(kind('bug fixes'), ReleaseSectionKind.fixed);
      expect(kind('Misc'), ReleaseSectionKind.other);
      expect(kind('Bugfixes'), ReleaseSectionKind.fixed);
      expect(kind('Fixes for the new player'), ReleaseSectionKind.fixed);
      expect(kind('Breaking changes'), ReleaseSectionKind.other);
    });

    test('counts read one and many', () {
      final entry = parseReleaseEntries('''
## v2.0.0

### New

- a

### Improvements

- b
- c

### Fixes

- d
- e
''').entries.single;
      expect(entry.summary, '1 new · 2 improvements · 2 fixes');
    });

    test('nothing to read: no entries', () {
      expect(parseReleaseEntries('').entries, isEmpty);
      expect(parseReleaseEntries('<!-- only a note -->\n').entries, isEmpty);
    });
  });
}
