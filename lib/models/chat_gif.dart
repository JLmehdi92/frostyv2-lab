import 'package:flutter/foundation.dart';

/// A GIF sent with Twitch's GIF keyboard, from a message's `gifs` tag.
///
/// The tag is `<start>-<end>|<gifID>|<gifURL>` entries joined by commas.
/// [start] and [end] are zero-based positions in the message (after a `/me`
/// prefix), [end] included. See [GifMessagePart.split] for how they count.
@immutable
class ChatGif {
  const ChatGif({
    required this.start,
    required this.end,
    required this.id,
    required this.url,
  });

  final int start;
  final int end;
  final String id;

  /// The address Twitch gave, kept exactly as sent: Twitch's doc forbids
  /// changing it.
  final String url;

  /// The entries of a `gifs` tag value, sorted by [start].
  ///
  /// Skips an entry like the Twitch app does: not exactly three `|` fields,
  /// an empty id or url, or a range that is not two integers joined by `-`.
  static List<ChatGif> parseTag(String? value) {
    if (value == null || value.isEmpty) return const [];
    final gifs = <ChatGif>[];
    for (final entry in value.split(',')) {
      final fields = entry.split('|');
      if (fields.length != 3) continue;
      final [range, id, url] = fields;
      if (id.isEmpty || url.isEmpty) continue;
      final bounds = range.split('-');
      if (bounds.length != 2) continue;
      final start = int.tryParse(bounds[0]);
      final end = int.tryParse(bounds[1]);
      if (start == null || end == null) continue;
      gifs.add(ChatGif(start: start, end: end, id: id, url: url));
    }
    gifs.sort((a, b) => a.start.compareTo(b.start));
    return gifs;
  }

  /// The sites a chat GIF may come from: GIPHY, which Twitch's GIF keyboard
  /// searches, and Twitch's own CDN, with their subdomains.
  static const allowedHosts = {'giphy.com', 'jtvnw.net'};

  /// Whether the app may load [url]: `https` on the default port, no user,
  /// and a host in [allowedHosts] or one of their subdomains.
  ///
  /// Twitch's app loads any address it is given. Here the tag can also come
  /// from the third-party recent-messages history, so a line could otherwise
  /// make every viewer fetch any address (their IP to any server, or a device
  /// on their network). A refused GIF shows its title instead.
  bool get isLoadable {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.isScheme('https') || uri.userInfo.isNotEmpty) {
      return false;
    }
    if (uri.hasPort && uri.port != 443) return false;
    final host = uri.host.toLowerCase();
    return allowedHosts.any(
      (allowed) => host == allowed || host.endsWith('.$allowed'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ChatGif &&
      other.start == start &&
      other.end == end &&
      other.id == id &&
      other.url == url;

  @override
  int get hashCode => Object.hash(start, end, id, url);

  @override
  String toString() => 'ChatGif($start-$end, $id)';
}

/// A piece of a chat message that holds GIFs: plain [text], or a GIF whose
/// title is [text].
@immutable
class GifMessagePart {
  const GifMessagePart(this.text, [this.gif]);

  final String text;
  final ChatGif? gif;

  /// [message] cut around the [gifs] that fit in it, or nothing when none
  /// does.
  ///
  /// [gifs] must be sorted by start. A position counts characters (code
  /// points), as the `emotes` tag does: an emoji before a GIF is one
  /// position. A range that does not fit that way is read in UTF-16 units,
  /// as the Twitch app reads it, unless it would cut an emoji in two. Like
  /// the Twitch app, a GIF is kept only when `0 <= start <= end` and it ends
  /// in the message, and one that starts before the end of the previous kept
  /// GIF is dropped.
  static List<GifMessagePart> split(String message, List<ChatGif> gifs) {
    if (gifs.isEmpty) return const [];
    // Where each character starts, in UTF-16 units.
    final starts = <int>[
      for (var i = 0; i < message.length; i++)
        if (!_insidePair(message, i)) i,
    ];
    final parts = <GifMessagePart>[];
    var next = 0;
    for (final gif in gifs) {
      final range = _unitRange(message, starts, gif);
      if (range == null) continue;
      final (start, end) = range;
      if (start < next) continue;
      if (start > next) {
        parts.add(GifMessagePart(message.substring(next, start)));
      }
      parts.add(GifMessagePart(message.substring(start, end), gif));
      next = end;
    }
    if (parts.isEmpty) return const [];
    if (next < message.length) {
      parts.add(GifMessagePart(message.substring(next)));
    }
    return parts;
  }

  /// [gif]'s range in UTF-16 units, its end excluded, or null when it fits
  /// [message] neither in characters nor in units.
  static (int, int)? _unitRange(String message, List<int> starts, ChatGif gif) {
    final ChatGif(:start, :end) = gif;
    if (start < 0 || start > end) return null;
    if (end < starts.length) {
      final after = end + 1 < starts.length ? starts[end + 1] : message.length;
      return (starts[start], after);
    }
    if (end < message.length &&
        !_insidePair(message, start) &&
        !_insidePair(message, end + 1)) {
      return (start, end + 1);
    }
    return null;
  }

  /// Whether UTF-16 unit [index] of [text] is the second half of an emoji
  /// (a surrogate pair), so a cut there would split it.
  static bool _insidePair(String text, int index) =>
      index > 0 &&
      index < text.length &&
      _isHighSurrogate(text.codeUnitAt(index - 1)) &&
      _isLowSurrogate(text.codeUnitAt(index));

  static bool _isHighSurrogate(int unit) => unit >= 0xD800 && unit <= 0xDBFF;

  static bool _isLowSurrogate(int unit) => unit >= 0xDC00 && unit <= 0xDFFF;
}
