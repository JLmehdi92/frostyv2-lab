final _wordBreak = RegExp(r'[\s.,!?;:"()\[\]{}<>]+');

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
      // A muted phrase ("bad word") matches its words in order.
      if (muted.contains(' ')) {
        if (RegExp(
          '(^|[\\s.,!?;:"()\\[\\]{}<>])${RegExp.escape(muted)}'
          '(\$|[\\s.,!?;:"()\\[\\]{}<>])',
        ).hasMatch(text)) {
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
