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

/// The label ids worth warning about, cleaned up: non-empty, trimmed,
/// de-duplicated, in a stable order, at most eight (a hostile channel can't
/// flood the card). What a store keeps; a screen names them with
/// [contentLabelNames].
List<String> contentLabelIds(Iterable<String> ids) {
  final seen = <String>{};
  final kept = <String>[];
  for (final id in ids) {
    final trimmed = id.trim();
    if (trimmed.isEmpty || !seen.add(trimmed)) continue;
    kept.add(trimmed);
    if (kept.length == 8) break;
  }
  return kept;
}

/// The labels worth warning about ([contentLabelIds]), named in [l]'s
/// language.
List<String> contentLabelNames(Iterable<String> ids, AppLocalizations l) => [
  for (final id in contentLabelIds(ids)) contentLabelName(id, l),
];
