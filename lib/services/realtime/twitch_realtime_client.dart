import 'dart:async';
import 'dart:math';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:onset/services/realtime/hermes_protocol.dart';
import 'package:onset/services/realtime/realtime_socket.dart';

/// What a topic subscriber receives.
sealed class RealtimeTopicEvent {
  const RealtimeTopicEvent();
}

/// A message published on the topic (the topic's own JSON, as a string).
final class RealtimeMessage extends RealtimeTopicEvent {
  const RealtimeMessage(this.payload, {this.serverTime});

  final String payload;
  final DateTime? serverTime;
}

/// The topic is (again) being listened to. After a resubscribe, messages
/// sent in between were missed: consumers should refetch their state.
final class RealtimeSubscribed extends RealtimeTopicEvent {
  const RealtimeSubscribed({required this.isResubscribe});

  final bool isResubscribe;
}

/// The topic cannot be listened to right now ([permanent]: not before the
/// next session or app resume).
final class RealtimeUnavailable extends RealtimeTopicEvent {
  const RealtimeUnavailable(this.reason, {this.permanent = false});

  final String reason;
  final bool permanent;
}

enum RealtimeConnectionState {
  idle,
  connecting,
  connected,
  reconnecting,
  paused,
  failed,
}

/// A handle on one topic; [cancel] when done (idempotent).
class RealtimeTopicSubscription {
  RealtimeTopicSubscription._(this.topic, this.events, this._cancel);

  /// A subscription backed by any stream, for consumers' tests.
  @visibleForTesting
  RealtimeTopicSubscription.forTesting(
    this.topic,
    this.events,
    void Function() cancel,
  ) : _cancel = cancel;

  final String topic;
  final Stream<RealtimeTopicEvent> events;
  final void Function() _cancel;
  var _cancelled = false;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _cancel();
  }
}

class _Topic {
  _Topic(this.name);

  final String name;
  final controller = StreamController<RealtimeTopicEvent>.broadcast();
  var refCount = 0;
  String? subscriptionId;
  Timer? unsubscribeTimer;

  /// The session the topic was first sent in: a later session resubscribes.
  int? firstSession;

  /// The last [RealtimeSubscribed] or [RealtimeUnavailable], replayed to
  /// each new listener so a late subscriber still learns where it stands.
  RealtimeTopicEvent? status;

  late final Stream<RealtimeTopicEvent> events = Stream.multi((listener) {
    final current = status;
    if (current != null) {
      listener.add(
        current is RealtimeSubscribed
            ? const RealtimeSubscribed(isResubscribe: false)
            : current,
      );
    }
    final subscription = controller.stream.listen(
      listener.add,
      onDone: listener.close,
    );
    // Not returning the cancel future: the done event would wait for it.
    listener
      ..onPause = subscription.pause
      ..onResume = subscription.resume
      ..onCancel = () => unawaited(subscription.cancel());
  });

  void emit(RealtimeTopicEvent event) {
    if (event is! RealtimeMessage) status = event;
    if (!controller.isClosed) controller.add(event);
  }
}

/// One shared, anonymous Hermes connection for public Twitch topics
/// (`hype-train-events-v2.<channelId>`, …), isolated from chat and video:
/// a failure only reaches the topic subscribers as [RealtimeUnavailable].
///
/// Connects lazily on the first subscription, reference-counts topics,
/// watches keepalives, reconnects with backoff and resubscribes, and sleeps
/// after a minute in the background.
class TwitchRealtimeClient {
  TwitchRealtimeClient({
    RealtimeSocketFactory? connect,
    Uri? endpoint,
    Random? random,
    this.idleClose = const Duration(seconds: 30),
    this.backgroundGrace = const Duration(seconds: 60),
    this.unsubscribeDelay = const Duration(milliseconds: 500),
    this.authTopicPrefixes = defaultAuthTopicPrefixes,
  }) : _connect = connect ?? WebSocketChannelSocket.new,
       _endpoint = endpoint ?? hermesEndpoint,
       _random = random ?? Random.secure();

