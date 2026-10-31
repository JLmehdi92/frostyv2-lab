import 'package:onset/l10n/l10n.dart';

/// Twitch's content classification labels (Helix `content_classification_labels`)
/// with the names Twitch shows the viewer, in the language on screen.
/// Unknown ids are kept and shown as themselves so a new label still warns.
String? _knownName(String id, AppLocalizations l) => switch (id) {
  'DrugsIntoxication' => l.contentLabelDrugs,
  'SexualThemes' => l.contentLabelSexualThemes,
  'ViolentGraphic' => l.contentLabelViolentGraphic,
  'Gambling' => l.contentLabelGambling,
  'ProfanityVulgarity' => l.contentLabelProfanity,
  'MatureGame' => l.contentLabelMatureGame,
  'DebatedSocialIssuesAndPolitics' => l.contentLabelPolitics,
  _ => null,
};

/// The label ids Twitch is known to use, in a stable order.
const knownContentLabelIds = [
  'DrugsIntoxication',
  'SexualThemes',
  'ViolentGraphic',
  'Gambling',
  'ProfanityVulgarity',
  'MatureGame',
  'DebatedSocialIssuesAndPolitics',
];

/// A readable name for a label id in [l]'s language ("SexualThemes" →
/// "Sexual Themes"). An unknown id is spaced out from its CamelCase so it
/// still reads.
String contentLabelName(String id, AppLocalizations l) {
  final known = _knownName(id, l);
  if (known != null) return known;
  final spaced = id
      .replaceAllMapped(RegExp(r'(?<=[a-z0-9])(?=[A-Z])'), (_) => ' ')
      .trim();
  return spaced.isEmpty ? id : spaced;
}

/// The labels worth warning about, cleaned up and named in [l]'s language:
/// non-empty ids, de-duplicated, in a stable order, at most eight (a
/// hostile channel can't flood the card).
List<String> contentLabelNames(Iterable<String> ids, AppLocalizations l) {
  final seen = <String>{};
  final names = <String>[];
  for (final id in ids) {
    final trimmed = id.trim();
    if (trimmed.isEmpty || !seen.add(trimmed)) continue;
    names.add(contentLabelName(trimmed, l));
    if (names.length == 8) break;
  }
  return names;
}
