/// Twitch's content classification labels (Helix `content_classification_labels`)
/// with the names Twitch shows the viewer. Unknown ids are kept and shown as
/// themselves so a new label still warns.
const _knownLabels = <String, String>{
  'DrugsIntoxication': 'Drugs, Intoxication, or Excessive Tobacco Use',
  'SexualThemes': 'Sexual Themes',
  'ViolentGraphic': 'Violent and Graphic Depictions',
  'Gambling': 'Gambling',
  'ProfanityVulgarity': 'Significant Profanity or Vulgarity',
  'MatureGame': 'Mature-Rated Game',
  'DebatedSocialIssuesAndPolitics': 'Politics and Sensitive Social Issues',
};

/// The label ids Twitch is known to use, in a stable order.
Iterable<String> get knownContentLabels => _knownLabels.keys;

/// A readable name for a label id ("SexualThemes" → "Sexual Themes"). An
/// unknown id is spaced out from its CamelCase so it still reads.
String contentLabelName(String id) {
  final known = _knownLabels[id];
  if (known != null) return known;
  final spaced = id
      .replaceAllMapped(RegExp(r'(?<=[a-z0-9])(?=[A-Z])'), (_) => ' ')
      .trim();
  return spaced.isEmpty ? id : spaced;
}

/// The labels worth warning about, cleaned up: non-empty ids, de-duplicated,
/// in a stable order, at most eight (a hostile channel can't flood the card).
List<String> contentLabelNames(Iterable<String> ids) {
  final seen = <String>{};
  final names = <String>[];
  for (final id in ids) {
    final trimmed = id.trim();
    if (trimmed.isEmpty || !seen.add(trimmed)) continue;
    names.add(contentLabelName(trimmed));
    if (names.length == 8) break;
  }
  return names;
}
