import 'package:flutter/foundation.dart';

@immutable
class ModActionEntry {
  const ModActionEntry({
    required this.action,
    required this.moderatorName,
    required this.at,
    this.userId,
    this.userName,
    this.reason = '',
    this.timeoutEndsAt,
  });

  final String action;
  final String moderatorName;
  final DateTime at;
  final String? userId;
  final String? userName;
  final String reason;
  final DateTime? timeoutEndsAt;

  Duration? get timeoutLength => timeoutEndsAt?.difference(at);
}

enum HeldMessageStatus { pending, approved, denied, expired }

@immutable
class HeldMessage {
  const HeldMessage({
    required this.id,
    required this.userId,
    required this.userName,
    required this.text,
    required this.reason,
    required this.heldAt,
    this.category = '',
    this.level = 0,
    this.status = HeldMessageStatus.pending,
  });

  final String id;
  final String userId;
  final String userName;
  final String text;
  final String reason;
  final String category;
  final int level;
  final DateTime heldAt;
  final HeldMessageStatus status;

  bool get isPending => status == HeldMessageStatus.pending;

  HeldMessage withStatus(HeldMessageStatus status) => HeldMessage(
    id: id,
    userId: userId,
    userName: userName,
    text: text,
    reason: reason,
    heldAt: heldAt,
    category: category,
    level: level,
    status: status,
  );
}

const kModActions = {
  'ban',
  'timeout',
  'unban',
  'untimeout',
  'warn',
  'delete',
  'clear',
  'mod',
  'unmod',
  'vip',
  'unvip',
  'raid',
  'unraid',
  'add_blocked_term',
  'remove_blocked_term',
  'add_permitted_term',
  'remove_permitted_term',
  'approve_unban_request',
  'deny_unban_request',
  'emoteonly',
  'emoteonlyoff',
  'followers',
  'followersoff',
  'slow',
  'slowoff',
  'subscribers',
  'subscribersoff',
  'uniquechat',
  'uniquechatoff',
};

const _targetObjects = {
  'ban': 'ban',
  'timeout': 'timeout',
  'unban': 'unban',
  'untimeout': 'untimeout',
  'warn': 'warn',
  'delete': 'delete',
  'mod': 'mod',
  'unmod': 'unmod',
  'vip': 'vip',
  'unvip': 'unvip',
  'raid': 'raid',
  'unraid': 'unraid',
  'approve_unban_request': 'unban_request',
  'deny_unban_request': 'unban_request',
};

String? _string(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

Map<String, Object?>? _map(Object? value) =>
    value is Map<String, Object?> ? value : null;

ModActionEntry? parseModerateEvent(
  Map<String, Object?> event, {
  required DateTime now,
}) {
  final action = _string(event['action']);
  if (action == null || !kModActions.contains(action)) return null;
  final moderator =
      _string(event['moderator_user_name']) ??
      _string(event['moderator_user_login']);
  if (moderator == null) return null;
  final target = _map(event[_targetObjects[action]]);
  final userName =
      _string(target?['user_name']) ?? _string(target?['user_login']);
  if (_targetObjects.containsKey(action) && userName == null) return null;
  final expiresAt = _string(target?['expires_at']);
  return ModActionEntry(
    action: action,
    moderatorName: moderator,
    at: now,
    userId: _string(target?['user_id']),
    userName: userName,
    reason:
        _string(target?['reason']) ??
        _string(target?['moderator_message']) ??
        '',
    timeoutEndsAt: expiresAt == null ? null : DateTime.tryParse(expiresAt),
  );
}

HeldMessage? parseHeldMessage(Map<String, Object?> event) {
  final id = _string(event['message_id']);
  final userId = _string(event['user_id']);
  final userName = _string(event['user_name']) ?? _string(event['user_login']);
  final text = _string(_map(event['message'])?['text']);
  if (id == null || userId == null || userName == null || text == null) {
    return null;
  }
  final automod = _map(event['automod']);
  final level = automod?['level'];
  return HeldMessage(
    id: id,
    userId: userId,
    userName: userName,
    text: text,
    reason: _string(event['reason']) ?? 'automod',
    category: _string(automod?['category']) ?? '',
    level: level is int ? level : 0,
    heldAt:
        DateTime.tryParse(_string(event['held_at']) ?? '') ?? DateTime.now(),
  );
}

({String id, HeldMessageStatus status})? parseHeldMessageUpdate(
  Map<String, Object?> event,
) {
  final id = _string(event['message_id']);
  final status = switch (_string(event['status'])?.toLowerCase()) {
    'approved' => HeldMessageStatus.approved,
    'denied' => HeldMessageStatus.denied,
    'expired' => HeldMessageStatus.expired,
    _ => null,
  };
  if (id == null || status == null) return null;
  return (id: id, status: status);
}

String? shieldModerator(Map<String, Object?> event) =>
    _string(event['moderator_user_name']) ??
    _string(event['moderator_user_login']);

@immutable
class ShoutoutNotice {
  const ShoutoutNotice({
    required this.id,
    required this.targetId,
    required this.targetLogin,
    required this.targetName,
  });

  final String id;
  final String targetId;
  final String targetLogin;
  final String targetName;
}

final _shoutoutLogin = RegExp(r'^[a-zA-Z0-9_]{1,25}$');
final _shoutoutId = RegExp(r'^[0-9]{1,20}$');

ShoutoutNotice? parseShoutout(
  String type,
  Map<String, Object?> data, {
  required String channelId,
}) {
  if (type != 'create') return null;
  if (_string(data['broadcasterUserID']) != channelId) return null;
  final login = _string(data['targetLogin']);
  final targetId = _string(data['targetUserID']);
  if (login == null || !_shoutoutLogin.hasMatch(login)) return null;
  if (targetId == null || !_shoutoutId.hasMatch(targetId)) return null;
  return ShoutoutNotice(
    id: _string(data['shoutoutID']) ?? '$targetId-${DateTime.now()}',
    targetId: targetId,
    targetLogin: login.toLowerCase(),
    targetName: _string(data['targetUserDisplayName']) ?? login,
  );
}
