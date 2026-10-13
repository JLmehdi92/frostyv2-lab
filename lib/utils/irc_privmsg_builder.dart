import 'package:frosty/models/irc.dart';

final _twitchLogin = RegExp(r'^[a-zA-Z0-9_]{1,25}$');
final _lineBreaks = RegExp(r'[\r\n]');
final _hexColor = RegExp(r'^#[0-9A-Fa-f]{6}$');
final _badgePart = RegExp(r'^[A-Za-z0-9_-]{1,64}$');
final _tagBreakers = RegExp(r'[;=\\\r\n]');
final _tagSafe = RegExp(r'^[A-Za-z0-9_]+$');

bool _isSafeBadge(({String setId, String version}) badge) =>
    _badgePart.hasMatch(badge.setId) && _badgePart.hasMatch(badge.version);

/// Builds the [IRCMessage] live chat would have produced for a message read
/// elsewhere (VOD chat replay, a pinned message), so it renders through the
/// same pipeline: badges, colours, Twitch emotes from the `emotes` tag,
/// 7TV/BTTV/FFZ words resolved by the chat assets store, mentions.
///
/// Builds a raw PRIVMSG line and parses it with the unchanged
/// [IRCMessage.fromString]. Emote ranges are in UTF-16 code units, matching
/// the `substring` calls of that parser. Everything that could break the
/// line (tag separators, line breaks, bad colours or badges, a login that is
/// not a Twitch login) is dropped or escaped.
IRCMessage buildPrivmsgIrcMessage({
  required List<({String text, String? emoteId})> fragments,
  required String? login,
  required String? displayName,
  required String id,
  required String channelId,
  required String channelLogin,
  required DateTime sentAt,
  String? userId,
  String? color,
  List<({String setId, String version})> badges = const [],
  String? viewerLogin,
}) {
  final text = StringBuffer();
  final emoteRanges = <String, List<String>>{};
  for (final fragment in fragments) {
    final part = fragment.text.replaceAll(_lineBreaks, ' ');
    final emoteId = fragment.emoteId;
    if (emoteId != null && part.isNotEmpty && _tagSafe.hasMatch(emoteId)) {
      final start = text.length;
      (emoteRanges[emoteId] ??= []).add('$start-${start + part.length - 1}');
    }
    text.write(part);
  }

  final known = login != null && _twitchLogin.hasMatch(login);
  final sender = known ? login.toLowerCase() : 'deleted_user';
  final shownName = (displayName ?? '').replaceAll(_tagBreakers, '').trim();
  final name = known
      ? (shownName.isEmpty ? sender : shownName)
      : 'Deleted user';

  final tags = <String, String>{
    if (badges.any(_isSafeBadge))
      'badges': badges
          .where(_isSafeBadge)
          .map((b) => '${b.setId}/${b.version}')
          .join(','),
    'color': ?_validColor(color),
    'display-name': _tagValue(name),
    if (emoteRanges.isNotEmpty)
      'emotes': emoteRanges.entries
          .map((e) => '${e.key}:${e.value.join(',')}')
          .join('/'),
    'id': _tagValue(id),
    'room-id': _tagValue(channelId),
    'tmi-sent-ts': '${sentAt.millisecondsSinceEpoch}',
    if (known && userId != null) 'user-id': _tagValue(userId),
  };
  final tagString = tags.entries
      .where((e) => e.value.isNotEmpty)
      .map((e) => '${e.key}=${e.value}')
      .join(';');
  final channel = _twitchLogin.hasMatch(channelLogin)
      ? channelLogin.toLowerCase()
      : 'channel';

  return IRCMessage.fromString(
    '@$tagString :$sender!$sender@$sender.tmi.twitch.tv PRIVMSG #$channel '
    ':$text',
    userLogin: viewerLogin,
  );
}

/// IRC tag value escaping: spaces become `\s`; `;`, `=` and backslashes
/// (which would break the tag parser) are dropped.
String _tagValue(String value) =>
    value.replaceAll(_tagBreakers, '').replaceAll(' ', r'\s');

String? _validColor(String? color) =>
    color != null && _hexColor.hasMatch(color) ? color : null;
