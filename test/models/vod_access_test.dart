import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/models/vod_access.dart';

import '../fixtures/vod_responses.dart';

void main() {
  group('VodAccessInfo.fromTokenValue', () {
    test('reads an allowed token', () {
      final info = VodAccessInfo.fromTokenValue(vodTokenValue);

      expect(info.forbidden, isFalse);
      expect(info.restrictedBitrates, isEmpty);
      expect(info.expiresAt, isNotNull);
    });

    test('reads a forbidden token with restricted bitrates', () {
      final info = VodAccessInfo.fromTokenValue(vodTokenForbiddenValue);

      expect(info.forbidden, isTrue);
      expect(info.reason, 'geoblocked');
      expect(info.restrictedBitrates, ['chunked', '720p60']);
    });

    test('tells a token asked as a viewer from an anonymous one', () {
      expect(
        VodAccessInfo.fromTokenValue(vodTokenValue).authenticated,
        isFalse,
      );
      expect(
        VodAccessInfo.fromTokenValue(vodTokenAuthValue).authenticated,
        isTrue,
      );
      expect(
        VodAccessInfo.fromTokenValue(
          '{"user_id":null,"expires":4102444800}',
        ).authenticated,
        isFalse,
      );
      expect(VodAccessInfo.fromTokenValue('not json').authenticated, isFalse);
    });

    test('reads the token of an usher url', () {
      String url(String token) =>
          'https://usher.ttvnw.net/vod/1.m3u8?sig=s&token='
          '${Uri.encodeQueryComponent(token)}';

      expect(
        VodAccessInfo.fromUsherUrl(url(vodTokenAuthValue)).authenticated,
        isTrue,
      );
      expect(
        VodAccessInfo.fromUsherUrl(url(vodTokenValue)).authenticated,
        isFalse,
      );
      for (final bad in ['', 'not a url', 'https://usher.ttvnw.net/vod/1']) {
        expect(VodAccessInfo.fromUsherUrl(bad).authenticated, isFalse);
      }
    });

    test('a malformed value is treated as allowed', () {
      final info = VodAccessInfo.fromTokenValue('not json');

      expect(info.forbidden, isFalse);
      expect(info.restrictedBitrates, isEmpty);
      expect(info.expiresAt, isNull);
    });
  });
}
