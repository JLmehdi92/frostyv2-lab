import 'dart:convert';

/// Twitch's EventSub websocket: events for the logged-in user, delivered
/// to a session that subscriptions (made over Helix) point at.
final eventSubEndpoint = Uri.parse('wss://eventsub.wss.twitch.tv/ws');

/// Frames above this size are dropped (no legitimate frame comes close).
const _maxFrameLength = 512 * 1024;

const _defaultKeepalive = Duration(seconds: 10);

/// A frame received from EventSub.
sealed class EventSubFrame {
  const EventSubFrame();
}

/// The session is ready: subscriptions may now name [sessionId]. On a
/// session reached through a reconnect URL the old subscriptions carry over.
final class EventSubWelcome extends EventSubFrame {
  const EventSubWelcome({required this.sessionId, required this.keepalive});

  final String sessionId;

  /// Silence longer than this (plus a margin) means the socket is dead.
  final Duration keepalive;
}

final class EventSubKeepalive extends EventSubFrame {
  const EventSubKeepalive();
}

final class EventSubNotification extends EventSubFrame {
  const EventSubNotification({
    required this.messageId,
    required this.subscriptionId,
    required this.type,
    required this.event,
    this.sentAt,
  });

  /// The same message may arrive twice: this tells them apart.
  final String messageId;
  final String subscriptionId;

  /// `user.whisper.message`, `stream.online`, …
  final String type;
  final Map<String, Object?> event;
  final DateTime? sentAt;
}

/// The server moves the session: connect to [url], whose welcome keeps
/// the subscriptions, then drop the old socket.
final class EventSubReconnect extends EventSubFrame {
  const EventSubReconnect(this.url);

  final Uri url;
}

/// Twitch ended a subscription ([status]: `authorization_revoked`,
/// `user_removed`, `version_removed`…).
final class EventSubRevocation extends EventSubFrame {
  const EventSubRevocation({
    required this.subscriptionId,
    required this.type,
    required this.status,
  });

  final String subscriptionId;
  final String type;
  final String status;
}

final class EventSubUnknown extends EventSubFrame {
  const EventSubUnknown(this.type);

  final String type;
}

final class EventSubMalformed extends EventSubFrame {
  const EventSubMalformed();
}

/// Decodes one text frame. Never throws: anything unexpected is
/// [EventSubMalformed].
EventSubFrame decodeEventSubFrame(String text) {
  if (text.length > _maxFrameLength) return const EventSubMalformed();
  final Object? decoded;
  try {
    decoded = jsonDecode(text);
  } catch (_) {
    return const EventSubMalformed();
  }
  if (decoded is! Map) return const EventSubMalformed();
  final metadata = _map(decoded['metadata']);
  final payload = _map(decoded['payload']);
  final type = _string(metadata?['message_type']);
  if (metadata == null || type == null) return const EventSubMalformed();

  switch (type) {
    case 'session_welcome':
      final session = _map(payload?['session']);
      final sessionId = _string(session?['id']);
      if (sessionId == null || sessionId.isEmpty) {
        return const EventSubMalformed();
      }
      final seconds = session?['keepalive_timeout_seconds'];
      return EventSubWelcome(
        sessionId: sessionId,
        keepalive: seconds is num && seconds.isFinite && seconds > 0
            ? Duration(milliseconds: (seconds.clamp(1, 600) * 1000).round())
            : _defaultKeepalive,
      );
    case 'session_keepalive':
      return const EventSubKeepalive();
    case 'notification':
      final messageId = _string(metadata['message_id']);
      final subscription = _map(payload?['subscription']);
      final subscriptionId = _string(subscription?['id']);
      final subscriptionType = _string(subscription?['type']);
      final event = _map(payload?['event']);
      if (messageId == null ||
          subscriptionId == null ||
          subscriptionType == null ||
          event == null) {
        return const EventSubMalformed();
      }
      return EventSubNotification(
        messageId: messageId,
        subscriptionId: subscriptionId,
        type: subscriptionType,
        event: {
          for (final MapEntry(:key, :value) in event.entries)
            if (key is String) key: value,
        },
        sentAt: DateTime.tryParse(_string(metadata['message_timestamp']) ?? ''),
      );
    case 'session_reconnect':
      final url = Uri.tryParse(
        _string(_map(payload?['session'])?['reconnect_url']) ?? '',
      );
      // The session token rides in the URL: only Twitch's own host.
      if (url == null || !isEventSubUrl(url)) return const EventSubMalformed();
      return EventSubReconnect(url);
    case 'revocation':
      final subscription = _map(payload?['subscription']);
      final subscriptionId = _string(subscription?['id']);
      if (subscriptionId == null) return const EventSubMalformed();
      return EventSubRevocation(
        subscriptionId: subscriptionId,
        type: _string(subscription?['type']) ?? '',
        status: _string(subscription?['status']) ?? '',
      );
    default:
      return EventSubUnknown(type);
  }
}

/// A secure websocket URL on Twitch's EventSub host.
bool isEventSubUrl(Uri url) =>
    url.scheme == 'wss' &&
    url.userInfo.isEmpty &&
    (url.host == 'eventsub.wss.twitch.tv' ||
        url.host.endsWith('.eventsub.wss.twitch.tv'));

/// How to react to the socket closing.
enum EventSubCloseKind {
  /// Transient: reconnect with backoff (a new session, so subscribe again).
  reconnect,

  /// Our bug (we sent a frame): retrying would loop.
  fatal,
}

EventSubCloseKind classifyEventSubClose(int? code) =>
    code == 4001 ? EventSubCloseKind.fatal : EventSubCloseKind.reconnect;

String? _string(Object? value) => value is String ? value : null;

Map? _map(Object? value) => value is Map ? value : null;
