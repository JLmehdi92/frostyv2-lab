import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mobx/mobx.dart';
import 'package:onset/apis/base_api_client.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/apis/twitch_mod_api.dart';
import 'package:onset/l10n/api_errors.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/channel/chat/mod_tools/mod_action_text.dart';
import 'package:onset/screens/channel/chat/mod_tools/mod_events.dart';
import 'package:onset/screens/channel/chat/mod_tools/mod_features.dart';
import 'package:onset/services/realtime/twitch_eventsub_client.dart';

part 'mod_tools_store.g.dart';

enum ModToolsView { hub, autoMod, moderators, vips }

typedef ModChatLine =
    void Function(String text, {String? actionLabel, VoidCallback? onAction});

@immutable
class UserModStatus {
  const UserModStatus({
    this.banned = false,
    this.timeoutUntil,
    this.warned = false,
    this.suspicion,
  });

  final bool banned;
  final DateTime? timeoutUntil;
  final bool warned;
  final SuspiciousStatus? suspicion;

  bool timedOutAt(DateTime now) =>
      !banned && timeoutUntil != null && timeoutUntil!.isAfter(now);

  UserModStatus copyWith({
    bool? banned,
    DateTime? Function()? timeoutUntil,
    bool? warned,
    SuspiciousStatus? Function()? suspicion,
  }) => UserModStatus(
    banned: banned ?? this.banned,
    timeoutUntil: timeoutUntil == null ? this.timeoutUntil : timeoutUntil(),
    warned: warned ?? this.warned,
    suspicion: suspicion == null ? this.suspicion : suspicion(),
  );
}

class ModToolsStore = ModToolsBase with _$ModToolsStore;

abstract class ModToolsBase with Store {
  ModToolsBase({
    required this.twitchApi,
    required this.broadcasterId,
    required this.onChatLine,
    this.listenEvents,
    bool Function()? showActionsInChat,
    DateTime Function()? clock,
  }) : _showActionsInChat = showActionsInChat ?? (() => true),
       _clock = clock ?? DateTime.now;

  final TwitchApi twitchApi;
  final String broadcasterId;
  final ModChatLine onChatLine;
  final EventSubHandle Function(EventSubTopic topic)? listenEvents;
  final bool Function() _showActionsInChat;
  final DateTime Function() _clock;

  static const maxActions = 200;
  static const maxHeldMessages = 100;
  static const maxUserStatuses = 500;

  final _handles = <EventSubHandle>[];
  final _subscriptions = <StreamSubscription<EventSubTopicEvent>>[];
  final _requests = StreamController<ModToolsView>.broadcast();
  var _session = 0;

  Stream<ModToolsView> get requests => _requests.stream;

  @readonly
  String? _moderatorId;

  @readonly
  Set<String>? _scopes;

  @readonly
  var _shieldActive = false;

  final actions = ObservableList<ModActionEntry>();

  final heldMessages = ObservableList<HeldMessage>();

  final userStatuses = ObservableMap<String, UserModStatus>();

  @computed
  bool get isBroadcaster => _moderatorId == broadcasterId;

  @computed
  int get pendingHeldCount => heldMessages.where((m) => m.isPending).length;

  bool canUse(ModFeature feature) {
    final scopes = _scopes;
    if (scopes == null || _moderatorId == null) return false;
    if (feature.broadcasterOnly && !isBroadcaster) return false;
    return scopes.containsAll(feature.scopes);
  }

  bool needsLogin(ModFeature feature) {
    final scopes = _scopes;
    if (scopes == null) return false;
    if (feature.broadcasterOnly && !isBroadcaster) return false;
    return !scopes.containsAll(feature.scopes);
  }

  bool shows(ModFeature feature) =>
      _moderatorId != null && (!feature.broadcasterOnly || isBroadcaster);

  void request(ModToolsView view) {
    if (!_requests.isClosed) _requests.add(view);
  }