  /// Topics that need a logged-in session. Hermes accepts them anonymously
  /// (verified), so the client refuses them itself.
  static const defaultAuthTopicPrefixes = {
    'hype-train-events-v1.rewards.',
    'whispers.',
    'chatrooms-user-v1.',
    'user-moderation-notifications.',
    'community-points-user-v1.',
    'predictions-user-v1.',
  };

  final RealtimeSocketFactory _connect;
  final Uri _endpoint;
  final Random _random;
  final Duration idleClose;
  final Duration backgroundGrace;
  final Duration unsubscribeDelay;
  final Set<String> authTopicPrefixes;

  static const _backoff = [1, 2, 4, 8, 16, 30];
  static const _healthySession = Duration(seconds: 60);
  static const _watchdogMargin = Duration(seconds: 5);
  static const _fatalRetryInterval = Duration(minutes: 5);
  static const _serverReconnectInterval = Duration(seconds: 30);

  final _topics = <String, _Topic>{};
  final _states = StreamController<RealtimeConnectionState>.broadcast();

  RealtimeSocket? _socket;
  StreamSubscription<String>? _socketSubscription;
  var _welcomed = false;
  var _sessionCount = 0;
  var _attempt = 0;
  var _keepalive = const Duration(seconds: 15);
  DateTime? _connectedAt;
  DateTime? _failedAt;
  DateTime? _serverReconnectAt;
  var _paused = false;
  var _disposed = false;

  Timer? _watchdog;
  Timer? _healthyTimer;
  Timer? _reconnectTimer;
  Timer? _idleTimer;
  Timer? _graceTimer;

  var _state = RealtimeConnectionState.idle;
  RealtimeConnectionState get state => _state;
  Stream<RealtimeConnectionState> get states => _states.stream;

  /// Starts listening to [topic]. Throws [ArgumentError] for a malformed
  /// topic and [StateError] for a topic that needs a logged-in session.
  RealtimeTopicSubscription subscribe(String topic) {
    if (_disposed) throw StateError('TwitchRealtimeClient is disposed');
    if (!isValidPubSubTopic(topic)) {
      throw ArgumentError.value(topic, 'topic', 'Not a pubsub topic');
    }
    if (authTopicPrefixes.any(topic.startsWith)) {
      throw StateError('$topic needs a logged-in session');
    }
    _idleTimer?.cancel();
    final entry = _topics.putIfAbsent(topic, () => _Topic(topic));
    entry.unsubscribeTimer?.cancel();
    entry.refCount++;
    if (_state == RealtimeConnectionState.failed) {
      if (!_retryAfterFatal()) {
        entry.emit(const RealtimeUnavailable('failed', permanent: true));
      }
    } else if (_socket == null) {
      _ensureConnected();
    } else if (_welcomed && entry.subscriptionId == null) {
      _sendSubscribe(entry);
    }
    return RealtimeTopicSubscription._(
      topic,
      entry.events,
      () => _release(entry),
    );
  }

  void _release(_Topic entry) {
    if (_disposed) return;
    entry.refCount--;
    if (entry.refCount > 0) return;
    entry.unsubscribeTimer?.cancel();
    // A quick switch back to the same channel keeps the subscription.
    entry.unsubscribeTimer = Timer(unsubscribeDelay, () {
      if (entry.refCount > 0) return;
      final subscriptionId = entry.subscriptionId;
      if (subscriptionId != null && _welcomed) {
        _send(
          encodeUnsubscribe(
            messageId: newHermesId(_random),
            subscriptionId: subscriptionId,
            now: clock.now(),
          ),
        );
      }
      _topics.remove(entry.name);
      unawaited(entry.controller.close());
      if (_topics.isEmpty) {
        // Nothing left to reconnect for.
        _reconnectTimer?.cancel();
        _idleTimer?.cancel();
        _idleTimer = Timer(idleClose, () {
          if (_topics.isNotEmpty) return;
          _dropSocket();
          _attempt = 0;
          _setState(RealtimeConnectionState.idle);
        });
      }
    });
  }

