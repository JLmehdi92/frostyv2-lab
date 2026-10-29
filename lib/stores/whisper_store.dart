import 'dart:async';

import 'package:clock/clock.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:frosty/apis/base_api_client.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/services/realtime/twitch_eventsub_client.dart';
import 'package:mobx/mobx.dart';

part 'whisper_store.g.dart';

final _numericId = RegExp(r'^[0-9]{1,20}$');
final _login = RegExp(r'^[a-zA-Z0-9_]{1,25}$');

final _unsafeForPreview = RegExp(
  '[\u0000-\u001f\u007f-\u009f\u061c\u200e\u200f\u2028\u2029'
  '\u202a-\u202e\u2066-\u2069]',
);

/// Characters that take no room: dropped, so a name cannot hide a
/// difference from another one.
final _invisibleForPreview = RegExp('[\u200b\u2060\ufeff]');

/// The joiners (U+200C, U+200D) where they mean nothing: beside a Latin
/// letter, digit or sign, or at either end, they only hide a difference
/// ("m\u200Cod"), and go. Between emoji or in scripts such as Persian or
/// the Indic ones they stay. Applied once the other invisibles are gone,
/// so none of them can shield a joiner.
final _strayJoiner = RegExp(
  '(?<=[\u0000-\u024f])[\u200c\u200d]'
  '|[\u200c\u200d](?=[\u0000-\u024f]|\$)'
  '|^[\u200c\u200d]',
);

/// [text] on one line for a preview or a notice: line breaks (Unicode's
/// too), control and direction characters become spaces and invisible
/// ones go, so a whisper cannot fake a second line or turn text around.
String whisperPreview(String text) => text
    .replaceAll(_invisibleForPreview, '')
    .replaceAll(_strayJoiner, '')
    .replaceAll(_unsafeForPreview, ' ')
    .replaceAll(RegExp(' {2,}'), ' ')
    .trim();

/// One whisper of a conversation.
@immutable
class Whisper {
  const Whisper({
    required this.id,
    required this.text,
    required this.mine,
    required this.sentAt,
  });

  final String id;
  final String text;

  /// Sent by the viewer (otherwise received).
  final bool mine;
  final DateTime sentAt;
}

/// A whisper received over EventSub (`user.whisper.message`).
typedef IncomingWhisper = ({
  String fromUserId,
  String fromLogin,
  String fromName,
  Whisper whisper,
});

/// The whisper in an EventSub `user.whisper.message` event addressed to
/// [me], or null when it is not one that can be read.
IncomingWhisper? whisperFromEvent(
  Map<String, Object?> event, {
  required String me,
  DateTime? sentAt,
}) {
  final fromId = event['from_user_id'];
  final fromLogin = event['from_user_login'];
  final toId = event['to_user_id'];
  final whisper = event['whisper'];
  final text = whisper is Map ? whisper['text'] : null;
  final id = event['whisper_id'];
  if (fromId is! String ||
      !_numericId.hasMatch(fromId) ||
      fromLogin is! String ||
      !_login.hasMatch(fromLogin) ||
      toId != me ||
      text is! String ||
      text.isEmpty ||
      text.length > TwitchApi.maxWhisperLength) {
    return null;
  }
  final name = event['from_user_name'];
  return (
    fromUserId: fromId,
    fromLogin: fromLogin.toLowerCase(),
    fromName: name is String && name.isNotEmpty && name.length <= 64
        ? name
        : fromLogin,
    whisper: Whisper(
      id: id is String && id.isNotEmpty
          ? id
          : 'in-${clock.now().microsecondsSinceEpoch}',
      text: text,
      mine: false,
      sentAt: sentAt ?? clock.now(),
    ),
  );
}

class WhisperThread = WhisperThreadBase with _$WhisperThread;

/// The whispers with one person, oldest first.
abstract class WhisperThreadBase with Store {
  WhisperThreadBase({
    required this.userId,
    required this.login,
    required this.displayName,
  });

  final String userId;
  final String login;
  final String displayName;

  /// At most this many whispers are kept per conversation.
  static const maxWhispers = 200;

  final whispers = ObservableList<Whisper>();

  /// Received since the conversation was last open.
  @observable
  var unread = 0;

  @observable
  DateTime? lastAt;

