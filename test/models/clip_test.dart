import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/clip.dart';

import '../fixtures/clip_responses.dart';

void main() {
  group('Clip.fromGql', () {
    test('reads every field of a full node', () {
      final clip = Clip.fromGql(clipNode);

      expect(clip.id, '2308545921');
      expect(clip.slug, 'InexpensiveHotGrouseNerfBlueBlaster--wdg-mRtFp79lgSC');
      expect(clip.title, 'breakup advice');
      expect(clip.viewCount, 16337);
      expect(clip.createdAt, DateTime.utc(2026, 10, 10, 20, 30, 36));
      expect(clip.duration, const Duration(seconds: 60));
      expect(clip.thumbnailUrl, contains('thumb-0000000000'));
      expect(clip.broadcasterId, '71092938');
      expect(clip.broadcasterLogin, 'xqc');
      expect(clip.broadcasterDisplayName, 'xQc');
      expect(clip.curatorLogin, 'clipper_1');
      expect(clip.curatorDisplayName, 'clipper_1');
      expect(clip.gameId, '509658');
      expect(clip.gameName, 'Just Chatting');
      expect(clip.vodId, '2897283075');
      expect(clip.vodOffset, const Duration(seconds: 1077));
    });

    test('a clip without VOD, clipper or category keeps the rest', () {
      final clip = Clip.fromGql(clipNodeOrphan);

      expect(clip.curatorLogin, isNull);
      expect(clip.gameName, isNull);
      expect(clip.vodId, isNull);
      expect(clip.vodOffset, isNull);
      expect(clip.thumbnailUrl, isNull);
      expect(clip.broadcasterLogin, 'xqc');
    });

    test('the channel of a list fills in a missing broadcaster', () {
      final clip = Clip.fromGql(
        {...clipNode, 'broadcaster': null},
        broadcaster: const {'id': '1', 'login': 'chan', 'displayName': 'Chan'},
      );
      expect(clip.broadcasterLogin, 'chan');
    });

    test('a node without id, slug, date or length throws', () {
      for (final key in ['id', 'slug', 'createdAt', 'durationSeconds']) {
        expect(
          () => Clip.fromGql({...clipNode, key: null}),
          throwsFormatException,
          reason: key,
        );
      }
    });

    test('a slug that is not a clip slug throws', () {
      expect(
        () => Clip.fromGql({...clipNode, 'slug': '../../etc'}),
        throwsFormatException,
      );
    });
  });

  group('isValidClipSlug', () {
    test('accepts old and new slugs', () {
      expect(isValidClipSlug('DeliciousDelightfulPicklesWOOP'), isTrue);
      expect(
        isValidClipSlug('InexpensiveHotGrouseNerfBlueBlaster--wdg-mRtFp79lgSC'),
        isTrue,
      );
      expect(
        isValidClipSlug('CourageousTolerantOryxMcaT-pl4mimgzF-_PPY-J'),
        isTrue,
      );
    });

    test('rejects anything that could leave the path or query', () {
      for (final slug in [
        '',
        '../x',
        'a b',
        'a/b',
        'a?b',
        'a%2F',
        '-leading',
        'x' * 101,
      ]) {
        expect(isValidClipSlug(slug), isFalse, reason: slug);
      }
    });
  });

  test('periods and sorts carry the GQL names Twitch accepts', () {
    expect(ClipPeriod.values.map((p) => p.gqlName), [
      'LAST_DAY',
      'LAST_WEEK',
      'LAST_MONTH',
      'ALL_TIME',
    ]);
    expect(ClipSort.values.map((s) => s.gqlName), [
      'VIEWS_DESC',
      'TRENDING',
      'VIEWS_DESC',
      'VIEWS_DESC',
    ]);
    expect(ClipSort.values.map((s) => s.fetched), [
      ClipSort.top,
      ClipSort.trending,
      ClipSort.top,
      ClipSort.top,
    ]);
  });

  test('a rendition label reads like the Twitch quality menu', () {
    expect(
      const ClipRendition(height: 1080, frameRate: 60, url: 'u').label,
      '1080p60',
    );
    expect(
      const ClipRendition(height: 720, frameRate: 30.0055, url: 'u').label,
      '720p',
    );
  });

  group('hostile values', () {
    test('a non-finite length is a malformed node, not a crash', () {
      expect(
        () => Clip.fromGql({...clipNode, 'durationSeconds': double.infinity}),
        throwsFormatException,
      );
      expect(
        () => Clip.fromGql({...clipNode, 'durationSeconds': double.nan}),
        throwsFormatException,
      );
    });

    test('negative counts and offsets are dropped', () {
      final clip = Clip.fromGql({
        ...clipNode,
        'viewCount': -5,
        'videoOffsetSeconds': -3,
        'durationSeconds': -1,
      });
      expect(clip.viewCount, 0);
      expect(clip.vodOffset, isNull);
      expect(clip.duration, Duration.zero);
    });
  });
}
