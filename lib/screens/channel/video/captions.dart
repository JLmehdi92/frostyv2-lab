import 'package:flutter/material.dart';
import 'package:onset/l10n/l10n.dart';

/// The longest a caption line stays when its cue gives no sane end.
const kCaptionMaxShown = Duration(seconds: 8);

/// A caption event from the native player as the text to show and for how
/// long; null for nothing to show (an empty cue clears the line).
({String text, Duration shownFor})? captionFromEvent(Map<String, dynamic> e) {
  final raw = e['text'];
  if (raw is! String) return null;
  final text = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (text.isEmpty) return null;
  final start = (e['startMs'] as num?)?.toInt();
  final end = (e['endMs'] as num?)?.toInt();
  var shownFor = const Duration(seconds: 4);
  if (start != null && end != null && end > start) {
    shownFor = Duration(milliseconds: end - start);
  }
  if (shownFor < const Duration(seconds: 1)) {
    shownFor = const Duration(seconds: 1);
  }
  if (shownFor > kCaptionMaxShown) shownFor = kCaptionMaxShown;
  return (
    text: text.length > 300 ? text.substring(0, 300) : text,
    shownFor: shownFor,
  );
}

/// The size of the caption line, Twitch's (15) by default.
enum CaptionSize {
  small(13),
  medium(15),
  large(19),
  extraLarge(24);

  const CaptionSize(this.fontSize);

  final double fontSize;
}

/// What sits behind the caption line: Twitch's black box by default.
enum CaptionBackground { black, translucent, none }

/// One caption track the player offers.
class CaptionTrack {
  const CaptionTrack({
    required this.id,
    this.name,
    this.language,
    this.number = 1,
  });

  final String id;

  /// What the track is called: its label, else its language (null when the
  /// stream gives neither).
  final String? name;

  /// Its place in the list, from 1: named "Captions 2" without a [name].
  final int number;

  /// Its language tag (`en`, `es-419`), when the stream gives one.
  final String? language;

  /// What the menu calls it, in [l]'s language: its [name], else "Captions
  /// [number]".
  String nameIn(AppLocalizations l) =>
      name ?? l.liveCaptionsTrack(number: number);
}

/// The tracks of a `textTracks` event from the native player, and the id
/// of the one it shows. Entries without an id are skipped.
({List<CaptionTrack> list, String? selected}) captionTracksFromEvent(
  Map<String, dynamic> e,
) {
  final raw = e['list'];
  final list = <CaptionTrack>[];
  if (raw is List) {
    for (final item in raw.take(20)) {
      if (item is! Map) continue;
      final id = item['id'];
      if (id is! String || id.isEmpty || id.length > 100) continue;
      final label = _short(item['label']);
      final language = _short(item['language']);
      list.add(
        CaptionTrack(
          id: id,
          name: label ?? language,
          number: list.length + 1,
          language: language,
        ),
      );
    }
  }
  final selected = e['selected'];
  return (
    list: list,
    selected: selected is String && list.any((t) => t.id == selected)
        ? selected
        : null,
  );
}

String? _short(Object? value) {
  if (value is! String) return null;
  final text = value.trim();
  if (text.isEmpty) return null;
  return text.length > 60 ? text.substring(0, 60) : text;
}

/// A caption line over the bottom of the video, readable on any picture:
/// Twitch's white text on black by default.
class CaptionText extends StatelessWidget {
  const CaptionText({
    super.key,
    required this.text,
    this.size = CaptionSize.medium,
    this.background = CaptionBackground.black,
  });

  final String text;
  final CaptionSize size;
  final CaptionBackground background;

  static const _outline = [
    Shadow(blurRadius: 3),
    Shadow(offset: Offset(1, 1), blurRadius: 2),
  ];

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: switch (background) {
            CaptionBackground.black => Colors.black,
            CaptionBackground.translucent => Colors.black.withValues(
              alpha: 0.6,
            ),
            CaptionBackground.none => null,
          },
          borderRadius: BorderRadius.circular(2),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Text(
            text,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: size.fontSize,
              shadows: background == CaptionBackground.none ? _outline : null,
            ),
          ),
        ),
      ),
    );
  }
}
