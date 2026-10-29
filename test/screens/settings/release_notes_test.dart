import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onset/screens/settings/widgets/release_notes.dart';

void main() {
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

  test('the bundled release notes have no entries yet', () {
    final bundled = File('assets/release-notes.md').readAsStringSync();
    expect(parseReleaseNotes(bundled).whereType<ReleaseVersion>(), isEmpty);
  });
}