  @action
  void _add(Whisper whisper) {
    whispers.add(whisper);
    if (whispers.length > maxWhispers) {
      whispers.removeRange(0, whispers.length - maxWhispers);
    }
    lastAt = whisper.sentAt;
  }
}

/// Whether whispers arrive.
enum WhisperStatus {
  /// Logged out, or not started.
  off,
  connecting,
  listening,

  /// Not for now (reconnecting); it retries by itself.
  interrupted,

  /// Twitch refuses the token (from before the whisper scope, or
  /// revoked): logging in again fixes it.
  refused,

  /// Twitch refuses for another reason; retried when the app comes back
  /// from the background.
  unavailable,
}

class WhisperStore = WhisperStoreBase with _$WhisperStore;

/// The logged-in viewer's whispers: received over EventSub, sent through
/// Helix. Kept in memory for the session only: Twitch has no public
/// history to reload them from, and private messages are not written to
/// disk.
abstract class WhisperStoreBase with Store {
  WhisperStoreBase({
    required this.twitchApi,
    required EventSubHandle Function(EventSubTopic topic) listen,
    required String? Function() currentUserId,
    Object? Function()? credentials,
  }) : _listen = listen {
    _userReaction = reaction(
      (_) => (currentUserId(), credentials?.call()),
      (session) => _follow(session.$1),
      fireImmediately: true,
    );
  }

  final TwitchApi twitchApi;
  final EventSubHandle Function(EventSubTopic topic) _listen;

  /// At most this many conversations are kept (the oldest go first).
  static const maxThreads = 50;

  late final ReactionDisposer _userReaction;
  EventSubHandle? _handle;
  StreamSubscription<EventSubTopicEvent>? _events;

  final _incoming = StreamController<IncomingWhisper>.broadcast();

  /// Each whisper received, for in-app notices.
  Stream<IncomingWhisper> get incoming => _incoming.stream;

  final _threads = ObservableMap<String, WhisperThread>();

  @readonly
  String? _me;

  @readonly
  var _status = WhisperStatus.off;

  /// The conversations on screen, the visible one last (one can open
  /// over another).
  final _openUserIds = ObservableList<String>();

  /// The conversation on screen: what arrives there is read already.
  @computed
  String? get openUserId => _openUserIds.lastOrNull;

  /// Conversations, most recent first.
  @computed
  List<WhisperThread> get threads => _threads.values.toList()
    ..sort(
      (a, b) => (b.lastAt ?? DateTime(0)).compareTo(a.lastAt ?? DateTime(0)),
    );

  @computed
  int get unreadCount => _threads.values.fold(0, (sum, t) => sum + t.unread);

  /// Follows the viewer [me]. The same viewer again (a new token, after
  /// logging in again) listens anew, so a refusal gets another try.
  @action
  void _follow(String? me) {
    if (me != null && me == _me) {
      _listenTo(me);
      return;
    }
    _handle?.cancel();
    _handle = null;
    unawaited(_events?.cancel());
    _events = null;
    // Another account (or none): its whispers are not this one's.
    _threads.clear();
    _openUserIds.clear();
    _me = me;
    if (me == null) {
      _status = WhisperStatus.off;
      return;
    }
    _listenTo(me);
  }

  void _listenTo(String me) {
    final previous = _handle;
    final previousEvents = _events;
    _status = WhisperStatus.connecting;
    // The new handle first: the topic stays subscribed across the switch.
    final handle = _listen(
      EventSubTopic('user.whisper.message', '1', {'user_id': me}),
    );
    _handle = handle;
    _events = handle.events.listen(_onEvent);
    previous?.cancel();
    unawaited(previousEvents?.cancel());
  }

  @action
  void _onEvent(EventSubTopicEvent event) {
    switch (event) {
      case EventSubListening():
        _status = WhisperStatus.listening;
      case EventSubUnavailable(:final permanent, :final unauthorized):
        _status = !permanent
            ? WhisperStatus.interrupted
            : unauthorized
            ? WhisperStatus.refused
            : WhisperStatus.unavailable;
      case EventSubData(:final event, :final sentAt):
        final me = _me;
        if (me == null) return;
        final incoming = whisperFromEvent(event, me: me, sentAt: sentAt);
        if (incoming == null) {
          // Field names only: never the whisper.
          if (kDebugMode) {
            debugPrint('Whisper skipped, fields: ${event.keys.join(', ')}');
          }
          return;
        }
        final thread = this.thread(
          userId: incoming.fromUserId,
          login: incoming.fromLogin,
          displayName: incoming.fromName,
        );
        if (thread.whispers.any((w) => w.id == incoming.whisper.id)) return;
        thread._add(incoming.whisper);
        if (openUserId != thread.userId) thread.unread++;
        if (!_incoming.isClosed) _incoming.add(incoming);
    }
  }

