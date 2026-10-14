import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:frosty/apis/base_api_client.dart';
import 'package:frosty/services/realtime/eventsub_protocol.dart';
import 'package:frosty/services/realtime/realtime_socket.dart';

/// One EventSub subscription type for one condition, e.g. the whispers of
/// a user: `EventSubTopic('user.whisper.message', '1', {'user_id': id})`.
@immutable
class EventSubTopic {
  const EventSubTopic(this.type, this.version, this.condition);

  final String type;
  final String version;
  final Map<String, String> condition;

  String get key {
    final keys = condition.keys.toList()..sort();
    return '$type/$version/${[for (final k in keys) '$k=${condition[k]}'].join('&')}';
  }

  @override
  bool operator ==(Object other) => other is EventSubTopic && other.key == key;

  @override
  int get hashCode => key.hashCode;
}

/// What a topic listener receives.
sealed class EventSubTopicEvent {
  const EventSubTopicEvent();
}

/// An event of the topic (its `event` object).
final class EventSubData extends EventSubTopicEvent {
  const EventSubData(this.event, {this.sentAt});

  final Map<String, Object?> event;
  final DateTime? sentAt;
}

/// The topic is (again) being listened to. [afterGap]: events sent while
/// it was not were missed.
final class EventSubListening extends EventSubTopicEvent {
  const EventSubListening({required this.afterGap});

  final bool afterGap;
}

/// The topic cannot be listened to right now ([permanent]: not before the
/// app comes back from the background or the topic is listened to again).
final class EventSubUnavailable extends EventSubTopicEvent {
  const EventSubUnavailable(this.reason, {this.permanent = false});

  final String reason;
  final bool permanent;
}

/// Creates the subscription of [topic] for the session [sessionId] (Helix
/// `POST /eventsub/subscriptions`) and returns its id.
typedef EventSubCreate =
    Future<String> Function(EventSubTopic topic, String sessionId);

/// Deletes a subscription (Helix `DELETE /eventsub/subscriptions`).
typedef EventSubDelete = Future<void> Function(String subscriptionId);

/// A handle on one topic; [cancel] when done (idempotent).
class EventSubHandle {
  EventSubHandle._(this.topic, this.events, this._cancel);

  /// A handle backed by any stream, for consumers' tests.
  @visibleForTesting
  EventSubHandle.forTesting(this.topic, this.events, void Function() cancel)
    : _cancel = cancel;

  final EventSubTopic topic;
  final Stream<EventSubTopicEvent> events;
  final void Function() _cancel;
  var _cancelled = false;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _cancel();
  }
}

class _Entry {
  _Entry(this.topic);

  final EventSubTopic topic;
  final controller = StreamController<EventSubTopicEvent>.broadcast();
  var refCount = 0;
  String? subscriptionId;
  var creating = false;
  var everListened = false;

  /// Refused for good (until listened to anew or the app resumes).
  var failed = false;
  Timer? releaseTimer;

  /// The last status, replayed to each new listener.
  EventSubTopicEvent? status;

  late final Stream<EventSubTopicEvent> events = Stream.multi((listener) {
    final current = status;
    if (current != null) {
      listener.add(
        current is EventSubListening
            ? const EventSubListening(afterGap: false)
            : current,
      );
    }
    final subscription = controller.stream.listen(
      listener.add,
      onDone: listener.close,
    );
    listener
      ..onPause = subscription.pause
      ..onResume = subscription.resume
      ..onCancel = () => unawaited(subscription.cancel());
  });

  bool get wanted => refCount > 0 && !failed;

  void emit(EventSubTopicEvent event) {
    if (event is! EventSubData) status = event;
    if (!controller.isClosed) controller.add(event);
  }
}

