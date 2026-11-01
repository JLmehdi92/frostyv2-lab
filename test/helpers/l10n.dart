import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

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
/// drawn text, and every label a screen reader reads (`Semantics` labels,
/// values and hints, `Tooltip` messages), equal to an English message that
/// French words differently.
///
/// A message matches on its fixed text around its placeholders, in any case
/// (labels are also shown in capitals); a message with plurals or selects
/// matches on each combination of its branches, wherever they sit in it.
///
/// A text is no leak when the French of the same message also gives it (in
/// any case), or when it is exactly, case included, a French text of any
/// message ("LIVE", the badge, is no leak of "Live", the tab). An English
/// message that French also uses as is, case included (the endonym
/// "English"), is not looked for.
List<String> englishLeaks(WidgetTester tester) => [
  for (final text in shownTexts(tester))
    if (_isEnglishLeak(text)) text,
];

/// Whether [text], shown on a French screen, is English (see
/// [englishLeaks]). Worked out once per text: the screens show the same
/// texts at every scroll step.
bool _isEnglishLeak(String text) =>
    _leakVerdicts.putIfAbsent(text, () => _findsEnglish(text));

final _leakVerdicts = <String, bool>{};

bool _findsEnglish(String text) {
  final (:checks, :frenchValues, :anyEnglish) = _leakChecks;
  if (frenchValues.contains(text)) return false;
  // Most texts match no English message: one pass over all of them first.
  if (!anyEnglish.hasMatch(text)) return false;
  return checks.any(
    (check) =>
        check.english.any((pattern) => pattern.hasMatch(text)) &&
        !check.french.any((pattern) => pattern.hasMatch(text)),
  );
}

typedef _LeakCheck = ({List<RegExp> english, List<RegExp> french});

/// The messages [englishLeaks] looks for, read once from the ARB files, and
/// all their English patterns in one ([anyEnglish]).
final ({List<_LeakCheck> checks, Set<String> frenchValues, RegExp anyEnglish})
_leakChecks = () {
  final english =
      jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
          as Map<String, Object?>;
  final french =
      jsonDecode(File('lib/l10n/app_fr.arb').readAsStringSync())
          as Map<String, Object?>;
  final frenchValues = {
    for (final MapEntry(:key, :value) in french.entries)
      if (!key.startsWith('@') && value is String) ...[
        value,
        // A select's branches, each shown whole ("Activés").
        ..._variants(value).where((v) => !v.contains(_hole)),
      ],
  };
  final checks = <_LeakCheck>[];
  for (final MapEntry(:key, :value) in english.entries) {
    if (key.startsWith('@') || value is! String) continue;
    // Shown as is in French too (an endonym): it cannot be told apart.
    if (frenchValues.contains(value)) continue;
    final englishPatterns = shownPatterns(value);
    if (englishPatterns.isEmpty) continue;
    checks.add((
      english: englishPatterns,
      french: shownPatterns(french[key]! as String),
    ));
  }
  final anyEnglish = RegExp(
    [
      for (final check in checks)
        for (final pattern in check.english) '(?:${pattern.pattern})',
    ].join('|'),
    caseSensitive: false,
    dotAll: true,
  );
  return (checks: checks, frenchValues: frenchValues, anyEnglish: anyEnglish);
}();

/// Every text [tester]'s screen shows a viewer: drawn text (with its
/// spans' screen-reader labels, and `SelectableText`), the texts of each
/// row read together (a number and its word drawn apart, "2 445" +
/// " watching"), and what a screen reader reads from `Semantics` (label,
/// value, hint, tooltip, attributed or not) and `Tooltip` (message).
Set<String> shownTexts(WidgetTester tester) => {
  for (final widget in tester.widgetList<RichText>(find.byType(RichText)))
    widget.text.toPlainText(),
  for (final widget in tester.widgetList<SelectableText>(
    find.byType(SelectableText),
  ))
    ?(widget.data ?? widget.textSpan?.toPlainText()),
  ..._rowTexts(tester),
  for (final widget in tester.widgetList<Semantics>(find.byType(Semantics)))
    ...[
      widget.properties.label,
      widget.properties.value,
      widget.properties.hint,
      widget.properties.tooltip,
      widget.properties.attributedLabel?.string,
      widget.properties.attributedValue?.string,
      widget.properties.attributedHint?.string,
    ].nonNulls.where((text) => text.trim().isNotEmpty),
  for (final widget in tester.widgetList<Tooltip>(find.byType(Tooltip)))
    ?(widget.message ?? widget.richMessage?.toPlainText()),
};

/// The text of each horizontal [Flex] (a `Row`) drawing more than one
/// text: its texts in order, joined as they stand side by side. A number
/// and its word in two `Text`s ("2 445" and " watching") read as one.
Iterable<String> _rowTexts(WidgetTester tester) sync* {
  for (final element in find.byWidgetPredicate((w) => w is Flex).evaluate()) {
    final flex = element.widget as Flex;
    if (flex.direction != Axis.horizontal) continue;
    final texts = <String>[];
    void visit(Element child) {
      if (child.widget case RichText(:final text)) {
        texts.add(text.toPlainText());
        return;
      }
      child.visitChildren(visit);
    }

    element.visitChildren(visit);
    if (texts.length > 1) yield texts.join();
  }
}

/// Punctuation a screen may add after a message: [shownPatterns] lets it
/// follow.
const _trailing = r'[\s.,;:!?…)»\u00a0\u202f]*';

/// Stands for a placeholder (or a plural's `#`) in [_variants].
const _hole = '\u{FFFC}';

