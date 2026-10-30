import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/onset_release.dart';

Map<String, dynamic> releaseJson({
  Object? tag = 'build-2023',
  Object? body = 'Faster chat\nFix PiP',
  List<Object?>? assets,
}) => {
  'tag_name': tag,
  'body': body,
  'assets':
      assets ??
      [
        {'id': 11, 'name': 'onset-arm64.apk', 'size': 52428800},
        {'id': 12, 'name': 'onset-arm64.apk.sha256', 'size': 64},
      ],
};

void main() {
  group('OnsetRelease.tryParse', () {
    test('reads the build, the notes and both assets', () {
      final release = OnsetRelease.tryParse(releaseJson())!;

      expect(release.build, 2023);
      expect(release.tag, 'build-2023');
      expect(release.notes, 'Faster chat\nFix PiP');
      expect(release.apkAssetId, 11);
      expect(release.shaAssetId, 12);
      expect(release.apkSize, 52428800);
    });

    test('a release without notes reads as empty notes', () {
      expect(OnsetRelease.tryParse(releaseJson(body: null))!.notes, isEmpty);
    });

    test('ignores other assets', () {
      final release = OnsetRelease.tryParse(
        releaseJson(
          assets: [
            {'id': 5, 'name': 'onset-x64.apk', 'size': 1},
            {'id': 11, 'name': 'onset-arm64.apk', 'size': 10},
            {'id': 12, 'name': 'onset-arm64.apk.sha256', 'size': 64},
          ],
        ),
      )!;

      expect(release.apkAssetId, 11);
    });

    for (final tag in [
      'v1.2.3',
      'build-',
      'build-12a',
      'build--3',
      'build-0',
      'prefix-build-12',
      'build-99999999999999999999999',
      12,
      null,
    ]) {
      test('ignores the tag "$tag"', () {
        expect(OnsetRelease.tryParse(releaseJson(tag: tag)), isNull);
      });
    }

    test('needs the APK', () {
      expect(
        OnsetRelease.tryParse(
          releaseJson(
            assets: [
              {'id': 12, 'name': 'onset-arm64.apk.sha256', 'size': 64},
            ],
          ),
        ),
        isNull,
      );
    });

    test('needs the hash, nothing is installed unverified', () {
      expect(
        OnsetRelease.tryParse(
          releaseJson(
            assets: [
              {'id': 11, 'name': 'onset-arm64.apk', 'size': 10},
            ],
          ),
        ),
        isNull,
      );
    });

    test('rejects negative or missing ids and sizes', () {
      for (final apk in [
        {'id': -1, 'name': 'onset-arm64.apk', 'size': 10},
        {'id': 11, 'name': 'onset-arm64.apk', 'size': -10},
        {'name': 'onset-arm64.apk', 'size': 10},
        {'id': '11', 'name': 'onset-arm64.apk', 'size': 10},
      ]) {
        expect(
          OnsetRelease.tryParse(
            releaseJson(
              assets: [
                apk,
                {'id': 12, 'name': 'onset-arm64.apk.sha256', 'size': 64},
              ],
            ),
          ),
          isNull,
          reason: '$apk',
        );
      }
    });

    test('rejects what is not a release', () {
      expect(OnsetRelease.tryParse(null), isNull);
      expect(OnsetRelease.tryParse('build-3'), isNull);
      expect(OnsetRelease.tryParse(releaseJson()..['assets'] = 'x'), isNull);
      expect(
        OnsetRelease.tryParse(releaseJson(assets: ['onset-arm64.apk', null])),
        isNull,
      );
    });
  });
}
