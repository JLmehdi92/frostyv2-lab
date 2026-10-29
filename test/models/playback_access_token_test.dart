import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/playback_access_token.dart';

void main() {
  group('PlaybackAccessToken.parseExpiry', () {
    test('reads an integer unix expiry', () {
      expect(
        PlaybackAccessToken.parseExpiry('{"channel":"x","expires":1760000000}'),
        DateTime.fromMillisecondsSinceEpoch(1760000000 * 1000, isUtc: true),
      );
    });

    test('reads a fractional expiry', () {
      expect(
        PlaybackAccessToken.parseExpiry('{"expires":1760000000.5}'),
        DateTime.fromMillisecondsSinceEpoch(1760000000500, isUtc: true),
      );
    });

    test('returns null when there is no usable expiry', () {
      expect(PlaybackAccessToken.parseExpiry('{"channel":"x"}'), isNull);
      expect(PlaybackAccessToken.parseExpiry('{"expires":"soon"}'), isNull);
      expect(PlaybackAccessToken.parseExpiry('not json'), isNull);
      expect(PlaybackAccessToken.parseExpiry(''), isNull);
      expect(PlaybackAccessToken.parseExpiry('[1,2]'), isNull);
    });
  });

  test('fromValue fills expiresAt from the token JSON', () {
    final token = PlaybackAccessToken.fromValue(
      value: '{"expires":1760000000}',
      signature: 'sig',
    );

    expect(token.signature, 'sig');
    expect(token.expiresAt, isNotNull);
  });
}