  void onAppPaused() {
    if (_disposed) return;
    _graceTimer?.cancel();
    _graceTimer = Timer(backgroundGrace, () {
      // A fatal close keeps its own retry gate.
      if (_state == RealtimeConnectionState.failed) return;
      _paused = true;
      _reconnectTimer?.cancel();
      _dropSocket();
      _setState(RealtimeConnectionState.paused);
    });
  }

  void onAppResumed() {
    if (_disposed) return;
    _graceTimer?.cancel();
    if (_state == RealtimeConnectionState.failed) {
      _retryAfterFatal();
      return;
    }
    if (!_paused) {
      // Back from a short background: don't sit out the rest of a backoff.
      if ((_reconnectTimer?.isActive ?? false) && _topics.isNotEmpty) {
        _attempt = 0;
        _openSocket();
      }
      return;
    }
    _paused = false;
    _attempt = 0;
    if (_topics.isEmpty) {
      _setState(RealtimeConnectionState.idle);
    } else {
      _openSocket();
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final timer in [
      _watchdog,
      _healthyTimer,
      _reconnectTimer,
      _idleTimer,
      _graceTimer,
    ]) {
      timer?.cancel();
    }
    for (final entry in _topics.values) {
      entry.unsubscribeTimer?.cancel();
      unawaited(entry.controller.close());
    }
    _topics.clear();
    final socket = _socket;
    _socket = null;
    unawaited(_socketSubscription?.cancel());
    await socket?.close(1000);
    await _states.close();
  }

  // --- Connection -------------------------------------------------------------

  void _ensureConnected() {
    if (_socket != null || _paused) return;
    if (_reconnectTimer?.isActive ?? false) return;
    _openSocket();
  }

  /// Retries after a fatal close once [_fatalRetryInterval] has passed;
  /// false while still waiting.
  bool _retryAfterFatal() {
    final failedAt = _failedAt;
    if (failedAt != null &&
        clock.now().difference(failedAt) < _fatalRetryInterval) {
      return false;
    }
    _failedAt = null;
    _attempt = 0;
    if (_topics.isNotEmpty) _openSocket();
    return true;
  }

  void _openSocket() {
    _reconnectTimer?.cancel();
    _dropSocket();
    if (_topics.isEmpty) {
      _setState(RealtimeConnectionState.idle);
      return;
    }
    _setState(
      _sessionCount == 0
          ? RealtimeConnectionState.connecting
          : RealtimeConnectionState.reconnecting,
    );
    final RealtimeSocket socket;
    try {
      socket = _connect(_endpoint);
    } catch (e) {
      _log('connect failed: $e');
      _scheduleReconnect();
      return;
    }
    _socket = socket;
    _welcomed = false;
    // No welcome within the window counts as a dead connection too.
    _armWatchdog();
    _socketSubscription = socket.messages.listen(
      _onText,
      onError: (Object e) => _onClosed(socket),
      onDone: () => _onClosed(socket),
      cancelOnError: true,
    );
  }

  /// Closes the current socket without reacting to its close.
  void _dropSocket() {
    _watchdog?.cancel();
    _healthyTimer?.cancel();
    final socket = _socket;
    _socket = null;
    _welcomed = false;
    _connectedAt = null;
    for (final entry in _topics.values) {
      entry.subscriptionId = null;
    }
    unawaited(_socketSubscription?.cancel());
    _socketSubscription = null;
    if (socket != null) unawaited(socket.close(1000));
  }

  void _onClosed(RealtimeSocket socket) {
    if (_disposed || !identical(socket, _socket)) return;
    final code = socket.closeCode;
    _log('closed ($code)');
    final wasHealthy =
        _connectedAt != null &&
        clock.now().difference(_connectedAt!) >= _healthySession;
    _socket = null;
    _dropSocket();
    if (classifyHermesClose(code) == HermesCloseKind.fatal) {
      _failedAt = clock.now();
      _setState(RealtimeConnectionState.failed);
      for (final entry in _topics.values) {
        entry.emit(RealtimeUnavailable('closed $code', permanent: true));
      }
      return;
    }
    _scheduleReconnect(immediate: wasHealthy);
  }

