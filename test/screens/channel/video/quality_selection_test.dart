import 'package:flutter_test/flutter_test.dart';
import 'package:onset/screens/channel/video/quality_selection.dart';

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

  group('audio only', () {
    test('is shown with a readable name', () {
      expect(qualityLabel('audio_only'), 'Audio only');
      expect(qualityLabel('1080p60'), '1080p60');
    });

    test('a saved audio only opens the next stream on Auto', () {
      for (final saved in ['audio_only', 'Audio only']) {
        expect(
          pickInitialQuality(
            available: const ['1080p60', 'audio_only'],
            defaultToHighest: false,
            lastQuality: saved,
          ),
          isNull,
          reason: saved,
        );
      }
    });

    test('this session\'s audio only pick is kept', () {
      expect(
        pickInitialQuality(
          available: const ['1080p60', 'audio_only'],
          defaultToHighest: false,
          lastQuality: 'audio_only',
          keepAudioOnly: true,
        ),
        'audio_only',
      );
    });

    test('highest quality never means audio only', () {
      expect(
        pickInitialQuality(
          available: const ['1080p60', '720p', 'audio_only'],
          defaultToHighest: true,
          lastQuality: null,
        ),
        '1080p60',
      );
    });
  });

  group('isQualityDownSwitch', () {
    test('lower resolution or frame rate is down', () {
      expect(isQualityDownSwitch('1080p60', '720p60'), isTrue);
      expect(isQualityDownSwitch('1080p60', '1080p30'), isTrue);
      expect(isQualityDownSwitch('720p60', 'audio_only'), isTrue);
      expect(isQualityDownSwitch('1440p60 HEVC', '1080p60'), isTrue);
    });

    test('up, the same or unknown is not', () {
      expect(isQualityDownSwitch('480p', '720p60'), isFalse);
      expect(isQualityDownSwitch('720p60', '720p60'), isFalse);
      expect(isQualityDownSwitch('720p30', '720p60'), isFalse);
      expect(isQualityDownSwitch('source', '720p60'), isFalse);
      expect(isQualityDownSwitch('720p60', 'chunked'), isFalse);
    });
  });
}