/// One EventSub websocket for the logged-in user's events (whispers, …),
/// isolated from chat and video: a failure only reaches the listeners as
/// [EventSubUnavailable].
///
/// Connects on the first listener, creates each topic's subscription for
/// the session through [EventSubCreate], follows `session_reconnect`
/// without losing the subscriptions, watches keepalives, reconnects with
/// backoff (a new session, so it subscribes again), drops duplicate
/// messages, and sleeps after a minute in the background.
class TwitchEventSubClient {
  TwitchEventSubClient({
    required EventSubCreate create,
    required EventSubDelete delete,
    RealtimeSocketFactory? connect,
    Uri? endpoint,
    Random? random,
    this.idleClose = const Duration(seconds: 5),
    this.backgroundGrace = const Duration(seconds: 60),
    this.releaseDelay = const Duration(milliseconds: 500),
  }) : _create = create,
       _delete = delete,
       _connect = connect ?? WebSocketChannelSocket.new,
       _endpoint = endpoint ?? eventSubEndpoint,
       _random = random ?? Random.secure();

  final EventSubCreate _create;
  final EventSubDelete _delete;
  final RealtimeSocketFactory _connect;
  final Uri _endpoint;
  final Random _random;
  final Duration idleClose;
  final Duration backgroundGrace;
  final Duration releaseDelay;

  static const _backoff = [1, 2, 4, 8, 16, 30];
  static const _healthySession = Duration(seconds: 60);
  static const _watchdogMargin = Duration(seconds: 5);
  static const _seenLimit = 200;

  final _entries = <EventSubTopic, _Entry>{};
  final _seen = <String>{};

  RealtimeSocket? _socket;
  StreamSubscription<String>? _socketSubscription;

  /// The socket a `session_reconnect` moves to, until its welcome.
  RealtimeSocket? _next;
  StreamSubscription<String>? _nextSubscription;

  String? _sessionId;

  /// Bumped on every new session (not on a move, which keeps them).
  var _session = 0;
  var _attempt = 0;
  var _keepalive = const Duration(seconds: 10);
  var _paused = false;
  var _disposed = false;
  var _fatal = false;

  Timer? _watchdog;
  Timer? _healthyTimer;
  Timer? _reconnectTimer;
  Timer? _idleTimer;
  Timer? _graceTimer;

  /// Starts listening to [topic].
  EventSubHandle listen(EventSubTopic topic) {
    if (_disposed) throw StateError('TwitchEventSubClient is disposed');
    _idleTimer?.cancel();
    final entry = _entries.putIfAbsent(topic, () => _Entry(topic));
    entry.releaseTimer?.cancel();
    if (entry.refCount == 0) entry.failed = false;
    entry.refCount++;
    if (_fatal) {
      entry.emit(const EventSubUnavailable('closed', permanent: true));
    } else if (_socket == null) {
      if (!_paused && !(_reconnectTimer?.isActive ?? false)) _open();
    } else if (_sessionId != null) {
      _subscribe(entry);
    }
    return EventSubHandle._(topic, entry.events, () => _release(entry));
  }

  void _release(_Entry entry) {
    if (_disposed) return;
    entry.refCount--;
    if (entry.refCount > 0) return;
    entry.releaseTimer?.cancel();
    // A quick switch back keeps the subscription.
    entry.releaseTimer = Timer(releaseDelay, () {
      if (entry.refCount > 0) return;
      final id = entry.subscriptionId;
      if (id != null) _deleteQuietly(id);
      _entries.remove(entry.topic);
      unawaited(entry.controller.close());
      if (!_entries.values.any((e) => e.wanted)) {
        _reconnectTimer?.cancel();
        _idleTimer?.cancel();
        // Twitch closes a session without subscriptions anyway.
        _idleTimer = Timer(idleClose, () {
          if (_entries.values.any((e) => e.wanted)) return;
          _dropSockets();
          _attempt = 0;
        });
      }
    });
  }

  void onAppPaused() {
    if (_disposed) return;
    _graceTimer?.cancel();
    _graceTimer = Timer(backgroundGrace, () {
      _paused = true;
      _reconnectTimer?.cancel();
      _dropSockets();
    });
  }

