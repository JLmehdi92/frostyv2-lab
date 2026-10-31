import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:mobx/mobx.dart' show autorun;
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/l10n.dart';

void main() {
  group('resolveAppLocale', () {
    for (final (device, expected) in [
      ([const Locale('fr', 'FR')], 'fr'),
      ([const Locale('fr', 'CA')], 'fr'),
      ([const Locale('en', 'GB')], 'en'),
      ([const Locale('de', 'DE')], 'en'),
      (<Locale>[], 'en'),
      ([const Locale('de'), const Locale('fr', 'BE')], 'fr'),
      ([const Locale('en', 'US'), const Locale('fr')], 'en'),
    ]) {
      test('system on $device: $expected', () {
        expect(resolveAppLocale(AppLanguage.system, device), Locale(expected));
      });
    }

    test('an explicit choice wins over the device', () {
      expect(
        resolveAppLocale(AppLanguage.en, [const Locale('fr', 'FR')]),
        const Locale('en'),
      );
      expect(
        resolveAppLocale(AppLanguage.fr, [const Locale('en', 'US')]),
        const Locale('fr'),
      );
    });
  });

  group('L10n', () {
    test('starts in English', () {
      expect(L10n.current.commonNext, 'Next');
      expect(L10n.english.localeName, 'en');
    });

    test('use() switches the texts and Intl, observably', () async {
      await useLocale(en);
      final seen = <String>[];
      final dispose = autorun((_) => seen.add(L10n.current.commonNext));
      addTearDown(dispose.call);

      L10n.use(const Locale('fr', 'CA'));
      expect(L10n.current.commonNext, 'Suivant');
      expect(Intl.defaultLocale, 'fr');

      L10n.use(const Locale('de'));
      expect(L10n.current.commonNext, 'Next');
      expect(Intl.defaultLocale, 'en');
      expect(seen, ['Next', 'Suivant', 'Next']);
    });

    test('French plural forms: "one" covers 0 and 1', () {
      // The French plural rule the ARB messages rely on.
      String fr(int n) =>
          Intl.plural(n, locale: 'fr', one: '$n chaîne', other: '$n chaînes');
      expect(fr(0), '0 chaîne');
      expect(fr(1), '1 chaîne');
      expect(fr(2), '2 chaînes');
      expect(fr(1000000), '1000000 chaînes');
    });
  });

  group('context.l10n', () {
    testWidgets('falls back to English without localizations', (tester) async {
      late AppLocalizations l;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              l = context.l10n;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(l.commonNext, 'Next');
    });

    testWidgets('reads the app\'s language', (tester) async {
      late AppLocalizations l;
      await pumpLocalized(
        tester,
        Builder(
          builder: (context) {
            l = context.l10n;
            return const SizedBox();
          },
        ),
      );
      expect(l.commonNext, 'Suivant');
    });
  });

  group('l10nSpans', () {
    const bold = TextStyle(fontWeight: FontWeight.w700);

    String plain(List<InlineSpan> spans) =>
        TextSpan(children: spans).toPlainText();

    test('places each piece where its mark is, in any order', () {
      final spans = l10nSpans('${l10nMark(1)} et ${l10nMark(0)}.', [
        const TextSpan(text: 'A', style: bold),
        const TextSpan(text: 'B'),
      ]);
      expect(plain(spans), 'B et A.');
      expect(spans, hasLength(4));
      expect((spans[2] as TextSpan).style, bold);
    });

    test('a message without marks is one plain span', () {
      final spans = l10nSpans('Bonjour', const []);
      expect(spans, hasLength(1));
      expect(plain(spans), 'Bonjour');
    });

    test('a mark without a piece is left out', () {
      expect(plain(l10nSpans('a${l10nMark(3)}b', const [])), 'ab');
    });

    test('keeps characters outside the basic plane', () {
      expect(
        plain(l10nSpans('🎉 ${l10nMark(0)}', const [TextSpan(text: 'x')])),
        '🎉 x',
      );
    });

    test('marks are private-use code points, sixteen of them', () {
      expect(l10nMark(0).runes.single, 0xF0000);
      expect(() => l10nMark(16), throwsRangeError);
    });
  });

  group('LocaleSync', () {
    testWidgets('tells L10n, then each listener, each time the locale '
        'changes; a failing listener stops nothing', (tester) async {
      await useLocale(en);
      final heard = <String>[];
      final errors = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = errors.add;
      addTearDown(() => FlutterError.onError = previous);

      Widget app(Locale locale) => MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) => LocaleSync(
          onLocale: [
            (_) => throw StateError('broken listener'),
            (locale) => heard.add(
              '${locale.languageCode} '
              '${L10n.current.commonNext}',
            ),
          ],
          child: child!,
        ),
        home: const SizedBox(),
      );

      await tester.pumpWidget(app(fr));
      await tester.pump();
      expect(heard, ['fr Suivant']);
      expect(errors.single.exception, isA<StateError>());

      await tester.pumpWidget(app(fr));
      expect(heard, ['fr Suivant'], reason: 'same locale: nothing');

      await tester.pumpWidget(app(en));
      await tester.pump();
      expect(heard, ['fr Suivant', 'en Next']);
      expect(Intl.defaultLocale, 'en');
    });
  });

  test('saveUiLanguage keeps the language for the background', () async {
    SharedPreferences.setMockInitialValues({});
    await saveUiLanguage(const Locale('fr', 'CA'));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(kUiLanguagePrefsKey), 'fr');
  });
}