  void _scheduleReconnect({bool immediate = false}) {
    if (_disposed || _paused) return;
    if (_topics.isEmpty) {
      _setState(RealtimeConnectionState.idle);
      return;
    }
    _setState(RealtimeConnectionState.reconnecting);
    for (final entry in _topics.values) {
      entry.emit(const RealtimeUnavailable('reconnecting'));
    }
    final Duration delay;
    if (immediate) {
      delay = Duration.zero;
    } else {
      final base = _backoff[min(_attempt, _backoff.length - 1)] * 1000;
      final jitter = 0.8 + _random.nextDouble() * 0.4;
      delay = Duration(milliseconds: (base * jitter).round());
      _attempt++;
    }
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, _openSocket);
  }

  void _armWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer(_keepalive + _watchdogMargin, () {
      _log('keepalive missed');
      final socket = _socket;
      if (socket == null) return;
      _dropSocket();
      _scheduleReconnect();
    });
  }

  // --- Frames -----------------------------------------------------------------

  void _onText(String text) {
    _armWatchdog();
    switch (decodeHermesFrame(text)) {
      case HermesWelcome(:final keepalive):
        _welcomed = true;
        _keepalive = keepalive;
        _armWatchdog();
        _sessionCount++;
        _connectedAt = clock.now();
        _healthyTimer?.cancel();
        _healthyTimer = Timer(_healthySession, () => _attempt = 0);
        _setState(RealtimeConnectionState.connected);
        for (final entry in _topics.values) {
          if (entry.refCount > 0) _sendSubscribe(entry);
        }
      case HermesSubscribeResult(:final subscriptionId, :final ok) &&
          final result:
        final entry = _topicFor(subscriptionId);
        if (entry == null) return;
        if (ok) {
          entry.emit(
            RealtimeSubscribed(
              isResubscribe:
                  (entry.firstSession ?? _sessionCount) < _sessionCount,
            ),
          );
        } else {
          entry.emit(
            RealtimeUnavailable(
              result.errorCode ?? result.error ?? 'subscribe failed',
              permanent: true,
            ),
          );
        }
      case HermesNotification(:final subscriptionId, :final payload) &&
          final notification:
        _topicFor(
          subscriptionId,
        )?.emit(RealtimeMessage(payload, serverTime: notification.serverTime));
      case HermesReconnect():
        _log('server asked to reconnect');
        // At once, unless the server keeps asking: then it is a loop.
        final last = _serverReconnectAt;
        final now = clock.now();
        _serverReconnectAt = now;
        if (last == null || now.difference(last) >= _serverReconnectInterval) {
          _attempt = 0;
          _openSocket();
        } else {
          _dropSocket();
          _scheduleReconnect();
        }
      case HermesKeepalive() ||
          HermesUnsubscribeResult() ||
          HermesUnknown() ||
          HermesMalformed():
        break;
    }
  }

  _Topic? _topicFor(String subscriptionId) {
    for (final entry in _topics.values) {
      if (entry.subscriptionId == subscriptionId) return entry;
    }
    return null;
  }

  void _sendSubscribe(_Topic entry) {
    final subscriptionId = newHermesId(_random);
    entry
      ..subscriptionId = subscriptionId
      ..firstSession ??= _sessionCount;
    _send(
      encodeSubscribe(
        messageId: newHermesId(_random),
        subscriptionId: subscriptionId,
        topic: entry.name,
        now: clock.now(),
      ),
    );
  }

  void _send(String frame) {
    try {
      _socket?.send(frame);
    } catch (e) {
      _log('send failed: $e');
    }
  }

  void _setState(RealtimeConnectionState state) {
    if (_state == state) return;
    _state = state;
    if (!_states.isClosed) _states.add(state);
  }

  void _log(String message) {
    if (kDebugMode) debugPrint('TwitchRealtimeClient $message');
  }
}
