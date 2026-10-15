import 'package:flutter/foundation.dart';

/// A GIF sent with Twitch's GIF keyboard, from a message's `gifs` tag.
///
/// The tag is `<start>-<end>|<gifID>|<gifURL>` entries joined by commas.
/// [start] and [end] are zero-based, [end] included, in UTF-16 units of the
/// message (after a `/me` prefix), like the Twitch app reads them.
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

  /// Whether the app may load [url]: an `https` address with a host.
  ///
  /// Twitch's app loads any address it is given. Anything but `https` is
  /// refused here, so a GIF never goes out in clear text or reaches a local
  /// file; its title is shown instead.
  bool get isLoadable {
    final uri = Uri.tryParse(url);
    return uri != null && uri.isScheme('https') && uri.host.isNotEmpty;
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
  /// [gifs] must be sorted by start. Like the Twitch app, a GIF is kept only
  /// when `0 <= start <= end < message.length`, and one that starts before
  /// the end of the previous kept GIF is dropped.
  static List<GifMessagePart> split(String message, List<ChatGif> gifs) {
    final parts = <GifMessagePart>[];
    var next = 0;
    for (final gif in gifs) {
      if (gif.start < 0 || gif.start > gif.end) continue;
      if (gif.end >= message.length || gif.start < next) continue;
      if (gif.start > next) {
        parts.add(GifMessagePart(message.substring(next, gif.start)));
      }
      parts.add(GifMessagePart(message.substring(gif.start, gif.end + 1), gif));
      next = gif.end + 1;
    }
    if (parts.isEmpty) return const [];
    if (next < message.length) {
      parts.add(GifMessagePart(message.substring(next)));
    }
    return parts;
  }
}
