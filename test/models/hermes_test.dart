import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/models/hermes.dart';

import '../fixtures/hermes_frames.dart';

void main() {
  group('HermesMessage.tryParse', () {
    test('returns null for anything but an object with a string type', () {
      expect(HermesMessage.tryParse('not json'), isNull);
      expect(HermesMessage.tryParse('[1]'), isNull);
      expect(HermesMessage.tryParse('{"id":"a"}'), isNull);
      expect(HermesMessage.tryParse('{"type":5}'), isNull);
    });

    test('ignores ids of the wrong type instead of throwing', () {
      final message = HermesMessage.tryParse(
        '{"type":"x","id":5,"parentId":{"a":1}}',
      );

      expect(message, isNotNull);
      expect(message!.type, 'x');
      expect(message.id, isNull);
      expect(message.parentId, isNull);
    });

    test('a welcome that is not an object reads as empty', () {
      final message = HermesMessage.tryParse(
        '{"type":"welcome","welcome":"later"}',
      )!;

      expect(message.keepaliveInterval, isNull);
      expect(message.recoveryUrl, isNull);
      expect(message.sessionId, isNull);
    });

    test('a welcome with wrongly typed fields reads as empty', () {
      final message = HermesMessage.tryParse(
        '{"type":"welcome","welcome":{"keepaliveSec":"15",'
        '"recoveryUrl":3,"sessionId":[]}}',
      )!;

      expect(message.keepaliveInterval, isNull);
      expect(message.recoveryUrl, isNull);
      expect(message.sessionId, isNull);
    });

    test('a subscribe response that is not an object is not ok', () {
      final message = HermesMessage.tryParse(
        '{"type":"subscribeResponse","subscribeResponse":"ok"}',
      )!;

      expect(message.isSubscribeOk, isFalse);
    });
  });

  group('keepaliveInterval', () {
    Duration? keepalive(Object seconds) => HermesMessage.tryParse(
      '{"type":"welcome","welcome":{"keepaliveSec":$seconds}}',
    )!.keepaliveInterval;

    test('reads the server value', () {
      expect(keepalive(15), const Duration(seconds: 15));
      expect(keepalive(30.9), const Duration(seconds: 30));
    });

    test('is clamped to a sane range', () {
      expect(keepalive(0), const Duration(seconds: 5));
      expect(keepalive(-3), const Duration(seconds: 5));
      expect(keepalive(1), const Duration(seconds: 5));
      expect(keepalive(100000), const Duration(seconds: 120));
    });
  });

  test('errorCode reads the code of an error frame only', () {
    expect(
      HermesMessage.tryParse(
        '{"type":"parseError","parseError":{"errorCode":"PE1","error":"x"}}',
      )!.errorCode,
      'PE1',
    );
    expect(
      HermesMessage.tryParse(
        '{"type":"subscribeResponse","subscribeResponse":'
        '{"result":"error","error":"invalid topic","errorCode":"SUB002"}}',
      )!.errorCode,
      'SUB002',
    );
    expect(
      HermesMessage.tryParse('{"type":"parseError","parseError":5}')!.errorCode,
      isNull,
    );
  });

  group('captured frames', () {
    test('welcome', () {
      final message = HermesMessage.tryParse(hermesWelcome)!;

      expect(message.type, HermesMessage.typeWelcome);
      expect(message.id, 'msg-welcome');
      expect(message.keepaliveInterval, const Duration(seconds: 15));
      expect(message.sessionId, 'session-1');
      expect(message.recoveryUrl, startsWith('wss://hermes.twitch.tv/'));
    });

    test('subscribe answers', () {
      final ok = HermesMessage.tryParse(hermesSubscribeOk)!;
      expect(ok.parentId, 'msg-sub-1');
      expect(ok.isSubscribeOk, isTrue);
      expect(ok.subscriptionId, 'sub-1');
      expect(ok.responseError, isNull);

      final refused = HermesMessage.tryParse(hermesSubscribeError)!;
      expect(refused.isSubscribeOk, isFalse);
      expect(refused.subscriptionId, 'sub-2');
      expect(refused.responseError, 'invalid topic');
      expect(refused.errorCode, 'SUB002');

      final unsubscribed = HermesMessage.tryParse(hermesUnsubscribeOk)!;
      expect(unsubscribed.subscriptionId, 'sub-1');
    });

    test('a notification decodes its double-encoded payload', () {
      final message = HermesMessage.tryParse(hermesNotification)!;

      expect(message.subscriptionId, 'sub-1');
      expect(message.payloadType, 'hype-train-progression');
      expect(message.payloadData, {'sequence_id': 1540});
      expect(message.notificationPayload, {
        'type': 'hype-train-progression',
        'data': {'sequence_id': 1540},
      });
    });

    test('keepalive and reconnect carry no subscription', () {
      expect(
        HermesMessage.tryParse(hermesKeepalive)!.type,
        HermesMessage.typeKeepalive,
      );
      final reconnect = HermesMessage.tryParse(hermesReconnect)!;
      expect(reconnect.type, HermesMessage.typeReconnect);
      expect(reconnect.subscriptionId, isNull);
    });
  });

  test('a revocation names its subscription', () {
    expect(
      HermesMessage.tryParse(
        '{"type":"revocation","revocation":{"subscription":{"id":"s9"}}}',
      )!.subscriptionId,
      's9',
    );
  });

  test('authenticate and unsubscribe errors are read too', () {
    expect(
      HermesMessage.tryParse(
        '{"type":"authenticateResponse",'
        '"authenticateResponse":{"result":"error","error":"bad token"}}',
      )!.responseError,
      'bad token',
    );
    expect(
      HermesMessage.tryParse(
        '{"type":"unsubscribeResponse",'
        '"unsubscribeResponse":{"result":"error","error":404}}',
      )!.responseError,
      '404',
    );
  });

  test('a notification body of the wrong shape reads as empty', () {
    for (final frame in [
      '{"type":"notification","notification":"x"}',
      '{"type":"notification","notification":{"pubsub":"not json"}}',
      '{"type":"notification","notification":{"pubsub":"[1]"}}',
      '{"type":"notification","notification":{"pubsub":3}}',
      '{"type":"notification","notification":{"pubsub":{"type":4,"data":[]}}}',
      '{"type":"notification","notification":'
          '{"subscription":{"id":5},"pubsub":{}}}',
    ]) {
      final message = HermesMessage.tryParse(frame)!;
      expect(message.payloadType, isNull, reason: frame);
      expect(message.payloadData, isNull, reason: frame);
      expect(message.subscriptionId, isNull, reason: frame);
    }
  });

  test('viewer topics carry the viewer id', () {
    expect(HermesTopics.forViewer('7'), [
      'community-points-user-v1.7',
      'predictions-user-v1.7',
    ]);
    expect(HermesTopics.userSubscribeEvents('7'), 'user-subscribe-events-v1.7');
    expect(HermesTopics.userBitsUpdates('7'), 'user-bits-updates-v1.7');
  });
}
