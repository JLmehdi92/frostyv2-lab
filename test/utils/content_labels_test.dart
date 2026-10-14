import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/utils/content_labels.dart';

void main() {
  test('known labels get Twitch\'s wording', () {
    expect(contentLabelName('SexualThemes'), 'Sexual Themes');
    expect(contentLabelName('Gambling'), 'Gambling');
  });

  test('an unknown label is spaced out from CamelCase', () {
    expect(contentLabelName('SomeNewLabel'), 'Some New Label');
    expect(contentLabelName('weird'), 'weird');
  });

  test('names are cleaned, de-duplicated and capped at eight', () {
    expect(
      contentLabelNames(['SexualThemes', ' ', 'SexualThemes', 'Gambling']),
      ['Sexual Themes', 'Gambling'],
    );
    expect(contentLabelNames(<String>[]), isEmpty);
    expect(
      contentLabelNames(List.generate(12, (i) => 'Label$i')),
      hasLength(8),
    );
  });
}