  Future<void> start(String moderatorId) async {
    stop();
    final session = ++_session;
    runInAction(() => _moderatorId = moderatorId);
    Set<String> scopes;
    try {
      scopes = await twitchApi.getTokenScopes();
    } catch (error) {
      debugPrint('Mod tools scopes unreadable: $error');
      scopes = const {};
    }
    if (session != _session) return;
    runInAction(() => _scopes = scopes);
    _listen();
    if (canUse(ModFeature.shieldMode)) unawaited(_loadShieldMode(session));
  }

  @action
  void stop() {
    _session++;
    for (final handle in _handles) {
      handle.cancel();
    }
    _handles.clear();
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    _moderatorId = null;
    _scopes = null;
    _shieldActive = false;
    heldMessages.clear();
  }

  void dispose() {
    stop();
    unawaited(_requests.close());
  }

  Future<void> _loadShieldMode(int session) async {
    final moderator = _moderatorId;
    if (moderator == null) return;
    try {
      final status = await twitchApi.moderation.getShieldMode(
        broadcasterId: broadcasterId,
        moderatorId: moderator,
      );
      if (session == _session) {
        runInAction(() => _shieldActive = status.isActive);
      }
    } catch (error) {
      debugPrint('Shield mode unreadable: $error');
    }
  }

  void _listen() {
    final listen = listenEvents;
    final moderator = _moderatorId;
    if (listen == null || moderator == null) return;
    final condition = {
      'broadcaster_user_id': broadcasterId,
      'moderator_user_id': moderator,
    };
    void on(
      String type,
      String version,
      void Function(Map<String, Object?> event) handle,
    ) {
      final handleOf = listen(EventSubTopic(type, version, condition));
      _handles.add(handleOf);
      _subscriptions.add(
        handleOf.events.listen((event) {
          if (event is! EventSubData) return;
          try {
            handle(event.event);
          } catch (error) {
            debugPrint('Mod event dropped (${error.runtimeType})');
          }
        }),
      );
    }

    if (canUse(ModFeature.actionFeed)) {
      on('channel.moderate', '2', _onModerate);
    }
    if (canUse(ModFeature.shieldMode)) {
      on('channel.shield_mode.begin', '1', (e) => _onShield(e, active: true));
      on('channel.shield_mode.end', '1', (e) => _onShield(e, active: false));
    }
    if (canUse(ModFeature.autoMod)) {
      on('automod.message.hold', '2', _onHeld);
      on('automod.message.update', '2', _onHeldUpdate);
    }
  }

  @action
  void _onModerate(Map<String, Object?> event) {
    final entry = parseModerateEvent(event, now: _clock());
    if (entry == null) return;
    actions.insert(0, entry);
    if (actions.length > maxActions) actions.removeLast();
    _noteAction(entry);
    if (_showActionsInChat()) {
      onChatLine(modActionLine(L10n.current, entry));
    }
  }

  void _noteAction(ModActionEntry entry) {
    final id = entry.userId;
    if (id == null) return;
    switch (entry.action) {
      case 'ban':
        _update(id, (s) => s.copyWith(banned: true, timeoutUntil: () => null));
      case 'timeout':
        _update(id, (s) => s.copyWith(timeoutUntil: () => entry.timeoutEndsAt));
      case 'unban' || 'untimeout':
        _update(id, (s) => s.copyWith(banned: false, timeoutUntil: () => null));
      case 'warn':
        _update(id, (s) => s.copyWith(warned: true));
    }
  }

  void _update(String userId, UserModStatus Function(UserModStatus) change) {
    final current = userStatuses.remove(userId) ?? const UserModStatus();
    userStatuses[userId] = change(current);
    while (userStatuses.length > maxUserStatuses) {
      userStatuses.remove(userStatuses.keys.first);
    }
  }

  @action
  void noteClearChat(String? userId, int? banSeconds) {
    if (userId == null || userId.isEmpty) return;
    if (banSeconds == null) {
      _update(
        userId,
        (s) => s.copyWith(banned: true, timeoutUntil: () => null),
      );
    } else {
      final until = _clock().add(Duration(seconds: banSeconds));
      _update(userId, (s) => s.copyWith(timeoutUntil: () => until));
    }
  }

