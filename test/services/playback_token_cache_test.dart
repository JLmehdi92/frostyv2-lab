import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/playback_access_token.dart';
import 'package:onset/services/playback_token_cache.dart';

void main() {
  late DateTime now;
  late PlaybackTokenCache cache;

  PlaybackAccessToken tokenExpiringIn(Duration d, {String sig = 'sig'}) =>
      PlaybackAccessToken(value: 'v', signature: sig, expiresAt: now.add(d));

  setUp(() {
    now = DateTime.utc(2026, 10, 13, 12);
    cache = PlaybackTokenCache(now: () => now, capacity: 2);
  });

  test('returns a token while it is valid', () {
    final token = tokenExpiringIn(const Duration(minutes: 10));
    cache.put('streamer', token);

    expect(cache.get('streamer'), same(token));
  });

  test('treats tokens inside the safety margin as expired', () {
    cache.put('streamer', tokenExpiringIn(const Duration(seconds: 30)));

    expect(cache.get('streamer'), isNull);
  });

  test('expires tokens as time passes', () {
    cache.put('streamer', tokenExpiringIn(const Duration(minutes: 5)));
    now = now.add(const Duration(minutes: 5));

    expect(cache.get('streamer'), isNull);
  });

  test('logins are case-insensitive', () {
    final token = tokenExpiringIn(const Duration(minutes: 10));
    cache.put('Streamer', token);

    expect(cache.get('STREAMER'), same(token));
  });

  test('invalidate removes the entry', () {
    cache
      ..put('streamer', tokenExpiringIn(const Duration(minutes: 10)))
      ..invalidate('streamer');

    expect(cache.get('streamer'), isNull);
  });

  test('never caches tokens without an expiry', () {
    cache.put(
      'streamer',
      const PlaybackAccessToken(value: 'v', signature: 's', expiresAt: null),
    );

    expect(cache.get('streamer'), isNull);
  });

  test('evicts the least recently used entry beyond capacity', () {
    cache
      ..put('a', tokenExpiringIn(const Duration(minutes: 10), sig: 'a'))
      ..put('b', tokenExpiringIn(const Duration(minutes: 10), sig: 'b'));
    cache.get('a');
    cache.put('c', tokenExpiringIn(const Duration(minutes: 10), sig: 'c'));

    expect(cache.get('a')?.signature, 'a');
    expect(cache.get('b'), isNull);
    expect(cache.get('c')?.signature, 'c');
  });

  test('shares a token being asked for until it arrives', () async {
    final token = tokenExpiringIn(const Duration(minutes: 10));
    cache.track('Streamer', Future.value(token));

    expect(await cache.pending('streamer'), same(token));
    await pumpEventQueue();
    expect(cache.pending('streamer'), isNull);

    cache.track('other', Future.error(Exception('down')));
    await expectLater(cache.pending('other'), throwsException);
    await pumpEventQueue();
    expect(cache.pending('other'), isNull);
  });
}
