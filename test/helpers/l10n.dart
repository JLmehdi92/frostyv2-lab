import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/theme.dart';

/// The French locale, for tests.
const fr = Locale('fr');

/// The English locale, for tests.
const en = Locale('en');

var _interLoaded = false;

/// Loads the bundled Inter faces under the family the app asks for, so
/// text is measured (and drawn, in screenshots) as on a device: tests
/// otherwise lay text out in a test font whose letters are all the same
/// width, which hides French running longer than English.
Future<void> loadInter() async {
  if (_interLoaded) return;
  final loader = FontLoader(OnsetTokens.bodyFamily);
  final faces = Directory(
    'assets/fonts',
  ).listSync().whereType<File>().where((f) => f.path.endsWith('.ttf'));
  for (final face in faces) {
    final bytes = face.readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
  _interLoaded = true;
}

/// Shows [locale] for the rest of the test, as LocaleSync does in the app
/// ([L10n.current], `Intl.defaultLocale`), and puts both back after it.
Future<void> useLocale(Locale locale) async {
  final previousIntl = Intl.defaultLocale;
  final previous = Locale(L10n.current.localeName);
  addTearDown(() {
    L10n.use(previous);
    Intl.defaultLocale = previousIntl;
  });
  await initializeDateFormatting(locale.languageCode);
  L10n.use(locale);
}

/// Pumps [child] in an app showing [locale] (French by default), in a
/// [size] window with text scaled by [textScale], in the real Inter font.
///
/// [wrap] puts the app under what the child needs (providers). Nothing
/// leaks into the next test: the window, [L10n] and `Intl.defaultLocale`
/// are put back.
Future<void> pumpLocalized(
  WidgetTester tester,
  Widget child, {
  Locale locale = fr,
  Size size = const Size(390, 844),
  double textScale = 1,
  ThemeMode themeMode = ThemeMode.dark,
  Widget Function(Widget app)? wrap,
  NavigatorObserver? observer,
}) async {
  await tester.runAsync(loadInter);
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await useLocale(locale);
  final themes = OnsetThemes(colorSchemeSeed: OnsetTokens.accent);
  final app = MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    theme: themes.light,
    darkTheme: themes.dark,
    themeMode: themeMode,
    navigatorObservers: [?observer],
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: child,
  );
  await tester.pumpWidget(wrap?.call(app) ?? app);
}

/// The English texts the screen shows while it should be in French: every
/// drawn text (and text field) equal to an English message that French
/// words differently. Placeholder messages are matched on their fixed
/// text around the placeholders.
List<String> englishLeaks(WidgetTester tester) {
  final english =
      jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
          as Map<String, Object?>;
  final french =
      jsonDecode(File('lib/l10n/app_fr.arb').readAsStringSync())
          as Map<String, Object?>;
  // A word French also shows as is (the endonym "English") is no leak.
  final frenchValues = french.values.toSet();
  final patterns = <RegExp>[];
  for (final MapEntry(:key, :value) in english.entries) {
    if (key.startsWith('@') ||
        value is! String ||
        frenchValues.contains(value)) {
      continue;
    }
    // A plural or select: its branches are not matched (none is shown
    // whole), its simple placeholders are.
    if (RegExp(r'\{\w+,').hasMatch(value)) continue;
    final fixed = value.split(RegExp(r'\{\w+\}')).map(RegExp.escape).join('.+');
    patterns.add(RegExp('^$fixed\$'));
  }
  final shown = <String>{
    for (final widget in tester.widgetList<RichText>(find.byType(RichText)))
      widget.text.toPlainText(),
  };
  return [
    for (final text in shown)
      if (patterns.any((pattern) => pattern.hasMatch(text))) text,
  ];
}