  @action
  void noteShieldMode(bool active) => _shieldActive = active;

  @action
  void noteSuspicion(String userId, SuspiciousStatus? status) =>
      _update(userId, (s) => s.copyWith(suspicion: () => status));

  @action
  void _onShield(Map<String, Object?> event, {required bool active}) {
    if (_shieldActive == active) return;
    _shieldActive = active;
    final moderator = shieldModerator(event);
    final l = L10n.current;
    onChatLine(
      moderator == null
          ? l.chatModShield(state: OnOff.of(active).name)
          : l.chatShieldModeChangedBy(
              moderator: moderator,
              state: OnOff.of(active).name,
            ),
    );
  }

  @action
  void _onHeld(Map<String, Object?> event) {
    final message = parseHeldMessage(event);
    if (message == null || heldMessages.any((m) => m.id == message.id)) {
      return;
    }
    heldMessages.insert(0, message);
    if (heldMessages.length > maxHeldMessages) heldMessages.removeLast();
    final l = L10n.current;
    onChatLine(
      l.chatAutoModHeld(name: message.userName),
      actionLabel: l.chatAutoModReview,
      onAction: () => request(ModToolsView.autoMod),
    );
  }

  @action
  void _onHeldUpdate(Map<String, Object?> event) {
    final update = parseHeldMessageUpdate(event);
    if (update == null) return;
    _setHeldStatus(update.id, update.status);
  }

  void _setHeldStatus(String id, HeldMessageStatus status) {
    final index = heldMessages.indexWhere((m) => m.id == id);
    if (index < 0) return;
    heldMessages[index] = heldMessages[index].withStatus(status);
  }

  @action
  void clearResolvedHeld() => heldMessages.removeWhere((m) => !m.isPending);

  Future<String?> resolveHeld(String id, AutoModDecision decision) async {
    final moderator = _moderatorId;
    if (moderator == null) return L10n.current.chatLogInToModerate;
    try {
      await twitchApi.moderation.resolveHeldMessage(
        moderatorId: moderator,
        messageId: id,
        decision: decision,
      );
      runInAction(
        () => _setHeldStatus(
          id,
          decision == AutoModDecision.allow
              ? HeldMessageStatus.approved
              : HeldMessageStatus.denied,
        ),
      );
      return null;
    } catch (error) {
      return modToolsFailure(
        error,
        decision == AutoModDecision.allow ? 'allowMessage' : 'denyMessage',
      );
    }
  }

  Future<String?> setShieldMode(bool active) async {
    final moderator = _moderatorId;
    if (moderator == null) return L10n.current.chatLogInToModerate;
    try {
      final status = await twitchApi.moderation.setShieldMode(
        broadcasterId: broadcasterId,
        moderatorId: moderator,
        active: active,
      );
      runInAction(() => _shieldActive = status.isActive);
      return null;
    } catch (error) {
      return modToolsFailure(error, active ? 'shieldOn' : 'shieldOff');
    }
  }

  Future<void> loadBan(String userId) async {
    if (!canUse(ModFeature.bans)) return;
    try {
      final ban = await twitchApi.moderation.getBan(
        broadcasterId: broadcasterId,
        userId: userId,
      );
      runInAction(
        () => _update(
          userId,
          (s) => s.copyWith(
            banned: ban != null && ban.timeoutEndsAt == null,
            timeoutUntil: () => ban?.timeoutEndsAt,
          ),
        ),
      );
    } catch (error) {
      debugPrint('Ban status unreadable: $error');
    }
  }

  UserModStatus statusOf(String userId) =>
      userStatuses[userId] ?? const UserModStatus();
}

String modToolsFailure(Object error, String command) {
  final l = L10n.current;
  return switch (error) {
    UnauthorizedException() => l.chatModLogInAgain,
    ApiException(statusCode: 403) => l.chatModFailed(
      command: command,
      reason: l.chatModCannotModerate,
    ),
    final ApiException error => l.chatModFailed(
      command: command,
      reason: chatErrorText(l, error),
    ),
    _ => l.chatModFailedUnexpected(command: command),
  };
}
