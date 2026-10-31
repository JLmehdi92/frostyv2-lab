import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/utils/content_labels.dart';

void main() {
  final english = L10n.english;
  final french = lookupAppLocalizations(const Locale('fr'));

  test('known labels get Twitch\'s wording', () {
    expect(contentLabelName('SexualThemes', english), 'Sexual Themes');
    expect(contentLabelName('Gambling', english), 'Gambling');
  });

  test('known labels are named in the language on screen', () {
    expect(contentLabelName('SexualThemes', french), 'Thèmes sexuels');
    expect(contentLabelName('Gambling', french), 'Jeux d’argent');
    for (final id in knownContentLabelIds) {
      expect(
        contentLabelName(id, french),
        isNot(contentLabelName(id, english)),
        reason: id,
      );
    }
  });

  test('an unknown label is spaced out from CamelCase', () {
    expect(contentLabelName('SomeNewLabel', english), 'Some New Label');
    expect(contentLabelName('weird', english), 'weird');
    expect(contentLabelName('SomeNewLabel', french), 'Some New Label');
  });

  test('names are cleaned, de-duplicated and capped at eight', () {
    expect(
      contentLabelNames([
        'SexualThemes',
        ' ',
        'SexualThemes',
        'Gambling',
      ], english),
      ['Sexual Themes', 'Gambling'],
    );
    expect(contentLabelNames(<String>[], english), isEmpty);
    expect(
      contentLabelNames(List.generate(12, (i) => 'Label$i'), english),
      hasLength(8),
    );
  });
}
