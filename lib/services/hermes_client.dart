import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:onset/models/hermes.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// One real-time event, already routed back to the topic that produced it.
@immutable
class HermesEvent {
  /// The topic, e.g. `hype-train-events-v2.155601320`.
  final String topic;

  /// The event name inside the payload, e.g. `goal_updated`.
  final String type;

  /// The payload's `data` object.
  final Map<String, dynamic> data;

  const HermesEvent({
    required this.topic,
    required this.type,
    required this.data,
  });

  @override
  String toString() => 'HermesEvent($topic, $type)';
}

/// Client for Twitch's real-time gateway.
///
/// Hermes replaced `pubsub-edge.twitch.tv`. It carries hype trains, predictions, channel points, creator
/// goals, leaderboards and the rest — one socket for all of them.
///
/// Two behaviours are not guessable from the protocol and were confirmed on a
/// live session before this was written:
///
/// 1. **Notifications never name their topic.** They carry only the
///    server-assigned subscription id, so the client keeps its own map. Reading
///    a topic off a notification yields null and routing silently delivers
///    nothing.
/// 2. **Channel-scoped topics need no authentication.** Only `*-user-v1`
///    topics do, so an unauthenticated viewer still gets every channel feature.
class HermesClient {
  /// The official Android client-id, as used by the app itself. GQL and Hermes
  /// both refuse client-ids that are not allowlisted.
  static const _clientId = 'kd1unb4b3q4t58fwlpcbzcbnm76a8fp';

  static const _endpoint = 'wss://hermes.twitch.tv/v1?clientId=$_clientId';

  /// Fallback when the server's `welcome` omits its keepalive.
  static const _defaultKeepalive = Duration(seconds: 15);

  /// How long to wait for any frame before assuming the socket is wedged.
  /// Generous relative to the keepalive so a slow network is not mistaken for
  /// a dead connection.
  static const _silenceFactor = 3;

  static const _maxBackoff = Duration(seconds: 60);

  /// Injected so tests can drive the client without a network.
  final WebSocketChannel Function(Uri url) _connect;

  /// Supplies the twitch.tv web token for user-scoped topics. Optional: the
  /// client is fully usable without it.
  final Future<String?> Function()? _tokenProvider;

  HermesClient({
    WebSocketChannel Function(Uri url)? connect,
    Future<String?> Function()? tokenProvider,
  }) : _connect = connect ?? WebSocketChannel.connect,
       _tokenProvider = tokenProvider;

  final _events = StreamController<HermesEvent>.broadcast();

  /// Every event from every subscribed topic.
  Stream<HermesEvent> get events => _events.stream;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _socketSubscription;
  Timer? _keepaliveTimer;
  Timer? _silenceTimer;
  Timer? _reconnectTimer;

  /// Topics the caller asked for. Survives reconnects, and is the source of
  /// truth when re-subscribing — the server's ids do not.
  final _desiredTopics = <String>{};

  /// Our request id -> topic, for the window between asking and being answered.
  final _pendingSubscribes = <String, String>{};

  /// Server subscription id -> topic. The only way to route a notification.
  final _subscriptionTopics = <String, String>{};

  var _reconnectAttempts = 0;
  var _disposed = false;

  /// Whether the server has welcomed us.
  ///
  /// Subscribing before that would be sent twice — once eagerly, once when the
  /// welcome replays the desired set — and every event would arrive in
  /// duplicate.
  var _sessionReady = false;
  Duration _keepalive = _defaultKeepalive;
  final _random = Random();

  bool get isConnected => _channel != null;

  /// Set while the app is in the background: no socket, no reconnects.
  var _paused = false;

  /// Closes the socket while the app is in the background, keeping the wanted
  /// topics for [resume]. Saves the pings and reconnects of a socket nobody
  /// is looking at (background audio, picture-in-picture).
  void pause() {
    if (_disposed || _paused) return;
    _paused = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _teardownSocket();
  }

  /// Reopens the socket after [pause]; the welcome replays every topic.
  Future<void> resume() async {
    if (_disposed || !_paused) return;
    _paused = false;
    _reconnectAttempts = 0;
    if (_desiredTopics.isNotEmpty) await connect();
  }

  /// Opens the socket. Safe to call repeatedly; a live connection is kept.
  Future<void> connect() async {
    if (_disposed || _paused || _channel != null) return;
    await _openSocket(Uri.parse(_endpoint));
  }