  /// The conversation with someone (made when there is none), without
  /// opening it.
  @action
  WhisperThread thread({
    required String userId,
    required String login,
    required String displayName,
  }) {
    final thread = _threads.putIfAbsent(
      userId,
      () =>
          WhisperThread(userId: userId, login: login, displayName: displayName),
    );
    // The least recent others go (never this one, nor the one on screen).
    while (_threads.length > maxThreads) {
      final oldest = threads
          .where((t) => t.userId != userId && !_openUserIds.contains(t.userId))
          .lastOrNull;
      if (oldest == null) break;
      _threads.remove(oldest.userId);
    }
    return thread;
  }

  /// The conversation with someone, now on screen (its whispers read).
  @action
  WhisperThread open({
    required String userId,
    required String login,
    required String displayName,
  }) {
    final thread = this.thread(
      userId: userId,
      login: login,
      displayName: displayName,
    );
    thread.unread = 0;
    _openUserIds.add(userId);
    return thread;
  }

  /// The conversation with [userId] left the screen (the one under it, if
  /// any, is on screen again).
  @action
  void close(String userId) {
    final index = _openUserIds.lastIndexOf(userId);
    if (index >= 0) _openUserIds.removeAt(index);
  }

  /// Whispers [text] to someone, starting the conversation only once it
  /// went (`/w`). Null when sent, else why not.
  Future<String?> sendTo({
    required String userId,
    required String login,
    required String displayName,
    required String text,
  }) async {
    final existing = _threads[userId];
    final thread =
        existing ??
        WhisperThread(userId: userId, login: login, displayName: displayName);
    return _send(thread, text, adopt: existing == null);
  }

  /// Whispers [text] to [thread]'s person. Null when sent, else why not.
  Future<String?> send(WhisperThread thread, String text) =>
      _send(thread, text, adopt: false);

  /// [adopt]: [thread] is new, kept only if the whisper goes.
  Future<String?> _send(
    WhisperThread thread,
    String text, {
    required bool adopt,
  }) async {
    final me = _me;
    if (me == null) return 'Log in to whisper.';
    // A screen kept from before an account switch.
    if (!adopt && !identical(_threads[thread.userId], thread)) {
      return 'This conversation belongs to another account.';
    }
    final message = text.trim();
    if (message.isEmpty) return null;
    if (message.length > TwitchApi.maxWhisperLength) {
      return 'Whispers can be ${TwitchApi.maxWhisperLength} characters at most.';
    }
    try {
      await twitchApi.sendWhisper(
        fromUserId: me,
        toUserId: thread.userId,
        message: message,
      );
    } on UnauthorizedException {
      return 'Log in again to whisper from this app.';
    } on ApiException catch (e) {
      return "Couldn't whisper: ${e.message}";
    } catch (e, stack) {
      // A bug, or Twitch changed something (never the whisper's text).
      try {
        FirebaseCrashlytics.instance.recordError(
          e,
          stack,
          reason: 'whisper send',
        );
      } catch (_) {
        // Firebase may not be initialized (e.g., in tests).
      }
      return "Couldn't whisper (unexpected error).";
    }
    // The account changed meanwhile: not this conversation any more.
    if (_me != me) return null;
    runInAction(() {
      final target = adopt
          ? this.thread(
              userId: thread.userId,
              login: thread.login,
              displayName: thread.displayName,
            )
          : thread;
      target._add(
        Whisper(
          id: 'out-${clock.now().microsecondsSinceEpoch}',
          text: message,
          mine: true,
          sentAt: clock.now(),
        ),
      );
    });
    return null;
  }

  void dispose() {
    _userReaction();
    _handle?.cancel();
    unawaited(_events?.cancel());
    unawaited(_incoming.close());
  }
}
