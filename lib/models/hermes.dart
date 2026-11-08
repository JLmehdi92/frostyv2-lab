import 'dart:convert';

/// The envelope every Hermes message shares.
///
/// Hermes is Twitch's WebSocket gateway for real-time channel events — hype
/// trains, predictions, channel points and the rest. Hermes replaced
/// `pubsub-edge.twitch.tv`. Topics kept their old names, so a topic string like
/// `hype-train-events-v2.<channelId>` is still the unit of subscription.
///
/// Shapes below were confirmed against a live session on 2026-07-30.
class HermesMessage {
  /// Server message types, as sent in the `type` field.
  static const typeWelcome = 'welcome';
  static const typeKeepalive = 'keepalive';
  static const typeNotification = 'notification';
  static const typeSubscribeResponse = 'subscribeResponse';
  static const typeUnsubscribeResponse = 'unsubscribeResponse';
  static const typeAuthenticateResponse = 'authenticateResponse';
  static const typeReconnect = 'reconnect';
  static const typeRevocation = 'revocation';
  static const typeParseError = 'parseError';

  final String type;
  final String? id;

  /// Ties a response back to the request that caused it.
  final String? parentId;

  final Map<String, dynamic> raw;

  const HermesMessage({
    required this.type,
    required this.raw,
    this.id,
    this.parentId,
  });

  /// Parses a frame. Returns null when the payload is not a JSON object,
  /// rather than throwing: a single malformed frame must not tear down a
  /// connection that is otherwise healthy.
  static HermesMessage? tryParse(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) return null;

      final type = decoded['type'];
      if (type is! String) return null;

      // `is` rather than `as`: a cast throws a TypeError, which the
      // FormatException handler below would not catch.
      final id = decoded['id'];
      final parentId = decoded['parentId'];
      return HermesMessage(
        type: type,
        id: id is String ? id : null,
        parentId: parentId is String ? parentId : null,
        raw: decoded,
      );
    } on FormatException {
      return null;
    }
  }

  /// How often the server expects to hear from us, from the `welcome` frame.
  ///
  /// Measured at 15 seconds. Read rather than hardcoded so a server-side change
  /// does not silently turn into dropped connections — but clamped, because a
  /// zero would arm a zero-interval ping timer and a zero silence timeout.
  Duration? get keepaliveInterval {
    final seconds = _welcome?['keepaliveSec'];
    if (seconds is! num) return null;
    return Duration(
      seconds: seconds.toInt().clamp(minKeepaliveSec, maxKeepaliveSec),
    );
  }

  /// Bounds for [keepaliveInterval].
  static const minKeepaliveSec = 5;
  static const maxKeepaliveSec = 120;

  /// The `welcome` body, when it is an object.
  Map<String, dynamic>? get _welcome {
    final welcome = raw['welcome'];
    return welcome is Map<String, dynamic> ? welcome : null;
  }

  /// The URL that resumes this session instead of starting a fresh one.
  String? get recoveryUrl {
    final url = _welcome?['recoveryUrl'];
    return url is String ? url : null;
  }

  String? get sessionId {
    final id = _welcome?['sessionId'];
    return id is String ? id : null;
  }

  /// Whether a `subscribeResponse` reported success.
  bool get isSubscribeOk {
    final response = raw['subscribeResponse'];
    return response is Map<String, dynamic> && response['result'] == 'ok';
  }

  /// The error a failed response carries, if any.
  String? get responseError {
    for (final key in const [
      'subscribeResponse',
      'unsubscribeResponse',
      'authenticateResponse',
    ]) {
      final body = raw[key];
      if (body is Map<String, dynamic>) {
        final error = body['error'];
        if (error != null) return error.toString();
      }
    }
    return null;
  }

  /// The machine-readable code of an error frame (`parseError` and the
  /// failed responses), safe to log: unlike the rest of the frame it never
  /// echoes what the client sent.
  String? get errorCode {
    for (final key in const [
      'parseError',
      'subscribeResponse',
      'unsubscribeResponse',
      'authenticateResponse',
    ]) {
      final body = raw[key];
      if (body is Map<String, dynamic>) {
        final code = body['errorCode'];
        if (code is String) return code;
      }
    }
    return null;
  }

  /// The server-assigned subscription id a message refers to.
  ///
  /// This is the only link a notification carries back to what was subscribed:
  /// **notifications do not repeat the topic string**. The id is handed out in
  /// `subscribeResponse` and echoed in every `notification`, so a client has to
  /// keep the id-to-topic mapping itself. Reading the topic off a notification
  /// would always yield null, and routing would fail silently.
  String? get subscriptionId {
    for (final key in const [
      'notification',
      'subscribeResponse',
      'unsubscribeResponse',
      'revocation',
    ]) {
      final body = raw[key];
      if (body is Map<String, dynamic>) {
        final subscription = body['subscription'];
        if (subscription is Map<String, dynamic>) {
          final id = subscription['id'];
          if (id is String) return id;
        }
      }
    }
    return null;
  }

  /// The decoded body of a notification.
  ///
  /// Hermes nests the payload as a JSON **string**, exactly as the old PubSub
  /// did, so it needs a second decode. Confirmed on a live `goal_updated`
  /// frame. Returns null when absent or malformed rather than throwing.
  Map<String, dynamic>? get notificationPayload {
    final notification = raw['notification'];
    if (notification is! Map<String, dynamic>) return null;

    final pubsub = notification['pubsub'];
    if (pubsub is Map<String, dynamic>) return pubsub;

    if (pubsub is String) {
      try {
        final decoded = jsonDecode(pubsub);
        return decoded is Map<String, dynamic> ? decoded : null;
      } on FormatException {
        return null;
      }
    }
    return null;
  }

  /// The `type` inside a notification payload — `goal_updated`,
  /// `hype-train-start`, `prediction-updated` and so on.
  String? get payloadType {
    final type = notificationPayload?['type'];
    return type is String ? type : null;
  }

  /// The `data` object inside a notification payload.
  Map<String, dynamic>? get payloadData {
    final data = notificationPayload?['data'];
    return data is Map<String, dynamic> ? data : null;
  }
}

