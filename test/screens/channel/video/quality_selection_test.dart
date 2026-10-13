import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/screens/channel/video/quality_selection.dart';

void main() {
  group('normalizeQualityName', () {
    test('lowercases and strips bracketed suffixes', () {
      expect(normalizeQualityName('1080p60 (source)'), '1080p60');
      expect(normalizeQualityName('720p60'), '720p60');
      expect(normalizeQualityName(' Audio_Only '), 'audio_only');
      expect(normalizeQualityName('Audio only'), 'audio_only');
    });
  });

  group('pickInitialQuality', () {
    const available = ['1440p60', '1080p60', '720p60', '480p'];

    test('highest wins when the setting is on', () {
      expect(
        pickInitialQuality(
          available: available,
          defaultToHighest: true,
          lastQuality: '480p',
        ),
        '1440p60',
      );
    });

    test('restores the last chosen quality', () {
      expect(
        pickInitialQuality(
          available: available,
          defaultToHighest: false,
          lastQuality: '720p60',
        ),
        '720p60',
      );
    });

    test('matches names saved by other engines', () {
      expect(
        pickInitialQuality(
          available: available,
          defaultToHighest: false,
          lastQuality: '1080p60 (source)',
        ),
        '1080p60',
      );
    });

    test('stays on Auto when nothing applies', () {
      for (final last in [null, 'Auto', '160p']) {
        expect(
          pickInitialQuality(
            available: available,
            defaultToHighest: false,
            lastQuality: last,
          ),
          isNull,
        );
      }
      expect(
        pickInitialQuality(
          available: const [],
          defaultToHighest: true,
          lastQuality: '720p60',
        ),
        isNull,
      );
    });
  });
}
