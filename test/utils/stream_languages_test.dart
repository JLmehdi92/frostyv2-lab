import 'package:flutter_test/flutter_test.dart';
import 'package:onset/utils/stream_languages.dart';

void main() {
  test('every language comes first', () {
    expect(kStreamLanguages.keys.first, '');
  });

  test('known codes are kept, anything else is every language', () {
    expect(streamLanguageOrAll('fr'), 'fr');
    expect(streamLanguageOrAll('other'), 'other');
    expect(streamLanguageOrAll(''), '');
    expect(streamLanguageOrAll('xx'), '');
    expect(streamLanguageOrAll('fr&first=100'), '');
  });

  test('codes are Helix language codes', () {
    for (final code in kStreamLanguages.keys.skip(1)) {
      expect(code, matches(RegExp(r'^([a-z]{2}|other)$')), reason: code);
    }
  });
}
