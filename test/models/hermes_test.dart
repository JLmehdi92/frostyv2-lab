import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/models/hermes.dart';

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
}
