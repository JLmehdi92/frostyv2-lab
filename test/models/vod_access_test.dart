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

    test('a malformed value is treated as allowed', () {
      final info = VodAccessInfo.fromTokenValue('not json');

      expect(info.forbidden, isFalse);
      expect(info.restrictedBitrates, isEmpty);
      expect(info.expiresAt, isNull);
    });
  });
}
