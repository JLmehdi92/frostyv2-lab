import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:mobx/mobx.dart';
import 'package:onset/apis/base_api_client.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/l10n/api_errors.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/whisper_history.dart';
import 'package:onset/services/realtime/twitch_eventsub_client.dart';
import 'package:onset/services/telemetry.dart';

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
/// the Indic ones they stay. A run of joiners is judged as one, and the
/// rule applies once the other invisibles are gone, so neither another
/// joiner nor another invisible can shield one.
final _strayJoiner = RegExp(
  '(?<=[\u0000-\u024f])[\u200c\u200d]+'
  '|[\u200c\u200d]+(?=[\u0000-\u024f]|\$)'
  '|^[\u200c\u200d]+',
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

  static bool _sameWhisper(Whisper a, Whisper b) =>
      a.mine == b.mine &&
      a.text == b.text &&
      a.sentAt.difference(b.sentAt).abs() < const Duration(minutes: 2);

  @action
  bool _merge(Whisper whisper) {
    if (whispers.any((w) => w.id == whisper.id || _sameWhisper(w, whisper))) {
      return false;
    }
    final index = whispers.indexWhere((w) => w.sentAt.isAfter(whisper.sentAt));
    if (index < 0) {
      whispers.add(whisper);
    } else {
      whispers.insert(index, whisper);
    }
    if (whispers.length > maxWhispers) {
      whispers.removeRange(0, whispers.length - maxWhispers);
    }
    final latest = whispers.last.sentAt;
    if (lastAt == null || latest.isAfter(lastAt!)) lastAt = latest;
    return true;
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
    Set<String> mutedUserIds = const {},
    Set<String> archivedUserIds = const {},
    void Function(Set<String> muted, Set<String> archived)?
    onPreferencesChanged,
    this.historyThreads,
    this.historyMessages,
  }) : _listen = listen,
       _onPreferencesChanged = onPreferencesChanged {
    _muted.addAll(mutedUserIds);
    _archived.addAll(archivedUserIds);
    _userReaction = reaction(
      (_) => (currentUserId(), credentials?.call()),
      (session) => _follow(session.$1),
      fireImmediately: true,
    );
  }

  final TwitchApi twitchApi;
  final EventSubHandle Function(EventSubTopic topic) _listen;
  final void Function(Set<String> muted, Set<String> archived)?
  _onPreferencesChanged;

  final _muted = ObservableSet<String>();
  final _archived = ObservableSet<String>();

  final Future<List<WhisperHistoryThread>?> Function(String me)?
  historyThreads;
  final Future<List<WhisperHistoryMessage>?> Function(String threadId)?
  historyMessages;

  final _remoteThreadIds = <String, String>{};
  final _hiddenAt = <String, DateTime>{};

  @readonly
  bool? _historyAvailable;

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
  List<WhisperThread> get threads =>
      _sorted(_threads.values.where((t) => !_archived.contains(t.userId)));

  @computed
  List<WhisperThread> get archivedThreads =>
      _sorted(_threads.values.where((t) => _archived.contains(t.userId)));

  List<WhisperThread> _sorted(Iterable<WhisperThread> threads) =>
      threads.toList()..sort(
        (a, b) => (b.lastAt ?? DateTime(0)).compareTo(a.lastAt ?? DateTime(0)),
      );

  @computed
  int get unreadCount => threads
      .where((t) => !_muted.contains(t.userId))
      .fold(0, (sum, t) => sum + t.unread);

  bool isMuted(String userId) => _muted.contains(userId);

  bool isArchived(String userId) => _archived.contains(userId);

  @action
  void toggleMute(String userId) {
    if (!_muted.remove(userId)) _muted.add(userId);
    _savePreferences();
  }

  @action
  void archive(String userId) {
    _archived.add(userId);
    _savePreferences();
  }

  @action
  void unarchive(String userId) {
    if (_archived.remove(userId)) _savePreferences();
  }

  String? remoteThreadId(String userId) => _remoteThreadIds[userId];

  static const historyRefreshGap = Duration(seconds: 30);
  DateTime? _historyAskedAt;

  Future<void> refreshHistory() async {
    final me = _me;
    final fetch = historyThreads;
    if (me == null || fetch == null) return;
    final now = clock.now();
    final asked = _historyAskedAt;
    if (asked != null && now.difference(asked) < historyRefreshGap) return;
    _historyAskedAt = now;
    final threads = await fetch(me);
    if (_me != me) return;
    runInAction(() {
      _historyAvailable = threads != null;
      if (threads == null) return;
      for (final remote in threads) {
        _remoteThreadIds[remote.peer.id] = remote.id;
        final last = remote.last;
        final hiddenAt = _hiddenAt[remote.peer.id];
        if (last == null) continue;
        if (hiddenAt != null && !last.sentAt.isAfter(hiddenAt)) continue;
        thread(
          userId: remote.peer.id,
          login: remote.peer.login,
          displayName: remote.peer.displayName,
        )._merge(_fromHistory(last, me));
      }
    });
  }

  Future<void> loadConversation(String userId) async {
    final me = _me;
    final threadId = _remoteThreadIds[userId];
    final fetch = historyMessages;
    if (me == null || threadId == null || fetch == null) return;
    final messages = await fetch(threadId);
    if (_me != me || messages == null) return;
    runInAction(() {
      final target = _threads[userId];
      if (target == null) return;
      for (final message in messages) {
        target._merge(_fromHistory(message, me));
      }
    });
  }

  static Whisper _fromHistory(WhisperHistoryMessage message, String me) =>
      Whisper(
        id: message.id,
        text: message.text,
        mine: message.fromId == me,
        sentAt: message.sentAt,
      );

  @action
  void hide(String userId) {
    _hiddenAt[userId] = clock.now();
    _threads.remove(userId);
    _openUserIds.removeWhere((id) => id == userId);
    unarchive(userId);
  }

  void _savePreferences() =>
      _onPreferencesChanged?.call({..._muted}, {..._archived});

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
    _remoteThreadIds.clear();
    _hiddenAt.clear();
    _historyAskedAt = null;
    _historyAvailable = null;
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
        unarchive(thread.userId);
        if (!_incoming.isClosed && !isMuted(thread.userId)) {
          _incoming.add(incoming);
        }
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
  Future<WhisperFailure?> sendTo({
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
  Future<WhisperFailure?> send(WhisperThread thread, String text) =>
      _send(thread, text, adopt: false);

  /// [adopt]: [thread] is new, kept only if the whisper goes.
  Future<WhisperFailure?> _send(
    WhisperThread thread,
    String text, {
    required bool adopt,
  }) async {
    final me = _me;
    if (me == null) return const WhisperLoggedOut();
    // A screen kept from before an account switch.
    if (!adopt && !identical(_threads[thread.userId], thread)) {
      return const WhisperOtherAccount();
    }
    final message = text.trim();
    if (message.isEmpty) return null;
    if (message.length > TwitchApi.maxWhisperLength) {
      return const WhisperTooLong(TwitchApi.maxWhisperLength);
    }
    try {
      await twitchApi.sendWhisper(
        fromUserId: me,
        toUserId: thread.userId,
        message: message,
      );
    } on UnauthorizedException {
      return const WhisperLogInAgain();
    } on ApiException catch (e) {
      return WhisperRefused(e);
    } catch (e, stack) {
      // A bug, or Twitch changed something (never the whisper's text).
      Telemetry.recordError(e, stack, reason: 'whisper send');
      return const WhisperUnexpected();
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

/// Why a whisper was not sent; [text] words it in a language.
sealed class WhisperFailure {
  const WhisperFailure();

  /// The line saying why, in [l]'s language.
  String text(AppLocalizations l);
}

/// No one is logged in.
final class WhisperLoggedOut extends WhisperFailure {
  const WhisperLoggedOut();

  @override
  String text(AppLocalizations l) => l.chatLogInToWhisper;
}

/// The conversation on screen was opened with another account.
final class WhisperOtherAccount extends WhisperFailure {
  const WhisperOtherAccount();

  @override
  String text(AppLocalizations l) => l.whisperOtherAccount;
}

/// Longer than Twitch takes ([max] characters).
final class WhisperTooLong extends WhisperFailure {
  const WhisperTooLong(this.max);

  final int max;

  @override
  String text(AppLocalizations l) => l.whisperTooLong(max: max);
}

/// The login predates the whisper permission.
final class WhisperLogInAgain extends WhisperFailure {
  const WhisperLogInAgain();

  @override
  String text(AppLocalizations l) => l.whisperLogInAgain;
}

/// Twitch refused it, or could not be reached.
final class WhisperRefused extends WhisperFailure {
  const WhisperRefused(this.error);

  final ApiException error;

  @override
  String text(AppLocalizations l) =>
      l.chatWhisperFailedBecause(reason: chatErrorText(l, error));
}

/// Something unexpected (a bug, or a Twitch change).
final class WhisperUnexpected extends WhisperFailure {
  const WhisperUnexpected();

  @override
  String text(AppLocalizations l) => l.whisperFailedUnexpected;
}
