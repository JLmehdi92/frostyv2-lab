import 'package:frosty/models/irc.dart';
import 'package:frosty/models/vod_comment.dart';

final _twitchLogin = RegExp(r'^[a-zA-Z0-9_]{1,25}$');
final _lineBreaks = RegExp(r'[\r\n]');
final _hexColor = RegExp(r'^#[0-9A-Fa-f]{6}$');
final _badgePart = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

bool _isSafeBadge(({String setId, String version}) badge) =>
    _badgePart.hasMatch(badge.setId) && _badgePart.hasMatch(badge.version);

/// Turns a replayed chat comment into the [IRCMessage] live chat would have
/// produced, so it renders through the same pipeline (badges, colours,
/// Twitch emotes from the `emotes` tag, 7TV/BTTV/FFZ words resolved by the
/// chat assets store, mentions).
///
/// Builds a raw PRIVMSG line and parses it with the unchanged
/// [IRCMessage.fromString]. Emote ranges are in UTF-16 code units, matching
/// the `substring` calls of that parser.
IRCMessage vodCommentToIrcMessage(
  VodComment comment, {
  required String channelId,
  required String channelLogin,
  required DateTime vodCreatedAt,
  String? viewerLogin,
}) {
  final text = StringBuffer();
  final emoteRanges = <String, List<String>>{};
  for (final fragment in comment.fragments) {
    final part = fragment.text.replaceAll(_lineBreaks, ' ');
    final emoteId = fragment.emoteId;
    if (emoteId != null && part.isNotEmpty && _isTagSafe(emoteId)) {
      final start = text.length;
      (emoteRanges[emoteId] ??= []).add('$start-${start + part.length - 1}');
    }
    text.write(part);
  }

  final rawLogin = comment.commenterLogin;
  final known = rawLogin != null && _twitchLogin.hasMatch(rawLogin);
  final login = known ? rawLogin.toLowerCase() : 'deleted_user';
  final shownName = (comment.commenterDisplayName ?? '')
      .replaceAll(_tagBreakers, '')
      .trim();
  final displayName = known
      ? (shownName.isEmpty ? login : shownName)
      : 'Deleted user';
  final sentAt = vodCreatedAt.add(Duration(seconds: comment.offsetSeconds));
  final id =
      comment.id ??
      'vod-${comment.key.hashCode.toUnsigned(32).toRadixString(16)}';

  final tags = <String, String>{
    if (comment.badges.any(_isSafeBadge))
      'badges': comment.badges
          .where(_isSafeBadge)
          .map((b) => '${b.setId}/${b.version}')
          .join(','),
    'color': ?_validColor(comment.color),
    'display-name': _tagValue(displayName),
    if (emoteRanges.isNotEmpty)
      'emotes': emoteRanges.entries
          .map((e) => '${e.key}:${e.value.join(',')}')
          .join('/'),
    'id': _tagValue(id),
    'room-id': _tagValue(channelId),
    'tmi-sent-ts': '${sentAt.millisecondsSinceEpoch}',
    if (known && comment.commenterId != null)
      'user-id': _tagValue(comment.commenterId!),
  };
  final tagString = tags.entries
      .where((e) => e.value.isNotEmpty)
      .map((e) => '${e.key}=${e.value}')
      .join(';');
  final channel = _twitchLogin.hasMatch(channelLogin)
      ? channelLogin.toLowerCase()
      : 'channel';

  return IRCMessage.fromString(
    '@$tagString :$login!$login@$login.tmi.twitch.tv PRIVMSG #$channel :$text',
    userLogin: viewerLogin,
  );
}

/// IRC tag value escaping: spaces become `\s`; `;`, `=` and backslashes
/// (which would break the tag parser) are dropped.
String _tagValue(String value) =>
    value.replaceAll(_tagBreakers, '').replaceAll(' ', r'\s');

final _tagBreakers = RegExp(r'[;=\\\r\n]');

String? _validColor(String? color) =>
    color != null && _hexColor.hasMatch(color) ? color : null;

bool _isTagSafe(String value) => RegExp(r'^[A-Za-z0-9_]+$').hasMatch(value);
