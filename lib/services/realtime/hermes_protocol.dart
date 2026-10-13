import 'dart:convert';
import 'dart:math';

import 'package:frosty/constants.dart';

/// Twitch's realtime websocket (the successor of PubSub), used anonymously
/// for public topics.
final hermesEndpoint = Uri.parse(
  'wss://hermes.twitch.tv/v1?clientId=$kTwitchWebClientId',
);

/// Frames above this size are dropped (no legitimate frame comes close).
const _maxFrameLength = 256 * 1024;

const _defaultKeepalive = Duration(seconds: 15);

/// A frame received from Hermes.
sealed class HermesFrame {
  const HermesFrame();
}

final class HermesWelcome extends HermesFrame {
  const HermesWelcome({
    required this.sessionId,
    required this.keepalive,
    this.recoveryUrl,
  });

  final String? sessionId;

  /// Silence longer than this (plus a margin) means the socket is dead.
  final Duration keepalive;

  /// Carries an opaque session token: never log it.
  final String? recoveryUrl;
}

final class HermesKeepalive extends HermesFrame {
  const HermesKeepalive();
}

final class HermesSubscribeResult extends HermesFrame {
  const HermesSubscribeResult({
    required this.parentId,
    required this.subscriptionId,
    required this.ok,
    this.error,
    this.errorCode,
  });

  final String? parentId;
  final String subscriptionId;
  final bool ok;
  final String? error;
  final String? errorCode;
}

final class HermesUnsubscribeResult extends HermesFrame {
  const HermesUnsubscribeResult({
    required this.parentId,
    required this.subscriptionId,
    required this.ok,
  });

  final String? parentId;
  final String subscriptionId;
  final bool ok;
}

final class HermesNotification extends HermesFrame {
  const HermesNotification({
    required this.id,
    required this.subscriptionId,
    required this.payload,
    this.serverTime,
  });

  final String? id;
  final String subscriptionId;

  /// The topic's own JSON message, as a string.
  final String payload;
  final DateTime? serverTime;
}

final class HermesReconnect extends HermesFrame {
  const HermesReconnect({this.url});

  final String? url;
}

final class HermesUnknown extends HermesFrame {
  const HermesUnknown(this.type);

  final String type;
}

final class HermesMalformed extends HermesFrame {
  const HermesMalformed();
}

/// Decodes one text frame. Never throws: anything unexpected is
/// [HermesMalformed].
HermesFrame decodeHermesFrame(String text) {
  if (text.length > _maxFrameLength) return const HermesMalformed();
  final Object? decoded;
  try {
    decoded = jsonDecode(text);
  } catch (_) {
    return const HermesMalformed();
  }
  if (decoded is! Map) return const HermesMalformed();
  final type = decoded['type'];
  if (type is! String) return const HermesMalformed();
  final id = _string(decoded['id']);
  final parentId = _string(decoded['parentId']);
  final timestamp = DateTime.tryParse(_string(decoded['timestamp']) ?? '');

  switch (type) {
    case 'welcome':
      final welcome = _map(decoded['welcome']);
      final seconds = welcome?['keepaliveSec'];
      return HermesWelcome(
        sessionId: _string(welcome?['sessionId']),
        keepalive: seconds is num && seconds.isFinite && seconds > 0
            ? Duration(milliseconds: (seconds.clamp(1, 120) * 1000).round())
            : _defaultKeepalive,
        recoveryUrl: _string(welcome?['recoveryUrl']),
      );
    case 'keepalive':
      return const HermesKeepalive();
    case 'subscribeResponse':
      final response = _map(decoded['subscribeResponse']);
      final subscriptionId = _string(_map(response?['subscription'])?['id']);
      if (response == null || subscriptionId == null) {
        return const HermesMalformed();
      }
      return HermesSubscribeResult(
        parentId: parentId,
        subscriptionId: subscriptionId,
        ok: response['result'] == 'ok',
        error: _string(response['error']),
        errorCode: _string(response['errorCode']),
      );
    case 'unsubscribeResponse':
      final response = _map(decoded['unsubscribeResponse']);
      final subscriptionId = _string(_map(response?['subscription'])?['id']);
      if (response == null || subscriptionId == null) {
        return const HermesMalformed();
      }
      return HermesUnsubscribeResult(
        parentId: parentId,
        subscriptionId: subscriptionId,
        ok: response['result'] == 'ok',
      );
    case 'notification':
      final notification = _map(decoded['notification']);
      final subscriptionId = _string(
        _map(notification?['subscription'])?['id'],
      );
      final pubsub = notification?['pubsub'];
      final payload = pubsub is String
          ? pubsub
          : pubsub is Map
          ? jsonEncode(pubsub)
          : null;
      if (subscriptionId == null || payload == null) {
        return const HermesMalformed();
      }
      return HermesNotification(
        id: id,
        subscriptionId: subscriptionId,
        payload: payload,
        serverTime: timestamp,
      );
    case 'reconnect':
      return HermesReconnect(url: _string(_map(decoded['reconnect'])?['url']));
    default:
      return HermesUnknown(type);
  }
}

String encodeSubscribe({
  required String messageId,
  required String subscriptionId,
  required String topic,
  required DateTime now,
}) => jsonEncode({
  'type': 'subscribe',
  'id': messageId,
  'timestamp': _timestamp(now),
  'subscribe': {
    'id': subscriptionId,
    'type': 'pubsub',
    'pubsub': {'topic': topic},
  },
});

String encodeUnsubscribe({
  required String messageId,
  required String subscriptionId,
  required DateTime now,
}) => jsonEncode({
  'type': 'unsubscribe',
  'id': messageId,
  'timestamp': _timestamp(now),
  'unsubscribe': {'id': subscriptionId},
});

/// How to react to the socket closing.
enum HermesCloseKind {
  /// We closed it.
  normal,

  /// Transient: reconnect with backoff.
  reconnect,

  /// The server refuses this client: stop retrying.
  fatal,
}

const _fatalCloseCodes = {4010, 4111, 4112, 4120, 4121, 4122, 4123, 4130, 4131};

HermesCloseKind classifyHermesClose(int? code, {bool initiatedByUs = false}) {
  if (initiatedByUs && code == 1000) return HermesCloseKind.normal;
  if (_fatalCloseCodes.contains(code)) return HermesCloseKind.fatal;
  return HermesCloseKind.reconnect;
}

final _topic = RegExp(r'^[a-z0-9-]+(?:\.[a-z0-9-]+)*\.[0-9]{1,20}$');

/// `family.name.<numeric id>`: the id ends up in a frame, so it is checked.
bool isValidPubSubTopic(String topic) => _topic.hasMatch(topic);

/// A random UUID v4 string for message and subscription ids.
String newHermesId(Random random) {
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

String _timestamp(DateTime now) => now.toUtc().toIso8601String();

String? _string(Object? value) => value is String ? value : null;

Map? _map(Object? value) => value is Map ? value : null;
