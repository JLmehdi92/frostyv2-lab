import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/utils/stream_languages.dart';

void main() {
  test('every language comes first, a language not listed last', () {
    expect(kStreamLanguageCodes.first, '');
    expect(kStreamLanguageCodes.last, 'other');
  });

  test('known codes are kept, anything else is every language', () {
    expect(streamLanguageOrAll('fr'), 'fr');
    expect(streamLanguageOrAll('other'), 'other');
    expect(streamLanguageOrAll(''), '');
    expect(streamLanguageOrAll('xx'), '');
    expect(streamLanguageOrAll('fr&first=100'), '');
  });

  test('codes are Helix language codes', () {
    for (final code in kStreamLanguageCodes.skip(1)) {
      expect(code, matches(RegExp(r'^([a-z]{2}|other)$')), reason: code);
    }
  });

  test('languages keep their own names; every and other are translated', () {
    final english = L10n.english;
    final french = lookupAppLocalizations(const Locale('fr'));
    expect(streamLanguageName('de', english), 'Deutsch');
    expect(streamLanguageName('de', french), 'Deutsch');
    expect(streamLanguageName('fr', english), 'Français');
    expect(streamLanguageName('', english), 'All languages');
    expect(streamLanguageName('', french), 'Toutes les langues');
    expect(streamLanguageName('other', english), 'Other');
    expect(streamLanguageName('other', french), 'Autre');
  });
}
