import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:onset/services/integrity/integrity_token.dart';
import 'package:onset/services/integrity/webview_integrity_minter.dart';

void main() {
  final token = 'v4.public.${'a' * 40}';

  String capture({
    Object? value,
    Object? deviceId = 'abcdef0123456789',
    Object? expiration = 1800000000000,
  }) => jsonEncode({
    'token': value ?? token,
    'deviceId': deviceId,
    'expiration': expiration,
  });

  test('reads a captured /integrity answer', () {
    final parsed = IntegrityToken.fromCapture(capture());
    expect(parsed?.value, token);
    expect(parsed?.deviceId, 'abcdef0123456789');
    expect(
      parsed?.expiresAt,
      DateTime.fromMillisecondsSinceEpoch(1800000000000, isUtc: true),
    );
  });

  test('rejects anything that is not a well-formed answer', () {
    for (final message in [
      'not json',
      '[]',
      capture(value: 'short'),
      capture(value: '${'a' * 30}<script>'),
      capture(deviceId: null),
      capture(deviceId: 'has spaces in it'),
      capture(expiration: '1800000000000'),
      capture(expiration: -1),
    ]) {
      expect(IntegrityToken.fromCapture(message), isNull, reason: message);
    }
  });

  test('never prints the token value', () {
    final parsed = IntegrityToken.fromCapture(capture())!;
    expect(parsed.toString(), isNot(contains(token)));
  });

  test('the page script reads the session from the cookie, not from Dart', () {
    final script = WebViewIntegrityMinter.captureScript();
    expect(script, contains("cookie('auth-token')"));
    expect(script, contains('gql.twitch.tv/integrity'));
    expect(script, contains(WebViewIntegrityMinter.channelName));
  });
}
