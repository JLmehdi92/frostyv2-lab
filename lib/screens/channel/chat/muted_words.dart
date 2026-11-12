final _wordBreak = RegExp(r'[\s.,!?;:"()\[\]{}<>]+');
final _wordChar = RegExp(r'[a-z0-9_]');
final _phrases = <String, RegExp>{};

/// Whether [message] contains one of [mutedWords], ignoring case. With
/// [wholeWord], a muted word must be a whole word of the message (split on
/// spaces and punctuation); otherwise any substring matches. Blank muted
/// words never match.
bool isMuted(
  String message,
  Iterable<String> mutedWords, {
  required bool wholeWord,
}) {
  final text = message.toLowerCase();
  Set<String>? words;
  for (final raw in mutedWords) {
    final muted = raw.trim().toLowerCase();
    if (muted.isEmpty) continue;
    if (wholeWord) {
      words ??= text.split(_wordBreak).toSet();
      // A phrase ("bad word") or a muted word with punctuation ("!sr",
      // "twitch.tv", ":D") is found as a whole, between spaces (or
      // punctuation next to a letter).
      if (_wordBreak.hasMatch(muted)) {
        const breaks = r'[\s.,!?;:"()\[\]{}<>]';
        final before = _wordChar.hasMatch(muted[0]) ? breaks : r'\s';
        final after = _wordChar.hasMatch(muted[muted.length - 1])
            ? breaks
            : r'\s';
        final phrase = _phrases.putIfAbsent(
          muted,
          () => RegExp('(^|$before)${RegExp.escape(muted)}(\$|$after)'),
        );
        if (phrase.hasMatch(text)) {
          return true;
        }
      } else if (words.contains(muted)) {
        return true;
      }
    } else if (text.contains(muted)) {
      return true;
    }
  }
  return false;
}
