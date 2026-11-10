import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:onset/services/integrity/integrity_token.dart';
import 'package:onset/services/integrity/webview_integrity_minter.dart';

void main() {
  final token = 'v4.public.${'a' * 40}';
  final now = DateTime.utc(2026, 11, 10, 12);
  const nonce = 'f00dfeed';

  String capture({
    Object? value,
    Object? deviceId = 'abcdef0123456789',
    Object? expiration,
    Object? sentNonce = nonce,
  }) => jsonEncode({
    'nonce': sentNonce,
    'token': value ?? token,
    'deviceId': deviceId,
    'expiration':
        expiration ??
        now.add(const Duration(minutes: 20)).millisecondsSinceEpoch,
  });

  IntegrityToken? parse(String message) =>
      IntegrityToken.fromCapture(message, nonce: nonce, now: now);

  test('reads a captured /integrity answer', () {
    final parsed = parse(capture());
    expect(parsed?.value, token);
    expect(parsed?.deviceId, 'abcdef0123456789');
    expect(parsed?.expiresAt, now.add(const Duration(minutes: 20)));
  });

  test('a far-future expiration is capped at one hour', () {
    final parsed = parse(
      capture(expiration: DateTime.utc(2099).millisecondsSinceEpoch),
    );
    expect(parsed?.expiresAt, now.add(IntegrityToken.maxLifetime));
  });

  test('a message without this mint’s nonce is ignored', () {
    expect(parse(capture(sentNonce: null)), isNull);
    expect(parse(capture(sentNonce: 'other')), isNull);
    expect(
      IntegrityToken.fromCapture(
        capture(sentNonce: ''),
        nonce: '',
        now: now,
      ),
      isNull,
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
      expect(parse(message), isNull, reason: message);
    }
  });

  test('never prints the token value', () {
    expect(parse(capture())!.toString(), isNot(contains(token)));
  });

  group('the page', () {
    final minter = WebViewIntegrityMinter(
      overlay: () => null,
      random: Random(1),
    );

    test('is asked for as a desktop browser', () {
      expect(WebViewIntegrityMinter.desktopUserAgent, contains('Windows NT'));
      expect(
        WebViewIntegrityMinter.desktopUserAgent,
        isNot(contains('Mobile')),
      );
    });

    test('gets the capture on every twitch.tv host, and only there', () {
      for (final url in [
        'https://www.twitch.tv/',
        'https://m.twitch.tv/',
        'https://twitch.tv/',
        'https://passport.twitch.tv/x',
      ]) {
        expect(WebViewIntegrityMinter.shouldInject(url), isTrue, reason: url);
      }
      for (final url in [
        'http://www.twitch.tv/',
        'https://twitch.tv.example.com/',
        'https://eviltwitch.tv/',
        'about:blank',
      ]) {
        expect(WebViewIntegrityMinter.shouldInject(url), isFalse, reason: url);
      }
    });

    test('carries a fresh nonce and reads the session from the cookie', () {
      final first = minter.newNonce();
      final second = minter.newNonce();
      expect(first, hasLength(32));
      expect(first, isNot(second));
      final script = WebViewIntegrityMinter.captureScript(first);
      expect(script, contains("nonce: '$first'"));
      expect(script, contains("cookie('auth-token')"));
      expect(script, contains('window.location.host'));
      expect(script, contains('gql.twitch.tv/integrity'));
      expect(script, contains(WebViewIntegrityMinter.channelName));
    });

    test('cancelling with nothing in flight does nothing', () {
      expect(minter.cancel, returnsNormally);
    });
  });
}