/// What [message] can show, as patterns matching the whole text: each
/// combination of its plural and select branches ([_variants]), with each
/// placeholder as any text, and any closing punctuation added after it
/// ("Couldn't load clips." for "Couldn't load clips"). A variant with fewer than three letters of its
/// own around its placeholders ("{scale}x") cannot be told from the data it
/// shows, and gives no pattern.
List<RegExp> shownPatterns(String message) {
  final patterns = <RegExp>[];
  for (final variant in _variants(message)) {
    final fixed = variant.split(_hole);
    if (fixed.length > 1 &&
        RegExp(r'\p{L}', unicode: true).allMatches(fixed.join()).length < 3) {
      continue;
    }
    // Whatever the case: group labels and eyebrows are shown in capitals.
    patterns.add(
      RegExp(
        '^${fixed.map(RegExp.escape).join('.+')}$_trailing\$',
        caseSensitive: false,
        dotAll: true,
      ),
    );
  }
  return patterns;
}

/// The texts an ICU [message] can give: one per combination of the branches
/// of its plurals and selects, each placeholder and plural `#` written as
/// [_hole]. At most [limit] (a message is never near it).
List<String> _variants(String message, {int limit = 512}) {
  var results = <String>[''];
  void append(List<String> pieces) {
    results = [
      for (final head in results)
        for (final piece in pieces) head + piece,
    ];
    if (results.length > limit) {
      throw StateError('Too many variants in: $message');
    }
  }

  final text = StringBuffer();
  var i = 0;
  while (i < message.length) {
    final char = message[i];
    if (char != '{') {
      text.write(char);
      i++;
      continue;
    }
    final end = _closing(message, i);
    append([text.toString()]);
    text.clear();
    final inner = message.substring(i + 1, end);
    final choice = RegExp(
      r'^\s*\w+\s*,\s*(plural|select|selectordinal)\s*,',
    ).firstMatch(inner);
    if (choice == null) {
      append([_hole]);
    } else {
      final isPlural = choice.group(1) != 'select';
      final branches = <String>[];
      var j = choice.end;
      while (true) {
        final open = inner.indexOf('{', j);
        if (open < 0) break;
        final close = _closing(inner, open);
        var branch = inner.substring(open + 1, close);
        if (isPlural) branch = branch.replaceAll('#', _hole);
        branches.addAll(_variants(branch, limit: limit));
        j = close + 1;
      }
      append(branches);
    }
    i = end + 1;
  }
  append([text.toString()]);
  return results;
}

/// The index of the brace closing the one at [open] in [text].
int _closing(String text, int open) {
  var depth = 0;
  for (var i = open; i < text.length; i++) {
    if (text[i] == '{') depth++;
    if (text[i] == '}' && --depth == 0) return i;
  }
  throw FormatException('Unclosed brace', text, open);
}

/// The windows every French screen is checked in: two phones, a landscape
/// and a portrait tablet.
const frenchScreenSizes = [
  ('360x640', Size(360, 640)),
  ('390x844', Size(390, 844)),
  ('1280x854', Size(1280, 854)),
  ('854x1280', Size(854, 1280)),
];

/// The windows the channel screen's French surfaces are checked in: the
/// four above and a landscape phone.
const frenchChannelScreenSizes = [
  ...frenchScreenSizes,
  ('844x390', Size(844, 390)),
];

/// The text scales every French screen is checked at.
const frenchTextScales = [1.0, 1.3];

/// No overflow (nor any other exception) and no English ([englishLeaks]) on
/// what [tester]'s screen shows, then on what each vertical list shows
/// when scrolled to its end. [where] names the screen in failures.
Future<void> expectFrenchThroughout(WidgetTester tester, String where) async {
  void check(String step) {
    final exception = tester.takeException();
    expect(
      exception,
      isNull,
      reason:
          '$where, $step\n'
          '${exception is FlutterError ? exception.toStringDeep() : ''}',
    );
    expect(englishLeaks(tester), isEmpty, reason: '$where, $step');
  }

  check('at the top');
  final lists = tester
      .stateList<ScrollableState>(find.byType(Scrollable))
      .where((state) => state.axisDirection == AxisDirection.down)
      .toList();
  for (final (index, list) in lists.indexed) {
    var steps = 0;
    // A step can rebuild the page and drop a list (a feed's next page):
    // each step asks again whether it is still there.
    while (list.mounted &&
        list.position.pixels < list.position.maxScrollExtent &&
        steps++ < 80) {
      final position = list.position;
      position.jumpTo(
        math.min(
          position.maxScrollExtent,
          position.pixels + position.viewportDimension * 0.75,
        ),
      );
      await tester.pump();
      check('list $index, step $steps');
    }
  }
}

/// The parts of a [MaterialApp] that show [locale] (null: none, as the
/// English tests' bare apps) in the real Inter font with text at
/// [textScale]: call it before pumping, and pass what it gives to the app.
/// [builder] is the app's own builder, kept under the text scale.
Future<
  ({
    Locale? locale,
    List<Locale> supportedLocales,
    List<LocalizationsDelegate<Object?>>? delegates,
    TransitionBuilder? builder,
  })
>
localizedApp(
  WidgetTester tester, {
  Locale? locale,
  double textScale = 1,
  TransitionBuilder? builder,
}) async {
  if (locale == null) {
    return (
      locale: null,
      supportedLocales: const [Locale('en', 'US')],
      delegates: null,
      builder: builder,
    );
  }
  await tester.runAsync(loadInter);
  await useLocale(locale);
  return (
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    delegates: AppLocalizations.localizationsDelegates,
    builder: (BuildContext context, Widget? child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: Builder(
        builder: (context) => builder?.call(context, child) ?? child!,
      ),
    ),
  );
}