  Future<void> _openSocket(Uri url) async {
    try {
      final channel = _connect(url);
      _channel = channel;

      _socketSubscription = channel.stream.listen(
        _onFrame,
        onError: (Object error) {
          debugPrint('Hermes socket error: $error');
          _scheduleReconnect();
        },
        onDone: _scheduleReconnect,
        cancelOnError: true,
      );

      _armSilenceTimer();
    } catch (e) {
      debugPrint('Hermes connect failed: $e');
      _scheduleReconnect();
    }
  }

  /// Subscribes to [topic]. Queued when the socket is not up yet, and replayed
  /// automatically after a reconnect.
  Future<void> subscribe(String topic) async {
    if (_disposed) return;

    // Already wanted: it is subscribed, in flight, or queued for the welcome.
    // Sending it again would deliver every event twice.
    final isNew = _desiredTopics.add(topic);

    // Before the welcome there is no session to subscribe against, and the
    // welcome replays the whole desired set anyway.
    if (!_sessionReady) {
      await connect();
      return;
    }
    if (isNew) _sendSubscribe(topic);
  }

  /// Subscribes to several topics at once.
  Future<void> subscribeAll(Iterable<String> topics) async {
    for (final topic in topics) {
      await subscribe(topic);
    }
  }

  /// Stops caring about [topic]. Also tells the server, when one is connected.
  void unsubscribe(String topic) {
    _desiredTopics.remove(topic);

    final entry = _subscriptionTopics.entries
        .where((e) => e.value == topic)
        .firstOrNull;
    if (entry == null) return;

    _subscriptionTopics.remove(entry.key);
    _sendUnsubscribe(entry.key);
  }

  void _sendUnsubscribe(String subscriptionId) {
    _send({
      'id': _newId(),
      'type': 'unsubscribe',
      'timestamp': _timestamp(),
      'unsubscribe': {'id': subscriptionId},
    });
  }

  void _sendSubscribe(String topic) {
    final requestId = _newId();
    _pendingSubscribes[requestId] = topic;

    _send({
      'id': requestId,
      'type': 'subscribe',
      'timestamp': _timestamp(),
      'subscribe': {
        'id': _newId(),
        'type': 'pubsub',
        'pubsub': {'topic': topic},
      },
    });
  }

  /// Sends the `authenticate` frame when a token is on hand.
  ///
  /// A provider that fails is treated as no token: channel topics still work
  /// anonymously, and they must not be lost to a storage hiccup.
  Future<void> _authenticate() async {
    final String? token;
    try {
      token = await _tokenProvider?.call();
    } catch (e) {
      debugPrint('Hermes token unavailable: ${e.runtimeType}');
      return;
    }
    if (token == null || token.isEmpty) return;

    _send({
      'id': _newId(),
      'type': 'authenticate',
      'timestamp': _timestamp(),
      'authenticate': {'token': token},
    });
  }

  void _send(Map<String, dynamic> message) {
    final channel = _channel;
    if (channel == null) return;

    try {
      channel.sink.add(jsonEncode(message));
    } catch (e) {
      debugPrint('Hermes send failed: $e');
      _scheduleReconnect();
    }
  }

  void _onFrame(dynamic frame) {
    if (frame is! String) return;

    // Any frame proves the socket is alive, including a keepalive.
    _armSilenceTimer();

    // A frame of an unexpected shape must cost that frame, never the socket:
    // an exception escaping here would surface as an uncaught error.
    try {
      _handleFrame(frame);
    } catch (e) {
      debugPrint('Hermes: frame dropped (${e.runtimeType})');
    }
  }

  void _handleFrame(String frame) {
    final message = HermesMessage.tryParse(frame);
    if (message == null) {
      debugPrint('Hermes: unparsable frame dropped');
      return;
    }

    switch (message.type) {
      case HermesMessage.typeWelcome:
        _onWelcome(message);

      case HermesMessage.typeSubscribeResponse:
        _onSubscribeResponse(message);

      case HermesMessage.typeNotification:
        _onNotification(message);

      case HermesMessage.typeReconnect:
        // The server is asking us to move. Treat it as a clean restart rather
        // than an error, so the backoff counter is not charged for it.
        _reconnectAttempts = 0;
        _scheduleReconnect();

      case HermesMessage.typeRevocation:
        final topic = _subscriptionTopics.remove(message.subscriptionId);
        if (topic != null) {
          debugPrint('Hermes revoked $topic; re-subscribing');
          _sendSubscribe(topic);
        }

      case HermesMessage.typeParseError:
        // The code only: the frame echoes what we sent, and what we send
        // includes the authenticate token.
        debugPrint('Hermes rejected a client message: ${message.errorCode}');

      case HermesMessage.typeKeepalive:
        break;

      default:
        final error = message.responseError;
        if (error != null) debugPrint('Hermes error: $error');
    }
  }

