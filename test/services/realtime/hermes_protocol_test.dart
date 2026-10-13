import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/services/realtime/hermes_protocol.dart';

import '../../fixtures/hermes_frames.dart';

void main() {
  group('decodeHermesFrame', () {
    test('welcome', () {
      final frame = decodeHermesFrame(hermesWelcome) as HermesWelcome;

      expect(frame.sessionId, 'session-1');
      expect(frame.keepalive, const Duration(seconds: 15));
      expect(frame.recoveryUrl, startsWith('wss://hermes.twitch.tv/a/v1'));
    });

    test('a welcome without a usable keepalive defaults to 15 s', () {
      final frame =
          decodeHermesFrame(
                '{"type":"welcome","welcome":{"keepaliveSec":0,"sessionId":"s"}}',
              )
              as HermesWelcome;

      expect(frame.keepalive, const Duration(seconds: 15));
    });

    test('an out-of-range keepalive is clamped and never throws', () {
      Duration keepalive(String seconds) =>
          (decodeHermesFrame(
                    '{"type":"welcome","welcome":{"keepaliveSec":$seconds}}',
                  )
                  as HermesWelcome)
              .keepalive;

      expect(keepalive('1e400'), const Duration(seconds: 15));
      expect(keepalive('1e300'), const Duration(seconds: 120));
      expect(keepalive('9007199254740993'), const Duration(seconds: 120));
      expect(keepalive('0.01'), const Duration(seconds: 1));
    });

    test('keepalive', () {
      expect(decodeHermesFrame(hermesKeepalive), isA<HermesKeepalive>());
    });

    test('subscribe results', () {
      final ok = decodeHermesFrame(hermesSubscribeOk) as HermesSubscribeResult;
      expect(ok.ok, isTrue);
      expect(ok.parentId, 'msg-sub-1');
      expect(ok.subscriptionId, 'sub-1');

      final error =
          decodeHermesFrame(hermesSubscribeError) as HermesSubscribeResult;
      expect(error.ok, isFalse);
      expect(error.subscriptionId, 'sub-2');
      expect(error.error, 'invalid topic');
      expect(error.errorCode, 'SUB002');
    });

    test('unsubscribe result', () {
      final frame =
          decodeHermesFrame(hermesUnsubscribeOk) as HermesUnsubscribeResult;

      expect(frame.ok, isTrue);
      expect(frame.subscriptionId, 'sub-1');
    });

    test('notification keeps the inner payload as a string', () {
      final frame = decodeHermesFrame(hermesNotification) as HermesNotification;

      expect(frame.subscriptionId, 'sub-1');
      expect(frame.serverTime, DateTime.utc(2026, 10, 13, 15, 50, 27, 500));
      expect(jsonDecode(frame.payload), {
        'type': 'hype-train-progression',
        'data': {'sequence_id': 1540},
      });
    });

    test('a notification payload sent as an object is re-encoded', () {
      final frame =
          decodeHermesFrame(
                '{"type":"notification","notification":{"subscription":'
                '{"id":"sub-1"},"pubsub":{"type":"x","data":{}}}}',
              )
              as HermesNotification;

      expect(jsonDecode(frame.payload), {
        'type': 'x',
        'data': <String, Object?>{},
      });
    });

    test('reconnect with and without a url', () {
      expect(
        (decodeHermesFrame(hermesReconnect) as HermesReconnect).url,
        'wss://hermes.twitch.tv/b/v1?clientId=CLIENT',
      );
      expect(
        (decodeHermesFrame('{"type":"reconnect"}') as HermesReconnect).url,
        isNull,
      );
    });

    test('an unknown type is kept as unknown', () {
      final frame = decodeHermesFrame('{"type":"somethingNew"}');

      expect(frame, isA<HermesUnknown>());
      expect((frame as HermesUnknown).type, 'somethingNew');
    });

    test('garbage is malformed, never a throw', () {
      for (final bad in [
        'not json',
        '[1,2]',
        '{"id":"no type"}',
        '{"type":7}',
        '{"type":"notification"}',
        '{"type":"subscribeResponse"}',
        'x' * (300 * 1024),
      ]) {
        expect(decodeHermesFrame(bad), isA<HermesMalformed>(), reason: bad);
      }
    });
  });

  group('encode', () {
    final now = DateTime.utc(2026, 10, 13, 15, 50, 1, 5);

    test('subscribe has the verified shape', () {
      final frame =
          jsonDecode(
                encodeSubscribe(
                  messageId: 'm1',
                  subscriptionId: 's1',
                  topic: 'hype-train-events-v2.42',
                  now: now,
                ),
              )
              as Map;

      expect(frame, {
        'type': 'subscribe',
        'id': 'm1',
        'timestamp': '2026-10-13T15:50:01.005Z',
        'subscribe': {
          'id': 's1',
          'type': 'pubsub',
          'pubsub': {'topic': 'hype-train-events-v2.42'},
        },
      });
    });

    test('unsubscribe has the verified shape', () {
      final frame =
          jsonDecode(
                encodeUnsubscribe(
                  messageId: 'm2',
                  subscriptionId: 's1',
                  now: now,
                ),
              )
              as Map;

      expect(frame, {
        'type': 'unsubscribe',
        'id': 'm2',
        'timestamp': '2026-10-13T15:50:01.005Z',
        'unsubscribe': {'id': 's1'},
      });
    });
  });

  test('close codes', () {
    for (final code in [4010, 4111, 4112, 4120, 4123, 4130, 4131]) {
      expect(classifyHermesClose(code), HermesCloseKind.fatal, reason: '$code');
    }
    for (final code in [4100, 4001, 4002, 1006, 1001, null]) {
      expect(
        classifyHermesClose(code),
        HermesCloseKind.reconnect,
        reason: '$code',
      );
    }
    expect(
      classifyHermesClose(1000, initiatedByUs: true),
      HermesCloseKind.normal,
    );
    expect(classifyHermesClose(1000), HermesCloseKind.reconnect);
  });

  test('topics', () {
    expect(isValidPubSubTopic('hype-train-events-v2.123'), isTrue);
    expect(isValidPubSubTopic('video-playback-by-id.1'), isTrue);
    for (final bad in [
      'hype-train-events-v2.',
      'x.12a',
      'a b.1',
      '../1',
      'hype-train-events-v2.${'1' * 21}',
      '',
      'HYPE.1',
    ]) {
      expect(isValidPubSubTopic(bad), isFalse, reason: bad);
    }
  });

  test('ids are unique uuid-v4 strings', () {
    final rng = Random(1);
    final ids = {for (var i = 0; i < 1000; i++) newHermesId(rng)};

    expect(ids, hasLength(1000));
    expect(
      ids.every(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ).hasMatch,
      ),
      isTrue,
    );
  });
}