/// The Hermes topics ONSET subscribes to.
///
/// Kept as builders rather than raw strings so a channel id can never be
/// forgotten — a topic without its suffix subscribes to nothing and fails
/// silently, which is the hardest kind of bug to notice here.
class HermesTopics {
  const HermesTopics._();

  static String predictionsChannel(String channelId) =>
      'predictions-channel-v1.$channelId';

  static String communityPointsChannel(String channelId) =>
      'community-points-channel-v1.$channelId';

  static String creatorGoals(String channelId) =>
      'creator-goals-events-v1.$channelId';

  static String celebrations(String channelId) =>
      'celebration-events-v1.$channelId';

  static String channelSubGifts(String channelId) =>
      'channel-sub-gifts-v1.$channelId';

  static String sharedChat(String channelId) =>
      'shared-chat-channel-v1.$channelId';

  static String shoutout(String channelId) => 'shoutout.$channelId';

  static String contentClassificationLabels(String channelId) =>
      'content-classification-labels-v1.$channelId';

  static bool sendsUntypedPayloads(String topic) =>
      topic.startsWith('content-classification-labels-v1.');

  static String videoPlayback(String channelId) =>
      'video-playback-by-id.$channelId';

  static String broadcastSettings(String channelId) =>
      'broadcast-settings-update.$channelId';

  static bool sendsFlatPayloads(String topic) =>
      topic.startsWith('video-playback-by-id.') ||
      topic.startsWith('broadcast-settings-update.');

  // User-scoped topics. These are the only ones that need authentication;
  // channel topics subscribe fine anonymously (verified 2026-07-30).
  static String predictionsUser(String userId) => 'predictions-user-v1.$userId';

  static String communityPointsUser(String userId) =>
      'community-points-user-v1.$userId';

  static String userSubscribeEvents(String userId) =>
      'user-subscribe-events-v1.$userId';

  static String userBitsUpdates(String userId) =>
      'user-bits-updates-v1.$userId';

  /// Everything worth watching for a channel the user is viewing. The hype
  /// train is left out: the hype train store follows it over EventSub/GQL.
  static List<String> forChannel(String channelId) => [
    predictionsChannel(channelId),
    communityPointsChannel(channelId),
    creatorGoals(channelId),
    celebrations(channelId),
    shoutout(channelId),
    contentClassificationLabels(channelId),
    videoPlayback(channelId),
    broadcastSettings(channelId),
  ];

  /// The viewer's own topics, which carry what happens to *them* rather than to
  /// the channel: the bonus chest becoming available, their points balance
  /// changing, their own prediction being settled.
  ///
  /// These are the ones that need authentication.
  static List<String> forViewer(String userId) => [
    communityPointsUser(userId),
    predictionsUser(userId),
    userSubscribeEvents(userId),
  ];
}
