import 'package:onset/models/chat_gif.dart';
import 'package:onset/models/irc.dart';

final _twitchLogin = RegExp(r'^[a-zA-Z0-9_]{1,25}$');
final _lineBreaks = RegExp(r'[\r\n]');
final _hexColor = RegExp(r'^#[0-9A-Fa-f]{6}$');
final _badgePart = RegExp(r'^[A-Za-z0-9_-]{1,64}$');
final _tagBreakers = RegExp(r'[;=\\\r\n]');
final _tagSafe = RegExp(r'^[A-Za-z0-9_]+$');

/// Control characters other than line breaks: `\x01` would turn a line into
/// a `/me` action, the others draw nothing.
final _controls = RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]');

/// What a `gifs` entry may not hold: its own separators (`,` between
/// entries, `|` between fields) and whitespace.
final _gifBreakers = RegExp(r'[,|\s]');

/// The tags [buildPrivmsgIrcMessage] takes from its caller besides the ones
/// it builds itself. Anything else (who sent it, their roles, the kind of
/// message) cannot be set from outside.
const privmsgExtraTags = {
  'historical',
  'bits',
  'source-room-id',
  'reply-parent-msg-id',
  'reply-parent-msg-body',
  'reply-parent-user-id',
  'reply-parent-user-login',
  'reply-parent-display-name',
  'reply-thread-parent-msg-id',
  'reply-thread-parent-user-login',
  'reply-thread-parent-display-name',
};

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
/// line (tag separators, line breaks, control characters, bad colours or
/// badges, a login that is not a Twitch login) is dropped or escaped.
///
/// [extraTags] adds the tags of [privmsgExtraTags] (others are ignored),
/// escaped the same way. [gifs] marks fragments, by index, as GIFs: they
/// become the `gifs` tag, counted in characters as Twitch counts them, and
/// only when [ChatGif.isLoadable] allows the address (else the fragment
/// stays its title), at most [GifMessagePart.maxGifs]. [action] makes it a
/// `/me` line, wrapped by the builder itself after the text is cleaned.
/// A `moderator` badge sets `mod=1`, as live IRC does.
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
  Map<String, String> extraTags = const {},
  Map<int, ({String id, String url})> gifs = const {},
  bool action = false,
}) {
  final text = StringBuffer();
  final emoteRanges = <String, List<String>>{};
  final gifEntries = <String>[];
  // Characters (code points) written so far: `gifs` positions count them.
  var characters = 0;
  for (final (index, fragment) in fragments.indexed) {
    final part = fragment.text
        .replaceAll(_lineBreaks, ' ')
        .replaceAll(_controls, '');
    final length = part.runes.length;
    final emoteId = fragment.emoteId;
    if (emoteId != null && part.isNotEmpty && _tagSafe.hasMatch(emoteId)) {
      final start = text.length;
      (emoteRanges[emoteId] ??= []).add('$start-${start + part.length - 1}');
    }
    final gif = gifs[index];
    if (gif != null &&
        gifEntries.length < GifMessagePart.maxGifs &&
        length > 0 &&
        gif.id.isNotEmpty &&
        !_gifBreakers.hasMatch(gif.id) &&
        !_gifBreakers.hasMatch(gif.url) &&
        !_controls.hasMatch(gif.url) &&
        ChatGif(
          start: characters,
          end: characters + length - 1,
          id: gif.id,
          url: gif.url,
        ).isLoadable) {
      gifEntries.add(
        '$characters-${characters + length - 1}|${gif.id}|${gif.url}',
      );
    }
    text.write(part);
    characters += length;
  }

  final known = login != null && _twitchLogin.hasMatch(login);
  final sender = known ? login.toLowerCase() : kDeletedUserLogin;
  final shownName = (displayName ?? '').replaceAll(_tagBreakers, '').trim();
  // An unknown sender's name is data in no language: it is worded where it
  // shows (IRCMessage.shownDisplayName), in the language on screen then.
  final name = known ? (shownName.isEmpty ? sender : shownName) : sender;

  final safeBadges = badges.where(_isSafeBadge).toList();
  final tags = <String, String>{
    if (safeBadges.isNotEmpty)
      'badges': safeBadges.map((b) => '${b.setId}/${b.version}').join(','),
    'color': ?_validColor(color),
    'display-name': _tagValue(name),
    if (emoteRanges.isNotEmpty)
      'emotes': emoteRanges.entries
          .map((e) => '${e.key}:${e.value.join(',')}')
          .join('/'),
    'id': _tagValue(id),
    if (safeBadges.any((b) => b.setId == 'moderator')) 'mod': '1',
    'room-id': _tagValue(channelId),
    'tmi-sent-ts': '${sentAt.millisecondsSinceEpoch}',
    if (known && userId != null) 'user-id': _tagValue(userId),
    if (gifEntries.isNotEmpty) 'gifs': _escapeTag(gifEntries.join(',')),
    for (final MapEntry(:key, :value) in extraTags.entries)
      if (privmsgExtraTags.contains(key)) key: _tagValue(value),
  };
  final tagString = tags.entries
      .where((e) => e.value.isNotEmpty)
      .map((e) => '${e.key}=${e.value}')
      .join(';');
  final channel = _twitchLogin.hasMatch(channelLogin)
      ? channelLogin.toLowerCase()
      : 'channel';

  // The CTCP wrapper the parser reads as `/me`: its positions (emotes,
  // GIFs) count from after it, so the ones above stay right.
  final body = action ? '\x01ACTION $text\x01' : '$text';
  return IRCMessage.fromString(
    '@$tagString :$sender!$sender@$sender.tmi.twitch.tv PRIVMSG #$channel '
    ':$body',
    userLogin: viewerLogin,
  );
}

/// IRC tag value escaping: spaces become `\s`; `;`, `=` and backslashes
/// (which would break the tag parser) are dropped.
String _tagValue(String value) =>
    value.replaceAll(_tagBreakers, '').replaceAll(' ', r'\s');

/// IRCv3 tag escaping, read back by `UserNotice.unescapeTag`: keeps every
/// character (a GIF address may hold `;` or `=`).
String _escapeTag(String value) =>
    value.replaceAll(r'\', r'\\').replaceAll(';', r'\:').replaceAll(' ', r'\s');

String? _validColor(String? color) =>
    color != null && _hexColor.hasMatch(color) ? color : null;
