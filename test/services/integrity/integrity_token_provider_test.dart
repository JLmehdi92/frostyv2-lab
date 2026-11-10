import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:onset/services/integrity/integrity_token.dart';
import 'package:onset/services/integrity/integrity_token_provider.dart';

void main() {
  late DateTime now;
  late int mints;
  late String? session;

  IntegrityToken tokenExpiringIn(Duration lifetime, [String value = 'v4']) =>
      IntegrityToken(
        value: value,
        deviceId: 'device0001',
        expiresAt: now.add(lifetime),
      );

  IntegrityTokenProvider providerWith(
    IntegrityMinter mint, {
    Duration timeout = const Duration(seconds: 15),
  }) => IntegrityTokenProvider(
    mint: () {
      mints++;
      return mint();
    },
    webSession: () => session,
    now: () => now,
    timeout: timeout,
  );

  setUp(() {
    now = DateTime.utc(2026, 11, 9, 12);
    mints = 0;
    session = 'web-token';
  });

  test('never mints until a caller asks', () {
    providerWith(() async => tokenExpiringIn(const Duration(hours: 1)));
    expect(mints, 0);
  });

  test('mints once and reuses the token until it nears expiry', () async {
    final provider = providerWith(
      () async => tokenExpiringIn(const Duration(minutes: 10)),
    );
    final first = await provider.tokenFor('web-token');
    final second = await provider.tokenFor('web-token');
    expect(first, isNotNull);
    expect(identical(first, second), isTrue);
    expect(mints, 1);

    now = now.add(const Duration(minutes: 9, seconds: 30));
    await provider.tokenFor('web-token');
    expect(mints, 2);
  });

  test('concurrent callers share one mint', () async {
    final pending = Completer<IntegrityToken>();
    final provider = providerWith(() => pending.future);
    final calls = [
      provider.tokenFor('web-token'),
      provider.tokenFor('web-token'),
      provider.tokenFor('web-token'),
    ];
    pending.complete(tokenExpiringIn(const Duration(hours: 1)));
    final tokens = await Future.wait(calls);
    expect(mints, 1);
    expect(tokens.every((token) => identical(token, tokens.first)), isTrue);
  });

  test('a mint that takes too long fails closed', () async {
    final provider = providerWith(
      () => Completer<IntegrityToken>().future,
      timeout: const Duration(milliseconds: 20),
    );
    expect(await provider.tokenFor('web-token'), isNull);
  });

  test('a failed mint returns null and the next tap tries again', () async {
    var fail = true;
    final provider = providerWith(() async {
      if (fail) throw StateError('challenge');
      return tokenExpiringIn(const Duration(hours: 1));
    });
    expect(await provider.tokenFor('web-token'), isNull);
    fail = false;
    expect(await provider.tokenFor('web-token'), isNotNull);
    expect(mints, 2);
  });

  test('an already expired token is refused', () async {
    final provider = providerWith(
      () async => tokenExpiringIn(const Duration(seconds: 30)),
    );
    expect(await provider.tokenFor('web-token'), isNull);
  });

  test('no web session, or another one, never mints', () async {
    final provider = providerWith(
      () async => tokenExpiringIn(const Duration(hours: 1)),
    );
    expect(await provider.tokenFor('someone-else'), isNull);
    expect(await provider.tokenFor(''), isNull);
    session = null;
    expect(await provider.tokenFor('web-token'), isNull);
    expect(mints, 0);
  });

  test('a session change drops the cached token', () async {
    final provider = providerWith(
      () async => tokenExpiringIn(const Duration(hours: 1)),
    );
    await provider.tokenFor('web-token');
    session = 'next-account';
    await provider.tokenFor('next-account');
    expect(mints, 2);
  });

  test('a token minted while the session ended is not kept', () async {
    final pending = Completer<IntegrityToken>();
    final provider = providerWith(() => pending.future);
    final call = provider.tokenFor('web-token');
    session = null;
    pending.complete(tokenExpiringIn(const Duration(hours: 1)));
    expect(await call, isNull);
  });

  test('invalidate forces a fresh mint', () async {
    final provider = providerWith(
      () async => tokenExpiringIn(const Duration(hours: 1)),
    );
    await provider.tokenFor('web-token');
    provider.invalidate();
    await provider.tokenFor('web-token');
    expect(mints, 2);
  });

  test('a far-future token is kept at most one hour', () async {
    final provider = providerWith(
      () async => tokenExpiringIn(const Duration(days: 30)),
    );
    final token = await provider.tokenFor('web-token');
    expect(token?.expiresAt, now.add(IntegrityToken.maxLifetime));
  });

  test('cancel stops the mint in flight and forgets the token', () async {
    final pending = Completer<IntegrityToken>();
    var cancelled = 0;
    final provider = IntegrityTokenProvider(
      mint: () {
        mints++;
        return pending.future;
      },
      cancelMint: () => cancelled++,
      webSession: () => session,
      now: () => now,
    );
    final call = provider.tokenFor('web-token');
    expect(provider.isMinting, isTrue);
    provider.cancel();
    expect(provider.isMinting, isFalse);
    pending.complete(tokenExpiringIn(const Duration(hours: 1)));
    expect(await call, isNull);
    expect(cancelled, 1);
    await provider.tokenFor('web-token');
    expect(mints, 2);
  });
}
