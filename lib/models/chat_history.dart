import 'package:flutter/foundation.dart';

final _numericId = RegExp(r'^[0-9]{1,20}$');

/// The longest text kept from one history message (Twitch caps a chat
/// message at 500 characters; this leaves room and bounds hostile data).
const _maxTextLength = 1000;

/// The most fragments kept from one history message.
const _maxFragments = 300;

/// The longest name or id kept.
const _maxShortLength = 64;

String? _string(Object? value, {int max = _maxShortLength}) {
  if (value is! String || value.isEmpty) return null;
  return value.length > max ? value.substring(0, max) : value;
}

String? _numeric(Object? value) {
  final id = _string(value);
  return id != null && _numericId.hasMatch(id) ? id : null;
}

({String setId, String version})? _badge(Object? json) {
  if (json is! Map) return null;
  final setId = _string(json['setID']);
  final version = _string(json['version']);
  if (setId == null || version == null) return null;
  return (setId: setId, version: version);
}

/// A chat user as the history names them.
@immutable
class ChatHistoryUser {
  const ChatHistoryUser({this.id, this.login, this.displayName, this.color});

  final String? id;
  final String? login;
  final String? displayName;

  /// The colour of the account (`chatColor`), used when the message has
  /// none of its own.
  final String? color;

  static ChatHistoryUser? tryParse(Object? json) {
    if (json is! Map) return null;
    return ChatHistoryUser(
      id: _numeric(json['id']),
      login: _string(json['login']),
      displayName: _string(json['displayName']),
      color: _string(json['chatColor']),
    );
  }
}

/// One piece of a history message's text: plain text, a Twitch emote, a
/// cheer, or a GIF (its title as [text]).
@immutable
class ChatHistoryFragment {
  const ChatHistoryFragment({
    required this.text,
    this.emoteId,
    this.bits = 0,
    this.gif,
  });

  final String text;
  final String? emoteId;

  /// The bits of a cheer, else 0.
  final int bits;

  final ({String id, String url})? gif;

  static ChatHistoryFragment? tryParse(Object? json) {
    if (json is! Map) return null;
    final text = json['text'];
    if (text is! String) return null;
    final content = json['content'];
    if (content is! Map) return ChatHistoryFragment(text: text);
    switch (content['__typename']) {
      case 'Emote':
        return ChatHistoryFragment(text: text, emoteId: _string(content['id']));
      case 'CheermoteToken':
        final bits = content['bitsAmount'];
        return ChatHistoryFragment(
          text: text,
          bits: bits is int && bits > 0 && bits <= 1000000 ? bits : 0,
        );
      case 'GifContent':
        final id = _string(content['id']);
        final url = _string(content['url'], max: 2048);
        return ChatHistoryFragment(
          text: text,
          gif: id == null || url == null ? null : (id: id, url: url),
        );
      default:
        return ChatHistoryFragment(text: text);
    }
  }
}

/// The message a history message replies to, or the first of its thread.
@immutable
class ChatHistoryParent {
  const ChatHistoryParent({required this.id, this.text, this.sender});

  final String id;
  final String? text;
  final ChatHistoryUser? sender;

  static ChatHistoryParent? tryParse(Object? json) {
    if (json is! Map) return null;
    final id = _string(json['id']);
    if (id == null) return null;
    final content = json['content'];
    return ChatHistoryParent(
      id: id,
      text: content is Map
          ? _string(content['text'], max: _maxTextLength)
          : null,
      sender: ChatHistoryUser.tryParse(json['sender']),
    );
  }
}

/// One message of a channel's recent chat, as Twitch's `ChatHistory` query
/// gives it (`Channel.recentChatMessages`), before it becomes a chat line.
@immutable
class ChatHistoryMessage {
  const ChatHistoryMessage({
    required this.id,
    required this.sentAt,
    this.deleted = false,
    this.sender,
    this.color,
    this.badges = const [],
    this.fragments = const [],
    this.sourceChannelId,
    this.parent,
    this.threadParent,
  });

  final String id;
  final DateTime sentAt;

  /// Deleted by a moderator (or with its sender's timeout or ban).
  final bool deleted;

  /// Who sent it; null when Twitch did not say (such a line is dropped).
  final ChatHistoryUser? sender;

  /// The sender's colour: the message's own, else the account's.
  final String? color;

  final List<({String setId, String version})> badges;
  final List<ChatHistoryFragment> fragments;

  /// The channel it was said in, in a Shared Chat.
  final String? sourceChannelId;

  final ChatHistoryParent? parent;
  final ChatHistoryParent? threadParent;

  /// The message in [json], or null when it has no id or no time.
  /// Everything else is optional and checked: the data comes from the
  /// network.
  static ChatHistoryMessage? tryParse(Object? json) {
    if (json is! Map) return null;
    final id = _string(json['id']);
    final sentAt = json['sentAt'];
    final time = sentAt is String ? DateTime.tryParse(sentAt) : null;
    if (id == null || time == null) return null;

    final sender = ChatHistoryUser.tryParse(json['sender']);
    final badges = json['senderBadges'];
    final content = json['content'];
    final rawFragments = content is Map ? content['fragments'] : null;
    final fragments = <ChatHistoryFragment>[];
    var length = 0;
    if (rawFragments is List) {
      for (final raw in rawFragments.take(_maxFragments)) {
        final fragment = ChatHistoryFragment.tryParse(raw);
        if (fragment == null) continue;
        length += fragment.text.length;
        if (length > _maxTextLength) break;
        fragments.add(fragment);
      }
    }
    if (fragments.isEmpty && content is Map) {
      final text = _string(content['text'], max: _maxTextLength);
      if (text != null) fragments.add(ChatHistoryFragment(text: text));
    }

    return ChatHistoryMessage(
      id: id,
      sentAt: time.toUtc(),
      deleted: json['deletedAt'] != null,
      sender: sender,
      color: _string(json['senderChatColor']) ?? sender?.color,
      badges: [
        if (badges is List)
          for (final badge in badges.take(_maxFragments)) ?_badge(badge),
      ],
      fragments: fragments,
      sourceChannelId: switch (json['sourceChannel']) {
        final Map source => _numeric(source['id']),
        _ => null,
      },
      parent: ChatHistoryParent.tryParse(json['parentMessage']),
      threadParent: ChatHistoryParent.tryParse(json['threadParentMessage']),
    );
  }
}
