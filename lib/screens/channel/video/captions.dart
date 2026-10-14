import 'package:flutter/material.dart';

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

/// A caption line over the bottom of the video, readable on any picture.
class CaptionText extends StatelessWidget {
  const CaptionText({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            text,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
        ),
      ),
    );
  }
}