  void _onWelcome(HermesMessage message) {
    _reconnectAttempts = 0;
    _keepalive = message.keepaliveInterval ?? _defaultKeepalive;
    _armKeepalive();

    // Subscriptions do not survive a new session: the ids are per-session, so
    // the old map is stale rather than merely incomplete.
    _subscriptionTopics.clear();
    _pendingSubscribes.clear();

    unawaited(_startSession());
  }

  /// Authenticates, then subscribes the desired set.
  ///
  /// Strictly in that order: Hermes refuses a `*-user-v1` subscribe that
  /// reaches it before the `authenticate` frame, and reading the token yields.
  /// The session is only marked ready once authenticated, so a topic asked for
  /// in the meantime joins the desired set and goes out with the rest.
  Future<void> _startSession() async {
    final channel = _channel;
    await _authenticate();

    // The socket may have been replaced, paused or disposed while waiting.
    if (_disposed || channel == null || !identical(channel, _channel)) return;

    _sessionReady = true;
    for (final topic in _desiredTopics) {
      _sendSubscribe(topic);
    }
  }

  void _onSubscribeResponse(HermesMessage message) {
    final topic = _pendingSubscribes.remove(message.parentId);
    if (topic == null) return;

    if (!message.isSubscribeOk) {
      debugPrint(
        'Hermes refused $topic: ${message.responseError ?? 'unknown reason'}',
      );
      return;
    }

    final id = message.subscriptionId;
    if (id == null) return;

    // Dropped while the request was in flight: mapping it now would route a
    // topic nobody wants, so release it on the server instead.
    if (!_desiredTopics.contains(topic)) {
      _sendUnsubscribe(id);
      return;
    }
    _subscriptionTopics[id] = topic;
  }

  void _onNotification(HermesMessage message) {
    final topic = _subscriptionTopics[message.subscriptionId];
    if (topic == null) return;

    final payload = message.notificationPayload;
    if (payload == null) return;
    final type = message.payloadType;
    if (type == null && !HermesTopics.sendsUntypedPayloads(topic)) return;

    _events.add(
      HermesEvent(
        topic: topic,
        type: type ?? '',
        data: type == null ? payload : message.payloadData ?? {},
      ),
    );
  }

  void _armKeepalive() {
    _keepaliveTimer?.cancel();
    // Comfortably inside the server's window, so a late tick is not fatal.
    final interval = Duration(
      milliseconds: (_keepalive.inMilliseconds * 0.6).round(),
    );
    _keepaliveTimer = Timer.periodic(interval, (_) {
      _send({'id': _newId(), 'type': 'ping', 'timestamp': _timestamp()});
    });
  }

  void _armSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(_keepalive * _silenceFactor, () {
      debugPrint('Hermes went quiet; reconnecting');
      _scheduleReconnect();
    });
  }

  void _scheduleReconnect() {
    if (_disposed || _paused || _reconnectTimer != null) return;

    _teardownSocket();

    // Exponential backoff with jitter: without it, every viewer of a channel
    // that Hermes drops would come back in lockstep.
    final base = min(
      _maxBackoff.inMilliseconds,
      500 * pow(2, _reconnectAttempts).toInt(),
    );
    final delay = Duration(
      milliseconds: base ~/ 2 + _random.nextInt(base ~/ 2 + 1),
    );
    _reconnectAttempts++;

    _reconnectTimer = Timer(delay, () {
      _reconnectTimer = null;
      unawaited(connect());
    });
  }

  void _teardownSocket() {
    _sessionReady = false;
    _keepaliveTimer?.cancel();
    _keepaliveTimer = null;
    _silenceTimer?.cancel();
    _silenceTimer = null;

    unawaited(_socketSubscription?.cancel());
    _socketSubscription = null;

    unawaited(_channel?.sink.close());
    _channel = null;

    _subscriptionTopics.clear();
    _pendingSubscribes.clear();
  }

  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _teardownSocket();
    _desiredTopics.clear();
    unawaited(_events.close());
  }

  String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 32)}';

  String _timestamp() => DateTime.now().toUtc().toIso8601String();
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
