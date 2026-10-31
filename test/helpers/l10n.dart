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
/// text around the placeholders; a message that is one plural or select
/// on each of its branches, in any case (labels shown in capitals too). A
/// text that the French of the same message also gives is no leak.
List<String> englishLeaks(WidgetTester tester) {
  final english =
      jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
          as Map<String, Object?>;
  final french =
      jsonDecode(File('lib/l10n/app_fr.arb').readAsStringSync())
          as Map<String, Object?>;
  // A word French also shows as is (the endonym "English") is no leak.
  final frenchValues = french.values.toSet();
  final checks = <({List<RegExp> english, List<RegExp> french})>[];
  for (final MapEntry(:key, :value) in english.entries) {
    if (key.startsWith('@') ||
        value is! String ||
        frenchValues.contains(value)) {
      continue;
    }
    final englishPatterns = _shownPatterns(value);
    if (englishPatterns.isEmpty) continue;
    checks.add((
      english: englishPatterns,
      french: _shownPatterns(french[key]! as String),
    ));
  }
  final shown = <String>{
    for (final widget in tester.widgetList<RichText>(find.byType(RichText)))
      widget.text.toPlainText(),
  };
  // A text French shows as is, in any case ("LIVE"), is no leak either.
  final frenchTexts = {
    for (final value in frenchValues)
      if (value is String) value.toLowerCase(),
  };
  bool leaks(String text) =>
      !frenchTexts.contains(text.toLowerCase()) &&
      checks.any(
        (check) =>
            check.english.any((pattern) => pattern.hasMatch(text)) &&
            !check.french.any((pattern) => pattern.hasMatch(text)),
      );
  return [
    for (final text in shown)
      if (leaks(text)) text,
  ];
}

/// What [message] can show, as patterns: the message itself with each
/// placeholder as any text, or for a message that is one plural or select,
/// each of its branches. Empty for a choice inside other text (no branch is
/// shown whole), and for text with fewer than three letters of its own
/// around its placeholders.
List<RegExp> _shownPatterns(String message) {
  RegExp? pattern(String text) {
    final fixed = text.split(RegExp(r'\{\w+\}|#'));
    // Next to no words of its own ("{scale}x", "{pixels}px"): it cannot be
    // told from the data it shows.
    if (RegExp(r'\p{L}', unicode: true).allMatches(fixed.join()).length < 3 &&
        fixed.length > 1) {
      return null;
    }
    // Whatever the case: group labels and eyebrows are shown in capitals.
    return RegExp(
      '^${fixed.map(RegExp.escape).join('.+')}\$',
      caseSensitive: false,
    );
  }

  final choice = RegExp(r'^\{\w+, ?(plural|select), ?').firstMatch(message);
  if (choice == null) {
    if (RegExp(r'\{\w+,').hasMatch(message)) return const [];
    return [?pattern(message)];
  }
  // The branches: "selector{text}" up to the closing brace.
  final branches = <RegExp>[];
  var i = choice.end;
  while (i < message.length - 1) {
    final open = message.indexOf('{', i);
    if (open < 0) break;
    var depth = 0;
    var end = open;
    for (; end < message.length; end++) {
      if (message[end] == '{') depth++;
      if (message[end] == '}' && --depth == 0) break;
    }
    final text = message.substring(open + 1, end);
    if (RegExp(r'\{\w+,').hasMatch(text)) return const [];
    if (pattern(text) case final branch?) branches.add(branch);
    i = end + 1;
  }
  return branches;
}
