import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/services/realtime/eventsub_protocol.dart';

String _frame(String type, [Map<String, Object?>? payload, Map? metadata]) =>
    jsonEncode({
      'metadata': {
        'message_id': 'm1',
        'message_type': type,
        'message_timestamp': '2026-10-14T10:00:00.5Z',
        ...?metadata,
      },
      'payload': payload ?? <String, Object?>{},
    });

void main() {
  test('welcome gives the session and its keepalive', () {
    final frame = decodeEventSubFrame(
      _frame('session_welcome', {
        'session': {
          'id': 'AQoQexAWVYKSTIu4ec_2VAxyuhAB',
          'status': 'connected',
          'keepalive_timeout_seconds': 10,
          'reconnect_url': null,
        },
      }),
    );
    expect(frame, isA<EventSubWelcome>());
    frame as EventSubWelcome;
    expect(frame.sessionId, 'AQoQexAWVYKSTIu4ec_2VAxyuhAB');
    expect(frame.keepalive, const Duration(seconds: 10));
  });

  test('a welcome without a usable keepalive gets the default', () {
    final frame =
        decodeEventSubFrame(
              _frame('session_welcome', {
                'session': {'id': 's', 'keepalive_timeout_seconds': 'x'},
              }),
            )
            as EventSubWelcome;
    expect(frame.keepalive, const Duration(seconds: 10));
  });

  test('a notification carries its type and event', () {
    final frame = decodeEventSubFrame(
      _frame('notification', {
        'subscription': {
          'id': 'sub-1',
          'type': 'user.whisper.message',
          'version': '1',
        },
        'event': {
          'from_user_id': '1',
          'whisper': {'text': 'hi'},
        },
      }),
    );
    expect(frame, isA<EventSubNotification>());
    frame as EventSubNotification;
    expect(frame.messageId, 'm1');
    expect(frame.subscriptionId, 'sub-1');
    expect(frame.type, 'user.whisper.message');
    expect(frame.event['from_user_id'], '1');
    expect(frame.sentAt, DateTime.utc(2026, 10, 14, 10, 0, 0, 500));
  });

  test('reconnect only to Twitch over wss', () {
    final ok = decodeEventSubFrame(
      _frame('session_reconnect', {
        'session': {
          'id': 's',
          'reconnect_url': 'wss://eventsub.wss.twitch.tv/ws?id=abc',
        },
      }),
    );
    expect((ok as EventSubReconnect).url.host, 'eventsub.wss.twitch.tv');

    for (final url in [
      'ws://eventsub.wss.twitch.tv/ws',
      'wss://evil.example/ws',
      'wss://eventsub.wss.twitch.tv.evil.example/ws',
      'wss://user@eventsub.wss.twitch.tv/ws',
      null,
    ]) {
      expect(
        decodeEventSubFrame(
          _frame('session_reconnect', {
            'session': {'reconnect_url': url},
          }),
        ),
        isA<EventSubMalformed>(),
        reason: '$url',
      );
    }
  });

  test('revocation names the subscription and why', () {
    final frame =
        decodeEventSubFrame(
              _frame('revocation', {
                'subscription': {
                  'id': 'sub-1',
                  'type': 'user.whisper.message',
                  'status': 'authorization_revoked',
                },
              }),
            )
            as EventSubRevocation;
    expect(frame.subscriptionId, 'sub-1');
    expect(frame.status, 'authorization_revoked');
  });

  test('keepalive, unknown and malformed frames', () {
    expect(
      decodeEventSubFrame(_frame('session_keepalive')),
      isA<EventSubKeepalive>(),
    );
    expect(
      (decodeEventSubFrame(_frame('something_new')) as EventSubUnknown).type,
      'something_new',
    );
    for (final text in [
      'not json',
      '[]',
      '{}',
      jsonEncode({'metadata': {}}),
      _frame('session_welcome'),
      _frame('notification', {
        'subscription': {'id': 'x'},
      }),
      'x' * (600 * 1024),
    ]) {
      expect(decodeEventSubFrame(text), isA<EventSubMalformed>());
    }
  });

  test('only a close caused by us is fatal', () {
    expect(classifyEventSubClose(4001), EventSubCloseKind.fatal);
    for (final code in [null, 1000, 1006, 4000, 4002, 4003, 4004, 4007]) {
      expect(classifyEventSubClose(code), EventSubCloseKind.reconnect);
    }
  });
}
