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
}