  void onAppResumed() {
    if (_disposed) return;
    _graceTimer?.cancel();
    final wasPaused = _paused;
    _paused = false;
    if (wasPaused || _fatal) {
      _fatal = false;
      _attempt = 0;
      for (final entry in _entries.values) {
        entry.failed = false;
      }
      if (_entries.values.any((e) => e.wanted)) _open();
    } else if ((_reconnectTimer?.isActive ?? false) &&
        _entries.values.any((e) => e.wanted)) {
      // Back from a short background: don't sit out the rest of a backoff.
      _attempt = 0;
      _open();
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
    for (final entry in _entries.values) {
      entry.releaseTimer?.cancel();
      final id = entry.subscriptionId;
      if (id != null) _deleteQuietly(id);
      unawaited(entry.controller.close());
    }
    _entries.clear();
    _dropSockets();
  }

  // --- Connection -------------------------------------------------------------

  void _open() {
    _reconnectTimer?.cancel();
    _dropSockets();
    if (!_entries.values.any((e) => e.wanted)) return;
    final RealtimeSocket socket;
    try {
      socket = _connect(_endpoint);
    } catch (e) {
      _log('connect failed: $e');
      _scheduleReconnect();
      return;
    }
    _socket = socket;
    _sessionId = null;
    // No welcome within the window counts as a dead connection too.
    _armWatchdog();
    _socketSubscription = socket.messages.listen(
      (text) => _onText(socket, text),
      onError: (Object e) => _onClosed(socket),
      onDone: () => _onClosed(socket),
      cancelOnError: true,
    );
  }

  /// Opens the socket a `session_reconnect` names, keeping the current one
  /// until the new one is welcomed.
  void _move(Uri url) {
    _dropNext();
    final RealtimeSocket socket;
    try {
      socket = _connect(url);
    } catch (e) {
      _log('move failed: $e');
      return;
    }
    _next = socket;
    _nextSubscription = socket.messages.listen(
      (text) => _onText(socket, text),
      onError: (Object e) => _onClosed(socket),
      onDone: () => _onClosed(socket),
      cancelOnError: true,
    );
  }

  void _dropNext() {
    final next = _next;
    _next = null;
    unawaited(_nextSubscription?.cancel());
    _nextSubscription = null;
    if (next != null) unawaited(next.close(1000));
  }

  /// Closes the sockets without reacting to their close. The session (and
  /// its subscriptions) ends with them.
  void _dropSockets() {
    _watchdog?.cancel();
    _healthyTimer?.cancel();
    _dropNext();
    final socket = _socket;
    _socket = null;
    _sessionId = null;
    for (final entry in _entries.values) {
      entry.subscriptionId = null;
    }
    unawaited(_socketSubscription?.cancel());
    _socketSubscription = null;
    if (socket != null) unawaited(socket.close(1000));
  }

  void _onClosed(RealtimeSocket socket) {
    if (_disposed) return;
    if (identical(socket, _next)) {
      // The move failed; the current socket carries on until it closes.
      _next = null;
      _nextSubscription = null;
      return;
    }
    if (!identical(socket, _socket)) return;
    final code = socket.closeCode;
    _log('closed ($code)');
    _socket = null;
    _socketSubscription = null;
    final next = _next;
    if (next != null) {
      // Twitch closes the old socket once the new one is up: keep waiting
      // for the new one's welcome.
      _socket = next;
      _socketSubscription = _nextSubscription;
      _next = null;
      _nextSubscription = null;
      _armWatchdog();
      return;
    }
    _dropSockets();
    if (classifyEventSubClose(code) == EventSubCloseKind.fatal) {
      _fatal = true;
      for (final entry in _entries.values) {
        entry.emit(EventSubUnavailable('closed $code', permanent: true));
      }
      return;
    }
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed || _paused) return;
    final wanted = _entries.values.where((e) => e.wanted).toList();
    if (wanted.isEmpty) return;
    for (final entry in wanted) {
      entry.emit(const EventSubUnavailable('reconnecting'));
    }
    final base = _backoff[min(_attempt, _backoff.length - 1)] * 1000;
    final jitter = 0.8 + _random.nextDouble() * 0.4;
    _attempt++;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(
      Duration(milliseconds: (base * jitter).round()),
      _open,
    );
  }

  void _armWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer(_keepalive + _watchdogMargin, () {
      _log('keepalive missed');
      if (_socket == null) return;
      _dropSockets();
      _scheduleReconnect();
    });
  }

  // --- Frames -----------------------------------------------------------------

  void _onText(RealtimeSocket socket, String text) {
    final frame = decodeEventSubFrame(text);
    if (identical(socket, _next)) {
      if (frame is EventSubWelcome) _onMoved(frame);
      return;
    }
    if (!identical(socket, _socket)) return;
    _armWatchdog();
    switch (frame) {
      case EventSubWelcome(:final sessionId, :final keepalive):
        _sessionId = sessionId;
        _keepalive = keepalive;
        _session++;
        _armWatchdog();
        _healthyTimer?.cancel();
        _healthyTimer = Timer(_healthySession, () => _attempt = 0);
        for (final entry in _entries.values) {
          entry.subscriptionId = null;
          if (entry.wanted) _subscribe(entry);
        }
      case EventSubNotification(
        :final messageId,
        :final subscriptionId,
        :final event,
        :final sentAt,
      ):
        if (!_seen.add(messageId)) return;
        while (_seen.length > _seenLimit) {
          _seen.remove(_seen.first);
        }
        _entryFor(subscriptionId)?.emit(EventSubData(event, sentAt: sentAt));
      case EventSubReconnect(:final url):
        _log('server moves the session');
        _move(url);
      case EventSubRevocation(:final subscriptionId, :final status):
        final entry = _entryFor(subscriptionId);
        if (entry == null) return;
        entry
          ..subscriptionId = null
          ..failed = true
          ..emit(EventSubUnavailable(status, permanent: true));
      case EventSubKeepalive() || EventSubUnknown() || EventSubMalformed():
        break;
    }
  }

  /// The moved session is up: it keeps the subscriptions and the old
  /// socket goes.
  void _onMoved(EventSubWelcome welcome) {
    final old = _socket;
    final oldSubscription = _socketSubscription;
    _socket = _next;
    _socketSubscription = _nextSubscription;
    _next = null;
    _nextSubscription = null;
    _sessionId = welcome.sessionId;
    _keepalive = welcome.keepalive;
    _armWatchdog();
    unawaited(oldSubscription?.cancel());
    if (old != null) unawaited(old.close(1000));
  }

  _Entry? _entryFor(String subscriptionId) {
    for (final entry in _entries.values) {
      if (entry.subscriptionId == subscriptionId) return entry;
    }
    return null;
  }

  Future<void> _subscribe(_Entry entry) async {
    final sessionId = _sessionId;
    if (sessionId == null || entry.creating || entry.subscriptionId != null) {
      return;
    }
    entry.creating = true;
    final session = _session;
    try {
      final id = await _create(entry.topic, sessionId);
      if (_disposed || session != _session || !entry.wanted) {
        // Made for a session that ended, or no longer wanted.
        if (session == _session) _deleteQuietly(id);
        return;
      }
      entry.subscriptionId = id;
      entry.emit(EventSubListening(afterGap: entry.everListened));
      entry.everListened = true;
    } catch (e) {
      _log('subscribe ${entry.topic.type} failed: $e');
      if (session != _session) return;
      // A refusal (no scope, logged out, bad condition) will not change
      // by itself; anything else may on the next session.
      final permanent = e is ApiException && _refused(e.statusCode);
      if (permanent) entry.failed = true;
      entry.emit(EventSubUnavailable('$e', permanent: permanent));
    } finally {
      entry.creating = false;
    }
  }

  static bool _refused(int? status) =>
      status == 400 || status == 401 || status == 403 || status == 404;

  void _deleteQuietly(String subscriptionId) {
    unawaited(
      _delete(subscriptionId).catchError((Object e) {
        _log('delete failed: $e');
      }),
    );
  }

  void _log(String message) {
    if (kDebugMode) debugPrint('TwitchEventSubClient $message');
  }
}
